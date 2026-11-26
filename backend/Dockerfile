# Utiliser une image de base Node.js légère
FROM node:18-alpine
# Définir le répertoire de travail de l'application
WORKDIR /app 

# Copier les fichiers package.json et package-lock.json pour installer les dépendances
#COPY package.json package.json
#COPY package-lock.json package-lock.json
#COPY src src
#COPY public public

COPY ./backend .
# Copier les fichiers sources de l'application dans le conteneur

# Installer les dépendances, construire l'application et nettoyer les modules Node.js
RUN npm install \
    && npm install -g serve \
    && npm run build \
    && rm -fr node_modules
# Exposer le port
EXPOSE 3007
# Démarrer l'application 
CMD ["serve", "-s", "build"]