
k8sgpt_namespace="k8sgpt-operator-system"

kubectl apply -f k8sgpt-sample.yaml -n $k8sgpt_namespace

kubectl apply -k ../errors