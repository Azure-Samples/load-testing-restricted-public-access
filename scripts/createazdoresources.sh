#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script is used to create Azure DevOps Service Connection, Variable Group and Azure DevOps pipeline
#- Parameters are:
#- [-o] organization - The Azure DevOps organization.
#- [-p] project - The Azure DevOps project.
#- [-y] repository - The Azure DevOps repository.
#- [-s] subscription - The subscription where the resources will reside.
#- [-t] tenantId - The Azure AD Tenant Id.
#- [-i] serviceprincipalId - The service principal id.
#- [-k] serviceprincipalKey - The service principal Key.
#- [-r] region - The Azure Region for the deployment (eastus2 by default).
###########################################################################################################################################################################################
set -eu
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)
cd "$parent_path"
# colors for formatting the output
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

errorMessage()
{
    printf "${RED}%s${NC}\n" "$*" >&2;
}
infoMessage()
{
    printf "${BLUE}%s${NC}\n" "$*";
}
#######################################################
#- function used to print out script usage
#######################################################
function usage() {
    infoMessage
    infoMessage "Arguments:"
    infoMessage " -o  Sets the Azure DevOps Organization"
    infoMessage " -p  Sets the Azure DevOps Project"
    infoMessage " -y  Sets the Azure DevOps Repository"
    infoMessage " -s  Sets the Azure Subscription"
    infoMessage " -t  Sets the Azure AD Tenant Id"
    infoMessage " -i  Sets the Service Principal id"
    infoMessage " -k  Sets the Service Principal Key"
    infoMessage " -r  Sets the Azure Region (eastus2 by default)"
    infoMessage
    infoMessage "Example:"
    infoMessage " bash createazdoresources.sh -o myOrg -p myProj -y myRepo -s b5c9fc83-fbd0-4368-9cb6-1b5823479b6a  -t 691ad3eb-9808-44f8-b9bf-368c69a4f712 -i 6a13df32-a807-43c4-8277-16f454c7078b -k xxxxxxxxxxxxxxxxxxxx"
}

# Run 'az config set extension.use_dynamic_install=yes_without_prompt' to allow installing extensions without prompt 
az config set extension.use_dynamic_install=yes_without_prompt 2>/dev/null

organization=
project=
repository=
subscription=
tenant=
spid=
spkey=
pipelineName="Load-Testing-EventHubs" 
pipelineDescription="Load Testing Event Hubs with restricted public access endpoint"
pipelineBranch="main"
variableGroup="load-testing-vg"
region="eastus2"
while getopts ":o:p:y:t:s:i:k:r:" opt; do
    case $opt in
    o) organization=$OPTARG ;;
    p) project=$OPTARG ;;
    y) repository=$OPTARG ;;
    s) subscription=$OPTARG ;;
    t) tenant=$OPTARG ;;
    i) spid=$OPTARG ;;
    k) spkey=$OPTARG ;;
    r) region=$OPTARG ;;
    :)
        errorMessage "Error: -${OPTARG} requires a value"
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done
# Make sure we are connected using a user principal that has Azure AD Admin permissions.
# az logout
# az login

