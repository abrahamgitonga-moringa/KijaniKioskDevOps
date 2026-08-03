#!/usr/bin/env bash
# ==============================================================================
# Script: post-deploy-monitor.sh
# Purpose: Continuous post-deployment health check with confidence window.
# Usage: ./post-deploy-monitor.sh [confidence_window_seconds]
# ==============================================================================

set -euo pipefail

WINDOW_SECONDS="${1:-60}"
POLL_INTERVAL=5
MAX_CONSECUTIVE_FAILURES=3
LATENCY_THRESHOLD_SEC=2.0

PROXY_URL="http://127.0.0.1:80/health"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONSECUTIVE_FAILURES=0
WINDOW_ERRORS=0
POLL_COUNT=0
START_TIME=$(date +%s)

log() { echo "[$(date +%H:%M:%S)] [MONITOR] $*"; }
warn() { echo "[$(date +%H:%M:%S)] [MONITOR WARN] $*"; }
fail() { echo "[$(date +%H:%M:%S)] [MONITOR FAIL] $*"; }

log "Starting post-deployment confidence monitoring window (${WINDOW_SECONDS}s)..."

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ "$ELAPSED" -ge "$WINDOW_SECONDS" ]; then
        log "Confidence window of ${WINDOW_SECONDS}s completed successfully without critical errors."
        log "=== Post-deployment monitoring PASSED ==="
        exit 0
    fi

    POLL_COUNT=$((POLL_COUNT + 1))
    
    # Measure HTTP status and latency
    HTTP_STATS=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "${PROXY_URL}" || echo "000 0.000")
    HTTP_CODE=$(echo "$HTTP_STATS" | awk '{print $1}')
    LATENCY=$(echo "$HTTP_STATS" | awk '{print $2}')

    IS_FAILED=0
    
    if [ "$HTTP_CODE" -ne 200 ]; then
        IS_FAILED=1
    elif (( $(echo "$LATENCY > $LATENCY_THRESHOLD_SEC" | bc -l) )); then
        IS_FAILED=1
    fi

    if [ "$IS_FAILED" -eq 1 ]; then
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        WINDOW_ERRORS=$((WINDOW_ERRORS + 1))
        
        log "Poll ${POLL_COUNT}: HTTP ${HTTP_CODE} | ${LATENCY}s | elapsed: ${ELAPSED}s"
        warn "Health check failed (consecutive: ${CONSECUTIVE_FAILURES}, window errors: ${WINDOW_ERRORS})"

        if [ "$CONSECUTIVE_FAILURES" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
            fail "ROLLBACK TRIGGERED: ${MAX_CONSECUTIVE_FAILURES} consecutive health check failures"
            fail "Calling rollback.sh..."
            
            if "${SCRIPT_DIR}/rollback.sh"; then
                log "Rollback completed successfully."
                exit 1
            else
                fail "Rollback script failed!"
                exit 2
            fi
        fi
    else
        CONSECUTIVE_FAILURES=0
        log "Poll ${POLL_COUNT}: HTTP ${HTTP_CODE} | ${LATENCY}s | elapsed: ${ELAPSED}s"
    fi

    sleep "$POLL_INTERVAL"
done
