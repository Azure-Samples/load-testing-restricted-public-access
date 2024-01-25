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
#- getPermissionId 
# $1 = Graph API id
# $2 = name of permission, e.g. User.ReadWrite.All
#######################################################
getPermissionId () {
  echo `az ad sp show --id $1 --query "appRoles[?value=='$2'].id" --output tsv || true`
}
#######################################################
#- grant permission to the service principal
# $1 = SP objectId
# $2 = resourceId
# $3 = permissionId
#######################################################
grantPermission () {
  cmd="az rest --method GET --uri \"https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments\" \
  --headers \"Content-Type=application/json\"| jq -r '.value[]|select(.appRoleId==\"$3\").appRoleId'"
  # echo "${cmd}"  
  roleId=$(eval "${cmd}")
  if [ "$roleId" != "$3" ]; then
    verboseMessage "Granting Permission '$4'-'$3' for service principal '$1'"    
    cmd="az rest --method POST --uri \"https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments\" \
        --headers \"Content-Type=application/json\" \
        --body \"{\\\"principalId\\\": \\\"$1\\\", \\\"resourceId\\\": \\\"$2\\\", \\\"appRoleId\\\": \\\"$3\\\"}\" \
        --only-show-errors  || true"
    eval "${cmd}" > /dev/null
    checkError
  else
    verboseMessage "Permission '$4'-'$3'  already granted for service principal '$1'"    
  fi
}
#######################################################
#- add permission to the service principal
# $1 = SP appId
# $2 = API ID
# $3 = permissionId
# $4 = permission text
#######################################################
addPermission () {
    cmd="az ad app permission list --id $1  --query \"[?resourceAppId=='$2'].resourceAccess[]\" | jq -r '[.[]|select(.type==\"Role\"and.id==\"$3\")][0].id'"
    permissionId=$(eval "${cmd}")
    if [ "$permissionId" != "$3" ]; then
        verboseMessage "Adding permission '$4'-'$3' to service principal '$1'"
        cmd="az ad app permission add --id $1 --api $2 --api-permissions $3=Role"
        eval "${cmd}" > /dev/null 2> /dev/null
    else
        verboseMessage "Permission '$4'-'$3' already set to service principal '$1'"
    fi
}
#######################################################
#- get Custom Role confirmed existence
# $1 = Subscription
# $2 = Custom Role Name
# $3 = Test Counter with same result
# $4 = Timeout in seconds 
#######################################################
roleExists () {
    # cmd="az role definition list --custom-role-only true --name \"$2\" --scope \"/subscriptions/$1\" --query \"[?roleName=='$2'].roleName|[0]\" -o tsv"
    cmd="az role definition list --custom-role-only true --name \"$2\" --scope \"/subscriptions/$1\" | jq -r '[.[]|select(.roleType==\"CustomRole\"and.roleName==\"$2\")][0].roleName'"
    local COUNTER=0
    local EXIST_COUNTER=0
    local NOT_EXIST_COUNTER=0
    while (( NOT_EXIST_COUNTER < $3 && EXIST_COUNTER < $3 && COUNTER < $4 ));
    do
        ROLE=$(eval "${cmd}")
        if [ "${ROLE}" == "$2" ]; then
            NOT_EXIST_COUNTER=0
            ((EXIST_COUNTER=EXIST_COUNTER+1))    
        else
            EXIST_COUNTER=0
            ((NOT_EXIST_COUNTER=NOT_EXIST_COUNTER+1)) 
        fi
        sleep 1
        ((COUNTER=COUNTER+1))
        # echo "$COUNTER $EXIST_COUNTER $NOT_EXIST_COUNTER"
    done   
    if (( EXIST_COUNTER >= $3 )); then
        echo "true"
    else
        if (( NOT_EXIST_COUNTER >= $3 )); then
            echo "false"
        else
            if (( NOT_EXIST_COUNTER >= EXIST_COUNTER  )); then
                echo "false"
            fi
        fi
    fi
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
    infoMessage " bash  -s b5c9fc83-fbd0-4368-9cb6-1b5823479b6a -a testazdosp "
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
        echo -e "${RED}\nAn error occurred in  bash${NC}"
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
verboseMessage "Service Principal ClientId: ${appId}"

# Adding current user as owner of the Service Principal
verboseMessage "Adding current user as owner of the Service Principal"
userId=$(az ad signed-in-user show --query id --output tsv)
az ad app owner add --id $appId --owner-object-id $userId

# Microsoft Graph API Id
GRAPH_API_ID="00000003-0000-0000-c000-000000000000"

USER_READ_ALL_ROLE="User.Read.All"
APPLICATION_READWRITE_ALL_ROLE="Application.ReadWrite.All"
DOMAIN_READ_ALL_ROLE="Domain.Read.All"

verboseMessage "Getting API permission IDs"
USER_READ_ALL_ID=$(getPermissionId $GRAPH_API_ID $USER_READ_ALL_ROLE)
APPLICATION_READWRITE_ALL_ID=$(getPermissionId $GRAPH_API_ID $APPLICATION_READWRITE_ALL_ROLE)
DOMAIN_READ_ALL_ID=$(getPermissionId $GRAPH_API_ID $DOMAIN_READ_ALL_ROLE)

verboseMessage  "USER_READ_ALL_ROLE = $USER_READ_ALL_ID"
verboseMessage  "APPLICATION_READWRITE_ALL_ROLE = $APPLICATION_READWRITE_ALL_ID"
verboseMessage  "DOMAIN_READ_ALL_ROLE = $DOMAIN_READ_ALL_ID"

# Add permissions to SP
verboseMessage "Adding permissions"
addPermission $appId $GRAPH_API_ID $USER_READ_ALL_ID "User.Read.All"
addPermission $appId $GRAPH_API_ID $APPLICATION_READWRITE_ALL_ID "Application.ReadWrite.All"
addPermission $appId $GRAPH_API_ID $DOMAIN_READ_ALL_ID "Domain.Read.All"

# NOTE: az cli does not have a command to consent for application permissions
# see here: https://github.com/Azure/azure-cli/issues/12137#issuecomment-596567479
# and here: https://learn.microsoft.com/en-us/graph/api/serviceprincipal-post-approleassignments?view=graph-rest-1.0&tabs=http
# Granting consent for API permissions
verboseMessage "Granting consent for API permissions"
APP_OBJECT_ID=$(az ad sp show --id $appId --query "id" --output tsv)
API_OBJECT_ID=$(az ad sp show --id $GRAPH_API_ID --query "id" --output tsv)
grantPermission $APP_OBJECT_ID $API_OBJECT_ID $USER_READ_ALL_ID "User.Read.All"
grantPermission $APP_OBJECT_ID $API_OBJECT_ID $APPLICATION_READWRITE_ALL_ID "Application.ReadWrite.All"
grantPermission $APP_OBJECT_ID $API_OBJECT_ID $DOMAIN_READ_ALL_ID "Domain.Read.All"

verboseMessage "Assign role \"Contributor\" to service principal"
cmd="az role assignment create --assignee \"$appId\"  --role \"Contributor\"  --scope \"/subscriptions/${subscription}\" --only-show-errors"
eval "${cmd}" 1> /dev/null 
checkError

verboseMessage "Assign role \"Load Test Contributor\" to service principal"   
cmd="az role assignment create --assignee \"$appId\"  --role \"Load Test Contributor\"  --scope \"/subscriptions/${subscription}\" --only-show-errors"
eval "${cmd}" 1> /dev/null 
checkError


CUSTOM_ROLE_NAME="Role Assignments Operator"
verboseMessage "Assign custom role \"${CUSTOM_ROLE_NAME}\" to service principal"
verboseMessage "Checking if custom role \"${CUSTOM_ROLE_NAME}\" exists wait up-to 600 seconds"
if [ $(roleExists "${subscription}" "${CUSTOM_ROLE_NAME}" "10" "600") == "false" ]; then
    TEMPDIR=$(mktemp -d)
    cat > "${TEMPDIR}/role.json" << EOF
{
    "Name": "${CUSTOM_ROLE_NAME}",
    "IsCustom": true,
    "Description": "Can assign roles.",
    "Actions": [
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Authorization/roleAssignments/read"
    ],
    "NotActions": [
    ],
    "AssignableScopes": [
        "/subscriptions/${subscription}"
    ]
}
EOF
    verboseMessage "Creating custom role \"${CUSTOM_ROLE_NAME}\""
    cmd="az role definition create --role-definition \"${TEMPDIR}/role.json\""
    eval "${cmd}" 1> /dev/null
    verboseMessage "Waiting 60 seconds before assigning the role: '${CUSTOM_ROLE_NAME}'" 
    sleep 60  
else
    verboseMessage "Custom role \"${CUSTOM_ROLE_NAME}\" already exists"
fi

verboseMessage "Checking if custom role \"${CUSTOM_ROLE_NAME}\" exists wait up-to 600 seconds"
if [ $(roleExists "${subscription}" "${CUSTOM_ROLE_NAME}" "10" "600") == "true" ]; then
    verboseMessage "Assigning custom role \"${CUSTOM_ROLE_NAME}\" to service principal"    
    cmd="az role assignment create --assignee \"${appId}\"  --role \"${CUSTOM_ROLE_NAME}\"  --scope \"/subscriptions/${subscription}\" --only-show-errors"
    # echo "${cmd}"
    eval "${cmd}" 1> /dev/null 
else
    errorMessage "Custom role '${CUSTOM_ROLE_NAME}' not created"
    exit 1
fi

verboseMessage "Information for the creation of Github Action Secret AZURE_CREDENTIALS:"  >&2
echo "$spjson"
