#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-app.sh
# Purpose: Zero-downtime deployment script for kk-api (Blue/Green architecture)
# Phases: 1. Fetch -> 2. Validate -> 3. Deploy -> 4. Restart -> 5. Health Check
# ==============================================================================

set -euo pipefail

# --- Configuration & Defaults ---
APP_VERSION="${APP_VERSION:-v1.4.0}"
DEPLOY_ENV="${DEPLOY_ENV:-green}" # blue or green
ARTIFACT_BASE_URL="${ARTIFACT_BASE_URL:-http://127.0.0.1:8080}"
BASE_DIR="/opt/kijanikiosk"
RELEASES_DIR="${BASE_DIR}/releases"
TARGET_DIR="${BASE_DIR}/${DEPLOY_ENV}/app"
VERSION_FILE="${BASE_DIR}/${DEPLOY_ENV}/.version"
SERVICE_NAME="kk-api-${DEPLOY_ENV}.service"
PORT=$([ "${DEPLOY_ENV}" = "blue" ] && echo 3000 || echo 3001)

ARTIFACT_NAME="kk-api-${APP_VERSION}.tar.gz"
ARTIFACT_PATH="${RELEASES_DIR}/${ARTIFACT_NAME}"

# Ensure required directories exist
mkdir -p "${RELEASES_DIR}" "${TARGET_DIR}"

log() {
    echo "[$(date -Iseconds)] [INFO] $*"
}

error() {
    echo "[$(date -Iseconds)] [ERROR] $*" >&2
}

# --- Phase 1: Fetch ---
phase_fetch() {
    log "=== Phase 1: Fetching Artifact ==="
    if [[ -f "${ARTIFACT_PATH}" ]]; then
        log "Artifact already downloaded: ${ARTIFACT_PATH} (Phase 1 skipped)"
        return 0
    fi

    log "Downloading artifact from ${ARTIFACT_BASE_URL}/${ARTIFACT_NAME}..."
    if ! curl -sfL "${ARTIFACT_BASE_URL}/${ARTIFACT_NAME}" -o "${ARTIFACT_PATH}"; then
        error "Phase 1 FAILED: Unable to download artifact from ${ARTIFACT_BASE_URL}/${ARTIFACT_NAME}"
        return 1
    fi
    log "Artifact fetched successfully."
}

# --- Phase 2: Validate ---
phase_validate() {
    log "=== Phase 2: Validating Artifact ==="
    if [[ ! -f "${ARTIFACT_PATH}" ]]; then
        error "Phase 2 FAILED: Artifact file ${ARTIFACT_PATH} does not exist."
        return 1
    fi

    log "Checking tarball integrity..."
    if ! tar -tzf "${ARTIFACT_PATH}" >/dev/null 2>&1; then
        error "Phase 2 FAILED: Tarball integrity check failed for ${ARTIFACT_PATH}"
        return 1
    fi
    log "Artifact validation passed."
}

# --- Phase 3: Deploy ---
phase_deploy() {
    log "=== Phase 3: Deploying Artifact ==="
    
    # Check current deployed version for idempotency
    if [[ -f "${VERSION_FILE}" ]] && [[ "$(cat "${VERSION_FILE}")" == "${APP_VERSION}" ]]; then
        log "Version ${APP_VERSION} already deployed to ${DEPLOY_ENV}. Skipping copy."
        return 0
    fi

    log "Extracting artifact to target directory: ${TARGET_DIR}..."
    # Clean old application build files if necessary and unpack
    rm -rf "${TARGET_DIR:?}"/*
    if ! tar -xzf "${ARTIFACT_PATH}" -C "${TARGET_DIR}"; then
        error "Phase 3 FAILED: Extraction failed."
        return 1
    fi

    # Record the newly deployed version
    echo "${APP_VERSION}" > "${VERSION_FILE}"
    
    # Ensure correct permissions
    chown -R kk-api:kk-api "${TARGET_DIR}" "${VERSION_FILE}"
    log "Phase 3 complete: ${APP_VERSION} deployed to ${DEPLOY_ENV}."
}

# --- Phase 4: Restart ---
phase_restart() {
    log "=== Phase 4: Restarting Service ==="
    log "Restarting systemd unit: ${SERVICE_NAME}..."
    
    if ! systemctl restart "${SERVICE_NAME}"; then
        error "Phase 4 FAILED: Systemd restart command failed for ${SERVICE_NAME}."
        return 1
    fi
    log "Service ${SERVICE_NAME} restarted."
}

# --- Phase 5: Verify ---
phase_verify() {
    log "=== Phase 5: Verifying Health ==="
    local health_url="http://127.0.0.1:${PORT}/health"
    local max_retries=5
    local attempt=1

    log "Polling health check endpoint: ${health_url}..."

    while [[ ${attempt} -le ${max_retries} ]]; do
        local response
        if response=$(curl -sf "${health_url}"); then
            if echo "${response}" | grep -q "${APP_VERSION}"; then
                log "Phase 5 PASSED: ${SERVICE_NAME} is healthy and running ${APP_VERSION}."
                return 0
            fi
        fi
        log "Attempt ${attempt}/${max_retries} failed. Retrying in 2 seconds..."
        sleep 2
        attempt=$((attempt + 1))
    done

    error "Phase 5 FAILED: Health check failed for ${SERVICE_NAME} on port ${PORT}."
    error "--- Trailing Systemd Logs ---"
    journalctl -u "${SERVICE_NAME}" -n 20 --no-pager >&2
    return 1
}

# --- Main Execution Loop ---
main() {
    phase_fetch    || { error "Deployment failed at Phase 1"; exit 1; }
    phase_validate || { error "Deployment failed at Phase 2"; exit 2; }
    phase_deploy   || { error "Deployment failed at Phase 3"; exit 3; }
    phase_restart  || { error "Deployment failed at Phase 4"; exit 4; }
    phase_verify   || { error "Deployment failed at Phase 5"; exit 5; }

    log "Deployment of ${APP_VERSION} to ${DEPLOY_ENV} completed successfully!"
}

main "$@"
