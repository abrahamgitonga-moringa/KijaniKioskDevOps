# Tuesday Reflection Answers: Event-Driven Architecture & Triggers

### Question 1: Failure Isolation & Latency Elimination
* **Latency Elimination:** In Architecture A (synchronous HTTP), `kk-payments` blocks execution while waiting for `kk-receipts` to process and respond, making user response latency additive ($T_{\text{total}} = T_{\text{payments}} + T_{\text{receipts}}$). In Architecture B (event-driven), `kk-payments` writes a payload to object storage (~10ms) and immediately returns a payment confirmation to the client ($T_{\text{total}} \approx T_{\text{payments}}$). `kk-receipts` executes asynchronously in the background out-of-band.
* **Failure Isolation:** Under Architecture A, if `kk-receipts` throws a 500 or times out during a cold start, the upstream `kk-payments` call risks failing the client's checkout transaction. Under Architecture B, if `kk-receipts` crashes or experiences a slow cold start, the user's payment transaction remains 100% successful. The receipt event is preserved in the storage layer/event queue and retried automatically until processed successfully upon service recovery.

---

### Question 2: Idempotency & Duplicate Event Delivery
* **The Problem with Duplicates:** Event delivery systems guarantee *at-least-once* delivery. Network retries or event bus re-deliveries can invoke `processReceiptUpload` multiple times for the exact same upload event.
* **How `orderId` Ensures Idempotency:** Extracting a deterministic `orderId` from the filename key (e.g., `ORD-001`) allows `kk-receipts` to derive a unique primary identifier or destination path (e.g., writing to `final-receipts/receipt-ORD-001.pdf`). If the function receives a duplicate trigger, it overwrites or checks the existing key rather than generating duplicate records or side-effects, ensuring processing remains strictly **idempotent**.

---

### Question 3: Observability Gaps in Asynchronous Systems
* **The Observability Gap:** Synchronous failures return immediate HTTP status codes (`500 Internal Server Error`). Asynchronous failures occur silently in the background after the client has received a `200 OK` payment confirmation. If `kk-receipts` fails silently, no user receives an error, and the failure remains invisible unless structured log metrics are monitored.
* **How Structured JSON Logging Solves It:** Logging single-line JSON (`console.log(JSON.stringify(logEntry))`) with standard metadata fields (`service`, `event`, `orderId`, `bucketName`, `uploadedAt`, `processedAt`) allows centralized log aggregators (CloudWatch, Datadog, Loki) to automatically parse, index, and query log streams. Teams can configure real-time metric alerts on missing `receipt.upload.received` events or elevated `warning` counts to capture silent background failures immediately.
