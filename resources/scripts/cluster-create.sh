#!/bin/bash

# Set error handling
set -euo pipefail


#######################################
# Validates if a hostname exists in /etc/hosts file
# Arguments:
#   param_hostname: The hostname to check (e.g., argocd.owl.com)
# Returns:
#   0 if hostname is found, exits with 1 if not found
# Outputs:
#   Success or error message to stdout
#######################################
function check_hostname(){
    if [ -z "$1" ]; then
        echo "ERROR: Hostname parameter is required"
        exit 1
    fi
    param_hostname="$1"
    if grep -q "$param_hostname" /etc/hosts; then
        echo "✓ Hostname '$param_hostname' found in /etc/hosts"
    else
        echo "*********************************************************************************"
        echo "ERROR: Pre-requisite not satisfied!"
        echo "Add the hostname $param_hostname in /etc/hosts pointing to your IP 192.168.x.y"
        echo "*********************************************************************************"
        exit 1
    fi
}

#######################################
# Checks if a required file exists in the filesystem
# Arguments:
#   filename: The path to the file to check
# Returns:
#   0 if file exists, exits with 1 if not found
# Outputs:
#   Success or error message to stdout
#######################################
function check_file_exist(){
    if [ -z "$1" ]; then
        echo "ERROR: Filename parameter is required"
        exit 1
    fi
    filename="$1"
    echo "Checking file exists: $filename"
    if ! test -f "$filename"; then
        echo "*********************************************************************************"
        echo "ERROR: Required file does not exist: $filename"
        echo "*********************************************************************************"
        exit 1
    fi
}

#######################################
# Creates and configures a KinD (Kubernetes in Docker) cluster 
# Sets up nginx ingress controller and waits for it to be ready
# Arguments:
#   param_folder: Base folder containing KinD configuration files (optional)
# Returns:
#   0 on success, exits with 1 on failure
# Outputs:
#   Status messages and errors to stdout
#######################################
function create_kind_cluster(){
    echo "------------------------ create_kind_cluster ---------------------------------------------------"
    echo "------------------------------------------------------------------------------------------------"
    
    param_folder="$1"

    if ! command -v kind &> /dev/null; then
        echo "ERROR: KinD is not installed. Please install it first."
        exit 1
    fi

    #calculating base folder where resources are located
    currentfolder=$(pwd)
    basefolder="${param_folder:-$currentfolder}"
    echo "KinD configuration base folder: $basefolder"

    #verifying if the current cluster is already active
    cluster_name=$(cat "$basefolder/kind/poc-cluster.yaml" | yq .name)
    cluster=$(kubectl config current-context 2>/dev/null || echo "none")
    cluster_name_expected="kind-$cluster_name"
    if [ "$cluster" = "$cluster_name_expected" ]; then
        echo "✓ Cluster $cluster already present."
        return
    else
        echo "Creating KinD cluster..."
    fi

    #create KinD cluster
    check_file_exist "$basefolder/kind/poc-cluster.yaml"
    kind create cluster --config "$basefolder/kind/poc-cluster.yaml"

    # Deploying KinD ingress
    check_file_exist "$basefolder/kind/nginx-ingress-kind-deploy.yaml"
    kubectl apply -f "$basefolder/kind/nginx-ingress-kind-deploy.yaml"
    sleep 15
    echo "Waiting for ingress-nginx pod to be ready $(date)"
    if ! kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s; then
        echo "*********************************************************************************"
        echo "ERROR: KinD Ingress controller not ready"
        echo "Inspect ingress pods: kubectl --namespace ingress-nginx get po"
        echo "*********************************************************************************"
        kubectl --namespace ingress-nginx get po
        exit 1
    fi
    echo "✓ Ingress-nginx pod ready $(date)"
}

