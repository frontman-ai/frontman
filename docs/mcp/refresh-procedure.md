# MCP Schema And Conformance Refresh

Refresh pinned artifacts only as an intentional protocol change. Never download
or update upstream material during CI.

## Schema And Examples

1. Select the immutable upstream MCP revision and record its commit.
2. Replace only vendored schema, generated schema, examples, and license under
   `libs/frontman-protocol/test/mcp-upstream/`.
3. Recompute `SHA256SUMS`; review every changed artifact and definition count.
4. Rebuild Sury contracts and exports through package Make targets.
5. Add an authoritative-TypeScript exception only with a differential test that
   proves the generated-artifact discrepancy.
6. Reconcile all 443 traceability rows against changed normative prose.
7. Run `make -C libs/frontman-protocol mcp-verify` twice and confirm stable output.

## Conformance Runner

1. Pin an exact package version and immutable source commit.
2. Vendor unchanged source and npm archives; update checksums.
3. Review archive entries, package identity, permissions, Worker/network limits,
   timeout/output bounds, and the secret-free environment.
4. Re-evaluate scenarios from advertised capabilities. Unexpected skips fail.
5. Remove fixture corrections when upstream fixes them. Disclose any new
   correction and never call corrected evidence pristine conformance.
6. Run focused harness tests and `make mcp-conformance`.

Finally run `make mcp-check-generated` and `git diff --check`. The root
`make mcp-verify` also requires provider credentials and is not passed until its
complete serial recipe finishes. Record versions, checksums, scenarios, skips,
corrections, and residual risks in [conformance.md](conformance.md).
