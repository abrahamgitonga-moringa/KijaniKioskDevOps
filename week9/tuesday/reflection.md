# Reflection: Rolling Update and Rollout History

## Reflection Questions

### 1. Why the Service continued routing traffic during the Phase 2 stall
* **Observed Pod States:** During Phase 2, running `kubectl get pods -l app=kk-payments` showed a mixed state: two old Pods (`kk-payments-79d9c65657-...`) were in the **`Running`** (1/1 READY) state, while the new Pods (`kk-payments-59fd984c58-...`) were stuck in **`ImagePullBackOff`** (0/1 READY).
* **Mechanism:** The Kubernetes `Service` routes traffic based on its `spec.selector` (matching `app=kk-payments`). However, a Service **only forwards network requests to Pods whose Endpoints are marked as READY**.
* **Explanation:** Because the new Pods failed to pull their image, they remained at `0/1 READY` and were never added to the Service's active Endpoints object. The existing healthy Pods remained at `1/1 READY`, continuing to match the label selector and handle 100% of incoming production traffic without dropping a single request.

---

### 2. `kubectl rollout undo` vs. `kubectl rollout undo --to-revision=N`
* **Difference:** 
  * `kubectl rollout undo` rolls back the Deployment to the **immediately preceding revision** (Revision $N-1$).
  * `kubectl rollout undo --to-revision=N` explicitly targets a **specific historical revision** ($N$).
* **Critical Scenario:** Targeting a specific revision is critical when a deployment pipeline has attempted multiple broken updates in a row, or when a release undergoes several configuration tweaks while broken.
* **Impact of Default `undo` after 3 Failed Deployments:** If revisions 3, 4, and 5 were all failed deployments, running the default `kubectl rollout undo` while at revision 5 would simply toggle the cluster back to **revision 4**—which is also broken. Using `--to-revision=2` allows you to jump over all failed interim attempts directly to the last known-good revision.

---

### 3. Why Kubernetes creates a new revision for a rollback
* **Observed History:** In `kubectl rollout history deployment/kk-payments`, executing the Phase 3 rollback did not delete revision 2 (`v1.2.0-bad`); instead, it appended a brand-new revision to the timeline.
* **Design Reason:** Kubernetes treats Deployments as **append-only event logs**. A rollback is not an erasure of past mistakes—it is a new intentional rollout whose template spec happens to duplicate an older, healthy spec.
* **Audit Properties:** This ensures complete auditability. Security and DevOps teams can trace every deployment attempt, when it occurred, and who initiated it. It prevents "ghost changes" in your cluster history, providing an immutable record of what specs were applied at any point in time.

---

### 4. The risk of omitting the local manifest Git commit
* **Immediate Cluster Impact:** The `kubectl rollout undo` command only mutates the live state inside the Kubernetes cluster's `etcd` database—it **does not edit local YAML files on disk**.
* **What would happen 20 minutes later:** If a teammate pulled `main` and executed `kubectl apply -f k8s/kk-payments-deployment.yaml`, `kubectl` would re-read the file still pointing to `v1.2.0-bad`. It would declare a new intent, overwrite the live cluster state, and **re-trigger the exact same `ImagePullBackOff` outage** that was just resolved.
* **Operational Principle:** An incident/rollback is only complete when the **Infrastructure-as-Code (Git repo)** matches the **Live Environment State**.

---

## Phase 5 Lab Analysis Question

**Question:** *What would happen during a broken update if `maxUnavailable` was set to `3` (or `100%`) on a 3-replica Deployment?*

**Answer:**  
If `maxUnavailable` were set to `3` (or `100%`), Kubernetes would allow the Deployment controller to terminate **all 3 running healthy Pods simultaneously** before confirming that the new Pods are healthy and ready to accept traffic. During a Phase 2 broken update (e.g., `ImagePullBackOff`), the cluster would kill all active `v1.1.0` Pods, fail to start any `v1.2.0-bad` Pods, and result in **0 active endpoints**. This would cause a total service outage (100% downtime) for users, completely nullifying the safety guarantees of a Kubernetes Rolling Update.
