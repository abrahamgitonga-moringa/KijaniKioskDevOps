# Week 3 Engineering Reflection: Incident Management & Cloud Architecture

**Engineer:** Abraham  
**Environment:** Ubuntu 22.04 LTS (ThinkPad X12 Detachable Gen 2 / Staging Framework)  
**Date:** June 24, 2026  

---

## Question 1: The Methodology Under Pressure

In my live system investigation, the discovery of the faults did not perfectly follow Tendo’s strict top-down layout because of an immediate disk space emergency. I encountered **Fault 1 (Disk Exhaustion)** first while running baseline checks, observing that the host root partition (`/`) was at **90% utilization with only 500 MB remaining**. This forced me to pivot immediately to emergency remediation to safeguard my ThinkPad hardware from file system corruption or an OS boot loop before I could safely explore the log and network layers. 

Once the storage safety margin was expanded to a secure **2.3 GB (and later 70 GB)**, I moved to the log layer to find **Fault 2 (Socket Binding Failures)** via Nginx upstream connection drops (`111: Connection refused`). Finally, I hit the network layer to discover **Fault 3 (Firewall Block on Port 3001)** using `sudo ufw status numbered`. This adjusted sequence was far more efficient *for this specific scenario* because ignoring a 500 MB disk exhaustion warning to check network sockets first risks a complete kernel lockup mid-triage.

Jumping directly to the network layer (e.g., executing `ss` and `ufw` first) presents a severe diagnostic risk. It exposes the engineer to "tunnel vision," where they mistake a symptom for the root cause. For example, if an engineer starts at the firewall layer and notices a `DENY` rule on port 3001, they will likely delete it immediately and assume the issue is resolved. 

However, in our specific three-layer incident, unblocking the firewall while the unmanaged `rogue-server.js` was still bound to port 3001 would have driven live customer traffic directly into a malicious or broken socket handler. This would have shifted the system from a clean `502 Bad Gateway` error to catastrophic, silent data corruption or persistent `500 Internal Server Errors`, compounding the outage while the underlying disk I/O saturation continued to degrade the host kernel in the background.

---

## Question 2: The Runbook as a System Artefact

Evaluating my runbook honestly from the perspective of an external engineer who has never seen the KijaniKiosk infrastructure, two clear operational gaps stand out:
1. **Lack of Exact Service Contitution Mapping:** The runbook notes that `rogue-server.js` hijacked port 3001, but it fails to document the precise directory paths, system users, or environment profiles required to audit *how* that script executed. A guest engineer wouldn't know if this was an orphan process spawned by a developer's manual shell or an automated systemd timer unit gone rogue. To patch this, I would add specific discovery commands like `sudo lsof -i :3001` and `ps aux | grep rogue-server.js` to expose parent PID lines and execution paths.
2. **Missing Application Recovery Validation Steps:** The runbook jumps from dropping the firewall rule straight to recording verification metrics. It skips an explicit step to verify that the official application service (`systemctl restart kk-payments`) successfully re-attached to its socket after the rogue server was killed. I would add an explicit socket validation step (`sudo ss -tlnp | grep 3001`) to confirm that the official service binary, and not another competitor, claimed the interface.
The difference between an incident runbook and a playbook comes down to their lifecycle and scope. A **Runbook** is an event-driven, historical log compiled *during* an active, specific outage; it captures messy, real-time telemetry, panic pivots, and raw diagnostic data unique to that timestamp. A **Playbook** is a static, generalized, and highly polished procedural standard extracted *from* successful runbooks. An investigation becomes a playbook once an incident type repeats or demonstrates an architectural pattern. Generalization is achieved by replacing system-specific values (like PID numbers or specific log paths) with declarative, generalized workflows.

Evaluating my runbook against the Google SRE framework criteria reveals a strong foundation with clear areas for improvement:
* **Detection:** **Satisfied.** The document clearly logs initial alert entries, response timestamps, and upfront user symptoms (`502 Bad Gateway`).
* **Investigation:** **Highly Satisfied.** It traces metrics across three distinct system layers using specific command outputs (`vmstat`, `df`, `ss`).
* **Mitigation:** **Satisfied.** The step-by-step remediation guide details the explicit commands used to kill processes and clear rulesets.
* **Prevention:** **Partially Satisfied.** While it implements an explicit infrastructure-as-code fix via the `logrotate` block, it could expand further on structural monitoring metrics to stop future occurrences.

