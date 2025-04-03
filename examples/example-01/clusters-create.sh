#!/bin/bash
folder=$(pwd)
examples=$(dirname "$folder")
parent=$(dirname "$examples")

# Sources the cluster creation script that contains functions for creating
# a k3d cluster and installing ArgoCD
source ../resources/scripts/cluster-create.sh 

create_kind_cluster $parent/resources 

k8sgpt_namespace="k8sgpt-operator-system"
instalation_list=$(helm list -n $k8sgpt_namespace)

if [[ "$instalation_list" == *"k8sgpt"* ]]; then
    echo "k8sgpt is already installed."
else
    helm repo add k8sgpt https://charts.k8sgpt.ai/
    helm repo update
    helm install k8sgpt-poc k8sgpt/k8sgpt-operator -n $k8sgpt_namespace --create-namespace

    OPENAI_TOKEN="${OPENAI_TOKEN:-not-provided}"
    kubectl create secret generic k8sgpt-openai-secret --from-literal=openai-api-key=$OPENAI_TOKEN -n $k8sgpt_namespace
fi

kubectl apply -f k8sgpt-sample.yaml -n $k8sgpt_namespace

echo "Installation finished!"