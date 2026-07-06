# Operational Integration Engineering Resolution Report

## Challenge A: ProtectSystem=strict vs. EnvironmentFile Storage Routing
* **The Conflict Architecture:** Activating `ProtectSystem=strict` mounts the host directory layout as completely read-only for the application context. If configuration keys or secret parameters are stored in areas that are locked down, the application will crash during startup because it cannot load its configuration.
* **Evaluated Options:** 1. Store secrets in `/etc/kijanikiosk/` and add explicit system exception rules.
  2. Maintain configuration payloads under `/opt/kijanikiosk/config/` and use explicit systemd exceptions.
* **Selected Path & Architectural Rationale:** We chose to place our configuration environment files under `/opt/kijanikiosk/config/`, combined with an explicit `EnvironmentFile=` directive. Because systemd handles environment loading *before* dropping privileges and enforcing sandbox restrictions, the application can securely read its runtime tokens while maintaining an entirely read-only filesystem environment during operation.

---

## Challenge B: Monitoring Namespace Access Validation & ACL Defaults
* **The Conflict Architecture:** The health status checkpoint engine runs under administrative root privileges, generating a reporting file (`last-provision.json`) owned exclusively by root. However, Amina's unprivileged user and our automated monitoring nodes require constant access to these files without using `sudo`.
* **Evaluated Options:**
  1. Add wide permissions (`chmod 777`) to eliminate access errors.
  2. Implement an automated ownership mapping policy inside the provisioning runtime.
* **Selected Path & Architectural Rationale:** We created a dedicated monitoring status directory (`/opt/kijanikiosk/health/`) owned by `kk-logs:kijanikiosk` with an explicit group directory permission mask of `0750`. This approach keeps reporting secure, allows monitoring agents to read health data safely without broad access permissions, and keeps health tracking separated from application data.

---

## Challenge C: Logrotate Postrotate Signals and PrivateTmp Isolation
* **The Conflict Architecture:** The log manager shifts file handles and sends a `systemctl reload` trigger to clear open descriptors. However, the log microservice runs inside an isolated namespace (`PrivateTmp=true`). This isolation can break standard signaling pipelines if they rely on shared temporary space.
* **Evaluated Options:**
  1. Remove `PrivateTmp=true` to restore standard signaling paths.
  2. Transition signaling from system-wide reloads to focused process triggers using `HUP` kernel parameters.
* **Selected Path & Architectural Rationale:** We opted to retain `PrivateTmp=true` to preserve security boundaries. We updated the post-rotation workflow to use a direct, scoped signal: `systemctl kill -s HUP kk-logs.service`. This method bypasses shared filesystem space entirely by using direct kernel communication channels to notify the service without restarting it.

---

## Challenge D: Dirty VM State Remediation and Immutable Package Anchoring
* **The Conflict Architecture:** Executing a provisioning run on a dirty machine can trigger unintended application downgrades or failures if system files have been modified or upgraded during the week.
* **Evaluated Options:**
  1. Clear the system and run a complete reinstall on every execution.
  2. Use programmatic checks to compare active package versions against definitions, skipping the install if they match.
* **Selected Path & Architectural Rationale:** We built an explicit conditional check into the script layout. The system queries active packages using `nginx -v`. If the installed software matches our production profile, the script skips the installation step entirely and logs the event. This approach ensures idempotency on dirty hosts, prevents accidental package updates, and maintains server stability across multiple runs.
