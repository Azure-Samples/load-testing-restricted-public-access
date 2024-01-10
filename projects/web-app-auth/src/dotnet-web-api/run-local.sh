#!/bin/bash
set -e
PORT=7000
export PORT_HTTP=${PORT}
export APP_VERSION=$(date +"%Y%m%d.%H%M%S")
export APP_ENVIRONMENT="Development"
echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
ASPNETCORE_URLS="http://0.0.0.0:${PORT_HTTP}"
echo "ASPNETCORE_URLS $ASPNETCORE_URLS"
echo "dotnet run --urls=\"${ASPNETCORE_URLS}\""
echo "open http://localhost:${PORT_HTTP}/swagger/index.html with your browser"
dotnet run --urls="${ASPNETCORE_URLS}" --environment "${APP_ENVIRONMENT}"
