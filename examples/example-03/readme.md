# K8aGPT - Docker compose

Runs k8sgpt using docker compose.

## Steps:
- [Create KinD cluster](../example-01/clusters-create.sh)
- [Configure docker compose and deploy some pod examples](./configure.sh)
- Analyze what happens in the cluster:
  - `docker compose run --remove-orphans k8sgpt analyse --explain --config /home/root/.k8sgpt.yaml  --kubeconfig /home/root/.kube/config`


