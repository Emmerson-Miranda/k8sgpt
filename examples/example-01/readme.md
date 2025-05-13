# example-01

Basic installation of k8sGPT operator (chart) in KinD.

- Export you OPENAI API token as environment variable: `export OPENAI_API_TOKEN="sk....MA"`
- [Create KinD cluster and deploy K8sGPT operator with Helm Chart](./clusters-create.sh)
- Run `configure.sh`
- List all errors detected by k8sgpt `k get results -A`

``` 
NAMESPACE                NAME                                KIND   BACKEND   AGE
k8sgpt-operator-system   defaultcrashloopdemo                Pod    openai    4m14s
k8sgpt-operator-system   defaultimagepullerrordemo           Pod    openai    6m48s
k8sgpt-operator-system   defaultlivenessfailuredemo          Pod    openai    4m14s
k8sgpt-operator-system   defaultpendingpoddemo               Pod    openai    6m48s
k8sgpt-operator-system   defaultpvcfailuredemo               Pod    openai    6m48s
k8sgpt-operator-system   defaultreadinessfailuredemo         Pod    openai    6m48s
k8sgpt-operator-system   defaultstuckcontainercreatingdemo   Pod    openai    6m48s
k8sgpt-operator-system   defaultunschedulableaffinitydemo    Pod    openai    6m48s
```

- Get details of specific error

```
k describe result defaultcrashloopdemo -n k8sgpt-operator-system
Name:         defaultcrashloopdemo
Namespace:    k8sgpt-operator-system
Labels:       k8sgpts.k8sgpt.ai/backend=openai
              k8sgpts.k8sgpt.ai/name=k8sgpt-sample
              k8sgpts.k8sgpt.ai/namespace=k8sgpt-operator-system
Annotations:  <none>
API Version:  core.k8sgpt.ai/v1alpha1
Kind:         Result
Metadata:
  Creation Timestamp:  2025-05-13T23:38:25Z
  Generation:          1
  Resource Version:    5072
  UID:                 cc88572d-403f-419f-9b79-52c4f7472409
Spec:
  Backend:  openai
  Details:  Error: The container named "crashing-container" in the pod "crashloop-demo" is repeatedly crashing and failing to start, leading to a crash loop.

Solution: 
1. Check logs: `kubectl logs crashloop-demo -c crashing-container`
2. Identify the error causing the crash.
3. Modify the container code/configuration as needed.
4. Increase resources if necessary.
5. Redeploy the pod: `kubectl delete pod crashloop-demo`
  Error:
    Text:         the last termination reason is Error container=crashing-container pod=crashloop-demo
  Kind:           Pod
  Name:           default/crashloop-demo
  Parent Object:  
Status:
  Lifecycle:  historical
Events:       <none>
```