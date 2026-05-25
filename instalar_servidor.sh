#!/bin/bash
# ============================================================
# instalar_servidor.sh
# Prepara un servidor Ubuntu virgen para Koiote.
# Instala: Docker · WireGuard · UFW · Fail2Ban
#
# Uso:
#   sudo ./scripts/cloud/instalar_servidor.sh
#
# Idempotente — se puede relanzar sin romper nada.
# Compatible con Ubuntu 22.04 y 24.04.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib.sh"

require_root

WG_DIR="/etc/wireguard"
WG_PORT="51820"
WG_ADDR="10.90.0.1/24"

banner "KOIOTE — INSTALAR SERVIDOR"
log_info "Ubuntu: $(lsb_release -d | cut -f2)"
log_info "Hostname: $(hostname)"

# ── 1. Actualizar sistema ────────────────────────────────────
log_step "Actualizando sistema..."
apt update -q
apt upgrade -y -q
apt install -y curl ca-certificates gnupg lsb-release \
  wireguard wireguard-tools iptables ufw fail2ban git htop
log_ok "Sistema actualizado"

# ── 2. Docker ────────────────────────────────────────────────
log_step "Instalando Docker..."
if command -v docker &>/dev/null; then
  log_ok "Docker ya instalado: $(docker --version)"
else
  install_docker
fi

# ── 3. sysctl ────────────────────────────────────────────────
log_step "Configurando ip_forward..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-koiote.conf
sysctl --system >/dev/null
log_ok "ip_forward activado"

# ── 4. WireGuard ─────────────────────────────────────────────
log_step "Configurando WireGuard..."
mkdir -p "$WG_DIR/clients" "$WG_DIR/developers/keys" "$WG_DIR/developers/configs"
chmod 700 "$WG_DIR"

if [ ! -f "$WG_DIR/server_private.key" ]; then
  wg genkey | tee "$WG_DIR/server_private.key" \
    | wg pubkey > "$WG_DIR/server_public.key"
  chmod 600 "$WG_DIR/server_private.key"
  chmod 644 "$WG_DIR/server_public.key"
  log_ok "Claves WireGuard generadas"
else
  log_warn "Claves WireGuard ya existen — reutilizando"
fi

PUBLIC_IFACE="$(detect_public_iface)"
SERVER_PRIVATE="$(cat "$WG_DIR/server_private.key")"

if [ ! -f "$WG_DIR/wg0.conf" ]; then
  cat > "$WG_DIR/wg0.conf" << EOF
[Interface]
Address = $WG_ADDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE
MTU = 1420

PostUp   = sysctl -w net.ipv4.ip_forward=1
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp   = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp   = iptables -t nat -A POSTROUTING -o $PUBLIC_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $PUBLIC_IFACE -j MASQUERADE
EOF
  chmod 600 "$WG_DIR/wg0.conf"
  log_ok "wg0.conf creado"
else
  log_warn "wg0.conf ya existe — no sobreescrito (peers conservados)"
fi

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
sleep 2
check_wg wg0

# ── 5. UFW ───────────────────────────────────────────────────
log_step "Configurando UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    comment 'SSH'
ufw allow 80/tcp    comment 'HTTP'
ufw allow 443/tcp   comment 'HTTPS'
ufw allow "${WG_PORT}/udp" comment 'WireGuard'
ufw --force enable
log_ok "UFW configurado"

# ── 6. Fail2Ban ──────────────────────────────────────────────
log_step "Configurando Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban
log_ok "Fail2Ban activo"

# ── 7. Directorios Koiote ────────────────────────────────────
log_step "Creando directorios Koiote..."
mkdir -p /opt/koiote/cloud
mkdir -p /opt/koiote/backups
log_ok "Directorios creados en /opt/koiote"

# ── 8. Resumen ───────────────────────────────────────────────
CLOUD_PUBLIC_KEY="$(cat "$WG_DIR/server_public.key")"

banner_ok "SERVIDOR LISTO"
echo ""
echo -e "  ${BOLD}Docker:${NC}     $(docker --version)"
echo -e "  ${BOLD}WireGuard:${NC}  activo en $WG_ADDR — puerto $WG_PORT/udp"
echo -e "  ${BOLD}Interfaz:${NC}   $PUBLIC_IFACE"
echo ""
echo -e "  ${BOLD}${YELLOW}CLOUD_PUBLIC_KEY (guarda esto):${NC}"
echo -e "  ${CYAN}$CLOUD_PUBLIC_KEY${NC}"
echo ""
echo -e "  ${BOLD}Próximo paso:${NC}"
echo -e "  Desplegar aplicación:"
echo -e "  sudo ./scripts/cloud/desplegar_app_cloud.sh CLIENTE DOMINIO"
echo ""
