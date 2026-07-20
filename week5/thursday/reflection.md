# Week 5 Thursday: Reflection and Engineering Thinking

---

## Question 1: Docker Agent Isolation in Depth

To handle a missing native Linux library (`libvips`) inside the `node:18-alpine` execution container, three distinct approaches are available:

1. **Quickest: Dynamic Installation (`args`)**  
   * **Change:** Add build args or runtime package installation via pipeline environment options (`args '-v /usr/local/lib:/usr/local/lib'`).  
   * **Disadvantage:** Creates fragile runtime host dependencies and leads to non-deterministic builds if the host OS library version changes.

2. **Moderate: Different Base Image (`node:18-bullseye`)**  
   * **Change:** Update the `Jenkinsfile` agent tag to `image 'node:18-bullseye'`, which includes glibc and pre-compiled native support for tools like `libvips`.  
   * **Disadvantage:** Increases image pull size (Debian vs. Alpine is ~200MB vs ~40MB), significantly slowing down build start times.

3. **Most Maintainable: Custom Dockerfile**  
   * **Change:** Build and publish a project-specific Docker image containing `node:18-alpine` with `libvips` pre-installed (`RUN apk add --no-cache vips-dev`). Point the `Jenkinsfile` agent to `myorg/node-vips:18-alpine`.  
   * **Disadvantage:** Requires extra pipeline infrastructure to maintain, version, and rebuild the custom agent image whenever dependencies update.

---

## Question 2: Parallel Stage Design Decisions

Adding an 8-minute database-backed integration test to the `Verify` stage breaks the 10-minute feedback rule. Because pipeline stages are bound by their longest-running parallel branch, total execution time would spike to 10+ minutes. Furthermore, integration tests require external state management (spinning up database containers), introducing test flakiness and resource contention during parallel execution.

### Correct Architecture
Fast feedback (linting, unit tests, security checks) must remain in the primary pull-request automated gate. Heavy integration and end-to-end tests should be decoupled into an asynchronous, downstream pipeline.

### Separation Mechanism
Use a **Multi-branch Pipeline with Triggers** or a post-merge **`build` step trigger** (`build job: 'integration-tests-nightly'`). In Jenkins, this is configured via scheduled triggers (`cron('0 0 * * *')`) or parameterized downstream jobs that execute only after a successful merge to the `main` branch, preserving rapid developer feedback.

---

## Question 3: The Week as a Complete System

### Boardroom Explanation (Plain Language — for Nia)
> "When an engineer completes a code update, our automated delivery system takes over immediately to eliminate human error. Think of it as a quality control assembly line. First, it scans the code for structural mistakes and runs instant diagnostic tests in a controlled, isolated room—making sure no old software traces interfere. 
> 
> Next, it audits third-party code for security flaws. If any step fails, the process instantly stops and alerts the team before any harm is done. If every safety check passes, the system packages the verified software, attaches a unique digital barcode matching the exact code version, and deposits it into a secure central vault. In under ten minutes, a fully tested, tamper-proof release package is ready for deployment."

### Technical Explanation (for Tendo)
> "The pipeline implements an automated CI/CD loop leveraging an isolated Docker runtime (`node:18-alpine`). On commit push, Jenkins executes a declarative pipeline that runs `npm run lint` and `npm ci` before stashing build outputs. It then fans out into a parallel execution stage running unit testing (`npm test` producing JUnit XML logs) alongside a high-threshold dependency audit (`npm audit`). 
> 
> Upon passing, artifacts are fingerprinted and archived locally before being published to the Nexus npm repository using dynamic SemVer versioning (`PKG_VERSION-GIT_SHORT`) via authenticated, masked credentials with immediate `.npmrc` file cleanup traps."

### System Comparison
* **What is the same:** Both explanations describe the identical end-to-end flow: automated verification triggered by code changes, strict fail-fast quality gates, version tagging, and final storage of a release-ready output.
* **What is different:** The plain language version uses analogies (assembly line, safety checks, central vault) to focus on risk reduction and business value. The technical version specifies precise tooling, protocols, and mechanisms (`Docker`, `SemVer`, `JUnit`, `Nexus`, parallel execution, credentials isolation).

---

## Question 4: What the Pipeline Cannot Prevent

Even a fully green pipeline cannot prevent every defect from reaching Nexus. Two major categories include:

### Category 1: Logical / Business Domain Bugs
* **Description:** Code that compiles cleanly and passes syntactical unit tests, but incorrectly implements business rules (e.g., calculating a 10% discount instead of 15% on payments).
* **Catching Mechanism:** Acceptance Testing / User Acceptance Testing (UAT) and exploratory product testing.
* **Why Outside CI:** Domain correctness requires human product context, exploratory scenario testing, and validation against real-world business expectations that standard automated unit assertions cannot infer.

### Category 2: Zero-Day Vulnerabilities & Unpatched Upstream Errors
* **Description:** Third-party dependencies that pass `npm audit` because their security vulnerabilities haven't been published to official CVE databases yet.
* **Catching Mechanism:** Continuous runtime threat monitoring, Software Bill of Materials (SBOM) tracking, and periodic automated re-audits.
* **Why Outside CI:** CI audits are point-in-time checks against *known* databases at build time. Zero-day threats emerge post-release, requiring persistent external security scanning of stored artifacts independent of pipeline triggers.
