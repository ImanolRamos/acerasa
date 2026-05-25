#!/bin/bash
# ============================================================
# wg_collector.sh — Koiote Cloud Stack
# Recoge métricas WireGuard y las inserta en TimescaleDB.
# Se instala como servicio systemd con instalar_wg_collector.sh
# ============================================================

set -euo pipefail

WG_IFACE="wg0"
WG_DIR="/etc/wireguard"

# Detectar cliente y credenciales DB desde el .env activo
ENV_FILE=""
for f in /opt/koiote/cloud/*/.env; do
  [ -f "$f" ] && ENV_FILE="$f" && break
done

[ -z "$ENV_FILE" ] && { echo "[wg_collector] No se encontró .env"; exit 1; }

CLIENT_NAME="$(grep '^CLIENT_NAME=' "$ENV_FILE" | cut -d= -f2)"
DB_USER="$(grep '^POSTGRES_USER=' "$ENV_FILE" | cut -d= -f2)"
DB_PASS="$(grep '^POSTGRES_PASSWORD=' "$ENV_FILE" | cut -d= -f2)"
DB_NAME="$(grep '^POSTGRES_DB=' "$ENV_FILE" | cut -d= -f2)"
DB_CONTAINER="koiote_${CLIENT_NAME}_timescaledb"

# Leer mapa nombre↔clave de los archivos de registro
declare -A PEER_NAMES

# clients/ — Teltonikas y edges
if [ -d "$WG_DIR/clients" ]; then
  for f in "$WG_DIR/clients/"*.conf; do
    [ -f "$f" ] || continue
    KEY="$(grep 'PublicKey' "$f" 2>/dev/null | awk '{print $3}' || true)"
    NAME="$(basename "$f" .conf)"
    [ -n "$KEY" ] && PEER_NAMES["$KEY"]="$NAME"
  done
fi

# peers/ — desarrolladores y herramientas
if [ -d "$WG_DIR/peers" ]; then
  for f in "$WG_DIR/peers/"*.conf; do
    [ -f "$f" ] || continue
    PRIV="$(grep 'PrivateKey' "$f" 2>/dev/null | awk '{print $3}' || true)"
    NAME="$(basename "$f" .conf)"
    if [ -n "$PRIV" ]; then
      PUB="$(echo "$PRIV" | wg pubkey 2>/dev/null || true)"
      [ -n "$PUB" ] && PEER_NAMES["$PUB"]="$NAME"
    fi
  done
fi

NOW="$(date +%s)"

# Procesar cada peer de wg dump
# Formato: public_key preshared_key endpoint allowed_ips latest_handshake tx rx persistent_keepalive
wg show "$WG_IFACE" dump | tail -n +2 | while IFS=$'\t' read -r PUB_KEY _PRESHARED ENDPOINT ALLOWED_IPS HANDSHAKE TX RX _KEEPALIVE; do
  [ -z "$PUB_KEY" ] && continue

  PEER_IP="$(echo "$ALLOWED_IPS" | cut -d/ -f1)"
  PEER_NAME="${PEER_NAMES[$PUB_KEY]:-desconocido}"
  SECONDS_SINCE=$(( NOW - HANDSHAKE ))
  CONNECTED="false"
  [ "$SECONDS_SINCE" -lt 180 ] && CONNECTED="true"
  [ "$HANDSHAKE" = "0" ] && SECONDS_SINCE=999999 && CONNECTED="false"

  SQL="INSERT INTO wireguard_peers
    (time, client_name, peer_name, peer_ip, public_key, endpoint,
     tx_bytes, rx_bytes, latest_handshake, seconds_since_handshake, connected)
    VALUES
    (NOW(), '$CLIENT_NAME', '$PEER_NAME', '$PEER_IP', '$PUB_KEY', '$ENDPOINT',
     $TX, $RX, $HANDSHAKE, $SECONDS_SINCE, $CONNECTED);"

  docker exec "$DB_CONTAINER" \
    psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL" >/dev/null 2>&1 || true
done

echo "[wg_collector] $(date '+%H:%M:%S') — métricas insertadas"
