# Operational Runbook: Failed Deployment Recovery Procedure

This runbook outlines the mandatory steps required to recover from a failed deployment. Follow these steps in sequence to safely restore service stability.

## Standard Recovery Steps

### 1. Initiate Automated Rollback
Do not attempt to hotfix code directly in production. Immediately roll back the deployment to the last known stable commit.
* **Action:** In your deployment platform (e.g., AWS ECS, Kubernetes, or GitHub Actions), trigger the rollback mechanism to redeploy the previous successful build version.

### 2. Verify System Traffic and Reroute (Drain Traffic)
Ensure that users are no longer being routed to the broken deployment.
* **Action:** Check your load balancer or reverse proxy logs. If canary routing or blue/green deployments are used, instantly shift 100% of traffic back to the stable environment.

### 3. Isolate and Capture Logs
Before the failed containers or instances are terminated by the rollback process, isolate them to capture state data.
* **Action:** Export application logs, database transaction logs, and system metrics from the failed instances to your centralized logging platform (e.g., CloudWatch, ELK stack) for deep forensics.

### 4. Notify Stakeholders and Update Status Page
Maintain transparency across the organization and with customers regarding the incident.
* **Action:** Alert the on-call incident commander, customer support teams, and update your status page (e.g., "Investigating deployment degradation") to manage external incoming tickets.

### 5. Conduct a Blameless Post-Mortem
Once the system is stable, schedule a post-mortem within 24 hours to review why the deployment failed and why the recovery procedures weren't caught earlier.
* **Action:** Document the timeline, root cause, and create new automated guardrail issues in your backlog. Do not assign blame to individuals.
