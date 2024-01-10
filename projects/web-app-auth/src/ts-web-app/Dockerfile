ARG ARG_PORT_HTTP=8000
ARG ARG_APP_VERSION="1.0.0.1"

# FROM nginx:alpine
# use image from mcr.microsoft.com 
FROM mcr.microsoft.com/dotnet/aspnet:6.0 

ARG ARG_PORT_HTTP
ENV PORT_HTTP ${ARG_PORT_HTTP}

ARG ARG_APP_VERSION
ENV APP_VERSION=${ARG_APP_VERSION}

RUN apt-get update  -y
RUN  apt-get install -y curl gnupg2 ca-certificates lsb-release 
RUN  apt-get install nginx -y
COPY ./build /usr/share/nginx/html

COPY ./default.conf /etc/nginx/conf.d/

EXPOSE 8080/tcp

CMD ["nginx", "-g", "daemon off;"]
