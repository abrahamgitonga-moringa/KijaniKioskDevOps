# Operational Setup Guide - kijani-project

## Required Manual Secrets
The `kk-payments-secrets` Secret is managed externally and **must NOT be committed to git**.

Before applying deployments, run:
```bash
kubectl create secret generic kk-payments-secrets \
  --from-literal=DB_PASSWORD=<obtain-from-team> \
  --from-literal=STRIPE_API_KEY=<obtain-from-team> \
  --from-literal=JWT_SECRET=<obtain-from-team> \
  -n kijani-project