#######################################
# Installs and configures ArgoCD in the cluster
# Includes initial setup, admin password retrieval, and CLI login
# Arguments:
#   param_folder: Base folder containing ArgoCD configuration files (optional)
# Returns:
#   0 on success, exits with 1 on failure
# Outputs:
#   ArgoCD admin password and status messages to stdout
# Notes:
#   - Requires helm to be installed
#   - Stores admin password in tmp/admin-password-argocd.txt
#######################################
function install_argocd(){
    echo "---------------------- install_argocd -----------------------------------------------------"
    echo "-------------------------------------------------------------------------------------------"
    argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    if [ "$argoPass" != "" ]; then
        echo "ArgoCD already present. Admin pass: $argoPass"
        return
    else
        echo "Deploying ArgoCD ..."
    fi
      
    param_folder="$1"
    currentfolder=$(pwd)
    basefolder="${param_folder:-$currentfolder}"
    echo "ArgoCD configuration base folder: $basefolder"

    helm repo add argo-cd https://argoproj.github.io/argo-helm
    check_file_exist $basefolder/values/argocd-values.yaml
    helm upgrade argocd argo-cd/argo-cd -i -n argocd -f $basefolder/values/argocd-values.yaml --create-namespace
    sleep 15
    kubectl wait po  -l app.kubernetes.io/name=argocd-server --for=condition=Ready -n argocd --timeout=60s

    argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "---------------------------------------"
    echo "ArgoCD Admin pass: $argoPass"
    echo "---------------------------------------"
    mkdir -p $basefolder/tmp
    echo $argoPass > $basefolder/tmp/admin-password-argocd.txt

    # LOGIN in ARGO CLI
    i=0
    until [[ $i -gt 6  ]]
    do
        argocd login --insecure --grpc-web argocd.owl.com --username admin --password $argoPass
        if [ $? -eq 0 ]; then
            echo 'Login succeeded'
            break
        else
            echo "Login $i failed, sleeping 5 secs"
            sleep 5
        fi

        i=$((i+1))
    done
}

#######################################
# Creates an ArgoCD secret for connecting to a remote Kubernetes cluster
# Extracts certificate data from kubeconfig and creates a secret manifest
# Arguments:
#   param_base_folder: Base folder containing ArgoCD manifests
#   param_cluster_name: Name of the cluster in kubeconfig
#   para_target_filename: Output file for the generated secret
# Returns:
#   0 on success, exits with 1 on failure
# Requirements:
#   - yq command-line tool
#   - Valid kubeconfig with cluster credentials
# Outputs:
#   Status messages and errors to stdout
#######################################
function create_argocd_secret_cluster_from_kubeconfig(){
    if [ "$#" -ne 3 ]; then
        echo "ERROR: Required parameters: <base_folder> <cluster_name> <target_filename>"
        exit 1
    fi

    param_base_folder="$1"
    param_cluster_name="$2"
    para_target_filename="$3"

    echo "Creating ArgoCD secret for cluster: $param_cluster_name"
    echo "Base folder: $param_base_folder"
    echo "Target file: $para_target_filename"

    if ! grep -q "$param_cluster_name" ~/.kube/config; then
        echo "*********************************************************************************"
        echo "ERROR: Cluster $param_cluster_name not found in ~/.kube/config!"
        echo "*********************************************************************************"
        exit 1
    fi

    if ! command -v yq &> /dev/null; then
        echo "ERROR: yq command is required but not found"
        exit 1
    fi

    caData=$(yq eval ".clusters[] | select(.name==\"$param_cluster_name\") | .cluster.certificate-authority-data" ~/.kube/config)
    certData=$(yq eval ".users[] | select(.name==\"$param_cluster_name\") | .user.client-certificate-data" ~/.kube/config)
    keyData=$(yq eval ".users[] | select(.name==\"$param_cluster_name\") | .user.client-key-data" ~/.kube/config)

    if [ -z "$caData" ] || [ -z "$certData" ] || [ -z "$keyData" ]; then
        echo "ERROR: Failed to extract required certificate data from kubeconfig"
        exit 1
    fi

    check_file_exist "$param_base_folder/resources/manifests/argocd/secret-cluster-template.yaml"
    sed -e "s/PLACEHOLDER_CERT_DATA/$certData/" \
        -e "s/PLACEHOLDER_KEY_DATA/$keyData/" \
        -e "s/PLACEHOLDER_CA_DATA/$caData/" \
        -e "s/PLACEHOLDER_CLUSTER/$param_cluster_name/" \
        "$param_base_folder/resources/manifests/argocd/secret-cluster-template.yaml" > "$para_target_filename"
}