# Validation
if [[ $# -eq 0 || -z $organization || -z $project ||  -z $repository || -z $tenant || -z $subscription || -z $spid || -z $spkey || -z $region ]]; then
    errorMessage "Required parameters are missing"
    usage
    exit 1
fi


checkError() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occurred in createazdoresources.sh bash${NC}"
        exit 1
    fi
}
# get Azure Subscription and Tenant Id if already connected
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true

# check if configuration file is set 
if [[ -z ${AZURE_SUBSCRIPTION_ID} || -z ${AZURE_TENANT_ID}  ]]; then
    errorMessage "Connection to Azure required, launch 'az login'"
    exit 1
fi

infoMessage "Creating Service Connection for:" 
infoMessage "  Subscription: $subscription" 
infoMessage "  Tenant: $tenant" 
infoMessage "  Service Principal Id: $spid" 
az account set --subscription "$subscription" >/dev/null

scJsonResult=""
spName=$(az ad sp show --id "${spid}" | jq -r '.displayName')
if [ -n "${spName}" ]
then
    servicePrincipalName=${spName/https:\/\//}
    subscriptionName=$(az account show -n "${subscription}" | jq -r '.name')
    if [ -n "${subscriptionName}" ]
    then
        scid=$(az devops service-endpoint list  --organization "https://dev.azure.com/${organization}/" --project "${project}" | jq -r '.[] | select(.name=="'sc-"${servicePrincipalName}"'").id')
        if [ -n "${scid}" ]
        then
            infoMessage "Service Connection already exists, deleting it..." 
            scJsonResult=$(az devops service-endpoint delete --id "${scid}" --org "https://dev.azure.com/${organization}/" --project "${project}" --yes  )
            # echo "$scJsonResult"
        fi
        infoMessage "Creating Service Connection..." 
        export AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY="${spkey}"
        scJsonResult=$(az devops service-endpoint azurerm create --org "https://dev.azure.com/${organization}/" --project "${project}"  --azure-rm-service-principal-id "${spid}" --azure-rm-subscription-id "${subscription}" --azure-rm-subscription-name "${subscriptionName}" --azure-rm-tenant-id "${tenant}" --name "sc-${servicePrincipalName}")
        scid=$(echo "$scJsonResult" | jq -r '.id')
        if [ -n "${scid}" ]
        then
            infoMessage "Updating Service Connection to allow all pipelines..." 
            scJsonResult=$(az devops service-endpoint update --id "${scid}" --org "https://dev.azure.com/${organization}/" --project "${project}" --enable-for-all true  )
            # echo "$scJsonResult"
        fi
    else
        errorMessage "Azure Subscription with Id: ${subscription} not found"
        exit 1
    fi
else
    errorMessage "Service Principal with Id: ${spid} not found"
    exit 1
fi

infoMessage "Creating Variables Group '${variableGroup}' for:" >&2
infoMessage "  Organization: 'https://dev.azure.com/${organization}/'" >&2
infoMessage "  Project: '${project}'" >&2
if [ -n "${scJsonResult}" ]
then
    # echo "$scJsonResult"
    scName=$(echo "$scJsonResult" | jq -r '.name')
    vgid=$(az pipelines variable-group list --org "https://dev.azure.com/${organization}/" --project "${project}"  --group-name "${variableGroup}"  | jq -r '.[] | select(.name=="'${variableGroup}'").id')
    if [ -z "${vgid}" ]
    then
        infoMessage "Creating Variables Group..." 
        vgJsonResult=$(az pipelines variable-group create --org "https://dev.azure.com/${organization}/" --project "${project}"  --name "${variableGroup}" --authorize true --variables AZURE_TEST_SUFFIX=evhub"$(shuf -i 1000-9999 -n 1)" AZURE_REGION="${region}" SERVICE_CONNECTION="${scName}" )
    else
        infoMessage "Updating Variables Group..." 
        vgJsonResult=$(az pipelines variable-group variable update --org "https://dev.azure.com/${organization}/" --project "${project}"  --group-id "${vgid}"  --name "AZURE_TEST_SUFFIX" --value "evhub$(shuf -i 1000-9999 -n 1)"  )
        # echo "$vgJsonResult"
        vgJsonResult=$(az pipelines variable-group variable update --org "https://dev.azure.com/${organization}/" --project "${project}"  --group-id "${vgid}"  --name "AZURE_REGION" --value "${region}" )
        # echo "$vgJsonResult"
        vgJsonResult=$(az pipelines variable-group variable update --org "https://dev.azure.com/${organization}/" --project "${project}"  --group-id "${vgid}"  --name "SERVICE_CONNECTION" --value "${scName}" )
        # echo "$vgJsonResult"
    fi
else
    errorMessage "Error while creating Service Connection  sc-${spName}"
    exit 1
fi

infoMessage "Creating Pipeline '${pipelineName}' for:" 
infoMessage "  Organization: 'https://dev.azure.com/${organization}/'" 
infoMessage "  Project: '${project}'" 
if [ -n "${vgJsonResult}" ]
then
     pipelineId=$(az pipelines list  --org "https://dev.azure.com/${organization}/" --project "${project}" --name "${pipelineName}"  | jq -r '.[] | select(.name=="'${pipelineName}'").id')
    if [ -z "${pipelineId}" ]
    then
        infoMessage "Creating Pipeline..." 
        pipelineJsonResult=$(az pipelines create  --org "https://dev.azure.com/${organization}/" --project "${project}" --name "${pipelineName}" --description "${pipelineDescription}" --repository "${repository}" --branch "${pipelineBranch}" --repository-type tfsgit --yml-path ./devops-pipelines/azure-pipelines/azure-pipelines-load-testing-eventhub-restricted-public-access.yml)
    else
        infoMessage "Updating Pipeline..." 
        pipelineJsonResult=$(az pipelines update  --org "https://dev.azure.com/${organization}/" --project "${project}" --id "${pipelineId}" --description "${pipelineDescription}"  --branch "${pipelineBranch}"  --yml-path ./devops-pipelines/azure-pipelines/azure-pipelines-load-testing-eventhub-restricted-public-access.yml)
    fi
    if [ -z "${pipelineJsonResult}" ]
    then
        errorMessage "Error while creating Variable Group:  ${variableGroup}"
        exit 1
    fi    
else
    errorMessage "Error while creating Variable Group:  ${variableGroup}"
    exit 1
fi
infoMessage "Pipeline '${pipelineName}' created." 
