#!/bin/bash
#
# executable
#

##############################################################################
# colors for formatting the output
##############################################################################
# shellcheck disable=SC2034
{
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
}
##############################################################################
#- function used to check whether an error occurred
##############################################################################
function checkError() {
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occurred exiting from the current bash${NC}"
        exit 1
    fi
}

##############################################################################
#- print functions
##############################################################################
function printMessage(){
    echo -e "${GREEN}$1${NC}" 
}
function printWarning(){
    echo -e "${YELLOW}$1${NC}" 
}
function printError(){
    echo -e "${RED}$1${NC}" 
}
function printProgress(){
    echo -e "${BLUE}$1${NC}" 
}
##############################################################################
#- azure Login 
##############################################################################
function azLogin() {
    # Check if current process's user is logged on Azure
    # If no, then triggers az login
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        printError "Variable AZURE_SUBSCRIPTION_ID not set"
        az login
        # get Azure Subscription and Tenant Id if already connected
        AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
        AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true        
    fi
    if [ -z "$AZURE_TENANT_ID" ]; then
        printError "Variable AZURE_TENANT_ID not set"
        az login
        # get Azure Subscription and Tenant Id if already connected
        AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
        AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true        
    fi
    azOk=true
    az account set -s "$AZURE_SUBSCRIPTION_ID" 2>/dev/null || azOk=false
    if [[ ${azOk} == false ]]; then
        printWarning "Need to az login"
        az login --tenant "$AZURE_TENANT_ID"
    fi

    azOk=true
    az account set -s "$AZURE_SUBSCRIPTION_ID"   || azOk=false
    if [[ ${azOk} == false ]]; then
        echo -e "unknown error"
        exit 1
    fi
}
##############################################################################
#- checkLoginAndSubscription 
##############################################################################
function checkLoginAndSubscription() {
    az account show -o none
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo -e "\nYou seems disconnected from Azure, running 'az login'."
        az login -o none
    fi
    CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
    if [[ -z "$AZURE_SUBSCRIPTION_ID"  || "$AZURE_SUBSCRIPTION_ID" != "$CURRENT_SUBSCRIPTION_ID" ]]; then
        # query subscriptions
        echo -e "\nYou have access to the following subscriptions:"
        az account list --query '[].{name:name,"subscription Id":id}' --output table

        echo -e "\nYour current subscription is:"
        az account show --query '[name,id]'
        # shellcheck disable=SC2154
        if [[ ${silentmode} == false || -z "$CURRENT_SUBSCRIPTION_ID" ]]; then        
            echo -e "
            You will need to use a subscription with permissions for creating service principals (owner role provides this).
            If you want to change to a different subscription, enter the name or id.
            Or just press enter to continue with the current subscription."
            read -r -p ">> " SUBSCRIPTION_ID

            if ! test -z "$SUBSCRIPTION_ID"
            then 
                az account set -s "$SUBSCRIPTION_ID"
                echo -e "\nNow using:"
                az account show --query '[name,id]'
                CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
            fi
        fi
    fi
}
##############################################################################
#- getResourceGroupName
##############################################################################
function getResourceGroupName(){
    suffix=$1
    echo "rg${suffix}"
}
##############################################################################
#- getLoadTestingResourceGroupName
##############################################################################
function getLoadTestingResourceGroupName(){
    suffix=$1
    echo "rgldtest${suffix}"
}
##############################################################################
#- getLoadTestingResourceName
##############################################################################
function getLoadTestingResourceName(){
    suffix=$1
    echo "ldtest${suffix}"
}
##############################################################################
#- getEventHubsResourceName
##############################################################################
function getEventHubsResourceName(){
    suffix=$1
    echo "evh${suffix}"
}
##############################################################################
#- getStorageAccountResourceName
##############################################################################
function getStorageAccountResourceName(){
    suffix=$1
    echo "sa${suffix}"
}
##############################################################################
#- getKeyVaultResourceName
##############################################################################
function getKeyVaultResourceName(){
    suffix=$1
    echo "kv${suffix}"
}

