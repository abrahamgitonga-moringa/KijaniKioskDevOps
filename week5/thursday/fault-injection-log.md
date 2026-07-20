# Fault Injection Log

| Stage faulted | Fault introduced | Expected behaviour | Observed? (Y/N) |
|---|---|---|---|
| **Lint** | Syntax error in source file | Build, Verify, Archive, Publish all skip | **Y** |
| **Build** | Invalid `npm ci` flag (`npm ci --invalid-flag`) | Verify, Archive, Publish all skip | **Y** |
| **Test** (in Verify) | Deliberate failing assertion (`exit 1` in test) | Audit runs to completion; Archive, Publish skip | **Y** |
| **Publish** | Wrong credential ID (`credentialsId: 'invalid-cred'`) | Archive ran; artifact in Jenkins but not in Nexus | **Y** |

## Explanations per Faulted Stage

1. **Lint Fault:** Introducing a syntax error stopped execution immediately prior to compilation, satisfying the fail-fast principle and skipping all subsequent resource-heavy stages.
2. **Build Fault:** Passing an invalid flag broke dependency installation; because compilation failed, downstream verification and archiving steps were aborted.
3. **Test Fault:** Failing the unit tests allowed the parallel `Security Audit` stage to complete execution, but prevented subsequent deployment (`Archive` and `Publish`) stages from executing.
4. **Publish Fault:** Providing an invalid credential ID permitted Jenkins to archive the artifact locally during the `Archive` stage, but choked on authentication during Nexus artifact publication.
