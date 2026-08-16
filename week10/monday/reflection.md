# Reflection Answers: Functions & Serverless Architecture

### Question 1: Idle Resource Consumption and Trade-offs
* **Resource Consumption at 3 AM:**
  The `kk-payments` service runs continuous processes inside active Kubernetes Pods. These Pods hold statically allocated CPU and memory reservations and run liveness/readiness probes 24/7 regardless of traffic. At 3 AM, when zero payments occur, `kk-payments` still consumes cluster CPU and memory resources. In contrast, `kk-receipts` consumes **zero CPU and zero memory** while idle because serverless platform containers are allocated on-demand upon request arrival and terminated after execution.
* **The Structural Trade-off:**
  `kk-payments` cannot trade away predictable execution latency for scale-to-zero cost savings—it must sit warm continuously to guarantee instant HTTP responses for user checkout calls. `kk-receipts` trades off instant startup readiness for zero idle resource costs, taking advantage of the fact that receipt processing is a background task where minor invocation delays are completely acceptable.

---

### Question 2: Event Parsing, Error Handling, and Input Validation
* **Necessity of `|| '{}'` Fallback:**
  API Gateway and `serverless-offline` pass the incoming HTTP request payload as a string on `event.body`. If an HTTP POST request arrives without a body, `event.body` resolves to `null` or `undefined`. Calling `JSON.parse(null)` or `JSON.parse(undefined)` throws an unhandled `SyntaxError` that crashes function execution. Falling back to `'{}'` guarantees that `JSON.parse` receives a valid string payload and evaluates safely to an empty object.
* **Missing `orderId` Behavior:**
  If `orderId` is missing from the payload, the handler must immediately short-circuit execution, return an HTTP `400 Bad Request` status code, and emit a descriptive JSON error body so the caller knows the payload structure was invalid.
* **Validation Logic Implementation:**
  ```javascript
  const body = JSON.parse(event.body || '{}');

  // Validate required payload fields
  if (!body.orderId || body.amount === undefined) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: "Missing required fields: 'orderId' and 'amount' are required.",
      }),
    };
  }```

Question 3: Environment Variables vs. Hardcoding Configuration
Multi-Environment Portability:
Hardcoding 'KES' directly inside handler.js binds application business logic strictly to a single currency/region context. Injecting environment values via process.env.DEFAULT_CURRENCY allows the exact same code to run across different environments (e.g., USD in staging, KES in production) simply by updating serverless.yml or shell environment configuration without touching application source code.

Separation of Concerns (12-Factor App):
Externalizing runtime parameters to serverless.yml maintains strict separation between execution code and runtime configuration. Centralizing environment variables alongside infrastructure declarations prevents operational variables from leaking into code repositories and allows injection of dynamic CI/CD secrets at deployment time.

Question 4: Moving to FaaS & Decoupling Cold Starts
Why Moving to a Function Solves Nia's Problem:
Extracting receipt creation into an isolated serverless function removes heavy receipt generation logic from the synchronous processing path of kk-payments. kk-payments can immediately confirm a transaction and respond with 200 OK to the client without waiting for receipt processing to finish.

Architectural Change Eliminating Cold Start Impact:
Transitioning to an asynchronous event-driven architecture (e.g., kk-payments emits a payment event to an event queue/bus such as AWS SQS or EventBridge, which then triggers kk-receipts). Because the client receives its synchronous payment response before the receipt function is invoked, a 200ms–2s cold start on kk-receipts happens entirely out-of-band and has zero impact on user experience.

