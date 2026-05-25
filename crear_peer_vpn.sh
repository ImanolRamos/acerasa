#!/bin/bash
# ============================================================
# crear_peer_vpn.sh — Koiote Cloud Stack
# Crea un peer WireGuard para acceso VPN desde un PC,
# herramienta (Node-RED, MQTT Explorer, etc.) o desarrollador.
#
# Uso:
#   sudo ./crear_peer_vpn.sh NOMBRE IP_VPN
#
# Ejemplo:
#   sudo ./crear_peer_vpn.sh imanol 10.91.0.10
#   sudo ./crear_peer_vpn.sh nodered-windows 10.91.0.11
#
# Rango recomendado para PCs/herramientas: 10.91.0.10 – 10.91.0.254
# (distinto del rango de edges: 10.90.0.20 – 10.90.0.254)
#
# Al terminar genera un archivo .conf listo para importar
# en WireGuard (Windows, Mac, Linux, iOS, Android).
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

[ "$EUID" -ne 0 ] && { log_error "Ejecuta con sudo: sudo ./crear_peer_vpn.sh NOMBRE IP_VPN"; exit 1; }

if [ "$#" -lt 2 ]; then
  echo -e "\n${BOLD}Uso:${NC} sudo ./crear_peer_vpn.sh NOMBRE IP_VPN"
  echo -e "Ej:  sudo ./crear_peer_vpn.sh imanol 10.91.0.10"
  echo -e "Ej:  sudo ./crear_peer_vpn.sh nodered 10.91.0.11\n"
  exit 1
fi

PEER_NAME="$1"
PEER_IP="$2"
WG_IFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
PEERS_DIR="$WG_DIR/peers"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Validaciones ─────────────────────────────────────────────
banner "CREAR PEER VPN — $PEER_NAME"

[ -f "$WG_DIR/server_public.key" ] || {
  log_error "No existe $WG_DIR/server_public.key"
  log_error "Ejecuta primero: sudo ./instalar_servidor.sh"
  exit 1
}

systemctl is-active --quiet "wg-quick@$WG_IFACE" || {
  log_error "WireGuard no está activo"
  exit 1
}
log_ok "WireGuard activo"

# Validar IP
echo "$PEER_IP" | grep -qE '^10\.(9[01])\.[0-9]{1,3}\.[0-9]{1,3}$' || {
  log_error "IP inválida: $PEER_IP"
  echo "  Usa el rango 10.91.0.10 – 10.91.0.254 para PCs/herramientas"
  exit 1
}

# Detectar si la IP ya está en uso
if wg show "$WG_IFACE" allowed-ips 2>/dev/null | grep -q "${PEER_IP}/32"; then
  log_error "La IP $PEER_IP ya está en uso en WireGuard"
  echo ""
  echo "  IPs actualmente en uso:"
  wg show "$WG_IFACE" allowed-ips | awk '{print "  " $2}'
  exit 1
fi

# Detectar si el nombre ya existe
mkdir -p "$PEERS_DIR"
[ -f "$PEERS_DIR/${PEER_NAME}.conf" ] && {
  log_error "Ya existe un peer con el nombre '$PEER_NAME'"
  echo "  Para eliminarlo: sudo ./eliminar_peer_vpn.sh $PEER_NAME"
  exit 1
}
log_ok "IP $PEER_IP disponible"

# ── Detectar endpoint público ─────────────────────────────────
log_step "Detectando IP pública del servidor..."
CLOUD_PUBLIC_IP="$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || \
  curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || echo "")"
[ -z "$CLOUD_PUBLIC_IP" ] && {
  log_error "No se pudo detectar la IP pública. Introduce la IP/dominio del servidor:"
  read -r CLOUD_PUBLIC_IP
}
log_ok "Endpoint: $CLOUD_PUBLIC_IP:$WG_PORT"

# ── Generar claves ───────────────────────────────────────────
log_step "Generando claves para $PEER_NAME..."
PEER_PRIVATE="$(wg genkey)"
PEER_PUBLIC="$(echo "$PEER_PRIVATE" | wg pubkey)"
SERVER_PUBLIC="$(cat "$WG_DIR/server_public.key")"
log_ok "Claves generadas"

