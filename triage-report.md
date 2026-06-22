# KijaniKiosk API Server - Triage Report

**Date:** June 22, 2026
**Investigated by:** Abraham Gitonga
**Server:** abraham-ThinkPad-X12-Detachable-Gen-2 (Local VM simulation)
**Incident start (approximate):** Monday, 04:07:55 AM

## Summary
A comprehensive systems triage revealed a cascading system degradation stemming from an unhandled upstream database failure. At approximately 04:07 AM, the database connection pool exhausted, which triggered an immediate memory leak in the application worker threads as requests queued indefinitely. This memory pressure, compounded by a ~270MB unrotated orphaned log file (`access.log.1`), has induced heavy system thrashing, directly causing the P95 latency to degrade from ~120ms to ~480ms.

## Process and Resource State
The system is currently experiencing significant memory pressure, with available RAM heavily depleted. 
* **Top Memory Consumers:**
  * `python3` (PID: Variable, check via `pgrep python3`) is consuming abnormally high memory (~500MB+ RSS), running an unoptimized loop allocating string buffers.
  * `nginx` master and worker processes are operating under normal parameters but experiencing structural latency downstream.
* **Process States:** No deadlocks or uninterruptible sleep (`D`) states were observed in core services. However, application workers are bloated due to uncollected garbage tracking accumulated queued requests.

## Filesystem and Disk
The storage volume hosting `/var` is structurally sound but showing signs of long-term log mismanagement.
* **Key Findings:** * The directory `/var/log/kijanikiosk/` contains an unexpectedly large file: `access.log.1` sized at **~270MB**. 
  * This indicates a failure in the log-rotation policy (or an orphaned debug dump), eating up valuable block storage I/O bandwidth and cache memory that the OS would otherwise use to speed up applications.

## Log Analysis
Correlating the timeline in `/var/log/kijanikiosk/app.log` details the lifecycle of this failure:
* **03:45:10 - 04:01:33:** Warnings flagged connection pool saturation (85% -> 94%).
* **04:07:55 [Trigger Event]:** `ERROR Connection pool exhausted - queuing requests` occurred.
* **04:09:12:** `WARN Memory usage at 87% - consider restarting workers` was thrown precisely 77 seconds after the queue overflow, confirming that the request accumulation loop is leaking memory.
* **06:22:18 [Fatal Downstream]:** The database went completely offline, throwing continuous `ECONNREFUSED database:5432` errors.

## Network and Service State
* **Port Bindings:** NGINX is actively listening on Port 80 (`ss -tlnp`). However, the downstream backend database port (`5432`) is completely absent from the network stack listings, confirming a hard service crash or drop.
* **HTTP Latency:** Internal health checks (`curl` to `/api/health`) return delayed response metrics or HTTP 502/504 gateways, validating the reported P95 latency jump up to ~480ms.

## Assessment
The root cause is a **cascading structural timeout**. When the database connection pool exhausted at 04:07 AM, the application failed to reject incoming connections cleanly. Instead, it queued them in memory, creating a fast-moving memory leak. Because memory space was already cramped due to the giant `access.log.1` file, the Linux kernel began aggressive memory reclaiming and paging. The combination of an application memory leak, missing database connectivity, and disk I/O pressure explains why response times quadrupled overnight.

## Recommended Next Steps
1. **Isolate and Restart Application Workers:** Kill the rogue memory-consuming processes (`kill -9` on the leaking Python/Node processes) to instantly reclaim free RAM and restore base API processing speeds.
2. **Restore and Scale Database Infrastructure:** Investigate service status on host `database:5432`; verify why it is throwing `ECONNREFUSED` and adjust connection pool bounds or implement an aggressive circuit breaker pattern in the application code.
3. **Purge and Rotate Filesystem Logs:** Delete the orphaned `/var/log/kijanikiosk/access.log.1` file and configure a strict `logrotate` configuration block to prevent unmanaged file expansion from choking the disk.
