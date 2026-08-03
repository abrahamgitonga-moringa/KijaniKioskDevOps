# Post-Incident Review: Week 5 Monday Outage

## 1. Summary
On Week 5 Monday morning during an investor walkthrough led by Nia, the staging and production environments experienced a total 18-minute service outage. While attempting a minor configuration change, Amina executed `make configure ENV=production` manually from a local shell, inadvertently overwriting production database credentials with incomplete staging variables. Traffic was restored by manually re-deploying production secrets from backup vault stores.

## 2. Timeline
- **08:52:00 EAT:** Amina opens local terminal to prepare environment configuration changes.
- **08:55:12 EAT:** Amina executes `make configure ENV=production` from local workstation.
- **08:55:18 EAT:** Production application pods fail database connectivity checks and crash loop.
- **08:56:00 EAT:** Nia's live investor demonstration fails with HTTP 500 connection errors.
- **08:58:30 EAT:** Tendo identifies database connection reset errors in centralized logs.
- **09:03:15 EAT:** Tendo traces configuration change back to manual `make` execution from workstation IP.
- **09:08:00 EAT:** Amina restores environment production secrets from secure vault backup.
- **09:13:12 EAT:** Services successfully pass health checks; full production restoration confirmed.

## 3. Root Cause Analysis (5 Whys)
1. **Why did the production API crash?** Application pods could not authenticate to the production database instance.
2. **Why could pods not authenticate?** The production environment variables were overwritten with invalid staging parameters.
3. **Why were variables overwritten?** Amina manually executed `make configure ENV=production` from her local machine.
4. **Why was a developer able to run production configuration commands directly?** Local Makefile targets lacked environment checks and allowed workstation execution against production parameter stores without guardrails.

## 4. Contributing Factors
- **Manual CLI execution:** Production infrastructure changes were performed directly via local shell instead of automated CI/CD pipelines.
- **Lack of environment isolation:** Workstation credentials had direct write access to production environment stores.
- **Missing pipeline parameter validation:** Makefile targets did not validate parameter inputs or execution context.

## 5. Prevention Mechanisms
- **Automated Environment Isolation:** The `set-environment` job in `.github/workflows/deploy.yml` reads `github.ref_name` and removes the `ENV` override parameter entirely, prohibiting manual environment injection.
- **Pipeline Execution Guardrails:** The `configure` job in `deploy.yml` enforces OIDC-based GitHub Actions secret access, revoking developer workstation write privileges to production config files.
- **Pre-Flight Sanity Checks:** The `verify` job in `deploy.yml` runs automated static schema validation against configuration files before applying them.

## 6. Action Items

| Action Item | Owner | Target |
|-------------|-------|--------|
| Revoke local developer workstation write permissions to production parameter stores | Tendo | Week 8 |
| Implement OIDC keyless authentication for GitHub Actions deployment workflows | Amina | Week 8 |
| Enforce branch-protection rules requiring mandatory pull-request reviews for workflow updates | Nia | Week 8 |
