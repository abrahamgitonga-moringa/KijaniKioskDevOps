#!/usr/bin/env bash
# ==============================================================================
# Script: switch-env.sh
# Purpose: Atomically switches Nginx upstream proxy between Blue and Green.
# Usage: ./switch-env.sh <blue|green>
# ==============================================================================

set -euo pipefail

TARGET_ENV="${1:-}"

if [[ -z "${TARGET_ENV}" ]] || [[ ! "${TARGET_ENV}" =~ ^(blue|green)$ ]]; then
    echo "[ERROR] Usage: $0 <blue|green>" >&2
    exit 1
fi

CURRENT_ENV_FILE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_FILE="/opt/kijanikiosk/.previous-env"
NGINX_CONF="/etc/nginx/kijanikiosk-active-env.conf"

CURRENT_ENV=$(cat "${CURRENT_ENV_FILE}" 2>/dev/null || echo "unknown")
TARGET_PORT=$([ "${TARGET_ENV}" = "blue" ] && echo 3000 || echo 3001)

log() { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"

# Step 1: Pre-switch health check on target environment
log "Step 1: Verifying ${TARGET_ENV} is healthy on port ${TARGET_PORT}..."
HEALTH_URL="http://127.0.0.1:${TARGET_PORT}/health"

if ! curl -sf "${HEALTH_URL}" >/dev/null; then
    fail "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding\n[FAIL] Refusing to switch. Run the deployment script first."
fi
log "Pre-switch health check passed: ${TARGET_ENV} is healthy"

# Step 2: Write new Nginx active-env configuration
log "Step 2: Writing new nginx active-env configuration..."
cat << EOF | sudo tee "${NGINX_CONF}" > /dev/null
upstream kk_api_backend {
    server 127.0.0.1:${TARGET_PORT} max_fails=3 fail_timeout=5s;
}
EOF

# Step 3: Validate Nginx configuration syntax
log "Step 3: Validating nginx configuration..."
if ! sudo nginx -t >/dev/null 2>&1; then
    fail "Step 3 FAILED: Nginx configuration test failed!"
fi

# Step 4: Reload Nginx gracefully
log "Step 4: Reloading nginx..."
if ! sudo systemctl reload nginx; then
    fail "Step 4 FAILED: Failed to reload nginx!"
fi
log "nginx reloaded. Traffic now routing to ${TARGET_ENV}."

# Step 5: Post-switch confirmation via local HTTP proxy
log "Step 5: Confirming switch via proxy health check..."
sleep 1
PROXY_PORT=$(curl -sf http://127.0.0.1:80/health | grep -o '"port":[0-9]*' | cut -d: -f2 || true)

if [[ "${PROXY_PORT}" != "${TARGET_PORT}" ]]; then
    fail "Step 5 FAILED: Proxy is routing to port ${PROXY_PORT}, expected ${TARGET_PORT}!"
fi

# Update state tracking files
echo "${CURRENT_ENV}" | sudo tee "${PREVIOUS_ENV_FILE}" >/dev/null
echo "${TARGET_ENV}" | sudo tee "${CURRENT_ENV_FILE}" >/dev/null

log "Post-switch confirmation passed: proxy is routing to ${TARGET_ENV} (port ${TARGET_PORT})"
log "=== Switch to ${TARGET_ENV} complete ==="
