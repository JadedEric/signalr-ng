# Introduction

This project serves as a test bed implementation of SignalR and Angular 9, to demonstrate polling of data from a back-end source onto an SPA front-end.

SignalR was decided upon due to the fact that all web service calls have already been built using .Net Core 3.1 and hubs exposed by SignalR would fit the current architecture perfectly.



## Team

The team is made up of two (2) developers with focus on .Net Core, a front-end developer with focus on frameworks (Angular, Vue, Aurelia and React), and a DBA to handle all the database-centric work.



## Continuous Delivery / Continuous Integration

Project pipeline lives in Azure DevOps



## Technologies

- Microsoft .Net Core 3.1
- Google Angular v9
- Microsoft SignalR
- PostgreSQL 11
- Microsoft Entity Framework
- Docker



## Solution Run Down

The following section talks about the basic run down of the solution, touching on some of the areas within the project that is of relevance to any developer who joins the team.

###### 1. Solution folder

The solution root folder, contains a single '**docker-composer.yml**' file, which will compose the reverse proxy and api images for the API layer, and the web image for Angular front-end.

###### 2. Api folder

The **API** folder root contains an 'nginx' folder containing information relevant to serving the API layer through Nginx, the Visual Studio solution file (sln) as well as the folder containing the Visual Studio project (csproj).

###### 2.1. Nginx folder

The **nginx** folder contains a configuration file for nginx as well as dockerfile which will be used to copy the configuration file to the relevant folder within the image.

The reason we split this apart was for modularity.

###### 2.2. SignalRApi folder

The default project folder created by Visual Studio, when creating a new Web API project. Of relevance in this folder is the **api.dockerfile** which is used to create the necessary image for the API layer.

###### 3. Web folder

The **Web** folder contains the Angular 9 application and is standard to what the Angular CLI scaffolds when running **ng new**.

The only file in this folder that is of relevance here, is the **ng.dockerfile** which builds the image for the Angular application



## Getting Started

To get started with this project, clone/fork the master branch to your local environment.

Once cloned/forked, simply run **docker-compose build** from the root of the solution folder followed by **docker-compose up -d** to start the container.

There are other ways to compose up and build, use the correct command at your discretion.



## How to access the web sites after starting the container

Access to the API image is through the reverse proxy, and can be found by launching http://localhost/weatherforecast (the default .net core 3.1 controller) and http://localhost:81/ to access the Angular project once the containers have been started up.

Docker dashboard in Windows produces the following screenshot:

<img src="https://cdn.peculiaritydigital.com/github/images/docker-dashboard.png" />

## Docker-compose

I'm quickly going to run through the docker-compose.yml here. Outlined in the YAML file is our interpretation of a compose up script and might not be correct to most of the readers. We encourage feedback if something we're doing makes no sense, or can be done better.

```yaml
version: "3.7"

services:

    reverseproxy:
        build:
            context: ./api/nginx
            dockerfile: nginx.dockerfile
        ports:
            - "80:80"
        restart: always

    api:
        depends_on:
            - reverseproxy
        build:
            context: ./api/SignalRApi
            dockerfile: api.dockerfile
        expose:
            - "5000"
        restart: always

    web:
        build:
            context: ./web/
            dockerfile: ng.dockerfile
        ports:
            - "81:80"
        restart:
            always
```

The script is split into three (3) service constructs, namely: **reverseproxy**, **api**, and **web**.

**api** service depends on the **reverseproxy** to have been created first, however, we ran into an issue, where the **reverseproxy** image would throw an internal exception where it could not find the **api**. It turned out that by the time the one image has been started up, the other's startup had been delayed; this was addressed by adding a timeout to the **nginx.conf** file.

The **api** image is exposed on localhost:80, which might pose a problem on Windows environments where IIS has been installed and configured. You are more than welcome to change the port through which the image exposes the **api** layer through the **ports** node under the **reverseproxy** section.



## nginx.conf | api

The **nginx.conf** can be found, navigating to */api/nginx/nginx.conf* from the solution root folder.

```nginx
worker_processes 1;

events { 
    
    worker_connections 1024; 
}

http {

    sendfile on; 

    upstream web-api {
        server api:5000 fail_timeout=5s max_fails=5;
    }

    server {
        listen 80;
        server_name $hostname;
        location / {
            proxy_pass          http://web-api;
            proxy_redirect      off;
            proxy_http_version  1.1;
            proxy_cache_bypass  $http_upgrade;
            proxy_set_header    Upgrade $http_upgrade;
            proxy_set_header    Connection keep-alive;
            proxy_set_header    Host $host;
            proxy_set_header    X-Real-IP $remote_addr;
            proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto $scheme;
            proxy_set_header    X-Forwarded-Host $server_name;
        }
    }
}
```

Nothing special about the configuration file, except that nginx, in this instance, is set up as a reverse proxy and the X-Forwarded header is exposed.



## nginx.dockerfile

This file just copies the configuration file to *etc/nginx*

```dockerfile
FROM nginx:latest
COPY nginx.conf /etc/nginx/nginx.conf
```



## api.dockerfile

This file is used to build the docker image for **api** layer.

```dockerfile
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-alpine AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/core/sdk:3.1-alpine AS build
WORKDIR /src
COPY ["SignalRApi.csproj", "./"]
RUN dotnet restore "./SignalRApi.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "SignalRApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "SignalRApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS http://*:5000
ENTRYPOINT ["dotnet", "SignalRApi.dll"]
```

It is a multi-step dockerfile, used to build and publish the .Net Core 3.1 project, which then get's exposed via port 5000, as set up by the environment variable **ASPNETCORE_URLS**



## default.conf | web

The **default.conf** can be found by navigating to **web/nginx/**, from the solution root folder.

```nginx
server {

    listen 80;

    sendfile on;

    default_type application/octet-stream;

    gzip                on;
    gzip_http_version   1.1;
    gzip_disable        "MSIE [1-6]\."
    gzip_min_length     1100;
    gzip_vary           on;
    gzip_proxied        expired no-cache no-store private auth;
    gzip_types          text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_comp_level     9;

    root /usr/share/nginx/html;

    location / {
        try_files $uri $uri/ /index.html =404;
    }
}
```

The default for the Angular project is set up, and basic gzip enabled, basic configuration setup here.



## ng.dockerfile | web

This file is used to build the image for the Angular application and can be found by navigating to **web/ng.dockerfile** from the solution root.

```dockerfile
FROM node:latest as builder

COPY package.json package-lock.json /usr/ng-app/
WORKDIR /usr/ng-app
RUN npm install --no-optional --no-shrinkwrap --no-package-lock

COPY ./ /usr/ng-app
RUN npm run build --prod

FROM nginx:latest

RUN rm -rf /usr/share/nginx/html/*

COPY nginx/default.conf /etc/nginx/conf.d/

COPY --from=builder /usr/ng-app/dist/web-api /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
```

