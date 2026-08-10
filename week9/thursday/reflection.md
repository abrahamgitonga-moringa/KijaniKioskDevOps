## Thursday Lab Analysis: Nia's Readiness Probe Sequence

**Question:** *Nia asks: "If the readiness probe on a Pod fails during a high-traffic period, what exactly happens to that Pod? Does it restart? Does traffic stop going to it? Can it recover without a deployment? Walk me through the sequence."*

### Step-by-Step Technical Sequence:

1. **Probe Failure Threshold Breached:** 
   During a spike in traffic, a Pod's application thread or connection pool becomes saturated, causing `/health` to return non-2xx status codes or time out. Once the failure count reaches the configured `failureThreshold` (3 consecutive failures), the `kubelet` marks the readiness status of that specific Pod container as `FALSE`.

2. **Immediate Removal from Endpoints (Traffic Halts):**
   The Kubernetes Endpoint Controller immediately observes the readiness status change and removes the Pod's IP address from the `kk-payments` **Endpoints / EndpointSlice** object. 

3. **Ingress and Service Routing Updates:**
   The Ingress Controller (and `kube-proxy`) continuously monitors the Service's Endpoints. As soon as the Pod IP is removed from Endpoints, **new incoming HTTP traffic stops being routed to that Pod immediately**. The Pod is completely isolated from production user requests.

4. **No Container Restart:**
   The container **does NOT restart**. Unlike a liveness probe failure, a readiness probe failure strictly affects routing, not process lifecycle. The container process continues running unabated.

5. **Self-Healing & Traffic Recovery without Deployment:**
   Because no new traffic is reaching the isolated Pod, its internal processing queue and database connection pool can drain and cool down. Once the application recovers and the `/health` endpoint succeeds on the next check, the `kubelet` marks readiness as `TRUE`. The Endpoint Controller re-adds the Pod IP back to the Service Endpoints list, and **traffic resumes automatically**—all without any manual intervention, container restarts, or deployment rollouts.
