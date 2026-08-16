# Wednesday Reflection Answers: Serverless IaC and Function Chaining

### Question 1: Eliminating Manual Pre-Steps with Declared Resources
* **The Problem with Manual CLI Setup:** Manually creating S3 buckets via `aws s3 mb` leaves infrastructure state unversioned, environment-dependent, and prone to human error. New developers or CI/CD runners cannot reliably recreate the stack.
* **How `resources` Solves It:** Defining bucket resources within the `resources.Resources` block of `serverless.yml` makes the stack fully self-describing. Running `serverless deploy` (or `serverless offline start` with local S3 plugins) provisions all declared buckets and configures triggers automatically, guaranteeing reproducible environments across all deployment stages.

---

### Question 2: Correlation IDs Across Asynchronous Multi-Function Chains
* **Tracing Challenges:** In distributed, event-driven architectures, function logs interleave asynchronously. When multiple orders process simultaneously, identifying the path of a single transaction across separate function logs becomes difficult without a unifying key.
* **Role of `orderId` as Correlation ID:** Passing `orderId` through output file keys (`processed-{orderId}.json`, `notify-{orderId}.json`) and embedding it into every structured log entry allows developers to query logs across all services using a single identifier (e.g., `grep ORD-CHAIN-001`). This re-establishes end-to-end request tracing across decoupled services.

---

### Question 3: Trade-Offs of Direct Bucket Chaining vs. Queue Orchestration
* **Advantages of Direct Bucket Chaining:** Simple to implement, zero messaging service overhead, fast execution, and straightforward local emulation without complex queuing middleware.
* **Limitations and Production Alternatives:** Direct S3 chaining lacks message persistence, rate limiting, and backpressure handling. If a downstream function crashes or hits concurrency limits, events can be dropped. Production systems use **AWS SQS** or **AWS EventBridge** with **Dead Letter Queues (DLQ)** to guarantee *at-least-once* delivery, backpressure buffer management, and replay capabilities.
