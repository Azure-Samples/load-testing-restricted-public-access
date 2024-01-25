#!/bin/bash
set -eu
export PORT_HTTP=80
export APP_VERSION=$(date +"%Y%M%d.%H%M%S")
export IMAGE_NAME="web-app-ui"
export IMAGE_TAG=${APP_VERSION}
export ALTERNATIVE_TAG="latest"

echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
echo "IMAGE_NAME $IMAGE_NAME"
echo "IMAGE_TAG $IMAGE_TAG"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"

result=$(docker image inspect $IMAGE_NAME:$ALTERNATIVE_TAG  2>/dev/null) || true
#if [[ ${result} == "[]" ]]; then
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile --build-arg APP_VERSION=${IMAGE_TAG} --build-arg ARG_PORT_HTTP=${PORT_HTTP}  .
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${ALTERNATIVE_TAG}
#fi
echo "docker run -d -e ARG_PORT_HTTP=${PORT_HTTP}   -e APP_VERSION=${IMAGE_TAG} -p ${PORT_HTTP}:8080/tcp     ${IMAGE_NAME}:${ALTERNATIVE_TAG}"  
docker run -d -e ARG_PORT_HTTP=${PORT_HTTP}   -e APP_VERSION=${IMAGE_TAG} -p ${PORT_HTTP}:8080/tcp     ${IMAGE_NAME}:${ALTERNATIVE_TAG}  