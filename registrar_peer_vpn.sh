#!/bin/bash
# ============================================================
# registrar_teltonika.sh — Koiote Cloud Stack
# Registra un dispositivo Teltonika como peer WireGuard.
#
# Antes de ejecutar este script, en el Teltonika:
#   1. VPN → WireGuard → Añadir instancia
#   2. Anota la Public Key que genera el Teltonika
#   3. Configura en el Teltonika:
#      - Endpoint: IP_PUBLICA_SERVIDOR:51820
#      - Allowed IPs: 10.90.0.0/24
#      - DNS: (dejar vacío)
#
# Uso:
#   sudo ./registrar_teltonika.sh NOMBRE IP_VPN PUBLIC_KEY
#
# Ejemplo:
#   sudo ./registrar_teltonika.sh teltonika-acerasa 10.90.0.30 "AbCdEf1234...="
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

[ "$EUID" -ne 0 ] && { log_error "Ejecuta con sudo: sudo ./registrar_teltonika.sh NOMBRE IP_VPN PUBLIC_KEY"; exit 1; }

if [ "$#" -lt 3 ]; then
  echo -e "\n${BOLD}Uso:${NC} sudo ./registrar_teltonika.sh NOMBRE IP_VPN PUBLIC_KEY"
  echo -e "Ej:  sudo ./registrar_teltonika.sh teltonika-acerasa 10.90.0.30 \"AbCdEf1234...=\"\n"
  exit 1
fi

DEVICE_NAME="$1"
DEVICE_IP="$2"
DEVICE_PUBLIC_KEY="$3"
WG_IFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
DEVICES_DIR="$WG_DIR/clients"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner "REGISTRAR TELTONIKA — $DEVICE_NAME"
echo -e "  IP VPN:     $DEVICE_IP"
echo -e "  Public Key: ${DEVICE_PUBLIC_KEY:0:20}..."

# ── Validaciones ─────────────────────────────────────────────
log_step "Validando..."
systemctl is-active --quiet "wg-quick@$WG_IFACE" || {
  log_error "WireGuard no está activo. Ejecuta: sudo ./instalar_servidor.sh"
  exit 1
}

echo "$DEVICE_IP" | grep -qE '^10\.90\.[0-9]{1,3}\.[0-9]{1,3}$' || {
  log_error "IP inválida: $DEVICE_IP"
  echo "  Usa el rango 10.90.0.20 – 10.90.0.254 para dispositivos edge"
  exit 1
}

if wg show "$WG_IFACE" allowed-ips 2>/dev/null | grep -q "${DEVICE_IP}/32"; then
  log_error "La IP $DEVICE_IP ya está en uso"
  echo "  IPs en uso:"
  wg show "$WG_IFACE" allowed-ips | awk '{print "  " $2}'
  exit 1
fi

mkdir -p "$DEVICES_DIR"
[ -f "$DEVICES_DIR/${DEVICE_NAME}.conf" ] && {
  OLD_KEY="$(grep 'PublicKey' "$DEVICES_DIR/${DEVICE_NAME}.conf" | awk '{print $3}')"
  if [ "$OLD_KEY" = "$DEVICE_PUBLIC_KEY" ]; then
    log_warn "Este dispositivo ya estaba registrado con la misma clave — actualizando"
    wg set "$WG_IFACE" peer "$OLD_KEY" remove 2>/dev/null || true
  else
    log_warn "Ya existe '$DEVICE_NAME' con clave distinta — reemplazando"
    wg set "$WG_IFACE" peer "$OLD_KEY" remove 2>/dev/null || true
  fi
}
log_ok "Validaciones OK"

# ── Detectar IP pública ───────────────────────────────────────
log_step "Detectando IP pública del servidor..."
CLOUD_PUBLIC_IP="$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || \
  curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || echo "")"
[ -z "$CLOUD_PUBLIC_IP" ] && {
  log_warn "No se pudo detectar la IP pública automáticamente"
  echo -n "  Introduce la IP o dominio público del servidor: "
  read -r CLOUD_PUBLIC_IP
}
log_ok "Endpoint: $CLOUD_PUBLIC_IP:$WG_PORT"