# ── Registrar peer en WireGuard ──────────────────────────────
log_step "Registrando peer en WireGuard..."
wg set "$WG_IFACE" peer "$PEER_PUBLIC" allowed-ips "${PEER_IP}/32"
wg-quick save "$WG_IFACE"
log_ok "Peer registrado y persistido"

# ── Generar archivo .conf para el cliente ────────────────────
log_step "Generando configuración cliente..."
CONFIG_FILE="$PEERS_DIR/${PEER_NAME}.conf"

cat > "$CONFIG_FILE" << EOF
# ============================================================
# Koiote VPN — Configuración para: $PEER_NAME
# Generado: $(date +%Y-%m-%d)
#
# Importa este archivo en tu cliente WireGuard:
#   Windows/Mac: Archivo → Importar túnel
#   Linux:       sudo cp $PEER_NAME.conf /etc/wireguard/ && sudo wg-quick up $PEER_NAME
#   iOS/Android: Escanea el QR (si tienes qrencode instalado)
# ============================================================

[Interface]
PrivateKey = $PEER_PRIVATE
Address = ${PEER_IP}/24

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = ${CLOUD_PUBLIC_IP}:${WG_PORT}
# Solo ruteamos la red VPN, no todo el tráfico de internet
AllowedIPs = 10.90.0.0/24, 10.91.0.0/24
PersistentKeepalive = 25
EOF
chmod 600 "$CONFIG_FILE"
log_ok "Configuración guardada en $CONFIG_FILE"

# ── Copiar al directorio de trabajo para descarga fácil ──────
DOWNLOAD_FILE="$SCRIPT_DIR/${PEER_NAME}-vpn.conf"
cp "$CONFIG_FILE" "$DOWNLOAD_FILE"
chmod 644 "$DOWNLOAD_FILE"
log_ok "Copia descargable: $DOWNLOAD_FILE"

# ── QR code (si está disponible) ────────────────────────────
if command -v qrencode &>/dev/null; then
  echo ""
  echo -e "  ${BOLD}QR para móvil:${NC}"
  qrencode -t ansiutf8 < "$CONFIG_FILE"
fi

# ── Resumen ──────────────────────────────────────────────────
banner_ok "PEER VPN CREADO — $PEER_NAME"
echo ""
echo -e "  ${BOLD}Nombre:${NC}    $PEER_NAME"
echo -e "  ${BOLD}VPN IP:${NC}    $PEER_IP"
echo -e "  ${BOLD}Endpoint:${NC}  $CLOUD_PUBLIC_IP:$WG_PORT"
echo ""
echo -e "  ${BOLD}Archivo de configuración:${NC}"
echo -e "  ${CYAN}$DOWNLOAD_FILE${NC}"
echo ""
echo -e "  ${BOLD}Descarga este archivo y en WireGuard (Windows):${NC}"
echo -e "  Archivo → Importar túnel → selecciona ${PEER_NAME}-vpn.conf"
echo ""
echo -e "  ${BOLD}Una vez conectado, accedes a:${NC}"
echo -e "  MQTT Broker:  ${CYAN}10.90.0.1:1883${NC}"
echo -e "  App:          ${CYAN}http://10.90.0.1${NC}"
echo -e "  Grafana:      ${CYAN}http://10.90.0.1:3000${NC}  (si expuesto)"
echo ""
echo -e "  ${BOLD}Credenciales MQTT (del .env):${NC}"
if [ -f "$SCRIPT_DIR/.env" ]; then
  MQTT_USER="$(grep '^MQTT_USER=' "$SCRIPT_DIR/.env" | cut -d= -f2 || echo 'ver .env')"
  MQTT_PASS="$(grep '^MQTT_PASSWORD=' "$SCRIPT_DIR/.env" | cut -d= -f2 || echo 'ver .env')"
  echo -e "  Usuario:  ${CYAN}$MQTT_USER${NC}"
  echo -e "  Password: ${CYAN}$MQTT_PASS${NC}"
else
  echo -e "  Ver el archivo .env en /opt/koiote/cloud/CLIENTE/"
fi
echo ""
echo -e "  ${YELLOW}Para eliminar este peer:${NC}"
echo -e "  sudo ./eliminar_peer_vpn.sh $PEER_NAME"
echo ""
