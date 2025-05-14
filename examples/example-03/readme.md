# K8S GPT Command Line

Runs k8sgpt using docker compose.

## Steps:
- [Create KinD cluster](../example-01/clusters-create.sh)
- [Configure Command line and deploy some pod examples](./configure.sh)
- Analyze what happens in the cluster:
  - `docker compose run --remove-orphans k8sgpt analyse --explain --config /home/root/.k8sgpt.yaml  --kubeconfig /home/root/.kube/config`


