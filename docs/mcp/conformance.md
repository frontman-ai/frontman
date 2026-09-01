# MCP Conformance

Frontman runs the official `@modelcontextprotocol/conformance` `0.2.0-alpha.11` runner at commit `c321dd32035556e6769d3724a8ee97d87c3faaac` against MCP `2026-07-28`.

The unchanged source archive and official npm package are stored under `libs/frontman-protocol/test/mcp-upstream/conformance/`. `SHA256SUMS` pins both. CI rejects unexpected paths and non-regular archive entries, extracts the package into a disposable directory, verifies its name and version, executes it without an expected-failure baseline, and deletes all runner output afterward. Node permissions limit reads to the extracted runner, package dependencies, and the Frontman client modules under test; writes are limited to the disposable directory. A preload guard permits only loopback TCP connections and denies Unix-domain sockets. The runner has no child-process permission: its exact fixed client command is intercepted and hosted in a permission-inheriting Worker, while every other child-process API is denied. The child environment contains no `PATH`, application, or provider secrets.

Run the gate with:

```text
make mcp-conformance
```

## Applicable Scenarios

The server gate runs through the real Frontman Vite Node/Web chassis with a conformance-only tool registry:

- `tools-list`
- `tools-call-simple-text`
- `tools-call-image`
- `tools-call-audio`
- `tools-call-embedded-resource`
- `tools-call-mixed-content`
- `tools-call-error`

The client gate runs the real `FrontmanClient__MCP__Client`:

- `tools_call`
- `request-metadata`
- `http-standard-headers`
- `http-custom-headers`
- `http-invalid-tool-headers`
- `json-schema-ref-no-deref`

Every selected scenario must exit successfully with no failure or warning. A skipped check also fails unless it is one of the explicitly enumerated conditional checks for roots, sampling, elicitation, resources, prompts, or initialization-era methods that Frontman does not advertise or send.

## Scope

The upstream `2026-07-28` requirements file includes scenarios for resources, prompts, completions, progress streaming, MRTR, OAuth client flows, and optional task extensions. Frontman does not advertise or implement those capabilities, so their fixture scenarios are not applicable to this release. The runner's combined `server-stateless` scenario also requires diagnostic streaming, logging, mutation, and missing-capability tools that are not production protocol capabilities. Frontman's discovery, metadata, routing, error, cancellation, and subscription-absence behavior remains covered by its normative traceability and black-box suites rather than an expected-failure baseline against that mixed fixture.

These client results are pinned-runner checks, not a claim that the unmodified upstream fixtures pass the production client. Two fixture corrections are isolated in the client command harness. Several mock discovery responses place `serverInfo` in the pre-final result body instead of `result._meta`; the harness relocates that fixture value before the strict production client parses it. The custom-header null case supplies `null` against a schema that permits only an optional boolean; the harness omits that optional value, which exercises the intended header-omission rule without weakening production argument validation. Both corrections remain visible exceptions to pristine official-client conformance until upstream fixes the fixtures.

The official runner is one proof source. It does not replace Frontman's schema, differential, transport, security, concurrency, recovery, application E2E, or traceability gates.