#######################################
# Installs and configures HashiCorp Vault in the cluster
# Includes initialization, unsealing, and setting up example secrets
# Arguments:
#   param_folder: Base folder containing Vault configuration files (optional)
# Returns:
#   0 on success, exits with 1 on failure
# Outputs:
#   Vault root token and status messages to stdout
# Notes:
#   - Requires helm to be installed
#   - Stores initialization data in tmp/vault-operator-init.txt
#   - Stores root token in tmp/root-token-vault.txt
#   - Sets up kv-v2 secrets engine with example secrets
#######################################
function install_hashicorp_vault(){
    echo "--------------------- install_hashicorp_vault ------------------------------------------------------"
    echo "----------------------------------------------------------------------------------------------------"
    param_folder="$1"
    currentfolder=$(pwd)
    basefolder="${param_folder:-$currentfolder}"
    mkdir -p $basefolder
    #echo "Base folder: $basefolder"

    phase=$(kubectl -n vault get po vault-0 -o=jsonpath={.status.phase})
    if [ "$phase" = "Running" ]; then
        roottoken=$(cat $basefolder/tmp/root-token-vault.txt)
        #echo "Hashicorp Vault already present. Admin Token: $roottoken"
        echo $roottoken
    else
        #echo "Deploying Hashicorp Vault ..."

        helm repo add hashicorp https://helm.releases.hashicorp.com
        check_file_exist $basefolder/values/hashicorp-vault-values.yaml
        helm upgrade vault hashicorp/vault -i -n vault -f $basefolder/values/hashicorp-vault-values.yaml --create-namespace
        sleep 15
        kubectl wait po  -l app.kubernetes.io/name=vault --for=condition=Ready -n vault --timeout=60s

        kubectl -n vault exec vault-0 -- vault operator init > $basefolder/tmp/vault-operator-init.txt
        key1=$(cat $basefolder/tmp/vault-operator-init.txt | grep "Unseal Key 1" | cut -d' ' -f4-)
        key2=$(cat $basefolder/tmp/vault-operator-init.txt | grep "Unseal Key 2" | cut -d' ' -f4-)
        key3=$(cat $basefolder/tmp/vault-operator-init.txt | grep "Unseal Key 3" | cut -d' ' -f4-)
        roottoken=$(cat $basefolder/tmp/vault-operator-init.txt | grep "Initial Root Token:" | cut -d' ' -f4-)
        echo $roottoken > $basefolder/tmp/root-token-vault.txt

        kubectl -n vault exec vault-0 -- vault operator unseal $key1 
        kubectl -n vault exec vault-0 -- vault operator unseal $key2
        kubectl -n vault exec vault-0 -- vault operator unseal $key3
        kubectl -n vault exec vault-0 -- vault login $roottoken

        kubectl -n vault exec vault-0 -- vault secrets enable kv-v2
        kubectl -n vault exec vault-0 -- vault secrets list
        kubectl -n vault exec vault-0 -- vault kv put kv-v2/my-secrets/secret1 username=emmerson1 password=mypassword1
        kubectl -n vault exec vault-0 -- vault kv put kv-v2/my-secrets/secret2 username=emmerson2 password=mypassword2
        kubectl -n vault exec vault-0 -- vault kv put kv-v2/my-secrets/secret3 username=emmerson3 password=mypassword3
        echo $roottoken
    fi
}


#######################################
# Waits for a KinD cluster to be fully ready by checking node status
# Arguments:
#   None
# Returns:
#   0 on success, exits with 1 on timeout
# Outputs:
#   Status messages to stdout
#######################################
function wait_for_kind_cluster() {
    echo "Waiting for KinD cluster nodes to be ready..."
    
    # Try for up to 2 minutes (24 * 5 seconds)
    for i in {1..24}; do
        if kubectl wait --for=condition=ready nodes --all --timeout=5s >/dev/null 2>&1; then
            echo "✓ All KinD cluster nodes are ready"
            return 0
        fi
        echo "Still waiting for nodes to be ready... (attempt $i/24)"
        sleep 5
    done

    echo "*********************************************************************************"
    echo "ERROR: Timeout waiting for KinD cluster nodes to be ready"
    echo "Check cluster status with: kubectl get nodes"
    echo "*********************************************************************************"
    exit 1
}
