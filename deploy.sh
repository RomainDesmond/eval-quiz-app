#!/usr/bin/env bash
# Déploiement idempotent de quiz-frontend et quiz-backend sur Azure Container Apps
# Usage manuel : az login && ./deploy.sh
# Usage CI     : variables AZURE_* fournies par GitLab, voir .gitlab-ci.yml
set -euo pipefail

# ---------- Configuration (surchargeable par variables d'environnement) ----------
RESEND_API_KEY="${RESEND_API_KEY:-}"
RG="${RG:-eval-quiz-ressource}"
LOCATION="${LOCATION:-austriaeast}"                 # ADAPTER : région autorisée par la policy
ACR_NAME="${ACR_NAME:-acrevalquizzra265555}"
ENV_NAME="${ENV_NAME:-env-eval-quiz}"
BACKEND_APP="${BACKEND_APP:-backend}"
FRONTEND_APP="${FRONTEND_APP:-quiz-frontend}"
BACKEND_PORT="${BACKEND_PORT:-3007}"               # ADAPTER
FRONTEND_PORT="${FRONTEND_PORT:-8080}"               # ADAPTER
BACKEND_DIR="${BACKEND_DIR:-./backend}"            # ADAPTER
FRONTEND_DIR="." #"${FRONTEND_DIR:-.}"         # ADAPTER

# Tag = SHA du commit (CI) ou git SHA local, ou horodatage en dernier recours
TAG="${CI_COMMIT_SHORT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

# DATABASE_URL optionnelle : injectée seulement si définie
DATABASE_URL="${DATABASE_URL:-}"

log() { echo -e "\n=== $* ==="; }

# ---------- Vérification de la connexion Azure ----------
az account show >/dev/null 2>&1 || { echo "Non connecté à Azure : lancez 'az login'"; exit 1; }

# ---------- Providers ----------
log "Enregistrement des providers"
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# ---------- Resource group ----------
log "Resource group"
az group create --name "$RG" --location "$LOCATION" --output none

# ---------- ACR ----------
log "ACR"
if ! az acr show --name "$ACR_NAME" --resource-group "$RG" >/dev/null 2>&1; then
  az acr create --resource-group "$RG" --name "$ACR_NAME" \
    --sku Basic --admin-enabled true --location "$LOCATION" --output none
fi
az acr update --name "$ACR_NAME" --admin-enabled true --output none
ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)

# ---------- Build + push (via ACR Tasks, pas besoin de Docker local) ----------
# Si ACR Tasks est bloqué sur compte étudiant, voir la variante docker build/push plus bas.
#log "Build & push des images (tag: $TAG)"
#az acr build --registry "$ACR_NAME" --image "quiz-backend:$TAG"  "$BACKEND_DIR"
#az acr build --registry "$ACR_NAME" --image "quiz-frontend:$TAG" "$FRONTEND_DIR"

# --- Variante Docker local (décommenter si 'az acr build' est refusé) ---
 az acr login --name "$ACR_NAME"
 #docker build -t "$ACR_SERVER/quiz-backend:$TAG"  "$BACKEND_DIR"  && docker push "$ACR_SERVER/quiz-backend:$TAG"
 #docker build -t "$ACR_SERVER/quiz-frontend:$TAG" "$FRONTEND_DIR" && docker push "$ACR_SERVER/quiz-frontend:$TAG"
 docker build -t "$ACR_SERVER/quiz-backend:$TAG" "$BACKEND_DIR"
 docker push "$ACR_SERVER/quiz-backend:$TAG"
 docker build -t "$ACR_SERVER/quiz-frontend:$TAG" "$FRONTEND_DIR"
 docker push "$ACR_SERVER/quiz-frontend:$TAG"


 
# ---------- Environnement Container Apps ----------
log "Environnement Container Apps"
if ! az containerapp env show --name "$ENV_NAME" --resource-group "$RG" >/dev/null 2>&1; then
  az containerapp env create --name "$ENV_NAME" --resource-group "$RG" \
    --location "$LOCATION" --output none
fi

ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

