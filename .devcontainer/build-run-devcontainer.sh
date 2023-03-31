#!/bin/bash
set -e
BASH_SCRIPT=$(readlink -f "$0")
BASH_DIR=$(dirname "$BASH_SCRIPT")
# Run devcontainer locally without VSCode
# Run this bash file from the .devcontainer folder
docker build -f Dockerfile "${BASH_DIR}/.." -t devcontainer-image:latest
docker run -it --rm -v "${BASH_DIR}/..:/avworkspace" -u vscode -w /avworkspace --name devcontainer devcontainer-image:latest bash
