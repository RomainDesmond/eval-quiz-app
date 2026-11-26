# Utiliser une image de base Node.js légère
FROM postgres:17-alpine
ENV POSTGRES_DB=quiz_db
ENV POSTGRES_USER=quiz_user
COPY init.sql /docker-entrypoint-initdb.d/
USER postgres
