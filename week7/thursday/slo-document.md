# KijaniKiosk Service Level Objectives

## kk-api (API Service)

### SLIs
1. **Availability SLI:** Measures the proportion of successful HTTP requests returned by the proxy endpoint. It is collected via Nginx ingress access logs filtering for HTTP status codes `2xx` and `3xx` divided by total requests.
2. **Latency SLI:** Measures request execution duration at the 95th percentile ($P_{95}$). It is collected using Prometheus metrics emitted by the `kk-api` Express HTTP request latency histogram over 5-minute rolling windows.
3. **Error rate SLI:** Measures unhandled server-side processing failures. It is collected via Prometheus counter metrics calculating `5xx` response codes divided by total requests across all `/api/v1/*` endpoints.

### SLOs

| SLI | Target | Window | Error budget |
|-----|--------|--------|--------------|
| Availability | 99.9% | 30 Days | 43.2 minutes downtime |
| Latency ($P_{95}$) | < 200ms | 30 Days | 36.0 hours total window variance |
| Error Rate | < 0.1% | 30 Days | 43,200 failed requests per 43.2M total |

### Rollback threshold justification
The thresholds in `post-deploy-monitor.sh` (3 consecutive failures over 15 seconds, >2s latency threshold) are **significantly more conservative** than our 30-day SLO targets. 

This design is intentional: an SLO measures long-term reliability commitments over a 30-day rolling window, whereas deployment monitoring protects the system during high-risk state changes. A deployment triggering 3 consecutive 5-second failures consumes approximately `0.0006%` of the monthly availability error budget (`0.25` minutes of `43.2` total budget minutes). Tripping rollbacks early guarantees that deployment anomalies are halted long before they threaten or exhaust the monthly SLO error budget.

---

## kk-payments (Payments Service)

### SLIs
1. **Transaction Success Rate SLI:** Measures the proportion of valid payment attempts that receive a terminal `200 OK` settlement response. It is collected using application-level gateway log counters comparing successful transactions against total attempts.
2. **Transaction Latency SLI:** Measures end-to-end payment settlement time at the 99th percentile ($P_{99}$). It is collected via payment gateway client instrumentation metrics measuring time elapsed from request dispatch to callback receipt.
3. **Payment Error Rate SLI:** Measures failed gateway integration requests excluding end-user declines (e.g., insufficient funds). It is collected by tracking non-user-caused `5xx` and payment gateway timeout events.

### SLOs

| SLI | Target | Window | Error budget |
|-----|--------|--------|--------------|
| Transaction Success Rate | 99.95% | 30 Days | 21.6 minutes downtime |
| Transaction Latency ($P_{99}$) | < 1500ms | 30 Days | 7.2 hours total window variance |
| Payment Error Rate | < 0.05% | 30 Days | 21,600 failed requests per 43.2M total |

### Rollback threshold justification
Payment failures directly impact revenue and user trust. The payment gateway rollback monitor uses an aggressive threshold of **2 consecutive transaction timeouts or HTTP 5xx errors**. This threshold ensures that any bad release affecting payment settlement is halted within 10 seconds, preserving 99.99% of the error budget for external gateway provider outages outside our control.
