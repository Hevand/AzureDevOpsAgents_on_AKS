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