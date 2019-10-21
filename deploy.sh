#!/bin/bash

# Azure DevOps
azureDevOpsUri="https://dev.azure.com/hevand"
azureDevOpsPat="35m24umnhnhcwr7koyuwkcklzellbx6lbh3tlpbg5cq2ngmzrgma"

#### Configuration
subscriptionId=""
location="WestEurope"
resourceGroup="blog-buildagent-rg"
clusterName="azdo"
containerRepositoryName="azuredevopsbuildagentimages"
containerName="buildagent"

# Let's make sure that we're logged in as the authorized user and working in the right subscription:
az login
az account set -s $subscriptionId

az configure --defaults location=$location

# Azure CLI defaults / extensions
# - Cluster autoscaler: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
az extension add --name aks-preview
az extension update --name aks-preview

## Create Resource Group
az group create --name $resourceGroup

# Create an ACR
az acr create -g $resourceGroup -n $containerRepositoryName --sku Basic

# Create AKS:
# - Connect with ACR for service principal authorization
# - Enable VM Scale Sets + AutoScaling (1..10)
az aks create -g $resourceGroup -n $clusterName \
  --ssh-key-value ~/.ssh/id_rsa.pub \
  --attach-acr $containerRepositoryName \
  --node-count 1 \
  --enable-vmss \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 10

# Build and push the container image to the ACR
cd */buildagent
az acr login --name $containerRepositoryName
az acr build -t $containerName -r $containerRepositoryName .

# Get AKS credentials, to be used with kubectl
az aks get-credentials -g $resourceGroup -n $clusterName

# Deployment YAML file
# - Integrated in deploy.sh for simplified / readable parameter substitution
buildagent=$(cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildagent-deployment
  labels:
    app: buildagent-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: buildagent
  template:
    metadata:
      labels:
        app: buildagent
    spec:
      containers:
      - name: buildagent
        image: $containerRepositoryName.azurecr.io/$containerName:latest
        env:
        - name: AZP_URL
          value: "$azureDevOpsUri"
        - name: AZP_TOKEN
          value: "$azureDevOpsPat"
        resources:
          requests:
            cpu: "1"
            memory: "1024Mi"
          limits:
            cpu: "2"
            memory: "2048Mi"
EOF
)

# Deployment to AKS
sudo az aks install-cli
echo "$buildagent" | kubectl apply -f -

# Enable horizontal pod scaling - https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale
kubectl autoscale deployment "buildagent-deployment" --cpu-percent=50 --min=1 --max=10