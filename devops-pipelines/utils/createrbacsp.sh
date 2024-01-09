#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script is used to deploy the Lorentz service
#- Parameters are:
#- [-s] subscription - The subscription where the resources will reside.
#- [-a] serviceprincipalName - The service principal name to create.
#- [-v] verbose - Verbose mode will display details while creating the service principal.
###########################################################################################################################################################################################
set -eu
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)
cd "$parent_path"
# colors for formatting the output
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
verboseMessage()
{
    if [ ${verbose} -eq 1 ]
    then
        printf "${YELLOW}%s${NC}\n" "$*" >&2;
    fi
}
errorMessage()
{
    printf "${RED}%s${NC}\n" "$*" >&2;
}
infoMessage()
{
    printf "${BLUE}%s${NC}\n" "$*" >&2;
}
#######################################################
#- function used to print out script usage
#######################################################
function usage() {
    infoMessage
    infoMessage "Arguments:"
    infoMessage " -s  Sets the subscription"
    infoMessage " -a  Sets the service principal name (required)"
    infoMessage " -v  Sets the verbose mode (disable by default)"
    infoMessage
    infoMessage "Example:"
    infoMessage " bash create-rbac-sp.sh -s b5c9fc83-fbd0-4368-9cb6-1b5823479b6a -a testazdosp "
}
subscription=
appName=
verbose=0
while getopts ":s:a:v" opt; do
    case $opt in
    s) subscription=$OPTARG ;;
    a) appName=$OPTARG ;;
    v) verbose=1 ;;
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
if [[ $# -eq 0 || -z $subscription || -z $appName ]]; then
    errorMessage "Required parameters are missing"
    usage
    exit 1
fi


checkError() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occurred in create-rbac-sp.sh bash${NC}"
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

verboseMessage "Creating Service Principal for:" 
verboseMessage "Service Principal Name: $appName" 
verboseMessage "Subscription: $subscription" 
az account set --subscription "$subscription" >/dev/null
checkError

tenantId=$(az account show --query tenantId -o tsv)
verboseMessage "TenantId : $tenantId" >&2
spjson=$(az ad sp create-for-rbac --sdk-auth true --skip-assignment true --name "https://$appName"  -o json --only-show-errors )

appId=$(echo "$spjson" | jq -r .clientId)
# appSecret=$(echo "$spjson" | jq -r .clientSecret)
# principalId=$(az ad sp show --id "$appId" --query "id" --output tsv --only-show-errors)

verboseMessage "Assign role \"Owner\" to service principal"
az role assignment create --assignee "$appId"  --role "Owner"  --only-show-errors 1> /dev/null 
checkError

verboseMessage "Assign role \"Load Test Contributor\" to service principal"   
az role assignment create --assignee "$appId"  --role "Load Test Contributor"  --only-show-errors 1> /dev/null 
checkError

verboseMessage "Information for the creation of Github Action Secret AZURE_CREDENTIALS:"  >&2
echo "$spjson"

