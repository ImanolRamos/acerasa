#!/bin/bash
# ============================================================
# desplegar_app_cloud.sh
# Despliega la aplicación cloud-stack en el servidor cloud.
# Incluye: Traefik + Vue3 + Node.js + TimescaleDB + Mosquitto + Grafana
#
# Uso:
#   sudo ./scripts/cloud/desplegar_app_cloud.sh CLIENTE DOMINIO
#
# Ejemplo:
#   sudo ./scripts/cloud/desplegar_app_cloud.sh acerasa acerasa.koiote.es
#
# Para reset completo: añade --reset al final
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib.sh"

require_root
require_args 2 "$#" \
  "sudo ./scripts/cloud/desplegar_app_cloud.sh CLIENTE DOMINIO [--reset]"

CLIENT_NAME="$1"
DOMAIN="$2"
RESET_MODE=false
for arg in "$@"; do [ "$arg" = "--reset" ] && RESET_MODE=true; done

validate_client_name "$CLIENT_NAME"

TEMPLATE_DIR="$REPO_ROOT/koiote-template/templates/cloud-stack"
APP_DIR="/opt/koiote/cloud/$CLIENT_NAME"
CLOUD_WG_IP="10.90.0.1"
ACME_EMAIL="${ACME_EMAIL:-sistemas@koiote.es}"

banner "DESPLEGAR APP CLOUD — $CLIENT_NAME"
log_info "Template:  $TEMPLATE_DIR"
log_info "Destino:   $APP_DIR"
log_info "Dominio:   $DOMAIN"
[ "$RESET_MODE" = true ] && log_warn "Modo RESET — se eliminarán los volúmenes Docker"

# ── 1. Verificar template ────────────────────────────────────
log_step "Verificando template..."
[ -f "$TEMPLATE_DIR/docker-compose.yml" ] || {
  log_error "Template no encontrado en $TEMPLATE_DIR"
  exit 1
}
log_ok "Template encontrado"

# ── 2. Verificar DNS ─────────────────────────────────────────
log_step "Verificando DNS del dominio..."
CLOUD_PUBLIC_IP="$(curl -s ifconfig.me 2>/dev/null || echo "")"
RESOLVED_IP="$(host "$DOMAIN" 2>/dev/null | grep 'has address' | head -1 | awk '{print $4}' || echo "")"
if [ -n "$RESOLVED_IP" ] && [ "$RESOLVED_IP" = "$CLOUD_PUBLIC_IP" ]; then
  log_ok "DNS correcto: $DOMAIN → $RESOLVED_IP"
else
  log_warn "DNS no apunta a este servidor (esperado: $CLOUD_PUBLIC_IP, resuelve: $RESOLVED_IP)"
  log_warn "El certificado TLS fallará si el DNS no está configurado"
fi

# ── 3. Reset opcional ────────────────────────────────────────
if [ "$RESET_MODE" = true ]; then
  log_warn "Eliminando contenedores y volúmenes..."
  cd "$APP_DIR" 2>/dev/null && docker compose down -v || true
fi

# ── 4. Copiar template ───────────────────────────────────────
log_step "Copiando template..."
if [ -f "$APP_DIR/.env" ]; then
  cp "$APP_DIR/.env" "/tmp/.koiote_cloud_env_backup"
fi
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$TEMPLATE_DIR/." "$APP_DIR/"
if [ -f "/tmp/.koiote_cloud_env_backup" ]; then
  cp "/tmp/.koiote_cloud_env_backup" "$APP_DIR/.env"
  rm -f "/tmp/.koiote_cloud_env_backup"
fi
log_ok "Template copiado"

# ── 5. Generar .env ──────────────────────────────────────────
log_step "Configurando .env..."
ENV_FILE="$APP_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  DB_PASS="$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 24)"
  GF_PASS="$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 24)"
  MQTT_PASS="$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 24)"

  cat > "$ENV_FILE" << EOF
# Generado automáticamente el $(date +%Y-%m-%d)
CLIENT_NAME=$CLIENT_NAME
DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
CLOUD_WG_IP=$CLOUD_WG_IP

POSTGRES_USER=koiote
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=koiote_cloud

MQTT_USER=teltonika
MQTT_PASSWORD=$MQTT_PASS

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GF_PASS
EOF
  chmod 600 "$ENV_FILE"
  log_ok ".env generado con contraseñas aleatorias"
else
  log_warn ".env ya existe — conservado"
  sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" "$ENV_FILE"
  sed -i "s/^CLIENT_NAME=.*/CLIENT_NAME=$CLIENT_NAME/" "$ENV_FILE"
fi

# ── 6. Generar passwd Mosquitto ──────────────────────────────
log_step "Configurando Mosquitto (usuarios MQTT)..."
MQTT_USER="$(grep '^MQTT_USER=' "$ENV_FILE" | cut -d= -f2)"
MQTT_PASS="$(grep '^MQTT_PASSWORD=' "$ENV_FILE" | cut -d= -f2)"

# Generar el archivo passwd con mosquitto_passwd dentro de un contenedor temporal
docker run --rm -v "$APP_DIR/mosquitto:/mosquitto/config" \
  eclipse-mosquitto:2.0 \
  mosquitto_passwd -b -c /mosquitto/config/passwd "$MQTT_USER" "$MQTT_PASS" 2>/dev/null
log_ok "Usuario MQTT '$MQTT_USER' configurado"

# ── 7. Levantar stack ────────────────────────────────────────
log_step "Levantando Docker Compose..."
cd "$APP_DIR"
docker compose up -d --build

log_step "Esperando servicios (max 90s)..."
sleep 30
ELAPSED=30
while [ $ELAPSED -lt 90 ]; do
  if docker compose ps | grep -q "Up"; then
    break
  fi
  sleep 5; ELAPSED=$((ELAPSED + 5)); echo -n "."
done
echo ""

# ── 8. Verificación ─────────────────────────────────────────
log_step "Verificando servicios..."
FAILS=0
docker compose ps | grep -q "Up" || { log_error "Contenedores no activos"; ((FAILS++)); }
check_http "http://localhost/api/health" || ((FAILS++))

# ── 9. Resumen ───────────────────────────────────────────────
echo ""
docker compose ps --format "table {{.Name}}\t{{.Status}}"

GF_PASS_SHOW="$(grep '^GRAFANA_ADMIN_PASSWORD' "$ENV_FILE" | cut -d= -f2)"
MQTT_PASS_SHOW="$(grep '^MQTT_PASSWORD' "$ENV_FILE" | cut -d= -f2)"
MQTT_USER_SHOW="$(grep '^MQTT_USER' "$ENV_FILE" | cut -d= -f2)"

echo ""
echo -e "  ${BOLD}Accesos públicos:${NC}"
echo -e "  App:     https://$DOMAIN"
echo -e "  Grafana: https://grafana.$DOMAIN  (admin / $GF_PASS_SHOW)"
echo ""
echo -e "  ${BOLD}Configuración Teltonika (MQTT por VPN):${NC}"
echo -e "  Broker:   $CLOUD_WG_IP"
echo -e "  Puerto:   1883"
echo -e "  Usuario:  $MQTT_USER_SHOW"
echo -e "  Password: $MQTT_PASS_SHOW"
echo -e "  Topic:    ${CLIENT_NAME}/<sensor>"
echo ""

summary_result $FAILS "APP CLOUD DESPLEGADA — $CLIENT_NAME"
