# Production Readiness Assessment: KijaniKiosk Deployment

## 1. External Routing and Security
The current Ingress configuration is insufficient for production because traffic is transmitted unencrypted over HTTP. For a payment service handling credit card tokens and JWTs, plain HTTP exposes credentials to packet sniffing and man-in-the-middle (MITM) attacks. 

To resolve this:
- **TLS Termination:** We must configure TLS termination at the Ingress by defining a `tls` block referencing a secret containing valid TLS certificates (`tls-secret`). We must also set the annotation `nginx.ingress.kubernetes.io/ssl-redirect: "true"` to enforce HTTPS.
- **Traffic Protection:** Beyond encryption, the system lacks rate limiting. Unrestricted endpoints leave `kk-payments` vulnerable to brute-force or Denial-of-Service (DoS) attacks. We should implement the annotation `nginx.ingress.kubernetes.io/limit-rps: "10"` to restrict each client IP to a safe threshold.

## 2. Health Signaling and Probes
The current probe thresholds (`initialDelaySeconds: 5`, `failureThreshold: 3`) carry operational risks under production payment conditions. If `kk-payments` experiences temporary database connection throttling during peak load, response latency will spike. 

With `failureThreshold: 3` checked every 10 seconds, Kubernetes will declare the container unhealthy within 30 seconds and terminate it. Under heavy traffic:
1. Restarting pods drops in-flight payment transactions mid-checkout.
2. Cascading failures occur as remaining pods absorb the redirected load, causing them to fail probes and crash as well.

**Production Recommendation:** Increase `initialDelaySeconds` to `15` to allow database connection pools to warm up, increase `failureThreshold` on readiness probes to `6`, and use startup probes (`startupProbe`) to isolate initialization delays from runtime readiness checks.

## 3. Capacity and Autoscaling Strategy
Relying on 3 static replicas with manual scaling cannot handle unpredictable end-of-month traffic spikes. Implementing automated scaling requires a deployed `metrics-server`, explicit container CPU/Memory `requests`, and a configured Horizontal Pod Autoscaler (`HPA`).

HPA threshold selection carries distinct operational risks:
- **Target CPU set too high (e.g., 90%):** Pods become saturated before the HPA can spin up new replicas. Because Kubernetes requires 1–3 minutes to schedule, pull images, and pass readiness probes, the system will drop incoming customer payment requests due to queue exhaustion before new capacity goes live.
- **Target CPU set too low (e.g., 20%):** Normal background spikes or garbage collection cycles trigger unnecessary pod creation ("thrashing"). This wastes cloud compute budget and exhausts downstream database connection limits.

**Production Recommendation:** Target an optimal HPA CPU utilization threshold of **65%–70%** with a minimum of 3 and a maximum of 10 replicas.
