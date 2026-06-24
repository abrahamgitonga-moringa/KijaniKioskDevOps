# KijaniKiosk Staging Environment Incident Runbook

**Incident Classification:** Intermittent 502 Bad Gateway Outage (Staging Payments Endpoint)  
**Target Environment:** Ubuntu 22.04 LTS (ThinkPad X12 Detachable Gen 2)  
**Assigned Engineer:** Abraham  

> "I have read the setup script. I understand what it does in general terms. 
> I commit to treating the server as a black box during investigation and not 
> referring back to the script until my runbook is complete."
> 
> **Investigation Start Timestamp:** 2026-06-22 16:05:00 EAT  
> **Resolution Timestamp:** 2026-06-22 17:58:12 EAT  
> **Total Triage Time:** 1 Hour 53 Minutes (Note: Extended due to real-time low-disk-space emergency remediation to prevent hardware lockup).

---

## 1. Incident Summary & Symptoms
At approximately 16:05 EAT, the KijaniKiosk staging server began reporting intermittent `502 Bad Gateway` errors from the core payments endpoint (`:3001`), threatening an upcoming live product demo. Initial black-box monitoring indicated concurrent degradation across system performance, application log outputs, and network layer boundaries.

---

## 2. Phase 1 & 2 Findings: Performance and Log Layers

### Performance Layer Observations
* **System I/O Wait (`wa`):** Initial telemetry spikes showed CPU storage wait states climbing drastically, indicating severe disk I/O saturation.
* **Blocked Processes (`b`):** The `vmstat` queue registered blocked tasks waiting exclusively for disk read/write cycles to clear.
* **Disk Spatial Capacity (`df -h`):** The host root partition (`/`) hit **90% utilization**, leaving a critical safety margin of only **500 MB** of free storage. 
* **Log Directory Volume:** Checking `/opt/kijanikiosk/shared/logs/` revealed an abnormal expansion of uncompressed `.log` assets totaling **1.6 GB**.

### Log Layer Observations
* **Nginx Error Streams:** Upstream routing flags inside `/var/log/nginx/error.log` recorded connection drops and `111: Connection refused` hooks when attempting to reverse-proxy traffic down to port 3001.
* **Application Service Journals:** `journalctl -u kk-payments` flagged socket binding failures, indicating that the core payment app could not attach to its designated port.

### Initial Diagnostic Hypothesis
> "I believe the 502 errors are caused by high CPU storage wait states (`wa`) and disk space exhaustion, suggesting unmanaged log replication has saturated write I/O. Simultaneously, application-layer socket errors indicate a port contention vector or local socket crash. My next step is to map local socket bindings and network rulesets to identify port blocks."

---

## 3. Phase 3 Findings: Network Boundary Anomalies
A comprehensive inspection of network sockets (`ss -tlnp`) and firewall vectors uncovered two critical flaws:
1.  **Port Contention (Contender Process):** A rogue user-space execution context running a raw Node server (`rogue-server.js`) had bound itself to `127.0.0.1:3001`, blocking the official `kk-payments` service from capturing its socket.
2.  **Firewall Isolation Block:** The `ufw` ruleset contained a malicious security policy explicitly blocking traffic on the payment engine's port:
    ```text
    [ 3] 3001/tcp                    DENY IN     Anywhere                   # MISCONFIGURED: blocks health checks
    ```
    This rule completely severed health check visibility from external load balancers, prompting persistent upstream gateway routing dropouts.

---

## 4. Root Cause Analysis (The Three Injected Faults)
The outage was driven by a triad of compounding faults:
1.  **Fault 1 (Disk Exhaustion):** Creation of 1.6 GB of unrotated, uncompressed random stream transaction logs under `/opt/kijanikiosk/shared/logs/`. This induced heavy write I/O wait states and brought the host filesystem down to a dangerous 500 MB capacity limit.
2.  **Fault 2 (Port Collision):** An unmanaged rogue background script (`rogue-server.js`) hijacked network port `3001`, forcing an internal application routing conflict.
3.  **Fault 3 (Network Block):** A misconfigured local firewall policy (`ufw deny 3001/tcp`) dropped incoming monitoring packets, blinding the load balancers and throwing `502 Bad Gateway` metrics.

---

## 5. Remediation Playbook (Executed Order & Commands)

### Step 1: Emergency Storage Reclamation (Hardware Protection Pivot)
* **Rationale:** Because host space dropped to a critical 500 MB threshold, immediate disk clearing took absolute priority over standard staging operations to prevent a complete system crash or OS boot loop.
* **Action Run:**
    ```bash
    sudo rm -f /opt/kijanikiosk/shared/logs/payments-2024-03-*.log
    ```
* **Result:** Reclaimed 1.6 GB of space instantly, expanding the safety cushion back up to a healthy **2.3 GB available** (subsequently scaled up to 70 GB permanently).

### Step 2: Port Contention Resolution
* **Rationale:** Safely terminate the unauthorized socket contender using standard exit signals before applying aggressive kernel overrides.
* **Action Run:**
    ```bash
    sudo pkill -f rogue-server.js
    ```
* **Result:** Port 3001 was instantly released and made clean for standard systemd services.

### Step 3: Firewall Access Posture Restoration
* **Rationale:** Drop the block policies to let system health-checks traverse the network border safely.
* **Action Run:**
    ```bash
    sudo ufw delete deny 3001/tcp
    sudo ufw reload
    ```
* **Result:** Restored network compliance back to ports 22 and 80 exclusively.

---

## 6. Fix Order Rationale & Counterfactual Impact

### Why Fix 1 & 2 Take Precedence Over Fix 3 Under Normal Operations
In a standard production tier, an engineer must terminate the rogue port socket handler (Fix 1) and drop the firewall blocks (Fix 2) first. These steps immediately stop the 502 gateway errors and restore traffic routing capabilities within seconds. 

### What Happens If You Apply Fixes Out of Order?
* **Running Logrotate (Fix 3) First:** Forcing a compression run on massive multi-gigabyte log assets while an I/O crisis is already occurring will cause a massive CPU spike. This can freeze the database entirely and worsen the outage.
* **Clearing the Firewall (Fix 2) Before Killing the Rogue Server (Fix 1):** If the firewall is unlocked while the rogue server still owns port 3001, external traffic will hit the bad process. The monitoring console will see valid connections, but customers will receive legitimate `500 Internal Server Errors` directly from the rogue app rather than a clean gateway error.

---

## 7. Operational Prevention Controls

### A. Infrastructure-As-Code (IaC) Enhancements
To permanently secure staging servers against drift, the core Wednesday provisioning script (`kijanikiosk-provision.sh`) was updated to include a structured, automated log management phase:

```bash
# Append to Phase 7: Persistent Infrastructure Logging Framework Configuration
provision_logging() {
    cat > /etc/logrotate.d/kijanikiosk << 'EOF'
/opt/kijanikiosk/shared/logs/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        systemctl reload nginx 2>/dev/null || true
    endscript
}

### B. Architectural Guard Rails
1.  **Staging Spatial Monitoring:** Implement an automated alert that fires when disk capacity hits 80%, giving engineers plenty of warning before the system reaches the 500 MB danger zone.
2.  **Socket Validation Checks:** Modify continuous deployment hooks to sweep ports before startup via `ss -tlnp | grep 3001`, automatically killing dangling developer processes before a deployment begins.
