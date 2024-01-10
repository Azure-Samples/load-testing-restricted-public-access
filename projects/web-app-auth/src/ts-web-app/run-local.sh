#!/bin/bash
set -eu
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../../"
    pwd -P
)
# Read variables in configuration file
SCRIPTS_DIRECTORY=`dirname $0`

pushd ${SCRIPTS_DIRECTORY}
./node_modules/http-server/bin/http-server ./build -c-1
popd