# ---------- Fonction de déploiement create-or-update ----------
deploy_app() {
  local app="$1" image="$2" port="$3" envvars="${4:-}"
  if az containerapp show --name "$app" --resource-group "$RG" >/dev/null 2>&1; then
    log "Mise à jour de $app"
    az containerapp registry set --name "$app" --resource-group "$RG" \
      --server "$ACR_SERVER" --username "$ACR_USER" --password "$ACR_PASS" --output none
    local upd=(--name "$app" --resource-group "$RG" --image "$image")
    [[ -n "$envvars" ]] && upd+=(--set-env-vars "$envvars")
    az containerapp update "${upd[@]}" --output none
  else
    log "Création de $app"
    local crt=(--name "$app" --resource-group "$RG" --environment "$ENV_NAME" --image "$image"
      --registry-server "$ACR_SERVER" --registry-username "$ACR_USER" --registry-password "$ACR_PASS"
      --target-port "$port" --ingress external --min-replicas 1 --max-replicas 2)
    [[ -n "$envvars" ]] && crt+=(--env-vars "$envvars")
    az containerapp create "${crt[@]}" --output none
  fi
}

# ---------- Backend ----------
deploy_app "$BACKEND_APP" "$ACR_SERVER/quiz-backend:$TAG" "$BACKEND_PORT"

# DATABASE_URL : le secret ne peut être posé qu'une fois l'app créée
#if [[ -n "$DATABASE_URL" ]]; then
#  az containerapp secret set --name "$BACKEND_APP" --resource-group "$RG" \
#    --secrets "database-url=$DATABASE_URL" --output none
#  az containerapp update --name "$BACKEND_APP" --resource-group "$RG" \
#    --set-env-vars "DATABASE_URL=secretref:database-url" --output none
#fi

# ---------- Secrets du backend ----------
SECRETS=()
ENVS=()
add_secret() {  # nom_secret  VAR_ENV  valeur
  if [[ -n "$3" ]]; then
    SECRETS+=("$1=$3")
    ENVS+=("$2=secretref:$1")
  fi
}
add_secret resend-api-key  RESEND_API_KEY  "$RESEND_API_KEY"
add_secret jwt-secret      JWT_SECRET      "$JWT_SECRET"
add_secret admin-password  ADMIN_PASSWORD  "$ADMIN_PASSWORD"
add_secret database-url    DATABASE_URL    "$DATABASE_URL"
[[ -n "$ADMIN_USERNAME" ]] && ENVS+=("ADMIN_USERNAME=$ADMIN_USERNAME")

if [[ ${#SECRETS[@]} -gt 0 ]]; then
  log "Secrets du backend"
  az containerapp secret set --name "$BACKEND_APP" --resource-group "$RG" \
    --secrets "${SECRETS[@]}" --output none
  az containerapp update --name "$BACKEND_APP" --resource-group "$RG" \
    --set-env-vars "${ENVS[@]}" --output none
fi

BACKEND_FQDN=$(az containerapp show --name "$BACKEND_APP" --resource-group "$RG" \
  --query properties.configuration.ingress.fqdn -o tsv)

# ---------- Frontend ----------
# BACKEND_URL exposée au frontend (utile si nginx/app l'utilise)
deploy_app "$FRONTEND_APP" "$ACR_SERVER/quiz-frontend:$TAG" "$FRONTEND_PORT" \
  "BACKEND_URL=https://$BACKEND_FQDN"

FRONTEND_FQDN=$(az containerapp show --name "$FRONTEND_APP" --resource-group "$RG" \
  --query properties.configuration.ingress.fqdn -o tsv)

# ---------- Vérifications ----------
log "Vérifications"
az containerapp list --resource-group "$RG" \
  --query "[].{Nom:name, URL:properties.configuration.ingress.fqdn}" -o table

echo "Test /health du backend..."
for i in {1..10}; do
  if curl -fsS "https://$BACKEND_FQDN/health" >/dev/null; then
    echo "Backend OK"; break
  fi
  [[ $i -eq 10 ]] && { echo "Backend KO après 10 tentatives"; exit 1; }
  sleep 10
done

echo "Test du frontend..."
curl -fsSI "https://$FRONTEND_FQDN" | head -n 1

log "Déploiement terminé"
echo "Frontend : https://$FRONTEND_FQDN"
echo "Backend  : https://$BACKEND_FQDN"