# Capstone Technical Reflection

## 1. What Did You Get Wrong?
Initially, I attempted to apply Kubernetes manifests directly inside Ansible using the community `k8s` module. This introduced unnecessary Python runtime dependencies and credential management issues when cluster contexts rotated. I refactored the design so Ansible generates environment-specific ConfigMap manifests as pure templated artifacts, delegating cluster state execution to `kubectl` within the Jenkins pipeline.

## 2. Most Important Thing Learned
The single most transformative concept was Infrastructure as Code reproducibility (Week 4). Moving from imperative cluster configuration to declarative Terraform and Ansible automation demonstrated that a deployment is only production-ready if the entire environment can be wiped and re-created cleanly from git history without manual steps.

## 3. What Would a Second Pass Look Like?
If granted additional development iterations, I would:
1. Replace static file-based ConfigMaps with Kustomize overlays for smoother environment inheritance.
2. Implement automated Chaos Mesh fault-injection tests during the Jenkins staging smoke-test phase.
3. Integrate Prometheus Alertmanager with PagerDuty for real-time alert routing.