##############################################################################
#- isEventHubsNameAvailable
##############################################################################
function isEventHubsNameAvailable(){
    rg=$1
    name=$2
    # check if already exists in resource group
    if [[ $(az eventhubs namespace list --resource-group "${rg}" --query "[?name=='${name}'] | length(@)"  2>/dev/null ) -gt 0 ]]
    then
        echo "true"
    else
        # check if already exists outside of resource group
        if [[ $(az eventhubs namespace exists --name "${name}" | jq -r '.nameAvailable'  2>/dev/null) == "false" ]]
        then
            echo "false"
        else
            echo "true"
        fi
    fi    
}
##############################################################################
#- isStorageAccountNameAvailable
##############################################################################
function isStorageAccountNameAvailable(){
    rg=$1
    name=$2
    # check if already exists in resource group
    if [[ $(az storage account list --resource-group "${rg}" --query "[?name=='${name}'] | length(@)"  2>/dev/null ) -gt 0 ]]
    then
        echo "true"
    else
        # check if already exists outside of resource group
        if [[ $(az storage account check-name --name "${name}" | jq -r '.nameAvailable'  2>/dev/null) == "false" ]]
        then
            echo "false"
        else
            echo "true"
        fi
    fi    
}
##############################################################################
#- isKeyVaultNameAvailable
##############################################################################
function isKeyVaultNameAvailable(){
    subscription=$1
    rg=$2
    name=$3
    # check if already exists in resource group
    if [[ $(az keyvault list --resource-group "${rg}" --query "[?name=='${name}'] | length(@)"  2>/dev/null ) -gt 0 ]]
    then
        echo "true"
    else
        # check if already exists outside of resource group
        if [[ $(az rest --method post --uri "https://management.azure.com/subscriptions/${subscription}/providers/Microsoft.KeyVault/checkNameAvailability?api-version=2019-09-01" --headers "Content-Type=application/json" --body "{\"name\": \"${name}\",\"type\": \"Microsoft.KeyVault/vaults\"}" 2>/dev/null | jq -r ".nameAvailable"  2>/dev/null) == "false" ]]        
        then
            echo "false"
        else
            echo "true"
        fi
    fi  
}

##############################################################################
#- getNewSuffix
##############################################################################
function getNewSuffix(){
    subscription=$1
    checkname="false"
    while [ ${checkname} == "false" ]
    do
        suffix="evhub$(shuf -i 1000-9999 -n 1)"
        RESOURCE_GROUP=$(getResourceGroupName "${suffix}")
        LOAD_TESTING_RESOURCE_GROUP=$(getLoadTestingResourceGroupName "${suffix}")
        STORAGE_ACCOUNT_NAME=$(getStorageAccountResourceName "${suffix}")
        EVENT_HUB_NAME=$(getEventHubsResourceName "${suffix}")
        KEY_VAULT_NAME=$(getKeyVaultResourceName "${suffix}")
        checkname="false"
        if [ "$(isStorageAccountNameAvailable "${RESOURCE_GROUP}" "${STORAGE_ACCOUNT_NAME}" )" == "false" ]
        then
            continue
        fi
        if [ "$(isEventHubsNameAvailable "${RESOURCE_GROUP}" "${EVENT_HUB_NAME}" )" == "false" ]
        then
            continue
        fi
        if [ "$(isKeyVaultNameAvailable "${subscription}" "${LOAD_TESTING_RESOURCE_GROUP}" "${KEY_VAULT_NAME}" )" == "false" ]
        then
            continue
        fi
        echo "${suffix}"
        checkname="true"
    done
}

