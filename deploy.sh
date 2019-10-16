#!/bin/bash

#### Configuration
resourceGroup="blog-buildagent-rg"
clusterName="azuredevopsbuildagents"
containerRepositoryName="azuredevopsbuildagentimages"
containerName="buildagent"
location="WestEurope"

azureDevOpsUri="https://dev.azure.com/hevand"
azureDevOpsPat="35m24umnhnhcwr7koyuwkcklzellbx6lbh3tlpbg5cq2ngmzrgma"

# Azure Portal
## Login
az configure --defaults location=$location

## Resource Group
az group create --name $resourceGroup

# Create an ACR and AKS
az acr create -g $resourceGroup -n $containerRepositoryName --sku Basic
az aks create -g $resourceGroup -n $clusterName --ssh-key-value ~/.ssh/id_rsa.pub --attach-acr $containerRepositoryName

# Build and push the container image
cd ./buildagent
az acr login --name $containerRepositoryName
az acr build -t $containerName -r $containerRepositoryName .

# Get AKS credentials
az aks get-credentials -g $resourceGroup -n $clusterName

#Install kubectl. 
sudo az aks install-cli

resourceGroup="blog-buildagent-rg"
clusterName="azuredevopsbuildagents"
containerRepositoryName="azuredevopsbuildagentimages"
containerName="buildagent"
location="WestEurope"

azureDevOpsUri="https://dev.azure.com/hevand"
azureDevOpsPat="35m24umnhnhcwr7koyuwkcklzellbx6lbh3tlpbg5cq2ngmzrgma"

# Defining the YAML file in the deployment script, so that parameters can easily be incorporated.
buildagent=$(cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildagent-deployment
  labels:
    app: buildagent-deployment
spec:
  replicas: 2
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

EOF
)

echo "$buildagent" | kubectl apply