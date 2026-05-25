#!/bin/bash
# ============================================================
# listar_peers.sh — Koiote Cloud Stack
# Muestra todos los peers VPN registrados y su estado.
#
# Uso: sudo ./listar_peers.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; GRAY='\033[0;37m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && { echo "Ejecuta con sudo: sudo ./listar_peers.sh"; exit 1; }

WG_IFACE="wg0"
WG_DIR="/etc/wireguard"

systemctl is-active --quiet "wg-quick@$WG_IFACE" || {
  echo -e "${RED}WireGuard no está activo${NC}"; exit 1
}

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Peers VPN registrados — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL=$(wg show "$WG_IFACE" peers | wc -l)
echo -e "  ${BOLD}Total peers:${NC} $TOTAL"
echo ""
printf "  ${BOLD}%-25s %-16s %-14s %-20s${NC}\n" "NOMBRE" "IP VPN" "ESTADO" "ÚLTIMO HANDSHAKE"
echo "  ──────────────────────────────────────────────────────────────"

# Guardar lista de peers en variable para evitar subshell
PEERS_LIST="$(wg show "$WG_IFACE" peers)"

for PEER_PUBLIC_KEY in $PEERS_LIST; do
  [ -z "$PEER_PUBLIC_KEY" ] && continue

  # IP del peer
  PEER_IP="$(wg show "$WG_IFACE" allowed-ips \
    | grep "$PEER_PUBLIC_KEY" | awk '{print $2}' | cut -d/ -f1 || echo "desconocida")"

  # Último handshake
  HANDSHAKE_RAW="$(wg show "$WG_IFACE" latest-handshakes \
    | grep "$PEER_PUBLIC_KEY" | awk '{print $2}' || echo "0")"

  if [ -n "$HANDSHAKE_RAW" ] && [ "$HANDSHAKE_RAW" != "0" ]; then
    NOW="$(date +%s)"
    DIFF=$((NOW - HANDSHAKE_RAW))
    if [ "$DIFF" -lt 180 ]; then
      ESTADO="[Conectado]"
      COLOR="$GREEN"
      HS_LABEL="${DIFF}s"
    elif [ "$DIFF" -lt 3600 ]; then
      ESTADO="[Reciente] "
      COLOR="$YELLOW"
      HS_LABEL="$((DIFF / 60))min"
    else
      ESTADO="[Inactivo] "
      COLOR="$RED"
      HS_LABEL="$((DIFF / 3600))h $((DIFF % 3600 / 60))min"
    fi
  else
    ESTADO="[Sin handshake]"
    COLOR="$GRAY"
    HS_LABEL="nunca"
  fi

  # Buscar nombre — en clients/ (Teltonikas)
  PEER_NAME=""
  if [ -d "$WG_DIR/clients" ]; then
    for f in "$WG_DIR/clients/"*.conf; do
      [ -f "$f" ] || continue
      if grep -q "$PEER_PUBLIC_KEY" "$f" 2>/dev/null; then
        PEER_NAME="$(basename "$f" .conf) [teltonika]"
        break
      fi
    done
  fi

  # Buscar nombre — en peers/ (devs y herramientas)
  if [ -z "$PEER_NAME" ] && [ -d "$WG_DIR/peers" ]; then
    for f in "$WG_DIR/peers/"*.conf; do
      [ -f "$f" ] || continue
      PEER_PRIVATE="$(grep 'PrivateKey' "$f" 2>/dev/null | awk '{print $3}' || true)"
      if [ -n "$PEER_PRIVATE" ]; then
        DERIVED="$(echo "$PEER_PRIVATE" | wg pubkey 2>/dev/null || true)"
        if [ "$DERIVED" = "$PEER_PUBLIC_KEY" ]; then
          PEER_NAME="$(basename "$f" .conf) [peer]"
          break
        fi
      fi
    done
  fi

  [ -z "$PEER_NAME" ] && PEER_NAME="(sin nombre)"

  printf "  %-25s %-16s ${COLOR}%-14s${NC} %-20s\n" \
    "$PEER_NAME" \
    "${PEER_IP:-desconocida}" \
    "$ESTADO" \
    "$HS_LABEL"
done

echo ""
echo -e "  ${BOLD}Detalle completo:${NC} sudo wg show"
echo ""
