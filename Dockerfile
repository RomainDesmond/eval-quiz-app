# Utiliser une image de base Node.js légère
FROM node:20-alpine
# Définir le répertoire de travail de l'application
WORKDIR /app  

# Copier les fichiers package.json et package-lock.json pour installer les dépendances
#COPY package*.json .
#COPY public public
#COPY questions_defaut_2.js questions_defaut_2.js
#COPY questions_defaut.js questions_defaut.js
#COPY main.js main.js
#COPY index.html index.html
#COPY style.css style.css
#COPY vite.config.js vite.config.js
#COPY images images
#COPY javascript.svg javascript.svg
COPY . .
# Copier les fichiers sources de l'application dans le conteneur

# Installer les dépendances, construire l'application et nettoyer les modules Node.js
RUN npm install \
    && npm install -g serve \
&& npm run build
   # && rm -fr node_modules
# Exposer le port
EXPOSE 5173
# Démarrer l'application 
#CMD ["serve", "-s", "build"]
CMD ["npm", "run", "dev", "--", "--host"]