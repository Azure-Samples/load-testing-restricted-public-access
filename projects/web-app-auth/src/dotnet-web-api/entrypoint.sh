#!/bin/bash
set -e
export ASPNETCORE_URLS="http://0.0.0.0:${PORT_HTTP}"
export ASPNETCORE_ENVIRONMENT="${APP_ENVIRONMENT}"
./dotnet-web-api  --urls=${ASPNETCORE_URLS} --environment "${APP_ENVIRONMENT}"
