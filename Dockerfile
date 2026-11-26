# Étape 1 : build
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
USER 65532

# Étape 2 : nginx
FROM nginxinc/nginx-unprivileged:alpine3.24-perl
#On repasse en root pour pouvoir upgrade une dépendance et ne pas avoir de faille critique
USER root 
RUN rm /etc/nginx/conf.d/default.conf && apk upgrade --no-cache brotli-libs
#On met un user sans droits
USER 65532
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
