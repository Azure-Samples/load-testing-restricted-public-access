#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script used to install pre-requisites, deploy/undeploy service, start/stop service, test service
#- Parameters are:
#- [-a] ACTION - value: login, install, getsuffix, createconfig, deploy, undeploy, deploytest, undeploytest, opentest, runtest, closetest 
#- [-c] configuration file - which contains the list of path of each load-testing-tool.sh to call (configuration/default.env by default)
#- [-h] event Hub Sku - Event Hub Sku - by default Standard  values: "Basic","Standard","Premium"
#

# executable
###########################################################################################################################################################################################
set -u
#repoRoot="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck disable=SC2034
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../../"
    pwd -P
)
# Read variables in configuration file
SCRIPTS_DIRECTORY=$(dirname "$0")
# shellcheck disable=SC1091
source "$SCRIPTS_DIRECTORY"/../../../scripts/common.sh

#######################################################
#- function used to print out script usage
#######################################################
function usage() {
    echo
    echo "Arguments:"
    echo -e " -a  Sets iactool ACTION {login, install, getsuffix, createconfig, deploy, undeploy, deploytest, undeploytest, opentest, runtest, closetest}"
    echo -e " -c  Sets the iactool configuration file"
    echo -e " -h  Event Hub Sku - Azure Event Hub Sku - by default Standard (Basic, Standard, Premium)"

    echo
    echo "Example:"
    echo -e " bash ./load-testing-tool.sh -a install "
    echo -e " bash ./load-testing-tool.sh -a deploy -c .evhtool.env"
    
}

ACTION=
CONFIGURATION_FILE="$(dirname "${BASH_SOURCE[0]}")/../../configuration/.default.env"
AZURE_RESOURCE_SKU="B1"
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""   
AZURE_REGION="eastus2"
LOAD_TESTING_SECRET_NAME="EVENTHUB-TOKEN"
LOAD_TESTING_DURATION="60"
LOAD_TESTING_THREADS="1"
LOAD_TESTING_ENGINE_INSTANCES="1"
LOAD_TESTING_ERROR_PERCENTAGE="5"
LOAD_TESTING_RESPONSE_TIME="100"
LOAD_TESTING_TEST_NAME="eventhub-restricted-public-access"
# shellcheck disable=SC2034
while getopts "a:c:h:r:" opt; do
    case $opt in
    a) ACTION=$OPTARG ;;
    c) CONFIGURATION_FILE=$OPTARG ;;
    h) AZURE_RESOURCE_SKU=$OPTARG ;;
    r) AZURE_REGION=$OPTARG ;;
    :)
        echo "Error: -${OPTARG} requires a value"
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

