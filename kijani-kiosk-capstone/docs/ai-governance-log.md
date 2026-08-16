# AI Governance Log

## Entry 1: 2026-08-15
- **Tool Used:** Claude 3.5 Sonnet
- **Task Description:** Generation of Ansible Jinja2 ConfigMap template.
- **Prompt Provided:** "Write a Jinja2 template for a K8s ConfigMap that injects DB_HOST and RECEIPT_BUCKET dynamically."
- **AI-Generated Output:** Valid ConfigMap manifest missing explicit namespace metadata.
- **What It Got Right:** Correct Jinja2 variable interpolation syntax (`{{ db_host }}`).
- **What It Got Wrong:** Omitted `namespace: {{ namespace }}` under metadata, defaulting creation to active namespace context.
- **Manual Modifications Made:** Manually added explicit `namespace` attribute inside `metadata`.
- **Governance Control Reference:** Control 2 (Configuration Isolation & Namespace Boundaries).
- **Reviewer Signature:** Abraham

## Entry 2: 2026-08-16
- **Tool Used:** Gemini
- **Task Description:** Authoring Prometheus alert rule for HTTP error threshold.
- **Prompt Provided:** "Provide a Prometheus alerting rule that fires when error rate exceeds 5% over 2 minutes."
- **AI-Generated Output:** Prometheus rule using `rate(http_requests_total{status="500"}[2m])`.
- **What It Got Right:** Structure of `expr`, `for`, and `labels` blocks.
- **What It Got Wrong:** Filtered strictly for HTTP 500 status codes, ignoring HTTP 502, 503, and 504 gateway failures.
- **Manual Modifications Made:** Updated status regex matching to `status=~"5.."`.
- **Governance Control Reference:** Control 5 (Observability & Alerting Precision).
- **Reviewer Signature:** Abraham
