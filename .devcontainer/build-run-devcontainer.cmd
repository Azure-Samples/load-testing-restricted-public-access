REM Run devcontainer locally without VSCode
REM Run this cmd file from the .devcontainer folder
docker build -f Dockerfile  %~dp0/.. -t devcontainer-image:latest
docker run   -it --rm -v %~dp0/..:/avworkspace -u vscode -w /avworkspace --name devcontainer devcontainer-image:latest bash
