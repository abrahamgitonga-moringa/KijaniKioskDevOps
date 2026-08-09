### 1. ConfigMaps vs. Secrets & The Base64 Reality
* **Purpose:** **ConfigMaps** are designed strictly for non-sensitive operational configuration parameters (hostnames, log levels, port numbers, feature toggles). **Secrets** are intended for sensitive data (database passwords, API tokens, TLS keys) that require restricted viewing and controlled distribution inside the cluster.
* **Cluster Protections Provided:** ConfigMaps are stored in plain text and accessible to anyone with standard read access to the namespace. Secrets provide access isolation via **Kubernetes RBAC** (restricting which service accounts or users can read the object) and can be encrypted at rest in `etcd` if cluster encryption is enabled.
* **Why Base64 Encoding is NOT Security:** Base64 encoding is an encoding scheme used to transport arbitrary binary data safely over text-based formats (YAML/JSON)—it is **not encryption**. Anyone with read access to a Secret manifest can instantly decode the payload using `base64 --decode`. Base64 provides zero confidentiality; security depends entirely on RBAC restrictions and secure key management systems.

---

### 2. Environment Variable vs. Volume-Mounted ConfigMap Behavior
* **What Would Change (Dynamic Refresh):** If `kk-payments` mounted the ConfigMap as a volume (e.g., files under `/etc/config/`), Kubernetes via the `kubelet` would **automatically update the mounted file contents** in the container within 60–90 seconds of applying the updated ConfigMap, without requiring a `kubectl rollout restart`.
* **What Would Stay the Same (Application Process State):** Even though the underlying file changes dynamically on disk, if the application reads configuration files only once at startup into memory, the running application process **still would not notice the change** until the process re-reads the file or the Pod is restarted. Hot-reloading requires both volume mounts and application-level file-watching logic.

---

### 3. Decoupled Manifests across Multi-Namespace Environments
* **Meaning of Name-Based Reference:** By using `envFrom` pointing to `configMapRef: { name: kk-payments-config }`, the Deployment contains no environmental facts about database hosts or log levels—it specifies only *where to look* for those facts at runtime.
* **Handling Staging without Manifest Duplication:** To deploy to a `staging` namespace without creating duplicate Deployment manifests:
  1. Keep a **single, identical** Deployment manifest across all environments.
  2. Create a `kk-payments-config` ConfigMap inside the `staging` namespace containing staging-specific values (e.g., `DB_HOST=postgres-staging.internal`).
  3. Create a `kk-payments-config` ConfigMap inside the `production` namespace containing production values (e.g., `DB_HOST=postgres-prod.internal`).
  4. When applied in either namespace, the Deployment automatically binds to the local namespace's ConfigMap without modifying a single line of the Deployment YAML (or by using Kustomize overlays / Helm values).

---

### 4. Operational Dependencies Created by Imperative Secrets
* **What Teammates Will Find for ConfigMap:** They will find the complete, valid declarative `k8s/kk-payments-configmap.yaml` file in Git, ready to apply immediately.
* **What Teammates Will Find for Secret:** They will find only `k8s/kk-payments-secrets.yaml.example`—a skeleton file with empty keys and comments, but **no usable values**.
* **Operational Dependency:** Imperative, uncommitted Secrets create an **external operational dependency on secret management processes**. Git alone is insufficient to reconstruct a functional cluster environment. Teams must rely on external vaults (e.g., HashiCorp Vault, AWS Secrets Manager, 1Password) or documented onboarding pipelines to inject the actual credential values when building environments from scratch.
