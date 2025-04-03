
# Source: https://docs.k8sgpt.ai/getting-started/getting-started/

# Installing k8sgpt command line
brew_tap=$(brew tap)
if [[ "$brew_tap" == *"k8sgpt"* ]]; then
    k8sgpt version
else
    brew tap k8sgpt-ai/k8sgpt
    brew install k8sgpt
fi

# Configuring k8sgpt OpenAI backend
k8sgpt_auth_list=$(k8sgpt auth list --details)
if [[ "$k8sgpt_auth_list" == *"Model: gpt-4o-mini"* ]]; then
    echo "OpenAI backend enabled!"
else
    echo "Adding OpenAI backend!"
    k8sgpt auth add --backend openai --model gpt-4o-mini
fi

kubectl apply -f broken-pod.yml
kubectl apply -f node-selector-pod.yml
