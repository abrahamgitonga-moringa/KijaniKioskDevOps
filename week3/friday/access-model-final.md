# KijaniKiosk Production Access Model Blueprint & Permission Matrix

## 1. Directory Structure and Base POSIX Permissions

| Directory Path | Intended Purpose | Owner User | Primary Group | Standard Mode |
| :--- | :--- | :--- | :--- | :--- |
| `/opt/kijanikiosk` | Application Deployment Root | `root` | `kijanikiosk` | `0755` |
| `/opt/kijanikiosk/config` | Secrets and Environment Files | `kk-api` | `kijanikiosk` | `0750` |
| `/opt/kijanikiosk/shared/logs` | Inter-service Transaction Logs | `kk-api` | `kijanikiosk` | `0770` |
| `/opt/kijanikiosk/health` | Automated Infrastructure Monitoring | `kk-logs` | `kijanikiosk` | `0750` |

---

## 2. Access Control List (ACL) Layer Specifics

To enforce strict separation of duties, standard Linux user/group boundaries are enhanced with POSIX Access Control Lists (ACLs) to manage access to `/opt/kijanikiosk/shared/logs`:

* **`kk-api` (Owner Context):** Allocated full access (`rwx`) to facilitate low-overhead file generation and continuous append operations.
* **`kk-payments` (Financial Processor):** Granted access (`r-x`) to allow real-time audit correlation across system blocks without modifying logs.
* **`kk-logs` (Aggregator Node):** Configured with standard access (`r-x`) to cleanly transport uncompressed streams out of the local system space.
* **Inheritance Layer Rule:** The directory default mask is explicitly locked with `default:user::rwx`, `default:group::r-x`, and `default:mask::r-x`. This ensures that newly generated data payloads instantly inherit these strict permissions, preventing lockouts during rotation.

---

## 3. Logrotate System Integration Parameters

The integration challenge between standard log rotation and our custom access control layer has been resolved. When the log utility cycles files via cron, it strips active user permissions unless explicit overrides are defined. 

Our production script resolves this by passing an explicit creation payload inside `/etc/logrotate.d/kijanikiosk`:
```text
create 0640 kk-api kijanikiosk
