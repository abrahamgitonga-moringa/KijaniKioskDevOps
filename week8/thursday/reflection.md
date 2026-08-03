# Reflection and Engineering Thinking: Kubernetes Objects

## Question 1: The Declarative Model and `kubectl apply`

### Re-applying Unchanged Manifests
When `kubectl apply -f kk-payments-deployment.yaml` is run a second time without modifications, the Kubernetes API server compares the incoming manifest with the **desired state** stored in `etcd` and the **current actual state** of the cluster. Because there are no delta changes between the declared specification and the active cluster state, the **reconciliation loop** takes no action.
* **Cluster Changes:** Zero changes are made (no Pods are recreated, updated, or restarted).
* **Command Output:** `deployment.apps/kk-payments unchanged`

### Updating Replicas (`replicas: 2` → `replicas: 3`)
If only the `spec.replicas` field is changed from `2` to `3` and re-applied:
1. **Reconciliation Loop Trigger:** The Deployment controller detects a delta: Desired (`3`) ≠ Actual (`2`).
2. **Object Escalation:** The Deployment controller updates its underlying **ReplicaSet** object (`kk-payments-<hash>`), changing its desired replica count to 3.
3. **Pod Creation:** The ReplicaSet controller requests the API server to create one new Pod object.
4. **Scheduling & Binding:** The `kube-scheduler` assigns the new Pod to an available node, and the local `kubelet` pulls the image (or uses local cache) and launches the container.
* **Objects Changed:** 
  * `Deployment` (`spec.replicas` updated)
  * `ReplicaSet` (`spec.replicas` updated)
  * `Pod` (1 new Pod object created)
* **Duration:** Because the container image is already cached on the node from the previous two replicas, the new Pod transitions from `Pending` → `ContainerCreating` → `Running` in approximately **1 to 3 seconds**.

---

## Question 2: Resource Requests, Limits, and the Scheduler

### Scenario (a): Pod attempts to allocate 300MB of memory (Limit = 256Mi)
* **Behavior:** **OOMKilled (Out of Memory Killed)**
* **Explanation:** While CPU throttling occurs when CPU limits are exceeded, Memory is a hard limit. The Linux kernel's cgroups enforcer inside the container runtime monitors memory usage. The moment the process memory allocation exceeds the declared limit of `256Mi` (300MB > 256MB), the kernel sends a `SIGKILL` to the process. Kubernetes marks the container status as `OOMKilled`, terminates it, and the kubelet restarts the container according to the Pod's `restartPolicy`.

### Scenario (b): Adding a 3rd replica when node has 100MB unallocated memory (Request = 64Mi)
* **Behavior:** **Successfully Scheduled and Started**
* **Explanation:** The `kube-scheduler` makes placement decisions based on **Resource Requests**, *not* Resource Limits. The new Pod requests `64Mi` of memory. Since `64Mi` is less than the node's `100MB` (~95.3Mi) available allocatable capacity, the scheduler successfully binds the Pod to the node. (Note: If the request had been larger than 100MB, the Pod would remain in a **`Pending`** state indefinitely until capacity became available).

### Scenario (c): Unconstrained 2nd workload consumes all available node memory
* **Behavior:** **Pod Eviction / Node Pressure OOM**
* **Explanation:** Kubernetes assigns a **Quality of Service (QoS)** class to every Pod based on its requests and limits:
  1. `Guaranteed` (Requests == Limits)
  2. `Burstable` (`kk-payments`: Requests < Limits)
  3. `BestEffort` (Unconstrained workload: No Requests or Limits specified)

When the node experiences memory pressure, the kubelet calculates evictions based on QoS classes. The unconstrained `BestEffort` workload is the primary target for eviction to save the node. If memory pressure remains critical, the `kk-payments` (`Burstable`) Pods may eventually be evicted or face OOM death depending on whether their current consumption exceeds their requested `64Mi`.

---

## Question 3: The Service Selector and Deployment Updates

### Traffic Routing During Transition Window
* **Behavior:** The `kk-payments-service` routes traffic to **both `v1.0.0` and `v1.1.0` Pods simultaneously**.
* **Mechanism:** The Service uses a label selector (`app: kk-payments`). During a rolling update, both the old ReplicaSet (`v1.0.0`) and the new ReplicaSet (`v1.1.0`) maintain Pods carrying the label `app: kk-payments`. The Service updates its **Endpoints** (or `EndpointSlice`) list to include the Pod IPs of both versions. Incoming requests are load-balanced across all ready Pod endpoints regardless of image version.

### Relation to Week 7 Mixed-Version Issue
Yes, this exhibits the **mixed-version window problem** discussed in Week 7. If the payment API or database schema undergoes breaking changes between `v1.0.0` and `v1.1.0`, client requests sent to `v1.0.0` Pods might behave differently than those sent to `v1.1.0` Pods during the rollout.

### Controlling Rollout Concurrency
The **`spec.strategy.rollingUpdate`** block inside the Deployment manifest controls how many Pods of each version run simultaneously:
* **`maxSurge`**: Controls how many Pods can be created *above* the desired replica count (e.g., `maxSurge: 1` allows 3 total Pods during rollout).
* **`maxUnavailable`**: Controls how many Pods can be unavailable *below* the desired replica count during the update (e.g., `maxUnavailable: 0` ensures 2 Pods remain active at all times).

---

## Question 4: Kubernetes vs. Week 7 Deployment Model

### Comparison & Evidence-Based Advantages
Kubernetes introduces three major architectural capabilities that the Week 7 manual deployment model lacked:

1. **Automated Self-Healing:**
   * *Evidence:* In Phase 4, when a Pod was manually deleted, Kubernetes detected the missing replica and brought a replacement Pod to `Running` state in **17 seconds** automatically without human intervention.
2. **Continuous Service Continuity & High Availability:**
   * *Evidence:* During the 17-second replacement window in Phase 4, the second replica actively absorbed incoming traffic through the `kk-payments-service`. Client health requests received continuous successful responses (`200 OK`) throughout the failure window.
3. **Downtime & Rollback Comparison:**
   * *Evidence:* In Week 7, recovering from a failure or executing a blue/green rollback required manual script execution or container restarts, incurring **downtime measured in minutes**. Under Kubernetes, self-healing occurs in **17 seconds**, and rolling updates preserve active endpoints continuously.

### What Week 7 Handled that Week 8 Lacks
* **Externalized Environment Configuration:**
  * In the Week 7 model, environment variables and configuration parameters (like database URLs, secret keys, or feature flags) were loaded dynamically from external `.env` files or host system configurations.
  * In this week's Kubernetes lab, values such as `NODE_ENV=production` are **hardcoded directly into the Deployment manifest**. This makes the deployment static across environments. 
  * *Looking Ahead:* Week 9 addresses this gap by decoupling configuration from workload manifests using native **ConfigMaps** and **Secrets**.
