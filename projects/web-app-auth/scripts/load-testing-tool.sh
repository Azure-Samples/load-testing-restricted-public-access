#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script used to install pre-requisites, deploy/undeploy service, start/stop service, test service
#- Parameters are:
#- [-a] ACTION - value: login, install, getsuffix, createconfig, deploy, createapp, deployservices, undeploy, deploytest, undeploytest, opentest, runtest, closetest 
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
    echo -e " -a  Sets iactool ACTION {login, install, getsuffix, createconfig, deploy, createapp, deployservices, undeploy, deploytest, undeploytest, opentest, runtest, closetest}"
    echo -e " -c  Sets the iactool configuration file"
    echo -e " -h  Azure Function Sku - Azure Function Sku - by default B1 (B1, B2, B3, S1, S2, S3)"

    echo
    echo "Example:"
    echo -e " bash ./load-testing-tool.sh -a install "
    echo -e " bash ./load-testing-tool.sh -a deploy -c .evhtool.env"
    
}

USE_STATIC_WEB_APP=true
ACTION=
CONFIGURATION_FILE="$(dirname "${BASH_SOURCE[0]}")/../configuration/.default.env"
AZURE_RESOURCE_PREFIX="waa"
AZURE_RESOURCE_SKU="B1"
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""   
AZURE_REGION="eastus2"
AZURE_APP_ID=""
LOAD_TESTING_SECRET_NAME="AD-TOKEN"
LOAD_TESTING_DURATION="60"
LOAD_TESTING_THREADS="1"
LOAD_TESTING_ENGINE_INSTANCES="1"
LOAD_TESTING_ERROR_PERCENTAGE="5"
LOAD_TESTING_RESPONSE_TIME="100"
LOAD_TESTING_TEST_NAME="web-app-auth-multi-users"
LOAD_TESTING_USERS_CONFIGURATION=""
LOAD_TESTING_TARGET_HOSTNAME=""
LOAD_TESTING_TARGET_PATH=""

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
    && ! "${ACTION}" == "closetest" && ! "${ACTION}" == "deploytest" && ! "${ACTION}" == "undeploytest"  && ! "${ACTION}" == "createapp"  && ! "${ACTION}" == "deployservices" ]]; then
    echo "ACTION '${ACTION}' not supported, possible values: login, install, getsuffix, createconfig, deploy, createapp, deployservices, undeploy, deploytest, undeploytes, opentest, runtest, closetest"
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
    printProgress "Installing .Net 6.0 SDK "
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    sudo apt-get update; \
    sudo apt-get install -y apt-transport-https && \
    sudo apt-get update && \
    sudo apt-get install -y dotnet-sdk-6.0
    printProgress "Installing Typescript and node services "
    sudo npm install -g npm@latest 
    printProgress "NPM version:"
    sudo npm --version 
    sudo npm install --location=global -g typescript
    tsc --version
    sudo npm install --location=global -g webpack
    sudo npm install --location=global  --save-dev @types/jquery
    sudo npm install --location=global -g http-server
    sudo npm install --location=global -g forever
    sudo npm install -g @azure/static-web-apps-cli
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
        AZURE_TEST_SUFFIX=$(getNewSuffix  "${AZURE_RESOURCE_PREFIX}" "${AZURE_SUBSCRIPTION_ID}")
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
        SUFFIX=$(getNewSuffix  "${AZURE_RESOURCE_PREFIX}" "${AZURE_SUBSCRIPTION_ID}")
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

if [[ "${ACTION}" == "createapp" ]] ; then
    printMessage "Create Application in Microsoft Entra ID Tenant..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    az config set extension.use_dynamic_install=yes_without_prompt 
    # Get resources names for the infrastructure deployment
    RESOURCE_GROUP=$(getResourceGroupName "${AZURE_TEST_SUFFIX}")
    appName=$(getApplicationName "${AZURE_TEST_SUFFIX}")
    printMessage "Create/Update Azure AD Application name: ${appName} ..."
    # if AZURE_APP_ID is not defined in variable group 
    # Create application
    appId=$(createApplication "${AZURE_TEST_SUFFIX}" "${AZURE_RESOURCE_WEB_APP_SERVER}") 
    if [[ ! -z ${appId} && ${appId} != 'null' && $(isGuid ${appId}) == "true" ]] ; then
        # set Azure DevOps variable AZURE_APP_ID 
        updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_APP_ID" "${appId}"
        assignStorageRole "${appId}" "Storage Blob Data Contributor" "${AZURE_SUBSCRIPTION_ID}" "${RESOURCE_GROUP}" "${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}"
        printMessage "Create/Update Azure AD Application name: ${appName}  appId: ${appId} done"
    else
        printError "Error while creating Application name: ${appName} appId: ${appId}"
        exit 1
    fi
