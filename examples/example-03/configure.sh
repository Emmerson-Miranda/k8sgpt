#!/bin/bash
# Source: https://docs.k8sgpt.ai/getting-started/installation/

# Configuring k8sgpt OpenAI backend
envsubst < k8sgpt.template.yaml | sed "s/OPENAI_API_TOKEN/$OPENAI_API_TOKEN/g" > k8sgpt.yaml

# Deploying errors
kubectl apply -k ../errors

