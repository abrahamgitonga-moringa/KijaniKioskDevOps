# Post-Incident Review (PIR): Failure Injected Rollback Test

## Incident Summary
* **Date/Time:** 2026-08-03 19:37:48 UTC
* **Impacted Environment:** Green (`kk-api-green.service`, v1.4.0)
* **Trigger:** Controlled fault injection (`systemctl stop kk-api-green.service`)
* **Detection & Recovery Time:** 16 seconds total recovery time
* **User Impact:** 0 HTTP 500 errors returned to end users after automated traffic shift back to Blue (v1.3.0).

## Timeline
* **19:37:43** – Baseline active environment confirmed as Green (v1.4.0). Monitor initiated with 60s confidence window.
* **19:37:48 ($T_0$)** – Controlled stop of `kk-api-green.service` executed.
* **19:37:53 ($T_1$)** – Poll 3 fails with `HTTP 502 Bad Gateway`. Monitor registers consecutive failure 1.
* **19:38:03** – Poll 5 fails. 3 consecutive failure threshold breached. Monitor automatically triggers `rollback.sh`.
* **19:38:03** – `rollback.sh` executes `switch-env.sh blue`, updating Nginx upstream configuration.
* **19:38:04 ($T_2$)** – Nginx reloaded successfully. Synthetic health check through port 80 returns `HTTP 200 OK` (v1.3.0).

## Root Cause Analysis (5 Whys)
1. **Why did the API return 502 errors?** The Green backend service (`kk-api-green`) stopped processing requests.
2. **Why did traffic keep sending to Green?** Nginx routing configuration was pointing active upstream traffic to port 3001.
3. **Why did the outage clear within 16 seconds?** `post-deploy-monitor.sh` continuously polled the endpoint every 5s and invoked automated recovery upon reaching 3 consecutive errors.
4. **Why was no manual intervention required?** Deployment scripts maintain strict separation between Blue and Green with state tracking in `/opt/kijanikiosk/.active-env`.

## Lessons Learned & Action Items
1. **Keep confidence windows active:** Continuous monitoring post-switch is critical to catching instant startup crashes.
2. **Action Item:** Reduce monitor poll interval from 5s to 3s to reduce total recovery time under 10 seconds.
3. **Action Item:** Add health endpoint latency threshold checks in addition to status codes.
