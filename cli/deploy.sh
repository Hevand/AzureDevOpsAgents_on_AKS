#!/bin/bash

#### Configuration
resourceGroup="AKSBuildAgent"
clusterName="AKSBuildAgentCluster"
containerRepositoryName="AKSBuildAgentACR"
location="WestEurope"

AzureDevOpsUri="https://dev.azure.com/hevand/DevOps"
AzureDevOpsPAT=""
AzureDevOpsAgentName="AKSBuildAgent"


# Azure Portal
## Login
az configure --defaults location=$location

## Resource Group
az group create --name $resourceGroup

# Create an ACR
az acr create -g $resourceGroup -n $containerRepositoryName --sku Basic
az acr login --name $containerRepositoryName

# Create AKS cluster
az aks create -g $resourceGroup -n $clusterName --ssh-key-value ~/.ssh/id_rsa.pub

# Build agent
cd ../buildagent
docker build -t buildagent:latest .
docker push $containerRepositoryName.azurecr.io/buildagent

# Provision Agent
#docker run -e AZP_URL=$AzureDevOpsUri -e AZP_TOKEN=$AzureDevOpsPAT -e AZP_AGENT_NAME=$AzureDevOpsAgentName buildagent:latest