# ── Registrar peer ───────────────────────────────────────────
log_step "Registrando peer en WireGuard..."
wg set "$WG_IFACE" peer "$DEVICE_PUBLIC_KEY" allowed-ips "${DEVICE_IP}/32"
log_ok "Peer registrado"

log_step "Persistiendo configuración..."
wg-quick save "$WG_IFACE"
log_ok "wg0.conf actualizado"

# ── Guardar registro del dispositivo ────────────────────────
log_step "Guardando registro del dispositivo..."
cat > "$DEVICES_DIR/${DEVICE_NAME}.conf" << EOF
# Dispositivo: $DEVICE_NAME
# Registrado: $(date +%Y-%m-%d)
# Tipo: Teltonika
[Peer]
PublicKey = $DEVICE_PUBLIC_KEY
AllowedIPs = ${DEVICE_IP}/32
EOF
chmod 600 "$DEVICES_DIR/${DEVICE_NAME}.conf"
log_ok "Registro guardado en $DEVICES_DIR/${DEVICE_NAME}.conf"

# ── Leer credenciales MQTT del .env ─────────────────────────
MQTT_USER="teltonika"
MQTT_PASS="ver archivo .env"
ENV_FILE="/opt/koiote/cloud/$(ls /opt/koiote/cloud/ 2>/dev/null | head -1)/.env"
if [ -f "$SCRIPT_DIR/.env" ]; then
  MQTT_USER="$(grep '^MQTT_USER=' "$SCRIPT_DIR/.env" | cut -d= -f2 || echo 'teltonika')"
  MQTT_PASS="$(grep '^MQTT_PASSWORD=' "$SCRIPT_DIR/.env" | cut -d= -f2 || echo 'ver .env')"
elif [ -f "$ENV_FILE" ]; then
  MQTT_USER="$(grep '^MQTT_USER=' "$ENV_FILE" | cut -d= -f2 || echo 'teltonika')"
  MQTT_PASS="$(grep '^MQTT_PASSWORD=' "$ENV_FILE" | cut -d= -f2 || echo 'ver .env')"
fi

# ── Resumen ──────────────────────────────────────────────────
banner_ok "TELTONIKA REGISTRADO — $DEVICE_NAME"
echo ""
echo -e "  ${BOLD}Peers activos en WireGuard:${NC}"
wg show "$WG_IFACE" allowed-ips | awk '{print "  " $2}' | sort
echo ""
echo -e "  ${BOLD}${YELLOW}Configuración que debes meter en el Teltonika:${NC}"
echo ""
echo -e "  ${BOLD}[ WireGuard — Interface ]${NC}"
echo -e "  Peer IP:     ${CYAN}${DEVICE_IP}/24${NC}"
echo -e "  DNS:         ${CYAN}(dejar vacío)${NC}"
echo ""
echo -e "  ${BOLD}[ WireGuard — Peer (el cloud) ]${NC}"
echo -e "  Public Key:  ${CYAN}$(cat "$WG_DIR/server_public.key")${NC}"
echo -e "  Endpoint:    ${CYAN}${CLOUD_PUBLIC_IP}:${WG_PORT}${NC}"
echo -e "  Allowed IPs: ${CYAN}10.90.0.0/24${NC}"
echo -e "  Keepalive:   ${CYAN}25${NC}"
echo ""
echo -e "  ${BOLD}[ MQTT — para publicar datos ]${NC}"
echo -e "  Broker:      ${CYAN}10.90.0.1${NC}"
echo -e "  Puerto:      ${CYAN}1883${NC}"
echo -e "  Usuario:     ${CYAN}$MQTT_USER${NC}"
echo -e "  Password:    ${CYAN}$MQTT_PASS${NC}"
echo -e "  Topic:       ${CYAN}CLIENTE/<sensor>${NC}  (ej: acerasa/temperatura)"
echo ""
echo -e "  ${YELLOW}Para eliminar este registro:${NC}"
echo -e "  sudo ./eliminar_peer_vpn.sh $DEVICE_NAME"
echo ""
