#!/bin/bash
# ============================================================
# eliminar_peer_vpn.sh — Koiote Cloud Stack
# Elimina un peer VPN y revoca su acceso.
#
# Uso:
#   sudo ./eliminar_peer_vpn.sh NOMBRE
#
# Ejemplo:
#   sudo ./eliminar_peer_vpn.sh imanol
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "\n${BOLD}${CYAN}▸ $*${NC}"; }
banner_ok(){ echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════\n  ✓ $1\n══════════════════════════════════════════${NC}"; }

[ "$EUID" -ne 0 ] && { log_error "Ejecuta con sudo"; exit 1; }
[ "$#" -lt 1 ] && { echo "Uso: sudo ./eliminar_peer_vpn.sh NOMBRE"; exit 1; }

PEER_NAME="$1"
WG_IFACE="wg0"
WG_DIR="/etc/wireguard"
PEERS_DIR="$WG_DIR/peers"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$PEERS_DIR/${PEER_NAME}.conf"

[ -f "$CONFIG_FILE" ] || {
  log_error "No existe el peer '$PEER_NAME' en $PEERS_DIR"
  echo "  Peers existentes:"
  ls "$PEERS_DIR"/*.conf 2>/dev/null | xargs -I{} basename {} .conf | sed 's/^/  /' || echo "  (ninguno)"
  exit 1
}

log_step "Obteniendo clave pública del peer..."
PEER_PUBLIC="$(grep 'PrivateKey' "$CONFIG_FILE" | awk '{print $3}' | wg pubkey)"
log_ok "Clave obtenida"

log_step "Eliminando peer de WireGuard..."
wg set "$WG_IFACE" peer "$PEER_PUBLIC" remove 2>/dev/null && log_ok "Peer eliminado" \
  || log_error "Peer no encontrado en WireGuard (¿ya eliminado?)"

log_step "Persistiendo WireGuard..."
wg-quick save "$WG_IFACE"
log_ok "wg0.conf actualizado"

log_step "Eliminando archivos de configuración..."
rm -f "$CONFIG_FILE"
rm -f "$SCRIPT_DIR/${PEER_NAME}-vpn.conf"
log_ok "Archivos eliminados"

banner_ok "PEER ELIMINADO — $PEER_NAME"
echo ""
echo -e "  Peers restantes: $(wg show $WG_IFACE peers | wc -l)"
echo ""
