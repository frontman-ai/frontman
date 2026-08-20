# MCP 2026-07-28 Traceability

The inventory contains 443 unique normative rows. Each row is a current implementation record unless its notes explicitly identify a dated historical checkpoint. Conditional features are N/A only when an exact capability or method absence test is named.

Use the [capability support matrix](capability-support.md) to distinguish JavaScript Streamable HTTP, WordPress Streamable HTTP, the browser HTTP client, the browser custom Phoenix server, and the Phoenix custom-transport client.

| Matrix | Coverage |
| --- | --- |
| [`base-versioning.md`](traceability/base-versioning.md) | Base protocol, JSON-RPC, statelessness, schema usage, metadata, versioning, compatibility, extension negotiation, message patterns, and custom transports |
| [`http-security.md`](traceability/http-security.md) | Streamable HTTP, HTTP cancellation, authorization, authorization discovery, client registration, authorization security, and security best practices |
| [`tools-discovery.md`](traceability/tools-discovery.md) | Server discovery, tools, caching, pagination, schemas, headers, content, results, errors, and icons |
| [`patterns-optional.md`](traceability/patterns-optional.md) | Cancellation, progress, MRTR, subscriptions, logging, resources, prompts, elicitation, sampling, roots, and deprecated features |

Supporting current-state documents: [endpoint/authentication](endpoint-auth.md), [implementation limits](implementation-limits.md), [custom Phoenix transport](custom-phoenix-transport.md), [private Relay migration](private-relay-migration.md), [schema/conformance refresh](refresh-procedure.md), and [protocol-safe troubleshooting](troubleshooting.md).

Every matrix uses the required columns:

| Requirement ID | Normative text | Applicability | Code location | Positive test | Negative test | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

Requirements for unadvertised or deprecated features remain in the inventory with explicit applicability rather than being omitted. Architecture contains no uppercase BCP 14 requirements beyond the normative documents represented here.

Frontman clients recognize and validate the core `input_required` result shape because MRTR is a core message pattern. They advertise no elicitation, sampling, or roots capability and do not automatically fulfill or retry input requests. Initial Frontman servers never emit `input_required`. This is narrower than production MRTR machinery without misclassifying a core result type as unknown.

The whole Phase 10 semantic-review remediation is implemented across runtime and focused
tests, including absent-result normalization, non-retrying `input_required` recognition,
opaque pagination with one invalid-cursor restart, receipt-based cache expiry, browser
invocation rate limiting, call-result identity, error-result output validation, reserved
trace-field rejection, WordPress method-based `Mcp-Name`, and OAuth absence evidence.
Independent runtime and evidence rereviews pass. This implementation record remains pending explicit acceptance, including disposition of the `BASE-AUTH-001` SHOULD deviation.
