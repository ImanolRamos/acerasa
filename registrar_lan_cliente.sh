#!/bin/bash
# ============================================================
# registrar_lan_cliente.sh — Koiote Cloud Stack
# Registra la subred LAN de un cliente accesible a través
# del Teltonika WireGuard.
#
# Qué hace:
#   1. Añade la subred LAN al AllowedIPs del peer Teltonika
#   2. Añade la ruta persistente en el servidor cloud
#   3. Regenera los .conf de los peers autorizados para
#      que incluyan la nueva subred
#
# Uso:
#   sudo ./registrar_lan_cliente.sh NOMBRE_TELTONIKA LAN_SUBNET PEERS_AUTORIZADOS
#
# Ejemplo:
#   sudo ./registrar_lan_cliente.sh \
#     teltonika-acerasa \
#     10.90.1.0/24 \
#     "imanol inaki"
#
# Para autorizar a todos los peers: usa "all"
#   sudo ./registrar_lan_cliente.sh teltonika-acerasa 10.90.1.0/24 all
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_step() { echo -e "\n${BOLD}${CYAN}▸ $*${NC}"; }
banner()   { echo -e "\n${BOLD}══════════════════════════════════════════\n  $1\n══════════════════════════════════════════${NC}"; }
banner_ok(){ echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════\n  ✓ $1\n══════════════════════════════════════════${NC}"; }

[ "$EUID" -ne 0 ] && { log_error "Ejecuta con sudo"; exit 1; }

if [ "$#" -lt 3 ]; then
  echo -e "\n${BOLD}Uso:${NC} sudo ./registrar_lan_cliente.sh NOMBRE_TELTONIKA LAN_SUBNET PEERS"
  echo -e "Ej:  sudo ./registrar_lan_cliente.sh teltonika-acerasa 10.90.1.0/24 \"imanol inaki\""
  echo -e "Ej:  sudo ./registrar_lan_cliente.sh teltonika-acerasa 10.90.1.0/24 all\n"
  exit 1
fi

TELTONIKA_NAME="$1"
LAN_SUBNET="$2"
AUTHORIZED_PEERS="$3"

WG_IFACE="wg0"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$WG_DIR/clients"
PEERS_DIR="$WG_DIR/peers"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner "REGISTRAR LAN CLIENTE — $TELTONIKA_NAME"
log_info "Subred LAN: $LAN_SUBNET"
log_info "Peers autorizados: $AUTHORIZED_PEERS"

# ── Validaciones ─────────────────────────────────────────────
log_step "Validando..."

systemctl is-active --quiet "wg-quick@$WG_IFACE" || {
  log_error "WireGuard no está activo"; exit 1
}

TELTONIKA_CONF="$CLIENTS_DIR/${TELTONIKA_NAME}.conf"
[ -f "$TELTONIKA_CONF" ] || {
  log_error "No existe el Teltonika '$TELTONIKA_NAME' en $CLIENTS_DIR"
  echo "  Teltonikas registrados:"
  ls "$CLIENTS_DIR"/*.conf 2>/dev/null | xargs -I{} basename {} .conf | sed 's/^/  /' || echo "  (ninguno)"
  exit 1
}

# Obtener la clave pública del Teltonika
TELTONIKA_PUBLIC_KEY="$(grep 'PublicKey' "$TELTONIKA_CONF" | awk '{print $3}')"
[ -n "$TELTONIKA_PUBLIC_KEY" ] || {
  log_error "No se encontró PublicKey en $TELTONIKA_CONF"
  exit 1
}
log_ok "Teltonika encontrado: $TELTONIKA_NAME ($TELTONIKA_PUBLIC_KEY)"

# ── 1. Obtener AllowedIPs actuales del Teltonika ─────────────
log_step "Obteniendo AllowedIPs actuales del Teltonika..."

CURRENT_ALLOWED="$(wg show "$WG_IFACE" allowed-ips \
  | grep "$TELTONIKA_PUBLIC_KEY" | awk '{$1=""; print $0}' | xargs)"

log_info "AllowedIPs actuales: $CURRENT_ALLOWED"

# Comprobar si la subred ya está registrada
if echo "$CURRENT_ALLOWED" | grep -qF "$LAN_SUBNET"; then
  log_warn "La subred $LAN_SUBNET ya está en AllowedIPs del Teltonika"
else
  # Limpiar IPs individuales redundantes que estén dentro de la subred
  # (ej: si había 10.90.1.1/32 y 10.90.1.2/32, los eliminamos y ponemos /24)
  LAN_BASE="$(echo "$LAN_SUBNET" | cut -d/ -f1 | cut -d. -f1-3)"
  CLEAN_ALLOWED=""
  for ip in $CURRENT_ALLOWED; do
    IP_BASE="$(echo "$ip" | cut -d/ -f1 | cut -d. -f1-3)"
    if [ "$IP_BASE" = "$LAN_BASE" ] && echo "$ip" | grep -q "/32"; then
      log_info "Eliminando IP individual redundante: $ip"
    else
      CLEAN_ALLOWED="$CLEAN_ALLOWED $ip"
    fi
  done
  NEW_ALLOWED="$(echo "$CLEAN_ALLOWED $LAN_SUBNET" | xargs | tr ' ' ',')"

  log_step "Actualizando AllowedIPs del Teltonika en WireGuard..."
  wg set "$WG_IFACE" peer "$TELTONIKA_PUBLIC_KEY" allowed-ips "$NEW_ALLOWED"
  wg-quick save "$WG_IFACE"
  log_ok "AllowedIPs actualizado: $NEW_ALLOWED"
fi

# ── 2. Ruta persistente en el cloud ──────────────────────────
log_step "Configurando ruta persistente..."

# Añadir ruta activa ahora
if ip route show | grep -q "^$LAN_SUBNET"; then
  log_warn "Ruta $LAN_SUBNET ya existe"
else
  ip route add "$LAN_SUBNET" dev "$WG_IFACE"
  log_ok "Ruta añadida: $LAN_SUBNET dev $WG_IFACE"
fi

# Persistir en /etc/network/if-up.d/ para que sobreviva reinicios
ROUTE_SCRIPT="/etc/network/if-up.d/koiote-routes"
if [ ! -f "$ROUTE_SCRIPT" ]; then
  cat > "$ROUTE_SCRIPT" << 'ROUTE_EOF'
#!/bin/bash
# Rutas persistentes Koiote — generado automáticamente
ROUTE_EOF
  chmod +x "$ROUTE_SCRIPT"
fi

ROUTE_LINE="ip route add $LAN_SUBNET dev $WG_IFACE 2>/dev/null || true"
if ! grep -qF "$LAN_SUBNET" "$ROUTE_SCRIPT"; then
  echo "$ROUTE_LINE" >> "$ROUTE_SCRIPT"
  log_ok "Ruta persistida en $ROUTE_SCRIPT"
else
  log_warn "Ruta ya estaba persistida"
fi

# También via systemd para mayor fiabilidad
SYSTEMD_ROUTE="/etc/systemd/system/koiote-routes.service"
cat > "$SYSTEMD_ROUTE" << EOF
[Unit]
Description=Koiote — rutas LAN clientes
After=network.target wg-quick@wg0.service
Wants=wg-quick@wg0.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $ROUTE_SCRIPT

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable koiote-routes.service >/dev/null 2>&1 || true
log_ok "Servicio systemd koiote-routes activado (persiste tras reinicio)"

# ── 3. Guardar LAN en el registro del Teltonika ──────────────
log_step "Actualizando registro del Teltonika..."
if ! grep -qF "LAN" "$TELTONIKA_CONF"; then
  echo "LAN = $LAN_SUBNET" >> "$TELTONIKA_CONF"
else
  sed -i "s|^LAN = .*|LAN = $LAN_SUBNET|" "$TELTONIKA_CONF"
fi
log_ok "Registro actualizado"

# ── 4. Regenerar .conf de peers autorizados ──────────────────
log_step "Regenerando configuración de peers autorizados..."

# Detectar IP pública del cloud
CLOUD_PUBLIC_IP="$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || \
  curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || echo "")"
CLOUD_PUBLIC_KEY="$(cat "$WG_DIR/server_public.key")"
WG_PORT="51820"

# Determinar lista de peers a actualizar
if [ "$AUTHORIZED_PEERS" = "all" ]; then
  PEERS_TO_UPDATE="$(ls "$PEERS_DIR"/*.conf 2>/dev/null \
    | xargs -I{} basename {} .conf || true)"
else
  PEERS_TO_UPDATE="$AUTHORIZED_PEERS"
fi

UPDATED=0
for PEER_NAME in $PEERS_TO_UPDATE; do
  PEER_CONF="$PEERS_DIR/${PEER_NAME}.conf"
  [ -f "$PEER_CONF" ] || {
    log_warn "Peer '$PEER_NAME' no encontrado en $PEERS_DIR — saltando"
    continue
  }

  # Leer datos del peer
  PEER_IP="$(grep 'Address' "$PEER_CONF" | awk '{print $3}' | cut -d/ -f1)"
  PEER_PRIVATE="$(grep 'PrivateKey' "$PEER_CONF" | awk '{print $3}')"

  # Obtener AllowedIPs actuales y añadir la nueva subred si no está
  CURRENT_PEER_ALLOWED="$(grep 'AllowedIPs' "$PEER_CONF" | sed 's/AllowedIPs = //')"

  if echo "$CURRENT_PEER_ALLOWED" | grep -qF "$LAN_SUBNET"; then
    log_warn "Peer '$PEER_NAME' ya tiene $LAN_SUBNET en AllowedIPs"
    continue
  fi

  NEW_PEER_ALLOWED="$CURRENT_PEER_ALLOWED, $LAN_SUBNET"

  # Reescribir el .conf del peer
  cat > "$PEER_CONF" << EOF
# ============================================================
# Koiote VPN — Configuración para: $PEER_NAME
# Actualizado: $(date +%Y-%m-%d) — LAN cliente añadida: $LAN_SUBNET
# ============================================================

[Interface]
PrivateKey = $PEER_PRIVATE
Address = ${PEER_IP}/24

[Peer]
PublicKey = $CLOUD_PUBLIC_KEY
Endpoint = ${CLOUD_PUBLIC_IP}:${WG_PORT}
AllowedIPs = $NEW_PEER_ALLOWED
PersistentKeepalive = 25
EOF
  chmod 600 "$PEER_CONF"

  # Copiar versión descargable
  cp "$PEER_CONF" "$SCRIPT_DIR/${PEER_NAME}-vpn.conf"
  chmod 644 "$SCRIPT_DIR/${PEER_NAME}-vpn.conf"

  log_ok "Peer '$PEER_NAME' actualizado — AllowedIPs: $NEW_PEER_ALLOWED"
  UPDATED=$((UPDATED + 1))
done

# ── 5. Resumen ───────────────────────────────────────────────
banner_ok "LAN CLIENTE REGISTRADA"
echo ""
echo -e "  ${BOLD}Teltonika:${NC}   $TELTONIKA_NAME"
echo -e "  ${BOLD}LAN subred:${NC}  $LAN_SUBNET"
echo -e "  ${BOLD}Peers actualizados:${NC} $UPDATED"
echo ""
echo -e "  ${BOLD}${YELLOW}Acción requerida en los peers actualizados:${NC}"
echo -e "  Deben reimportar su .conf en WireGuard:"
for PEER_NAME in $PEERS_TO_UPDATE; do
  PEER_CONF="$PEERS_DIR/${PEER_NAME}.conf"
  [ -f "$PEER_CONF" ] || continue
  echo -e "  ${CYAN}${PEER_NAME}-vpn.conf${NC} → descargar y reimportar"
done
echo ""
echo -e "  ${BOLD}Verificar conectividad desde un peer autorizado:${NC}"
LAN_GW="$(echo "$LAN_SUBNET" | sed 's/0\/24/1/')"
echo -e "  ping $LAN_GW"
echo ""