# Validation
if [[ $# -eq 0 || -z "${ACTION}" || -z $CONFIGURATION_FILE ]]; then
    echo "Required parameters are missing"
    usage
    exit 1
fi
if [[ ! "${ACTION}" == "login" && ! "${ACTION}" == "install" && ! "${ACTION}" == "createconfig" && ! "${ACTION}" == "getsuffix" \
    && ! "${ACTION}" == "deploy" && ! "${ACTION}" == "undeploy" && ! "${ACTION}" == "opentest" && ! "${ACTION}" == "runtest" \
    && ! "${ACTION}" == "closetest" && ! "${ACTION}" == "deploytest" && ! "${ACTION}" == "undeploytest" ]]; then
    echo "ACTION '${ACTION}' not supported, possible values: login, install, getsuffix, createconfig, deploy, undeploy, deploytest, undeploytes, opentest, runtest, closetest"
    usage
    exit 1
fi
# colors for formatting the output
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
GREEN='\033[1;32m'
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
BLUE='\033[1;34m'
# shellcheck disable=SC2034
NC='\033[0m' # No Color


if [[ "${ACTION}" == "install" ]] ; then
    printMessage "Installing pre-requisite"
    printProgress "Installing azure cli"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    az config set extension.use_dynamic_install=yes_without_prompt
    sudo apt-get -y update
    sudo apt-get -y install  jq
    printMessage "Installing pre-requisites done"
    exit 0
fi
if [[ "${ACTION}" == "login" ]] ; then
    # if configuration file exists read subscription id and tenant id values in the file
    if [[ $CONFIGURATION_FILE ]]; then
        if [ -f "$CONFIGURATION_FILE" ]; then
            readConfigurationFile "$CONFIGURATION_FILE"
        fi
    fi
    printMessage "Login..."
    azLogin
    checkLoginAndSubscription
    printMessage "Login done"
    exit 0
fi

# check if configuration file is set 
if [[ -z $CONFIGURATION_FILE ]]; then
    CONFIGURATION_FILE="$(dirname "${BASH_SOURCE[0]}")/../../../projects/web-app-auth/configuration/.default.env"
fi

# get Azure Subscription and Tenant Id if already connected
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true

# check if configuration file is set 
if [[ -z ${AZURE_SUBSCRIPTION_ID} || -z ${AZURE_TENANT_ID} ]] && [[ ! "${ACTION}" == "install" ]] && [[ ! "${ACTION}" == "login" ]]; then
    printError "Connection to Azure required, launching 'az login'"
    printMessage "Login..."
    azLogin
    checkLoginAndSubscription
    printMessage "Login done"    
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
fi

if [[ "${ACTION}" == "createconfig" ]] ; then
    # Get a suffix available with no conflict with existing Azure resources
    # Get a suffix available with no conflict with existing Azure resources
    printMessage  "Getting a suffix with no conflict with existing resources on Azure..."  
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    if [ -n "${AZURE_SUBSCRIPTION_ID}" ]
    then
        AZURE_TEST_SUFFIX=$(getNewSuffix "${AZURE_SUBSCRIPTION_ID}")
        printMessage "Suffix found AZURE_TEST_SUFFIX: '${AZURE_TEST_SUFFIX}'"
        cat > "$CONFIGURATION_FILE" << EOF
AZURE_REGION="${AZURE_REGION}"
AZURE_TEST_SUFFIX=${AZURE_TEST_SUFFIX}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
EOF
        printMessage "Creation of configuration file '${CONFIGURATION_FILE}' done"
        exit 0
    else
        printError "Connection to Azure required, run 'az login'"
    fi
fi

if [[ "${ACTION}" == "getsuffix" ]] ; then
    # Get a suffix available with no conflict with existing Azure resources
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    if [ -n "${AZURE_SUBSCRIPTION_ID}" ]
    then
        SUFFIX=$(getNewSuffix "${AZURE_SUBSCRIPTION_ID}")
        echo "${SUFFIX}"
    fi
    exit 0
fi

if [[ $CONFIGURATION_FILE ]]; then
    if [ ! -f "$CONFIGURATION_FILE" ]; then
        printError "$CONFIGURATION_FILE does not exist."
        exit 1
    fi
    readConfigurationFile "$CONFIGURATION_FILE"
else
    printWarning "No env. file specified. Using environment variables."
fi



if [[ "${ACTION}" == "deploy" ]] ; then
    printMessage "Deploying the infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    printMessage "Deploy infrastructure subscription: '$AZURE_SUBSCRIPTION_ID' region: '$AZURE_REGION' suffix: '$AZURE_TEST_SUFFIX'"
    printMessage "       Backend: 'Azure EventHubs with restricted public access'"
    # Get Agent IP address
    ip=$(curl -s https://ifconfig.me/ip) || true

    # Get resources names for the infrastructure deployment
    RESOURCE_GROUP=$(getResourceGroupName "${AZURE_TEST_SUFFIX}")

    deployAzureInfrastructure "$AZURE_SUBSCRIPTION_ID" "$AZURE_REGION" "$AZURE_TEST_SUFFIX" "$RESOURCE_GROUP"  \
     "$AZURE_RESOURCE_SKU" "$ip" "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/infrastructure/infrastructure-to-test/arm/global.json" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "RESOURCE_GROUP" "${RESOURCE_GROUP}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUBS_NAMESPACE" "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_INPUT1_NAME" "${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_INPUT2_NAME" "${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME" "${AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_INPUT1_CONSUMER_GROUP" "${AZURE_RESOURCE_EVENTHUB_INPUT1_CONSUMER_GROUP}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_INPUT2_CONSUMER_GROUP" "${AZURE_RESOURCE_EVENTHUB_INPUT2_CONSUMER_GROUP}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_EVENTHUB_OUTPUT1_CONSUMER_GROUP" "${AZURE_RESOURCE_EVENTHUB_OUTPUT1_CONSUMER_GROUP}" 
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_STORAGE_ACCOUNT_NAME" "${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}"   
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_APP_INSIGHTS_NAME" "${AZURE_RESOURCE_APP_INSIGHTS_NAME}"   
    echo "File: ${CONFIGURATION_FILE}"
    cat "${CONFIGURATION_FILE}"
    
    
    printMessage "Assigning Roles 'Azure Event Hubs Data Sender' and 'Azure Event Hubs Data Receiver' on scope Event Hub ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}"
    # Get current user objectId
    printProgress "Get current user objectId"
    UserType="User"
    UserSPMsiPrincipalId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true  
    if [[ -z $UserSPMsiPrincipalId ]]; then
        printProgress "Get current service principal objectId"
        UserType="ServicePrincipal"
        # shellcheck disable=SC2154        
        UserSPMsiPrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null) || true
    fi

    if [[ -n $UserSPMsiPrincipalId ]]; then
        printProgress "Checking role assignment 'Azure Event Hubs Data Sender' between '${UserSPMsiPrincipalId}' and name space '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}'"
        UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.EventHub/namespaces/"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}"/eventhubs/"${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Azure Event Hubs Data Sender") | length')

        if [ "$UserSPMsiRoleAssignmentCount" != "1" ];
        then
            printProgress  "Assigning 'Azure Event Hubs Data Sender' role assignment on scope '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}'..."
            cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${RESOURCE_GROUP}\"/providers/Microsoft.EventHub/namespaces/\"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}\"/eventhubs/\"${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}\" --role \"Azure Event Hubs Data Sender\"  "
            printProgress "$cmd"
            eval "$cmd" >/dev/null
            checkError
        fi


        printProgress "Checking role assignment 'Azure Event Hubs Data Sender' between  '${UserSPMsiPrincipalId}' and name space '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}'"
        UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.EventHub/namespaces/"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}"/eventhubs/"${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Azure Event Hubs Data Sender") | length')

        if [ "$UserSPMsiRoleAssignmentCount" != "1" ];
        then
            printProgress  "Assigning 'Azure Event Hubs Data Sender' role assignment on scope '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}'..."
            cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${RESOURCE_GROUP}\"/providers/Microsoft.EventHub/namespaces/\"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}\"/eventhubs/\"${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}\" --role \"Azure Event Hubs Data Sender\"  "
            printProgress "$cmd"
            eval "$cmd" >/dev/null
            checkError
        fi

        printProgress "Checking role assignment 'Azure Event Hubs Data Receiver' between  '${UserSPMsiPrincipalId}' and name space '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME}'"
        UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.EventHub/namespaces/"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}"/eventhubs/"${AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME}"  2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Azure Event Hubs Data Receiver") | length')

        if [ "$UserSPMsiRoleAssignmentCount" != "1" ];
        then
            printProgress  "Assigning 'Azure Event Hubs Data Receiver' role assignment on scope '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' '${AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME}'..."
            cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${RESOURCE_GROUP}\"/providers/Microsoft.EventHub/namespaces/\"${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}\"/eventhubs/\"${AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME}\" --role \"Azure Event Hubs Data Receiver\"  "
            printProgress "$cmd"
            eval "$cmd" >/dev/null
            checkError
        fi
    fi
    printMessage "Assigning Roles 'Azure Event Hubs Data Sender' and 'Azure Event Hubs Data Receiver' on scope Event Hub done"
    
    printMessage "Deploying the infrastructure done"
    exit 0
