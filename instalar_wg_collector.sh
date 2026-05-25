#!/bin/bash
# ============================================================
# instalar_wg_collector.sh — Koiote Cloud Stack
# Instala el collector de métricas WireGuard como servicio
# systemd que se ejecuta cada minuto.
#
# Uso: sudo ./instalar_wg_collector.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()  { echo -e "${GREEN}[OK]${NC}    $*"; }
log_step(){ echo -e "\n${BOLD}${CYAN}▸ $*${NC}"; }
banner_ok(){ echo -e "\n${GREEN}${BOLD}══════════════════════════════════════════\n  ✓ $1\n══════════════════════════════════════════${NC}"; }

[ "$EUID" -ne 0 ] && { echo "Ejecuta con sudo"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$SCRIPT_DIR/wg_collector.sh"

[ -f "$COLLECTOR" ] || { echo "No se encuentra wg_collector.sh"; exit 1; }

# ── 1. Aplicar migración SQL ─────────────────────────────────
log_step "Aplicando migración SQL (tabla wireguard_peers)..."

ENV_FILE=""
for f in /opt/koiote/cloud/*/.env; do [ -f "$f" ] && ENV_FILE="$f" && break; done
[ -z "$ENV_FILE" ] && { echo "No se encontró .env — ejecuta desplegar_app_cloud.sh primero"; exit 1; }

CLIENT_NAME="$(grep '^CLIENT_NAME=' "$ENV_FILE" | cut -d= -f2)"
DB_USER="$(grep '^POSTGRES_USER=' "$ENV_FILE" | cut -d= -f2)"
DB_NAME="$(grep '^POSTGRES_DB=' "$ENV_FILE" | cut -d= -f2)"
DB_CONTAINER="koiote_${CLIENT_NAME}_timescaledb"

docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  < "$SCRIPT_DIR/add_wireguard_peers.sql" >/dev/null
log_ok "Tabla wireguard_peers creada"

# ── 2. Instalar collector ────────────────────────────────────
log_step "Instalando collector en /usr/local/bin..."
cp "$COLLECTOR" /usr/local/bin/koiote-wg-collector.sh
chmod +x /usr/local/bin/koiote-wg-collector.sh
log_ok "Collector instalado"

# ── 3. Systemd service ───────────────────────────────────────
log_step "Creando servicio systemd..."
cat > /etc/systemd/system/koiote-wg-collector.service << 'EOF'
[Unit]
Description=Koiote WireGuard Metrics Collector

[Service]
Type=oneshot
ExecStart=/usr/local/bin/koiote-wg-collector.sh
StandardOutput=journal
EOF

cat > /etc/systemd/system/koiote-wg-collector.timer << 'EOF'
[Unit]
Description=Koiote WireGuard Metrics Collector Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=koiote-wg-collector.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable koiote-wg-collector.timer
systemctl start koiote-wg-collector.timer
log_ok "Timer activo (recoge métricas cada minuto)"

# ── 4. Primera ejecución inmediata ───────────────────────────
log_step "Primera recogida de métricas..."
bash /usr/local/bin/koiote-wg-collector.sh
log_ok "Datos insertados"

# ── 5. Verificar ────────────────────────────────────────────
log_step "Verificando datos en TimescaleDB..."
docker exec "$DB_CONTAINER" \
  psql -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT peer_name, peer_ip, connected, seconds_since_handshake FROM wireguard_peers_latest;" \
  2>/dev/null

banner_ok "COLLECTOR INSTALADO"
echo ""
echo -e "  Datos disponibles en Grafana → datasource TimescaleDB"
echo -e "  Tabla: ${CYAN}wireguard_peers${NC}"
echo -e "  Vista: ${CYAN}wireguard_peers_latest${NC}"
echo ""
echo -e "  Importa el dashboard:"
echo -e "  Grafana → Dashboards → Import → sube ${CYAN}grafana-dashboard-vpn.json${NC}"
echo ""
