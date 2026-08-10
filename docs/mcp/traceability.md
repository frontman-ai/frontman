# MCP 2026-07-28 Traceability

The Phase 0 requirement inventory is complete for the declared initial scope. Rows are traceability records, not runtime implementation claims. Planned code and test evidence must be replaced with exact locations as each owning phase is accepted.

| Matrix | Coverage |
| --- | --- |
| [`base-versioning.md`](traceability/base-versioning.md) | Base protocol, JSON-RPC, statelessness, schema usage, metadata, versioning, compatibility, extension negotiation, message patterns, and custom transports |
| [`http-security.md`](traceability/http-security.md) | Streamable HTTP, HTTP cancellation, authorization, authorization discovery, client registration, authorization security, and security best practices |
| [`tools-discovery.md`](traceability/tools-discovery.md) | Server discovery, tools, caching, pagination, schemas, headers, content, results, errors, and icons |
| [`patterns-optional.md`](traceability/patterns-optional.md) | Cancellation, progress, MRTR, subscriptions, logging, resources, prompts, elicitation, sampling, roots, and deprecated features |

Every matrix uses the required columns:

| Requirement ID | Normative text | Applicability | Code location | Positive test | Negative test | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

Requirements for unadvertised or deprecated features remain in the inventory with explicit applicability rather than being omitted. Architecture contains no uppercase BCP 14 requirements beyond the normative documents represented here.

Frontman clients recognize and validate the core `input_required` result shape because MRTR is a core message pattern. They advertise no elicitation, sampling, or roots capability and do not automatically fulfill or retry input requests. Initial Frontman servers never emit `input_required`. This is narrower than production MRTR machinery without misclassifying a core result type as unknown.