fi

if [[ "${ACTION}" == "deploy" ]] ; then
    printMessage "Deploying the infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    az config set extension.use_dynamic_install=yes_without_prompt 
    printMessage "Deploy infrastructure subscription: '$AZURE_SUBSCRIPTION_ID' region: '$AZURE_REGION' suffix: '$AZURE_TEST_SUFFIX'"
    printMessage "       Backend: 'Azure EventHubs with restricted public access'"
    # Get Agent IP address
    ip=$(curl -s https://ifconfig.me/ip) || true

    # Get resources names for the infrastructure deployment
    RESOURCE_GROUP=$(getResourceGroupName "${AZURE_TEST_SUFFIX}")

    deployAzureInfrastructure "$AZURE_SUBSCRIPTION_ID" "$AZURE_REGION" "$AZURE_TEST_SUFFIX" "$RESOURCE_GROUP"  \
     "$AZURE_RESOURCE_SKU" "$ip" "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/infrastructure/infrastructure-to-test/arm/global.json" 
    # if we use use Azure Static Web App to host the frontend 
    # override the value AZURE_RESOURCE_WEB_APP_SERVER with Static Web App url 
    # instead of Azure Storage Web url
    if [ ${USE_STATIC_WEB_APP} == true ]; then
        STATIC_WEB_APP_DOMAIN=$(az staticwebapp show --name "${AZURE_RESOURCE_STATIC_WEBAPP_NAME}" --resource-group "${RESOURCE_GROUP}" --query defaultHostname -o tsv)
        AZURE_RESOURCE_WEB_APP_SERVER="https://${STATIC_WEB_APP_DOMAIN}/"
        printProgress "Allowing origin https://${STATIC_WEB_APP_DOMAIN}"
        cmd="az functionapp cors add -g \"${RESOURCE_GROUP}\" -n \"${AZURE_RESOURCE_FUNCTION_NAME}\" --allowed-origins \"https://${STATIC_WEB_APP_DOMAIN}\""
        printProgress "$cmd"
        eval "$cmd"        
    fi
    printMessage "Azure Web App Url: ${AZURE_RESOURCE_WEB_APP_SERVER}"
    printMessage "Azure function Url: ${AZURE_RESOURCE_FUNCTION_SERVER}"
    AZURE_RESOURCE_WEB_APP_DOMAIN=$(echo "${AZURE_RESOURCE_WEB_APP_SERVER}" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    AZURE_RESOURCE_FUNCTION_DOMAIN=$(echo "${AZURE_RESOURCE_FUNCTION_SERVER}" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

    updateConfigurationFile "${CONFIGURATION_FILE}" "RESOURCE_GROUP" "${RESOURCE_GROUP}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_ACR_LOGIN_SERVER" "${AZURE_RESOURCE_ACR_LOGIN_SERVER}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_WEB_APP_SERVER" "${AZURE_RESOURCE_WEB_APP_SERVER}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_FUNCTION_SERVER" "${AZURE_RESOURCE_FUNCTION_SERVER}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_WEB_APP_DOMAIN" "${AZURE_RESOURCE_WEB_APP_DOMAIN}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_FUNCTION_DOMAIN" "${AZURE_RESOURCE_FUNCTION_DOMAIN}"  
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_STORAGE_ACCOUNT_NAME" "${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}"   
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_STATIC_WEBAPP_NAME" "${AZURE_RESOURCE_STATIC_WEBAPP_NAME}"
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_APP_INSIGHTS_NAME" "${AZURE_RESOURCE_APP_INSIGHTS_NAME}"      
    updateConfigurationFile "${CONFIGURATION_FILE}" "AZURE_RESOURCE_APP_INSIGHTS_CONNECTION_STRING" "${AZURE_RESOURCE_APP_INSIGHTS_CONNECTION_STRING}"      
    echo "File: ${CONFIGURATION_FILE}"
    cat "${CONFIGURATION_FILE}"    
    printMessage "Deploying the infrastructure done"
fi


if [[ "${ACTION}" == "deployservices" ]] ; then
    printMessage "Create Application in Microsoft Entra ID Tenant..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    az config set extension.use_dynamic_install=yes_without_prompt
    appName=$(getApplicationName "${AZURE_TEST_SUFFIX}") 
    printMessage "Building the backend hosting the Web API containers..."
    printProgress  "Building Application '${appName}' with application Id: ${AZURE_APP_ID} "
    # Variables used to build the application or configure the application
    APP_VERSION=$(date +"%y%m%d.%H%M%S")
    APP_PORT=80  
    APP_AUTHORIZATION_DISABLED=false

    # Build dotnet-api docker image
    TEMPDIR=$(mktemp -d)
    printProgress  "Update file: $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json application Id: ${AZURE_APP_ID} name: '${appName}'"
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.ClientId = \"${AZURE_APP_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.ClientId = \"${AZURE_APP_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.TenantId = \"${AZURE_TENANT_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.TenantId = \"${AZURE_TENANT_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    


    printProgress "Check if connected as Service Principal"
    UserSPMsiPrincipalId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true  
    SPMsiPrincipalId=
    if [[ -z $UserSPMsiPrincipalId ]]; then
        printProgress "Connected as Service Principal"
        # shellcheck disable=SC2154        
        SPMsiPrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query appId --output tsv  2> /dev/null)
    fi
    if [[ -n $SPMsiPrincipalId ]]; then
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.AllowWebApiToBeAuthorizedByACL = true ' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
        eval "$cmd"    
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.AllowWebApiToBeAuthorizedByACL = true ' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
        eval "$cmd"

        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.AccessControlList = [ \"${SPMsiPrincipalId}\" ]' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
        eval "$cmd"    
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.AccessControlList = [ \"${SPMsiPrincipalId}\" ]' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
        eval "$cmd"
    else
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.AllowWebApiToBeAuthorizedByACL = false ' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
        eval "$cmd"    
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.AllowWebApiToBeAuthorizedByACL = false ' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
        eval "$cmd"

        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.AzureAd.AccessControlList = [  ]' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
        eval "$cmd"    
        cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.AzureAd.AccessControlList = [  ]' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
        eval "$cmd"
    fi    

    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.ApplicationInsights.ConnectionString = \"${AZURE_RESOURCE_APP_INSIGHTS_CONNECTION_STRING}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.ApplicationInsights.ConnectionString = \"${AZURE_RESOURCE_APP_INSIGHTS_CONNECTION_STRING}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.Services.StorageVisit.Endpoint = \"https://${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}.table.core.windows.net\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.Services.StorageVisit.Endpoint = \"https://${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}.table.core.windows.net\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.Services.StorageAccount = \"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.Services.StorageAccount = \"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    

    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json  | jq -r '.Services.AuthorizationDisabled = ${APP_AUTHORIZATION_DISABLED,,}' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json  | jq -r '.Services.AuthorizationDisabled = ${APP_AUTHORIZATION_DISABLED,,}' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.Development.json"
    eval "$cmd"    
 

    echo "Content of appsettings.json:"
    cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api/appsettings.json

    # Build dotnet-api docker image
  
    printMessage "Building dotnet-rest-api container version:${APP_VERSION} port: ${APP_PORT}"
    buildWebAppContainer "${AZURE_RESOURCE_ACR_LOGIN_SERVER}" "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/dotnet-web-api" "dotnet-web-api" "${APP_VERSION}" "latest" ${APP_PORT}

    printMessage "Building the backend hosting the Web API containers done"

    printMessage "Building the Front End hosting the Web UI..."
    # Create or update application
    printProgress "Check if Application '${appName}' appId exists"
    if [[ -z ${AZURE_APP_ID} || ${AZURE_APP_ID} == 'null' || ${AZURE_APP_ID} == '' ]] ; then
        printError "Application ${appName} appId not available"
        exit 1
    fi
    printProgress  "Building Application '${appName}' with application Id: ${AZURE_APP_ID} "

    printMessage "Building ts-web-app container version:${APP_VERSION} port: ${APP_PORT}"

    # Update version in HTML package
    TENANT_DNS_NAME=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query 'value[?isDefault].id' -o tsv)
    TEMPDIR=$(mktemp -d)
    printProgress  "Update file: $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json application Id: ${AZURE_APP_ID} name: '${appName}'"
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.version = \"${APP_VERSION}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.clientId = \"${AZURE_APP_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"   

    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.tokenAPIRequest.scopes = [\"https://${TENANT_DNS_NAME}/${AZURE_APP_ID}/user_impersonation\" ]' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"   

    #cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.authority = \"https://login.microsoftonline.com/${AZURE_TENANT_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.authority = \"https://login.microsoftonline.com/common\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.tenantId = \"${AZURE_TENANT_ID}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.redirectUri = \"${AZURE_RESOURCE_WEB_APP_SERVER}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.storageAccountName = \"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.storageSASToken = \"\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.apiEndpoint = \"${AZURE_RESOURCE_FUNCTION_SERVER}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.appInsightsKey = \"${AZURE_RESOURCE_APP_INSIGHTS_INSTRUMENTATION_KEY}\"' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd"    
    cmd="cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json  | jq -r '.authorizationDisabled = ${APP_AUTHORIZATION_DISABLED,,}' > "${TEMPDIR}tmp.$$.json" && mv "${TEMPDIR}tmp.$$.json" $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json"
    eval "$cmd" 
    echo "Content of config.json:"
    cat $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/src/config/config.json

    # build web app
    pushd $SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app

    printProgress "NPM version:"
    npm --version
    printProgress "NPM Install..."
    npm install -s    
    npm audit fix -s
    printProgress "Typescript build..."
    tsc --build tsconfig.json
    printProgress "Webpack..."
    webpack --config webpack.config.min.js
    popd    
    buildWebAppContainer "${AZURE_RESOURCE_ACR_LOGIN_SERVER}" "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app" "ts-web-app" "${APP_VERSION}" "latest" ${APP_PORT}
    checkError    
    printMessage "Building the Front End containers done"


    printMessage "Deploying the backend container hosting web api in the infrastructure..."
    # get latest image version
    latest_dotnet_version=$(getLatestImageVersion "${AZURE_RESOURCE_ACR_NAME}" "dotnet-web-api")
    if [ -z "${latest_dotnet_version}" ]; then
        latest_dotnet_version=$APP_VERSION
    fi
    printProgress "Latest version to deploy: '$latest_dotnet_version'"

    # deploy dotnet-web-api
    printProgress "Deploy image dotnet-web-api:${latest_dotnet_version} from Azure Container Registry ${AZURE_RESOURCE_ACR_LOGIN_SERVER}"
    deployWebAppContainer "$AZURE_SUBSCRIPTION_ID" "$AZURE_TEST_SUFFIX" "functionapp" "$AZURE_RESOURCE_FUNCTION_NAME" "${AZURE_RESOURCE_ACR_LOGIN_SERVER}" "${AZURE_RESOURCE_ACR_NAME}"  "dotnet-web-api" "latest" "${latest_dotnet_version}" "${APP_PORT}"
    
    printProgress "Checking role assignment 'Storage Table Data Contributor' between '${AZURE_RESOURCE_FUNCTION_NAME}' and Storage '${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}' "  

    WebAppMsiPrincipalId=$(az functionapp show -n "${AZURE_RESOURCE_FUNCTION_NAME}" -g "${RESOURCE_GROUP}" -o json 2> /dev/null | jq -r .identity.principalId)
    WebAppMsiAcrPullAssignmentCount=$(az role assignment list --assignee "${WebAppMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.Storage/storageAccounts/"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}" 2> /dev/null | jq -r 'select(.[].roleDefinitionName=="Storage Table Data Contributor") | length')

    if [ "$WebAppMsiAcrPullAssignmentCount" != "1" ];
    then
        printProgress  "Assigning 'Storage Table Data Contributor' role assignment on scope ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}..."
        az role assignment create --assignee-object-id "$WebAppMsiPrincipalId" --assignee-principal-type ServicePrincipal --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.Storage/storageAccounts/"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}" --role "Storage Table Data Contributor" 2> /dev/null
    fi

    # Get current user objectId
    printProgress "Get current user objectId"
    UserType="User"
    WebAppMsiPrincipalId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null ) || true  
    if [[ -z $WebAppMsiPrincipalId ]]; then
        printProgress "Get current service principal objectId"
        UserType="ServicePrincipal"
        WebAppMsiPrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null) || true
    fi

    if [[ -n $WebAppMsiPrincipalId ]]; then
        printProgress  "Check 'Storage Blob Data Contributor' role assignment on scope ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}..."
        WebAppMsiAcrPullAssignmentCount=$(az role assignment list --assignee "${WebAppMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.Storage/storageAccounts/"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}" 2> /dev/null | jq -r 'select(.[].roleDefinitionName=="Storage Blob Data Contributor") | length')
        if [ "$WebAppMsiAcrPullAssignmentCount" != "1" ];
        then
            printProgress  "Assigning 'Storage Blob Data Contributor' role assignment on scope ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}..."
            az role assignment create --assignee-object-id "$WebAppMsiPrincipalId" --assignee-principal-type $UserType --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${RESOURCE_GROUP}"/providers/Microsoft.Storage/storageAccounts/"${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME}" --role "Storage Blob Data Contributor" 2> /dev/null
        fi
    fi
    # Test services
    # Test dotnet-web-api
    dotnet_rest_api_url="${AZURE_RESOURCE_FUNCTION_SERVER}version"
    printProgress "Testing dotnet-web-api url: $dotnet_rest_api_url expected version: ${latest_dotnet_version}"
    result=$(checkWebUrl "${dotnet_rest_api_url}" "${latest_dotnet_version}" 420)
    if [[ $result != "true" ]]; then
        printError "Error while testing dotnet-web-api"
        exit 1
    else
        printMessage "Testing dotnet-web-api successful"
    fi

    printMessage "Deploying the backend container hosting web api in the infrastructure done"

    printMessage "Deploying the frontend container hosting web ui in the infrastructure..."
    # get latest image version
    latest_webapp_version=$(getLatestImageVersion "${AZURE_RESOURCE_ACR_NAME}" "ts-web-app")
    if [ -z "${latest_webapp_version}" ]; then
        latest_webapp_version=$APP_VERSION
    fi
    if [ ${USE_STATIC_WEB_APP} == true ]; then
        printProgress "Deploy  ts-web-app:${latest_webapp_version} to Azure Static Web App "
        STATIC_WEB_APP_TOKEN=$(az staticwebapp secrets list --name "${AZURE_RESOURCE_STATIC_WEBAPP_NAME}" --query "properties.apiKey" -o tsv)
        cmd="swa deploy  \"$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/build\" --deployment-token \"${STATIC_WEB_APP_TOKEN}\" --env production --verbose silly"       
        printProgress "$cmd"
        eval "$cmd"
    else
        printProgress "Enable Static Web Page on Azure Storage: ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME} "
        cmd="az storage blob service-properties update --account-name ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME} --static-website  --index-document index.html --only-show-errors"
        printProgress "$cmd"
        eval "$cmd"
        printProgress "Deploy  ts-web-app:${latest_webapp_version} to Azure Storage \$web"
        cmd="az storage azcopy blob upload -c \"\\\$web\" --account-name ${AZURE_RESOURCE_STORAGE_ACCOUNT_NAME} -s \"$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/src/ts-web-app/build/*\" --recursive --only-show-errors"
        printProgress "$cmd"
        eval "$cmd"
    fi

    # Test web-app
    node_web_app_url="${AZURE_RESOURCE_WEB_APP_SERVER}config.json"
    printProgress "Testing node_web_app_url url: $node_web_app_url expected version: ${latest_webapp_version}"
    result=$(checkWebUrl "${node_web_app_url}" "${latest_webapp_version}" 420)
    if [[ $result != "true" ]]; then
        printError "Error while testing node_web_app_url"
        exit 1
    else
        printMessage "Testing node_web_app_url successful"
    fi

    printMessage "Deploying the frontend container hosting web ui in the infrastructure done"

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

    appName=$(getApplicationName "${AZURE_TEST_SUFFIX}")    
    printProgress "Check if Application '${appName}' still exists..."        
    cmd="az ad app list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].id"
    printProgress "$cmd"
    id=$(eval "$cmd") || true    
    if [[ -n ${id} && ${id} != 'null' ]] ; then
        printProgress "Delete Application '${appName}' "        
        cmd="az ad app delete --id '${id}'"        
        printProgress "$cmd"
        eval "$cmd" || true
        checkError
    fi 
    printProgress "Check if Service Principal '${appName}' still exists..."        
    cmd="az ad sp list --filter \"displayName eq '${appName}'\" -o json --only-show-errors | jq -r .[0].id"
    printProgress "$cmd"
    id=$(eval "$cmd") || true    
    if [[ -n ${id} && ${id} != 'null' ]] ; then
        printProgress "Delete Service Principal '${appName}' "        
        cmd="az ad sp delete --id '${id}'"        
        printProgress "$cmd"
        eval "$cmd" || true
        checkError
    fi 

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

    printMessage "Assigning Roles 'Load Test Contributor' for current user or service principal on scope Load Test ${LOAD_TESTING_NAME}"
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

    LOAD_TESTING_PRINCIPAL_ID=$(az load show  --name  "${LOAD_TESTING_NAME}" --resource-group "${LOAD_TESTING_RESOURCE_GROUP}" | jq '.identity.principalId' | tr -d '"')
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

    if [ -z "${LOAD_TESTING_USERS_CONFIGURATION}" ];
    then
        echo "Variable LOAD_TESTING_USERS_CONFIGURATION not defined."
        echo "Format:"
        echo "LOAD_TESTING_USERS_CONFIGURATION='[{"
        echo "\"adu\": \"{AD_USERNAME}\","
        echo "\"pw\": \"{AD_PASSWORD}\","
        echo "\"tid\":\"{TENANT_ID}\""
        echo "}]'"            
        exit 1
    else
        updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_USERS_CONFIGURATION" "'${LOAD_TESTING_USERS_CONFIGURATION}'"
    fi    
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
        if [ -z ${LOAD_TESTING_TARGET_HOSTNAME} ]; then
            LOAD_TESTING_TARGET_HOSTNAME=${AZURE_RESOURCE_FUNCTION_DOMAIN}
            updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_TARGET_HOSTNAME" "${LOAD_TESTING_TARGET_HOSTNAME}"
        fi
        if [ -z ${LOAD_TESTING_TARGET_PATH} ]; then
            LOAD_TESTING_TARGET_PATH="visit"
            updateConfigurationFile "${CONFIGURATION_FILE}" "LOAD_TESTING_TARGET_PATH" "${LOAD_TESTING_TARGET_PATH}"
        fi

        # Update Load Testing configuration file
        TEMP_DIR=$(mktemp -d)
        cp  "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/load-testing.template.json"  "$TEMP_DIR/load-testing.json"
        sed -i "s/{name}/${LOAD_TESTING_TEST_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{engineInstances}/${LOAD_TESTING_ENGINE_INSTANCES}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{errorPercentage}/${LOAD_TESTING_ERROR_PERCENTAGE}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{responseTimeMs}/${LOAD_TESTING_RESPONSE_TIME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{hostname}/$(echo ${LOAD_TESTING_TARGET_HOSTNAME} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{path}/$(echo ${LOAD_TESTING_TARGET_PATH} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing.json"
        
        COUNTER=1
        AZURE_AD_TOKENS=""
        while read item; do     
            ITEM="\"token_${COUNTER}\":{\"value\":\"https://{keyVaultName}.vault.azure.net/secrets/{keyVaultAzureADTokenSecretName}-${COUNTER}/\",\"type\":\"AKV_SECRET_URI\"}"
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                AZURE_AD_TOKENS="${ITEM}"
            else
                AZURE_AD_TOKENS="${AZURE_AD_TOKENS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "AZURE_AD_TOKENS: ${AZURE_AD_TOKENS}"
        sed -i "s/{azureADTokens}/$(echo ${AZURE_AD_TOKENS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.json"

        COUNTER=1
        USERS=""
        while read item; do 
            VALUE=$(jq -r '.adu' <<< "$item");
            ITEM="\"user_${COUNTER}\":\"${VALUE}\""
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                USERS="${ITEM}"
            else
                USERS="${USERS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "USERS: ${USERS}"
        sed -i "s/{users}/$(echo ${USERS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.json"

        sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing.json"
        sed -i "s/{keyVaultAzureADTokenSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing.json"

        #echo "$TEMP_DIR/load-testing.json content:"
        #cat "$TEMP_DIR/load-testing.json"

        cmd="curl -s -X PATCH \
        \"https://$LOAD_TESTING_HOSTNAME/tests/$LOAD_TESTING_TEST_ID?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer $LOAD_TESTING_TOKEN' \
        -d \"@$TEMP_DIR/load-testing.json\" "
        # echo "$cmd"
        eval "$cmd" >/dev/null
    
        printProgress ""
        printProgress "Preparing load-testing.jmx for test ${LOAD_TESTING_TEST_NAME}..." 
        cp  "$SCRIPTS_DIRECTORY/../../../projects/web-app-auth/scenarios/${LOAD_TESTING_SCENARIO}/load-testing.template.jmx"  "$TEMP_DIR/load-testing.jmx"
        COUNTER=1
        AZURE_AD_TOKENS=""
        while read item; do     
            ITEM="<elementProp name=\"udv_token_${COUNTER}\" elementType=\"Argument\"><stringProp name=\"Argument.name\">udv_token_${COUNTER}</stringProp><stringProp name=\"Argument.value\">\${__GetSecret(token_${COUNTER})}</stringProp><stringProp name=\"Argument.desc\">Azure AD or SAS Token Token ${COUNTER}</stringProp><stringProp name=\"Argument.metadata\">=</stringProp></elementProp>"
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                AZURE_AD_TOKENS="${ITEM}"
            else
                AZURE_AD_TOKENS="${AZURE_AD_TOKENS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "AZURE_AD_TOKENS: ${AZURE_AD_TOKENS}"
        sed -i "s/{tokens}/$(echo ${AZURE_AD_TOKENS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.jmx"

        COUNTER=1
        USERS=""
        while read item; do 
            VALUE=$(jq -r '.adu' <<< "$item");
            ITEM="<elementProp name=\"udv_user_${COUNTER}\" elementType=\"Argument\"><stringProp name=\"Argument.name\">udv_user_${COUNTER}</stringProp><stringProp name=\"Argument.value\">\${__BeanShell( System.getenv(\"user_${COUNTER}\") )}</stringProp><stringProp name=\"Argument.desc\">User ${COUNTER}</stringProp><stringProp name=\"Argument.metadata\">=</stringProp></elementProp>"
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                USERS="${ITEM}"
            else
                USERS="${USERS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "USERS: ${USERS}"
        sed -i "s/{users}/$(echo ${USERS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing.jmx"
        (( COUNTER-- ))
        # echo "COUNTER: ${COUNTER}"
        sed -i "s/{count}/${COUNTER}/g" "$TEMP_DIR/load-testing.jmx"


        #echo "$TEMP_DIR/load-testing.jmx content:"
        #cat "$TEMP_DIR/load-testing.jmx"

        printProgress "Uploading load-testing.jmx for test ${LOAD_TESTING_TEST_NAME}..."    
        cmd="curl -s -X PUT \
        \"https://${LOAD_TESTING_HOSTNAME}/tests/${LOAD_TESTING_TEST_ID}/files/load-testing.jmx?fileType=JMX_FILE&api-version=2022-11-01\" \
        -H 'Content-Type: application/octet-stream' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
        --data-binary  \"@$TEMP_DIR/load-testing.jmx\" "
        # echo "$cmd"
        eval "$cmd" >/dev/null
        checkError

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


        if [ -z "${LOAD_TESTING_USERS_CONFIGURATION}" ];
        then
            printError "Variable LOAD_TESTING_USERS_CONFIGURATION not defined."
            exit 1  
        else
            COUNTER=1
            TENANT_DNS_NAME=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query 'value[?isDefault].id' -o tsv)
            SCOPE="https://${TENANT_DNS_NAME}/${AZURE_APP_ID}/user_impersonation"
            CLIENT_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
            while read item; do 
                AD_USER=$(jq -r '.adu' <<< "$item");
                PASSWORD=$(jq -r '.pw' <<< "$item");
                TENANT_ID=$(jq -r '.tid' <<< "$item");

                ENCODED_PASSWORD=$(urlEncode "${PASSWORD}")
                # echo "ENCODED_PASSWORD: ${ENCODED_PASSWORD}"
                
                printProgress "Getting Azure AD Token for user ${COUNTER}..."     
                cmd="curl -s -X POST https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token  \
                -H 'accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' \
                -d 'client_id=${CLIENT_ID}&scope=${SCOPE}&username=${AD_USER}&password=${ENCODED_PASSWORD}&grant_type=password' | jq -r '.access_token' "
                # echo "${cmd}"
                AZURE_AD_TOKEN="Bearer $(eval "${cmd}")"
                # echo "TOKEN: ${AZURE_AD_TOKEN}"

                printProgress "Store the token in the Azure Key Vault for test ${LOAD_TESTING_RESOURCE_NAME} for user ${COUNTER}..."   
                cmd="az keyvault secret set --vault-name \"${LOAD_TESTING_KEY_VAULT_NAME}\" --name \"${LOAD_TESTING_SECRET_NAME}-${COUNTER}\" --value \"${AZURE_AD_TOKEN}\" --output none"
                # echo "$cmd"
                eval "${cmd}"  
                checkError
                (( COUNTER++ ))
            done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        fi

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
        sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{hostname}/$(echo ${LOAD_TESTING_TARGET_HOSTNAME} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{path}/$(echo ${LOAD_TESTING_TARGET_PATH} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing-run.json"

        COUNTER=1
        AZURE_AD_TOKENS=""
        while read item; do     
            ITEM="\"token_${COUNTER}\":{\"value\":\"https://{keyVaultName}.vault.azure.net/secrets/{keyVaultAzureADTokenSecretName}-${COUNTER}/\",\"type\":\"AKV_SECRET_URI\"}"
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                AZURE_AD_TOKENS="${ITEM}"
            else
                AZURE_AD_TOKENS="${AZURE_AD_TOKENS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "AZURE_AD_TOKENS: ${AZURE_AD_TOKENS}"
        sed -i "s/{azureADTokens}/$(echo ${AZURE_AD_TOKENS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing-run.json"

        COUNTER=1
        USERS=""
        while read item; do 
            VALUE=$(jq -r '.tcu' <<< "$item");
            ITEM="\"user_${COUNTER}\":\"${VALUE}\""
            # echo "ITEM: ${ITEM}"
            if [[ COUNTER -eq 1 ]]; then
                USERS="${ITEM}"
            else
                USERS="${USERS},${ITEM}"
            fi
            (( COUNTER++ ))
        done <<< $(echo "${LOAD_TESTING_USERS_CONFIGURATION}" | jq -c -r ".[]" ); 
        # echo "USERS: ${USERS}"
        sed -i "s/{users}/$(echo ${USERS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing-run.json"
        sed -i "s/{keyVaultAzureADTokenSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing-run.json"

        # Wait 10 seconds to be sure the JMX file is validated
        sleep 10

        cmd="curl -s -X PATCH  \
        \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
        -d \"@$TEMP_DIR/load-testing-run.json\" "
        #echo "$cmd"
        eval "$cmd"  >/dev/null
        checkError

        printProgress "Waiting the end of the test run ${LOAD_TESTING_TEST_RUN_ID}..."    
        statuscmd="curl -s -X GET \
        \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
        -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' "
        #echo "$statuscmd"
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
            LOAD_TESTING_RESULTS=$(eval "$statuscmd")
            # printMessage "Result: $LOAD_TESTING_RESULTS"
            LOAD_TESTING_STATISTICS=$(echo "${LOAD_TESTING_RESULTS}" | jq -r '.testRunStatistics')
            LOAD_TESTING_RESULTS_CSV_URL=$(echo "${LOAD_TESTING_RESULTS}" | jq -r '.testArtifacts.outputArtifacts.resultFileInfo.url')
            LOAD_TESTING_RESULTS_CSV_FILE=$(echo "${LOAD_TESTING_RESULTS}" | jq -r '.testArtifacts.outputArtifacts.resultFileInfo.fileName')
            LOAD_TESTING_RESULTS_LOGS_URL=$(echo "${LOAD_TESTING_RESULTS}" | jq -r '.testArtifacts.outputArtifacts.logsFileInfo.url')
            LOAD_TESTING_RESULTS_LOGS_FILE=$(echo "${LOAD_TESTING_RESULTS}" | jq -r '.testArtifacts.outputArtifacts.logsFileInfo.fileName')

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
                echo "LOAD_TESTING_RESULTS: ${LOAD_TESTING_RESULTS}"
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
                echo "LOAD_TESTING_RESULTS: ${LOAD_TESTING_RESULTS}"
            fi
            if [ "${LOAD_TESTING_RESULT}" == "FAILED" ]; then
                printError "Load testing result failed"
            else
                if [ "${LOAD_TESTING_RESULT}" == "PASSED" ]; then
                    printMessage "Load testing result successful"
                else
                    printMessage "Load testing result unknown"
                fi
            fi
            #printMessage "Result: $LOAD_TESTING_RESULT"
            printMessage "Statistics: $LOAD_TESTING_STATISTICS"  
            exit 0
        fi
    done
fi

if [[ "${ACTION}" == "opentest" ]] ; then
    printMessage "Opening access to Keyvault..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    readConfigurationFile "$CONFIGURATION_FILE"

    printProgress "Open access to Key Vault '${LOAD_TESTING_KEY_VAULT_NAME}' for the test..."    
    cmd="az keyvault update --default-action Allow --name ${LOAD_TESTING_KEY_VAULT_NAME} -g ${LOAD_TESTING_RESOURCE_GROUP}"
    # echo "$cmd"
    eval "${cmd}" >/dev/null
    checkError
    printMessage "Keyvault is now accessible from Azure Load Testing"

    exit 0
fi

if [[ "${ACTION}" == "closetest" ]] ; then
    printMessage "Closing access to Keyvault..."
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


    printMessage "Keyvault is no more accessible from Azure Load Testing"

    exit 0
fi
