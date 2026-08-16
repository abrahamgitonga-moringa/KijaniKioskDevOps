### Lab Analysis Question Answer

To transition from local development to production event-driven execution, **`kk-payments` must implement the following changes and meet these strict knowledge boundaries**:

1. **What `kk-payments` MUST DO and KNOW:**
   * **Action**: `kk-payments` must write/upload the receipt data object directly to the target object storage service (or publish an execution message to an event bus like AWS EventBridge / SNS).
   * **Knowledge**: `kk-payments` only needs to know the **S3 Bucket Name** (or ARN) and the agreed object key naming convention (`receipt-{orderId}.json`).

2. **What `kk-payments` DOES NOT NEED TO KNOW:**
   * `kk-payments` does **not** need to know that the `kk-receipts` service exists.
   * `kk-payments` does **not** need to know `kk-receipts`' API endpoints, function names, execution environments, runtime dependencies, or retry policies.
   * `kk-payments` has zero awareness of downstream consumers processing files from the bucket. This guarantees true architectural decoupling, eliminating direct latency coupling and isolating `kk-payments` from `kk-receipts` cold starts or downstream crashes.
