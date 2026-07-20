# Capstone Reflection & PR Summary

## PR Summary for Tendo

### What Was Built This Week
This week, I transformed a single-line test build into a complete, board-ready CI delivery pipeline for `kijanikiosk-payments`. The pipeline executes inside an isolated `node:18-alpine` Docker container, enforces a fail-fast `Lint` stage prior to `Build`, runs `Test` and `Security Audit` in parallel, archives fingerprinted build outputs, and publishes versioned `.tgz` packages to Nexus using dynamic `semver-gitsha` tagging. Credential security is enforced using short-lived `withCredentials` blocks protected by `.npmrc` cleanup traps.

### Confident Design Decision
I am most confident in the **parallel execution structure within the `Verify` stage coupled with early linting**. Placing code quality checks before build compilation prevents wasted computing resources, while running security audits concurrently with unit tests cuts verification feedback loop times significantly.

### Next Engineering Step
Next, I would introduce **automated container image scanning** (using tools like Trivy or Grype) into the security audit stage to scan not just npm packages, but the underlying base container OS for vulnerabilities before release.

---

## Answers to Reflection Questions

### Question 1: Requirement Tension
The strongest tension occurred between **Environment Isolation (Docker Agent)** and **Nexus Network Access (Challenge A)**. Running the pipeline inside an isolated Docker container meant `localhost:8081` resolved inside the container itself rather than the host VM where Nexus was listening. To resolve this, I prioritized reliable environment execution without sacrificing isolation by passing `--add-host=host.docker.internal:host-gateway` and explicitly binding the bridge IP (`172.17.0.1`) in `NEXUS_URL`.

### Question 2: Plain Language vs. Technical Translation
* **Board Document Sentence (Plain Language):**  
  > *"If an engineer submits broken code, the system halts immediately, blocks the update from reaching the central storage vault, and alerts the team."*
* **Technical Translation (Jenkinsfile / Engineering):**  
  > *"Stage failure triggers an immediate non-zero exit code, aborting downstream `Archive` and `Publish` stage execution while triggering the `post { failure { ... } }` block for notification."*
* **Comparison:** Both versions convey the core rule that invalid code is prevented from deploying. The board version focuses on business safety and outcome; the technical version specifies structural mechanisms (exit codes, stage dependency, and post-execution handlers).

### Question 3: Scaling Bottleneck (4 to 40 Developers)
If team size grows tenfold, **single-executor resource contention and workspace lockouts on the Jenkins controller** will break first. Running parallel stages and sequential builds on a single node will cause build queue backlogs, slow down feedback times past 10 minutes, and exhaust local disk space during concurrent `npm ci` executions. To fix this, we would need to scale horizontally from a single controller to a **dynamic Kubernetes build agent pool** (or Jenkins ephemeral agent nodes) that provisions build containers on demand.
