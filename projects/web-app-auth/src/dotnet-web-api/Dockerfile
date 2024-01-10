ARG ARG_PORT_HTTP=8000
ARG ARG_APP_VERSION="1.0.0.1"
ARG ARG_APP_ENVIRONMENT="Production"
ARG ARG_WEB_API_PROJECT="dotnet-web-api.csproj"
# stage 1
FROM mcr.microsoft.com/dotnet/sdk:6.0  AS build-image

WORKDIR /app
COPY ./Controllers ./Controllers
COPY ./Models ./Models
COPY ./Options ./Options
COPY ./Services ./Services
COPY ./appsettings.json ./appsettings.json
COPY ./Program.cs ./Program.cs
COPY ./entrypoint.sh ./entrypoint.sh
COPY ./dotnet-web-api.csproj ./dotnet-web-api.csproj


RUN dotnet restore ${ARG_WEB_API_PROJECT}
RUN dotnet publish --self-contained -r linux-x64 -c Release -o out ${ARG_WEB_API_PROJECT}

# stage 2
FROM mcr.microsoft.com/dotnet/aspnet:6.0  AS release-image
ARG ARG_PORT_HTTP
ENV PORT_HTTP ${ARG_PORT_HTTP}

ARG ARG_APP_VERSION
ENV APP_VERSION=${ARG_APP_VERSION}

ARG ARG_APP_ENVIRONMENT
ENV APP_ENVIRONMENT=${ARG_APP_ENVIRONMENT}

WORKDIR /app


COPY --from=build-image ./app/out ./
COPY ./entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

EXPOSE $PORT_HTTP/tcp

CMD ["./entrypoint.sh"]