fi

if [[ "${ACTION}" == "undeploy" ]] ; then
    printMessage "Undeploying the infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    RESOURCE_GROUP=$(getResourceGroupName "${AZURE_TEST_SUFFIX}")
    undeployAzureInfrastructure "$AZURE_SUBSCRIPTION_ID" "$RESOURCE_GROUP"

    printMessage "Undeploying the infrastructure done"
    exit 0
fi


if [[ "${ACTION}" == "deploytest" ]] ; then
    printMessage "Deploying the Load Testing infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    printMessage "Deploy load testing infrastructure subscription: '$AZURE_SUBSCRIPTION_ID' region: '$AZURE_REGION' suffix: '$AZURE_TEST_SUFFIX'"
    printMessage "       Backend: 'Azure EventHubs with restricted public access'"
    # Get Agent IP address
    ip=$(curl -s https://ifconfig.me/ip) || true

    # Get resources names for the infrastructure deployment
    LOAD_TESTING_RESOURCE_GROUP=$(getLoadTestingResourceGroupName "${AZURE_TEST_SUFFIX}")
    LOAD_TESTING_KEY_VAULT_NAME=$(getKeyVaultResourceName "${AZURE_TEST_SUFFIX}")
    LOAD_TESTING_RESOURCE_NAME=$(getLoadTestingResourceName "${AZURE_TEST_SUFFIX}")

    deployAzureTestInfrastructure "$AZURE_SUBSCRIPTION_ID" "$AZURE_REGION" "$AZURE_TEST_SUFFIX" "$LOAD_TESTING_RESOURCE_GROUP"  \
      "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/infrastructure/load-testing-infrastructure/arm/global.json"  
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_RESOURCE_GROUP" "${LOAD_TESTING_RESOURCE_GROUP}"
    # shellcheck disable=SC2153
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_NAME" "${LOAD_TESTING_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_KEY_VAULT_NAME" "${LOAD_TESTING_KEY_VAULT_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_SECRET_NAME" "${LOAD_TESTING_SECRET_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_DURATION" "${LOAD_TESTING_DURATION}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_THREADS" "${LOAD_TESTING_THREADS}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_ENGINE_INSTANCES" "${LOAD_TESTING_ENGINE_INSTANCES}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_ERROR_PERCENTAGE" "${LOAD_TESTING_ERROR_PERCENTAGE}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_RESPONSE_TIME" "${LOAD_TESTING_RESPONSE_TIME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_TEST_NAME" "${LOAD_TESTING_TEST_NAME}"

    echo "File: ${CONFIGURATION_FILE}"
    cat "${CONFIGURATION_FILE}"

    printMessage "Waiting 30 seconds before assigning Roles..."
    sleep 30 

    printMessage "Assigning Roles 'Network Contributor' for current user or service principal on scope Virtual Network ${LOAD_TESTING_VNET_NAME}"
    # Get current user objectId
    printProgress "Get current user objectId"
    UserType="User"
    PRINCIPAL_ID=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true  
    if [[ -z $PRINCIPAL_ID ]]; then
        printProgress "Get current service principal objectId"
        UserType="ServicePrincipal"
        # shellcheck disable=SC2153
        PRINCIPAL_ID=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null) || true
    fi

    printProgress "Checking role assignment 'Network Contributor' between '${PRINCIPAL_ID}' and VNET '${LOAD_TESTING_VNET_NAME}'"
    RoleAssignmentCount=$(az role assignment list --assignee "${PRINCIPAL_ID}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${LOAD_TESTING_RESOURCE_GROUP}"/providers/Microsoft.Network/virtualNetworks/"${LOAD_TESTING_VNET_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Network Contributor") | length')
    if [ "$RoleAssignmentCount" != "1" ];
    then
        printProgress "Assigning 'Network Contributor' role assignment on scope VNET '${LOAD_TESTING_VNET_NAME}'..."
        #cmd="az role assignment create --assignee-object-id \"${PRINCIPAL_ID}\" --assignee-principal-type '${UserType}' --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${LOAD_TESTING_RESOURCE_GROUP}\"/providers/Microsoft.Network/virtualNetworks/\"${LOAD_TESTING_VNET_NAME}\" --role \"Network Contributor\"  2>/dev/null"
        cmd="az role assignment create --assignee-object-id \"${PRINCIPAL_ID}\" --assignee-principal-type '${UserType}' --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${LOAD_TESTING_RESOURCE_GROUP}\"/providers/Microsoft.Network/virtualNetworks/\"${LOAD_TESTING_VNET_NAME}\" --role \"Network Contributor\"  "
        printProgress "$cmd"
        eval "$cmd" >/dev/null
        checkError
    fi

    printMessage "Assigning Roles 'Load Test Contributor' for current user or service principal on scope Load Test ${LOAD_TESTING_NAME}"
    printProgress "Checking role assignment 'Load Test Contributor' between '${PRINCIPAL_ID}' and LOAD TEST '${LOAD_TESTING_NAME}'"
    RoleAssignmentCount=$(az role assignment list --assignee "${PRINCIPAL_ID}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${LOAD_TESTING_RESOURCE_GROUP}"/providers/Microsoft.LoadTestService/loadTests/"${LOAD_TESTING_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Load Test Contributor") | length')
    if [ "$RoleAssignmentCount" != "1" ];
    then
        printProgress "Assigning 'Load Test Contributor' role assignment on scope LOAD TEST '${LOAD_TESTING_NAME}'..."
        cmd="az role assignment create --assignee-object-id \"${PRINCIPAL_ID}\" --assignee-principal-type '${UserType}' --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${LOAD_TESTING_RESOURCE_GROUP}\"/providers/Microsoft.LoadTestService/loadTests/\"${LOAD_TESTING_NAME}\" --role \"Load Test Contributor\"  2>/dev/null"
        printProgress "$cmd"
        eval "$cmd" >/dev/null
        checkError
    fi

    LOAD_TESTING_PRINCIPAL_ID=$(az resource list -n  "${LOAD_TESTING_NAME}" -g "${LOAD_TESTING_RESOURCE_GROUP}" | jq '.[0].identity.principalId' | tr -d '"')
    if [ -z "${LOAD_TESTING_PRINCIPAL_ID}" ] || [ "${LOAD_TESTING_PRINCIPAL_ID}" == "null" ];
    then
        echo "Principal Id not found for Load Test resource: '${LOAD_TESTING_NAME}'"
        exit 1
    fi
    printMessage "Assigning Roles 'Key Vault Secrets Officer' for current user or service principal on scope key vault  ${LOAD_TESTING_KEY_VAULT_NAME}"
    printProgress "Checking role assignment 'Key Vault Secrets Officer' between '${PRINCIPAL_ID}' and KEY VAULT '${LOAD_TESTING_KEY_VAULT_NAME}'"
    RoleAssignmentCount=$(az role assignment list --assignee "${PRINCIPAL_ID}" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${LOAD_TESTING_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${LOAD_TESTING_KEY_VAULT_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Key Vault Secrets Officer") | length')
    if [ "$RoleAssignmentCount" != "1" ];
    then
        printProgress "Assigning 'Key Vault Secrets Officer' role assignment on scope KEY VAULT '${LOAD_TESTING_KEY_VAULT_NAME}'..."
        cmd="az role assignment create --assignee-object-id \"${PRINCIPAL_ID}\" --assignee-principal-type '${UserType}' --scope \"/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${LOAD_TESTING_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${LOAD_TESTING_KEY_VAULT_NAME}\" --role \"Key Vault Secrets Officer\"  "
        printProgress "$cmd"
        eval "$cmd" >/dev/null
        checkError
    fi

    printMessage "Assigning Roles 'Key Vault Secrets User' for load test managed identity  on scope key vault  ${LOAD_TESTING_KEY_VAULT_NAME}"
    printProgress "Checking role assignment 'Key Vault Secrets User' between Load Test PrincipalId '${LOAD_TESTING_PRINCIPAL_ID}' and KEY VAULT '${LOAD_TESTING_KEY_VAULT_NAME}'"
    RoleAssignmentCount=$(az role assignment list --assignee "${LOAD_TESTING_PRINCIPAL_ID}" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${LOAD_TESTING_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${LOAD_TESTING_KEY_VAULT_NAME}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Key Vault Secrets User") | length')
    if [ "$RoleAssignmentCount" != "1" ];
    then
        printProgress "Assigning 'Key Vault Secrets User' role assignment for Load Test PrincipalId  on scope KEY VAULT '${LOAD_TESTING_KEY_VAULT_NAME}'..."
        cmd="az role assignment create --assignee-object-id \"${LOAD_TESTING_PRINCIPAL_ID}\" --assignee-principal-type 'ServicePrincipal' --scope \"/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${LOAD_TESTING_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${LOAD_TESTING_KEY_VAULT_NAME}\" --role \"Key Vault Secrets User\"  "
        printProgress "$cmd"
        eval "$cmd" >/dev/null
        checkError
    fi

    printMessage "Assigning Roles 'Network Contributor'  on scope VNET done"
    printMessage "Assigning Roles 'Load Test Contributor' on scope load testing done"
    printMessage "Assigning Roles 'Key Vault Secrets User' and 'Key Vault Secrets Officer' on scope key vault done"
    printMessage "Deploying the load testing infrastructure done"
    exit 0
fi

if [[ "${ACTION}" == "undeploytest" ]] ; then
    printMessage "Undeploying the load testing infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    LOAD_TESTING_RESOURCE_GROUP=$(getLoadTestingResourceGroupName "${AZURE_TEST_SUFFIX}")
    undeployAzureTestInfrastructure "$AZURE_SUBSCRIPTION_ID" "$LOAD_TESTING_RESOURCE_GROUP"

    printMessage "Undeploying the infrastructure done"
    exit 0
fi

if [[ "${ACTION}" == "runtest" ]] ; then
    printMessage "Running the load test..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    for i in $(ls -d ./projects/web-app-auth/scenarios/*/); 
    do 
        LOAD_TESTING_SCENARIO=$(basename ${i%%/})
        printProgress "Checking whether scenario '${LOAD_TESTING_SCENARIO}' is valid with all the required files..."  
        checkScenario ${i%%/}
        printProgress "Launching Load Testing for scenario '${LOAD_TESTING_SCENARIO}'..."  

        printProgress "Getting Load Testing token..."  
        az config set extension.use_dynamic_install=yes_without_prompt  
        LOAD_TESTING_RESOURCE_GROUP=$(getLoadTestingResourceGroupName "${AZURE_TEST_SUFFIX}")
        LOAD_TESTING_RESOURCE_NAME=$(getLoadTestingResourceName "${AZURE_TEST_SUFFIX}")
        cmd="az load  show --name ${LOAD_TESTING_RESOURCE_NAME} --resource-group ${LOAD_TESTING_RESOURCE_GROUP}"
        printProgress "$cmd"
        LOAD_TESTING_HOSTNAME=$(az load  show --name "${LOAD_TESTING_RESOURCE_NAME}" --resource-group "${LOAD_TESTING_RESOURCE_GROUP}" | jq -r ".dataPlaneURI")
        LOAD_TESTING_TOKEN=$(az account get-access-token --resource "${LOAD_TESTING_HOSTNAME}" --scope "https://cnt-prod.loadtesting.azure.com/.default" | jq -r '.accessToken')
        # echo "LOAD_TESTING_TOKEN: $LOAD_TESTING_TOKEN"
        LOAD_TESTING_TEST_ID=$(cat /proc/sys/kernel/random/uuid)

        printProgress ""
        printProgress "Creating/Updating test ${LOAD_TESTING_TEST_NAME} ID:${LOAD_TESTING_TEST_ID}..."    
        # Update Load Testing configuration file
        TEMP_DIR=$(mktemp -d)
        cp  "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/load-testing.template.json"  "$TEMP_DIR/load-testing.json"
        sed -i "s/{name}/${LOAD_TESTING_TEST_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{engineInstances}/${LOAD_TESTING_ENGINE_INSTANCES}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{errorPercentage}/${LOAD_TESTING_ERROR_PERCENTAGE}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{responseTimeMs}/${LOAD_TESTING_RESPONSE_TIME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{loadTestSecretName}/eventhub_token/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{keyVaultSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{eventhubNameSpace}/${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{eventhubInput1}/${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{eventhubInput2}/${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{subnetId}/${LOAD_TESTING_SUBNET_ID////\\/}/g" "$TEMP_DIR/load-testing.json"

        #echo "$TEMP_DIR/load-testing.json content:"
        #cat "$TEMP_DIR/load-testing.json"

        cmd="curl -s -X PATCH \
        \"https://$LOAD_TESTING_HOSTNAME/tests/$LOAD_TESTING_TEST_ID?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer $LOAD_TESTING_TOKEN' \
        -d \"@$TEMP_DIR/load-testing.json\" "
        # echo "$cmd"
        eval "$cmd" >/dev/null
    
        printProgress ""
        printProgress "Uploading load-testing.jmx for test ${LOAD_TESTING_TEST_NAME}..."    
        cmd="curl -s -X PUT \
        \"https://${LOAD_TESTING_HOSTNAME}/tests/${LOAD_TESTING_TEST_ID}/files/load-testing.jmx?fileType=JMX_FILE&api-version=2022-11-01\" \
        -H 'Content-Type: application/octet-stream' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
        --data-binary  \"@$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/load-testing.jmx\" "
        # echo "$cmd"
        eval "$cmd" >/dev/null


        for i in $(ls -d ./projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/*.csv);
        do 
            LOAD_TESTING_DATA_FILE=$(basename ${i%%/})
            printProgress "Uploading ${LOAD_TESTING_DATA_FILE} for test ${LOAD_TESTING_TEST_NAME}..."    
            cmd="curl -s -X PUT \
            \"https://${LOAD_TESTING_HOSTNAME}/tests/${LOAD_TESTING_TEST_ID}/files/${LOAD_TESTING_DATA_FILE}?fileType=ADDITIONAL_ARTIFACTS&api-version=2022-11-01\" \
            -H 'Content-Type: application/octet-stream' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
            --data-binary  \"@$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/${LOAD_TESTING_DATA_FILE}\" "
            # echo "$cmd"
            eval "$cmd" >/dev/null
        done 



        printProgress "Waiting the validation of the jmx file for test  ${LOAD_TESTING_TEST_NAME}..."    
        statuscmd="curl -s -X GET \
        \"https://${LOAD_TESTING_HOSTNAME}/tests/${LOAD_TESTING_TEST_ID}/files/load-testing.jmx?fileType=JMX_FILE&api-version=2022-11-01\" \
        -H 'Content-Type: application/octet-stream' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' "
        # echo "$statuscmd" 
        JMX_STATUS="unknown"
        while [ "${JMX_STATUS}" != "VALIDATION_FAILURE" ] && [ "${JMX_STATUS}" != "VALIDATION_SUCCESS" ] && [ "${JMX_STATUS}" != "VALIDATION_NOT_REQUIRED" ] && [ "${JMX_STATUS}" != "null" ]
        do
            sleep 10
            JMX_STATUS=$(eval "$statuscmd" | jq -r '.validationStatus')
            printProgress "Current JMX status: ${JMX_STATUS}" 
        done

        if [[ $JMX_STATUS == "VALIDATION_FAILURE" ]]; then
            printError "Validation of the jmx file for test  '${LOAD_TESTING_TEST_NAME}' failed."
            exit 1
        fi


        printProgress "Store the EventHub token in the Azure Key Vault for test ${LOAD_TESTING_RESOURCE_NAME}..."    
        key=$(az eventhubs namespace authorization-rule keys list --resource-group "${RESOURCE_GROUP}" --namespace-name "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" --name RootManageSharedAccessKey | jq -r .primaryKey)
        EVENTHUB_TOKEN=$("$SCRIPTS_DIRECTORY/../../../scripts/get-event-hub-token.sh" "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" RootManageSharedAccessKey "$key")
        cmd="az keyvault secret set --vault-name \"${LOAD_TESTING_KEY_VAULT_NAME}\" --name \"${LOAD_TESTING_SECRET_NAME}\" --value \"${EVENTHUB_TOKEN}\" --output none"
        # echo "$cmd"
        eval "${cmd}"
        checkError

        printProgress ""
        LOAD_TESTING_TEST_RUN_ID=$(cat /proc/sys/kernel/random/uuid)
        printProgress "Launching test ${LOAD_TESTING_TEST_NAME} RunID:${LOAD_TESTING_TEST_RUN_ID}..."    
        # Update Load Testing configuration file
        LOAD_TESTING_DATE=$(date +"%y%m%d-%H%M%S")
        TEMP_DIR=$(mktemp -d)
        cp  "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/load-testing-run.template.json"  "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{name}/${LOAD_TESTING_TEST_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{id}/${LOAD_TESTING_TEST_ID}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{date}/${LOAD_TESTING_DATE}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{engineInstances}/${LOAD_TESTING_ENGINE_INSTANCES}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{errorPercentage}/${LOAD_TESTING_ERROR_PERCENTAGE}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{responseTimeMs}/${LOAD_TESTING_RESPONSE_TIME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{loadTestSecretName}/eventhub_token/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{keyVaultSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{eventhubNameSpace}/${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{eventhubInput1}/${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{eventhubInput2}/${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{subnetId}/${LOAD_TESTING_SUBNET_ID////\\/}/g" "$TEMP_DIR/load-testing-run.json"

        # Wait 10 seconds to be sure the JMX file is validated
        sleep 10

        cmd="curl -s -X PATCH  \
        \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
        -d \"@$TEMP_DIR/load-testing-run.json\" "
        # echo "$cmd"
        eval "$cmd"  >/dev/null


        printProgress "Waiting the end of the test run ${LOAD_TESTING_TEST_RUN_ID}..."    
        statuscmd="curl -s -X GET \
        \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' "
        # echo "$statuscmd"
        LOAD_TESTING_STATUS="unknown"
        while [ "${LOAD_TESTING_STATUS}" != "DONE" ] && [ "${LOAD_TESTING_STATUS}" != "FAILED" ] && [ "${LOAD_TESTING_STATUS}" != "null" ]
        do
            sleep 10
            LOAD_TESTING_STATUS=$(eval "$statuscmd" | jq -r '.status')
            printProgress "Current status: ${LOAD_TESTING_STATUS}" 
        done

        # echo "$statuscmd"
        LOAD_TESTING_RESULT=$(eval "$statuscmd" | jq -r '.testResult')
        if [ "${LOAD_TESTING_STATUS}" == "FAILED" ] || [ "${LOAD_TESTING_STATUS}" == "null" ]
        then
            printError "Running load testing failed"
        else
            printMessage "Running load testing successful"
        fi

        if [ "${LOAD_TESTING_STATUS}" == "DONE" ] 
        then
            printMessage "Waiting for the results..."
            LOAD_TESTING_RESULT="NOT_APPLICABLE"
            while [ "${LOAD_TESTING_RESULT}" == "NOT_APPLICABLE" ] 
            do
                sleep 10
                LOAD_TESTING_RESULT=$(eval "$statuscmd" | jq -r '.testResult')
                printProgress "Current results status: ${LOAD_TESTING_RESULT}" 
            done
            # Renewing the token
            LOAD_TESTING_TOKEN=$(az account get-access-token --resource "${LOAD_TESTING_HOSTNAME}" --scope "https://cnt-prod.loadtesting.azure.com/.default" | jq -r '.accessToken')
            statuscmd="curl -s -X GET \
            \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
            -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' "
            LOAD_TESTING_RESULT=$(eval "$statuscmd")
            # printMessage "Result: $LOAD_TESTING_RESULT"
            LOAD_TESTING_STATISTICS=$(echo "${LOAD_TESTING_RESULT}" | jq -r '.testRunStatistics')
            LOAD_TESTING_RESULTS_CSV_URL=$(echo "${LOAD_TESTING_RESULT}" | jq -r '.testArtifacts.outputArtifacts.resultFileInfo.url')
            LOAD_TESTING_RESULTS_CSV_FILE=$(echo "${LOAD_TESTING_RESULT}" | jq -r '.testArtifacts.outputArtifacts.resultFileInfo.fileName')
            LOAD_TESTING_RESULTS_LOGS_URL=$(echo "${LOAD_TESTING_RESULT}" | jq -r '.testArtifacts.outputArtifacts.logsFileInfo.url')
            LOAD_TESTING_RESULTS_LOGS_FILE=$(echo "${LOAD_TESTING_RESULT}" | jq -r '.testArtifacts.outputArtifacts.logsFileInfo.fileName')

            if [[ ! -z "${LOAD_TESTING_RESULTS_CSV_FILE}"  && "${LOAD_TESTING_RESULTS_CSV_FILE}" != "null" ]]
            then
                printProgress "Downloading CSV file: ${LOAD_TESTING_RESULTS_CSV_FILE}..."    
                downloadcmd="curl -s -X GET \"${LOAD_TESTING_RESULTS_CSV_URL}\" --output \"${LOAD_TESTING_RESULTS_CSV_FILE}\""
                # echo ${downloadcmd}
                $(eval "$downloadcmd")
                unzip -o "${LOAD_TESTING_RESULTS_CSV_FILE}" 
                INDEX=1
                while (( INDEX <= LOAD_TESTING_ENGINE_INSTANCES )); do     
                    echo "Result file for engine ${INDEX}: engine${INDEX}_results.csv"
                    # Uncomment the line below if you want to display the results for each engine in the stdout
                    # cat engine${INDEX}_results.csv
                    (( INDEX++ ))
                done 
            else
                printWarning "Result zip file not available through the Azure Load Testing REST API" 
                echo "statuscmd: ${statuscmd}"
                echo "LOAD_TESTING_RESULT: ${LOAD_TESTING_RESULT}"
            fi

            if [[ ! -z "${LOAD_TESTING_RESULTS_LOGS_FILE}"  && "${LOAD_TESTING_RESULTS_LOGS_FILE}" != "null" ]]
            then
                printProgress "Downloading Logs file: ${LOAD_TESTING_RESULTS_LOGS_FILE}..."    
                downloadcmd="curl -s -X GET \"${LOAD_TESTING_RESULTS_LOGS_URL}\" --output \"${LOAD_TESTING_RESULTS_LOGS_FILE}\""
                # echo ${downloadcmd}
                $(eval "$downloadcmd")
            else
                printWarning "Logs zip file not available through the Azure Load Testing REST API" 
                echo "statuscmd: ${statuscmd}"
                echo "LOAD_TESTING_RESULT: ${LOAD_TESTING_RESULT}"
            fi
            
            printMessage "Running load testing successful"
            #printMessage "Result: $LOAD_TESTING_RESULT"
            printMessage "Statistics: $LOAD_TESTING_STATISTICS"  
            exit 0
        fi
    done
fi

if [[ "${ACTION}" == "opentest" ]] ; then
    printMessage "Opening access to Eventhub and Keyvault..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    readConfigurationFile "$CONFIGURATION_FILE"

    printProgress "Open access to EventHubs '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' access for the load testing resource with public ip: ${LOAD_TESTING_PUBLIC_IP_ADDRESS}..."    
    if [[ -n ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} ]]; then
        if [[ -n $(az eventhubs namespace show --name "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" --resource-group "${RESOURCE_GROUP}" 2>/dev/null| jq -r .id) ]]; then
            if [[ -n ${LOAD_TESTING_PUBLIC_IP_ADDRESS} ]]; then
                cmd="az eventhubs namespace network-rule-set list  --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} | jq -r '.[].ipRules[]  |  select(.ipMask==\"${LOAD_TESTING_PUBLIC_IP_ADDRESS}\") ' | jq --slurp '.[0].action' | tr -d '\"'"
                # echo "cmd=${cmd}"
                ALLOW=$(eval "${cmd}")
                if [ ! "${ALLOW}" == "Allow" ]  
                then
                    # Get Agent IP address
                    ip=$(curl -s https://ifconfig.me/ip) || true
                    #cmd="az eventhubs namespace network-rule-set create --ip-rules '[{\"action\":\"Allow\",\"ipMask\":\"${LOAD_TESTING_PUBLIC_IP_ADDRESS}\"}]' --public-network-access 'SecuredByPerimeter' --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} "
                    cmd="az eventhubs namespace network-rule-set update --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} --default-action Deny --public-network Enabled --ip-rules \"[{ip-mask:${ip},action:Allow},{ip-mask:${LOAD_TESTING_PUBLIC_IP_ADDRESS},action:Allow}]\"  "
                    # echo "$cmd"
                    eval "${cmd}" >/dev/null
                    checkError
                    # Wait 30 seconds for the access to the eventhubs
                    sleep 30
                fi
            fi
        fi
    fi

    printProgress "Open access to Key Vault '${LOAD_TESTING_KEY_VAULT_NAME}' for the test..."    
    cmd="az keyvault update --default-action Allow --name ${LOAD_TESTING_KEY_VAULT_NAME} -g ${LOAD_TESTING_RESOURCE_GROUP}"
    # echo "$cmd"
    eval "${cmd}" >/dev/null
    checkError
    printMessage "Eventhub and Keyvault are now accessible from Azure Load Testing"

    exit 0
fi

if [[ "${ACTION}" == "closetest" ]] ; then
    printMessage "Closing access to Eventhub and Keyvault..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    readConfigurationFile "$CONFIGURATION_FILE"

    printProgress "Close access to Key Vault '${LOAD_TESTING_KEY_VAULT_NAME}' for the test..."    
    cmd="az keyvault update --default-action Deny --name ${LOAD_TESTING_KEY_VAULT_NAME} -g ${LOAD_TESTING_RESOURCE_GROUP}"
    # echo "$cmd"
    eval "${cmd}" >/dev/null
    checkError

    printProgress "Close access to EventHubs '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' access for the load testing resource with pubic ip: ${LOAD_TESTING_PUBLIC_IP_ADDRESS}..."    
    if [[ -n ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} ]]; then
        if [[ -n $(az eventhubs namespace show --name "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" --resource-group "${RESOURCE_GROUP}" 2>/dev/null| jq -r .id) ]]; then
            if [[ -n ${LOAD_TESTING_PUBLIC_IP_ADDRESS} ]]; then
                # Get Agent IP address
                ip=$(curl -s https://ifconfig.me/ip) || true
                cmd="az eventhubs namespace network-rule-set update --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} --default-action Deny --public-network Enabled --ip-rules '[{ip-mask:${ip},action:Allow}]'  "
                # echo "$cmd"
                eval "${cmd}" >/dev/null
                checkError
            fi
        fi
    fi
    printMessage "Eventhub and Keyvault are no more accessible from Azure Load Testing"

    exit 0
fi
