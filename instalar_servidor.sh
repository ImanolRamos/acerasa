#!/bin/bash
# ============================================================
# instalar_servidor.sh — Koiote Cloud Stack
# Prepara un servidor Ubuntu virgen: Docker + WireGuard + UFW
#
# Uso: sudo ./instalar_servidor.sh
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

[ "$EUID" -ne 0 ] && { echo "Ejecuta con sudo"; exit 1; }

WG_DIR="/etc/wireguard"
WG_PORT="51820"
WG_ADDR="10.90.0.1/24"

banner "KOIOTE — INSTALAR SERVIDOR"
echo -e "  Ubuntu: $(lsb_release -d | cut -f2)\n  Hostname: $(hostname)"

log_step "Actualizando sistema e instalando paquetes..."
apt update -q
apt install -y curl ca-certificates gnupg lsb-release \
  wireguard wireguard-tools iptables ufw fail2ban git htop
log_ok "Paquetes instalados"

log_step "Instalando Docker oficial..."
if command -v docker &>/dev/null; then
  log_ok "Docker ya instalado: $(docker --version)"
else
  apt remove -y docker.io containerd runc 2>/dev/null || true
  install -m 0755 -d /etc/apt/keyrings
  rm -f /etc/apt/keyrings/docker.gpg
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  ARCH="$(dpkg --print-architecture)"
  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update -q
  apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  systemctl enable docker && systemctl start docker
  log_ok "Docker instalado: $(docker --version)"
fi

log_step "Activando ip_forward..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-koiote.conf
sysctl --system >/dev/null
log_ok "ip_forward activado"

log_step "Configurando WireGuard..."
mkdir -p "$WG_DIR/clients" "$WG_DIR/developers/keys" "$WG_DIR/developers/configs"
chmod 700 "$WG_DIR"
if [ ! -f "$WG_DIR/server_private.key" ]; then
  wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
  chmod 600 "$WG_DIR/server_private.key"
  chmod 644 "$WG_DIR/server_public.key"
  log_ok "Claves WireGuard generadas"
else
  log_warn "Claves ya existen — reutilizando"
fi

PUBLIC_IFACE="$(ip route get 1.1.1.1 2>/dev/null \
  | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -1)"
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
  log_warn "wg0.conf ya existe — peers conservados"
fi

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
sleep 2
systemctl is-active --quiet wg-quick@wg0 && log_ok "WireGuard activo" || {
  log_error "WireGuard no arrancó"; journalctl -u wg-quick@wg0 --no-pager | tail -5; exit 1
}

log_step "Configurando UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "${WG_PORT}/udp"
ufw --force enable
log_ok "UFW configurado"

log_step "Configurando Fail2Ban..."
systemctl enable fail2ban && systemctl start fail2ban
log_ok "Fail2Ban activo"

mkdir -p /opt/koiote/cloud

CLOUD_PUBLIC_KEY="$(cat "$WG_DIR/server_public.key")"

banner_ok "SERVIDOR LISTO"
echo -e "\n  ${BOLD}${YELLOW}CLOUD_PUBLIC_KEY:${NC}\n  ${CYAN}$CLOUD_PUBLIC_KEY${NC}"
echo -e "\n  ${BOLD}Próximo paso:${NC}"
echo -e "  sudo ./desplegar_app_cloud.sh CLIENTE DOMINIO\n"
