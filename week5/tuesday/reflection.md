# Tuesday Reflection: Declarative Pipeline

## Question 1: What the Red Build Proved

The red build proved three key mechanisms in Jenkins execution:
1. **Build (Green) vs. Test (Red):** Proved that the workspace compiled successfully and that the failure was strictly isolated to the test suite, preventing false build-step diagnostics.
2. **Skipped Archive Stage:** Proved pipeline short-circuiting. Because the `Test` stage returned a non-zero exit code (`1`), Jenkins halted pipeline execution, preventing broken code from producing an archived artifact.
3. **Execution of `post { failure }`:** Proved that error-handling hooks fire reliably even when stages fail, enabling notifications without blocking workspace cleanup in `post { always }`.

If a syntax error caused the test runner (e.g., Jest or Node) to crash, Jenkins would process it the exact same way at the pipeline level. A crash terminates the shell process with a non-zero exit code (such as `1` or `127`). Jenkins reads this non-zero exit code, marks the `Test` stage `FAILED` (red), and halts the pipeline before reaching `Archive`.

---

## Question 2: npm ci vs npm install in a Team Context

`npm install` respects semantic versioning ranges defined in `package.json` (e.g., `^1.2.0`). If a third-party dependency author publishes a patch update on Tuesday (v1.2.1) without any KijaniKiosk engineer modifying code, `npm install` in Tuesday's pipeline will automatically fetch v1.2.1 instead of Monday’s v1.2.0. If v1.2.1 introduces a breaking change or bug, the build will fail unexpectedly on Tuesday despite zero code changes by the team.

`npm ci` prevents this by ignoring `package.json` version ranges and installing the exact, locked dependency tree recorded in `package-lock.json`. It also enforces consistency by throwing a hard error if `package-lock.json` and `package.json` are out of sync, guaranteeing reproducible builds across all four developers and the Jenkins agent.

---

## Question 3: The Archived Artifact (Looking Ahead)

To address Tendo’s concerns regarding controller disk capacity and cross-machine artifact retrieval, a dedicated artifact store must possess the following properties:

1. **Automated Retention & Lifecycle Policies:** Ability to set rules that automatically purge, compress, or archive old build artifacts (e.g., keeping only the last 10 builds or release tags) to prevent disk saturation.
2. **Centralized Remote Storage & REST API Access:** A network-accessible registry accessible over HTTP/HTTPS, allowing remote deployment servers or secondary Jenkins agents to pull artifacts via curl or API calls without requiring direct disk access to the Jenkins controller.
3. **Version Immutability & Metadata Indexing:** Semantic versioning support (e.g., `v1.0.0`) that guarantees build artifacts are stored securely with checksums (fingerprints) without being overwritten.

---

## Question 4: What Tuesday's Pipeline Still Cannot Do

Nia is right: **this pipeline will NOT catch security vulnerabilities.** If unit tests pass, a vulnerable dependency will breeze through to `Archive`. 

To close this gap, two categories of automated checks should be added:

1. **Dependency Vulnerability Scanning (Software Composition Analysis - SCA):**
   * **Tool:** `npm audit` or **Snyk**.
   * **Pipeline Placement:** Belongs in the **Build stage** immediately after `npm ci`. Checking dependencies early prevents waste: if a critical vulnerability is present, there's no reason to waste agent resources running tests or generating artifacts.

2. **Static Application Security Testing (SAST):**
   * **Tool:** **SonarQube** or **Semgrep**.
   * **Pipeline Placement:** Belongs in a dedicated **Analysis/Quality stage** running parallel to or right after the **Test stage**. SAST analyzes source code for hardcoded secrets, injection flaws, and unsafe function calls prior to archiving.
