# Thursday Challenge Lab: AI-Assisted DevOps Governance & Safety

**Name:** Abraham  
**Repository:** `kijanikiosk-devops`  
**Path:** `~/Documents/kijanikiosk-devops/week10/thursday/`  
**Date:** August 16, 2026  

---

## Deliverable 1: AI-Assisted Log Analysis Comparison Table

### Incident Log Analysis (kk-payments Incident: 02:14 EAT)

| Analysis Point | My Manual Finding | AI Finding | Agreement / Discrepancy |
| :--- | :--- | :--- | :--- |
| **1. Incident start timestamp and first signal** | **Finding:** Starts at `2024-11-15T02:10:01Z` with `msg: "db.pool.utilisation"` showing `active: 18, waiting: 2`. <br>**Location:** Log line 5. | **AI Finding:** "The incident began at `2024-11-15T02:10:01Z` when the `db.pool.utilisation` warning logged 18 active connections out of 20 with 2 requests waiting." | **Agree:** Both identified the precise warning timestamp and pool utilization log prior to the first connection timeout error at `02:10:28Z`. |
| **2. Root cause mechanism** | **Finding:** Database connection pool exhaustion/starvation (`poolSize: 20`). <br>**Location:** Log lines 7, 9, 12, 17 (`error: "connection acquire timeout"` and `reason: "db.connection.timeout"`). | **AI Finding:** "Root cause is database connection pool exhaustion. The application reached its maximum pool limit of 20 connections, causing incoming requests to timeout after 5 seconds waiting for a connection." | **Agree:** Both identified database connection pool capacity limits and connection acquire timeouts as the primary root cause. |
| **3. Scaling action effect** | **Finding:** Did NOT fix the issue; worsened queueing. Pod scaling added more connection clients competing for the same DB pool. <br>**Location:** `02:12:19Z` (`replica.added`) followed immediately by `02:12:20Z` (`waiting: 22`) and timeouts at `02:12:21Z` & `02:12:22Z`. | **AI Finding:** "The horizontal scaling at 02:12:19 did not resolve the issue. Adding a replica increased database load/competition, causing waiting connections to jump from 14 to 22 at 02:12:20Z and triggering further payment failures." | **Agree:** AI correctly identified that adding replicas increased pressure on the fixed pool size rather than relieving it. |
| **4. ConfigMap reload interpretation** | **Finding:** An engineer attempted a hot-fix to increase `MAX_CONNECTIONS`, but set `newValue` to `20` (same as `oldValue`). <br>**Location:** `02:11:33Z` (`config.reload` and `config.reload.no-change`). | **AI Finding:** "Indicates an attempted manual remediation to increase `MAX_CONNECTIONS`. However, the reload failed to change the setting because both `oldValue` and `newValue` were '20', resulting in no effective change." | **Agree:** Both recognized the human intervention attempt and noted that the configuration change was ineffective due to identical old and new values. |
| **5. Incident resolution status** | **Finding:** Stabilizing but NOT fully resolved. Traffic is succeeding (`02:13:01Z`, `02:13:44Z`), but pool is still near capacity (`active: 19`, `waiting: 3`). <br>**Location:** `02:14:02Z` (`db.pool.utilisation`). | **AI Finding:** "The incident is partially mitigated but not fully resolved. Successful payments returned at 02:13:01Z, but as of 02:14:02Z, pool utilization remains high (19 active, 3 waiting), leaving the system vulnerable to another traffic burst." | **Agree:** Both noted that while errors stopped and payments resumed, the non-zero waiting queue (`waiting: 3`) means the underlying risk remains. |

---
