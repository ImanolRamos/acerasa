#!/bin/bash
# ============================================================
# desplegar_app_cloud.sh — Koiote Cloud Stack
# Despliega: Traefik + Vue3 + Node.js + TimescaleDB + Mosquitto + Grafana
#
# Uso: sudo ./desplegar_app_cloud.sh CLIENTE DOMINIO [--reset]
# Ejemplo: sudo ./desplegar_app_cloud.sh acerasa acerasa.koiote.es
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_step() { echo -e "\n${BOLD}${CYAN}▸ $*${NC}"; }
banner()   { echo -e "\n${BOLD}══════════════════════════════════════════\n  $1\n══════════════════════════════════════════${NC}"; }
banner_ok(){ echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════\n  ✓ $1\n══════════════════════════════════════════${NC}"; }
banner_err(){ echo -e "\n${RED}${BOLD}══════════════════════════════════════════\n  ✗ $1\n══════════════════════════════════════════${NC}"; }

[ "$EUID" -ne 0 ] && { echo "Ejecuta con sudo"; exit 1; }
[ "$#" -lt 2 ] && {
  echo -e "Uso: sudo ./desplegar_app_cloud.sh CLIENTE DOMINIO [--reset]"
  echo -e "Ej:  sudo ./desplegar_app_cloud.sh acerasa acerasa.koiote.es"
  exit 1
}

CLIENT_NAME="$1"
DOMAIN="$2"
RESET_MODE=false
for arg in "$@"; do [ "$arg" = "--reset" ] && RESET_MODE=true; done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/koiote/cloud/$CLIENT_NAME"
CLOUD_WG_IP="10.90.0.1"
ACME_EMAIL="${ACME_EMAIL:-sistemas@koiote.es}"

banner "DESPLEGAR APP CLOUD — $CLIENT_NAME"
echo -e "  Dominio:  $DOMAIN\n  Destino:  $APP_DIR"
[ "$RESET_MODE" = true ] && echo -e "  ${YELLOW}Modo RESET activado${NC}"

log_step "Verificando Docker..."
systemctl is-active --quiet docker || {
  log_error "Docker no activo. Ejecuta primero: sudo ./instalar_servidor.sh"
  exit 1
}
log_ok "Docker activo"

log_step "Verificando DNS..."
CLOUD_IP="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")"
RESOLVED="$(host "$DOMAIN" 2>/dev/null | grep 'has address' | head -1 | awk '{print $4}' || echo "")"
if [ -n "$RESOLVED" ] && [ "$RESOLVED" = "$CLOUD_IP" ]; then
  log_ok "DNS correcto: $DOMAIN → $RESOLVED"
else
  log_warn "DNS no apunta aquí (IP servidor: $CLOUD_IP, DNS resuelve: $RESOLVED)"
  log_warn "El certificado TLS no se emitirá hasta que el DNS esté correcto"
fi

[ "$RESET_MODE" = true ] && [ -d "$APP_DIR" ] && {
  log_step "Eliminando contenedores y volúmenes..."
  cd "$APP_DIR" && docker compose down -v 2>/dev/null || true
}

log_step "Copiando template a $APP_DIR..."
[ -f "$APP_DIR/.env" ] && cp "$APP_DIR/.env" "/tmp/.koiote_env_bak"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$SCRIPT_DIR/." "$APP_DIR/"
[ -f "/tmp/.koiote_env_bak" ] && { cp "/tmp/.koiote_env_bak" "$APP_DIR/.env"; rm -f "/tmp/.koiote_env_bak"; }
log_ok "Template copiado"

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

log_step "Generando credenciales MQTT..."
MQTT_USER_VAL="$(grep '^MQTT_USER=' "$ENV_FILE" | cut -d= -f2)"
MQTT_PASS_VAL="$(grep '^MQTT_PASSWORD=' "$ENV_FILE" | cut -d= -f2)"
docker run --rm \
  -v "$APP_DIR/mosquitto:/mosquitto/config" \
  eclipse-mosquitto:2.0 \
  mosquitto_passwd -b -c /mosquitto/config/passwd "$MQTT_USER_VAL" "$MQTT_PASS_VAL"
log_ok "Usuario MQTT '$MQTT_USER_VAL' configurado"

log_step "Levantando Docker Compose..."
cd "$APP_DIR"
docker compose up -d --build

log_step "Esperando servicios (60s)..."
sleep 60
echo ""

log_step "Estado final:"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

GF_PASS_SHOW="$(grep '^GRAFANA_ADMIN_PASSWORD' "$ENV_FILE" | cut -d= -f2)"
MQTT_PASS_SHOW="$(grep '^MQTT_PASSWORD' "$ENV_FILE" | cut -d= -f2)"
MQTT_USER_SHOW="$(grep '^MQTT_USER' "$ENV_FILE" | cut -d= -f2)"

banner_ok "APP CLOUD DESPLEGADA — $CLIENT_NAME"
echo ""
echo -e "  ${BOLD}Accesos públicos:${NC}"
echo -e "  App:     ${CYAN}https://$DOMAIN${NC}"
echo -e "  Grafana: ${CYAN}https://grafana.$DOMAIN${NC}  (admin / $GF_PASS_SHOW)"
echo ""
echo -e "  ${BOLD}${YELLOW}Configuración Teltonika — MQTT por VPN:${NC}"
echo -e "  Broker:   ${CYAN}$CLOUD_WG_IP${NC}"
echo -e "  Puerto:   ${CYAN}1883${NC}"
echo -e "  Usuario:  ${CYAN}$MQTT_USER_SHOW${NC}"
echo -e "  Password: ${CYAN}$MQTT_PASS_SHOW${NC}"
echo -e "  Topic:    ${CYAN}${CLIENT_NAME}/<sensor>${NC}"
echo ""
