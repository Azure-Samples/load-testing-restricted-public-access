#!/bin/bash
set -e
export PORT_HTTP=8000
export APP_VERSION=$(date +"%Y%m%d.%H%M%S")
export IMAGE_NAME="dotnet-web-api"
export IMAGE_TAG=${APP_VERSION}
export ALTERNATIVE_TAG="latest"
export APP_ENVIRONMENT="Development"

echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
echo "IMAGE_NAME $IMAGE_NAME"
echo "IMAGE_TAG $IMAGE_TAG"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"

echo "Building container"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile --build-arg APP_VERSION=${IMAGE_TAG} --build-arg ARG_PORT_HTTP=${PORT_HTTP}  .
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${ALTERNATIVE_TAG}

echo "Running container development mode"
cmd="docker run -d -e ARG_PORT_HTTP=${PORT_HTTP}  -e APP_ENVIRONMENT="Development"   -e APP_VERSION=${IMAGE_TAG} -p ${PORT_HTTP}:${PORT_HTTP}/tcp     ${IMAGE_NAME}:${ALTERNATIVE_TAG}  "
echo "${cmd}"
echo "open http://localhost:${PORT_HTTP}/swagger/index.html with your browser"
docker run -d -e ARG_PORT_HTTP=${PORT_HTTP} -e APP_ENVIRONMENT="${APP_ENVIRONMENT}" -e APP_VERSION=${IMAGE_TAG} -p ${PORT_HTTP}:${PORT_HTTP}/tcp     ${IMAGE_NAME}:${ALTERNATIVE_TAG}  

# You can open 
# ${ASPNETCORE_URLS}/swagger/index.html
# with your browser