# KijaniKiosk Access Model Design Table

| Directory Path | Owner | Group | Mode | ACL Rules Applied | Architectural Reasoning |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/opt/kijanikiosk/api/` | `kk-api` | `kk-api` | `750` | None | Limits exposure to the API engine. Denies cross-service reads. |
| `/opt/kijanikiosk/payments/` | `kk-payments` | `kk-payments` | `750` | None | Secures sensitive financial processing blocks from other user spaces. |
| `/opt/kijanikiosk/logs/` | `kk-logs` | `kk-logs` | `750` | None | Secures log monitoring assets from external modifications. |
| `/opt/kijanikiosk/config/` | `root` | `kijanikiosk` | `750` | `u:amina:r` | Root retains ownership; `kijanikiosk` group allows app read access; ACL grants `amina` audit reads without root access. |
| `/opt/kijanikiosk/shared/logs/` | `kk-logs` | `kijanikiosk` | `2770` | `u:kk-api:rwx`, `u:kk-payments:rx`, `u:amina:rx` | `2` (SetGID) forces files to inherit the `kijanikiosk` group. ACLs grant tailored cross-component capabilities. |

### ACL vs. Basic Permissions Choice
Standard UGO permissions only allow defining a single user and a single group owner. For complex shared environments like `/opt/kijanikiosk/shared/logs/`, where `kk-api` must write, `kk-payments` must read, and `kk-logs` must manage, standard POSIX bits break down. ACLs allow us to extend permissions to multiple independent system entities without weakening security bounds.
