#!/bin/bash
# ==============================================================================
# Script Name:  kijanikiosk-provision.sh
# Description:  Automated, idempotent staging environment provisioning script.
# Author:       abraham
# Date:         June 22, 2026
# ==============================================================================

# Ensure strict error handling and pipeline safety
set -euo pipefail

log() { echo -e "[\e[34mINFO\e[0m] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
error() { echo -e "[\e[31mERROR\e[0m] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# --- Phase 1: Environment Guard Rails ---
log "=== Phase 1: Verifying Environment Guards ==="
if [ "$EUID" -ne 0 ]; then
    error "This provisioning script must be run as root."
    exit 1
fi
if [ ! -f /etc/os-release ] || ! grep -qi "ubuntu" /etc/os-release; then
    error "Unsupported Operating System. Ubuntu only."
    exit 1
fi

# --- Phase 2: Package Installation & Version Pinning ---
log "=== Phase 2: Installing and Holding Pinned Packages ==="

# SPEED OPTIMIZATION: Tell apt to skip updating man-db to prevent 3-hour freezes
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
apt-get update -qq
apt-get install -y -qq curl gnupg2 ufw

if ! command -v node &>/dev/null; then
    log "Configuring NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
fi

log "Installing nginx and nodejs..."
apt-get install -y -qq nginx nodejs
apt-mark hold nginx nodejs

# --- Phase 3: Service Account & Group Matrix Allocation ---
log "=== Phase 3: Allocating System Service Accounts ==="
if ! getent group kijanikiosk >/dev/null; then
    groupadd -r kijanikiosk
    log "Created shared application group: 'kijanikiosk'"
fi

for user in kk-api kk-payments kk-logs; do
    if ! id "$user" &>/dev/null; then
        useradd -r -s /usr/sbin/nologin -g kijanikiosk "$user"
        log "Provisioned system service account: '$user'"
    fi
done

# FIX: Dynamic user mapping so it works on your ThinkPad AND Tendo's fresh server
SUDO_REF="${SUDO_USER:-$(whoami)}"
if [ "$SUDO_REF" != "root" ]; then
    if ! groups "$SUDO_REF" | grep -q "kijanikiosk"; then
        usermod -aG kijanikiosk "$SUDO_REF"
        log "Appended user '$SUDO_REF' to supplemental group 'kijanikiosk'."
    fi
fi

# --- Phase 4: Directory Engineering & Access Control Rules ---
log "=== Phase 4: Structural Architecture & ACL Implementation ==="
mkdir -p /opt/kijanikiosk
chmod 755 /opt/kijanikiosk
chown root:root /opt/kijanikiosk

for dir in api app config logs payments scripts shared; do
    mkdir -p "/opt/kijanikiosk/$dir"
done

chown kk-api:kk-api /opt/kijanikiosk/api         && chmod 750 /opt/kijanikiosk/api
chown root:root /opt/kijanikiosk/app             && chmod 755 /opt/kijanikiosk/app
chown root:kijanikiosk /opt/kijanikiosk/config   && chmod 750 /opt/kijanikiosk/config
chown kk-logs:kk-logs /opt/kijanikiosk/logs      && chmod 750 /opt/kijanikiosk/logs
chown kk-payments:kk-payments /opt/kijanikiosk/payments && chmod 750 /opt/kijanikiosk/payments
chown root:root /opt/kijanikiosk/scripts         && chmod 755 /opt/kijanikiosk/scripts
chown root:root /opt/kijanikiosk/shared          && chmod 755 /opt/kijanikiosk/shared

mkdir -p /opt/kijanikiosk/shared/logs
chown kk-logs:kijanikiosk /opt/kijanikiosk/shared/logs
chmod 2770 /opt/kijanikiosk/shared/logs

setfacl -b /opt/kijanikiosk/config
setfacl -b /opt/kijanikiosk/shared/logs

setfacl -m "u:$SUDO_REF:rx" /opt/kijanikiosk/config/
setfacl -m g:kijanikiosk:rx /opt/kijanikiosk/config/

setfacl -m "u:kk-api:rwx,u:kk-payments:rx,u:$SUDO_REF:rx" /opt/kijanikiosk/shared/logs/
setfacl -d -m "u:kk-api:rwx,u:kk-payments:rx,g:kijanikiosk:rwx" /opt/kijanikiosk/shared/logs/

if [ ! -f /opt/kijanikiosk/config/db.env ]; then
    cat > /opt/kijanikiosk/config/db.env << 'EOF'
DB_HOST=internal-postgres.kijanikiosk.internal
DB_PORT=5432
DB_NAME=kijanikiosk_prod
DB_USER=kk_app
DB_PASSWORD=s3cr3t-pr0d-p@ssword
EOF
    chown root:kijanikiosk /opt/kijanikiosk/config/db.env
    chmod 640 /opt/kijanikiosk/config/db.env
    setfacl -m "u:$SUDO_REF:r" /opt/kijanikiosk/config/db.env
fi
log "System directory architecture and ACL layers verified."

# --- Phase 5: Hardened Systemd Engine Installation ---
log "=== Phase 5: Compiling Hardened Service Configuration ==="
cat > /etc/systemd/system/kk-api.service << 'EOF'
[Unit]
Description=KijaniKiosk Core API Engine Service
After=network.target

[Service]
Type=simple
User=kk-api
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/db.env
WorkingDirectory=/opt/kijanikiosk/api
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=30s
StartLimitBurst=3

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
PrivateDevices=true
CapabilityBoundingSet=
RestrictRealtime=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kk-api.service
log "Hardened Systemd unit file installed."

# --- Phase 6: Firewall Configuration ---
log "=== Phase 6: Executing Safe Non-Interactive Firewall Configuration ==="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'Permit administrative SSH access'
ufw allow 80/tcp comment 'Permit application HTTP access'
ufw --force enable
log "Perimeter network hardening complete."
log "=== Script Completed Execution Safely ==="
