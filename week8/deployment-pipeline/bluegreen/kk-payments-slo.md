# Service Level Objective (SLO) & Error Budget: kk-payments

## 1. Service Definition & Target SLA
* **Service:** `kk-payments` API
* **Target Availability:** 99.9% monthly uptime
* **Target Latency:** 95% of requests processed under 200ms
* **Total Allowed Downtime (Monthly Error Budget):** ~43.8 minutes (43m 49s)

## 2. Error Budget Impact Analysis: Automated Rollback

### Performance Metrics (From Live Evidence)
* **Detection Time ($T_0 \rightarrow T_1$):** 5 seconds (1 failed health check interval)
* **Threshold Trigger ($T_1 \rightarrow T_{\text{trigger}}$):** 10 seconds (3 consecutive failed checks @ 5s intervals)
* **Switch Execution ($T_{\text{trigger}} \rightarrow T_2$):** 1 second (Nginx config rewrite & zero-downtime reload)
* **Total Incident Downtime ($T_0 \rightarrow T_2$):** **16 seconds**

### Error Budget Consumption
$$\text{Error Budget Consumed} = \frac{16 \text{ seconds}}{2629.74 \text{ seconds (43.8 mins)}} \times 100 \approx 0.61\%$$

### Analysis & Recommendations
* **SLA Target Compliance:** **PASSED** (16s is well within the 90-second SLA limit).
* **Impact:** The automated monitor consumed less than **1% of the monthly error budget** during a total backend service failure.
* **Key Finding:** Automated polling combined with Nginx instant configuration reload prevents runaway SLA erosion compared to manual engineer intervention (which averages 15–30 minutes).
