### Wednesday Lab Analysis Question Answer

**What Happens in the Current Architecture:**
1. **`kk-receipts` Retry Behavior:** `kk-receipts` **does not** retry. Its execution completed successfully (status 200) once `processed-ORD-003.json` landed in the bucket. It has no knowledge of downstream functions.
2. **`kk-processor` Retry Behavior:** Direct S3-to-Lambda event triggers execute asynchronously. If `kk-processor` crashes (e.g., runtime exception or unhandled promise rejection), AWS S3 retries the invocation twice by default. If it fails on all retries, the event is silently discarded.
3. **`kk-notifier` Execution:** `kk-notifier` **never fires** for `ORD-003` because `kk-processor` crashed prior to writing `notify-ORD-003.json` to the notification bucket. The event is lost.

**Required Architectural Solution (Missing Component):**
To guarantee zero dropped events, decouple the storage event notification from function invocation by introducing an **Amazon SQS (Simple Queue Service) Queue with a Dead Letter Queue (DLQ)** between stages:
* **Pattern**: `S3 Bucket` $\rightarrow$ `SQS Queue` $\rightarrow$ `kk-processor` $\rightarrow$ `DLQ (on failure)`.
* **Mechanism**: When `processed-ORD-003.json` is created, the event is written to an SQS Queue. `kk-processor` polls SQS. If `kk-processor` crashes, the message is not acknowledged and returns to the queue after the visibility timeout. If processing fails repeatedly past the max receive count, SQS routes the unhandled event to a **Dead Letter Queue (DLQ)**. This prevents silent event drops and enables automated retries and alarm alerting.
