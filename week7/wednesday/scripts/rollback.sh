#!/usr/bin/env bash
# ==============================================================================
# Script: rollback.sh
# Purpose: Switches Nginx traffic back to the previously active environment.
# ==============================================================================

set -euo pipefail

PREVIOUS_ENV_FILE="/opt/kijanikiosk/.previous-env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date +%H:%M:%S)] [ROLLBACK] $*"; }

if [[ ! -f "${PREVIOUS_ENV_FILE}" ]]; then
    log "[ERROR] Rollback state file ${PREVIOUS_ENV_FILE} not found!" >&2
    exit 1
fi

TARGET_ENV=$(cat "${PREVIOUS_ENV_FILE}")
log "Triggering automatic rollback to previous environment: ${TARGET_ENV}"

# Delegate execution to switch-env.sh
exec "${SCRIPT_DIR}/switch-env.sh" "${TARGET_ENV}"
