# Week 5 Monday Reflection: The Plumbing of CI

## Question 1: What Today's Pipeline Does Not Do
Today's pipeline is merely a trigger verification and health check; it lacks the 3 properties that define true Continuous Integration (CI): automated compilation/assembly, automated testing, and artifact creation. To transform this from plumbing into a genuine CI pipeline, three distinct stages must be added to the `Jenkinsfile` directly after the `Environment Check`:

1. **Automated Assembly/Build:** A stage must verify that the application and its dependencies can cleanly compile and combine. For our Node.js payments service, this requires adding a stage that runs `npm ci` (clean install for automated environments) to locked down versions in `package-lock.json`, followed by `npm run build` if the project uses a compiler like TypeScript.
2. **Automated Testing:** A stage must execute the test suite against the built code. This would run `npm test`. The pipeline must catch the exit code of this command; if a test fails, the process exits with a non-zero status, and Jenkins immediately halts the build.
3. **Artifact Archiving:** A valid CI pipeline must package successful builds into an immutable artifact. This requires an `archiveArtifacts` step in Jenkins, capturing the production files (like the `dist/` or `build/` folders and `package.json`) using syntax like `archiveArtifacts artifacts: 'dist/**, package.json', fingerprint: true`.

---

## Question 2: The Broken-Build Contract in Practice
With four developers, three target environments (`api`, `payments`, `logs`), and a board review looming in three weeks, a developer under intense pressure might argue: *"My feature branch is fine, but the main branch build is failing because of an unrelated network timeout or a minor linting error. I need to merge my critical payment processing patch right now for testing, so let's ignore the red build just this once."*

This exception is deceptively expensive. The moment the main branch stays broken, it blinds the rest of the team. If Developer B pulls the broken `main` branch to start new work, they inherit the breakage, wasting hours debugging code they didn't write. If Developer C pushes new code, they cannot tell if *their* changes broke the system or if they are simply seeing the original failure. 

Over a two-week sprint, "just this once" compounding exceptions cause complete visibility failure. Trust in the pipeline collapses, developers stop looking at Jenkins, and integration reverts to a terrifying, manual "big bang" mess right before the board review.

---

## Question 3: The Jenkinsfile in the Repository
Storing pipeline definitions exclusively inside the Jenkins web UI creates severe operational risks and erodes DevOps best practices in two major ways:

First, **Disaster Recovery and Portability** become a nightmare. If the ThinkPad host machine crashes, or the Jenkins Docker container volume is corrupted, a UI-defined configuration is gone forever. Rebuilding the pipeline requires manual click-by-click recreation. Conversely, with a `Jenkinsfile` in the repository, rebuilding the server is trivial: you spin up a new Jenkins instance, point it at the Git URL, and the pipeline reconstructs itself instantly.

Second, **Change Control and Visibility** are completely lost. When the pipeline lives in the UI, anyone with access can modify a script or disable a test step without leaving a trace. A developer trying to understand why a build step changed has no audit log. By keeping the `Jenkinsfile` in version control, every pipeline modification must go through a GitHub Pull Request. It is subject to code review, and `git log` provides an absolute historical record of *who* changed the build process, *when*, and *why*.

---

## Question 4: Webhooks vs Polling
Our pipeline uses a **Webhook** trigger via an `ngrok` secure tunnel. The technical mechanism is push-based: the moment a developer runs `git push origin main`, GitHub intercepts the event and actively sends an HTTP POST request containing a JSON payload down through our ngrok tunnel endpoint directly to the Jenkins controller at `/github-webhook/`. Jenkins receives this payload instantly and immediately schedules the build.

**SCM Polling** would be more appropriate in a highly secured enterprise network where inbound public traffic (even via tools like ngrok) is strictly blocked by a corporate firewall. In that scenario, Jenkins must actively pull information by regularly querying the GitHub API (e.g., every 5 minutes) using `git ls-remote` to check if the remote repository's commit hash has changed.

At scale, the real cost of polling is feedback latency. If a team of 4 developers pushes code 3 to 4 times a day each (~15 pushes total), a 5-minute polling latency means developers regularly spend up to 5 minutes sitting idle waiting for a build to start. If the team grows to 15 developers pushing hourly, the pipeline feedback loop stretches out completely. Developers context-switch away to new tasks before discovering they broke the build 10 minutes ago, destroying the immediate feedback loop central to CI.
