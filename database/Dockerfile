# Utiliser une image de base Node.js légère
FROM postgres:16
# Définir le répertoire de travail de l'application
#WORKDIR /app 

# Copier les fichiers package.json et package-lock.json pour installer les dépendances
#COPY package.json package.json
#COPY package-lock.json package-lock.json
#COPY src src
#COPY public public

#COPY database/ .
#COPY backend/server.js server.js 
#COPY backend/package.json package.json
# Copier les fichiers sources de l'application dans le conteneur

# Installer les dépendances, construire l'application et nettoyer les modules Node.js
#ENV POSTGRES_DB=app_db
#ENV POSTGRES_USER=admin
#ENV POSTGRES_PASSWORD=secret
ENV POSTGRES_DB=quiz_db
ENV POSTGRES_USER=quiz_user
ENV POSTGRES_PASSWORD=quiz_password
COPY database/init.sql /docker-entrypoint-initdb.d/
#EXPOSE 3007
# Démarrer l'application 
#CMD ["npm", "run", "dev", "--", "--host"]