##############################################################################
#- deployAzureInfrastructure
##############################################################################
function deployAzureInfrastructure(){
    subscription=$1
    region=$2
    suffix=$3
    resourcegroup=$4
    sku=$5
    ip=$6
    template=$7

    datadep=$(date +"%y%m%d-%H%M%S")
    
    cmd="az group create  --subscription $subscription --location $region --name $resourcegroup --output none "
    printProgress "$cmd"
    eval "$cmd"
    checkError

    cmd="az deployment group create \
        --name $datadep \
        --resource-group $resourcegroup \
        --subscription $subscription \
        --template-file $template \
        --output none \
        --parameters \
        suffix=$suffix  sku=$sku ipAddress=\"$ip\""

    printProgress "$cmd"
    eval "$cmd"
    checkError
    
    # Initialize the environment variables from the infrastructure deployment
    getDeploymentVariables "${resourcegroup}" "${datadep}"
}
##############################################################################
#- getDeploymentVariables
##############################################################################
function getDeploymentVariables(){
    resourcegroup="$1"

    response=$(az group exists --resource-group "$resourcegroup")
    if [ "$response" == "true" ]; then
        if [[ ! $# -ge 2 ]]; then
            datadep=$(getDeploymentName "$AZURE_SUBSCRIPTION_ID" "$resourcegroup" 'storageAccountName')
        else
            if [ -z "$2" ]; then
                datadep=$(getDeploymentName "$AZURE_SUBSCRIPTION_ID" "$resourcegroup" 'storageAccountName')
            else
                datadep="$2"
            fi
        fi
        printProgress "Getting variables from deployment Name: ${datadep} from resource group ${resourcegroup}"
        for i in $(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq  '.properties.outputs' | jq -r 'keys' | jq -r '.[]'); 
        do 
            if [[ "${i^^}" == AZURE_RESOURCE_* ]]; 
            then 
                VARIABLE=$(echo "${i}" | tr a-z A-Z)
                cmd="az deployment group show --resource-group \"${resourcegroup}\" -n \"${datadep}\" | jq -r '.properties.outputs.\"${i}\".value'"
                VALUE=$(eval "${cmd}")
                printProgress "${VARIABLE}=${VALUE}"
                export ${VARIABLE}=${VALUE}
            fi;
        done;

        # printProgress "Getting variables from deployment Name: ${datadep} from resource group ${resourcegroup}"
        # APP_INSIGHTS_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsName.value')
        # APP_INSIGHTS_CONNECTION_STRING=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsConnectionString.value')    
        # APP_INSIGHTS_INSTRUMENTATION_KEY=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsInstrumentationKey.value')    

        # STORAGE_ACCOUNT_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.storageAccountName.value')
        # STORAGE_ACCOUNT_TOKEN=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.storageAccountToken.value')
        # STORAGE_ACCOUNT_INPUT_CONTAINER=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.inputContainerName.value')
        # STORAGE_ACCOUNT_OUTPUT_CONTAINER=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputContainerName.value')

        # EVENTHUB_NAME_SPACE=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.namespaceName.value')
        # EVENTHUB_INPUT_1_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput1Name.value')
        # EVENTHUB_INPUT_2_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput2Name.value')
        # EVENTHUB_OUTPUT_1_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubOutput1Name.value')
        # EVENTHUB_OUTPUT_1_CONSUMER_GROUP_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubOutput1ConsumerGroup.value')
        # EVENTHUB_INPUT_1_CONSUMER_GROUP_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput1ConsumerGroup.value')
        # EVENTHUB_INPUT_2_CONSUMER_GROUP_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput2ConsumerGroup.value')

        RESOURCE_GROUP=$resourcegroup
    else
        printProgress "Getting variables from deployment, Resource group ${resourcegroup} doesn't exist"
        # APP_INSIGHTS_NAME=""
        # APP_INSIGHTS_CONNECTION_STRING=""
        # APP_INSIGHTS_INSTRUMENTATION_KEY=""
        # EVENTHUB_NAME_SPACE=""
        # EVENTHUB_INPUT_1_NAME=""
        # EVENTHUB_INPUT_2_NAME=""
        # EVENTHUB_OUTPUT_1_NAME=""
        # EVENTHUB_OUTPUT_1_CONSUMER_GROUP_NAME=""
        # EVENTHUB_INPUT_1_CONSUMER_GROUP_NAME=""
        # EVENTHUB_INPUT_2_CONSUMER_GROUP_NAME=""

        RESOURCE_GROUP=$resourcegroup
    fi
}


##############################################################################
#- undeployAzureInfrastructure
##############################################################################
function undeployAzureInfrastructure(){
    subscription=$1
    resourcegroup=$2

    cmd="az group delete  --subscription $subscription  --name $resourcegroup -y --output none "
    printProgress "$cmd"
    eval "$cmd"
}
##############################################################################
#- undeployAzureTestInfrastructure
##############################################################################
function undeployAzureTestInfrastructure(){
    subscription=$1
    resourcegroup=$2

    cmd="az group delete  --subscription $subscription  --name $resourcegroup -y --output none "
    printProgress "$cmd"
    eval "$cmd"
}
##############################################################################
#- deployAzureTestInfrastructure
##############################################################################
function deployAzureTestInfrastructure(){
    subscription=$1
    region=$2
    suffix=$3
    resourcegroup=$4
    loadtestname=$5
    akvname=$6
    template=$7

    datadep=$(date +"%y%m%d-%H%M%S")
    
    cmd="az group create  --subscription $subscription --location $region --name $resourcegroup --output none "
    printProgress "$cmd"
    eval "$cmd"
    checkError

    cmd="az deployment group create \
        --name $datadep \
        --resource-group $resourcegroup \
        --subscription $subscription \
        --template-file $template \
        --output none \
        --parameters \
        suffix=$suffix loadTestName=$loadtestname akvName=$akvname location=$region tags='{\"Environment\":\"Dev\",\"Project\":\"load-testing-eventhub-restricted-public-access\"}' "

    printProgress "$cmd"
    eval "$cmd"
    checkError

    # Initialize the environment variables from the infrastructure deployment
    getTestDeploymentVariables "${resourcegroup}" "${datadep}"   
}
##############################################################################
#- getTestDeploymentVariables
##############################################################################
function getTestDeploymentVariables(){
    resourcegroup="$1"

    response=$(az group exists --resource-group "$resourcegroup")
    if [ "$response" == "true" ]; then
        if [[ ! $# -ge 2 ]]; then
            datadep=$(getDeploymentName "$AZURE_SUBSCRIPTION_ID" "$resourcegroup" 'keyVaultName')
        else
            if [ -z "$2" ]; then
                datadep=$(getDeploymentName "$AZURE_SUBSCRIPTION_ID" "$resourcegroup" 'keyVaultName')
            else
                datadep="$2"
            fi
        fi
        printProgress "Getting variables from deployment Name: ${datadep} from resource group ${resourcegroup}"
        for i in $(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq  '.properties.outputs' | jq -r 'keys' | jq -r '.[]'); 
        do 
            if [[ "${i^^}" == AZURE_RESOURCE_* ]]; 
            then 
                VARIABLE=$(echo "${i}" | tr a-z A-Z)
                cmd="az deployment group show --resource-group \"${resourcegroup}\" -n \"${datadep}\" | jq -r '.properties.outputs.\"${i}\".value'"
                VALUE=$(eval "${cmd}")
                printProgress "${VARIABLE}=${VALUE}"
                export ${VARIABLE}=${VALUE}
            fi;
        done;

        # LOAD_TESTING_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.loadTestName.value')
        # LOAD_TESTING_KEY_VAULT_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.keyVaultName.value')
        # LOAD_TESTING_NAT_GATEWAY_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.natGatewayName.value')
        # LOAD_TESTING_PIP_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.publicIPAddressName.value')
        # LOAD_TESTING_VNET_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.vnetName.value')
        # LOAD_TESTING_SUBNET_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.subnetName.value')
        # LOAD_TESTING_PUBLIC_IP_ADDRESS=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.publicIPAddress.value')
        # LOAD_TESTING_SUBNET_ID=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.subnetId.value')
       
        LOAD_TESTING_RESOURCE_GROUP=$resourcegroup
    else
        printProgress "Getting variables from deployment, Resource group ${resourcegroup} doesn't exist"
        # LOAD_TESTING_NAME=""
        # LOAD_TESTING_KEY_VAULT_NAME=""
        # LOAD_TESTING_NAT_GATEWAY_NAME=""
        # LOAD_TESTING_PIP_NAME=""
        # LOAD_TESTING_VNET_NAME=""
        # LOAD_TESTING_SUBNET_NAME=""
        # LOAD_TESTING_PUBLIC_IP_ADDRESS=""
        # LOAD_TESTING_SUBNET_ID=""
       
        LOAD_TESTING_RESOURCE_GROUP=$resourcegroup
    fi
}
##############################################################################
#- getDeploymentName: get latest deployment Name for resource group
#  arg 1: Azure Subscription
#  arg 2: Resource Group
#  arg 3: Output variable to support
##############################################################################
function getDeploymentName(){
    subscription="$1"
    resource_group="$2"
    output_variable="$3"
    cmd="az deployment group list -g  ${resource_group} --subscription ${subscription} --output json"
    #echo "$cmd"
    result=$(eval "$cmd")
    cmd="echo '$result' | jq -r 'length'"
    count=$(eval "$cmd")
    if [ -n "$count" ] ; then
        #echo "COUNT: $count"
        # shellcheck disable=SC2004
        for ((index=0;index<=(${count}-1);index++ ))
        do
            cmd="echo '$result' | jq -r '.[${index}].name'"
            name=$(eval "$cmd")
            #echo "name: $name"
            cmd="az deployment group show --resource-group ${resource_group} -n ${name} --subscription ${subscription} | jq -r '.properties.outputs.${output_variable}.value'"
            value=$(eval "$cmd")
            #echo "value: $value"
            if [[ -n "$value" ]]; then
                if [[ "$value" != "null" ]]; then
                    echo "${name}"
                    return
                fi
            fi
        done
    fi               
}

##############################################################################
#- updateConfigurationFile: Update configuration file
#  arg 1: Configuration file path
#  arg 2: Variable Name
#  arg 3: Value
##############################################################################
function updateConfigurationFile(){
    configFile="$1"
    variable="$2"
    value="$3"

    count=$(grep "${variable}=.*" -c < "$configFile") || true
    if [ "${count}" == 1 ]; then
        sed -i "s/${variable}=.*/${variable}=${value////\\/}/g" "${configFile}" 
    elif [ "${count}" == 0 ]; then
        echo "${variable}=${value}" >> "${configFile}"
    fi
}
##############################################################################
#- readConfigurationFile: Update configuration file
#  arg 1: Configuration file path
##############################################################################
function readConfigurationFile(){
    file="$1"

    set -o allexport
    # shellcheck disable=SC1090
    source "$file"
    set +o allexport
}
##############################################################################
#- checkScenario: Check whether the folder contains all the files required to  
#                 run load testing.
#  arg 1: Scenario path
##############################################################################
function checkScenario(){
    DIRECTORY="$1"
    FILE="${DIRECTORY}/load-testing.template.json"
    if [ ! -f "${FILE}" ]; then
        printError "Load Testing template file ${FILE} doesn't exists."
        exit 1
    fi
    FILE="${DIRECTORY}/load-testing-run.template.json"
    if [ ! -f "${FILE}" ]; then
        printError "Load Testing run template file ${FILE} doesn't exists."
        exit 1
    fi
    FILE="${DIRECTORY}/load-testing.jmx"
    if [ ! -f "${FILE}" ]; then
        printError "Load Testing JMX file ${FILE} doesn't exists."
        exit 1
    fi
}