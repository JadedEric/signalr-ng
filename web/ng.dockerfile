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