---

## 3. The Disk I/O Root Cause

The behavior of disk performance metrics varies significantly between local hardware and cloud storage abstractions. On a bare-metal server with a local SSD, the `await` metric in `iostat` (average time for I/O requests to be served) represents actual physical hardware bus latency and cell write cycles. On a cloud VM utilizing network-attached storage (such as AWS EBS), `await` represents a network round-trip across the cloud provider's internal fabric, including network encapsulation delays and shared storage host congestion. 

Consequently, a cloud VM can exhibit elevated `await` values even under negligible I/O workloads if network jitter occurs or if the VM is placed on an oversubscribed storage plane, whereas a local SSD maintains sub-millisecond latencies until it reaches absolute physical saturation.



This variance is closely tied to the I/O credit bursting mechanics used by cloud storage volumes like AWS EBS gp2. These volumes are allocated a baseline performance tier proportional to their provisioned size (e.g., 3 IOPS per GB), alongside a temporary "burst bucket" that allows performance to scale up to 3,000 IOPS for short periods. When a payment retry storm spikes or log rotation fails, a sustained write workload drains these burst credits faster than they can accumulate. Once the burst bucket hits zero, the storage volume is instantly throttled down to its low, provisioned baseline.

Before credit exhaustion, `iostat -x` logs will show relatively low `await` values (under 5–10ms), high write throughput (`wMB/s`), and low disk utilization percentages (`%util`). The moment the credits are exhausted, the output shifts dramatically: `%util` locks at **100%**, `await` spikes into hundreds of milliseconds, and throughput drops to the volume's baseline floor. 

To determine if a disk crisis is an infrastructure-level throttling issue rather than an application-level optimization flaw, the first step is to check vendor-agnostic abstraction layers and hypervisor metrics—specifically monitoring **EBS Burst Balance** in CloudWatch or checking for kernel throttling flags inside `/proc/diskstats`.

---

## 4. Monitoring Architecture

To prevent this multi-layer failure from compounding again, the KijaniKiosk staging environment requires a comprehensive, vendor-neutral monitoring topology targeting each layer independently.

| Layer / Signal | Specific Metric | Check Frequency | Alerting Threshold | Alert Recipient |
| :--- | :--- | :--- | :--- | :--- |
| **Storage Capacity** | File System Storage Utilization (`df`) | Every 5 Minutes | `>80%` Utilization (Warning)<br>`>90%` (Critical hardware risk) | DevOps Engineering On-Call Team via Pager Platform |
| **Performance Layer** | CPU I/O Wait State Metrics (`%wa`) via `vmstat` | Every 60 Seconds | `wa > 15%` sustained over 3 consecutive polling ticks | Infrastructure Team / Staging Admins |
| **Application Socket** | Synthetic TCP Port 3001 Availability | Every 30 Seconds | Connection timeout or `Refused` status on localhost | Payments Backend Engineering Team |
| **Network Security** | UFW Configuration State & Rule Ingress Maps | Every 10 Minutes | Any hash drift from the approved Tuesday baseline file | Security Engineering Team Security Log Sink |
| **Ingress Telemetry** | External HTTP Ingress Edge Error Ratios (Nginx) | Every 10 Seconds | 5xx HTTP server response codes exceeding `>2%` of total traffic over a 30s window | Core DevOps On-Call Team & Slack Incident Channel |

### Telemetry Implementation Rationale
By monitoring these signals simultaneously, the system would catch the incident long before a 502 error ever reaches a customer. If an unauthorized script attempts to inject a firewall rule, the network security monitor triggers an instant security alert. If log generation runs wild, the storage metric clears the warning threshold while hundreds of megabytes remain available, allowing automated scripts to execute clean log rotations before I/O wait states saturate the CPU. This transforms a chaotic multi-layer outage into an automated, self-healing background event.
