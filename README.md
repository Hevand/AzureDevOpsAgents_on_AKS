# DevOps
## About
As companies accelerate their move to the cloud, they run into scenarios where the desire to empower their employees, securing the overall environment and the economics of running things at scale start to negatively impact one another. 

In this article, we'll consider the following scenario: A company has dozens of applications under active development / support. Each application has a dedicated team working on it and these teams are responsible for their own app and infra. The source code for these applications and the supporting infrastructure is stored on premises and is not accessible via the internet. The company is in favor of using Pipelines in Azure DevOps to manage their release process for Azure deployments, requiring to provision the infrastructure and deploy the application. 

>[Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/user-guide/what-is-azure-devops?view=azure-devops) is a Microsoft service offering end-to-end capabilities that are required for software development inside of the enterprise and on your private projects. Azure DevOps comes with a complete set of services, ranging from [Repos](https://azure.microsoft.com/services/devops/repos/) to store and version your source code, automated execution of your CI/CD [Pipelines](https://azure.microsoft.com/services/devops/pipelines/), planning project activities and track progression via [Boards](https://azure.microsoft.com/services/devops/boards/) and [Test Plans](https://azure.microsoft.com/en-us/services/devops/test-plans/) and distribute versions of your project and its components as [Artifacts](https://azure.microsoft.com/en-us/services/devops/artifacts/). 


To achieve this, we'll need to address multiple challenges: 
- Allow the Azure Pipeline to connect to the on premises repository (Networking, Identity)
- Allow the Azure Pipeline to create and configure Azure resources that are required by the application that is being deployed (RBAC)
- Prevent Azure Pipeline to create, delete or modify Azure resources that are **not** related to the application that is being deployed (RBAC)

Once we realize that Microsoft-hosted agents will not be able to access our source code, we start looking at assigning limited permissions to individual teams / applications and leverage self-hosted agents to address infrastructure limitations. 

Applying this concept to our organization, we could end up with the following approach for every team and/or application: 
1) In the Azure DevOps organization, create a Project
2) In the Azure environment, create an Azure Subscription or Resource Group<sup>1</sup>
3) In the Azure environment, create a self-hosted build agent (VM) that connects to our Azure DevOps project. Configure the VM with a Managed Service Identity
4) Grant the MSI permissions to this subscription or resource group
5) In Azure DevOps, configure the build / release pipelines to use the registered self-hosted build agent

This works! The approach addresses all of the challenges identified at the beginning of this article, is elegant in its setup and the amount of work in maintaining the build agents seems manageable. 

Unfortunately, the approach has some limitations as well. As time progresses and the number of project using this setup grows, so do the costs involved in running a large number of self-hosted build agents. What works for few applications does not work for many. 

What could we do to optimize?

### Reduce running costs of the current setup
#### Option 1: Keep setup as-is; configure Auto-shutdown / automated startup
A quick mitigation is to shut down the environment outside of business hours. This is relatively simple to complete, and reducing our compute hours from 24*7 to 12*5 is reducing overall costs with about 60%.

#### Option 2: Keep setup as-is; switch to B-series machines
Shutting down our build agents may not be desirable. An alternative is to change our regular VMs to burstable [B-series VMs](https://azure.microsoft.com/nl-nl/blog/introducing-b-series-our-new-burstable-vm-size). B-series are charged at a lower rate (around 15%) and offers a great alternative for regular VMs in scenarios where the VM has frequent but unpreditable periods of idle time. 

When idle, the B-series will generate credits which can be used to perform at their maximum capacity at later time. When the credits run out, the system will be throttled to run at a lower capacity.

#### Option 3: Keep setup as-is; Leverage Reserved Instances
Another way to reduce costs is via [Reserved Instances (RI)](https://azure.microsoft.com/en-us/pricing/reserved-vm-instances/). With RI, you commit upfront to a particular workload for the next 1 or 3 years. In return, Microsoft bills your workload at a discounted rate, depending on the type of resource and the region (see [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/). 

> To optimize costs, B-Series VMs can be _combined_ with Reserved Instances. 
>
> To illustrate this, let's use the Azure Calculator to compare the price in North Europe for
> * a single DS3v2 (4 vCPU, 14GB RAM, 28GB Temp storage), without reservations 
> * a B4MS (4 vCPU, 14GB RAM, 32GB Temp storage) + 3 years reservation
>
> The savings are more than **73%**! This goes beyond what can be achieved with shutting down the machines.

### Reconsider our setup


### Option 4: Container Orchestrator


* Use a container orchestrator (e.g. Azure Kubernetes Services) to run the workload? This helps us to run multiple agents
* Share our self-hosted build agents across projects?

## The concepts

## Solution

## Alternatives

## Next steps

## Footnotes
<sup>1</sup> Both Subscriptions and Resource Groups provide sufficient isolation for this article. Evaluating all considerations that apply to your particular case would be beyond the scope of this article. 