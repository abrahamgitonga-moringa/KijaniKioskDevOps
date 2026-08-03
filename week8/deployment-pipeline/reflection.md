# Engineering Reflection: Pipeline Architecture and Rollback Automation

## Question 1: Non-Technical Communication and Technical Precision
In the board demo script, stating *"The system detected the failure and restored normal operations in 13 seconds"* oversimplifies what actually happened. It implies the platform automatically identified an application bug, whereas the monitor simply detected two failing HTTP health checks caused by an abruptly stopped process. 

To be more precise without confusing board members, I would frame it as: *"The system detected that our new release stopped responding to health checks, automatically isolated the failure, and redirected customer traffic back to our stable release in 13 seconds."* This preserves clarity while accurately describing signal detection rather than magic bug identification.

## Question 2: Highest-Value Incident Action Item
The highest-value action item is implementing a pre-flight assertion script that checks the target environment before applying configuration changes (`if [ "$DEPLOY_ENV" == "$ACTIVE_ENV" ]; then exit 1; fi`). 

I am highly confident this prevents recurrence because it removes human parameter entry errors from the execution path. To be 100% certain, I would need to verify that all deployment executions occur through isolated CI/CD runner pipelines where environment parameters are injected programmatically rather than typed in terminal sessions.

## Question 3: VM Blue/Green Concepts vs. Kubernetes Automation

### Concepts That Carry Forward:
* **Decoupled Deployments:** The concept of bringing up new software instances and verifying health *before* routing live customer traffic remains identical.
* **Health Probes & Automated Rollbacks:** The requirement to continuously monitor endpoints and trigger automatic rollbacks based on failure thresholds remains essential.

### Concepts Rendered Redundant by Kubernetes:
* **Manual Proxy Configuration:** Writing custom Nginx configuration scripts to swap upstream IP addresses becomes obsolete; Kubernetes Service endpoints handle target routing dynamically.
* **Custom Watchdog Daemon Scripts:** Shell-based monitoring daemons (`post-deploy-monitor.sh`) are replaced by native Kubernetes Liveness and Readiness probes.
* **Instance Tracking via State Files:** Maintaining local disk state files (`.active-env`, `.previous-env`) is unnecessary because cluster state is maintained in `etcd`.

## Question 4: Hardcoded Manifest Values and Operational Risks

The following hardcoded values in `kk-payments-deployment.yaml` should be extracted:

1. `NODE_ENV: "production"`:
   * *Operational Risk:* Prevents reusing the same manifest across staging, development, and production environments without manual file edits.
2. `image: kijani-registry.internal:5000/kk-payments:v1.4.0-7a3f91c`:
   * *Operational Risk:* Hardcoding specific image tags requires modifying source control manifests for every release rather than injecting build tags dynamically.
3. Resource Limits (`memory: "256Mi"`, `cpu: "500m"`):
   * *Operational Risk:* Load profiles differ between environments; static resource limits can cause unnecessary OOMKills in high-traffic production environments or waste cluster capacity in lower environments.
