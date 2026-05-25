-- ============================================================
-- Koiote Cloud Stack — añadir tabla wireguard_peers
-- Ejecutar manualmente una vez:
--   docker exec -i koiote_CLIENTE_timescaledb \
--     psql -U koiote -d koiote_cloud < add_wireguard_peers.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS wireguard_peers (
    time            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    client_name     TEXT            NOT NULL,
    peer_name       TEXT            NOT NULL,
    peer_ip         TEXT,
    public_key      TEXT            NOT NULL,
    endpoint        TEXT,
    tx_bytes        BIGINT          DEFAULT 0,
    rx_bytes        BIGINT          DEFAULT 0,
    latest_handshake BIGINT         DEFAULT 0,
    seconds_since_handshake BIGINT  DEFAULT 0,
    connected       BOOLEAN         DEFAULT FALSE
);

SELECT create_hypertable('wireguard_peers', 'time', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_wg_peers_name
    ON wireguard_peers (peer_name, time DESC);

CREATE INDEX IF NOT EXISTS idx_wg_peers_client
    ON wireguard_peers (client_name, time DESC);

-- Vista: último estado de cada peer
CREATE OR REPLACE VIEW wireguard_peers_latest AS
SELECT DISTINCT ON (peer_name)
    time, client_name, peer_name, peer_ip,
    tx_bytes, rx_bytes, latest_handshake,
    seconds_since_handshake, connected, endpoint
FROM wireguard_peers
ORDER BY peer_name, time DESC;

SELECT add_retention_policy('wireguard_peers', INTERVAL '30 days', if_not_exists => TRUE);
