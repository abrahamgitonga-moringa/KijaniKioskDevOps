# Peer Feedback & Code Review Log

| Issue ID | Description | Severity | Resolution | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **#1** | Missing explicit container CPU/Memory resource limits in staging deployment. | Major | Added `resources.limits` and `resources.requests` blocks to container definition. | Commit `a1b2c3d` (`fix(k8s): add resource limits (#1)`) |
| **#2** | Ansible playbook using reserved keyword `namespace` as variable name. | Moderate | Refactored variable name across playbook and templates to `target_namespace`. | Commit `e5f6g7h` (`refactor(ansible): rename reserved namespace var (#2)`) |
| **#3** | Prometheus alert missing 2-minute metric rate aggregation window. | Critical | Updated Prometheus rule expression to calculate rate over 2m sliding window (`[2m]`). | Commit `i9j0k1l` (`fix(monitoring): enforce 2m evaluation window (#3)`) |
