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
    prefix=$1
    subscription=$2
    checkname="false"
    while [ ${checkname} == "false" ]
    do
        suffix="${prefix}$(shuf -i 1000-9999 -n 1)"
        RESOURCE_GROUP=$(getResourceGroupName "${suffix}")
        LOAD_TESTING_RESOURCE_GROUP=$(getLoadTestingResourceGroupName "${suffix}")
        AZURE_RESOURCE_STORAGE_ACCOUNT_NAME=$(getStorageAccountResourceName "${suffix}")
        AZURE_RESOURCE_EVENTHUBS_NAMESPACE=$(getEventHubsResourceName "${suffix}")
        LOAD_TESTING_KEY_VAULT_NAME=$(getKeyVaultResourceName "${suffix}")
        checkname="false"
        if [ "$(isStorageAccountNameAvailable "${RESOURCE_GROUP}" "${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}" )" == "false" ]
        then
            continue
        fi
        if [ "$(isEventHubsNameAvailable "${RESOURCE_GROUP}" "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" )" == "false" ]
        then
            continue
        fi
        if [ "$(isKeyVaultNameAvailable "${subscription}" "${LOAD_TESTING_RESOURCE_GROUP}" "${LOAD_TESTING_KEY_VAULT_NAME}" )" == "false" ]
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
        # AZURE_RESOURCE_APP_INSIGHTS_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsName.value')
        # APP_INSIGHTS_CONNECTION_STRING=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsConnectionString.value')    
        # APP_INSIGHTS_INSTRUMENTATION_KEY=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputAppInsightsInstrumentationKey.value')    

        # AZURE_RESOURCE_STORAGE_ACCOUNT_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.storageAccountName.value')
        # STORAGE_ACCOUNT_TOKEN=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.storageAccountToken.value')
        # STORAGE_ACCOUNT_INPUT_CONTAINER=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.inputContainerName.value')
        # STORAGE_ACCOUNT_OUTPUT_CONTAINER=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.outputContainerName.value')

        # AZURE_RESOURCE_EVENTHUBS_NAMESPACE=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.namespaceName.value')
        # AZURE_RESOURCE_EVENTHUB_INPUT1_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput1Name.value')
        # AZURE_RESOURCE_EVENTHUB_INPUT2_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput2Name.value')
        # AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubOutput1Name.value')
        # AZURE_RESOURCE_EVENTHUB_OUTPUT1_CONSUMER_GROUP=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubOutput1ConsumerGroup.value')
        # AZURE_RESOURCE_EVENTHUB_INPUT1_CONSUMER_GROUP=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput1ConsumerGroup.value')
        # AZURE_RESOURCE_EVENTHUB_INPUT2_CONSUMER_GROUP=$(az deployment group show --resource-group "$resourcegroup" -n "$datadep" | jq -r '.properties.outputs.eventHubInput2ConsumerGroup.value')

        RESOURCE_GROUP=$resourcegroup
    else
        printProgress "Getting variables from deployment, Resource group ${resourcegroup} doesn't exist"
        # AZURE_RESOURCE_APP_INSIGHTS_NAME=""
        # APP_INSIGHTS_CONNECTION_STRING=""
        # APP_INSIGHTS_INSTRUMENTATION_KEY=""
        # AZURE_RESOURCE_EVENTHUBS_NAMESPACE=""
        # AZURE_RESOURCE_EVENTHUB_INPUT1_NAME=""
        # AZURE_RESOURCE_EVENTHUB_INPUT2_NAME=""
        # AZURE_RESOURCE_EVENTHUB_OUTPUT1_NAME=""
        # AZURE_RESOURCE_EVENTHUB_OUTPUT1_CONSUMER_GROUP=""
        # AZURE_RESOURCE_EVENTHUB_INPUT1_CONSUMER_GROUP=""
        # AZURE_RESOURCE_EVENTHUB_INPUT2_CONSUMER_GROUP=""

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
    template=$5

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
        suffix=$suffix location=$region tags='{\"Environment\":\"Dev\",\"Project\":\"load-testing\"}' "

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
            if [[ "${i^^}" == LOAD_TESTING_* ]]; 
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
    if [ "${count}" != 0 ]; then
        ESCAPED_REPLACE=$(printf '%s\n' "${value}" | sed -e 's/[\/&]/\\&/g')
        sed -i "s/${variable}=.*/${variable}=${ESCAPED_REPLACE}/g" "${configFile}"         
    elif [ "${count}" == 0 ]; then
        if [[ $(tail -c1 "${configFile}" | wc -l) -eq 0 ]]; then
            echo "" >> "${configFile}"
        fi
        echo "${variable}=${value}" >> "${configFile}"
    fi
}
##############################################################################
#- readConfigurationFileValue: Read one value in  configuration file
#  arg 1: Configuration file path
#  arg 2: Variable Name
##############################################################################
function readConfigurationFileValue(){
    configFile="$1"
    variable="$2"

    grep "${variable}=*"  < "${configFile}" | head -n 1 | sed "s/${variable}=//g"
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
    FILE_TEMPLATE="${DIRECTORY}/load-testing.template.jmx"
    if [[ ! -f "${FILE}" && ! -f "${FILE_TEMPLATE}" ]]; then
        printError "Load Testing JMX file ${FILE} nor Load Testing Template JMX file ${FILE} don't exists."
        exit 1
    fi
}
##############################################################################
#- buildWebAppContainer
##############################################################################
function buildWebAppContainer() {
    ContainerRegistryName="${1}"
    targetDirectory="$2"
    imageName="$3"
    imageTag="$4"
    imageLatestTag="$5"
    portHttp="$6"

    if [ ! -d "$targetDirectory" ]; then
            echo "Directory '$targetDirectory' does not exist."
            exit 1
    fi

    echo "Building and uploading the docker image for '$targetDirectory'"

    # Navigate to API module folder
    # shellcheck disable=SC2164
    pushd "$targetDirectory" > /dev/null

    # Build the image
    echo "Building the docker image for '$imageName:$imageTag'"
    cmd="az acr build --registry $ContainerRegistryName --resource-group ${RESOURCE_GROUP} --image ${imageName}:${imageTag} --image ${imageName}:${imageLatestTag} -f Dockerfile --build-arg APP_VERSION=${imageTag} --build-arg ARG_PORT_HTTP=${portHttp} --build-arg ARG_APP_ENVIRONMENT=\"Production\" . --only-show-errors 2> /dev/null"
    #cmd="az acr build --registry $ContainerRegistryName --resource-group ${RESOURCE_GROUP} --image ${imageName}:${imageTag} --image ${imageName}:${imageLatestTag} -f Dockerfile --build-arg APP_VERSION=${imageTag} --build-arg ARG_PORT_HTTP=${portHttp} --build-arg ARG_APP_ENVIRONMENT=\"Development\" . --only-show-errors 2> /dev/null"
    printProgress "$cmd"
    eval "$cmd"

    # shellcheck disable=SC2164
    popd > /dev/null

}
##############################################################################
#- deployWebAppContainer
##############################################################################
function deployWebAppContainer(){
    SUBSCRIPTION_ID="$1"
    prefix="$2"
    appType="$3"
    webapp="$4"
    ContainerRegistryUrl="$5"
    ContainerRegistryName="$6"
    imageName="$7"
    imageTag="$8"
    appVersion="$9"
    portHTTP="${10}"

    resourcegroup="rg${prefix}"

    # When deployed, WebApps get automatically a managed identity. Ensuring this MSI has AcrPull rights
    printProgress  "Ensure ${webapp} has AcrPull role assignment on ${ContainerRegistryName}..."
    WebAppMsiPrincipalId=$(az "${appType}" show -n "$webapp" -g "$resourcegroup" -o json --only-show-errors  2> /dev/null | jq -r .identity.principalId)
    WebAppMsiAcrPullAssignmentCount=$(az role assignment list --assignee "$WebAppMsiPrincipalId" --scope /subscriptions/"${SUBSCRIPTION_ID}"/resourceGroups/"${resourcegroup}"/providers/Microsoft.ContainerRegistry/registries/"${ContainerRegistryName}" 2> /dev/null | jq -r 'select(.[].roleDefinitionName=="AcrPull") | length')

    if [ "$WebAppMsiAcrPullAssignmentCount" != "1" ];
    then
        printProgress  "Assigning AcrPull role assignment on scope ${ContainerRegistryName}..."
        az role assignment create --assignee-object-id "$WebAppMsiPrincipalId" --assignee-principal-type ServicePrincipal --scope /subscriptions/"${SUBSCRIPTION_ID}"/resourceGroups/"${resourcegroup}"/providers/Microsoft.ContainerRegistry/registries/"${ContainerRegistryName}" --role "AcrPull" 2> /dev/null
    fi

    printProgress  "Check if WebApp ${webapp} use Managed Identity for the access to ACR ${ContainerRegistryName}..."
    WebAppAcrConfigAcrEnabled=$(az resource show --ids /subscriptions/"${SUBSCRIPTION_ID}"/resourceGroups/"${resourcegroup}"/providers/Microsoft.Web/sites/"${webapp}"/config/web 2> /dev/null | jq -r ".properties.acrUseManagedIdentityCreds")
    if [ "$WebAppAcrConfigAcrEnabled" = false ];
    then
        printProgress "Enabling Acr on ${webapp}..."
        az resource update --ids /subscriptions/"${SUBSCRIPTION_ID}"/resourceGroups/"${resourcegroup}"/providers/Microsoft.Web/sites/"${webapp}"/config/web --set properties.acrUseManagedIdentityCreds=True 2> /dev/null
    fi


    printProgress "Create Containers"
    FX_Version="Docker|$ContainerRegistryUrl/$imageName:$imageTag"

    #Configure the ACR, Image and Tag to pull
    cmd="az resource update --ids /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${resourcegroup}/providers/Microsoft.Web/sites/${webapp}/config/web --set properties.linuxFxVersion=\"$FX_Version\" -o none --force-string"
    printProgress "$cmd"
    eval "$cmd"

    printProgress "Create Config"
    if [ "${appType}" == "webapp" ];
    then 
    cmd="az ${appType} config appsettings set -g \"$resourcegroup\" -n \"$webapp\" \
    --settings WEBSITES_PORT=8080 APP_VERSION=${appVersion} PORT_HTTP=${portHTTP} --only-show-errors --output none"
    else
    cmd="az ${appType} config appsettings set -g \"$resourcegroup\" -n \"$webapp\" \
    --settings APP_VERSION=${appVersion} PORT_HTTP=${portHTTP} --only-show-errors --output none"
    fi
    printProgress "$cmd"
    eval "$cmd"
}
##############################################################################
#- getLatestImageVersion: get latest image version
#  arg 1: ACR Name
#  arg 2: image Name
##############################################################################
function getLatestImageVersion(){
    acr="$1"
    image="$2"
    #cmd="az acr repository show-manifests --name ${acr} --repository ${image} --output json"
    cmd="az acr manifest list-metadata -r ${acr} -n ${image} --output json 2> /dev/null"
    #echo "$cmd"
    result=$(eval "$cmd")
    cmd="echo '$result' | jq -r 'length'"
    count=$(eval "$cmd")
    if [ -n "$count" ] ; then
        #echo "COUNT: $count"
        # shellcheck disable=SC2004
        for ((index=0;index<=((${count}-1));index++ ))
        do
            cmd="echo '$result' | jq -r '.[${index}].tags' | jq -r 'length' "
            count_tags=$(eval "$cmd")
            #echo "count_tags: $count_tags"
            # shellcheck disable=SC2004
            for ((index_tag=0;index_tag<=((${count_tags}-1));index_tag++ ))
            do
                cmd="echo '$result' | jq -r '.[${index}].tags[${index_tag}]' "
                tag=$(eval "$cmd")
                if [ "$tag" == 'latest' ]; then
                    if [ $index_tag -ge 1 ]; then
                        cmd="echo '$result' | jq -r '.[${index}].tags[0]' "
                        version=$(eval "$cmd")
                        echo "${version}"
                        return
                    fi
                fi
            done
        done
    fi               
}
##############################################################################
#- check is Url is ready returning 200
##############################################################################
function checkWebUrl() {
    httpCode="404"
    apiUrl="$1"
    expectedResponse="$2"
    timeOut="$3"
    response=""
    count=0
    while [[ "$httpCode" != "200" ]] || [[ ! "${response}" =~ .*"${expectedResponse}".* ]] && [[ $count -lt ${timeOut} ]]
    do
        SECONDS=0
        httpCode=$(curl -s -o /dev/null -L -w '%{http_code}' "$apiUrl") || true
        if [[ $httpCode == "200" ]]; then
            response=$(curl -s  "$apiUrl") || true
            response=${response//\"/}
        fi
        #echo "count=${count} code: ${httpCode} response: ${response} "
        sleep 10
        ((count=count+SECONDS))
    done
    #echo "httpcode: ${httpCode}"
    #echo "response: ${response}"
    #echo "expectedResponse: ${expectedResponse}"
    if [[ $httpCode == "200" ]] && [[ "${response}" =~ .*"${expectedResponse}".* ]]; then
        echo "true"
        return
    fi
    echo "false"
    return
}
##############################################################################
#- url encode of a string 
#  arg 1: string to encode
##############################################################################
urlEncode()
{
    local S="${1}"
    local encoded=""
    local ch
    local o
    for i in $(seq 0 $((${#S} - 1)) )
    do
        ch=${S:$i:1}
        case "${ch}" in
            [-_.~a-zA-Z0-9]) 
                o="${ch}"
                ;;
            *) 
                o=$(printf '%%%02x' "'$ch")                
                ;;
        esac
        encoded="${encoded}${o}"
    done
    echo ${encoded}
}
##############################################################################
#- Get Application Name 
#  arg 1: Suffix
##############################################################################
getApplicationName()
{
    if [[ -z $1 ]] ; then
        echo ""
    else
        echo "sp-$1-app"
    fi
}
##############################################################################
#- Create an Application in Microsoft Entra ID Tenant 
#  arg 1: Suffix
#  arg 2: Web App Url (redirect Uri)
##############################################################################
createApplication()
{
    local suffix=$1
    local webAppUrl=$2
    local appId=""
    local appName=$(getApplicationName "${suffix}")
    cmd="az ad app list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].appId"
    # printProgress "$cmd"
    appId=$(eval "$cmd")
    checkError   
    if [[ -z ${appId} || ${appId} == 'null' ]] ; then
        # Create application 
        # printProgress "Create Application '${appName}' "        
        cmd="az ad app create  --display-name \"${appName}\"  --required-resource-access \"[{\\\"resourceAppId\\\": \\\"00000003-0000-0000-c000-000000000000\\\",\\\"resourceAccess\\\": [{\\\"id\\\": \\\"e1fe6dd8-ba31-4d61-89e7-88639da4683d\\\",\\\"type\\\": \\\"Scope\\\"}]},{\\\"resourceAppId\\\": \\\"e406a681-f3d4-42a8-90b6-c2b029497af1\\\",\\\"resourceAccess\\\": [{\\\"id\\\": \\\"03e0da56-190b-40ad-a80c-ea378c433f7f\\\",\\\"type\\\": \\\"Scope\\\"}]}]\" --only-show-errors | jq -r \".appId\" "
        # printProgress "$cmd"
        appId=$(eval "$cmd")
        checkError   
        # wait 30 seconds
        # printProgress "Wait 30 seconds after app creation"
        # Wait few seconds before updating the Application record in Azure AD
        sleep 30
        # Get application objectId  
        cmd="az ad app list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].id"    
        # printProgress "$cmd"
        objectId=$(eval "$cmd")     
        checkError   
        if [[ -n ${objectId} && ${objectId} != 'null' ]] ; then
            # printProgress "Update Application '${appName}' in Microsoft Graph "   
            # Azure CLI Application Id : 04b07795-8ddb-461a-bbee-02f9e1bf7b46 
            # Azure CLI will be authorized to get access token to the API using the commands below:
            #  token=$(az account get-access-token --resource https://<TenantDNSName>/<WebAPIAppId> | jq -r .accessToken)
            #  curl -i -X GET --header "Authorization: Bearer $token"  https://<<WebAPIDomain>/visit
            TENANT_DNS_NAME=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query 'value[?isDefault].id' -o tsv)
            cmd="az rest --method PATCH --uri \"https://graph.microsoft.com/v1.0/applications/${objectId}\" \
                --headers \"Content-Type=application/json\" \
                --body \"{\\\"api\\\":{\\\"oauth2PermissionScopes\\\":[{\\\"id\\\": \\\"1619f87e-396b-48f1-91cf-9dedd9c786c8\\\",\\\"adminConsentDescription\\\": \\\"Grants full access to Visit web services APIs\\\",\\\"adminConsentDisplayName\\\": \\\"Full access to Visit API\\\",\\\"userConsentDescription\\\": \\\"Grants full access to Visit web services APIs\\\",\\\"userConsentDisplayName\\\": null,\\\"isEnabled\\\": true,\\\"type\\\": \\\"User\\\",\\\"value\\\": \\\"user_impersonation\\\"}]},\\\"spa\\\":{\\\"redirectUris\\\":[\\\"${webAppUrl}\\\"]},\\\"identifierUris\\\":[\\\"https://${TENANT_DNS_NAME}/${appId}\\\"]}\""
            # printProgress "$cmd"
            local azRestResult=$(eval "$cmd")
            checkError   
            # Wait few seconds before updating the Application record in Azure AD 
            sleep 10
            cmd="az rest --method PATCH --uri \"https://graph.microsoft.com/v1.0/applications/${objectId}\" \
                --headers \"Content-Type=application/json\" \
                --body \"{\\\"api\\\":{\\\"preAuthorizedApplications\\\": [{\\\"appId\\\": \\\"04b07795-8ddb-461a-bbee-02f9e1bf7b46\\\",\\\"delegatedPermissionIds\\\": [\\\"1619f87e-396b-48f1-91cf-9dedd9c786c8\\\"]}]}}\""
            # printProgress "$cmd"
            local azRestResult=$(eval "$cmd")
            checkError   
        else
            printError "Error while creating application ${appName} can't get objectId"
            exit 1
        fi
        cmd="az ad app list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].appId"
        # printProgress "$cmd"
        appId=$(eval "$cmd")     
        checkError   
        if [[ -n ${appId} && ${appId} != 'null' ]] ; then
            # printProgress "Create Service principal associated with application '${appName}' "        
            cmd="az ad sp create-for-rbac --name '${appName}'  --role contributor --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} --only-show-errors"        
            # printProgress "$cmd"
            local spResult=$(eval "$cmd")
            checkError   
        fi 
        # printProgress  "Application '${appName}' with application Id: ${appId} and object Id: ${objectId} has been created"
    else
        # printProgress  "Application '${appName}' with application Id: ${appId} already exists"
        # printProgress  "Update application '${appName}' with the new redirectUri ${webAppUrl}"
        # Get application objectId  
        cmd="az ad app list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].id"    
        # printProgress "$cmd"
        objectId=$(eval "$cmd")    
        checkError   
        if [[ -n ${objectId} && ${objectId} != 'null' ]] ; then
            # printProgress "Update Application '${appName}' in Microsoft Graph "   
            # Azure CLI Application Id : 04b07795-8ddb-461a-bbee-02f9e1bf7b46 
            # Azure CLI will be authorized to get access token to the API using the commands below:
            #  token=$(az account get-access-token --resource https://<TenantDNSName>/<WebAPIAppId> | jq -r .accessToken)
            #  curl -i -X GET --header "Authorization: Bearer $token"  https://<<WebAPIDomain>/visit
            TENANT_DNS_NAME=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query 'value[?isDefault].id' -o tsv)
            cmd="az rest --method PATCH --uri \"https://graph.microsoft.com/v1.0/applications/$objectId\" \
                --headers \"Content-Type=application/json\" \
                --body \"{\\\"api\\\":{\\\"oauth2PermissionScopes\\\":[{\\\"id\\\": \\\"1619f87e-396b-48f1-91cf-9dedd9c786c8\\\",\\\"adminConsentDescription\\\": \\\"Grants full access to Visit web services APIs\\\",\\\"adminConsentDisplayName\\\": \\\"Full access to Visit API\\\",\\\"userConsentDescription\\\": \\\"Grants full access to Visit web services APIs\\\",\\\"userConsentDisplayName\\\": null,\\\"isEnabled\\\": true,\\\"type\\\": \\\"User\\\",\\\"value\\\": \\\"user_impersonation\\\"}]},\\\"spa\\\":{\\\"redirectUris\\\":[\\\"${webAppUrl}\\\"]},\\\"identifierUris\\\":[\\\"https://${TENANT_DNS_NAME}/${appId}\\\"]}\""
            # printProgress "$cmd"
            local azRestResult=$(eval "$cmd")
            checkError   
        fi
    fi
    echo "${appId}"
}
##############################################################################
#- Check if string is a GUID 
#  arg 1: string
##############################################################################
isGuid()
{
    local uuid=$1
    if [[ $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
        echo "true"
    else
        echo "false"
    fi
}

##############################################################################
#- Assign Storage Role to an Application 
#  arg 1: application Id
#  arg 2: Role
#  arg 3: Subscription
#  arg 4: ResourceGroup
#  arg 5: Storage Account Name
##############################################################################
assignStorageRole()
{
    local appId=$1
    local role=$2
    local subscriptionId=$3
    local resourceGroup=$4
    local storageAccountName=$5
    printProgress  "Check 'Storage Blob Data Contributor' role assignment on scope ${storageAccountName} for ApplicationId ${appId}..."
    cmd="az role assignment list --assignee \"${appId}\" --scope /subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Storage/storageAccounts/${storageAccountName} --only-show-errors  | jq -r 'select(.[].roleDefinitionName==\"Storage Blob Data Contributor\") | length'"
    printProgress "$cmd"
    assignmentCount=$(eval "$cmd") || true  
    if [ "${assignmentCount}" != "1" ];
    then
        printProgress  "Assigning 'Storage Blob Data Contributor' role assignment on scope ${storageAccountName} for  appId..."
        cmd="az role assignment create --assignee \"${appId}\"  --scope /subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Storage/storageAccounts/${storageAccountName} --role \"Storage Blob Data Contributor\" --only-show-errors"        
        printProgress "$cmd"
        eval "$cmd"
    fi
}