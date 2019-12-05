# DevOps
## About
As companies accelerate their move to the cloud, they run into scenarios where self-service, isolation and security starts to negatively impact the costs involved. 

In those situations, it is not always obvious what to do. So, let's  evaluate our options based on the following scenario: 

Company A is developing multiple applications. Every application is owned by a team, and that team is responsible for application and infrastructure. Application source code is stored on premises and is not accessible via the internet. The company is using Azure DevOps Pipelines to manage their release process for Azure deployments.

>**Introduction to Azure DevOps**: [Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/user-guide/what-is-azure-devops?view=azure-devops) is a Microsoft service, offering end-to-end capabilities required for software development teams. Azure DevOps focusses on application development teams and is used by enterprises and individual users. 
>Azure DevOps consists of a set of services, ranging from [Repos](https://azure.microsoft.com/services/devops/repos/) that store and version your source code, via [Pipelines](https://azure.microsoft.com/services/devops/pipelines/) that allow for hosting your CI/CD process, planning project activities and track progression via [Boards](https://azure.microsoft.com/services/devops/boards/) and [Test Plans](https://azure.microsoft.com/en-us/services/devops/test-plans/) and distribute versions of your project and its components as [Artifacts](https://azure.microsoft.com/en-us/services/devops/artifacts/). 


To achieve their goals, the customer realized that they'll need to address several challenges: 
- Allow the Azure Pipeline to connect to the on premises repository (Networking, Identity)
- Allow the Azure Pipeline to create and configure Azure resources that are required by the application that is being deployed (RBAC)
- Prevent Azure Pipeline to create, delete or modify Azure resources that are **not** related to the application that is being deployed (RBAC)

Azure DevOps Pipelines offers Microsoft-hosted agents, but as these agents are not part of your companies network they will have trouble accessing the on premises source code. Consequently, Company A started looking at self-hosted agents. Every agent was made project-specific, so that it was possible to assign a managed service identity and have this identity be authorized ONLY to the teams applications / infrastructure. 

Applying this concept to their organization, they drafted an initial approach and implemented that. For every team and/or application: 
1) In the Azure DevOps organization, create a Project
2) In the Azure environment, create an Azure Subscription or Resource Group<sup>1</sup>
3) In the Azure environment, create a self-hosted build agent (VM) that connects to our Azure DevOps project. Configure the VM with a Managed Service Identity
4) Grant the MSI permissions to this subscription or resource group
5) In Azure DevOps, configure the build / release pipelines to use the registered self-hosted build agent

![Azure agent per project](assets/AzureAgentPerProject.svg)

This approach works quite well. It addresses all of the challenges identified at the beginning of this article and is manageable by the operations team. 

Unfortunately, the approach comes with a major disadvantage - the costs are directly linked to the number of projects. As the number of project grows, the number of self-hosted build agents grows with it. Most of these agents would only be used periodically, but shutting them down complicates and delays the CI/CD process. What works for few applications does not work for many. 

So... how can we optimize?

## Reduce running costs of existing infrastructure
### Option 1: Keep setup as-is; configure Auto-shutdown / automated startup
A quick mitigation is to shut down the environment outside of business hours. This is relatively simple to complete and comes with immediate cost savings as  reducing the compute hours from 24*7 to 12*5 is reducing costs with 60%!

### Option 2: Keep setup as-is; switch to B-series machines
Shutting down our build agents might not be desirable, as development activities could happen across timezones and nightly builds / test runs are a reality for many organizations. 

