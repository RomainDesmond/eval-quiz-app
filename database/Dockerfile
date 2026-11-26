# Utiliser une image de base Node.js légère
FROM golang:1.25-alpine AS gosu-build
RUN go install github.com/tianon/gosu@latest

FROM postgres:17-alpine
COPY --from=gosu-build /go/bin/gosu /usr/local/bin/gosu
ENV POSTGRES_DB=quiz_db
ENV POSTGRES_USER=quiz_user
COPY init.sql /docker-entrypoint-initdb.d/
USER postgres
