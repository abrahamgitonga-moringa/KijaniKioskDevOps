# Systemd Hardening Telemetry Journal: kk-payments.service

## 1. Baseline Benchmark Profile
* **Initial Telemetry Score:** `9.6 / 10 (UNSAFE)`[cite: 4]
* **Assessment Summary:** The default service configuration granted the application context wide access to core system calls, network sockets, and kernel resources.[cite: 4]

---

## 2. Iterative Hardening Phases & Score Delta Tracking

### Step 1: Privilege Escalation and Identity Sandbox
* **Directives Added:**
```ini
  NoNewPrivileges=true
  CapabilityBoundingSet=
  ```[cite: 4]
* **Score Delta:** Dropped from `9.6` to `6.8`[cite: 4]
* **Impact Analysis:** Prevents the system context from invoking setuid binaries or executing root privilege escalation hooks. The application cannot escalate out of its sandbox.[cite: 4]

### Step 2: File System Perimeter Shielding
* **Directives Added:**
```ini
  ProtectSystem=strict
  ProtectHome=true
  PrivateTmp=true
  ReadWritePaths=/opt/kijanikiosk/shared/logs/
  ```[cite: 4]
* **Score Delta:** Dropped from `6.8` to `4.1`[cite: 4]
* **Impact Analysis:** Mounts the entire host OS directory tree as read-only for this process. It isolates user home environments and shields temporary directories via isolated mount spaces, while maintaining an explicit append vector on log files.[cite: 4]

### Step 3: Kernel Layer and Syscall Isolation
* **Directives Added:**
```ini
  ProtectKernelTunables=true
  ProtectControlGroups=true
  RestrictSUIDSGID=true
  MemoryDenyWriteExecute=true
  ```[cite: 4]
* **Score Delta:** Dropped from `4.1` to `2.3`[cite: 4]
* **Impact Analysis:** Blocks changes to hardware configurations or kernel parameters via `/proc/sys`. It completely stops the allocation of memory spaces that are simultaneously writable and executable, protecting against remote memory injection vulnerabilities.[cite: 4]

---

## 3. Alternative Hardening Paths Evaluated and Rejected

### Rejected Directive 1: `ProtectHome=strict`
* **Reason for Rejection:** Applying this directive conflicts with local development setups and shared credential files, causing the application framework to crash on startup during user profile loading.[cite: 4]

### Rejected Directive 2: `PrivateDevices=true`
* **Reason for Rejection:** The payment validation suite uses a specialized hardware security module interface (`/dev/hsm0`) to verify transactional message authentication codes. Restricting the system device namespace completely removes access to this cryptographic bus, causing payments to fail silently.[cite: 4]

---

## 4. Hardened Production Service Configuration Profile

```ini
[Unit]
Description=KijaniKiosk Financial Payments Processing Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
WorkingDirectory=/opt/kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/node -e "console.log('Production engine active'); setInterval(() => {}, 1000);"
Restart=always

# Production Security Isolation Posture Matrix (Score: 2.3)
CapabilityBoundingSet=
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/kijanikiosk/shared/logs/
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
```[cite: 4]
