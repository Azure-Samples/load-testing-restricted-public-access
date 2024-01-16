#!/bin/bash
set -u

get_sas_token() {
        local EVENT_HUBS_NAMESPACE="$1.servicebus.windows.net"
        local SHARED_ACCESS_KEY_NAME=$2
        local SHARED_ACCESS_KEY=$3
        local EXPIRY=${EXPIRY:=$((60 * 60 * 24 * 10))} # Default token expiry is 10 days

        local ENCODED_URI
        ENCODED_URI=$(echo -n "$EVENT_HUBS_NAMESPACE" | jq -s -R -r @uri)
        local TTL=$(($(date +%s) + "$EXPIRY"))
        local UTF8_SIGNATURE
        UTF8_SIGNATURE=$(printf "%s\n%s" "$ENCODED_URI" "$TTL" | iconv -t utf8)

        local HASH
        HASH=$(echo -n "$UTF8_SIGNATURE" | openssl sha256 -hmac "$SHARED_ACCESS_KEY" -binary | base64)
        local ENCODED_HASH
        ENCODED_HASH=$(echo -n "$HASH" | jq -s -R -r @uri)

        echo -n "SharedAccessSignature sr=$ENCODED_URI&sig=$ENCODED_HASH&se=$TTL&skn=$SHARED_ACCESS_KEY_NAME"
}

get_ad_token() {
        local EVENT_HUBS_NAMESPACE=$1

        az account get-access-token --resource "https://${EVENT_HUBS_NAMESPACE}.servicebus.windows.net/" --query accessToken --output tsv
}

if [[ $# == 1 ]]; then
        AD_TOKEN=$(get_ad_token "$1")
        if [[ -z ${AD_TOKEN} ]] ; then
            echo  -e "${RED}\nFailed to get azure Token${NC}"
            exit 1
        fi
        #echo "AD_TOKEN:"
        echo "Bearer ${AD_TOKEN}"
        exit 0
fi
if [[ $# == 3 ]]; then
        SAS_TOKEN=$(get_sas_token "$1" "$2" "$3")
        #echo "SAS_TOKEN:"
        echo "${SAS_TOKEN}"
        exit 0
fi
RED='\033[0;31m'
NC='\033[0m' # No Color
echo -e "${RED}\nFailed to get Token, wrong arguments${NC}"
echo "Get Event Hubs Token syntax:"    
echo "Get Event Hubs SAS Token:"
echo "./get-event-hub-token.sh [EVENT_HUBS_NAMESPACE] SHARED_ACCESS_KEY_NAME SHARED_ACCESS_KEY"
echo "Get Event Hubs Azure AD Token:"
echo "./get-event-hub-token.sh [EVENT_HUBS_NAMESPACE]"

# Below samples to use the different Token
# echo "Send message"
# EVENT_HUBS_NAMESPACE="ehloadtesting"
# EVENT_HUBS_INSTANCE="evinput1"
# EVENT_HUBS_INSTANCE="evinput2"
# PARTITION_ID="0"
# cmd="az rest --method post --uri \"https://${EVENT_HUBS_NAMESPACE}.servicebus.windows.net/${EVENT_HUBS_INSTANCE}/partitions/${PARTITION_ID}/messages\" --body '{\"Location\": \"Redmond\", \"Temperature\":\"37.0\" }' --headers \"Content-Type=application/json\" \"Authorization=${AD_TOKEN}\"  --output tsv"
# cmd="az rest --method post --uri \"https://${EVENT_HUBS_NAMESPACE}.servicebus.windows.net/${EVENT_HUBS_INSTANCE}/partitions/${PARTITION_ID}/messages\" --body '{\"Location\": \"Redmond\", \"Temperature\":\"37.0\" }' --headers \"Content-Type=application/json\" \"Authorization=${SAS_TOKEN}\" --output tsv"
# echo "${cmd}"
# result=$(eval "$cmd")
