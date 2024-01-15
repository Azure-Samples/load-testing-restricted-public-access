#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script is used to create users in the Test Tenant. You need to be connected as Tenant Admin to run this script 
#- Parameters are:
#- [-t] tenant - The subscription where the resources will reside.
#- [-s] scope - The scope associated with the multi-tenant application.
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
    infoMessage " -a  Sets the action 'create' or 'delete'"
    infoMessage " -t  Sets the tenant id of the test tenant"
    infoMessage " -s  Sets the scope of the multi-tenant application"
    infoMessage " -p  Sets the user name prefix: by default: 'automationtest' "
    infoMessage " -c  Sets the users count (maximum value 10): by default: '5'  "
    infoMessage
    infoMessage "Example:"
    infoMessage " create-users.sh -a create -t b5c9fc83-fbd0-4368-9cb6-1b5823479b6a -s https://fdpo.onmicrosoft.com/d3c5dde6-2a9e-4e96-b09f-9340bbcbcadf/user_impersonation -p automationtest -c 8"
}
AZURE_AUTOMATION_USER_PREFIX="automationtest"
AZURE_USERS_COUNT=5
AZURE_TENANT=
AZURE_SCOPE=
ACTION=
while getopts ":a:t:s:p:c:" opt; do
    case $opt in
    a) ACTION=$OPTARG ;;
    t) AZURE_TENANT=$OPTARG ;;
    s) AZURE_SCOPE=$OPTARG ;;
    c) AZURE_USERS_COUNT=$OPTARG ;;    
    p) AZURE_AUTOMATION_USER_PREFIX=$OPTARG ;;    
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

# Validation
if [[ $# -eq 0 || -z $ACTION || -z $AZURE_TENANT || ( -z $AZURE_SCOPE && $ACTION == "create" ) ]]; then
    errorMessage "Required parameters are missing"
    usage
    exit 1
fi

if [[ ! "${ACTION}" == "create" && ! "${ACTION}" == "delete"  ]]; then
    errorMessage "ACTION '${ACTION}' not supported, possible values: create, delete"
    usage
    exit 1
fi

re='^[0-9]+$'
if ! [[ ${AZURE_USERS_COUNT} =~ ${re} ]] ; then
    errorMessage "Users count value '${AZURE_USERS_COUNT}' is not a number"
    usage
    exit 1
fi

if (( AZURE_USERS_COUNT > 10 )) ; then
    errorMessage "Users count value '${AZURE_USERS_COUNT}' is over 10"
    usage
    exit 1
fi

checkError() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occurred in  bash${NC}"
        exit 1
    fi
}
# get Azure Subscription and Tenant Id if already connected
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true

# check if configuration file is set 
if [[ -z ${AZURE_SUBSCRIPTION_ID} || -z ${AZURE_TENANT_ID} || ${AZURE_TENANT_ID} != ${AZURE_TENANT} ]]; then
    az login --allow-no-subscriptions -t ${AZURE_TENANT}
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
fi
AZURE_TENANT_DNS=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query 'value[?isDefault].id' -o tsv)

if [[ "${ACTION}" == "create" ]] ; then
    infoMessage "Creating ${AZURE_USERS_COUNT} users with prefix '${AZURE_AUTOMATION_USER_PREFIX}' in Microsoft Entra ID Tenant: ${AZURE_TENANT_DNS} " 
    COUNTER=1
    AZURE_AD_TOKENS=""
    LOAD_TESTING_USERS_CONFIGURATION_VALUE="'["
    while (( COUNTER <= AZURE_USERS_COUNT ))
    do     
        infoMessage "Creating user ${COUNTER} ${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}"
        PASSWORD=$(tr -dc 'A-Za-z0-9!#%&()*+,-.:;<=>?@[\]^_{}~' </dev/urandom | head -c 13; echo)
        cmd="az ad user create --display-name \"${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}\" --password \"${PASSWORD}\" --user-principal-name \"${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}\""
        eval "${cmd}" || true
        if [ $? -ne 0 ]; then
            errorMessage "The creation of user '${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}' failed. Command: ${cmd}"
        fi
        ITEM="{\"adu\":\"${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}\",\"pw\":\"${PASSWORD}\",\"sco\":\"${AZURE_SCOPE}\",\"clid\":\"04b07795-8ddb-461a-bbee-02f9e1bf7b46\",\"tid\":\"${AZURE_TENANT}\"}"
        # echo "ITEM: ${ITEM}"
        if [[ COUNTER -eq 1 ]]; then
            LOAD_TESTING_USERS_CONFIGURATION_VALUE="${LOAD_TESTING_USERS_CONFIGURATION_VALUE}${ITEM}"
        else
            LOAD_TESTING_USERS_CONFIGURATION_VALUE="${LOAD_TESTING_USERS_CONFIGURATION_VALUE},${ITEM}"
        fi    
        (( COUNTER++ ))
    done  
    LOAD_TESTING_USERS_CONFIGURATION_VALUE="${LOAD_TESTING_USERS_CONFIGURATION_VALUE}]'"
    infoMessage "Value of the variable LOAD_TESTING_USERS_CONFIGURATION: "  
    echo "${LOAD_TESTING_USERS_CONFIGURATION_VALUE}"
    infoMessage "Creation done"
fi
if [[ "${ACTION}" == "delete" ]] ; then
    infoMessage "Deleting ${AZURE_USERS_COUNT} users with prefix '${AZURE_AUTOMATION_USER_PREFIX}' from Microsoft Entra ID Tenant: ${AZURE_TENANT_DNS} " 
    COUNTER=1
    AZURE_AD_TOKENS=""
    LOAD_TESTING_USERS_CONFIGURATION_VALUE="'["
    while (( COUNTER <= AZURE_USERS_COUNT ))
    do     
        infoMessage "Deleting user ${COUNTER} ${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}"
        cmd="az ad user delete --id  \"${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}\""
        eval "${cmd}" || true
        if [ $? -ne 0 ]; then
            errorMessage "The creation of user '${AZURE_AUTOMATION_USER_PREFIX}${COUNTER}@${AZURE_TENANT_DNS}' failed. Command: ${cmd}"
        fi
        (( COUNTER++ ))
    done  
    infoMessage "Deletion done"
fi