An alternative is to change from regular VMs to the burstable [B-series VMs](https://azure.microsoft.com/nl-nl/blog/introducing-b-series-our-new-burstable-vm-size). B-series are charged at a lower rate (prices vary, but for argumentation sake: 15% reduction) and offer a great alternative for regular VMs in scenarios where the VM has frequent, but unpredictable, periods of idle time. 

When idle, the B-series will generate credits which can be used to perform at full capacity at later time. When the credits run out, the system will be throttled to run at a lower capacity.

### Option 3: Keep setup as-is; Leverage Reserved Instances
Another way to reduce costs is via [Reserved Instances (RI)](https://azure.microsoft.com/en-us/pricing/reserved-vm-instances/). With RI, you commit upfront to a particular workload for the next 1 or 3 years. In return, Microsoft bills your workload at a discounted rate, depending on the type of resource and the region (see [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/). 

> To optimize costs, B-Series VMs can be _combined_ with Reserved Instances. 
>
> To illustrate this, let's use the Azure Calculator to compare the price in North Europe for
> * a single DS3v2 (4 vCPU, 14GB RAM, 28GB Temp storage), without reservations 
> * a B4MS (4 vCPU, 14GB RAM, 32GB Temp storage) + 3 years reservation
>
> The savings are more than **73%**, exceeding the savings realized by shutting down the machines outside of business hours(!).

## Reconsider our setup
Reducing the costs for a given VM is a good practice and yields great results in this scenario. But what if we would change the approach even more dramatically? 

In the current cost model, the baseline infrastructure requirement is driven by the total number of _projects_: an ever-increasing number, where every project will add another build agent, which will run continuously. 

When we start sharing build agents across projects, that changes. When shared, the _max number of parallel builds_ is what defines the required infrastructure and corresponding costs.

That makes for a much easier conversation with anyone that controls our budget, so let's think about how we can share build agents across projects - without sacrificing security or isolation. 

## The concepts
### Azure DevOps Agent Pools
In Azure DevOps, self-hosted build agents are managed via so-called [Agent Pools](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/pools-queues?view=azure-devops&tabs=yaml). Every running build agent is expected to register itself with the pool, and every pipeline will define from which pool it expects to be granted resources when executing its jobs. 

![Azure - Agent Per Organization](assets/AzureAgentPerOrganization.svg)

Agent Pools can be defined / made available at the level of the organization or on the level of individual projects within an Azure DevOps organization.

### Service Connections
In Azure DevOps, Service Connections allow us to register a connection with an  external / remote services _once_ and reference to that connection within the scope of the project. Sensitive information (such as the certificate or key) is only accessible to the platform, not to the end-user. 

![DevOps - Agent Per Organization](assets/DevOpsAgentPerOrganization.svg)

During execution of a Pipeline, DevOps will pass the connection to the build agent running the job. This allows the build agent to interact with the external / remote service in a secure way.

### Azure Kubernetes Cluster Scaling
A container orchestrator allows us to manage a given workload on a cluster of VMs. To optimize running costs while maximizing the number of concurrent pipeline executions, it would be very beneficial to dynamically scale the number of nodes in the cluster. 

On Azure, this is possible by combining the AKS cluster autoscaler with [horizontal pod scaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/): 
- [AKS Auto-scaler](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler) (Preview) - Scales out the underlying cluster, to be used by Kubernetes to host 1 or more containers.
- [Horizontal pod scaling on AKS](https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale) - Adding additional pods (i.e. agents) based on the resource utilization of the existing pods.

## The technology
### Prerequisites
Please ensure that the following components are installed / available: 

**On your local machine**
- [Docker Desktop (for Windows)](https://docs.docker.com/docker-for-windows/install/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Bash (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10?redirectedfrom=MSDN)

**In the cloud**
- [Azure subscription](https://azure.microsoft.com/en-us/free/)
- [Azure DevOps organization](https://docs.microsoft.com/en-us/azure/devops/user-guide/sign-up-invite-teammates?view=azure-devops)


### Create a _Default_ agent pool and get credentials
- Create an [Agent Pool](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/pools-queues?view=azure-devops&tabs=yaml%2Cbrowser#creating-agent-pools) named "_Default_" on your Azure DevOps organization. While using a different name is possible, it requires you to modify some of the scripts / parameters that come with this article.  
- [Prepare permissions](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#permissions) by generating a Personal Access Token (PAT). This token should be treated as highly confidential and stored securely.

### Setup the build agent in your Azure environment
First, we connect with Azure and ensure that we're working in the appropriate subscription / location:

```bash
az login
az account set -s $subscriptionGuid
az configure --defaults location=$location
```

Next, let's enable the AKS preview features that we'll be using - and set a few default configuration values as well:
```bash
# Azure CLI defaults / extensions
# - Cluster autoscaler: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
az extension add --name aks-preview
az extension update --name aks-preview
```

In our next step, let's create the core Azure components: a resource group, container registry and kubernetes environment:

```bash
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
```

### Package your build agent as a container
Once these are successfully provisioned, it is time to create the docker file for the build agent. 

We're going to use the [linux-based self-hosted agent on docker](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops#linux).

> The docker file references a `start.sh` file. This file is quite lengthy and excluded here for readability, but is crucial for the build agent to register itself correctly with the Azure DevOps environment. Make sure to get it - either from the link above or as part of this repository. 

```Docker
FROM ubuntu:16.04

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        git \
        iputils-ping \
        libcurl3 \
        libicu55 \
        libunwind8 \
        netcat

WORKDIR /azp

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
```

Once the dockerfile is created, it can be build and published as follows: 

```bash
# Build and push the container image to the ACR
cd */buildagent
az acr login --name $containerRepositoryName
az acr build -t $containerName -r $containerRepositoryName .
```

### Deploy the container onto AKS
The next step is to deploy the build agent image to the kubernetes environment. For this purpose, we're going to use a yaml file that defines the appropriate image, resource requirements and the number of instances. 

Specific for this article are the following two settings: 
- _environment variables_, that are used to pass the Azure DevOps organization / key to the container during startup. 
- _resource reservations_, that are used for horizontal scaling of the pods. 

```bash
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
```

This yaml file is then used to deploy the agent: 
```bash
# Deployment to AKS
sudo az aks install-cli
echo "$buildagent" | kubectl apply -f -

# Enable horizontal pod scaling - https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale
kubectl autoscale deployment "buildagent-deployment" --cpu-percent=50 --min=1 --max=10
```

That's it! You've just created an environment with a single build agent, which will automatically scale out based on your organization's requirements. 

As the build agent is now shared across projects, the last step is to ensure that a build agent can only interact with source code repositories and azure infrastructure that is owned by the project.  

## Project and resource group setup
### In Azure 
In the Azure environment, create the following:
- A [Resource Group](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview#resource-groups) per project / environment
- An [Azure AD Application](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) per project / environment
- [Assign the Azure AD application Contributor permissions](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal) to the appropriate resource group(s). 


### In Azure DevOps
In the Azure DevOps environment, create the following:
- A [Project](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page) per project
- A [Service Connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml) for every project, configured with the Azure AD application ID. 
- A (number of) [build + release pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=browser%2Ctfs-2018-2). These pipelines should use the _Default_ agent pool and leverage the service connection when deploying to Azure. 

With this in place, the only step left is to generate enough load to see the auto-scaling in action. 

# Conclusions
## Cleaning up orphaned build agents
Every instance of the build agent will register itself with our agent pool. As we're continuously generating new ones (by design), over time the number of build agents will only grow. To address this, consider the following script: 


```bash
#!/bin/bash

while getopts o:p:t: opts; do
   case ${opts} in
      o) azureDevOpsUri=${OPTARG} ;;
      p) azureDevOpsAgentPoolName=${OPTARG} ;;
      t) azureDevOpsPat=${OPTARG} ;;
   esac
done

# AZ DevOps CLI doesn't allow management of pipeline agents (yet) 
# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/agents/list?view=azure-devops-rest-5.1

echo "This script will remove all offline agents for Organization '$azureDevOpsUri' and Pool '$azureDevOpsAgentPoolName'";
# Get the agent pool(s) for this organization
AZP_AGENT_POOLS=$(curl -LsS \
  -u user:$azureDevOpsPat \
  -H 'Accept:application/json;' \
  "$azureDevOpsUri/_apis/distributedtask/pools?api-version=5.1")

echo "The following agent pools were found:"
echo $AZP_AGENT_POOLS | jq ".value[] | [.name, .id] | tostring"

AZP_AGENT_POOLID=$(echo $AZP_AGENT_POOLS | jq ".value[] | select(.name==\"$azureDevOpsAgentPoolName\") | .id")
echo "Continuing with agent pool id: '$AZP_AGENT_POOLID'"
echo ""


# Get the list of agents that exist
AZP_AGENT_LIST=$(curl -LsS \
  -u user:$azureDevOpsPat \
  -H 'Accept:application/json;' \
  "$azureDevOpsUri/_apis/distributedtask/pools/$AZP_AGENT_POOLID/agents?api-version=5.1")

echo "The following agents were found in pool '$AZP_AGENT_POOLID':"
echo $AZP_AGENT_LIST | jq ".value[] | [.name, .id, .status] | tostring"

# Filter for offline agents
AZP_AGENT_OFFLINE_IDS=$(echo $AZP_AGENT_LIST | jq '.value[] | select(.status=="offline") | .id')

for i in $AZP_AGENT_OFFLINE_IDS
do 
  echo "Deleting Agent '$i' in Pool '$AZP_AGENT_POOLID'..."
  # Delete
  AZP_AGENT_RESPONSE=$(curl -LsS \
    -X DELETE \
    -u user:$azureDevOpsPat \
    -H 'Accept:application/json;api-version=3.0-preview' \
    "$azureDevOpsUri/_apis/distributedtask/pools/$AZP_AGENT_POOLID/agents/$i?api-version=5.1")

  echo $AZP_AGENT_RESPONSE

  echo ""
done

echo "Script completed"
```

## Regularly updating the build agent
Microsoft releases a new version of the build agent every few weeks. In this article, we've taken a specific version and used this to generate our own. As part of application lifecycle management and subject to your requirements, the build agent should be updated every once in a while. 

- [Verion and upgrade](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops#agent-version-and-upgrades)


## Storing application secrets in the library
In this article, we've not used an Azure DevOps variable groups to store parameters. In practice, you do want to store common and sensitive (such as a PAT) parameters outside of the actual pipeline. [Variable groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml) offer that flexibility. 


## Errata
<sup>1</sup> Both Subscriptions and Resource Groups provide sufficient isolation for this article. Evaluating all considerations that apply to your particular case would be beyond the scope of this article. 