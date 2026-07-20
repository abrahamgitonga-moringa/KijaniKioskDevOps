# Fault Injection Log & Analysis

This document records the intentional faulting of each pipeline stage to verify that downstream execution halts or isolates as intended by design principles.

| Stage Faulted | Fault Introduced | Expected Behavior | Observed Behavior | Design Rationale |
|---|---|---|---|---|
| **Initialize Environment** | Corrupted `package.json` syntax | Pipeline halts; all downstream stages skip | Pipeline stopped at initial stage with syntax error; Lint, Build, Verify, Archive, Publish skipped. | Prevents execution on invalid configuration before allocating system build resources. |
| **Lint** | Syntax error injected in source file (`npm run lint` set to exit 1) | Build, Verify, Archive, Publish all skip | Lint stage failed; Build and all subsequent stages skipped. | **Fail-Fast Principle:** Stops execution immediately before triggering heavy dependency pulls or compilation. |
| **Build** | Invalid `npm ci` flag (`npm ci --invalid-flag`) | Verify, Archive, Publish all skip | Build stage failed on dependency installation; Verify, Archive, Publish skipped. | Prevents running tests or packaging broken/missing software binaries. |
| **Test** *(in Verify)* | Deliberate failing test assertion (`exit 1` in test script) | Security Audit completes; Archive & Publish skip | Security Audit finished execution in parallel; stage failed; Archive & Publish skipped. | Parallel branches complete independent checks, but downstream deployment is aborted if quality gates fail. |
| **Publish** | Invalid credential ID specified (`invalid-nexus-id`) | Archive completes; artifact stored in Jenkins but NOT Nexus | Archive stage succeeded; Publish stage failed with authentication lookup error. | Local artifacts remain available for internal inspection, but broken credentials block external release. |

---
*All faults were individually verified and cleared, returning the pipeline to a green status.*
