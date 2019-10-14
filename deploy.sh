#!/bin/bash

#### Configuration
resourceGroup="blog-buildagent-rg"
clusterName="azuredevopsbuildagents"
containerRepositoryName="azuredevopsbuildagentimages"
containerName="buildagent"
location="WestEurope"

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

kubectl apply -f buildagent.yaml