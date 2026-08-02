# Week 7 Monday: Deployment Strategy Analysis

## Scenario 1: The Overnight Batch Processor

**Selected Strategy:** Recreate (In-Place / Big Bang)

**Justification:**
Given the tight infrastructure budget constrained to a single worker VM and zero external user traffic during the nightly execution, the Recreate strategy avoids the costs and complexity of maintaining duplicate environments. This approach satisfies the scenario's 24-hour rollback window requirement, as any batch failure can simply be reverted by re-running the prior version (v2.0.0) against the database before the next scheduled run.

---

## Scenario 2: The User-Facing Authentication Service

**Selected Strategy:** Blue/Green Deployment

**Justification:**
Blue/Green deployment is required because the breaking JWT token change lacks backward compatibility, making progressive traffic splits under a Canary rollout impossible without logging out mid-session users. Utilizing the available double-server budget, Blue/Green allows instant, atomic router switching to v2.0 for all users simultaneously while enabling a sub-5-minute rollback to the old environment if authentication error rates exceed the 1% threshold.

---

## Scenario 3: The Machine Learning Recommendation Engine

**Selected Strategy:** Canary Deployment

**Justification:**
Canary deployment allows the team to route a small percentage of live production traffic to the untested v3.0 model while maintaining the stable v2.8 baseline for the majority of users. This progressive rollout satisfies the requirement for zero-downtime rollback at any stage while allowing real-time comparison of high-compute latency against performance SLOs.

### Data Collection & Go/No-Go Signals

#### 1. Data to Collect During Deployment
* **Business Metrics:** Real-time Click-Through Rate (CTR) and conversion rates, strictly tagged by model version (`v2.8` vs `v3.0`).
* **Performance Metrics:** P95 and P99 latency per request, CPU/Memory utilization per instance, and HTTP 5xx error rates across both model versions.

#### 2. Go/No-Go Signals Per Stage
* **Stage 1 (5% Traffic Canary):** 
  * *Go Signal:* Zero increase in 5xx error rates and P95 latency remains within the defined SLO over a 15-minute observation window.
  * *No-Go Signal:* Any memory leak, unexpected CPU throttling, or P95 latency exceeding the SLO triggers an immediate traffic rollback to 0%.
* **Stage 2 (25% to 50% Traffic Expansion):** 
  * *Go Signal:* System resource consumption scales linearly, latency remains stable, and initial telemetry demonstrates a positive trend toward the targeted +15% CTR improvement.
  * *No-Go Signal:* CTR drops below the baseline v2.8 model or latency degraded past SLO limits.
* **Stage 3 (100% Full Promotion):** 
  * *Go Signal:* Telemetry confirms a statistically significant CTR increase near or at the +15% goal with stable system latency across full production load.
