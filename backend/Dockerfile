# Utiliser une image de base Node.js légère
FROM node:22-alpine
# Définir le répertoire de travail de l'application
WORKDIR /app 
RUN chown node:node /app
USER node

COPY --chown=node:node . .

RUN npm ci 
EXPOSE 3007
CMD ["node", "server.js"]
