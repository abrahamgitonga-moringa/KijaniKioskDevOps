# KijaniKiosk Capstone Project - Track A: Infrastructure-First

## 1. Overview
KijaniKiosk is an end-to-end multi-environment microservice system. This repository contains the complete Infrastructure as Code (Terraform), Configuration Management (Ansible), Kubernetes deployment manifests, Jenkins CI/CD pipeline, and Prometheus observability stack for `kk-payments`.

## 2. Architecture Overview
- **Infrastructure Layer:** Terraform provisions the `kijani-staging` namespace and sets Resource Quotas (2 CPU, 4Gi Memory, 10 Pods).
- **Configuration Layer:** Ansible renders and applies environment-isolated ConfigMaps (`DB_HOST=staging-db.internal` vs `DB_HOST=prod-db.internal`).
- **Delivery Layer:** Jenkins pipeline executes automated staging deployments, runs smoke tests, halts at an interactive approval gate requiring written rationale, and releases to production.
- **Observability Layer:** Prometheus rule evaluating HTTP 5xx error rates over 2 minutes, firing an alert if errors exceed 5%.

## 3. Prerequisites
- Docker Engine & Minikube (v1.30+)
- Terraform (v1.3.0+)
- Ansible (v2.12+)
- `kubectl` configured to active Minikube cluster context

## 4. Quick Start (Clean Checkout Test)
```bash
# 1. Provision Infrastructure
cd infrastructure/terraform && terraform init && terraform apply -auto-approve

# 2. Apply Configuration
cd ../ansible && ansible-playbook -i inventory/hosts.ini playbook.yml

# 3. Deploy Workloads
kubectl apply -f ../../kubernetes/staging/
kubectl apply -f ../../kubernetes/production/
```
