# MCP 2026-07-28 Alignment Plan

## Purpose

Frontman will migrate aggressively and atomically to Model Context Protocol (MCP) specification version `2026-07-28`.

The target is a latest-only implementation:

- No support for initialization-era MCP versions.
- No `initialize` or `notifications/initialized` handshake.
- No `Mcp-Session-Id` protocol sessions.
- No fallback to the private Frontman relay protocol.
- No deprecated HTTP+SSE transport.
- Browser-to-framework communication uses standard MCP Streamable HTTP at `POST /mcp`.
- Phoenix-to-browser communication uses MCP over a documented custom Phoenix transport.
- Frontman advertises only capabilities it implements and validates completely.

This document is the implementation plan, specification traceability starting point, test strategy, and release acceptance contract.

Absolute absence of defects cannot be mathematically proven. The release standard is independently validated conformance, exhaustive coverage of applicable normative requirements, zero accepted conformance failures, explicit implementation limits, and documented residual risks.

## Implementation Status

Last updated: `2026-08-20`.

| Milestone | Status | Evidence or blocker |
| --- | --- | --- |
| Repository-wide comment-removal implementation | Merged | Cleanup, source-aware scanner, scanner tests, Make target, Lefthook hook, CI job, Credo alignment, and Makefile help preservation are on `main`. |
| Repository-wide comment-removal acceptance | Accepted | WordPress core-tool and runtime tests passed, followed by the source scan, generated-schema diff check, and `git diff --check`. |
| Phase 0 normative oracle and traceability | Accepted | The immutable upstream schema, 129 official examples, license, and checksum-pinned conformance archive are vendored. Offline checksums, JSON Schema 2020-12 validation, and structural verification of 443 unique normative traceability requirements pass. Concrete limits, exact boundary vectors, threat model, and initial-scope decisions are frozen. |
| Whole-corpus semantic and threat-model review | Accepted and explicitly approved | BlueHotDog approved the completed `2026-08-17` review and its corrected evidence record. All 443 rows and the threat/capability documents were reviewed against the pinned oracle and then-current source/tests. The review itself remains accepted; its dated decision rejected whole Phase 2 and whole Phase 10 at that checkpoint. The subsequently completed remediation and whole-Phase-10 acceptance are recorded separately below; the dated rejection remains historical evidence. |
| Phase 1 shared MCP wire contract | Accepted | Shared/custom-Phoenix consumers use modern per-request metadata, discovery, tools listing/calling, named errors, complete results, and `ai.frontman/execution-context`; initialization-era MCP schemas and duplicate modern exports are deleted. The serial protocol/client/core/server gate passes, deterministic differential tests pass the 1,000-case pull-request and 10,000-case scheduled profiles locally, the larger profile is configured for scheduled CI, and the pinned generated-schema `JSONValue` defect is recorded as an explicit authoritative-TypeScript exception. Phase 4 subsequently completes browser request-scoped cancellation abort. |
| Phase 2 framework Streamable HTTP server | Accepted and explicitly approved | Foundations through accepted 2K-K and explicitly approved Parts 2K-L through 2K-O implement the shared endpoint for Next.js, Vite, Astro, and WordPress. The semantic-review defects are closed. Credentialed installed Next.js, Astro, Vite, and Vue-Vite E2E passes `11/11`, server precommit passes `828/828`, one uninterrupted root `make mcp-verify` passes, and BlueHotDog explicitly approved whole Phase 2 on `2026-08-20`. Item 24 and applicable official conformance retain their accepted scopes. |
| Phase 3 browser Streamable HTTP client | Accepted and explicitly approved | `FrontmanClient__MCP__Client` owns latest-only `POST /mcp`; the temporary Relay API name and types are removed. Exact JSON/SSE response bytes, 32/33 pages, 256/257 tools, 4,096/4,097-byte cursors, definition, and catalog limits pass against a real loopback server. Focused tests prove result compatibility, opaque pagination, bounded cursor recovery, receipt-based cache expiry, hostile OAuth-challenge non-follow-up, reconnect recovery, consent, and cross-origin remote-schema validation. Credentialed installed framework recovery passes across Next.js, Astro, Vite, and Vue-Vite. BlueHotDog explicitly approved whole Phase 3 on `2026-08-20`. |
| Application consumer cutover | Accepted and explicitly approved, including credentialed browser flow | ACP transport readiness remains independent of framework availability, while session creation waits for framework discovery to succeed or reach an explicit nonfatal failure state. Browser-only creation remains available when `/mcp` is unavailable. Rejected lifecycle callbacks settle, ACP initialization replays on reconnect, local read tools and remote framework tools declaring standard `annotations.readOnlyHint: true` enter the read-only consent catalog, and absent/false hints default to write consent. Credentialed installed E2E verifies first-use read-only consent and per-invocation write consent with name and inputs. BlueHotDog explicitly approved the completed application proof on `2026-08-20`. |
| Phase 4 browser custom-Phoenix transport | Accepted, including execution capacity | The browser owns callback-specific listeners and at most `256` underlying durable executions, including cancelled tools that ignore abort until settlement. Structurally identical durable-ID replays join one execution, changed replays fail, completed replay state is count- and byte-bounded with fail-closed tombstones, exact-ID cancellation propagates through AbortSignal, and cancelled/detached late responses are suppressed. One-page listing, deterministic serialization, collision ownership, attachment metadata, and the custom binding retain their accepted proof. |
| Phase 5 existing Phoenix connection owner | Accepted | `TasksChannel` owns bounded discovery, catalog, calls, `600,000 ms` deadlines, cancellation, canonical result persistence, project-context readiness, deterministic oldest-live-owner selection/failover, and teardown. Task observers no longer own MCP. Pending work is capped at `256`; terminal records are capped at `4,096` for `900,000 ms`. Task-scoped correlation, malformed/duplicate/late fencing, last-owner and session-deletion execution quiescence, ten-seed converted-channel stability, two clean full-suite runs, strict Credo, and independent review pass. The initializer/parser/tests and browser no-op are deleted. Phase 6 subsequently adds approved durable existing-row claim authority. |
| Phase 6 durable execution ownership | Accepted | The approved no-DDL design declares namespaced claim state in the existing tool-call interaction JSONB row. Short database-time transactions serialize logical identity, lock the exact interaction UUID, acquire and renew 60-second generation-fenced claims, record dispatch intent, and atomically persist cancellation/completion with the canonical result. Independent PostgreSQL connections prove one winner, exact lease boundaries, takeover, stale-owner rejection, duplicate-row failure, typed round trips, and transactional terminal state. Browser durable-ID deduplication is count- and byte-bounded and fails closed. Frontman deploys one Phoenix node, so multi-node and cross-node acceptance are out of scope; accepted Phase 7 subsequently implements the single-node recovery architecture and its approved release-hardening fault injection. |
| Phase 7 restart-safe cancellation and timeouts | Accepted and explicitly approved, including release hardening | BlueHotDog approved the completed Phase 7 release-hardening checkpoint on `2026-08-16`. Every durable execution records one database-time start and immutable absolute deadline. Completion, cancellation, timeout, ambiguity, and recovery serialize through task-then-interaction locks and commit one canonical terminal result. A supervised recovery owner scans at most `100` due candidates every `5,000 ms`; persisted recovery markers separate terminal commit from executor delivery and reconnect resumption; task cancellation fences pre-claim work; and a monitored state owner replaces channel-owned ETS. Database races, exact boundary classification, takeover, early timers, concurrent recovery, cancellation/recovery convergence, fresh-BEAM application recovery, the post-commit/pre-notification death seam, supervised-delivery marker finalization, mixed recovered/unresolved reconnect, atomic cancellation-marker cleanup, and actual state-owner supervisor restart pass for the supported single-node deployment. |
| Phase 9 tool content and schema safety | Accepted and explicitly approved | BlueHotDog approved Phase 9 on `2026-08-14`. Canonical persistence, migration, all standard content paths, exact content/media/resource/dimension limits, invocation-time `outputSchema` snapshots, bounded isolated JSON Schema 2020-12 validation, unsupported-dialect and no-external-resolver policy, individual malformed-tool exclusion, and payload-safe logging pass focused and full gates. |
| Phase 7 release hardening | Accepted and explicitly approved | BlueHotDog approved this checkpoint on `2026-08-16`. Successful supervised-recovery delivery finalizes the exact marker; absent delivery retains `pending_resume`; mixed recovered/unresolved reconnect consumes markers only after successful execution resumption; and task cancellation consumes existing markers in its terminal transaction. A fresh separate BEAM starts the real application and recovers an overdue claim, the exact post-commit/pre-notification caller is killed at a synchronous telemetry checkpoint, and the supervised connection-state owner is killed and repopulated by a live channel. The focused `127`-test gate and full `824`-test server gate pass with warnings-as-errors compilation, formatting, strict Credo, `git diff --check`, and independent final `PASS`. |
| Item 23 CI ownership and Astro E2E cutover | Accepted and explicitly approved; installed E2E complete | BlueHotDog approved the initial checkpoint on `2026-08-16`. CI owns the Astro, Vite, and Astro-browser suites and their transitive E2E inputs. Astro, Vite, and Next.js package lint targets invoke `rescript format --check` without rejected directory arguments, and root aggregate ownership includes their lint/tests plus client, logs, statestore, SwarmAI, server, notifier, marketing, WordPress, compatibility, black-box, conformance, E2E, source, and generated gates. The remaining credentialed installed-application gate passes `11/11` and was explicitly approved on `2026-08-20`. |
| Item 24 repository-wide legacy removal | Accepted and explicitly approved | BlueHotDog approved Item 24 on `2026-08-16`. The private Relay protocol, JavaScript routes and wrappers, custom bare SSE producer, temporary client API names, generated schemas, obsolete exports, positive legacy tests, stale fixtures, browser-test references, and active documentation are removed. Explicit route-absence tests and dated historical records remain as evidence. Protocol, client, core, framework, adapter, source-scan, generated-asset, and full `824`-test Phoenix gates pass, and two independent final rereviews return `PASS`. |
| Official MCP conformance | Accepted and explicitly approved with disclosed pinned-runner fixture corrections | BlueHotDog approved this checkpoint on `2026-08-16`. The unchanged official `0.2.0-alpha.11` npm package and source commit are checksum-pinned. Seven server scenarios pass unchanged through the real Vite Node/Web endpoint. Six client runner scenarios pass through `FrontmanClient__MCP__Client`, but several malformed upstream discovery fixtures and one schema-invalid null argument are corrected by the isolated harness as documented in `docs/mcp/conformance.md`; this is not pristine unmodified-fixture client conformance. There is no expected-failure baseline, failure, or warning. Skips are rejected except for an exact allowlist of conditional capabilities and methods Frontman does not advertise. Execution has exact archive-entry validation, narrow read permissions, disposable-only writes, no child-process permission, fixed bounded Workers, a secret-free environment without `PATH`, and loopback-only networking across TCP, DNS, and UDP controls. Ten focused harness tests, all scenarios, `129` official examples, three aggregate orchestration tests, `git diff --check`, and independent final security rereview pass. |
| Root MCP aggregate verification | Accepted and explicitly approved | Root `make mcp-verify` preflights credentialed E2E, then serially owns protocol, every relevant package lint/test, notifier, marketing, WordPress, compatibility, black-box, official conformance, E2E, source-scan, and generated-asset gates. `mcp-check-generated` compares temporary pre-generation snapshots, independent of Git staging state. The nondeterministic cross-BEAM fixture-email collision was removed by using UUID-backed addresses, server precommit passes `828/828`, and one uninterrupted aggregate invocation passes. BlueHotDog explicitly approved this aggregate evidence on `2026-08-20`. |
| Phase 10 security and authorization | Accepted and explicitly approved | BlueHotDog explicitly approved the completed whole-Phase-10 semantic-review remediation on `2026-08-17`. Browser time-window limiting, active-client result recognition, opaque pagination and bounded invalid-cursor recovery, receipt-based cache expiry, browser call `serverInfo`, successful and error-result `outputSchema` validation, reserved trace-field rejection, WordPress method-based `Mcp-Name`, and focused OAuth-absence evidence pass final independent runtime and evidence rereviews. BlueHotDog explicitly accepted `BASE-AUTH-001` as a deliberate application-authentication SHOULD deviation. Frontman makes no MCP OAuth conformance claim; a complete OAuth protected-resource flow remains a future separately approved feature if remote framework MCP access is required. That `2026-08-17` acceptance did not itself accept whole Phase 2 or release; whole Phase 2 was separately accepted on `2026-08-20`, while release remains open. |
| Phase 8 deferred MRTR decision | Accepted | The initial release intentionally retains the cancellable browser-local question tool and advertises no MRTR, Roots, Sampling, or Elicitation capability. |
| Phase 11 framework adapter cutover | Accepted and explicitly approved | Shared real-process coverage, credentialed installed Next.js/Astro/Vite/Vue-Vite E2E `11/11`, WordPress runtime, and Playground scoped-runtime evidence pass. |
| Phase 12 legacy removal | Accepted and explicitly approved | Item 24 removed the private Relay runtime, initialization-era MCP behavior, obsolete generated assets, compatibility branches, and shipped legacy artifacts. |
| Release documentation and publishing | Open | Remaining README/architecture/integration/marketing and migration documentation, credential rotation, final release review, and ordinary package/version/publishing checks remain open. |

The prerequisite implementation and protocol migration remain separate atomic changes. Phases 1 through 12 retain their accepted scopes; Phase 7 remains limited to one Phoenix node. The dated `2026-08-17` whole-corpus review below records why whole Phase 2 and whole Phase 10 were rejected at that checkpoint and remains historical evidence. The corresponding runtime and evidence remediation was subsequently implemented, independently rereviewed, and explicitly accepted by BlueHotDog as whole Phase 10, including deliberate acceptance of the `BASE-AUTH-001` application-authentication SHOULD deviation. OAuth is not implemented or claimed conformant and remains a future separate feature if required. Credentialed installed-application E2E, server precommit `828/828`, and one uninterrupted root `make mcp-verify` are complete. BlueHotDog explicitly approved whole Phases 2 and 3 and the completed installed-application/aggregate gate on `2026-08-20`. The product remains unreleasable until remaining README/architecture/integration/marketing and migration documentation is complete, exposed credentials are rotated, and final security/release, package, version, and publishing checks finish.

### 2026-08-20 Credentialed Installed-E2E And Aggregate Verification Delta

1. Credentialed installed Next.js, Astro, Vite, and Vue-Vite E2E passes `11/11`. The scenario verifies framework MCP discovery, read-only session consent, write-tool per-invocation consent, ACP reconnect reinitialization, remote-schema worker startup, local and framework tool routing, and recovery after the framework MCP connection closes.
2. Installed Vite and Vue-Vite fixtures retain their configured local host, and deterministic routed WebSocket closure replaces browser offline-mode behavior that did not reliably close Chromium WebSockets.
3. Cross-origin remote schemas load through a Blob module bootstrap with an explicit worker-ready handshake and bounded startup timeout. Worker validation failures preserve their typed diagnostics.
4. Session creation waits for framework MCP discovery to succeed or fail non-fatally, eliminating the Astro catalog race while preserving browser-only operation when `/mcp` is unavailable.
5. Focused package evidence passes `170/170` frontman-client tests and `334/334` client tests with both package lint gates. WordPress runtime, Astro compatibility, no-secrets black-box, official conformance, credentialed E2E, source-comment, generated-schema, generated browser-asset, and `git diff --check` gates also pass.
6. A complete aggregate initially stopped in the Phoenix suite at `827/828` because `unique_user_email/0` used a BEAM-local integer that could collide with a row persisted by the turn-number migration test across VM restarts. UUID-backed fixture addresses remove that cross-BEAM collision; server `make precommit` passes `828/828` and the subsequent uninterrupted root `make mcp-verify` passes.

### 2026-08-20 Installed E2E, Aggregate, And Phase 2/3 Final Approval And Lessons

1. BlueHotDog explicitly approved this completed session on `2026-08-20`. Approval covers credentialed installed Next.js, Astro, Vite, and Vue-Vite application E2E, the reconnect and consent corrections required by that gate, the UUID-backed server fixture correction, generated browser-asset regeneration, one uninterrupted root `make mcp-verify`, whole Phase 2, whole Phase 3, the completed Item 23 credentialed-application gate, and the installed application-consumer proof. It does not complete remaining release documentation, rotate exposed credentials, authorize publishing, or accept the final migration release.
2. Credentialed installed application E2E passes `11/11` across Next.js, Astro, Vite, and Vue-Vite. It proves framework discovery, browser-local and framework tool routing, read-only session consent, per-invocation write consent with tool name and inputs, ACP reconnect initialization replay, remote-schema Worker readiness, recovery after framework MCP closure, and a real post-reconnect provider-backed source operation.
3. Installer-driven Vite and Vue-Vite execution must preserve the host already configured by the application. Replacing that host with an installer default can silently move the browser and WebSocket authority even when the application still appears reachable.
4. Chromium offline mode is not deterministic WebSocket-failure evidence. The accepted recovery vector closes the routed framework WebSocket explicitly, waits for the intended disconnect, and proves recovery through a replacement connection.
5. ACP reconnect must replay ACP initialization before normal session traffic resumes. MCP remains latest-only and initialization-free; this is ACP lifecycle replay, not restoration of the removed MCP `initialize` handshake.
6. Cross-origin remote-schema validation starts through a Blob module Worker bootstrap. The caller waits for an explicit ready handshake under a bounded startup timeout before sending validation work, and startup or validation failures preserve typed diagnostics rather than collapsing into an opaque timeout.
7. Remote framework tools default to write/read-write consent unless their standard MCP definition declares `annotations.readOnlyHint: true`. The merged read-only consent catalog includes those remote definitions plus local read tools; absent or false hints remain write consent. This annotation chooses the consent prompt policy and does not grant execution authorization.
8. ACP transport readiness remains independent of framework availability, but session creation waits until framework discovery either succeeds or reaches its explicit nonfatal failure state. This preserves browser-only operation while preventing the Astro catalog race.
9. Credentialed E2E executes both consent classes. It asserts one first-use prompt containing the read-only catalog and a separate write-tool prompt containing the tool name and serialized inputs.
10. Test identities that cross BEAM lifetimes must not use process-local uniqueness. UUID-backed fixture email addresses eliminate collisions with rows persisted by earlier VM runs; server `make precommit` passes `828/828`.
11. Generated browser assets are executable protocol artifacts. They must be regenerated and compared after client or protocol changes; source compilation alone does not prove the shipped Phoenix browser bundle is current.
12. Parallel worktrees can collide on host port `5173`. A failure caused by another worktree owning that port is environment contamination, not product evidence; E2E must verify port ownership or allocate an isolated port before starting fixtures.
13. The observed `Js.typeof`, Vitest `poolOptions`, and Next.js dynamic-ripgrep messages are non-failing warnings. They did not invalidate the `11/11`, `828/828`, or aggregate result, but they should be tracked separately rather than silently promoted to release blockers or described as clean diagnostic output.
14. Live credentials exposed to this session or its tooling output must be rotated before release. Rotation and removal of exposed values from local files, shell history, logs, captured output, and CI artifacts are release requirements; passing credentialed E2E does not make credential exposure an accepted residual risk.

### Current Semantic-Review Remediation And Acceptance Status

1. Browser HTTP and Phoenix clients normalize an absent `resultType` to `complete`, validate core `input_required`, surface it as unsupported, and perform no automatic MRTR retry.
2. Browser pagination forwards cursors unchanged, including repeated and empty values, and relies on the 32-page bound. A continuation `-32602` discards accumulated pages and triggers one client-owned restart from the beginning; a second invalid cursor fails without publication or retry.
3. Discovery and each tools page calculate expiry from result receipt. The catalog cache uses the earliest expiry across discovery and all pages.
4. The browser custom-Phoenix server enforces 256 new underlying tool executions per fixed 60-second server-instance window independently of its 256-active-execution cap. Identical active joins and completed durable replays do not re-execute or consume another window slot, and rate-rejected durable identities remain terminal under exact replay. The server also adds `serverInfo` to local and framework-backed call results and call errors.
5. JavaScript validates declared `outputSchema` for structured successful and `isError: true` results. Invalid or missing structured output returns correlated JSON-RPC `-32603` instead of emitting another schema-invalid tool result.
6. Shared, browser, Phoenix, framework, and WordPress metadata boundaries reject reserved `traceparent`, `tracestate`, and `baggage` fields while trace propagation is unsupported.
7. WordPress derives `Mcp-Name` authority by method: `params.name` for `tools/call` and `prompts/get`, and `params.uri` for `resources/read`, with required-header precedence for malformed named-method requests.
8. Focused browser-client evidence serves a hostile `401` `resource_metadata` challenge and proves exactly one original `/mcp` POST with zero metadata, well-known, token, or registration requests. Direction-specific optional-feature evidence replaces broad aliases in the current matrices.
9. Release checklist items 4151 and 4152 are implemented, final independent runtime and evidence rereviews return `PASS`, and BlueHotDog explicitly accepts the completed remediation as whole Phase 10. BlueHotDog also explicitly accepts `BASE-AUTH-001` as a deliberate application-authentication SHOULD deviation; this is not MCP OAuth conformance, and OAuth remains a future separate feature. Provider-backed installed-application E2E and complete root `make mcp-verify` now pass, and BlueHotDog explicitly accepted whole Phase 2 and whole Phase 3 on `2026-08-20`. Release remains blocked by remaining release and migration documentation, credential rotation, and final release acceptance.

### 2026-08-17 Whole-Phase-10 Semantic-Review Remediation Acceptance Delta

1. BlueHotDog explicitly approved the completed semantic-review remediation on `2026-08-17`. Approval covers the implemented runtime corrections, corrected direction-specific evidence, final independent runtime and evidence rereviews, this acceptance record, and whole Phase 10.
2. Final independent runtime and evidence rereviews return `PASS`. The accepted remediation covers browser 256-new-underlying-executions-per-60-second limiting, absent-`resultType` normalization, validated non-retrying `input_required` handling, opaque repeated/empty cursor forwarding, one bounded invalid-cursor restart, receipt-based cache expiry using the earliest discovery/page expiry, browser call `serverInfo`, successful and error-result `outputSchema` validation, reserved trace-field rejection, WordPress method-based `Mcp-Name`, and focused OAuth-absence evidence.
3. BlueHotDog explicitly accepts `BASE-AUTH-001` as a deliberate SHOULD deviation for Frontman's current application-authenticated deployment. JavaScript bearer/cookie policy and WordPress session/capability/nonce policy remain the endpoint authorization authorities.
4. This acceptance does not claim MCP OAuth conformance. Hostile `401` challenge evidence proves that Frontman does not accidentally initiate protected-resource metadata, well-known, registration, authorization, or token flows; absence evidence is not an OAuth implementation.
5. If remote framework MCP access becomes a product requirement, the complete MCP OAuth protected-resource profile must be implemented as a future separate feature with its own capability, threat-model, interoperability, negative, and acceptance review. No partial bearer-token approximation is authorized.
6. Whole Phase 2 remains unaccepted only because provider-backed installed Next.js, Astro, Vite, and Vue-Vite application E2E has not executed and complete root `make mcp-verify` consequently has not run. WordPress method-based `Mcp-Name`, JavaScript error-result `outputSchema` validation, and the other semantic-review defects are no longer Phase 2 blockers.
7. Release remains unaccepted. Provider-backed installed application E2E, complete root aggregate execution, remaining README/architecture/integration/marketing and migration documentation, final security/release review, and ordinary package, version, and publishing checks remain open.
8. The earlier `2026-08-17` whole-corpus review and its explicit Phase 2 and Phase 10 rejection remain dated historical evidence. Their findings were correct for that checkpoint and are not rewritten or erased by later remediation acceptance.
9. Acceptance remains compositional. Whole Phase 10 acceptance does not manufacture provider credentials, complete the aggregate, accept whole Phase 2, or authorize publishing.
10. Final executed remediation evidence is: `170/170` frontman-client tests, `483/483` frontman-core tests, `828/828` Phoenix tests with warnings-as-errors compilation, formatting, and strict Credo, `397` focused WordPress MCP assertions plus the real WordPress runtime gate, `21/21` no-secrets real-process black-box tests, `10/10` official conformance tests, `123/123` protocol verifier tests, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, staging-independent generated-schema/browser-asset checks, and `git diff --check`.
11. Complete root `make mcp-verify` was attempted and stopped at its intentional preflight because `test/e2e/.env` is absent. No provider-backed acceptance or aggregate success is inferred from the passing constituent gates.

### 2026-08-17 Whole-Phase-10 Remediation Final Approval And Lessons

1. A SHOULD deviation must be recorded as an applicable deliberate deviation, not converted to N/A because application authentication exists.
2. Absence evidence proves non-adoption only. A client making zero metadata, registration, authorization, or token requests does not establish OAuth conformance.
3. Accepting a current deployment deviation does not pre-approve a future feature. Remote MCP OAuth requires a separate complete implementation and acceptance boundary.
4. Cursor opacity forbids equality-based loop detection even when comparison appears harmless. Independent page, byte, and catalog bounds provide the compliant resource control.
5. Compatibility obligations can remain unconditional under a latest-only policy. Absent `resultType` normalizes to `complete`, while recognized `input_required` can be surfaced as unsupported without implementing fulfillment or retry.
6. Cache expiry authority begins at result receipt. Discovery and pagination latency must not consume or extend a TTL measured from another event.
7. Output-schema obligations apply to structured error results as well as successful results unless the specification grants an explicit exception. A schema-mismatch fallback must not itself be another schema-invalid successful tool result; framework and forwarded failures terminate as correlated JSON-RPC `-32603` errors.
8. Rate limits and concurrency limits control different resources. The browser window counts new underlying executions; identical joins and completed durable replays do not execute work and must retain their exact terminal result.
9. Durable identity is stronger than a rate-window reset. A rate-rejected durable identity remains terminal under exact replay; a new durable identity after window expiry may start a new execution.
10. Reserved trace names are constrained when they are immediate keys of schema-defined MCP metadata objects. Recursively interpreting arbitrary vendor JSON as metadata rejects valid open protocol data.
11. Acceptance records must distinguish runtime scope, phase scope, and release scope. Whole Phase 10 can be accepted while whole Phase 2 remains blocked by installed E2E and the aggregate and release remains blocked by later gates.
12. Remediation acceptance supersedes current status, not historical evidence. Dated rejection findings remain useful regression criteria and must not be silently rewritten.
13. A final stale-state sweep must cover the top-level status table, current architecture, package checklists, phase work and proof gates, release checklist, residual risks, and implementation order. Reviewing only the new acceptance delta leaves contradictory current prose behind.
14. Structural traceability guards should reject known evidence placeholders, but matrix shape still cannot prove semantic correctness. Runtime dispatch paths and named tests remain the authority.
15. Integrated boundaries matter. The browser HTTP client correctly rejecting invalid framework output was insufficient while the custom-Phoenix wrapper converted that rejection back into a schema-invalid success; end-to-end owner composition exposed the defect.
16. Error diagnostics crossing a peer boundary must remain categorical. Forwarded framework validation failures return a fixed internal error, do not leak peer diagnostics, and replay without another underlying call.
17. “Blocked only by” is an evidence claim. Every stale unchecked task or superseded blocker in current sections must be corrected before that phrase is accurate.
18. Provider-blocked E2E cannot be inferred from focused, black-box, conformance, or no-secrets evidence. Acceptance must continue to name exactly what was not executed.
19. ReScript package outputs share generated interfaces. A stale Astro interface appeared after protocol changes even under serial verification; cleaning through the package Make target and rebuilding serially restored a trustworthy black-box gate without weakening checks.
20. Test names are evidence claims too. Boundary names such as request 256/257, exact expiry, actual process death, or framework-output failure must match the vector being exercised rather than borrowing a nearby limit or implementation detail.

### 2026-08-17 Whole-Corpus Semantic And Threat-Model Review Acceptance Delta

This section is a dated historical checkpoint. Its rejection findings were accurate on `2026-08-17`; the later acceptance delta above supersedes current status only and does not erase or rewrite this evidence.

1. BlueHotDog explicitly approved the completed review on `2026-08-17`. Approval covers the review method, corrected traceability/capability/threat-model records, explicit Phase 2 and Phase 10 rejection, verification evidence, and lessons below. It does not approve either rejected phase, waive a normative requirement, supply missing provider credentials, complete the root aggregate, or authorize release.
2. Independent reviewers examined all `443` requirement rows across `base-versioning.md`, `http-security.md`, `tools-discovery.md`, and `patterns-optional.md`. A separate security review covered `docs/mcp/threat-model.md` and `docs/mcp/capability-support.md`. Every actionable finding was checked against the exact normative wording and current implementation/test path before it was accepted, narrowed, or rejected.
3. Whole Phase 2 is rejected. Existing approved slices retain their exact scope, but provider-backed installed application E2E and the root aggregate remain blocked, WordPress has incomplete method-based `Mcp-Name` enforcement under `HTTP-028`, and JavaScript bypasses declared output-schema validation for `isError: true` results under `TD-RESULT-007` without a normative exception.
4. Whole Phase 10 is rejected. The browser custom-Phoenix tool server caps active executions but has no time-window invocation rate limit. JavaScript and WordPress principal limiters remain accepted for their exact endpoints.
5. Active browser and Phoenix clients accept only `resultType: "complete"`. The standalone schema recognizes `input_required`, but active consumers reject it, and they reject absent `resultType` instead of treating it as `complete`. These are core receiver gaps even though Frontman advertises no MRTR fulfillment capability and performs no automatic retry.
6. The browser HTTP client compares cursor values to reject repeats, violating cursor opacity. Cache expiry is timestamped before discovery rather than after receipt or catalog assembly, and invalid-cursor recovery fails closed without the recommended client-owned restart.
7. JavaScript and WordPress include `serverInfo` on their documented results. The browser custom-Phoenix server includes it on discovery and list but not local call results.
8. Reserved `traceparent`, `tracestate`, and `baggage` fields are accepted without required when-present format validation. Trace propagation absence does not make malformed reserved fields conformant.
9. Several evidence claims exceeded their tests, including OAuth absence, optional-feature direction/dispatcher proof, active SSE cancellation, UTF-8/Origin breadth, and cache/pagination vectors. The matrices now distinguish source review, generic infrastructure tests, focused runtime tests, and active black-box evidence.
10. The capability matrix now distinguishes JavaScript/WordPress `tools.listChanged: false` from the browser custom-Phoenix server's omitted field and required `ai.frontman/execution-context` extension. It also distinguishes browser-server execution capacity from a normative time-window rate limiter and narrows browser `serverInfo` claims to discovery/list.
11. The threat model now records wholesale result `_meta` scrubbing before canonical persistence, payload-safe categorical log fields, the supported one-Phoenix-node boundary, and the difference between portable Node/API guards and OS-enforced hostile-code containment.
12. Stale current-state prose was corrected after the first documentation pass. Current sections no longer call accepted restart recovery, durable deadlines, Relay removal, or the semantic review incomplete. Dated historical checkpoints remain intact where they explicitly identify their former limits.
13. Final verification passed the offline protocol gate with `116` tests, all `129` official examples, and structural verification of all `443` unique requirement rows. `git diff --check` passed. A resumed independent final rereview returned `PASS` after the stale current-architecture statement was corrected.

### 2026-08-17 Whole-Corpus Review Final Approval And Lessons

1. Structural traceability is an inventory gate, not a semantic conformance gate. Eight non-empty cells and a unique requirement ID cannot prove that cited code exists, a named test exercises the claim, applicability is correct, or runtime behavior satisfies the normative text.
2. A schema existing in the shared contract does not prove production recognition. `InputRequiredResult` passed shared verifier fixtures while both active clients explicitly rejected it; evidence must follow the value through the actual consumer dispatch path.
3. Latest-only version policy does not erase unconditional receiver compatibility. Rejecting initialization-era negotiation is separate from the core requirement to treat an absent `resultType` as `complete`.
4. Capability omission is not a universal N/A certificate. Base receiver obligations still apply, and features such as progress and subscriptions may be activated by method or request metadata rather than a standalone advertised capability.
5. Absence proof must be direction- and owner-specific. Exact capability objects, method receiver allowlists, notification producer inventories, and client request producers prove different things; one representative unsupported-method test cannot stand in for all four.
6. Concurrency and rate are separate controls. A cap of 256 active durable executions bounds simultaneous work but does not limit an authenticated principal issuing an unlimited sequence of short calls.
7. Failing closed is not equivalent to implementing recovery guidance. Returning an invalid-cursor error prevents cache contamination, but it does not implement the client's recommendation to discard pages and restart from the beginning.
8. Opaque means opaque even when comparison looks harmless. Repeated-cursor detection inferred loop meaning from token equality and violated the explicit rule; the independent page-count bound is the compliant resource-exhaustion control.
9. Cache clocks must start at the specified event. Capturing time before discovery means network, pagination, and validation consume a TTL defined from response receipt; tests need delayed responses and exact expiry boundaries, not only a fake clock near cache access.
10. Infrastructure evidence cannot be promoted to active-protocol evidence. A generic chassis test that closes an arbitrary response reader does not prove cancellation of an emitted MCP SSE response, and closing an incomplete request upload exercises a different direction.
11. Application authentication does not make the MCP HTTP authorization recommendation disappear. The correct record is an applicable SHOULD with a deliberate application-authentication deviation, not OAuth N/A used as a blanket classification.
12. When-present requirements remain active when propagation is absent. Accepting reserved trace fields as arbitrary JSON is different from ignoring unknown vendor metadata; reserved W3C fields must be validated or rejected.
13. Error results do not gain undocumented schema exemptions. If a tool declares `outputSchema`, the normative text does not exclude `isError: true`; an implementation exception must be removed or recorded as a deviation rather than described as conformance.
14. Security documentation must name the actual enforcement boundary. Node permissions, monkey-patched APIs, a secret-free environment, and resource bounds are useful defense in depth, but they are not a container, separate UID, kernel egress policy, or hard host memory boundary.
15. Deployment scope is part of every proof claim. Independent PostgreSQL connections prove transactional contention inside the supported single-node architecture; they do not prove distributed Registry ownership, leader election, partition handling, or cross-node recovery.
16. Review findings are hypotheses until checked. The review correctly narrowed an initial WordPress claim: well-formed `prompts/get` already rejects a missing `Mcp-Name` through body-name comparison, while `resources/read` and malformed named-method requests expose the actual method-based enforcement gap.
17. Acceptance is compositional and must remain scoped. Approving this review means its findings, corrections, rejection decisions, and evidence are accepted; it does not retroactively revoke sound focused checkpoints or convert unresolved runtime gaps into accepted residual risks.
18. Documentation review requires a second stale-state sweep after edits. The first pass corrected matrices but left current plan summaries saying semantic review, restart recovery, deadlines, and Relay cleanup were still open; the resumed final review caught those contradictions.
19. A final `PASS` is meaningful only after every concrete finding is either corrected or rejected with evidence. Reviewer agreement is not authority; the pinned specification, current code, and executable tests remain authoritative.

### 2026-08-17 Consent, Security, And Verification Delta

1. BlueHotDog explicitly chose the browser-host consent policy. `libs/client/src/Client__ToolConsent.res` requests first-use session consent listing the sorted read-only catalog and requests consent for every write/read-write invocation with its tool name and serialized inputs. `libs/client/test/Client__ToolConsent.test.res` proves one-session read consent, per-write prompting, displayed inputs, and retry after denial.
2. `libs/frontman-client/src/FrontmanClient__MCP__Server.res` exposes the `authorizeTool` callback and calls it before either local execution or framework dispatch. `libs/client/src/Client__FrontmanProvider.res` wires `Client__ToolConsent.make()`. `libs/frontman-client/test/FrontmanClient__MCP.test.res` proves denial returns `Tool invocation denied by user` and produces zero framework `tools/call` requests.
3. `test/e2e/helpers/frontman-ui.ts` accepts browser dialogs during the provider-backed recovery operation and requires both a read-only session prompt and a write-tool prompt. Those assertions are implemented but not executed because BlueHotDog explicitly chose not to provide `test/e2e/.env`; no provider-backed acceptance is inferred.
4. BlueHotDog explicitly reviewed and accepted four recommendation-level limits: fixed per-request timeout policy (`CAN-004`/`CAN-TIMEOUT-CONFIG`), terminal cancellation visibility without a separate cancellation-request state (`CAN-012`/`CAN-OBSERVABILITY`), framework-owned local listener binding (`HTTP-006`), and embedding-host local-process sandbox/least-privilege guidance (`SBP-011`). They are accepted SHOULD deviations or residual host responsibilities, not unimplemented MUSTs.
5. `libs/frontman-core/src/FrontmanCore__Middleware.res` provisions the browser MCP credential as a `/mcp`-scoped `HttpOnly; SameSite=Strict` cookie with `Secure` on HTTPS; `libs/frontman-core/test/FrontmanCore__Middleware.test.res` proves encoding, flags, local-HTTP behavior, and absence from HTML.
6. JavaScript and WordPress both enforce 256 requests per 60-second principal window. Sources are `libs/frontman-core/src/FrontmanCore__MCP__RateLimiter.res` and `libs/frontman-wordpress/includes/class-frontman-mcp.php`; tests are `libs/frontman-core/test/FrontmanCore__MCP__RateLimiter.test.res`, `libs/frontman-core/test/FrontmanCore__MCP__Endpoint.test.res`, and `libs/frontman-wordpress/tests/McpTest.php`, including request 257, exact expiry, principal isolation, and no execution on rejection.
7. Framework result identity uses JSON/Sury metadata merging rather than discriminator rewriting. `libs/frontman-core/src/FrontmanCore__Server.res::resultMeta` and `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res::completeToolResult` own the merge; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` proves adding `serverInfo` preserves an audio block as audio rather than image.
8. Root `Makefile::mcp-verify` aggregate ownership now includes Next.js, Astro, Vite, Astro-browser, application client, logs, React statestore, SwarmAI, Phoenix server, notifier, marketing, WordPress, Astro compatibility, black-box, conformance, E2E, source-scan, and generated checks. `test/mcp-verify/mcp-verify.test.mjs` exact-compares the serial recipe.
9. `libs/frontman-astro/Makefile`, `libs/frontman-vite/Makefile`, and `libs/frontman-nextjs/Makefile` now call `yarn rescript format --check` without directory arguments. The former Astro/Vite formatter failure is closed and is not a release blocker.
10. Notifier dependencies are refreshed in `apps/frontman_notifier/mix.exs` and `mix.lock`, including `postgrex 0.22.4`, `req 0.7.2`, `finch 0.23.0`, and `mint 1.9.3`; notifier lint/test are owned by the aggregate. The earlier unavailable/outdated dependency residual is closed.
11. Generated checks are staging-independent. `libs/frontman-protocol/Makefile::check-schemas` snapshots schemas to a temporary directory before generation, and root `Makefile::mcp-check-generated` does the same for the browser-test asset before rebuilding and diffing. `test/mcp-verify/mcp-verify.test.mjs` verifies aggregate ownership and browser-asset comparison.
12. At this checkpoint, release was not accepted. By BlueHotDog's explicit decision, absent `test/e2e/.env` blocked provider-backed Next.js, Astro, Vite, and Vue-Vite E2E and therefore blocked a complete `make mcp-verify`; whole Phase 2, whole Phase 10, and release acceptance could not be recorded from the evidence then available. The later semantic-review remediation acceptance supersedes only the whole-Phase-10 status; whole Phase 2 and release remain blocked.
13. Rate limiting now derives its key through `FrontmanCore__MCP__HttpSecurity.policy.principal` after successful authorization. Generated Next.js authorization classifies a valid browser cookie and configured bearer token into stable principals, so rotating arbitrary credential text cannot evade the limit. Core `481/481`, Next.js `193/193`, and real-process request-257 proof pass.
14. The shared middleware already issued the configured browser cookie for all adapters, but `FrontmanVite__Plugin.frontmanPlugin` dropped `mcpBrowserToken` while reconstructing its internal config. The option is now forwarded. Vite passes `7/7`, and the rebuilt no-secrets black-box matrix passes `18/18` across Next.js, Astro, Vite, and WordPress with HttpOnly cookie provisioning asserted for every JavaScript framework.
15. JavaScript dependencies were refreshed to patched compatible releases, with narrow root resolutions for transitive packages whose parent ranges otherwise retain vulnerable versions. `yarn npm audit --all --recursive --severity high` reports `No audit suggestions`; marketing passes `28/28` tests and a clean `147`-page production build; black-box and official conformance were rerun after the lockfile change and pass `18/18` and `10/10` respectively.
16. Phoenix moved from vulnerable `decimal 2.4.1` to `3.1.1` by updating the test-only `ex_json_schema` constraint, and compatible Phoenix, LiveView, Postgrex, Sentry, Swoosh, Bandit, Cowboy, and cowlib releases were refreshed. `make precommit` passes warnings-as-errors compilation, formatting, strict Credo, and all `824` tests. No patched cowlib release exists for `CVE-2026-43966` or `CVE-2026-43969`; both are narrowly acknowledged in `mix.exs`, and the deployed application remains on Bandit rather than Cowboy.

### 2026-08-17 Phase 2/10 Security-Hardening Approval And Lessons

1. BlueHotDog explicitly approved this security-hardening checkpoint on `2026-08-17`. Approval covers the trusted-principal rate authority, generated Next.js credential classification, Vite browser-cookie plumbing fix, dependency remediation and disposition, executed regression/security gates, and this documentation record. It does not convert missing provider credentials into E2E evidence, complete root `make mcp-verify`, accept all of Phase 2 or Phase 10, or approve release publishing.
2. Authorization and rate identity are separate policy outputs. Successful authorization alone does not make attacker-supplied header text a safe limiter key; the policy now returns a trusted principal after authorization, and the endpoint carries that principal into rate checking before parsing or execution.
3. Generated Next.js authorization maps a valid `frontman_mcp_session` cookie to `configured-browser-cookie` and the configured bearer token to `configured-bearer-token`. A valid browser cookie remains the principal even when an attacker rotates an accompanying bearer header, so requests 1 through 256 succeed and request 257 returns an empty `429` without tool execution.
4. The default shared policy principal remains the canonical authorized Origin when an embedding adapter does not provide a more specific principal callback. This is stable and attacker-header-independent, but applications with multiple independently authorized users behind one Origin should supply an authorization-specific principal if they require separate budgets.
5. Security options must survive every adapter configuration boundary. Core middleware and Vite config already supported `mcpBrowserToken`, but `frontmanPlugin` reconstructed a narrower object and silently dropped the field. Real HTTP proof caught what config-unit proof did not: Vite served `/frontman/` without `Set-Cookie` until the option was forwarded.
6. Cookie proof must exercise the installed UI response and authenticated endpoint together. The final black-box test requires `frontman_mcp_session`, `HttpOnly`, and `SameSite=Strict`, then sends that cookie to `/mcp` while supplying a hostile bearer value. Next.js additionally proves the complete 257-request stable-principal boundary.
7. Remote framework annotations are not trusted authorization metadata. Tools learned through a remote framework catalog default to write consent rather than gaining session-wide read consent from framework-supplied annotation claims; denial occurs before local or framework invocation.
8. Dependency remediation must follow the vulnerable function into the actual dependency tree. Decimal required a major move to `3.1.1`; the production consumers allowed it, while test-only `ex_json_schema 0.11.3` was the constraint retaining Decimal 2 and therefore had to move to `0.11.5`.
9. `mix hex.audit` can report an advisory for the newest published release when upstream has not shipped a fix. The two cowlib findings are not silently called fixed: they are exact ignored advisory IDs in `mix.exs`, Cowboy enters through Bypass/optional tooling, the deployed endpoint uses Bandit, and the disposition must be removed when a patched cowlib release becomes available.
10. Open-ended Yarn resolutions are unsafe even when their lower bound is patched. The first attempt allowed `undici >=7.29.0` to resolve to 8.x and similarly risked cross-major upgrades for transitive libraries. The final resolutions preserve compatible major ranges, and ordinary recursive updates select patched releases within each parent's declared range.
11. A clean dependency audit is necessary but not sufficient. After `yarn npm audit` became clean, the marketing production build failed because Astro externalized `cookie` while Yarn hoisted Express's CommonJS `cookie 0.7.2`. Adding root development dependency `cookie 2.0.1` made Astro's ESM package authoritative while Express retained its compatible nested copy; the subsequent 147-page build passed.
12. A vulnerable dependency with no patched release should be removed through its parent when possible. `extract-zip 2.0.1` disappeared only after the sole parent path, `astro-icon -> @iconify/tools`, was moved to the current `@iconify/tools 5.x`; no fake direct pin or audit suppression was used.
13. The final JavaScript remediation covers every high finding observed during this session: `brace-expansion`, `extract-zip`, `fast-uri`, `fast-xml-parser`, `ip-address`, both `js-yaml` lines, `nanoid`, the vulnerable Next.js workspace resolution, `postcss`, `sharp`, both `svgo` lines, and `undici`. Root direct/resolution controls now include major-bounded `undici 7`, `sharp 0.35`, patched `postcss`, current `@iconify/tools 5`, and `cookie 2.0.1`; marketing uses Astro `7.2.2` and Starlight `0.41.7`, and the blog-starter Next.js range starts at patched `16.2.12`.
14. Repository commands are part of the evidence contract. `mix precommit` does not exist in `frontman_server`; the canonical server gate is `make precommit`, which owns warnings-as-errors compilation, unused-dependency cleanup, formatting, strict Credo, and the complete test suite.
15. ReScript package builds remain serial because generated outputs are shared. Core, Next.js, Vite, adapter rebuilds, black-box, and conformance were run in sequence; parallel package compilation would weaken evidence by reintroducing known generated-artifact races.
16. Final executed evidence after the lockfile refresh is: core `481/481`, Next.js `193/193`, Vite `7/7`, Phoenix `824/824`, marketing `28/28` plus a 147-page production build, real-process black-box `18/18`, official conformance `10/10`, all `129` official examples, JavaScript high-severity audit with `No audit suggestions`, successful disposition-aware Hex audit, and `git diff --check`.
17. Focused independent re-review found no correctness defect in dependency disposition, Vite token forwarding, principal authority flow, generated Next.js classification, or black-box coverage. Its lone low style note concerned `if` statements inside generated TypeScript text and was rejected because the repository's ReScript `switch` rule does not govern control flow in emitted TypeScript source strings.
18. At this checkpoint, root `make mcp-verify` stopped because `test/e2e/.env` was absent. Provider-backed installed Next.js, Astro, Vite, and Vue-Vite recovery, complete aggregate execution, semantic-review remediation, and final publishing/release checks remained open; the whole-corpus review itself was complete. The later acceptance delta closes semantic-review remediation only.

### 2026-08-16 Phase 7 Acceptance Delta

This section preserves the historical pre-hardening acceptance checkpoint. Its recorded residuals are closed by the later release-hardening acceptance and final-approval sections below.

1. BlueHotDog gave final approval to the implemented Phase 7 checkpoint on `2026-08-16`. Durable claim state now includes one database-clock `started_at`, immutable `deadline_at`, and explicit recovery-delivery state without adding a table, column, migration, broker, or multi-node scheduler. Approval preserves the release-hardening residuals discovered during the final documentation audit rather than converting unrun fault vectors into evidence.
2. Initial acquisition computes the lease and absolute deadline from one PostgreSQL timestamp. Safe pre-send and verified-idempotent takeover preserve the original start and deadline; reconnect cannot reset the execution budget.
3. Equality remains active by contract: completion at the exact deadline wins, while the first representable instant after it selects timeout. Early process-timer delivery re-reads database time, cancels the stale timer, and schedules only the persisted remainder.
4. Completion, cancellation, timeout, ambiguity, recovery, and task-wide cancellation use the same task-then-interaction lock order. Independent PostgreSQL connections prove timeout/completion convergence, concurrent recovery convergence, and recovery/cancellation convergence without duplicate results or deadlocks.
5. Task cancellation atomically resolves both claimed and persisted-but-not-yet-claimed tool calls. Claim acquisition checks for an existing terminal result under the task lock, so cancellation before dispatch cannot be followed by a late browser side effect.
6. `FrontmanServer.MCPRecovery` is a supervised owner with a bounded candidate count. It scans at most `100` due claims every `5,000 ms`, resolves absolute-deadline expiry and expired started non-idempotent ambiguity, rechecks every candidate under lock, and remains idempotent across concurrent sweeps. The count bound does not impose a wall-clock bound on database lock waits or total sweep duration.
7. Ordinary claimed completion, timeout, and ambiguity paths persist `pending_resume` with the canonical terminal result before commit. Successful delivery through the ordinary completion path advances the exact claim to `resumed`; absent delivery retains durable resume evidence. Task-wide cancellation deliberately writes `resumed`, and pre-claim cancellation has no claim to mark. Supervised recovery currently notifies a live executor but does not finalize that claim's marker from the returned delivery status; this is release-hardening work.
8. Task cancellation terminally fences both claimed and persisted-but-not-yet-claimed calls. It clears pre-existing recovery markers after the cancellation transaction, so the tested recovery/cancellation race converges without revival; however, a process death between cancellation commit and the follow-up marker transaction remains an explicit seam to close. Legacy backend tools without durable MCP rows retain their established fallback cancellation path.
9. Safe pre-send claims become reclaimable at their persisted lease boundary. Started non-idempotent claims are never blindly replayed and become one canonical ambiguity result after ownership expiry.
10. `MCPConnectionState` replaces channel-owned ETS handles with one supervised GenServer that owns immutable catalog and project-context snapshots and monitors registered channel PIDs. Concurrent reads remain safe while a channel owner dies, dead owners are removed, and state can be repopulated for a live channel. The current restoration test unregisters and repopulates channel state; it does not kill and supervisor-restart `MCPConnectionState` itself.
11. Focused proof covers pure exact deadline classification, immutable takeover, early timers, pre-claim cancellation, safe pre-send takeover, ownerless task cancellation, concurrent recovery, recovery/cancellation convergence, normal live-delivery marker finalization, supervised recovery startup, abrupt channel-owner loss, state repopulation, and duplicate/late result fencing. It simulates absent process-local state but does not restart the BEAM/application or kill the exact owner after terminal commit and before notification.
12. The accepted implementation gate passed warnings-as-errors compilation, formatting, strict Credo with zero issues, all `819` server tests, `git diff --check`, and an independent final PASS review. The subsequent plan audit identified proof overstatement and marker-lifecycle residuals that the green gate did not expose. Multi-node and cross-node Phoenix scheduling remain explicitly out of scope. At this historical checkpoint, Phase 7 release hardening remained open; the later acceptance section closes it, while Relay deletion, provider-backed installed application E2E, official conformance, and final release review remain open.

### 2026-08-16 Phase 7 Final Approval And Lessons

This section preserves the audit findings that defined the release-hardening work. The findings remain useful regression criteria; their actionable single-node residuals are closed below rather than erased from the record.

1. Database time is execution authority; process timers are only wakeups. An early timer must reread PostgreSQL time and schedule the persisted remainder rather than inventing a new local deadline.
2. Start and deadline form one immutable execution budget. Reconnect, lease renewal, and generation takeover may change the live owner but must never reset elapsed time.
3. Logical identity and row identity solve different races. The task row serializes `{task_id, turn_number, tool_call_id}` creation, while the exact interaction row and claim generation fence one persisted execution.
4. One task-then-interaction lock order is a correctness feature, not merely style. Completion, timeout, ambiguity, recovery, and task cancellation can converge only when every competing terminal path acquires authority in the same order.
5. Persisting `started` before the Phoenix push deliberately trades possible false ambiguity for protection against duplicate non-idempotent side effects. A crash after the marker but before bytes leave the process cannot be distinguished from a dispatched call, so automatic replay is unsafe.
6. Safe takeover is state-dependent. An expired pre-send `claimed` lease may be reclaimed; an expired `started` claim may be replayed only when verified idempotent; otherwise it must become one canonical ambiguity result.
7. Terminal persistence, executor notification, and recovery-marker consumption are three separate lifecycle stages. A transaction can select the correct result while a later delivery or marker-finalization seam remains incomplete; every producer, including supervised recovery, must own all applicable stages.
8. A recovery batch bound is not a latency bound. Limiting each sweep to `100` candidates controls work amplification, but database waits and sequential per-candidate transactions still determine wall-clock duration.
9. Reconnect logic must handle mixed state, not only the zero-unresolved happy path. A task may contain a recovered terminal result and another unresolved call; dispatching the latter must not strand the earlier `pending_resume` marker.
10. Cancellation and recovery-marker cleanup must be one durable decision when a crash between transactions could preserve stale resume authority. Passing a concurrent race without injecting that exact seam does not prove atomicity.
11. Fault-injection names must match the process actually killed. Killing a channel owner proves channel-owner loss; unregistering and repopulating state does not prove supervisor restart of the state owner; direct context calls with process-local state absent do not prove a BEAM/application restart.
12. Post-commit crash safety requires an injected failure after the database commit and before executor notification. Separately proving a retained marker with no executor and marker clearance during ordinary live delivery is useful, but it does not exercise that named window.
13. Exact equality semantics need separate wording from end-to-end race evidence. Pure classification proves that equality remains active and `+1 microsecond` expires; the integration race currently forces the deadline into the past rather than arranging a transaction at exact database equality.
14. Ecto queries are lazy values until a repository operation executes them. The first full-gate marker failures came from a test helper that built an update query without executing it; fixing the helper, rather than weakening marker assertions, restored the intended database setup.
15. Timing-based asynchronous tests need a budget that reflects the owning process and database work. The focused recovery test's original wait was too tight under the complete suite; extending only that polling budget removed suite-order timing noise without changing production deadlines.
16. Green compilation, Credo, focused races, and `819` tests were necessary but not sufficient evidence. A final claim-by-claim documentation audit still found an ignored supervised-delivery status, a mixed-state reconnect gap, a two-transaction cancellation seam, and several test names broader than their actual fault injection.
17. Deployment scope remains part of correctness. Independent PostgreSQL connections are relevant single-node contention proof; distributed scheduling, cross-node Registry ownership, partitions, and multi-node recovery remain unsupported rather than silently inferred.
18. Final approval records the substantial single-node recovery architecture delivered in this session while keeping release hardening explicit. Approval is not permission to erase known residuals, call simulated process loss a real application restart, or promote test descriptions beyond their fixtures.

### 2026-08-16 Phase 7 Release-Hardening Acceptance Delta

1. BlueHotDog explicitly approved the completed Phase 7 release-hardening checkpoint on `2026-08-16`. Approval covers the implemented and executed single-node vectors below, not multi-node recovery or distributed execution ownership.
2. Supervised recovery now consumes its delivery result. `:notified` advances the exact recovered interaction from `pending_resume` to `resumed` under the established task-then-interaction lock order; `:no_executor` deliberately leaves durable resume evidence.
3. Any successful inactive-task resumption consumes pending markers. The mixed-state vector persists one recovered terminal call and one unresolved call, redispatches only the unresolved call, resumes once after its result, and proves that the prior marker is no longer stranded.
4. Task-wide cancellation locks existing `pending_resume` rows and unresolved tool calls beneath the same task lock, advances the old markers, and inserts canonical cancellation results in one transaction. The former post-commit marker-cleanup transaction is deleted.
5. A synchronous `[:frontman_server, :mcp, :tool_call, :committed]` telemetry checkpoint identifies the exact durable-commit boundary before broadcast or executor notification. Fault injection blocks the completing caller at that checkpoint, kills it, proves one canonical result and retained `pending_resume`, and proves that the executor received no result.
6. A fresh separate BEAM starts the real `frontman_server` application against the committed test database with supervised recovery enabled. It resolves an overdue claim without inherited Registry, channel, timer, or process-local state and leaves `pending_resume` because no executor exists.
7. The test kills the actual named `MCPConnectionState` process and observes a different supervisor-started PID. A live channel recreates its catalog state and republishes completed project-context readiness; pending and in-flight contexts retain the recreated connection's explicit `:pending` default.
8. Focused proof passes `127` tests. The complete server gate passes warnings-as-errors compilation in development and test environments, formatting, strict Credo with zero issues, all `824` tests, `git diff --check`, and an independent final `PASS` review.
9. Multi-node recovery, distributed Registry ownership, partitions, and cross-node scheduling remain unsupported. Release-hardening acceptance closes the recorded single-node lifecycle seams without changing that deployment boundary.

### 2026-08-16 Phase 7 Release-Hardening Final Approval And Lessons

1. A delivery status is part of durable state transition input, not disposable notification metadata. Ignoring `:notified` in supervised recovery left a successfully delivered execution marked `pending_resume`; every terminal producer must consume the delivery outcome it creates.
2. Marker finalization after one delivered result must target the exact tool-call interaction. Task-wide marker consumption remains appropriate only when the task execution itself has successfully resumed or task cancellation has terminally superseded every pending recovery.
3. `:notified` means the result message was sent to a currently registered executor; it is not an executor acknowledgement. The accepted single-node contract advances the marker after that send, while reconnect recovery remains responsible when no executor is registered.
4. Durable cancellation is not atomic if canonical cancellation results commit before stale recovery authority is cleared. Locking old `pending_resume` rows and unresolved calls beneath one task lock converts cancellation and cleanup into one rollback-safe database decision.
5. Lock order remains task first, interaction second. Adding marker finalization and cancellation cleanup did not justify a new lock order; preserving the existing order keeps recovery, timeout, completion, ambiguity, and cancellation convergent.
6. Reconnect must converge mixed state at the point where the final unresolved call permits execution resumption. Handling markers only in the zero-unresolved entry path misses the common case where one call recovered before reconnect and a sibling completes afterward.
7. Marker consumption must follow successful resumption, never precede it. If `Tasks.resume_execution/3` fails, `pending_resume` remains durable evidence for a later attempt rather than being cleared optimistically.
8. A named post-commit fault requires control at the exact post-commit seam. Ownerless completion tests and ordinary marker-retention assertions were useful but did not prove process death between commit and notification; the synchronous telemetry checkpoint made that window deterministic.
9. The telemetry checkpoint executes synchronously on the completion caller. Production telemetry handlers attached to this event must therefore remain bounded and nonblocking; the blocking handler exists only inside the controlled fault-injection test and is detached in test cleanup.
10. Post-commit fault proof needs negative side-effect assertions. The test proves not only that the canonical result and `pending_resume` survive, but also that the registered executor receives no result before the caller is killed.
11. Fresh-process recovery must exclude inherited local state. Starting a separate BEAM against committed PostgreSQL state proves application startup recovery without inherited Registry entries, channel PIDs, process timers, or test-process ownership.
12. The fresh-BEAM vector is precisely scoped. It proves a fresh real application instance can recover committed durable state; it does not claim a same-VM hot restart, operating-system reboot, multi-node election, or distributed scheduler behavior.
13. External-process tests need their own bound. The nested `mix run --no-start --no-compile` invocation is wrapped in a task with a `20,000 ms` limit, while the child recovery poll is independently bounded to `100` attempts at `50 ms` each.
14. State-owner restart proof requires killing the actual named process and observing a different supervisor-started PID. Unregistering a connection or killing a channel owner exercises different behavior and cannot substitute for this vector.
15. Restoring the catalog first recreates the connection snapshot with explicit `:pending` project-context defaults. The live channel then republishes only completed `{:loaded, fingerprint}` contexts as `:ready`; pending and in-flight work correctly remains pending rather than being promoted.
16. Independent review findings still require claim-by-claim evaluation. A review concern that pending contexts were not explicitly republished was rejected with code and test evidence because catalog restoration creates the pending default before ready contexts are restored; unrelated pre-existing findings were not folded into this atomic hardening change.
17. TDD exposed the ignored supervised-delivery status before implementation. The focused recovery test failed with a retained marker, then passed only after exact-row finalization consumed `:notified`; the post-commit fault test likewise failed until the real committed seam existed.
18. Full-suite evidence matters after focused races. The focused four-file gate passed `127` tests, while the complete server suite increased from `819` to `824` tests and passed alongside development/test warnings-as-errors compilation, formatting, strict Credo, and `git diff --check`.
19. Static analysis improved the final shape. Strict Credo rejected an overly nested recovered-marker finalizer; extracting the transaction body retained fail-loud behavior while restoring the repository's maximum nesting discipline.
20. No schema, table, column, migration, broker, or second recovery owner was required. The hardening work closes lifecycle seams around the accepted existing-row claim model rather than replacing it.
21. The existing Phoenix transport changeset now explicitly records atomic recovery-marker cleanup, mixed-state reconnect recovery, and direct restart fault injection so release notes do not omit the hardening behavior.
22. Phase 7 is fully accepted for Frontman's supported one-Phoenix-node deployment. The later approved item-23 checkpoint closes the identified workflow path and package-test ownership gaps, and Item 24 removes the private Relay implementation and artifacts. The applicable official conformance gate now passes. At this `2026-08-16` checkpoint, the implemented root aggregate stopped at its credential preflight, so provider-backed installed application E2E and a complete aggregate run remained open alongside final release gates. The `2026-08-20` acceptance records their completion.

### 2026-08-16 Item 23 CI And Astro Cutover Acceptance Delta

1. BlueHotDog explicitly approved this item-23 checkpoint on `2026-08-16`. Approval covers the implemented CI ownership, Astro installed and packed-consumer MCP cutover, exact trailing-slash routing correction, available no-secrets gates, and this documentation record. It does not accept the credentialed installed application gate, private JavaScript Relay deletion, official conformance, or whole-migration release readiness.
2. `.github/workflows/ci.yml` now runs the Astro, Vite, and Astro-browser package tests in one serial framework-adapter job. Serial execution is deliberate because repository ReScript package builds share generated artifacts and have previously raced when run concurrently.
3. `.github/workflows/e2e.yml` now owns `test/astro-compat`, bindings, complete client packages, all active framework packages including Astro-browser, server `priv` inputs, the generated browser-test source, root workspace and ReScript configuration, all changesets, and the actual workflow. The former narrow source-only and nonexistent-adapter assumptions no longer decide whether the E2E workflow runs.
4. E2E concurrency is keyed by pull request or ref rather than one repository-wide `e2e` group. A new pull request run can cancel only its own predecessor, not evidence running for an unrelated pull request.
5. The installed Astro E2E fixture now enables explicit test-only MCP Origin and bearer authorization and calls `tools/call` through a complete `2026-07-28` JSON-RPC request at exact `POST /mcp`. The old `POST /frontman/tools/call/` request and private SSE extraction are removed from that test.
6. The packed Astro compatibility fixture uses the same standard authenticated MCP request shape. Its `get_client_pages` result is read from a complete `CallToolResult`, and its route assertions inspect the structured route payload rather than matching private SSE text.
7. The first installed Astro assertion failed red at HTTP `404`, proving that the ordinary fixture had never enabled its accepted MCP endpoint. Adding fixture-scoped security made the exact call pass without weakening production authentication or embedding a production credential in browser output.
8. The first packed compatibility run passed `trailingSlash: "ignore"` but followed Astro's `always` normalization into an HTML `404`. That exposed a real framework-ordering defect: a correct Vite middleware route guard was insufficient because Astro's raw HTTP request handling could normalize the URL before the middleware owned it.
9. Astro now marks the original exact `/mcp` request by request-object identity in a `WeakSet` and rewrites only the internal URL seen by Astro's normalizer. The Vite adapter accepts the marked request while continuing to reject `/mcp/`, `/MCP`, `/frontman/mcp`, and direct access to the internal sentinel path.
10. Independent review found that the first identity-marker implementation rewrote `/mcp` even when MCP was not configured, which could have routed that public path to a user-defined internal-sentinel route. The final implementation creates the marker and internal rewrite only when `mcpSecurity` exists, and a focused disabled-MCP test proves the path remains untouched and unowned otherwise.
11. The Astro package passes `70` tests, Vite passes `7`, and Astro-browser passes `6`. The packed Astro 6 consumer passes build, package-surface checks, and exact authenticated `/mcp` execution under `ignore`, `always`, and `never` trailing-slash policies.
12. The shared real-process no-secrets adapter and security matrix passes `15` tests across Next.js, Astro, Vite, and genuine WordPress Playground. The source-aware comment gate passes `30` tests plus the repository scan, changed ReScript files pass direct formatter checks, both workflow files parse as YAML, and `git diff --check` passes.
13. The first complete server run had one transient account-fixture unique-email collision and finished `823/824`; the exact failed test then passed alone, and the complete rerun passed all `824` tests. The failure did not touch an MCP path, but both the failure and clean rerun remain recorded rather than silently reporting only the final green count.
14. `make e2e` stopped at its explicit preflight because `test/e2e/.env` is absent. No provider-backed Next.js, Astro, Vite, or Vue-Vite result is inferred from no-secrets transport proof, source-level recovery tests, or the successful direct Astro MCP call.
15. The existing major framework-endpoint changeset now records exact Astro routing across every trailing-slash mode. No separate changeset was added for CI wiring because the user-visible behavior belongs to the same breaking framework endpoint change.
16. Final independent re-review returned `PASS` after the disabled-MCP route exposure was fixed. Approval therefore covers the reviewed final shape, not the earlier implementation that marked every exact `/mcp` request unconditionally.

### 2026-08-16 Item 23 CI And Astro Cutover Lessons

1. A route guard inside framework middleware does not prove route ownership when the framework can normalize or redirect at an earlier raw HTTP layer. Compatibility proof must exercise the actual framework server under every supported routing policy.
2. Fetch follows redirects by default. Parsing the final response as JSON hid the first Astro failure behind an HTML syntax error; asserting HTTP status before parsing exposed the actual `404` and made the routing defect obvious.
3. Exact external route identity and an internal framework-bypass path are different authorities. A private internal pathname alone becomes an undocumented public alias; request-object identity preserves the original exact request without granting direct callers that authority.
4. Internal rewrites must be conditional on endpoint ownership. Rewriting `/mcp` when MCP is disabled changes unrelated application routing and can expose a user route through a Frontman sentinel.
5. Route tests need positive exact-path proof and negative alias proof. `/mcp`, `/mcp/`, `/MCP`, `/frontman/mcp`, and any internal sentinel must be tested separately rather than inferred from one successful request.
6. A compatibility test that still calls a private endpoint can keep obsolete protocol code alive despite a green modern black-box suite. Installed and packed fixtures must speak the same public protocol that users are expected to run.
7. Security configuration belongs in the fixture when the fixture is proving an authenticated endpoint. Omitting security and testing only route absence proves neither the endpoint nor its authorization boundary.
8. CI ownership is part of implementation evidence. Package-local tests that are runnable but absent from every workflow are local evidence, not release gates.
9. Workflow path filters must follow transitive test inputs, including package manifests, bindings, migrations and seeds, generated browser assets, compatibility fixtures, root configuration, shared helpers, and changesets. Source directories alone do not own the behavior.
10. A repository-wide concurrency key destroys unrelated pull-request evidence. Cancellation groups must include the pull request or ref that owns the run.
11. ReScript package gates in this repository must run serially when they share generated output. Parallel test jobs are safe only when each job has an isolated checkout; serial steps remain required within one checkout.
12. Independent review must include disabled-feature behavior. The successful configured-MCP path did not reveal that the first marker design altered routing when MCP was absent.
13. Provider credentials are an execution dependency, not permission to downgrade the assertion. Missing `test/e2e/.env` leaves the credentialed gate open and must not be converted into a skip that counts as acceptance.
14. A flaky full-suite failure needs an exact rerun and another complete run. Passing only the isolated test would not prove suite convergence; reporting only the final full pass would conceal instability.
15. At this historical checkpoint the Astro package lint target rejected directory arguments. It was subsequently repaired to invoke `rescript format --check` without directory arguments and is now owned by root `make mcp-verify`.
16. At this historical Item 23 checkpoint, the root `make mcp-verify` target still forwarded only to `libs/frontman-protocol mcp-verify`; it did not compose the adapter, server, source-scan, conformance, and E2E gates described later in this plan. The earlier checked aggregate-target claim was overstated and is corrected below.

### 2026-08-16 Item 24 Legacy Removal Acceptance Delta

1. BlueHotDog explicitly approved Item 24 on `2026-08-16`. Approval covers the reviewed repository-wide legacy deletion, MCP client naming cutover, generated and shipped artifact cleanup, checked-in fixture correction, active documentation updates, payload-safe logging correction, executed gates, and this acceptance record. It does not accept the credentialed installed-framework E2E, root aggregate target, official conformance runner, or final release review.
2. Item 24 removes the private Relay runtime atomically from active JavaScript and ReScript consumers. `FrontmanProtocol__Relay`, its generated schemas, the private core SSE producer, the old discovery/call request handlers, JavaScript framework routes and wrappers, private tool serialization, tests that required the old behavior, and obsolete public exports are deleted.
3. The modern browser Streamable HTTP implementation is now named `FrontmanClient__MCP__Client`; its standard SSE parser is `FrontmanClient__MCP__SSE`. Application reducer, provider, source-location, browser-test, test, and documentation owners use framework-MCP terminology without retaining Relay aliases or compatibility exports.
4. Next.js middleware and Proxy own only Frontman UI and source-location traffic. The generated Pages API route retains body parsing disabled, while `next.config.mjs`, `next.config.js`, and `next.config.ts` are recognized as owners of the exact `/mcp` rewrite. Checked-in Next.js 15 and 16 fixtures contain the API route and rewrite without placing `/mcp` in middleware or Proxy matchers.
5. Explicit core, Next.js, WordPress, and runtime tests retain the removed route strings only to prove non-ownership. Historical plan and changelog records retain old names as dated evidence. Active integration docs, architecture prose, traceability, READMEs, and the agentic-harness article describe the custom Phoenix MCP transport and MCP Streamable HTTP rather than a private relay.
6. Invalid local-tool arguments no longer place argument keys or Sury decoder diagnostics in normal logs. The browser-test logger records only request category, direction, status, and counts, and its rebuilt bundle contains no removed protocol symbol, route, custom SSE event, or argument-diagnostic field.
7. Verification passes all `116` protocol verifier tests, `129` official examples, and `443` traceability requirements; `151` frontman-client tests; `331` application-client tests; `462` core tests; `193` Next.js tests; `70` Astro tests; `7` Vite tests; the shared `15`-test real-process adapter/security matrix; and the complete `824`-test Phoenix server precommit gate with warnings-as-errors compilation, formatting, and strict Credo. The tracked-source scanner passes `30` tests plus the repository check, direct ReScript formatter checks pass, schema export deletes only the three Relay schemas, the Phoenix browser-test asset rebuilds, `git diff --check` passes, and two independent final rereviews return `PASS`.
8. The first combined package gate exposed that the checked-in Next.js fixtures had moved `/mcp` to `next.config`, but the host-update validator and manual-edit guidance still required middleware or Proxy to rewrite `/mcp`. The accepted fix changed the validator, prompts, templates, cached auto-edit fixtures, and tests to keep MCP out of body-consuming middleware while preserving Frontman UI/source-location ownership.
9. After that correction, a cached Proxy auto-edit test still failed because its ordering assertion used the removed `"/frontman"` route literal as a proxy for handler order. The assertion now checks the actual `frontman(req)` call before existing proxy behavior, which tests the intended invariant instead of an incidental route string.
10. Independent review found three actionable residuals before approval: stale active documentation still described the private relay, local-tool validation logs retained argument keys and decoder diagnostics, and the installer ignored `next.config.ts`. All three were corrected and their owning gates rerun. A separate concern that session creation can precede framework discovery was rejected as an Item 24 defect because the accepted application policy deliberately permits browser-only sessions when framework MCP is unavailable or still connecting.
11. This completion does not infer provider-backed installed-framework E2E from the no-secrets matrix. At the Item 24 checkpoint the credentialed Next.js, Astro, Vite, and Vue-Vite recovery gate, true root aggregate, pinned official conformance runner, final security/release review, documentation release set, and later release gates remained open. Later checkpoints completed conformance, credentialed execution, and the aggregate as recorded above.

### 2026-08-16 Item 24 Legacy Removal Final Approval And Lessons

1. A modern implementation behind a legacy module name is still legacy API surface. Replacing wire behavior inside `FrontmanClient__Relay` was not complete removal; the module, types, reducer variants, provider fields, base-URL helper, tests, browser-test exports, and documentation all had to move to MCP-owned names without aliases.
2. Route deletion is broader than deleting two handler branches. Classification, `OPTIONS` behavior, wildcard CORS ownership, request-body consumption, framework wrappers, public exports, tool serializers, custom SSE helpers, tests, fixtures, and generated bundles can independently keep an obsolete protocol reachable or shippable.
3. Negative legacy-route tests are not legacy implementations. Explicit assertions that `GET /frontman/tools`, `POST /frontman/tools/call`, and their preflights are unowned remain valuable regression evidence and must be distinguished from positive compatibility behavior during repository searches.
4. Historical documentation and active documentation require different treatment. Dated migration baselines and changelogs should preserve what existed; current READMEs, integration guides, architecture pages, traceability status, browser-test copy, and explanatory articles must describe only the shipped architecture.
5. Generated and ignored artifacts can still ship. Cleaning and rebuilding ReScript output, framework `dist` bundles, packed adapter paths, exported schemas, and the Phoenix browser-test bundle is part of deletion evidence even when Git does not track every generated file.
6. Schema deletion must happen at the source list and generated-output levels. Removing checked-in Relay schemas without deleting their exporter entries would recreate them; deleting only exporter entries without rerunning export would leave stale shipped artifacts.
7. Checked-in fixtures are executable architecture claims. Moving `/mcp` out of Next.js middleware exposed that installer validation, LLM prompts, manual instructions, and cached auto-edit responses still taught the rejected routing design despite green endpoint tests.
8. The body-preserving Next.js owner is `next.config` plus the generated Pages API route. Middleware and Proxy remain responsible only for UI and source-location paths. Installer detection must recognize every supported config extension, including `next.config.ts`, or it can create competing config files and strand the MCP rewrite.
9. Tests should assert semantic ownership rather than obsolete text markers. The Proxy ordering test became correct only when it checked `frontman(req)` before existing behavior instead of looking for a route literal that no longer belongs in Proxy.
10. Payload-safe logging excludes more than argument values. User-controlled argument keys and parser diagnostics can disclose payload structure or content; categorical tool, task, and durable-call identifiers are sufficient operational context for validation failures.
11. Browser-only readiness was intentional, not an Item 24 cleanup defect. At that checkpoint ACP session creation remained independent of optional framework discovery so browser tools worked when `/mcp` was unavailable; the later accepted application cutover preserves transport independence while gating session creation on terminal discovery.
12. Shared generated ReScript outputs make serial package verification the safe local strategy. A passing isolated package run is insufficient when another package build can clean or regenerate common artifacts underneath it.
13. Package lint targets that pass directories to the current ReScript formatter are not evidence. Direct explicit-file formatter checks were used for the affected packages, while repairing the broken Astro/Next/Vite lint targets remains a separately recorded tooling task.
14. Green unit suites do not prove shipped deletion. Repository searches, rebuilt-bundle searches, schema regeneration, browser-asset compilation, real-process adapter tests, source scanning, and full Phoenix precommit all supplied distinct evidence.
15. Independent review should run after documentation and generated artifacts are updated, not only after runtime deletion. The first reviews found stale active prose and logging/configuration gaps that package tests did not expose; approval followed only after fixes and two clean rereviews.
16. Approval is scoped. Item 24 closes private Relay removal, but it does not manufacture provider credentials, expand the root verification target, supply the official conformance runner, or satisfy the final security and release review.

### 2026-08-16 Official MCP Conformance Acceptance Delta

1. BlueHotDog explicitly approved the applicable official MCP conformance checkpoint on `2026-08-16`. Approval covers the pinned runner, advertised-capability scenario selection, real server and client integration, fail-closed result policy, execution isolation, CI ownership, documentation, focused verification, and independent final security rereview described below. It does not accept provider-backed installed application E2E, a complete root aggregate run, whole-Phase 2 acceptance, or the final migration release review.
2. The executable is the unchanged official `@modelcontextprotocol/conformance` package `0.2.0-alpha.11`, aligned to source commit `c321dd32035556e6769d3724a8ee97d87c3faaac`. The npm package SHA-256 is `67d28b0d50d64458232945d9b3af75178add5d05819c748ec2c8b26e5cb038c5`; the package and source archive are vendored under `libs/frontman-protocol/test/mcp-upstream/conformance/` and pinned by `SHA256SUMS` for offline execution.
3. `McpConformanceRunner.mjs` verifies the package checksum before inspection, requires the exact six expected archive paths, rejects every non-regular entry including links and special files, extracts only after those checks into a disposable directory, verifies package name and version, and removes results and extracted code after each scenario. No conformance temporary directory remained after final verification.
4. The server matrix runs seven applicable tool scenarios through the real Frontman Vite Node/Web endpoint and its conformance-only real tool registry: listing plus simple text, image, audio, embedded resource, mixed content, and tool-error calls. These server scenarios use the unchanged official runner and fixtures.
5. The client matrix runs six applicable runner scenarios through `FrontmanClient__MCP__Client`: tool calling, request metadata, standard headers, custom headers, invalid-tool headers, and non-dereferenced local JSON Schema references. The runner remains unchanged, but these are pinned-runner checks rather than pristine unmodified-fixture client conformance.
6. Two upstream fixture defects are corrected only at the isolated client harness boundary. Several mock discovery responses place `serverInfo` in the pre-final result body instead of `result._meta`; the harness relocates that fixture field before strict production parsing. One custom-header fixture supplies JSON `null` against its own optional-boolean schema; the harness omits the invalid optional argument so the intended header-omission behavior is exercised without weakening production schema validation.
7. Those corrections are explicit conformance evidence limits, not hidden expected failures and not production compatibility behavior. `docs/mcp/conformance.md`, `docs/mcp/threat-model.md`, the top-level status table, release criteria, implementation order, and definition of done distinguish zero accepted product failures from the two disclosed malformed-runner fixture corrections.
8. The gate has no expected-failure baseline. Any runner exit failure, failed check, warning, duplicate or missing `checks.json`, or unexpected skip fails. The only permitted skips are exact named checks for conditional capabilities and methods Frontman does not advertise; resources, prompts, completions, progress, MRTR fulfillment, OAuth, optional tasks, and the runner's mixed diagnostic `server-stateless` fixture are outside the advertised release scope rather than silently skipped applicable behavior.
9. At this historical conformance checkpoint, root `make mcp-conformance` delegated to the protocol package target, built the current ReScript sources, verified the `2026-07-28` oracle and all `129` official examples, and executed the focused conformance test. Root `make mcp-verify` included this gate in its serial aggregate after the credential preflight, but complete execution remained blocked while `test/e2e/.env` was absent. The later `2026-08-20` acceptance records the uninterrupted passing aggregate.
10. `.github/workflows/e2e.yml` owns `test/mcp-conformance/**` in addition to the protocol, client, framework, documentation, plan, root Makefile, workspace, and workflow inputs. A change to the harness or its security guard can no longer evade the no-secrets conformance CI step through a missing path filter.
11. The runner process receives no application/provider credentials and no `PATH`. Node filesystem permissions allow reads only from the extracted runner, required package dependencies, exact Frontman client/protocol/binding/log modules, the preload guard, and the client harness. Writes are limited to the disposable scenario directory. Focused probes prove repository writes and `.git/config` reads fail.
12. The runner receives no Node child-process permission. Its one exact shell-shaped client command is validated by executable, harness, shell flag, and loopback server URL, then emulated by a permission-inheriting Worker that presents the runner's required ChildProcess event/stdout/stderr interface. Every real `spawn`, `spawnSync`, `exec`, `execFile`, and `fork` path is denied; a focused probe proves an attempted `curl` subprocess cannot run.
13. Arbitrary Worker creation is denied. The fixed client harness Worker receives a reconstructed allowlisted environment rather than caller-spread options. The production schema validator may create only its exact known eval wrapper and exact `RemoteSchemaWorker` URL, with caller-controlled `execArgv`, preload, environment, path, and option injection removed. Active schema Workers are capped and both harness and schema Workers have V8 generation limits.
14. Network controls cover more than `fetch`. TCP permits only `localhost`, `127.0.0.1`, and `::1`; `localhost` is canonicalized to `127.0.0.1` and caller-supplied `lookup`, `hostname`, `path`, and other socket options are discarded before connection. String and object Unix-domain sockets, UDP factory and constructor paths, callback and promise DNS resolvers, custom Resolver constructors, and non-loopback fetches are denied.
15. Security tests explicitly exercise non-loopback fetch, string Unix sockets, UDP creation, DNS resolution, Resolver constructors, attacker-controlled localhost lookup, arbitrary subprocesses, arbitrary Workers, repository writes, and repository metadata reads. Review found that testing only ordinary `fetch` would not have covered the real escape surface.
16. Execution is bounded by a `60,000 ms` runner timeout, a `512 MiB` runner V8 old-space limit, per-Worker V8 generation limits, a schema-Worker count cap, and a `1 MiB` captured stdout/stderr limit. These are useful denial-of-service bounds but not a portable hard total-RSS limit: Node does not cap external `Buffer`/`ArrayBuffer` or native allocations. The threat model now requires an outer isolated CI-worker memory limit when defending against a malicious checksum-pinned artifact is necessary.
17. The first independent review correctly rejected broad `--allow-child-process`, repository-wide read permission, missing conformance-harness CI ownership, archive validation that checked names but not entry types, and language that overstated fixture purity. The implementation removed broad child permission and root reads, added exact archive-type and CI ownership checks, and corrected the claims instead of treating a JavaScript monkey patch as an operating-system sandbox.
18. Subsequent adversarial rereviews found and drove fixes for string-form Unix sockets, UDP and DNS APIs, unrestricted Workers, caller-spread Worker options, DNS/UDP constructors, custom localhost lookup, and a getter/Proxy time-of-check/time-of-use path caused by spreading validated socket options. The final socket boundary reconstructs only validated scalar `{host, port}` values.
19. Verification deliberately retained failed intermediate runs as engineering evidence: the first narrowed filesystem run exposed a missing preload read allowance; the first Worker replacement exposed generated-client Worker needs; fixed environment reconstruction initially serialized absent context as the literal string `"undefined"`; and the first socket-option sanitization mishandled Node's normalized nested argument-array call shape. Each failure was corrected at the owning boundary rather than weakening the probe or production client.
20. Final `make mcp-conformance` passes `10` focused harness tests, all seven server scenarios, all six client runner scenarios, and all `129` official examples. The previously executed complete `frontman-client` suite passes `152` tests, including the bounded same-version discovery retry regression. `node --test test/mcp-verify/mcp-verify.test.mjs` passes all three aggregate orchestration contracts, and `git diff --check` passes.
21. The same independent reviewer was resumed after every security correction rather than replaced with a more agreeable reviewer. The final review returned `PASS` with the hard total-RSS limitation retained as a documented residual risk rather than mislabeled as solved.

### 2026-08-16 Official MCP Conformance Final Approval And Lessons

1. A checksum proves artifact identity, not safety. Exact provenance and offline execution prevent silent upstream drift, while filesystem, process, Worker, network, output, and time controls constrain what the known executable can do.
2. Archive path allowlisting is insufficient without entry-type validation. A symlink or hard link under an expected name can redirect extraction outside the intended trust boundary; only exact regular files are accepted.
3. Node's `--allow-child-process` is all-or-nothing. A JavaScript `spawn` wrapper cannot turn that broad native permission into a security boundary, so the accepted design grants no child-process permission and emulates the fixed runner command with a bounded Worker.
4. A preload guard must cover alternate APIs, constructors, and overloads. Blocking `fetch` did not block UDP, DNS, Resolver instances, or Unix sockets; checking only object-form `path` did not block string-form sockets.
5. `localhost` is a name, not proof of loopback. Passing a caller-controlled `lookup` callback can resolve an allowed label externally, so the boundary canonicalizes it to a numeric loopback address and discards lookup hooks.
6. Validation followed by object spread is vulnerable to getters and Proxies. Reconstructing a minimal options object from already validated scalar authority avoids time-of-check/time-of-use changes and prevents unrelated socket options from regaining authority.
7. Fixed code is not enough if its options remain attacker-controlled. Exact Worker source and URL checks still require constructing exact `env`, `workerData`, `resourceLimits`, and execution options rather than spreading values that can introduce a preload or alternate execution context.
8. Least-privilege filesystem tests must prove sensitive reads fail, not merely that repository writes fail. Read-only access to the entire checkout still exposes `.git` metadata and any accidentally present credentials.
9. Security claims should name the mechanism and limit. “Bounded resources” was too broad; the accepted statement names timeout, V8 heap, Worker count, and output bounds while recording the absence of a hard RSS cap.
10. Upstream runner defects must not be laundered into product behavior. Correcting malformed fixture input in an isolated harness is acceptable evidence only when the correction is exact, production validation remains strict, and the result is not called pristine unmodified-fixture conformance.
11. Capability applicability is an advertised-runtime decision, not a convenient skip. Every permitted skip is exact and named; unsupported resources, prompts, MRTR fulfillment, OAuth, and optional task machinery stay unadvertised and are not treated as partial implementations.
12. The official runner remains one proof source. It does not replace schema differential tests, exact transport/error tests, security probes, cancellation and deadline races, durable ownership/recovery proof, application E2E, or normative traceability.
13. Independent review earned its keep by attacking claims and alternate call paths rather than rerunning happy paths. Reusing the same reviewer across corrections prevented findings from disappearing through reviewer churn.
14. A green focused gate does not authorize a broader release claim. At this checkpoint, provider-backed installed framework E2E, the complete credentialed aggregate, subsequent semantic-review remediation, remaining release documentation, and whole-migration release approval remained open. The later acceptance delta closes semantic-review remediation only.

### 2026-08-09 Session Delta

This session completed the Phase 1 consumer cutover and evidence slice without starting Streamable HTTP:

1. At this Phase 1 checkpoint, the browser custom Phoenix dispatcher and temporary Phoenix TaskChannel exchange modern request metadata, `server/discover`, `tools/list`, `tools/call`, modern named errors, and explicit `ai.frontman/execution-context` values. Cancellation was only structurally validated here; accepted Phase 4 subsequently adds correlation and work abortion.
2. Initialization-era MCP schemas and duplicate modern contract artifacts were deleted after consumers moved to the in-place owners. Complete `resultType`, structured content, and open top-level values survive Phoenix persistence and replay, while result `_meta` is scrubbed before storage so provider credentials cannot return through `get_tool_result`.
3. `libs/frontman-protocol/test/fixtures/mcp-phase1-parity.json` supplies one deterministic value set for discovery request/result, list request/result, context-bearing call, complete result, named error, cancellation, and string/numeric IDs. The final serial evidence is `115` protocol verifier tests, all `129` official examples, all `443` traceability requirements, `94` frontman-client tests, `321` frontman-core tests, `319` client tests, and `730` server tests.
4. A major changeset covers only `@frontman-ai/frontman-protocol` and `@frontman-ai/frontman-client` for the latest-only shared/custom-Phoenix contract break.

At the end of the `2026-08-09` slice, deterministic broad differential/property coverage and the final acceptance review remained. The `2026-08-10` acceptance delta below closes those Phase 1 blockers; cancellation abort remained later work at that checkpoint and is completed by accepted Phase 4. `FrontmanProtocol__MCP.protocolVersion` matches the modern contracts and Elixir producer at `2026-07-28`.

### 2026-08-10 Phase 1 Acceptance Delta

1. `VerifyMcpProperty.test.mjs` deterministically generates locally accepted IDs, progress tokens, cancellation IDs, icon themes, audiences, resource sizes, object-rooted tool input schemas, tool arguments, structured content, and metadata key/byte boundaries. Every accepted value round-trips through the Sury runtime schema and validates through the generated schema and named upstream definition.
2. The property suite also deletes generated required fields across request metadata, cancellation parameters, Tool, tools/call parameters, and complete tool results. Existing focused tests retain complete wrong-type, required-field, open-field, and authoritative-artifact discrepancy matrices.
3. Pull-request verification runs `1,000` cases with seed `20260728`. `.github/workflows/mcp-property.yml` verifies the checksum-pinned oracle and runs `10,000` cases weekly or on manual dispatch. Upstream validators are compiled once per named definition so the larger deterministic replay remains bounded and completes locally in under two seconds.
4. The recursive `JSONValue` discrepancy is resolved by explicit source precedence: where the checksum-pinned generated JSON Schema contradicts the authoritative TypeScript schema and rendered specification by rejecting recursive null or fractional values, Frontman follows the authoritative type and keeps an exact test proving the known generated-artifact rejection.
5. Final cleanup searches found no `MCP20260728`, initialization-era MCP schema, old MCP version, required wire `callId`, silent MCP `Suspended`, unnamespaced MCP policy field, or object-only structured-content assumption in active consumers or generated modern schemas. ACP initialization is intentionally unrelated; private Relay policy fields remain only in Relay artifacts scheduled for removal in Phases 2-3.
6. Final protocol evidence is `116` verifier tests, all `129` official examples, all `443` traceability requirements, a local execution of the configured `10,000`-case scheduled profile, stable repeated generation of all `85` schemas, the `30`-test source-comment gate, and `git diff --check`.

### 2026-08-10 Phase 2 Foundation, Metadata, And Method-Boundary Delta

This session began Phase 2 as review-gated, route-independent `frontman-core` foundations. The code is not an accepted Streamable HTTP server and deliberately remains unreachable until the complete dispatcher can preserve the frozen validation order.

1. Slice 2A added `FrontmanCore__MCP__HeaderValue`. It accepts safe raw ASCII header values, decodes only the exact lowercase `=?base64?...?=` sentinel, requires canonical Base64, validates decoded UTF-8 with the typed `node:buffer` `isUtf8` export, and rejects raw Unicode, controls, edge whitespace, malformed Base64, noncanonical padding bits, and invalid UTF-8. It uses no `%raw`, fallback, or catch-all exception conversion.
2. Slice 2B added `FrontmanCore__MCP__RequestHeaders`. It requires `MCP-Protocol-Version` and `Mcp-Method`, requires `Mcp-Name` for `tools/call`, `resources/read`, and `prompts/get`, compares header names case-insensitively through the Web Headers API, compares protocol-version and method values directly and case-sensitively, decodes `Mcp-Name` before its case-sensitive comparison, rejects unexpected names, and distinguishes `HeaderMismatch` from a correctly mirrored unsupported version.
3. Standard-header validation now proves the frozen multi-fault order: check the presence of every required header first, compare every mirrored header with its body authority second, and classify a matching unsupported version third. Missing `Mcp-Method` or required `Mcp-Name` therefore wins over a simultaneous version mismatch; a header mismatch wins over unsupported-version classification.
4. Slice 2C added `FrontmanCore__MCP__ErrorResponse`. Header mismatch emits HTTP `400` with JSON-RPC `-32020`; unsupported version emits HTTP `400` with `-32022` and Sury-serialized `requested` and `supported` data. Numeric and string request IDs are preserved, emitted bodies validate against the shared named and exclusive generic error schemas, and messages do not echo hostile header values.
5. Slice 2D added `FrontmanCore__MCP__MediaTypes`. Frontman's request policy accepts `application/json` with optional case-insensitive `charset=utf-8`; response negotiation requires explicit exact offers of both `application/json` and `text/event-stream`, each bare or carrying one valid positive `q` weight. Wildcards, media-parameter mismatches, unavailable or malformed quality values, duplicate weights, malformed content-type parameters, and incomplete offers fail closed. A quote-aware scanner prevents commas inside quoted parameters from synthesizing fake required media ranges.
6. The authoritative Streamable HTTP text clarified a sentinel nuance: markers are case-sensitive, so only a value with both the exact lowercase prefix and suffix is decoded. Uppercase `BASE64` or an incomplete lowercase prefix is ordinary raw ASCII when otherwise header-safe; it is not malformed sentinel encoding. Slice 2H corrected the earlier uppercase-marker negative shorthand in `docs/mcp/traceability/http-security.md`.
7. Slice 2E added `FrontmanCore__MCP__BodyDecoder`. It accepts complete raw bytes, enforces the frozen `2,097,152`-byte limit before decoding, rejects malformed or truncated UTF-8, rejects object or array nesting above `64`, and parses exactly one arbitrary-root JSON value without applying a typed MCP schema. Slices 2F-2H subsequently supplied streaming reads, `Content-Length`, idle deadlines, and Web Request composition; Parts 2I-A through 2K-G subsequently supplied the complete route-independent path through exact pre-decode responses, ordered decoded-request handling, typed methods, cursor rejection, exact selection, selected-schema custom headers, selected-input error-result mapping, validated selected-call execution, and discovery/list success dispatch. Active routing and adapter-owned policy remain later work.
8. Slice 2F added `FrontmanCore__MCP__BodyReader` plus typed reader cancellation and lock-release bindings. It rejects malformed or oversized `Content-Length` before acquiring a reader, independently counts streamed bytes, cancels over-limit streams, limits one body to `4,096` chunks, avoids integer-overflow bypass by comparing each chunk against remaining capacity, and releases the reader after completion or rejection. Slices 2G-2H subsequently supplied idle deadlines and Web Request extraction; Part 2K-G now maps controlled reader/body failures to exact route-independent 400/`-32700`, 408, and 413 responses. Adapter abort propagation remains later work.
9. Slice 2G added the frozen `60,000`-millisecond body idle deadline to `FrontmanCore__MCP__BodyReader`. Monotonic time is checked before and after each pending read, non-empty bytes at exactly the deadline reset it, inactivity at `60,001` milliseconds expires it, zero-byte chunks do not reset it, timeout initiates cancellation without awaiting an untrusted underlying cancellation promise, pending reads are drained for lock release, and every timer is cleared on completion or rejection. Absolute request deadlines remained later work at that checkpoint; Part 2K-K subsequently added route-independent adapter transport cancellation and Part 2K-M added cancellation-aware execution plus the absolute active-framework deadline.
10. Slice 2H added `FrontmanCore__MCP__RequestBody`. A typed `Request.body` binding preserves `Uint8Array` chunks, consumed and missing bodies are classified before reader acquisition, and the approved reader and decoder are composed without collapsing their error categories or applying a typed MCP method schema. Parts 2I-A through 2K-G subsequently supplied exact pre-decode response mapping, coarse envelope classification, invalid-envelope ID recovery, raw mirrored authorities, complete metadata/capability validation, typed methods, cursor rejection, exact registry selection, selected-schema custom-header validation, selected-input validation, execution, and response composition for all three supported methods. Production routing remains later work.
11. Part 2I-A added `FrontmanCore__MCP__RequestEnvelope`. It uses a coarse Sury object schema plus the shared cross-message-field prohibition to accept exact JSON-RPC `2.0` requests with safe string/integer IDs and string methods, preserve all open fields, reject notifications/responses/mixed directions, and deliberately retain arbitrary JSON `params` for step-12 method validation. Parts 2I-B and 2I-C subsequently added independent ID recovery and raw mirrored-authority extraction without weakening this classifier.
12. Part 2I-B added narrow, independent request-ID recovery for invalid envelopes. It parses only the shared safe string or integer ID through Sury, preserves both inclusive wide numeric bounds through `JsonRpc.Id.toJson`, retains readable IDs despite unrelated envelope faults including response discriminants, and returns no ID for missing, null, fractional, unsafe, boolean, object, or array values. Part 2J-A uses this result for exact HTTP 400/`-32600` emission.
13. Part 2I-C added `FrontmanCore__MCP__RequestAuthorities`. Narrow Sury schemas preserve raw protocol-version, client-capability, and method-selected `name`/`uri` values without accepting malformed method parameters. The standard-header validator now consumes those raw authorities, keeps required-header presence first, and classifies missing or type-confused body mirrors as header mismatches before unsupported-version or complete metadata validation.
14. Part 2J-A added `FrontmanCore__MCP__DecodedRequest`. After successful JSON decoding it composes envelope classification before standard headers, recovers only readable IDs for HTTP 400/`-32600`, then composes raw authorities, presence-first standard-header validation, body comparison, and supported-version classification into exact HTTP 400/`-32020` and `-32022` responses. Its accepted value remains pre-dispatch and does not claim complete metadata or capability validation.
15. Part 2J-B completes generic request-metadata validation only after accepted standard headers and supported-version classification. Missing or malformed required metadata emits HTTP 400/`-32602`; an explicitly supplied aggregate client-capability requirement is checked afterward and emits schema-valid HTTP 400/`-32021` with exact `requiredCapabilities` when absent or incompatible. Core-only framework processing supplies no optional requirement, and the Phoenix-only execution-context extension is not imposed on HTTP clients.
16. Part 2J-C adds `FrontmanCore__MCP__MethodRequest` after complete metadata/capability validation. It parses `server/discover`, `tools/list`, and `tools/call` through their shared Sury request schemas, emits HTTP 200/`-32602` for malformed supported-method parameters, and emits HTTP 404/`-32601` for unsupported methods without echoing hostile values. Its accepted variants remain pre-registry and pre-execution.
17. Part 2K-A adds exact, case-sensitive registry selection only after a typed `tools/call`. Registered calls retain the selected tool module without reading its input schema or executing it; unknown tools emit the official HTTP 200/`-32602` protocol error with the readable request ID, while discovery and listing remain typed pass-through variants. `FrontmanCore__MCP__DecodedRequest` now expresses the frozen validation order as a linear pipeline of shallow `Result` stages rather than nested control flow.
18. Part 2K-B adds `FrontmanCore__MCP__CustomHeaders` after exact selection. It recursively discovers annotations only along `properties` paths, validates token names, case-insensitive uniqueness, primitive types, exact paths, sentinel decoding, missing/null omission, boolean spelling, and exact safe integral JSON-number equivalence. Recognized mismatches emit schema-valid HTTP 400/`-32020`; malformed Frontman-owned annotations crash; discovery/list, unknown tools, unrelated arguments, and execution remain untouched. Physical duplicate-header rejection is explicitly deferred because Web `Headers` has already combined duplicates; the raw adapter must prove singleton multiplicity before route activation.
19. Part 2J-B focused tests prove complete metadata acceptance, missing capabilities, malformed known capability and logging fields, exact HTTP 400/`-32602`, absent and incompatible explicit capability requirements, exact HTTP 400/`-32021` data, declared-capability acceptance, string and wide numeric ID preservation, and standard-header/version precedence over malformed metadata. Direct error tests validate the nested `InvalidParamsError`, complete `MissingRequiredClientCapabilityError`, and exclusive generic JSON-RPC error schemas at their actual structural levels.
20. Part 2J-C focused tests prove all three supported request variants, optional list cursor and call arguments, malformed cursor and arguments rejection, unsupported-method classification independent of untyped params, exact HTTP 200/`-32602`, exact HTTP 404/`-32601`, string and numeric ID preservation, metadata rejection before method classification, and explicit required-capability rejection before method classification.
21. Part 2K-A focused tests prove exact and case-sensitive registered-tool selection, discovery/list pass-through with an empty registry, acceptance before selected-tool argument validation, no execution, official unknown-tool wording and schema validity, HTTP 200/`-32602`, string and wide numeric ID preservation, and prior validation precedence.
22. Part 2K-B focused tests prove valid and forbidden annotation locations, all primitive types, exact safe-integer and precision boundaries, encoded values, mixed-case header names, absent/null/unreachable paths, recognized mismatches, unrecognized-header tolerance, ordering after selection, no general argument validation or execution, owned-schema crashes, HTTP 400/`-32020`, and string/wide numeric ID preservation.
23. Review caught and corrected a swallowed catch-all exception, an incorrect `Buffer.isUtf8` binding, permissive Node Base64 behavior, premature unsupported-version precedence, required-header presence/comparison interleaving, manual JSON serialization in the error path, manual JSON traversal in tests, quoted-comma Accept injection, an overcomplicated geometric body accumulator, integer-overflow-prone byte addition, unbounded chunk iteration, late bytes winning an idle-timeout race, awaited untrusted cancellation, an uncancelled already-expired path, misuse of JavaScript-exception handling for typed Sury failures, an incomplete negative safe-ID boundary matrix, precision-rounded fractional custom integers, and an arbitrary custom-integer exponent cutoff. These are recorded as regression criteria rather than left as review folklore.
24. Parts 2J-B through 2K-J each received an independent focused PASS review with no remaining findings. Their checkpoint residual risk was reachability, real application authentication, Vite/Astro pre-body streaming, adapter cancellation, active-endpoint side effects, and framework interoperability; Part 2K-K subsequently closes the route-independent streaming and transport-cancellation gaps.
25. At the Part 2K-J checkpoint, evidence was the complete `frontman-core` suite at `35` test files and `446` tests, the Next.js suite at `12` files and `189` tests, the Astro suite at `11` files and `63` tests, the Vite suite at `2` files and `4` tests, ReScript formatting, the `116`-test protocol verifier, all `129` official examples, all `443` traceability requirements, generated-schema diff verification, and the `30`-test repository source-comment gate plus repository scan. Parts 2K-B through 2K-J were explicitly approved after independent PASS reviews; the current accepted Part 2K-K evidence is recorded below.
26. At the Part 2K-J checkpoint, no Phase 2 checklist item requiring an active HTTP route was complete. Part 2K-L subsequently activates the JavaScript framework routes and adds their major changeset; private Relay endpoints and custom SSE remain active, so Phase 2 remains unreleasable and unaccepted.

### 2026-08-11 Phase 2 Selection, Custom-Header, Selected-Input, Execution, Discovery, And Listing Delta

This session continued the review-gated Phase 2 foundation through exact registry selection, selected-schema custom-header validation, complete selected-input validation, validated selected-call execution, and discovery/list success dispatch without registering `/mcp`:

1. The user approved continuation from Part 2J-C into Part 2K-A. `FrontmanCore__MCP__MethodRequest` now has an explicit selected-request domain: discovery and listing pass through without registry dependence, while a typed `tools/call` retains the exact case-sensitive registry tool module. Unknown tools return the official protocol-level HTTP 200/`-32602` response with the readable string or safe numeric request ID.
2. The first 2K-A integration made `FrontmanCore__MCP__DecodedRequest.validate` too deeply nested. At user direction it was flattened into shallow typed `Result` stages for standard headers, metadata, capabilities, method parsing, selection, and custom-header validation. The top-level pipeline now exposes precedence directly instead of encoding it in indentation.
3. Part 2K-A deliberately does not reuse `FrontmanCore__Server.executeTool`, because that helper immediately crosses into selected-tool argument validation and execution. The selected existential tool module is retained without unpacking its input schema until the later custom-header stage and without calling `execute`.
4. Part 2K-B added `FrontmanCore__MCP__CustomHeaders`. It converts the selected Sury input schema to JSON Schema, recursively inspects the complete JSON tree, accepts annotations only on primitive properties statically reachable through `properties`, and rejects annotations hidden at the root, beneath arrays, composition, conditionals, references, definitions, or unknown keywords.
5. Custom annotation names are nonempty RFC 9110 field-name tokens and unique case-insensitively. Selected Frontman-owned schemas with malformed annotations crash loudly as server defects. They are not mislabeled as hostile incoming `HeaderMismatch` requests, while future untrusted remote definitions remain assigned to Phase 3 individual-tool exclusion.
6. Recognized `Mcp-Param-*` headers use case-insensitive field-name lookup and the existing strict value decoder. String values compare exactly after sentinel decoding; booleans require lowercase `true` or `false`; integers accept exact integral JSON-number syntax and compare numerically only inside the inclusive IEEE-754 safe range. Missing, null, or unreachable argument paths require header omission, while present values require one matching recognized value.
7. The user explicitly chose to defer physical duplicate custom-header rejection because Web `Headers` irreversibly combines duplicate fields and cannot distinguish them from one legitimate comma-containing string. The active adapter must retain raw physical multiplicity and require a singleton recognized field before `/mcp` can be registered. Comma splitting is prohibited because commas are valid string data.
8. Independent review found that direct JavaScript numeric conversion could accept a lexically fractional header after precision rounding, such as `42.0000000000000001`. Exact mathematical integrality is now proven from the JSON-number text before conversion. A second review rejected an arbitrary exponent cutoff; the final bound is derived from mantissa length and accepts long exact forms such as `100...0e-101` when they denote a safe integer.
9. At the Part 2K-B checkpoint, focused integration proved custom validation occurred after exact selection and before complete argument validation or execution. Unknown tools retained HTTP 200/`-32602` even when custom fields were present; matching headers let a call missing unrelated required tool arguments reach the post-custom-header stage; mismatches returned schema-valid HTTP 400/`-32020`; malformed owned annotations crashed; discovery/list remained pass-through; and a test tool whose `execute` always failed provided initial no-execution evidence.
10. `docs/mcp/implementation-limits.md` now records Web Header duplicate folding, the raw-adapter singleton requirement, exact integral JSON-number handling, and owned-schema crash policy. At this historical checkpoint both custom-header traceability matrices retained partial status for active routing, raw duplicate proof, and the Phase 3 client; approved Parts 2K-H through 2K-L and the approved Phase 3 core slice subsequently close those implementation gaps while retaining their explicit acceptance blockers.
11. The Part 2K-B checkpoint evidence was `32` passing `frontman-core` test files with `411` tests, ReScript format checks, `116` protocol verifier tests, all `129` official examples, all `443` normative traceability requirements, the `30`-test source-comment gate plus repository scan, repeated `git diff --check`, and independent code/documentation PASS reviews after every concrete finding was corrected.
12. Part 2K-B was explicitly approved on `2026-08-11`.
13. Part 2K-C validates complete selected-tool arguments through the selected tool's existing Sury input schema only after successful custom-header validation. Omitted arguments are validated as the empty object, matching the existing execution helper.
14. Selected-input rejection produces HTTP 200 with a successful JSON-RPC response carrying the original string or wide safe numeric ID and a schema-valid complete `CallToolResult` with `isError: true`. It does not emit JSON-RPC `-32602` and does not expose Sury diagnostics or argument values in the response.
15. Valid input remains paired with the exact selected existential tool and original typed call parameters for later execution. Part 2K-C does not call `execute`, register `/mcp`, build discovery/list success results, or integrate media/body policy.
16. Focused integration proves custom-header mismatches still win before complete argument rejection, invalid selected input cannot execute, valid selected input remains accepted without execution, complete error results preserve string and wide numeric IDs, and stale acceptance fixtures now supply genuinely schema-valid input.
17. The boundary now distinguishes three terminal domains: `Accepted` retains a validated request for later dispatch, `Completed` carries a successful JSON-RPC response such as a SEP-1302 input-error result, and `Rejected` carries protocol or transport-boundary error responses. A tool input failure is therefore not mislabeled as a JSON-RPC rejection.
18. Omitted `arguments` are normalized to an empty object through Sury before selected-schema parsing. An all-optional schema accepts omission, while a required-input schema produces the same complete SEP-1302 error result as any other selected-schema failure.
19. Tests validate the complete emitted result through `MCP.CallToolResult.schema`, then use a narrow Sury projection for `resultType` and `isError`. Manual `JSON.Decode.object`, `Dict.get`, and `JSON.Encode.object` boundary logic introduced during the first test/implementation pass was removed after review.
20. No-execution proof uses an explicit invocation counter shared by test tools rather than relying only on an `execute` function that would fail if called. Valid selected input, invalid selected input, and omitted-input paths all assert that execution remains untouched.
21. The client-facing selected-input message is the fixed category `Invalid tool arguments`. Sury diagnostics and argument values are intentionally not echoed because they may contain sensitive input and are not required by SEP-1302.
22. The first TDD build failed because `Completed` did not yet exist, proving the new terminal domain was test-driven. The first full suite then exposed a stale required-capability acceptance fixture that omitted `read_file.path`; the fixture was corrected to valid input rather than weakening the new validator.
23. Independent review found and corrected manual JSON traversal in result assertions, weak no-execution evidence, missing omitted-argument coverage, stale result/error traceability rows, manual empty-object construction, stale implementation-table boundaries, and current-scope text that still ended at Part 2K-B. A final independent review returned PASS.
24. An attempted synthetic unknown-exception test used a throwing Sury transform parser, but Sury correctly wrapped that parser failure as `S.Exn`, so it exercised the ordinary selected-input error path rather than the unknown-exception rethrow branch. The misleading test was removed; production still catches only `S.Exn` and rethrows every other exception.
25. The Part 2K-C checkpoint evidence was `32` passing `frontman-core` test files with `415` tests, ReScript formatting, `116` protocol verifier tests, all `129` official examples, all `443` normative traceability requirements, the `30`-test source-comment gate plus repository scan, `git diff --check`, and an independent final PASS review. Part 2K-C was explicitly approved on `2026-08-11`.
26. Part 2K-D extracts the selected-tool invocation body into `FrontmanCore__Server.executeSelectedTool`. The existing private Relay executor delegates to the same helper, while the MCP boundary invokes the exact selected existential tool only after complete custom-header and input validation.
27. Successful tool results and tool-returned API or business error results are preserved, validated through `MCP.CallToolResult.schema`, and wrapped in HTTP 200 JSON-RPC success responses with the original string or wide safe numeric request ID.
28. Unexpected execution exceptions become the fixed complete error result `Tool execution failed`; raw exception messages are not exposed. A post-validation input discrepancy becomes the fixed `Invalid tool arguments` result, and an impossible lost-selected-tool state crashes loudly.
29. Focused tests prove one successful invocation, exact returned text preservation, one invocation for each returned business error, returned API error, and thrown execution failure, schema-valid complete results, absent `isError` on success, `isError: true` on every failure, fixed exception redaction, and string/numeric ID preservation.
30. Discovery and listing remain accepted but undispatched. Part 2K-D does not register `/mcp`, integrate media/body policy, build discovery/list success results, validate raw physical header multiplicity, or add cancellation.
31. The first full test run exposed execution-counter leakage between tests; every no-execution or exact-count assertion now initializes its own counter state rather than depending on test order.
32. Independent review found and corrected raw exception leakage, conflation of returned API errors with thrown exceptions, missing successful-content identity evidence, and duplicate result-response construction. The corrected code and documentation received independent PASS reviews. At the Part 2K-D checkpoint, evidence was `32` passing `frontman-core` test files with `417` tests, clean ReScript formatting, `116` protocol verifier tests, all `129` official examples, all `443` traceability requirements, and the `30`-test source-comment gate plus repository scan. Part 2K-D was explicitly approved on `2026-08-11`.
33. Part 2K-E adds route-independent `server/discover` and `tools/list` success dispatch. Both results are validated through their shared Sury schemas, preserve string and wide safe numeric IDs, carry exact framework server identity, and use `ttlMs: 0` with private cache scope.
34. Discovery advertises only `tools.listChanged: false` and the single supported protocol version. Listing emits one page without `nextCursor`, filters tools hidden from the agent, converts input/output schemas to standard MCP `Tool` definitions, maps internal access to conservative `readOnlyHint` values, and sorts exact names deterministically without changing Relay serialization.
35. The accepted boundary retains the validation-time registry so later list dispatch cannot accidentally serialize a different registry snapshot. Focused tests prove schema-valid discovery/list envelopes, identity and capability fields, string/numeric ID preservation, hidden-tool exclusion, output-schema preservation, access annotations, no execution, and identical ordering under reversed registration order.
36. At the Part 2K-E checkpoint, `32` `frontman-core` test files with `421` tests and ReScript formatting passed, followed by an independent final PASS review. That checkpoint remained route-independent and did not register `/mcp`, map media/body failures, reject unsolicited cursors, validate raw duplicate fields, apply Origin/auth policy, or add cancellation; Parts 2K-F and 2K-G subsequently closed its cursor and pre-decode mapping gaps.
37. Independent review first found semantically stale traceability and status prose plus insufficient evidence that the standard serializer preserved source descriptions and input/output schemas exactly. The documentation was corrected, and the serializer test now compares those values directly against the source tool module rather than relying only on successful `MCP.Tool.schema` validation.
38. Final serial verification passed the `421`-test `frontman-core` suite, ReScript formatting, the `116`-test protocol verifier, all `129` official examples, all `443` traceability requirements, generated-schema diff verification, the `30`-test source-comment gate plus repository scan, and `git diff --check`. A final independent re-review returned PASS.
39. Part 2K-E was explicitly approved on `2026-08-11`.

### 2026-08-11 Phase 2 Unsolicited-Cursor Delta

1. Part 2K-F rejects every supplied `tools/list` cursor after complete shared-schema parsing. Empty and arbitrary opaque strings are both valid wire values but invalid for Frontman's one-page server because it has no continuation cursor.
2. Cursor rejection uses the existing method-level HTTP 200/`-32602` response, preserves readable string and wide safe numeric IDs, and does not parse, normalize, or branch on cursor contents.
3. An absent cursor continues through exact selection to the existing one-page result. Rejected cursors never produce an accepted request, serialize a catalog, or execute a tool.
4. Focused method and decoded-boundary tests cover absent, empty, and opaque cursors, complete named-error schema validity, exact status/code/message, ID preservation, and zero execution side effects.
5. At the Part 2K-F checkpoint, the complete `frontman-core` suite passed at `32` test files and `423` tests alongside ReScript formatting, the `116`-test protocol verifier, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, and `git diff --check`.
6. Independent code, test, and documentation review returned PASS with no findings. Part 2K-F was explicitly approved but remains route-independent; Part 2K-G subsequently completed pre-decode HTTP response composition.

### 2026-08-11 Phase 2 Pre-Decode HTTP Delta

1. Part 2K-G adds route-independent `FrontmanCore__MCP__HttpRequest`. It validates request media before body access, composes the approved Web Request body reader/decoder, and delegates successful arbitrary-root JSON values to `DecodedRequest` without registering `/mcp` or executing accepted work.
2. Frontman's local standards-oriented policy returns empty HTTP 415 for unsupported request media, empty HTTP 406 for unacceptable response offers, empty HTTP 413 for declared or streamed body-size violations, and empty HTTP 408 for body idle timeout. These are local transport/security policies, not MCP-mandated status mappings.
3. Missing bodies, malformed `Content-Length`, excessive chunk fragmentation, malformed UTF-8, excessive JSON depth, and malformed JSON return HTTP 400 with the fixed ID-less `-32700` error `Parse error: Invalid JSON`. Responses never trust or recover an ID from bytes that did not produce a complete JSON value.
4. An already-consumed Web Request body and unexpected stream exceptions remain loud server invariant failures rather than hostile-client categories. Existing reader behavior retains cancellation and lock-release ownership for controlled byte, chunk, and timeout failures.
5. Focused composition tests prove media precedence without body consumption, exact empty response bodies and absent response media headers, every controlled typed mapping, malformed-body precedence over decoded validation, preflight 413 without reader acquisition, arbitrary-root handoff to `-32600`, complete-request acceptance, and zero execution side effects.
6. At the Part 2K-G checkpoint, evidence was the complete `frontman-core` suite at `33` test files and `433` tests, clean ReScript formatting, the `116`-test protocol verifier, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, and `git diff --check`.
7. Independent review found and corrected one stale Phase 1 cleanup sentence that still called parse/media/body mapping future work. The final code, test, and documentation re-review returned PASS. The user explicitly approved Part 2K-G. At that checkpoint, raw physical custom-header multiplicity, Origin, authorization, adapter cancellation, and active routing remained later gates; Parts 2K-H through 2K-J subsequently closed the first three route-independent blockers.

### 2026-08-11 Phase 2 Raw Physical Header Delta

1. Part 2K-H adds `FrontmanCore__MCP__RawHeaders` as the typed owner for Node's alternating physical name/value list. Odd-length input crashes as an adapter invariant instead of inventing a value.
2. Vite and Astro capture `IncomingMessage.rawHeaders` before constructing Web `Headers` and pass the resulting physical list through the core middleware boundary. Focused adapter tests preserve original name casing, duplicate occurrences, and one comma-containing value.
3. `HttpRequest` and `DecodedRequest` carry optional raw evidence to selected-schema custom-header validation. Calls without recognized annotations remain unaffected; a selected annotated call without physical evidence crashes loudly so a future route cannot silently trust folded Web headers.
4. Recognized physical names compare case-insensitively. Zero occurrences means omission, one occurrence supplies its exact unsplit value, and two or more occurrences return HTTP 400/`-32020` before complete selected-input validation or execution.
5. Focused custom-header, decoded-request, and complete pre-decode HTTP tests prove a comma-containing singleton remains accepted, mixed-case duplicates are rejected, duplicate rejection preserves the canonical error without exposing values, and execution remains at zero.
6. The complete `frontman-core` suite passes at `33` files and `438` tests. Astro passes `10` files and `61` tests; Vite passes `1` file and `2` focused adapter tests. The `116` protocol tests, `129` official examples, `443` traceability requirements, generated-schema diff check, `30` source-comment tests plus repository scan, and `git diff --check` pass.
7. Independent review first found one stale Phase 1 cleanup sentence that still called raw duplicate validation wholly future work. Re-review then found both adapters captured `rawHeaders` after beginning Web Request construction and that the first focused tests exercised only the extraction helper. Capture now occurs before body collection or Web Request construction, adapter tests invoke the actual middleware adaptation path, and final re-review returned PASS.
8. At the Part 2K-H checkpoint, Origin, authorization, Next.js raw access, adapter cancellation, and production dispatch remained later gates. Parts 2K-I and 2K-J subsequently closed the first three route-independent blockers, Part 2K-K added transport cancellation ownership, Part 2K-L completed configured JavaScript framework production dispatch, and Part 2K-M completed cancellation-aware selected-tool execution and the absolute framework deadline.
9. The user explicitly approved Part 2K-H on `2026-08-11` after the final independent PASS review.

### 2026-08-11 Phase 2 Origin And Authorization Delta

1. Part 2K-I adds `FrontmanCore__MCP__HttpSecurity` as the route-independent owner for configured Origin allowlists and adapter-supplied authorization decisions.
2. Incoming and configured HTTP(S) origins are parsed through the standard URL implementation and compared by canonical origin, including effective default ports. Missing, `null`, malformed, multiple, unlisted, userinfo-bearing, path/query/fragment-bearing, trailing-dot, encoded-host, and unsupported-scheme values return empty HTTP 403.
3. Origin rejection occurs before the authorization callback, media validation, body access, JSON parsing, decoded MCP validation, or execution. The authorization callback receives headers rather than the Web Request, preventing it from consuming the body through this API.
4. Missing authentication returns empty HTTP 401 and insufficient authorization returns empty HTTP 403. Both occur before media/body processing and only after an allowed Origin.
5. Responses after a validated Origin echo only its canonical value in `Access-Control-Allow-Origin` and append `Vary: Origin`; invalid-Origin responses contain no CORS permission. Wildcard MCP CORS is absent from the new boundary.
6. `HttpRequest.Accepted` carries the validated Origin separately from the decoded JSON-RPC request so a later production dispatcher can apply response policy without treating wire metadata as security context.
7. Focused multi-fault tests prove invalid Origin wins over authentication, media, declared body size, parsing, and execution; authentication failure wins over media/body faults; every rejection leaves the request body unread and tool execution at zero.
8. At the Part 2K-I checkpoint, the complete `frontman-core` suite passed at `34` files and `444` tests. Adapter configuration, Next.js raw evidence, preflight handling, active routing, real authentication, and sibling `/frontman/resolve-source-location` policy remained later gates; Part 2K-J subsequently closed the first two route-independent blockers.
9. Independent review found that WHATWG URL parsing accepted malformed shorthand such as `https:example.com` and canonicalized it to an allowlisted origin. A strict serialized-origin grammar now runs before URL parsing, alternate numeric-host forms are rejected, and focused regressions cover the bypass. A second hardening pass gives authorization an isolated header snapshot so callback mutation cannot alter later protocol validation. Final independent re-review returned PASS.
10. Part 2K-I was explicitly approved by the user on `2026-08-11` as part of the completed Origin/auth and adapter-input session.

### 2026-08-11 Phase 2 Adapter Configuration And Next.js Node Input Delta

1. Part 2K-J adds `FrontmanCore__MCP__AdapterSecurity`, one JS-facing adapter input with explicit allowed Origins and exact `authorized`, `missing-authentication`, and `insufficient-authorization` decisions. It delegates canonicalization and 401/403 behavior to `HttpSecurity` rather than duplicating policy.
2. Next.js, Vite, and Astro configs construct this policy eagerly when optional `mcp` configuration is present. Focused package tests prove canonical default-port behavior, malformed configured-Origin crashes, and that an attacker-controlled request URL cannot expand the allowlist.
3. No adapter derives MCP authority from the Frontman client asset URL, remote Phoenix host, incoming Host, forwarded headers, or JSON-RPC metadata. Supplying policy configuration remains inert and does not register `/mcp`.
4. Online verification against Next.js 16.3 documentation and upstream/community usage established that Proxy and App Route Handlers expose only folded Web Headers, while documented Pages API Routes receive `NextApiRequest` as Node `IncomingMessage` with physical `rawHeaders`. Pages API Routes continue to work alongside App Router projects.
5. `FrontmanNextjs__NodeApiAdapter` uses that supported Node API seam. It captures physical headers first, crashes on odd raw arrays or missing Host, requires `readableDidRead: false`, validates Origin and authorization from headers, and only after acceptance converts the untouched Node stream through `Readable.toWeb` with `duplex: half`.
6. Focused Next tests preserve original casing, duplicate occurrences, and a comma-containing singleton; prove hostile Origin rejection performs zero source reads; prove accepted input reaches an unconsumed Web Request and preserves its bytes; and crash when simulated Next body parsing already consumed the request.
7. A future generated Pages API Route must disable `bodyParser`, and a future reviewed internal rewrite may map public `/mcp` to that Node route. Neither is generated or active in this slice. Proxy/App Route headers are explicitly not accepted as physical evidence.
8. Review first rejected eager `Readable.toWeb`, a hidden Host fallback, premature public export, missing body-parser enforcement, and narrow non-registration proof. Security now precedes stream construction, Host and prior body consumption crash loudly, the adapter remains internal, and `/mcp`, `/frontman/mcp`, custom-base aliases, and preflights remain unregistered and body-unread. Final independent re-review returned PASS.
9. At the Part 2K-J checkpoint, evidence was `35` core files and `446` tests, `12` Next.js files and `189` tests, `11` Astro files and `63` tests, and `2` Vite files and `4` tests. Vite/Astro still buffered matched request bodies before core middleware; Part 2K-K subsequently replaces those paths with the shared streaming Node/Web chassis.
10. Part 2K-J was explicitly approved by the user on `2026-08-11` after the final independent PASS review and complete serial verification.

### 2026-08-11 Phase 2 Shared Node/Web Chassis Delta

1. Part 2K-K adds `FrontmanCore__NodeWebChassis` as the single Node `IncomingMessage` and `ServerResponse` lifecycle owner used by Next.js, Vite, and Astro.
2. The chassis captures the alternating physical header list before Web normalization, requires one nonempty physical Host field, and constructs its security snapshot from those captured fields.
3. An adapter-supplied asynchronous gate runs before `Readable.toWeb`, body construction, or middleware dispatch. The internal Next.js Pages API adapter supplies the approved Origin and authorization policy through this gate.
4. Vite and Astro no longer collect matched bodies into buffers. Their existing private Frontman routes now reach middleware as untouched streaming Web Requests, while inactive `/mcp` requests still pass through unread without middleware dispatch.
5. Request `aborted` and response `close` events converge on one idempotent cancellation owner. It aborts the matching Web signal, destroys the Node request, cancels an acquired Web response reader, resolves pending backpressure waits, and suppresses late middleware responses.
6. Cancellation races the security gate and middleware dispatch, so a disconnect returns without waiting for an uncooperative promise. The raced promise remains observed, preventing a later resolution or rejection from writing a response or becoming unhandled.
7. Web response bodies are written as exact `Uint8Array` bytes without text decoding. A false Node `write` result waits for `drain`, response close wins that wait, and normal completion removes listeners before ending the response.
8. Focused core tests prove denial before body pull, untouched streaming input, physical-header preservation, request-abort and response-close cancellation, late-response suppression, open-reader cancellation, exact non-text bytes, backpressure, close-during-backpressure, no ending after cancellation, and listener cleanup.
9. Focused package tests prove Next security-before-body behavior and response-close ownership, Vite/Astro streaming without pre-buffering, physical evidence propagation, and inactive `/mcp` pass-through with unread bodies.
10. Part 2K-K establishes transport cancellation ownership only. At that checkpoint tool execution contexts did not consume the abort signal; Part 2K-M subsequently propagates the same signal into selected execution and stops owned child processes cooperatively.
11. After review-driven test consolidation and cancellation-race coverage, the complete suites pass at core `36` files and `455` tests, Next.js `12` files and `190` tests, Astro `11` files and `64` tests, and Vite `2` files and `5` tests. `/mcp` remains unregistered.
12. Independent review found and corrected Vite partial-response error handling, then requested stronger uncooperative-gate, nonsettling-reader-cancellation, and normal-close evidence plus removal of adapter-local test-only helpers. Final re-review returned PASS.
13. The user explicitly approved Part 2K-K on `2026-08-11` after final review and verification. Approval covers the route-independent shared chassis checkpoint only; it does not activate `/mcp`, configure real authentication, or claim cancellation-aware tool execution.
14. Final protocol/documentation verification passed all `116` protocol verifier tests, all `129` official examples, structural verification of all `443` normative traceability requirements, the `30`-test repository source-comment gate, an explicit scan of newly created untracked chassis and adapter test files, and `git diff --check`.
15. The root ReScript formatter completed for tracked files and `frontman-core` formatted its new untracked chassis files directly. The Astro package `make format` target still fails before formatting because it passes directory arguments unsupported by the installed formatter; that pre-existing tooling defect remains separate work.
16. No `/mcp` route, generated Next API route or rewrite, preflight handler, real authentication policy, black-box transport suite, official conformance run, Relay deletion, or changeset was added in Part 2K-K.

### 2026-08-11 Phase 2 Active Endpoint Delta

1. Part 2K-L adds `FrontmanCore__MCP__Endpoint` as the shared active owner for Origin-only preflight, authenticated POST and unsupported-method handling, approved `HttpRequest` validation, asynchronous decoded execution, synchronous JSON responses, and validated-Origin CORS.
2. Security is split without weakening order: the chassis validates Origin and authorization once before Web body construction, and `HttpRequest.validateAfterSecurity` begins at media policy without repeating a stateful authorization decision.
3. Exact configured `/mcp` routing is active in Vite and Astro. Missing `mcp` configuration leaves the route untouched; case variants and trailing-slash aliases are not synthesized.
4. Next.js exports `createMcpHandler` for the documented Node Pages API seam. At this checkpoint the installer generated `pages/api/frontman-mcp.ts` or `src/pages/api/frontman-mcp.ts`, disabled body parsing, required explicit allowed Origins and a bearer token from environment variables, and placed the public `/mcp` rewrite in middleware or Proxy. Part 2K-N later proved that those interception layers consume the POST stream and moved the rewrite into installer-owned `next.config` server routing while excluding `/mcp` from middleware and Proxy matchers.
5. Preflight validates Origin without invoking request authentication, requires `Access-Control-Request-Method: POST`, accepts standard MCP headers, `Authorization`, recognized `Mcp-Param-*` names, and explicitly configured application headers, and returns an empty 204. Unsupported preflight fields return an empty Origin-bearing 400.
6. Every non-OPTIONS request validates Origin and authorization before adaptation. Unsupported methods return an empty 405 with `Allow: POST, OPTIONS`; POST preserves the frozen media, body, envelope, header, metadata, method, selection, custom-header, input, and execution order.
7. Focused active tests prove one authorization decision, no preflight authentication, schema-valid discovery execution, exact preflight fields, 405 policy, configured-only Vite/Astro activation, Next Node dispatch, installer route generation, rewrite installation, `bodyParser: false`, and required authentication environment inputs.
8. At the Part 2K-L checkpoint, serial evidence was core `37` files/`460` tests, Next.js `12`/`193`, Astro `11`/`65`, and Vite `2`/`6`. A deliberately attempted parallel core/Next run reproduced the documented shared generated-artifact race; serial reruns were authoritative.
9. Independent review found and corrected raw-method canonicalization, weak auto-edit and existing-route validation, incomplete preflight variance, and stale traceability claims. Final re-review returned PASS. At the Part 2K-L checkpoint cancellation-aware tool execution, absolute request deadlines, real-process framework proof, and source-location sibling policy remained open; Part 2K-M closed the first two, approved Part 2K-N closed real-process parity, and approved Part 2K-O closed the sibling policy. Relay removal, official conformance, and final Phase 2 acceptance remain open.
10. Raw HTTP method classification is retained in the gate context as `Post`, `Preflight`, or `Unsupported`. Dispatch does not infer the original method from a Fetch `Request`, whose constructor can canonicalize lowercase `post` into `POST`; lowercase `post` and `options` therefore authenticate and return 405 rather than executing or bypassing authentication.
11. Every Origin-dependent response now carries appropriate variance metadata. Invalid Origin responses use `Vary: Origin`; successful and rejected preflights vary on Origin, requested method, and requested headers so shared caches cannot reuse one authority decision for another.
12. At this checkpoint Next installer validation stripped comments and required structural evidence that the `/mcp` rewrite was the first middleware/Proxy operation, that the exported matcher contained `/mcp`, that `createMcpHandler` was the default API-route handler, and that exported `config.api.bodyParser` was false. Part 2K-N superseded the interception design: middleware/Proxy validators now exclude MCP routing, the installer owns the server rewrite in `next.config`, and the API-route body-parser and handler validation remains mandatory.
13. Existing partial or malformed Next API routes are not overwritten and are not reported as configured. They produce an explicit manual-repair result, including when `createMcpHandler` or `bodyParser: false` appears only in a comment or unrelated object.
14. `.changeset/modern-mcp-framework-endpoint.md` records a major change for `@frontman-ai/frontman-core`, `@frontman-ai/nextjs`, `@frontman-ai/astro`, and `@frontman-ai/vite` because this activates the latest-only secured framework transport and changes generated integration behavior.
15. Final verification passed ReScript formatting for the new core files, core `37`/`460`, Next.js `12`/`193`, Astro `11`/`65`, Vite `2`/`6`, all `116` protocol verifier tests, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, and `git diff --check`.
16. The user explicitly approved Part 2K-L on `2026-08-11` after every independent-review finding was corrected and the final serial verification completed. Approval covers the active JavaScript framework endpoint slice only; it does not accept Phase 2 or claim cancellation-aware execution, absolute deadlines, black-box framework parity, WordPress activation, Relay removal, or official conformance.

### 2026-08-12 Phase 2 Cancellation And Absolute Deadline Delta

1. Part 2K-M extends `FrontmanProtocol__Tool.serverExecutionContext` and `FrontmanCore__Server.executionContext` with one required typed `AbortSignal`. `FrontmanCore__MCP__Endpoint` passes the exact signal created by the shared Node/Web chassis into selected-tool execution without adding transport lifecycle state to `HttpRequest` or `DecodedRequest` accepted protocol values.
2. `FrontmanCore__Server.executeSelectedTool` checks the signal before invocation and after a tool returns. When cancellation has occurred, an abort-related rejection escapes the ordinary execution-error mapper instead of becoming the client-visible `Tool execution failed` result. Ordinary tool, business, API, validation, and server-invariant failures keep their existing classifications.
3. `FrontmanCore__NodeWebChassis` now owns an optional immutable absolute deadline in the same lifecycle domain as gate, adaptation, dispatch, response pumping, and disconnect ownership. Active Next.js, Vite, and Astro `/mcp` paths enable the frozen `600,000`-millisecond deadline; private legacy framework routes do not acquire an unrelated timeout policy.
4. The deadline is measured with monotonic time from Node request ingress. Work or a terminal response committed exactly at `600,000` milliseconds wins; at `600,001` milliseconds the chassis aborts the matching signal and returns exactly one empty HTTP 408. Activity, progress, body bytes, authorization, and execution do not reset the absolute deadline.
5. Disconnect and deadline remain distinct terminal reasons. A disconnect aborts work, destroys the Node request, suppresses all output, and returns no response; deadline expiry aborts work but retains response ownership long enough to emit the one empty 408. Both reasons cancel open response readers, release backpressure waits, observe losing promises, and remove timers and listeners.
6. Terminal state is published before `AbortController.abort` invokes synchronous abort listeners. `raceTerminal` therefore preserves `Cancelled` or `TimedOut` when an abort-aware gate or dispatch promise rejects immediately, while unrelated work failures still escape when the lifecycle remains active.
7. Response commitment is the deadline boundary, not Web response creation or Node status/header assignment. A response body that has not emitted its first bytes remains deadline-bound; the first Node write commits a body response, while an empty response commits when the chassis completes and ends it. A stalled body can no longer clear the timer and hang forever after merely assigning headers.
8. `FrontmanCore__ChildProcess` accepts the execution signal for `spawn` and `exec` ownership. Grep, search-files, list-tree, and list-files pass their selected-tool signal into ripgrep, grep, git, and shell work so disconnect or deadline sends `SIGTERM` to currently owned child processes.
9. Child-process cancellation does not report completion merely because `kill` was requested. Abort, max-buffer termination, and process-error paths retain their terminal category and settle only after the process `close` event. Output is ignored after termination begins, listeners are removed once, and a late close cannot replace the selected result.
10. Focused chassis tests prove ordinary disconnect, disconnect with synchronous abort-aware rejection, exact-deadline response commitment, one-millisecond-over timeout, timeout with synchronous abort-aware rejection, stalled pre-byte response timeout, signal abort, one empty 408, late-output suppression, one terminal `end`, and zero leaked timers.
11. Focused endpoint and decoded-execution tests prove the exact chassis signal reaches the selected existential tool unchanged. The child-process integration test proves the abort result and waits beyond a scheduled filesystem side effect to prove the terminated process did not continue after the promise settled.
12. Independent review found and corrected the abort/rejection ordering race, duplicate controller abort, premature deadline clearing before actual response commitment, immediate process settlement after `SIGTERM`, the same early-settlement defect in max-buffer paths, process `error` settlement before `close`, and non-exhaustive boolean control flow. The final focused re-review returned PASS.
13. `.changeset/modern-mcp-framework-endpoint.md` now includes cancellation-aware execution and the ten-minute absolute deadline in the existing major framework-endpoint change rather than adding a second fragment for the same unreleased transport break.
14. Final serial verification passed core `37` files/`468` tests, Next.js `12`/`193`, Astro `11`/`65`, Vite `2`/`6`, all `116` protocol verifier tests, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, ReScript formatting, and `git diff --check`.
15. The user explicitly approved Part 2K-M on `2026-08-12` after the final focused PASS review and complete serial verification. Approval covers active JavaScript framework cancellation-aware execution and absolute-deadline ownership; it did not at that checkpoint claim real-process framework black-box parity, which approved Part 2K-N subsequently establishes, or source-location CORS completion, which approved Part 2K-O subsequently establishes. It does not accept Phase 2 or claim transactional rollback of already committed tool effects, WordPress activation, Relay removal, browser-client cutover, or official conformance.

### 2026-08-12 Phase 2 Real-Process Framework Parity Delta

1. Part 2K-N adds one shared no-secrets real-process contract at `test/e2e/tests/mcp-blackbox.test.ts` for rebuilt public `@frontman-ai/nextjs`, `@frontman-ai/astro`, and `@frontman-ai/vite` artifacts. It launches actual framework development servers, communicates over loopback HTTP and raw TCP sockets, and does not substitute `fetch`, adapter middleware, or endpoint dispatch.
2. The `12` tests are table-driven across all three frameworks. They prove installed public `/mcp` reachability, private-alias rejection, configured Origin and authorization behavior, Origin-only preflight, unsupported HTTP methods, media rejection, discovery, deterministic listing, successful selected-tool execution, header mismatch, unsupported JSON-RPC methods, string and wide numeric ID preservation, socket-disconnect recovery, and absolute-deadline response behavior.
3. The suite rebuilds all three publishable adapter packages before startup so workspace consumers exercise current `dist` exports rather than stale checked-in bundles. This caught real source/bundle drift in Vite during exploration and freezes rebuild-before-black-box as part of the gate.
4. The first Next real-process request exposed a production transport defect that focused adapter tests could not see: rewriting `/mcp` from Next Proxy into a Pages API route consumed the POST stream before `createMcpHandler`, leaving the endpoint waiting for body bytes until timeout. Proxy returning `NextResponse.next()` did not preserve the body either.
5. The Next installer now owns a body-preserving server rewrite in `next.config.mjs` or the common existing `next.config.js` shape, generates the authenticated Pages API route with `bodyParser: false`, and removes `/mcp` routing and matching from middleware and Proxy templates. Unfamiliar existing Next config shapes produce explicit manual-repair output rather than destructive or speculative edits.
6. Next installer auto-edit prompts were corrected with the same ownership rule. Middleware and Proxy model instructions no longer request MCP rewrites or `/mcp` matchers, and Proxy instructions explicitly forbid the unsupported `runtime` field that Next rejects.
7. The Next active handler now passes `Endpoint.absoluteTimeoutMs` into the shared chassis. The first black-box exploration found that the exported handler path omitted the ten-minute deadline even though a lower-level helper supplied it.
8. Vite and Astro configure their Frontman MCP middleware before framework CORS and disable the framework-wide development CORS responder when explicit MCP security is active. Real preflight requests had shown Vite's default responder returning broad methods before Frontman's exact `POST, OPTIONS` policy ran.
9. Ordinary contract vectors use real time. The absolute deadline vector uses a child-process preload that accelerates timers at or above the frozen `600,000`-millisecond limit while leaving shorter framework timers unchanged. Focused core fake-time tests remain authoritative for exact `600,000/600,001` boundary semantics; the real-process vector proves each installed adapter actually wires the deadline to an empty HTTP 408 and remains healthy afterward.
10. Raw socket helpers distinguish HTTP chunk framing from entity-body bytes. Next emits an empty 408 using the valid terminal chunk `0\r\n\r\n`; tests decode that framing before asserting the response body is empty instead of treating transport framing as payload.
11. Framework teardown now sends `SIGTERM`, waits for the actual child `exit`, escalates to `SIGKILL` after five seconds, and only then restores generated fixture files. The earlier helper restored fixtures immediately after signaling, which could race a still-running framework process.
12. The dedicated `make mcp-blackbox` target builds Next.js, Vite, and Astro serially and runs `vitest.mcp.config.ts` without Phoenix, PostgreSQL, Playwright, provider credentials, or `test/e2e/.env`. `.github/workflows/e2e.yml` adds the corresponding no-secrets job and expands path ownership to protocol, core, adapter, MCP documentation, fixture, and root Makefile changes.
13. Review strengthened route-alias evidence from absence of a CORS header to an actual HTTP error status plus no allowed-Origin response. It also rejected a first deadline preload tied only to one exact timer implementation, required process-exit waiting during cleanup, and removed an unused fixture import.
14. The shared suite deliberately does not claim active emitted-SSE behavior because the server has no streaming producer. It proves synchronous JSON interoperability and socket cancellation before response commitment; exact first-byte response-commitment races remain focused shared-chassis evidence until a real MCP streaming producer exists.
15. Next server rewrites normalize path case and trailing slashes before the internal route. `/MCP` and `/mcp/` therefore remain a documented framework routing limit and are not counted as exact-alias rejection. Vite and Astro continue to prove exact case-sensitive root routing and reject those aliases.
16. A final review identified one residual child-process risk outside Part 2K-N: `exec`-launched shell pipelines receive `SIGTERM` at the immediate shell owner, but descendant process-group termination is not yet proven. The existing direct-child side-effect suppression remains valid; complete process-tree termination requires a separately owned runtime hardening slice rather than a black-box test workaround.
17. Final accepted evidence is the `12`-test real-process matrix, Next.js `12` files/`193` tests, Astro `11`/`65`, Vite `2`/`6`, all `116` protocol verifier tests, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, focused ReScript formatting, `git diff --check`, and independent review after every black-box, installer, teardown, and documentation finding was addressed.
18. The user explicitly approved Part 2K-N on `2026-08-12`. Approval closes real-process JavaScript framework parity with the stated Next routing and no-streaming-producer limits; it did not at that checkpoint close source-location CORS policy, which approved Part 2K-O subsequently establishes. It does not accept Phase 2, WordPress, Relay removal, browser-client cutover, or official conformance.

### 2026-08-12 Phase 2 Source-Location Security Delta

1. Part 2K-O adds `FrontmanCore__SourceLocationEndpoint` as the separate non-MCP owner for `/frontman/resolve-source-location`. It does not reuse MCP request metadata, method dispatch, Accept negotiation, JSON-RPC errors, or the MCP authorization callback.
2. Every source-location preflight and request requires one canonical HTTP(S) Origin from an explicit allowlist. Missing, `null`, malformed, multiple, unlisted, or unconfigured Origins return empty HTTP 403 before media validation or body access; invalid responses expose no CORS permission and vary on Origin through the shared security owner.
3. Accepted source-location responses echo only the validated Origin and append `Vary: Origin`. No response emits wildcard CORS or `Access-Control-Allow-Credentials`, so the endpoint does not authorize ambient browser credentials.
4. Origin-only preflight requires exact raw `OPTIONS`, requests `POST`, accepts only an absent request-header list or the single case-insensitive `Content-Type` field, returns empty HTTP 204 with `POST, OPTIONS`, and rejects unsupported methods or headers with an empty Origin-bearing HTTP 400.
5. Allowed non-preflight methods are deliberately narrow. Exact `POST` proceeds; every other method returns empty HTTP 405 with `Allow: POST, OPTIONS` after Origin validation.
6. POST accepts only `application/json` with the existing optional case-insensitive `charset=utf-8` policy. Unsupported or missing media returns empty HTTP 415 before reading the body.
7. The source-location handler no longer calls `Request.json`. It composes the shared `RequestBody`, `BodyReader`, and `BodyDecoder`, inheriting the two-megabyte byte limit, 4,096-chunk limit, 60-second idle deadline, strict UTF-8 validation, depth-64 limit, exact JSON parsing, reader cancellation, and lock-release behavior.
8. Controlled malformed bodies and typed request-schema failures return fixed HTTP 400 `Invalid request` JSON without validator diagnostics or hostile values. Declared or streamed body overflow returns empty HTTP 413, body idle timeout returns empty HTTP 408, and an already-consumed body remains a loud server invariant failure.
9. Source resolution failures now return only the fixed `Failed to resolve source location` category. Raw exception messages and filesystem diagnostics are no longer returned in `details`, closing a disclosure path found by independent review.
10. Source-location authorization is intentionally Origin-only in this slice. The current browser resolver does not possess the generated MCP bearer token, so invoking the MCP authorization callback would break the existing product path while falsely coupling a non-MCP endpoint to MCP credentials.
11. Adapter configuration exposes optional `sourceLocation.allowedOrigins`. Vite and Astro inherit the explicit MCP allowlist when no narrower source-location allowlist is supplied; an explicit source-location policy takes precedence. Missing both policies leaves the endpoint reachable only as an empty 403, not as the previous wildcard fallback.
12. Next middleware and Proxy templates read `FRONTMAN_MCP_ALLOWED_ORIGINS` for the source-location allowlist while the generated Pages API MCP route separately owns bearer authentication. Manual middleware/Proxy instructions and public Next/Astro TypeScript declarations include the new source-location configuration surface.
13. Focused endpoint tests prove missing, hostile, and unconfigured Origin rejection before body consumption; allowed Origin echo; no credential permission; case-insensitive `Content-Type` preflight; unsupported preflight fields; media-before-body ordering; malformed JSON through the shared decoder; declared oversize mapping; and authenticated-method independence.
14. Focused Next.js, Astro, and Vite config tests prove MCP-allowlist inheritance and explicit source-location-policy precedence. Existing framework suites prove the changed public configurations still build and retain their prior MCP behavior.
15. Independent review first found raw source-resolution exception disclosure and missing direct body-limit evidence. A second review found missing public TypeScript declarations, stale Next manual setup, and absent inheritance/precedence tests. All findings were corrected; the final focused independent review returned PASS.
16. Final serial evidence is core `38` files/`477` tests, Next.js `12`/`194`, Astro `11`/`66`, and Vite `2`/`7`, plus root ReScript formatting and `git diff --check`. Part 2K-O changes no MCP normative requirement count and does not claim WordPress support, browser Streamable HTTP cutover, Relay removal, or official conformance.
17. The existing four-package major changeset now includes the separate fail-closed source-location Origin policy rather than creating a duplicate fragment for the same unreleased framework security break.
18. The user explicitly approved Part 2K-O on `2026-08-12` after all review findings were corrected and the final serial verification completed. Approval closes the JavaScript framework source-location sibling-path security gate but does not accept Phase 2 or the complete migration.

### 2026-08-12 Phase 2 WordPress Streamable HTTP Delta

1. The user explicitly approved the WordPress MCP slice on `2026-08-12`. Approval covers the plugin's latest-only synchronous `/mcp` server, the browser runtime's explicit subdirectory-aware endpoint configuration, WordPress package and runtime verification, compatibility workflow expansion, public documentation, traceability updates, and the major changeset. It does not accept all of Phase 2 or the complete migration.
2. `Frontman_MCP` is the dedicated PHP protocol and security boundary. `Frontman_Router` classifies exact site-relative `/mcp` before suffix UI routing, delegates protocol work, emits the returned status/headers/body, and no longer contains private tool discovery/call or custom SSE result machinery.
3. Root WordPress installations expose `/mcp`. Subdirectory and Playground-style installations expose `{home-path}/mcp`; `get_request_path` strips the configured WordPress home path before exact classification. `/MCP`, `/mcp/`, `/frontman/mcp`, `GET /frontman/tools`, and `POST /frontman/tools/call` are not MCP aliases.
4. The browser runtime now receives an explicit `mcpBaseUrl` generated from `home_url()`. `Client__RuntimeConfig` preserves it, and `Client__FrontmanProvider` prefers it over pathname inference. This fixes ordinary WordPress subdirectory installations, which cannot be inferred from a `/frontman` UI suffix alone; the existing Playground scope inference remains the fallback for integrations without an explicit value.
5. Origin validation runs before authorization or body access. WordPress accepts only the canonical HTTP(S) Origin derived from its configured home URL, returns empty 403 for missing, malformed, multiple, or different Origins, echoes only the validated Origin, and varies responses on Origin. Preflight is Origin-only and allows the exact MCP headers, `X-WP-Nonce`, and `Mcp-Param-*` names without invoking session authentication.
6. Every non-preflight request performs one WordPress application-authorization decision after Origin validation. A valid logged-in session and `manage_options` are required; every POST additionally requires `X-WP-Nonce`. Missing authentication returns empty 401, while insufficient capability or nonce failure returns empty 403 before media validation or body access. This remains application authentication, not an MCP OAuth claim.
7. Frontman's strict request media policy runs next. `Content-Type` accepts only JSON with the optional UTF-8 charset, and `Accept` must offer both JSON and event stream. Declared `Content-Length` is validated before opening `php://input`; the body supplier then reads at most `2,097,153` bytes so the exact two-megabyte actual-byte boundary cannot be bypassed by a missing or understated length.
8. WordPress uses PHP's buffered request stream rather than the shared Node/Web reader. It enforces the same byte and JSON-depth limits, but the JavaScript `4,096`-chunk rule, 60-second reader-idle timer, ten-minute chassis deadline, and disconnect cancellation ownership do not apply. The hosting web server owns request-read deadlines; this is an explicit implementation limit, not claimed parity.
9. The PHP boundary accepts exact JSON-RPC `2.0` requests with string or safe-integer IDs, preserves readable IDs in responses, validates complete required request metadata and known client capability/implementation fields, preserves permitted open request and metadata fields, validates standard mirrored headers in the required order, decodes canonical lowercase Base64 sentinels, and returns modern named error/status combinations without echoing hostile values.
10. WordPress initially implements only `server/discover`, one-page `tools/list`, and `tools/call`. Discovery advertises only `tools.listChanged: false` and `2026-07-28`; discovery and listing use `ttlMs: 0`, `cacheScope: "private"`, and `frontman-wordpress` server identity. Every supplied list cursor is rejected, unknown methods return HTTP 404/`-32601`, and unknown tools return HTTP 200/`-32602`.
11. `Frontman_Tools` now emits standard deterministic tool definitions. It filters tools not visible to the agent, sorts exact names, preserves descriptions and input schemas, maps access to `annotations.readOnlyHint`, and omits private `access` and `visibleToAgent` fields. The established no-filesystem-tools policy remains enforced across the normal WordPress registry.
12. Calls select exact case-sensitive names, require object arguments, validate the selected schema before sanitization and execution, and treat omitted arguments as the empty object. Selected-input rejection returns a complete `CallToolResult` with `isError: true`; successful and tool-level failures carry `resultType: "complete"`; unexpected exceptions become the fixed `Tool execution failed` result without exposing PHP exception text.
13. WordPress tools do not emit `input_required` and advertise no MRTR capability. Any supplied `inputResponses` or `requestState` is rejected with HTTP 200/`-32602` before selection or execution rather than being partially parsed or silently ignored. Open unrelated extension fields remain accepted.
14. The old `GET /frontman/tools`, `POST /frontman/tools/call`, Relay version `1.0`, `input` alias, name sanitization, and bare `event: result` SSE output were removed atomically. The separate unsupported source-location route remains non-MCP and retains its existing WordPress application-authentication boundary.
15. Focused MCP tests now prove Origin/auth precedence, Origin-only preflight, discovery, private cache metadata, string and wide numeric IDs, deterministic standard listing, hidden-tool filtering, unsolicited-cursor rejection, successful execution, unknown tool/method classification, selected-input rejection, mirrored-name mismatch, encoded-name comparison, open fields, malformed known metadata, MRTR rejection, media rejection, declared oversize rejection, and no rejected-request execution. The complete isolated WordPress suite passes at eight runners, including `57` MCP assertions and `15` router assertions.
16. Real WordPress runtime verification packages the plugin, installs and activates it on WordPress `7.0.2`, enables actual Apache request routing, creates a real administrator cookie/nonce pair, changes `home_url` to `http://localhost/blog`, successfully performs authenticated discovery at `/blog/mcp`, and proves both legacy route/method pairs are absent. PHP `7.4.33` and `8.4.24` runtime executions pass; isolated tests also pass on PHP `7.4` and the local PHP `8.5` runtime, while CI now covers `7.4`, `8.4`, and `8.5`.
17. The browser client rebuild passes at `614` modules after adding `mcpBaseUrl`. The `30`-test source-comment gate plus repository scan, Changesets status, shell syntax, `git diff --check`, and the final independent review pass. `.changeset/modern-wordpress-mcp.md` records major changes for `@frontman-ai/frontman-wordpress` and `@frontman-ai/client`.
18. Review found and corrected eager body materialization before security, missing normal-subdirectory endpoint ownership, shallow known-metadata validation, closed-object rejection of valid extension fields, unvalidated MRTR state, missing encoded-name decoding, weak legacy-route runtime proof, PHP-version-specific reflection behavior, overstated evidence, and URI validation that initially accepted whitespace. The final independent re-review returned PASS.
19. Approval does not claim the full shared WordPress/Playground black-box matrix, PHP-side disconnect cancellation, JavaScript chassis deadlines, custom `x-mcp-header` annotations in the current WordPress catalog, emitted SSE, official conformance, JavaScript Relay deletion, or installed application E2E. The source-level application consumer cutover was subsequently accepted and does not alter those remaining gates.

### 2026-08-12 WordPress Streamable HTTP Lessons

1. Security ordering must be reflected in ownership, not just called in the right order after the fact. Passing a lazy bounded body supplier into the protocol boundary prevents the router from materializing hostile bytes before Origin, authentication, media, and declared-size checks.
2. A browser pathname cannot reliably reveal a WordPress installation base. Ordinary `/blog` installs and Playground `/scope:*` installs need the authoritative `home_url` path supplied by WordPress; heuristics remain only a fallback for integrations that cannot provide it.
3. WordPress session authentication and MCP wire validation are separate boundaries. Origin is transport security, session/capability/nonce are application authorization, and neither may be inferred from JSON-RPC metadata, Host, or client identity.
4. PHP's request body model is not Node's Web Streams model. Preserve common externally visible byte/decode behavior where practical, but document hosting-owned deadlines and the absence of chunk/disconnect ownership instead of claiming fake chassis parity.
5. Latest-only does not mean closed-object parsing. MCP request and metadata objects preserve permitted extension fields while known required fields and known optional fields are validated completely.
6. Optional protocol machinery without a producer is safer to reject than partially implement. Because WordPress emits no `input_required`, rejecting supplied MRTR retry fields before execution avoids a shallow parser becoming an authorization or replay ambiguity.
7. Tool serialization is a protocol boundary. Reusing Relay definitions would leak private policy fields; standard MCP definitions require a separate deterministic projection even when the underlying handlers and schemas remain unchanged.
8. Validate before sanitizing. Sanitization protects WordPress handlers, but it must not coerce malformed MCP arguments into valid-looking inputs before schema rejection.
9. Real HTTP proof must use real WordPress cookies, nonces, rewrites, and subdirectory paths. Direct PHP invocation proves handler compatibility, not router, authentication, or web-server behavior.
10. Evidence claims must name exactly what ran. Focused PHP vectors and authenticated subdirectory discovery are valuable, but they are not the full shared black-box suite; broader WordPress/Playground parity remains an acceptance gate.
11. Compatibility matrices catch test-harness bugs as well as production bugs. Reflection accessibility had opposite requirements on PHP 7.4 and 8.5, so version-aware test setup is part of maintaining the declared runtime range.
12. Atomic migration is simpler than compatibility layering. Removing both private route/method pairs and custom SSE in the same slice prevented a second WordPress protocol mode from surviving behind the modern client.

### 2026-08-12 Phase 9 Canonical Persisted-Result Delta

1. The user explicitly approved the canonical persisted-result slice on `2026-08-12`. Approval covers persistence-boundary validation, one-time legacy normalization, complete live/historical/ACP/model projection, focused migration proof, documentation updates, and the final independent PASS review. It does not accept all of Phase 9.
2. `FrontmanServer.Tasks.CanonicalToolResult` is the single current-runtime owner for canonical result normalization and model projection. `Interaction.ToolResult.changeset/2` invokes it for every new write, so browser responses, backend tools, protocol-error results, timeouts, cancellation outcomes, restart interruption, and duplicate-resolution winners all cross the same persistence boundary.
3. A persistable result requires exact `resultType: "complete"`, an array-valued `content`, valid standard content blocks, optional boolean `isError`, and valid optional result metadata. The validator preserves open top-level fields and arbitrary `structuredContent`, replaces result `_meta` with an empty object, and derives the persisted `is_error` flag from the canonical result rather than trusting caller-supplied state.
4. Runtime content validation now rejects malformed or noncanonical Base64 for image, audio, and embedded-blob content and rejects relative or malformed resource URIs. This closes the gap where a result could pass persistence and later crash at model projection through `Base.decode64!/1`.
5. Canonical storage and ACP retain text, image, audio, resource-link, embedded-text-resource, and embedded-blob-resource blocks without narrowing. Model runtimes continue to receive native text and image parts; unsupported audio and resource blocks receive deterministic textual representations that omit binary data and never dereference a URI.
6. Empty `content` is valid and now reaches a waiting executor and historical model reconstruction instead of being mislabeled as no executor or omitted from history. Historical error results preserve `is_error` in model-message metadata, matching live delivery semantics.
7. Structured content remains any JSON value. Object, array, string, number, boolean, and null survive persistence. ACP now distinguishes an absent `structuredContent` field from an explicitly present JSON null by carrying `Map.fetch/2`'s tagged result into the update builder; explicit null therefore emits `rawOutput: null` rather than disappearing.
8. `20260812000000_canonicalize_tool_results.exs` is the one-time persisted-data compatibility boundary. It adds `resultType: "complete"` only to otherwise valid legacy maps, scrubs historical result `_meta`, preserves content, structured content, error state, and open fields, and aborts deployment with the malformed-row count instead of silently dropping, coercing, or retaining a permanent legacy parser.
9. The migration contains a frozen, self-contained copy of the accepted validation rules. It deliberately does not call the current application changeset or protocol validator: historical migrations must remain deterministic if application modules are later renamed, removed, or tightened. The runtime changeset and migration have parallel responsibilities but different lifetimes.
10. Migration tests prove a valid pre-discriminator row, an already-canonical row, empty content, every standard content variant, explicit structured null, metadata scrubbing, and fail-loud malformed content. Focused canonical tests prove complete-field preservation, open-field preservation, invalid Base64 rejection, invalid URI rejection, all model projections, and empty content.
11. Existing TODO persistence fixtures that supplied incomplete maps were corrected to complete results. The new boundary intentionally exposed stale fixtures rather than weakening validation or adding compatibility behavior to production.
12. Review found and corrected a migration coupled to mutable application code, missing invalid-Base64 proof, incomplete migration variant coverage, compound boolean style violations, cross-boundary references, and an overlong migration regex. The final focused independent review returned PASS.
13. Final accepted evidence is the server precommit gate with warnings-as-errors compilation, formatting, strict Credo, and all `739` server tests; the `116`-test MCP verifier; all `129` official examples; all `443` traceability requirements; the `30`-test source-comment gate plus repository scan; Changesets status; `git diff --check`; and final independent review.
14. `.changeset/canonical-persisted-tool-results.md` records the server-side migration slice without inventing a published-package bump. The existing framework and shared-contract changesets remain responsible for their own public package breaks.
15. The `2026-08-14` Phase 9 acceptance delta below subsequently completes decoded media and image-dimension limits, embedded-resource limits, invocation-time output-schema validation, bounded server JSON Schema 2020-12 validation, unsupported-dialect and no-external-resolver behavior, malformed-definition exclusion, and sensitive argument/error-message log redaction.

### 2026-08-14 Phase 9 Schema-Safety Acceptance Delta

1. BlueHotDog explicitly approved complete Phase 9 on `2026-08-14`. Approval covers canonical media/resource limits, durable invocation-time output-schema authority, bounded server JSON Schema 2020-12 validation, malformed-definition isolation, logging redaction, traceability and threat-model updates, the final verification evidence, and correction of every Phase 9 review finding.
2. `FrontmanServer.Tasks.CanonicalToolResult` now enforces at most `64` content blocks, `8,388,608` decoded bytes per media block and aggregate result, `8,388,608` UTF-8 bytes per embedded text resource, and `7,680` pixels per parsed image axis. Exact limits pass and the first unit over fails the whole peer result without partial persistence.
3. Canonical Base64 encoded length is checked before one bounded decode. Image and audio MIME families and complete RFC field-token media types are validated; JPEG, PNG, GIF, and WebP dimensions use the shared image parser when available.
4. The selected tool's `outputSchema` is snapshotted in the existing tool-call interaction JSONB data before dispatch, hidden from public interaction JSON, and reloaded from the locked durable row during completion. Catalog refresh, reconnect, caller mutation, and claim-token state cannot change the schema authority.
5. A missing or mismatched structured result does not strand a durable claim. The locked completion transaction stores one small canonical `Invalid MCP tool result` error and marks the exact claim generation complete; duplicate or late completion returns the same terminal result.
6. `FrontmanServer.JSONSchema` uses JSV's JSON Schema 2020-12 implementation with 2020-12 as the absent-dialect default. The server supports no additional dialect, rejects unsupported root or nested schema-resource dialects, and distinguishes schema-valued keywords from literal annotation objects.
7. Schema documents are bounded to depth `32`, `1,024` containers, and `100` milliseconds per compilation or instance-validation operation. Each operation runs in a monitored process; completion at `100` milliseconds is accepted, `101` milliseconds is timed out, and the timeout probe proves the worker is killed without a late completion message.
8. JSV receives no external resolver. Same-document references work, while HTTP, loopback, link-local, file, data, cross-document `$ref`, and `$dynamicRef` definitions fail closed without an outbound resolution implementation.
9. Custom-Phoenix catalog conversion compiles input and output schemas independently and excludes only the malformed tool while retaining valid siblings. Rejection logs include the tool name and a categorical reason, never the schema or argument values.
10. Backend malformed-argument and streamed-fragment logs no longer contain raw argument bytes or decoder diagnostics. Sentry no longer accepts the removed sensitive metadata keys; catalog and project-context protocol errors use fixed categories and focused secret-marker tests prove peer messages do not return through logs.
11. Final accepted evidence is warnings-as-errors server compilation, formatting, strict Credo, all `805` server tests, all `116` SwarmAI tests, the `116`-test MCP verifier, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, Changesets status, `git diff --check`, and independent final PASS review after every Phase 9 finding was corrected. The review also identified a pre-existing MCP owner ETS lifetime race outside this slice; approval did not absorb that defect into Phase 9, and accepted Phase 7 subsequently closed it as connection-owner fault work.

### 2026-08-14 Phase 9 Schema-Safety Lessons

1. An output schema is invocation data, not catalog state. Looking up the current catalog when a response arrives can validate an old execution against a new definition after reconnect or refresh.
2. Invocation data becomes authoritative only when it is durable. The selected `outputSchema` therefore belongs in the existing persisted tool-call JSONB record, not only in a pending request map or process-local catalog.
3. A claim token proves owner and generation; it must not carry mutable validation authority. Independent review caught an initial design where a caller could replace or remove the token's schema while retaining a valid generation. Completion now locks the exact durable row and reads `row.data.output_schema` from that authority.
4. The persisted schema snapshot is internal execution state. It must round-trip through claim updates and restart recovery but remain absent from public interaction JSON, ACP updates, model messages, and logs.
5. Invalid peer output still needs one durable terminal outcome. Returning a changeset error would leave the claim unresolved and repeatedly recoverable; canonicalizing the failure into one small error result completes the exact generation without retrying side effects.
6. Schema-document traversal and schema-location traversal are different operations. Depth and container accounting intentionally visits every object and array, including annotation values, while dialect checks recurse only through JSON Schema keywords whose values are themselves schemas.
7. Treating every nested map containing `$schema`, `$ref`, or `$dynamicRef` as a schema location is wrong. Literal objects under `const`, `enum`, `default`, or examples may legally contain those keys and must remain ordinary instance data.
8. No external resolver is safer and simpler than an SSRF-aware resolver when the product has no caller requiring remote references. JSV receives only its internal/meta-schema resolvers; external reference families fail closed before any network implementation exists.
9. A timeout around work in the caller process is not isolation. Server schema compilation and instance validation run in monitored processes so the owner can kill work after the immutable budget and suppress late completion.
10. Timer callback order is not the timing authority. Monotonic elapsed time decides the exact boundary: observed completion at `100 ms` wins, while `101 ms` loses even if scheduling delayed the timeout callback.
11. Resource limits can make otherwise ordinary tests load-sensitive. Focused schema tests run serially so unrelated async CPU saturation does not make simple valid schemas spuriously exceed the real production wall-clock budget; production remains intentionally fail-closed under actual saturation.
12. Base64 size preflight prevents oversized allocation, but it is not incremental decoding. Documentation must describe the actual implementation: canonical encoded length is checked first, followed by one bounded decode and canonical re-encoding check.
13. Per-block and aggregate media limits protect different attacks. A result can contain individually valid blocks whose sum exceeds the budget, so acceptance is all-or-nothing across image, audio, and embedded-blob bytes.
14. Embedded text needs its own UTF-8 byte limit because it does not consume the decoded binary-media budget. Character count would not enforce the frozen byte boundary for multibyte text.
15. Dimension checks apply only when the shared parser recognizes JPEG, PNG, GIF, or WebP headers. Unknown formats remain constrained by canonical Base64, MIME family, per-block bytes, and aggregate bytes rather than being mislabeled as having known safe dimensions.
16. MIME validation must implement the complete RFC field-token character set. A narrowed hand-written alphabet incorrectly rejects legal `%`, apostrophe, `*`, backtick, pipe, and tilde characters.
17. Catalog invalidity is per tool. One malformed input or output schema excludes that definition with a categorical warning while valid siblings remain usable; poisoning the complete browser catalog would turn one hostile definition into a denial of service.
18. Sensitive logging review must include sibling error paths, not only the obvious executor. Raw malformed arguments, decoder diagnostics, JSON-RPC catalog messages, and project-context error messages can all carry credentials or source content.
19. Removing a log call is insufficient when Sentry still allowlists the old metadata keys. Production emitters, logger metadata configuration, Sentry assertions, and secret-marker regression tests must change together.
20. Tests that persist a tool result without a live executor can accidentally resume the agent. The Sentry channel test initially passed while a background agent crashed; registering the exact waiter and asserting its terminal message made the lifecycle part of the test contract.
21. Boundary ownership matters even for a small helper. Bounded Base64 belongs under `ModelContextProtocol` because both protocol parsing and canonical persistence use it; exporting an internal server helper across a forbidden Boundary edge produced warnings-as-errors and exposed the ownership mistake.
22. A runtime dependency must be direct. Server-side JSV usage is declared in `frontman_server` even though another dependency already brought an older JSV transitively; relying on the transitive package would make the production validator accidental and version-unstable.
23. Green focused tests were not enough. Independent review found mutable schema authority, annotation-map false positives, incomplete MIME token grammar, peer-controlled sibling logs, a background test crash, stale documentation, and strict-Credo nesting after the first implementation passed its focused suite.
24. Semantic documentation searches remain an acceptance gate. Updating only the Phase 9 section left package checklists, historical forward references, status rows, traceability, threat-model prose, and implementation order claiming the work was still future.
25. Review findings outside the approved slice remain explicit rather than being silently fixed or absorbed. The observed `MCPConnection` ETS owner-death race predated this work, was unchanged by Phase 9, and accepted Phase 7 subsequently closed it through restart/process-loss fault handling.

### 2026-08-12 Canonical Persisted-Result Lessons

1. Wire latest-only policy and persisted-data compatibility are different boundaries. Frontman rejects missing `resultType` on modern wire messages but migrates valid historical rows once because shipped database data cannot be wished away by protocol policy.
2. Validation belongs in the Ecto changeset for every future write. A helper called from one producer is insufficient because browser, backend, timeout, cancellation, restart, and recovery paths all write tool results.
3. A migration must not call mutable application validation code. Freeze the accepted rules inside the migration so a fresh deployment remains executable after later refactors or stricter runtime policy.
4. Migration duplication is acceptable only at this immutable boundary. The live application still has one runtime validator and one canonical projection owner; do not create parallel current-runtime parsers.
5. Validate before persistence. Persist-before-notify protects durability only when the persisted value is safe to replay; otherwise one malformed durable row converts a transient producer defect into a permanent replay failure.
6. Canonical storage and consumer projection are separate concerns. Preserve the full protocol value in storage and ACP, then make model limitations explicit through deterministic lossy projection instead of narrowing the canonical result.
7. Unsupported binary content must not be decoded merely to create a model placeholder. Audio and blob projections omit bytes without dereferencing resources; image bytes are decoded only because the model runtime has a native image part.
8. Empty content is data, not absence. Truthiness and non-empty-list patterns incorrectly erased a valid result and prevented executor notification and historical reconstruction.
9. JSON null and an absent field are different protocol states. Bracket access collapses both to Elixir `nil`; use `Map.fetch/2` when downstream serialization must preserve explicit null.
10. Error state must survive historical reconstruction as well as live delivery. A canonical result is incomplete operationally if replay drops `isError` while the live path retains it.
11. Open protocol fields should survive canonicalization unless explicitly sensitive. Result `_meta` is scrubbed because it can contain credentials; unrelated open fields and content-block metadata remain protocol data.
12. Strengthening a real boundary should break stale tests that used impossible data. Correct fixtures to the canonical contract rather than adding fallback shapes or weakening validation.
13. Structural traceability and a green test suite do not replace semantic review. Independent review caught migration mutability, missing negative proof, style defects, and coverage gaps after the first implementation was green.

### 2026-08-12 Phase 3 Browser Streamable HTTP Client Delta

1. The user explicitly approved the Phase 3 core browser-client slice on `2026-08-12`. Approval covers the implemented `frontman-client` transport, the real loopback HTTP proof, the application compatibility build, documentation and changeset updates, and correction of every concrete independent-review finding. It does not accept all of Phase 3 or the complete product migration.
2. `FrontmanClient__Relay` remains the temporary application-facing module and type owner so existing provider, connection-reducer, update-banner, browser-test, and browser MCP-server consumers do not require an unrelated naming rewrite. Its private Relay wire behavior is removed: discovery, listing, and calls now send one complete JSON-RPC request per `POST /mcp`.
3. Every request emits complete modern `_meta`, `Content-Type: application/json`, the exact dual `Accept: application/json, text/event-stream` offer, `MCP-Protocol-Version: 2026-07-28`, `Mcp-Method`, method-selected encoded `Mcp-Name`, and recognized encoded `Mcp-Param-*` fields. Mandatory MCP fields overwrite caller-provided values so application configuration cannot weaken the protocol request.
4. Browser-safe `FrontmanClient__MCP__HeaderValue` preserves safe raw ASCII and uses the exact lowercase UTF-8/Base64 sentinel for Unicode, controls, edge whitespace, and literal sentinel-shaped values. Focused tests freeze raw ASCII, Unicode, padded text, and sentinel-collision behavior.
5. `server/discover` validates exact response correlation, requires `resultType: "complete"`, requires readable server identity, and verifies support for `2026-07-28`. The client does not use `serverInfo` for authorization, protocol selection, collision disambiguation, or any other security decision.
6. `tools/list` follows opaque cursors by presence rather than truthiness, so an empty string is sent as a valid continuation. It rejects repeated cursors, cursors over `4,096` UTF-8 bytes, more than `32` pages, more than `256` accumulated remote tools, inconsistent page cache scopes, one tool over `65,536` bytes, and an accepted catalog over `1,048,576` bytes without publishing partial state.
7. Discovery and list freshness are combined conservatively from the minimum TTL and anchored before network work so pagination cannot extend an earlier response's lifetime. The complete catalog cache lives inside one client instance whose endpoint and copied request-header configuration define one authorization context; stale data is revalidated only on demand and no polling loop exists.
8. `FrontmanClient__MCP__RemoteSchema` validates default JSON Schema 2020-12 and explicit draft-07 schemas with strict AJV and formats, registers the standard `x-mcp-header` extension explicitly, enforces structural depth `32` and count `1,024`, and supplies no network schema loader. Unsupported dialects, malformed schemas, unresolved external references, and over-limit schemas exclude only the affected remote tool while valid siblings retain order.
9. `FrontmanClient__MCP__CustomHeaders` recursively inspects the complete schema JSON, accepts annotations only along direct `properties` paths, enforces nonempty token names, case-insensitive uniqueness, and string/integer/boolean property types, omits absent and null values, and emits exact encoded values. Remote schema defects are hostile peer data and exclude one tool; unlike Frontman-owned server schemas, they do not crash the catalog.
10. Browser-local tools win exact-name collisions. The merged browser MCP catalog excludes a colliding remote definition instead of relying on spoofable `serverInfo.name`, silently executing the remote tool, or exposing duplicate names to the model.
11. Calls validate arguments against the selected remote input schema before sending any request. Complete call results validate through `CallToolResult.schema`; when an output schema exists, `structuredContent` must be present and conform even when its root is a string, array, number, boolean, or null. Unsupported result types, mismatched IDs, malformed envelopes, and missing terminal results fail locally.
12. A conforming HTTP `400` response carrying `HeaderMismatch` `-32020` remains parsed as a JSON-RPC response instead of being collapsed into a generic HTTP error. It invalidates the catalog, reruns discovery/listing, and retries the call exactly once; the recursive retry disables another relist so a repeated mismatch cannot loop.
13. `FrontmanClient__SSE` replaces private `event: progress/result/error` semantics with standard SSE `data:` messages validated through `StreamableHttpSseMessage`. It supports LF and CRLF delimiters, delimiters split across chunks, comments, multi-line data, strict split UTF-8 decoding, EOF-terminated final events, related notifications, exactly one correlated terminal response, and rejection of independent requests.
14. JSON and SSE response paths enforce the frozen `12,582,912` raw-byte limit before accumulation, strict UTF-8 decoding with an explicit final decoder flush, and JSON depth `64`. Exact media type/subtype matching rejects prefix lookalikes such as `application/jsonp`; permitted media parameters do not change the selected type.
15. Caller cancellation and the immutable ten-minute maximum are combined into one Fetch signal. Cancellation reaches Fetch and acquired stream readers, late results cannot update client state, and reader cancellation is initiated without awaiting an untrusted cancellation promise so cancellation rejection or nonsettlement cannot replace the selected terminal outcome.
16. The real loopback server test does not replace `fetch`. It proves `POST /mcp`, independent request IDs, exact standard and authorization headers, discovery, an empty-string continuation cursor, multi-page assembly, invalid-tool sibling exclusion, fresh reconnect cache reuse, JSON and CRLF SSE call responses, Unicode custom-header encoding, pre-send input rejection, output-schema validation, and an actual HTTP `400`/`-32020` relist followed by one successful retry.
17. The public client transport still exposes the existing optional progress callback by serializing accepted SSE notification JSON. No server progress capability is invented, and Frontman's own framework server continues to emit synchronous JSON until a real streaming producer exists.
18. `ajv` and `ajv-formats` are production dependencies of `@frontman-ai/frontman-client`. `.changeset/modern-mcp-browser-client.md` records a major release because browser-to-framework wire behavior changes from private Relay routes and custom SSE to latest-only Streamable HTTP.
19. The frozen core-slice checkpoint evidence was `95` passing tests across `9` `frontman-client` test files, clean package formatting, a complete `libs/client` build at `614` modules, all `116` MCP verifier tests, all `129` official examples, structural verification of all `443` normative requirements, the `30`-test source-comment gate plus repository scan, Changesets status, `git diff --check`, and independent review after every concrete finding was corrected. The approved worker-isolation delta below supersedes only the current client test and downstream build counts.
20. At this historical core-slice checkpoint, exact response/catalog/page/tool/cursor boundaries, response lifecycle races, authorization isolation, and installed E2E remained open. The approved `2026-08-13` transport-acceptance delta closes every listed transport and cache gate with `138` passing client tests, while installed application and complete WordPress/real-Playground E2E remain open. The approved WordPress endpoint and accepted source-level application consumers no longer need private server routes, but approval does not authorize deleting remaining JavaScript Relay routes before fixture/E2E cutover and repository-wide legacy removal.

### 2026-08-12 Phase 3 Worker-Isolated Schema Validation Delta

1. The user explicitly approved the Phase 3 worker-isolated schema-validation slice on `2026-08-12`. Approval covers browser remote-schema compilation, pre-send input validation, post-response structured-output validation, exact timing and lifecycle ownership, browser-bundle proof, Relay integration proof, documentation and changeset updates, and correction of every concrete independent-review finding. It does not accept all of Phase 3 or authorize remaining Relay deletion.
2. `FrontmanClient__MCP__RemoteSchemaEngine` owns the synchronous strict AJV operation and is reachable in production only from the dedicated module Worker. It retains default JSON Schema 2020-12, explicit draft-07, `ajv-formats`, registered `x-mcp-header`, structural depth and container limits, and no network schema loader.
3. `FrontmanClient__MCP__RemoteSchemaWorker` performs exactly one requested compilation or instance-validation operation and returns only success or a fixed failure string. Business orchestration, HTTP requests, catalog publication, retries, and model delivery remain outside the Worker.
4. `FrontmanClient__MCP__RemoteSchema` owns one Worker per operation. It measures monotonic elapsed time from before Worker construction, accepts a result observed at or before `100 ms`, terminates at `101 ms`, and terminates the Worker on success, invalid schema/value, timeout, cancellation, asynchronous Worker error, synchronous post failure, and synchronous setup failure after construction.
5. Caller cancellation is checked before Worker construction and again immediately before posting. The exact registered abort callback is removed during cleanup; the timeout is cleared; terminal settlement is idempotent; late Worker messages cannot replace the selected result.
6. Catalog compilation timeout, invalid schema, unsupported dialect, unresolved external reference, and Worker failure exclude only the affected remote tool while retaining valid siblings. Caller cancellation remains a connection-level terminal result rather than being mislabeled as one bad tool.
7. Input validation runs before custom-header construction and HTTP transmission. A timeout returns `Tool argument validation timed out`, and the real loopback test proves no `tools/call` request was sent.
8. Output validation runs only after one correlated complete tool response. A timeout returns `Tool output validation timed out`; it does not enter the `-32020` relist path, issue another discovery/list sequence, or repeat tool execution.
9. The structural count is explicitly every object and array container in the schema JSON document, including keyword maps and annotation values. Local `$ref` strings do not trigger another traversal. Focused engine proof accepts exactly `1,024` containers and rejects `1,025`; this replaces the earlier inaccurate shorthand that called the implementation a unique-subschema counter.
10. Controlled timing tests prove completion at `100 ms`, termination at `101 ms`, one termination after cancellation, ignored late completion, typed synchronous construction/post failures, and cleanup after post-construction setup failures. A pathological regular-expression validation times out while a zero-delay main-thread task still runs, proving the expensive operation is not executing on the browser event loop.
11. A Vite browser-consumer build imports the public compiled client module and proves bundling emits a separate Worker chunk containing the schema engine. The Node test Worker shim remains only the runtime bridge for unit and loopback tests; it is not the browser-bundle evidence.
12. Independent review found and corrected synchronous Worker construction/post failures escaping the typed result, an off-by-one structural-count acceptance bug, mismatch between documented unique-subschema semantics and actual JSON traversal, missing browser-bundle evidence, missing Relay no-send/no-retry integration proof, and cleanup gaps when setup failed after registering a listener or timer. The final focused lifecycle re-review returned PASS.
13. The existing `.changeset/modern-mcp-browser-client.md` now names worker-isolated schema validation in the same major browser-transport break rather than adding a second fragment for one unreleased migration.
14. Final serial evidence is `104` passing tests across `9` `frontman-client` test files, including the real loopback HTTP server, controlled Worker lifecycle vectors, pathological-pattern isolation, and Vite browser bundling; a clean `libs/client` build at `616` modules; all `116` MCP verifier tests; all `129` official examples; all `443` traceability requirements; the `30`-test source-comment gate plus repository scan; Changesets status; `git diff --check`; and final independent PASS review.
15. At this historical worker-slice checkpoint, Phase 3 remained unaccepted with transport and E2E gates open. The approved `2026-08-13` transport-acceptance delta closes exact response, page, tool, cursor, definition, catalog, idle, absolute-timeout, cancellation, terminal/late-result, authorization-isolation, adversarial-chunking, and stale-connect gates. Installed application E2E and complete WordPress/real-Playground vectors remain open.

### 2026-08-12 Phase 3 Worker-Isolation Lessons

1. Server-side argument validation and client-side validation protect different trust boundaries. The framework server protects itself before execution; the browser client protects its catalog, outbound side effects, model context, and event loop from framework-provided schemas and results.
2. The framework MCP server is usually local, but it is still outside the browser client's trust boundary. “Remote” means framework-provided through `/mcp`, not necessarily internet-hosted.
3. Schema validation does not prove that a tool is honest, authorized, or semantically safe. It proves declared structure, blocks malformed definitions and values, prevents implicit network `$ref` resolution, and bounds validator resource use.
4. Structural limits do not bound runtime complexity. A small schema can contain a catastrophically expensive regular expression, so synchronous AJV on the browser thread remains unsafe even when depth and container counts are bounded.
5. A timeout around main-thread validation is fake protection because the timer cannot run while validation blocks the event loop. The expensive operation must live in a terminable Worker.
6. One Worker per operation is simpler and safer than a shared mutable validator pool at this scale. It provides direct ownership, hard termination, no cross-request compiled-schema state, and straightforward cancellation at the cost of bounded startup overhead.
7. The timing authority is elapsed monotonic time, not timer callback order. A completion observed at `100 ms` succeeds; elapsed time over the boundary loses even if the timeout callback has not run yet.
8. Cancellation must be checked both before construction and before posting because an abort can occur while setup is registering handlers. Listener removal must use the exact callback reference.
9. Worker construction, handler assignment, timer creation, and `postMessage` can all fail synchronously. Lifecycle cleanup must exist before setup crosses those failure points; handling only `onerror` is incomplete.
10. Catalog cancellation and one-tool invalidity are different outcomes. Invalid or timed-out peer schemas exclude one tool, while caller cancellation stops the connection operation instead of silently publishing a partial catalog.
11. Input and output validation have different side-effect rules. Input failure must prevent transmission; output failure must be terminal and must never retry an already executed tool.
12. Test shims can prove lifecycle behavior but not browser packaging. A real browser bundler must prove that `new URL(..., import.meta.url)` emits the Worker and its AJV dependency graph as a loadable chunk.
13. Limit names are contracts. Calling a full JSON-container traversal a “unique subschema” count overstated the algorithm; the documentation and tests now name the implemented conservative container-node measurement exactly.
14. Parallel ReScript package clean/build commands corrupt shared generated artifacts in this workspace. Final evidence must remain serial until build outputs are isolated.
15. Independent review remains substantive. The first green suite missed synchronous failure escape, the count boundary defect, packaging evidence, integration evidence, and setup cleanup; each finding is now a permanent regression criterion.

### 2026-08-13 Phase 3 Transport Acceptance And Phase 6 Research Delta

1. BlueHotDog explicitly approved this session's Phase 3 transport-acceptance slice and the candidate Phase 6 no-DDL research direction. Phase 3 approval covers browser transport behavior, exact limits, lifecycle races, authorization isolation, documentation, changeset updates, and correction of every relevant review finding. It does not accept installed application E2E, complete WordPress/Playground E2E, JavaScript Relay deletion, or all of Phase 3. At this historical checkpoint, Phase 6 approval permitted controlled design validation but did not yet implement or accept persisted claim state, database code, schema changes, migrations, or durable ownership. The `2026-08-14` delta below supersedes that limitation.
2. Exact browser response limits now have real-loopback proof for both JSON and byte-split SSE. Raw responses of exactly `12,582,912` bytes proceed; `12,582,913` bytes cancel the reader and request-owned Fetch, publish no partial catalog, and leave the client in a terminal error state without caching.
3. Exact catalog limits now pass at their inclusive boundary and fail immediately beyond it: `32/33` pages, `256/257` accumulated tools, `4,096/4,097` UTF-8 cursor bytes, `65,536/65,537` compact bytes for one tool definition, and `1,048,576/1,048,577` accepted catalog-definition bytes across pages. Over-limit definitions exclude only that tool while preserving valid siblings; page, tool, cursor, response, and catalog failures publish no partial cache.
4. The loopback fixture generates exact-size definitions and response envelopes at runtime and checks their compact UTF-8 sizes before serving them. Large static fixtures were deliberately avoided so boundary intent remains visible and source control does not carry megabytes of opaque padding.
5. `FrontmanClient__MCP__ResponseBody` owns a monotonic `60,000 ms` response-idle deadline after response headers. A read observed at the exact deadline wins and resets the deadline; inactivity at `60,001 ms` cancels without awaiting an untrusted cancellation promise. JSON reads now consume the caller/request signal, release the reader, and clear every owned timer and abort listener on completion, cancellation, timeout, or failure.
6. `FrontmanClient__SSE` uses the same idle owner. Valid received chunks, including zero-byte chunks and SSE comment bytes, reset inactivity. Caller cancellation, idle timeout, terminal response, EOF, malformed data, and byte overflow converge on one terminal result; cancelled or terminal streams initiate reader cancellation without waiting for cancellation settlement, release the lock, clear timers, and ignore later chunks.
7. The browser outgoing absolute deadline no longer relies on opaque `AbortSignal.timeout` ownership. `FrontmanClient__Relay.post` owns an explicit monotonic `600,000 ms` deadline, one request `AbortController`, one terminal state, and clearable timer/listener references. A correlated terminal response committed at exactly `600,000 ms` wins; at `600,001 ms` the request returns `MCP request timed out`, aborts Fetch, and rejects late output. Caller abort remains the distinct `Request cancelled` outcome.
8. Response parsing and protocol failures now abort the request-owned Fetch signal after selecting their fixed local error. This closes the gap where the stream reader could stop while Fetch retained transport ownership. Real-server tests prove the peer observes client closure after timeout, caller cancellation, and an unsupported response media type.
9. Independent review found that repeated immutable-string appends and whole-buffer SSE rescanning made the nominally bounded 12 MiB response vulnerable to quadratic CPU and transient allocation under adversarial chunking. JSON now retains decoded chunks and joins once. SSE scans each decoded character once, retains at most the possible three-character delimiter suffix between chunks, and joins only one completed frame. Focused tests read `32,768` one-byte JSON chunks and one terminal SSE frame split across `32,768` one-byte chunks.
10. Independent review also found that an older asynchronous `connect` could overwrite state or cache after `disconnect` or after a newer connection attempt. Each Relay instance now owns a monotonically increasing connection generation and the current connection controller. A new connect aborts and supersedes the old generation; disconnect invalidates and aborts pending work; every post-await state/cache write proves current generation ownership. Controlled real-server tests prove disconnect cannot reconnect later and the newest concurrent attempt alone owns final state and cache.
11. Authorization isolation now has two-client real-server proof rather than only structural reasoning. Each client copies its request headers during construction, owns a separate in-memory cache, receives an authorization-dependent private catalog, and reuses only its own fresh cache. Mutating the original caller dictionaries after construction cannot alter either authorization context, and no catalog or response crosses clients.
12. The final client evidence is `138` passing tests across `10` `frontman-client` test files, including real-loopback exact boundaries, controlled response lifecycle, Worker lifecycle, browser bundling, adversarial chunking, stale-connect fencing, and authorization isolation. Package formatting and build pass. The shared real-process JavaScript framework MCP matrix passes all `12` tests. The `30`-test source-comment suite plus repository scan, Changesets status, and `git diff --check` pass.
13. Installed Vite application E2E could not start locally because `test/e2e/.env` is absent and the Make target fails before Vitest. The session initially drafted framework-unavailable and same-page offline tests, but independent review correctly rejected editable/visible textbox assertions as insufficient proof of browser-tool usability or ACP reconnection. Those tests were removed rather than accepting checkbox theater.
14. Installed acceptance therefore remains explicit: it needs real evidence that ACP stays usable when framework MCP fails, a post-reconnect server interaction on the same page, deterministic question replay/completion where applicable, complete WordPress browser vectors, and an actual WordPress Playground runtime. A scoped Apache WordPress path is useful routing evidence but is not Playground E2E.
15. Phase 6 research rejected a new claim table as unnecessary at the current design stage and rejected every lock-only substitute as complete durable authority. Transaction row locks and transaction-scoped advisory locks remain useful serialization components, but they do not by themselves preserve owner generation, database-time lease, dispatch ambiguity, cancellation/terminal state, takeover fencing, or transactional result completion after the transaction ends.
16. The candidate no-DDL design stores a declared namespaced claim object in the existing tool-call interaction JSONB value and uses short atomic compare-and-set transactions keyed by the interaction UUID. The claim needs owner connection identity, generation, database-time lease expiration, dispatch state, terminal/resolution state, and replay policy. Recovery must retain the interaction UUID instead of returning only decoded tool-call data.
17. Review found two constraints that prevent claiming this design is already proven. First, `InteractionSchema.data` is a typed polymorphic embed; undeclared raw JSONB keys disappear from typed loads and can be lost by a later full embed dump, so claim state must be declared in `Interaction.ToolCall`. Second, only tool-result logical identity is uniquely indexed; duplicate tool-call rows could each win a UUID-scoped claim. Without an approved tool-call unique index, creation/acquisition must serialize the logical task/turn/tool-call identity and fail loudly unless exactly one row exists.
18. Adding a claim object to the existing JSONB column avoids database DDL but still changes persisted row shape, backup/export expectations, and the application embed type. BlueHotDog approved the candidate direction in this session; management approval and controlled concurrency/round-trip proof remain required before implementation. No database code, schema, migration, index, table, column, or data changed in this session.
19. Non-idempotent takeover remains inherently ambiguous when a former owner may have begun an external side effect. A successor must not automatically resend unless durable state proves dispatch never began or the selected tool has a verified idempotency guarantee bound to the preserved durable tool-call identifier. Ambiguous calls require explicit user resolution.
20. Independent review found one separate custom-Phoenix resource-bound risk outside Phase 3: `FrontmanClient__MCP` removes a cancelled call from its `256`-entry active registry before aborting it. A tool that ignores AbortSignal and never settles can therefore continue consuming resources while repeated start/cancel cycles admit more work. Phase 4 response ownership remains correct, but its execution-resource bound needs a follow-up owner that retains cancelled-but-unsettled work in the capacity accounting or otherwise terminates it.

### 2026-08-13 Phase 3 Transport And Durable-Ownership Lessons

1. A byte limit bounds retained payload size, not CPU complexity. Immutable append and repeated full-buffer scanning can turn a bounded response into quadratic work; adversarial one-byte chunk tests belong beside byte-limit tests.
2. Idle timeout and absolute timeout need separate owners. Activity resets only the idle deadline; it must never extend the immutable absolute request deadline.
3. The exact deadline rule requires monotonic post-read and post-response checks, not faith in timer callback order. Work observed at the inclusive boundary wins; work observed beyond it loses even when the timer callback has not yet run.
4. Native timeout signals are convenient but hide timer cleanup and terminal-reason ownership. An explicit timer, controller, listener, and terminal variant make exact cancellation-versus-timeout proof possible.
5. Cancelling a stream reader is not necessarily aborting Fetch. Parser-owned response failures must also abort the request-owned controller after fixing the selected local outcome.
6. Never await untrusted cancellation merely to settle local ownership. Initiate cancellation, observe rejection, release local locks, and let the selected timeout/cancellation outcome return even if the underlying cancellation promise never settles.
7. Cache isolation is a behavioral security property, not an inference from object construction. Use two private authorization contexts, mutate caller-owned input after construction, reconnect while fresh, and prove separate requests, catalogs, and cache reuse.
8. Async connection attempts need generation ownership just like JSON-RPC requests need IDs. Disconnect is not terminal if an older promise can later publish Connected, and a newer successful attempt is not authoritative if an older failure can overwrite it.
9. Exact generated boundary fixtures are better than giant checked-in blobs. Generate compact values, assert their actual byte size in the fixture, and then exercise the real transport.
10. Installed E2E must prove a post-failure product operation. DOM visibility or editable local text does not prove ACP reconnection, browser-tool availability, or session usability.
11. WordPress scope emulation and WordPress Playground are different environments. Do not upgrade path-shape evidence into runtime compatibility evidence.
12. JSONB avoids DDL, not persistence governance. New durable keys still change stored data contracts and typed application ownership.
13. A typed polymorphic embed is not an open JSON map. Raw SQL can preserve undeclared keys temporarily, but typed loads omit them and later dumps can erase them; durable state must have an explicit typed owner.
14. UUID row identity and logical tool-call identity solve different problems. Atomic CAS on one UUID is insufficient if duplicate logical rows can exist and claim independently.
15. Locks are implementation tools, not durable state. Use short locks to serialize CAS or duplicate detection, but do not hold pooled connections across browser execution or claim that session loss detection implements the frozen lease contract.
16. Lease takeover is not replay permission. Dispatch ambiguity and tool-level idempotency determine whether a successor may send again.
17. A correlation bound is not automatically an execution-resource bound. Removing terminal response ownership before uncooperative work settles can preserve wire correctness while allowing unbounded retained execution.
18. Independent review should be allowed to reopen assumptions after a green suite. This session's reviews found request-owned Fetch leakage, quadratic response processing, stale connection writes, weak E2E proof, polymorphic-embed loss, duplicate logical claim risk, and the custom-Phoenix cancellation-capacity gap.

### 2026-08-14 Phase 4 Capacity Closure And Phase 6 Acceptance Delta

1. BlueHotDog explicitly approved the completed Phase 4 hard execution-capacity follow-up and Phase 6 durable execution ownership on `2026-08-14`. Phase 4 is accepted with a hard underlying-execution bound. Phase 6 is accepted for Frontman's supported single-node Phoenix deployment. Accepted Phase 7 subsequently implements the restart-recovery architecture, and its later explicitly approved release hardening closes the recorded direct fault-injection work; distributed, multi-node, and cross-node Phoenix acceptance are out of scope.
2. One browser MCP handler now owns at most `256` underlying durable executions, including cancelled tools that ignore `AbortSignal` until their promises settle. Removing one JSON-RPC waiter no longer releases execution capacity. Repeated start/cancel cycles therefore cannot retain more than the hard bound, and admission fails closed at `257`.
3. Structurally identical requests with a new JSON-RPC ID join one execution by exact `{taskId, toolCallId}` identity and receive the same terminal result. Changed payloads fail deterministically. Canonical request identity sorts object keys, preserves array order and primitive distinctions, and rejects unsupported `inputResponses` or `requestState` before execution.
4. Browser replay state is finite without permitting eviction-based re-execution. One handler retains at most `4,096` durable identities and `1,048,576` aggregate UTF-8 bytes of keys plus canonical fingerprints. It separately caches at most `256` completed results and `1,048,576` aggregate result bytes. Result eviction or oversize preserves a tombstone; reaching either durable-identity bound rejects unseen work until detach instead of forgetting authority.
5. Phase 6 stores a declared `execution_claim` embed in the existing tool-call interaction JSONB value. The claim records globally unique connection ownership, positive generation, database-time lease expiry, claimed/started dispatch state, unresolved/completed/cancelled resolution state, and verified-idempotent/non-idempotent replay policy. No claim table, column, index, constraint, or migration was added.
6. Tool-call creation and claim acquisition serialize the logical `{task_id, turn_number, tool_call_id}` identity through a short task-row lock, then lock the exact interaction UUID. Acquisition fails loudly unless exactly one logical row exists. This closes the defect where two duplicate logical rows could each win independent UUID claims.
7. Claims last exactly `60,000 ms` and renew every `20,000 ms` using PostgreSQL `clock_timestamp()`. The current owner remains authoritative through the exact expiration instant; takeover begins immediately after it. Independent PostgreSQL backend and pool connections prove one winner, exact boundaries, renewal, generation increment, stale-owner fencing, and no pinned connection or long-running transaction.
8. Dispatch intent is persisted before the browser push. A crash after that durable transition is conservatively ambiguous even if the bytes never reached the browser. Expired non-idempotent started work becomes one canonical terminal ambiguity instead of automatic replay; only never-started or verified-idempotent work may be reclaimed automatically.
9. Canonical result insertion and claim completion or cancellation occur in one transaction. Graceful connection teardown durably cancels each owned started call before unregistering the live owner. Abrupt loss retains lease/generation authority. Former generations cannot renew, cancel, complete, or persist a late browser result.
10. Review found and corrected two legacy bypasses after the first green implementation. Agent pause/termination paths had still called unrestricted result persistence, which could insert a result while leaving the claim unresolved. Those paths now terminalize a current claim atomically and preserve the legacy path only for genuinely unclaimed/backend work. A recovery timer that fired after another owner completed had treated `already_resolved` as fatal; terminal persistence is now a benign recovery outcome rather than a channel crash.
11. Typed round-trip proof loads, updates, dumps, and reloads the claim through the polymorphic embed while preserving every tool-call field. Public interaction JSON deliberately omits internal claim owner, generation, lease, and replay state. Raw undeclared JSONB keys remain forbidden because typed loads and later dumps cannot safely own them.
12. The final independent targeted review returned PASS after the legacy persistence bypass, resolved-recovery race, and unbounded tombstone-fingerprint memory finding were corrected. The implementation limits, threat model, custom transport specification, Phase 6 research record, and owning changeset now describe the implemented behavior.
13. At this historical checkpoint, serial evidence was: server `790`; frontman-client `151`; frontman-core `477`; client `331`; Next.js `194`; Astro `66`; Vite `7`; Astro-browser `6`; React statestore `4`; logs `11`; SwarmAI `116`; marketing `28`; MCP verifier `116`, all `129` official examples, all `443` requirements, and the `10,000`-case property profile; source gate `30`; WordPress `1,167` core assertions plus WordPress `7.0.2` runtime and MCP HTTP runtime; and the shared framework black-box matrix `12`.
14. At this historical checkpoint, installed application E2E was blocked because `test/e2e/.env` was absent and notifier Hex dependencies were unavailable. The later `2026-08-20` acceptance records passing credentialed E2E and the aggregate; notifier dependencies were also refreshed and notifier lint/test added to root aggregate ownership. ReScript package tests remain serial because parallel clean/build commands share generated artifacts.

### 2026-08-14 Installed Recovery And WordPress Playground Delta

1. BlueHotDog explicitly approved the no-secrets installed-recovery test design, expanded real WordPress Apache contract, genuine WordPress Playground scoped-runtime matrix, Next trace exclusion, CI wiring, and this session record on `2026-08-14`. Approval accepts the applicable WordPress and Playground transport evidence. It does not accept the provider-backed installed JavaScript application gate, all of Phase 2 or Phase 3, Relay deletion, official conformance, or the complete migration.
2. Installed Next.js, Astro, Vite, and Vue-Vite application tests now fail exact browser `POST /mcp` discovery deterministically, force the live ACP Phoenix socket offline, require a replacement socket and enabled editor on the same page, plant a random value inside the preview, and require `execute_js` to recover that value and write it into the framework source file. This preserves the prior real source-edit operation while proving that a post-failure result cannot come from a DOM-only assertion or a value present in the prompt.
3. The recovery marker is generated with `randomUUID`, inserted only into the preview DOM after ACP reconnect, and omitted from the prompt except as a request to read the named dataset field. The final source assertion therefore proves a post-reconnect browser-tool read and provider-driven write rather than prompt echo, static fixture knowledge, or a local textbox operation.
4. The installed Vite run locally reached failed MCP discovery, ACP disconnect/reconnect, replacement-socket observation, editor recovery, random preview-marker insertion, and the provider-backed operation boundary. It then stopped because no provider token is seeded. The final random tool/source operation remains an execution gate until `test/e2e/.env` supplies valid provider credentials; the application path is not marked accepted from this partial run.
5. The real WordPress `7.0.2` Apache runtime now runs the same applicable contract at both root and literal `/scope:frontman-runtime` site bases. It proves exact routing and alias rejection, Origin/authentication/nonce precedence, Origin-only preflight, HTTP method and media policy, discovery, deterministic private one-page catalog, filesystem-tool absence, `wp_get_site_info` execution, cursor rejection, mirrored-header mismatch, unknown methods, malformed JSON, and private Relay-route absence.
6. A pinned `@wp-playground/cli` fixture mounts and activates the packaged plugin in a genuine PHP/WASM WordPress Playground runtime at `/scope:frontman-playground`. It uses WordPress `7.0`, PHP `8.4`, and one worker, logs in through the real WordPress form rather than CLI auto-login, follows scoped redirects while retaining cookies, obtains the MCP nonce from the authenticated Frontman page, and sends real HTTP requests to the scoped `/mcp` endpoint.
7. The Playground matrix has three groups: exact authenticated scoped routing/discovery and alias rejection; Origin, session, nonce, preflight, method, and media policy; and deterministic catalog, filesystem-tool exclusion, successful execution, cursor rejection, mirrored-header mismatch, unknown-method handling, and malformed-JSON handling. It preserves wide safe numeric IDs and checks private discovery cache metadata.
8. Playground startup owns a 120-second readiness bound and captures child output for failures. Teardown sends `SIGTERM`, waits up to five seconds for actual exit, escalates to `SIGKILL`, and awaits exit before returning. This prevents a surviving PHP/WASM process or occupied port from contaminating later vectors.
9. WordPress buffered-body behavior, hosting-owned read deadlines, and lack of PHP-side disconnect cancellation remain explicit adapter limits rather than silently skipped JavaScript chassis claims. The applicable contract is intentionally shared by behavior, not by pretending PHP implements Node Web Streams.
10. Next trace capture now suppresses exact public `/mcp` and generated `/api/frontman-mcp` spans. Focused proof retains nearby non-MCP paths so the exclusion cannot broaden into hiding unrelated application traffic.
11. The no-secrets `mcp-blackbox` CI job installs immutable dependencies, rebuilds the publishable adapters and packaged WordPress plugin through `make mcp-blackbox`, runs the real-process matrix, and cleans the three JavaScript framework ports plus the Playground port. Its path ownership includes client, protocol, core, adapters, WordPress, server, SwarmAI, MCP documentation, root Makefile, lockfile, and workflow changes.
12. After one documented stale shared ReScript artifact failure and a clean serial rebuild, `make mcp-blackbox` passes `15/15`: the existing `12` real-process Next.js/Astro/Vite tests plus `3` genuine WordPress Playground scoped-runtime groups. The expanded real WordPress Apache runtime passes at root and scoped paths. The focused Next span-processor suite passes `17/17`.
13. The approval boundary is deliberately asymmetric. WordPress and Playground protocol evidence is complete for the documented applicable vectors without provider credentials; installed Next.js/Astro/Vite/Vue-Vite application recovery still requires the random post-reconnect browser-tool/source edit under a real provider account. A transport matrix cannot substitute for that application operation, and a partial local run cannot substitute for its terminal assertion.

### 2026-08-14 Installed Recovery And Playground Lessons

1. An editable textbox after reconnect proves only local UI state. Installed recovery needs a post-reconnect operation that crosses ACP, invokes a browser tool, reaches the provider-backed agent, and changes real framework source.
2. A marker already present in the prompt is weak evidence because the model can echo it without using the requested tool. Generate the marker randomly, place it only in browser state after reconnect, and require the tool-derived value to appear in source.
3. Socket recovery must prove replacement ownership, not merely an open connection. Observe the original Phoenix socket close, then require a newly emitted matching socket before accepting the editor as recovered.
4. Deterministic framework MCP failure should target the exact public `POST /mcp` request. Broad network failure conflates optional framework-tool availability with ACP availability and cannot prove the application domains remain independent.
5. Provider credentials are an acceptance dependency, not a reason to weaken the assertion. When local credentials are absent, run to the provider boundary, record the blocker exactly, and leave the terminal application gate open.
6. A scoped Apache path is not WordPress Playground. Genuine Playground proof requires the PHP/WASM runtime, its scoped router, real plugin mounting and activation, real login cookies, and a nonce obtained through the rendered authenticated application.
7. Authentication helpers must own redirects and cookie rotation explicitly. Relying on CLI auto-login or a synthetic nonce bypasses the session behavior the MCP endpoint is meant to protect.
8. Shared black-box contracts need an applicability model. Assert common externally visible protocol behavior, but name PHP buffering, hosting deadlines, and disconnect limitations rather than silently skipping them or claiming nonexistent Node chassis parity.
9. Runtime teardown is part of test correctness. Signaling a child and returning immediately leaves ports, files, and output races behind; wait for exit and use bounded escalation.
10. Package and adapter black-box tests must rebuild what consumers execute. Shared ReScript artifacts can become stale or race under parallel builds, so clean serial rebuilds remain authoritative until generated outputs are isolated.
11. Trace exclusions need exact-path positive and nearby-path negative proof. Suppressing all similarly named routes would trade noisy telemetry for an observability blind spot.
12. Approval scopes should separate transport evidence from application evidence. A genuine runtime can close routing, security, and protocol gates while provider-backed agent behavior remains independently open.

### 2026-08-14 Durable Ownership Lessons

1. Existing JSONB storage avoids DDL but not type ownership. Durable keys must be declared in the embed or typed round trips can erase them.
2. Interaction UUID and logical tool-call identity enforce different invariants. UUID CAS fences one row; task-row serialization prevents duplicate logical rows from becoming separate authorities.
3. Persisting a claim is insufficient unless every terminal path uses it. Pause, timeout, cancellation, malformed response, graceful teardown, and ordinary completion must converge on one generation-fenced transaction.
4. Result uniqueness is a final persistence invariant, not execution authority. It cannot undo duplicate side effects that occurred before either result was inserted.
5. Marking dispatch before send intentionally prefers a possible false ambiguity over duplicate non-idempotent execution. Without tool-level idempotency, no ordering removes that uncertainty.
6. Graceful and abrupt loss have different evidence. Graceful teardown can transactionally cancel owned work; abrupt loss must rely on lease expiry, generation fencing, and conservative replay policy.
7. A recovery retry must recognize that another owner may have completed while it waited. `already_resolved` is terminal success for recovery, not an invariant crash.
8. A JSON-RPC waiter bound is not an execution bound. Abort-ignoring work must remain charged until actual settlement.
9. Bounded replay caches need fail-closed tombstones. Evicting the only memory of a completed durable key converts memory pressure into duplicate execution.
10. Count bounds without byte bounds are incomplete. Canonical request fingerprints and cached terminal results each need independent aggregate UTF-8 budgets.
11. JSON stringification is not structural equality for objects. Replay matching must ignore object insertion order while preserving semantically meaningful array and primitive distinctions.
12. Unsupported optional protocol fields must fail before deduplication or execution. Omitting them from a replay fingerprint can incorrectly join materially different requests.
13. Deployment scope belongs in acceptance criteria. Frontman supports one Phoenix node, so independent PostgreSQL connection contention is relevant proof while distributed Erlang node acceptance is not.
14. Green focused suites do not prove architectural closure. Independent review found legacy bypasses, a normal resolved-recovery race, and an unbounded-memory path after the initial implementation passed.
15. Verification tooling has its own concurrency model. Shared ReScript generated artifacts require serial package builds until outputs are isolated; parallel failures are not authoritative product failures.

### 2026-08-13 Application Consumer Cutover Delta

1. The user explicitly approved the source-level application consumer cutover on `2026-08-13` after focused independent review returned PASS. Approval covers application readiness, callback termination, React context ownership, browser-local question waiter lifecycle, standard browser-tool metadata, Astro audit schema/result proof, plan/checklist updates, and the owning package changesets. It does not accept all of Phase 3, authorize JavaScript Relay deletion by itself, or claim transport-correlated custom-Phoenix cancellation or installed E2E.
2. ACP application readiness is now independent of framework MCP discovery. An unavailable `/mcp` endpoint remains framework-tool unavailability but no longer becomes the application's ACP connection error, clears an otherwise healthy ACP facade, or prevents browser-local session creation and task loading. This makes the existing “nonfatal” framework failure policy true in behavior rather than only in logging.
3. Session creation no longer requires `RelayConnected`; it requires the authenticated ACP connection, browser MCP server interface, and valid ACP session state. Framework discovery continues independently and can enrich the browser MCP catalog later without owning ACP readiness.
4. Rejected create, load, and prompt requests now invoke their supplied callbacks with terminal errors instead of only logging and leaving UI callers pending. Create and load parse failures retain their failure authority: if the underlying ACP operation later returns a nominal session, that stale session is cleaned up and cannot replace the earlier parse failure with success.
5. React context no longer exposes the temporary `Relay.t` transport/client object. `Client__FrontmanProvider` exposes only optional discovered framework server identity, and `Client__UpdateBanner` consumes that product datum for installed-version checks. Transport construction, connection state, cache, and teardown remain private to the provider/reducer boundary.
6. ACP remains the carrier for browser MCP messages. Each current ACP task session supplies `MCPServer.toInterface` to the custom-Phoenix dispatcher; a validated `tools/call` extracts explicit `taskId` and durable `toolCallId` from `ai.frontman/execution-context`, selects the browser-local `question` tool, and awaits its complete `CallToolResult` before the dispatcher sends the correlated response on the Phoenix channel.
7. The question tool still uses one promise per invocation, but task state now stores an array of waiter callbacks under one pending question. A replay joins the existing waiter set only when both the durable tool-call ID and complete question payload are identical. Every joined waiter receives the same answer or terminal error, so reconnect redispatch cannot overwrite or orphan the original promise.
8. A different tool-call ID, or the same ID with a changed question payload, is rejected with the fixed local category `Another question is already pending`. The active question and its existing answers remain untouched. This distinguishes an exact replay from an ID collision or malformed replay rather than treating every matching ID as equivalent.
9. Answer, per-question skip, skip-all, and normal submission build one structured output and resolve every waiter exactly once. User question cancellation and turn cancellation reject every waiter, clear pending UI state, and also delegate ACP `CancelPrompt` so agent-turn cancellation remains coordinated with local promise settlement.
10. Agent errors reject pending question waiters with the agent error, including questions restored while `isAgentRunning` is false. ACP connection loss, task clear, and task deletion route through the same reasoned `QuestionTerminated` reducer path and reject every waiter before state is discarded. No cleanup path silently drops resolver callbacks.
11. At this application-slice checkpoint, incoming custom-Phoenix MCP `notifications/cancelled` remained schema-validated but uncorrelated. Accepted Phase 4 subsequently correlates the exact request, aborts browser execution, terminates question waiter state, and suppresses late responses; connection-wide and durable ownership remain Phase 5-7 work.
12. Browser tool serialization now emits standard `annotations.readOnlyHint` derived conservatively from internal access policy: read tools advertise `true`; write and read/write tools advertise `false`. Private `access`, `visibleToAgent`, and `executionMode` fields remain absent from MCP `Tool` definitions.
13. The Astro audit tool already used the shared modern structured-result constructor, so no duplicate constructor was added. Focused proof now validates `resultType: "complete"`, structured audit output, absent error state, object-rooted input schema, output-schema eligibility, registry access/visibility/execution policy, and standard read-only MCP metadata.
14. `.changeset/modern-mcp-application-cutover.md` records a major `@frontman-ai/client` change for readiness and interactive-question lifecycle. The existing major `@frontman-ai/frontman-client` changeset now includes standard browser-tool annotations. The private `@frontman-ai/astro-browser` package receives tests but no standalone release fragment.
15. Review found and corrected rejected prompts without terminal callbacks, load/join parse errors that could be overwritten by later nominal success, idle reconnect questions ignored by `CancelTurn`, agent errors that left question promises pending, same-ID changed payloads incorrectly joining the active waiter set, and task clear/delete paths that discarded question ownership. Final targeted re-review returned PASS.
16. Final focused evidence is `331` passing client tests, `104` passing frontman-client tests, `6` passing Astro-browser tests, a clean root ReScript build, focused ReScript formatting, `git diff --check`, and independent PASS review. The first parallel package verification attempt also confirmed that package clean/build targets share generated artifacts and must run serially; the failures were build-output races, not product failures.

### 2026-08-13 Application Consumer Cutover Lessons

1. Optional framework tools and core ACP application readiness are different availability domains. A framework `/mcp` outage must remove remote tools, not disable authenticated ACP chat or browser-local tools.
2. “Nonfatal” is a behavioral contract. Logging a failure as nonfatal while selectors, facades, and session guards treat it as fatal is worse than an honest hard failure because tests and operators receive contradictory signals.
3. Every callback-based reducer rejection needs a terminal callback effect. Logging-only fallback clauses leave UI promises pending and turn a state race into an invisible hang.
4. Parse failure must remain authoritative after asynchronous work returns. A callback can observe malformed session traffic before the join/create promise resolves; later nominal success must clean up the session rather than overwrite the established error.
5. React context should expose product data, not transport ownership. The update banner needs framework name/version, not access to client state, cache, request headers, or disconnect methods.
6. ACP is the application/session carrier, while MCP defines the browser tool request and response. Keeping those roles separate prevents ACP session lifecycle from being mistaken for MCP protocol sessions or framework HTTP readiness.
7. Durable tool-call identity alone is insufficient replay proof. The complete immutable request payload must also match before another waiter can join an in-flight operation.
8. Reconnect safety requires retaining all legitimate waiters, not replacing the old waiter with the newest one. Replaying one logical call can produce multiple local promises that must share one terminal outcome.
9. UI cleanup is execution cleanup only when it settles the underlying promise. Clearing `pendingQuestion` without invoking every waiter leaks browser MCP work even if the drawer disappears correctly.
10. Cancellation has layers. Local waiter settlement prevents promise leaks; ACP `CancelPrompt` stops the agent turn; accepted Phase 4 custom-Phoenix cancellation correlates and aborts one browser request; later durable cancellation must prevent redispatch. One layer must not be documented as proof for another.
11. A restored question can be pending while `isAgentRunning` is false. Cancellation guards must inspect pending interactive work directly rather than using the broader agent-running flag as a proxy.
12. Agent error, disconnect, task clear, and task deletion are all terminal owners for an interactive call. Routing them through one reasoned termination action avoids subtly different leak behavior across cleanup paths.
13. Standard MCP annotations are the wire projection of internal policy, not permission enforcement. `readOnlyHint` informs clients and models; actual authorization and execution policy remain internal.
14. Shared modern constructors should be proven, not reimplemented. The Astro audit tool already emitted complete modern results; the correct migration work was stronger schema/result/metadata evidence.
15. Parallel package clean/build commands are unsafe while packages share generated ReScript artifacts. Verification must remain serial until build outputs are isolated.
16. Focused independent review is valuable after a green suite. The initial tests missed callback termination, stale-success races, idle-question cancellation, agent-error leaks, changed-payload replay, and task-removal leaks; each is now a permanent regression criterion.

### 2026-08-13 Phase 4 Custom-Phoenix Transport Acceptance Delta

1. The user explicitly approved Phase 4 on `2026-08-13` after focused implementation review, correction of every Phase 4 finding, serial verification, and final independent re-review. Phase 4 is accepted for browser request lifecycle on the current custom Phoenix transport. It does not move ownership into connection-wide `TasksChannel`, add durable execution claims, make task cancellation durable when no executor is running, or accept installed application E2E.
2. `FrontmanClient__MCP` is now a stateful transport owner rather than a stateless async dispatcher. One handler owns an active flag, its exact Phoenix listener reference, and a dictionary capped at `256` correlated `tools/call` response owners. Later review found that cancellation removes correlation before uncooperative execution settles, so this historical checkpoint does not prove a hard `256` retained-execution bound.
3. Each accepted call receives one `AbortController`. `notifications/cancelled` parses the exact shared string-or-safe-integer request ID, removes that active entry before aborting, and therefore makes cancellation terminal before synchronous abort listeners or later promise completion can run.
4. Tool execution receives the exact request signal through the shared browser-server interface. Browser-local tools accept the signal, remote framework execution passes it into the existing Streamable HTTP client, and the interactive `question` tool terminates its reducer-owned waiter state when transport cancellation fires.
5. Completion sends a response only when it atomically removes the same active request object. Cancellation, detach, or replacement of ownership therefore suppresses both late success and late exception responses without awaiting untrusted work.
6. Detach marks the handler inactive before aborting work, removes only the exact listener reference returned by Phoenix `Channel.on`, aborts all handler-owned calls, empties the registry, and fences outgoing pushes. ACP session cleanup no longer calls broad `off("mcp:message")` and cannot remove another listener on the channel.
7. Duplicate active IDs do not start a second execution and do not abort the original. Requests of another method and malformed request-like messages carrying an active call ID are ignored rather than emitting a competing terminal response. The original call remains the sole response owner.
8. The browser one-page server rejects every supplied `tools/list` cursor by presence, including the empty string. Hidden browser tools are filtered before serialization, local/remote tools are sorted by exact case-sensitive name, and internal visibility or execution policy is not emitted.
9. Attachment resolution no longer branches on `write_file` or `wp_upload_media` names. Framework tools advertise `ai.frontman/attachment-resolution` in standard tool `_meta`; version `1` names the reference, content, encoding, encoding value, removal policy, and optional media-type arguments. The browser validates that metadata, resolves only within explicit task context, copies arguments, and fails closed on malformed or unsupported owned metadata.
10. Core `write_file` and WordPress `wp_upload_media` publish their exact metadata policies. Focused browser loopback proof shows a tool with an arbitrary name and arbitrary documented argument names receives resolved bytes, proving metadata rather than hidden naming activates the behavior. WordPress proof compares the complete metadata value rather than one field.
11. The temporary Phoenix `TaskChannel` now propagates ACP cancellation to every currently pending runtime MCP request. It snapshots pending correlation, publishes the empty pending map before pushing `notifications/cancelled`, and therefore rejects a late browser result as unknown instead of persisting it.
12. At this Phase 4 checkpoint, temporary `TaskChannel` cancellation deliberately left the durable unresolved tool call intact. That preserved reconnect behavior but allowed cancellation with no running executor to redispatch later. Accepted Phase 5 subsequently removed the temporary owner and added process-local cancellation/deadline authority; accepted Phase 6 owns durable claim, cancellation/completion, generation, and replay state; accepted and release-hardened Phase 7 owns durable deadlines and the approved single-node recovery architecture.
13. `docs/mcp/custom-phoenix-transport.md` defines connection/auth inheritance, one-message framing, directions, per-request stateless metadata, ordering, exact ID correlation, the `256`-call correlation bound, the absence of an additional time-window rate limiter, cancellation, teardown, replay identity, and attachment-resolution fallback behavior. A later follow-up must align its capacity language with cancelled-but-unsettled execution accounting.
14. `.changeset/modern-mcp-phoenix-transport.md` records the public protocol, frontman-client, client, core, and WordPress package impact. Changesets status resolves overlapping migration fragments to the repository's aggregate major release set.
15. Focused final evidence is all `110` frontman-client tests across `9` files, all `6` Astro-browser tests, the focused core registry suite at `6` tests, the focused Phoenix cancellation test, the WordPress media runner at `22` assertions, serial ReScript builds for frontman-client/client/core/Astro-browser, ReScript and Elixir formatting, PHP syntax checks, Changesets status, and `git diff --check`.
16. The complete TaskChannel test file ran `43/45`; the two failing reconnect/resume tests also fail independently and never reach their expected Mox resume callback. They are recorded as an existing server-suite blocker rather than Phase 4 evidence. Phase 4's new cancellation vector passes independently.
17. Independent review first found that duplicate IDs aborted valid work, non-call methods could steal an active ID's response, detach was vulnerable to callback reentrancy, hidden tools and cursors violated the one-page catalog contract, and clear-before-notify documentation exceeded the implementation. All were corrected and the final focused re-review found no remaining Phase 4 implementation blocker.
18. The final review retained explicit deferred risks instead of broadening this slice: failed ACP connection-attempt cleanup, termination of generic pending ACP request promises, durable cancellation with no executor, connection-wide rate/deadline ownership, multi-owner execution claims, and prevention of reconnect redispatch belong to Phases 5-7.

### 2026-08-13 Phase 4 Custom-Phoenix Transport Lessons

1. Structural cancellation parsing is not cancellation. A transport needs exact active-request ownership, a cancellation primitive consumed by execution, and one terminal transition before it can claim request abortion.
2. Publish terminal state before calling `AbortController.abort`. Abort listeners run synchronously; deleting correlation first prevents a late completion or rejection from reclaiming response ownership.
3. An AbortSignal alone is not late-response suppression. Completion must prove it still owns the exact active entry before sending either success or error.
4. Duplicate IDs are collisions, not cancellation authority. Reject or ignore the duplicate without aborting the original request; otherwise a malformed peer can cancel valid work merely by reusing its ID.
5. ID uniqueness spans every request method and malformed request-like envelope, not only concurrent `tools/call` values. Any second response for an active ID can corrupt correlation even when it comes from discovery, listing, method-not-found, or invalid-request handling.
6. Callback ownership needs the registration token returned by the event system. Event-wide `off` is a tiny chainsaw: it cannot coexist safely with connection-wide listeners or independent observers.
7. Reentrancy matters at observability hooks. Recheck active ownership after invoking a user callback because that callback can synchronously detach the transport before the push occurs.
8. Teardown order is part of the proof. Mark inactive, remove the exact listener, abort active work, clear state, and suppress later pushes; changing that order creates windows for late output or collateral listener removal.
9. One-page listing must reject cursor presence, not cursor truthiness. An explicit empty cursor is still a continuation request and silently replaying page one corrupts pagination semantics.
10. Deterministic serialization requires both visibility filtering and exact sorting. A schema-valid catalog can still leak hidden tools or vary with registry assembly order.
11. Tool names are not extension metadata. Hard-coded `write_file` and `wp_upload_media` branches made attachment behavior undiscoverable and non-generalizable; a documented namespaced tool `_meta` value lets arbitrary tools declare the same behavior explicitly.
12. Metadata-driven byte injection is security-sensitive configuration. Tests must compare every field controlling source, destination, encoding, deletion, and media type; proving only the reference argument leaves dangerous substitutions untested.
13. Clearing Phoenix correlation before sending cancellation is stronger than relying on channel mailbox serialization. The state invariant should remain true even if surrounding push behavior becomes reentrant later.
14. Request-scoped cancellation and durable execution cancellation are separate layers. Clearing transient correlation prevents late persistence on that channel, but only durable claim/resolution state can prevent reconnect from replaying cancelled non-idempotent work.
15. Concurrency limits and rate limits are different. The accepted `256` cap bounds active correlation and terminal response ownership but does not provide a time-window request rate policy or, after later review, a complete retained-execution bound for tools that ignore abort.
16. Parallel ReScript package builds remain unsafe because clean/build targets share generated artifacts. The first parallel verification reproduced missing `.ast` failures; authoritative evidence was collected serially.
17. Full-suite failures need classification, not convenient amnesia. Reproducing the two reconnect failures independently showed they were not introduced by the Phase 4 cancellation path, but they remain visible release-regression debt.
18. Independent review after green focused tests remains non-ceremonial. It found terminal ownership, cross-method correlation, reentrancy, catalog, documentation-ordering, and stale-fixture defects that compilation and the first focused suite did not expose.

### 2026-08-13 Phase 5 Connection-Owner Implementation Delta

1. At this historical checkpoint, the user explicitly approved the Phase 5 implementation direction and focused evidence but not whole-phase acceptance. The later Phase 5 acceptance record closes the legacy-suite, project-context, multi-owner, lifecycle-race, documentation, and final-review gates listed here.
2. Browser MCP attachment moved from each `task:<task-id>` channel to the existing authenticated connection-wide `tasks` channel. `FrontmanClient__ACP` retains one connection-owned detach action, attaches only after a session channel joins successfully, and detaches only when the ACP connection disconnects.
3. The first connection-level browser implementation put attachment idempotency, cleanup closure management, and readiness signaling inline inside `joinSession`. The user rejected that shape as overly complex. The final approved shape extracts small `attachMcp` and `detachMcp` helpers so `joinSession` only requests connection-level attachment after successful joining.
4. A real transport race required an explicit `mcp:ready` application event. `TasksChannel` no longer emits discovery during channel join, because the browser has not necessarily installed its exact MCP listener yet. The browser attaches first, signals readiness second, and only then can the server emit `server/discover`.
5. `FrontmanServer.MCPCatalog` owns the current connection discovery/list state machine independently of any task. It creates modern `server/discover` and `tools/list` requests, supplies method-specific response parsing, converts the standard tool catalog, and publishes ready or failed catalog state.
6. `FrontmanServer.MCPConnection` is the deliberately small live-addressing seam between `ToolExecutor`, task observers, and the selected `TasksChannel`. It uses an OTP Registry only to locate a live process and publish catalog snapshots. It is explicitly not durable ownership authority and did not satisfy the later Phase 6 claim requirements by itself.
7. `TasksChannel` now owns request ID generation, exact pending method state, a hard `256` pending-call bound, ten-minute timers, direct request dispatch, method-aware response parsing, result persistence, task/tool cancellation, reconnect redispatch, and connection teardown cleanup. Pending entries retain task, turn, canonical invocation identity, method, and timer ownership.
8. `ToolExecutor.start_mcp_tool` now persists the durable tool call and directly addresses the connection owner instead of relying on every task observer to react to one PubSub interaction. Its timeout and sibling-cancellation paths notify the owner to remove transient correlation and send exact MCP cancellation before persisting their terminal result.
9. `TaskChannel` no longer starts an MCP initializer, accepts `mcp:message`, stores request correlation, routes MCP tool calls from task PubSub, or persists browser MCP responses. It subscribes to connection catalog publication, uses snapshots in execution contexts, sends task cancellation/load intent to the owner, and remains responsible for ACP task observation.
10. Live and replayed tool-call values have different local representations. Live `SwarmAi.ToolCall.arguments` is encoded JSON and must be parsed once; persisted `Tasks.Interaction.ToolCall.arguments` is already a map and must not be passed back through the live parser. The owner normalizes both into one invocation map before wire construction.
11. Replayed duplicate suppression is scoped by task and durable tool-call ID rather than ID alone. This prevents two tasks that happen to reuse one tool-call ID from silently suppressing each other while preserving one transient request per durable call inside one owner.
12. Malformed responses for an active catalog request transition the published catalog to failed rather than leaving task execution blocked forever in discovering or listing state. Malformed or unknown non-catalog responses cannot claim a pending tool request merely by carrying an ID.
13. Connection teardown cancels every owned timer, sends best-effort exact cancellation for pending browser work, and publishes a pending empty catalog to task observers. This prevents task observers from treating a dead connection's catalog as currently executable, while durable takeover remains Phase 6 work.
14. The focused Phoenix evidence is `22` passing tests across `TasksChannel` and MCP tool-routing files, including one full agent MCP round trip. The frontend evidence is all `110` `frontman-client` tests across `9` files plus a successful ReScript build. Elixir warnings-as-errors compilation and formatting pass.
15. The broad task-channel run is intentionally not a passing acceptance gate. After adapting the common handshake helper, it reached `30/49`; the remaining `19` failures are dominated by assertions that deliberately push or expect MCP on `TaskChannel`, plus reconnect/cancellation tests that must retain the connection-owner socket. They are conversion work, not accepted expected failures.
16. Independent review identified multi-owner selection, owner-death state publication, executor-timeout late responses, malformed-catalog stalls, session-load/catalog races, cross-task duplicate IDs, failed-session attachment leaks, and missing lifecycle tests. This session corrected timeout cancellation, malformed-catalog failure, cross-task duplicate scoping, failed-session attachment order, teardown publication, and the browser helper shape. Multi-owner policy, complete owner-death/failover proof, session-load ordering proof, and final re-review remain blockers.
17. The obsolete `FrontmanServerWeb.TaskChannel.MCPInitializer` and its tests still exist but are unreachable from production `TaskChannel`. They must be deleted only after project-context loading is moved to normal connection-owner-managed `tools/call` work with catalog presence checks and canonical structured-content parsing.

The preceding implementation delta is a preserved historical checkpoint. Accepted Phase 5 supersedes its open items: the converted suite passes, deterministic multi-owner selection and graceful/abrupt failover are proven, project context moved to bounded ordinary calls with readiness gating, and the initializer, serialized-text parser, tests, and browser no-op notification branch are deleted.

### 2026-08-13 Phase 5 Connection-Owner Lessons

1. Moving a handler to a connection topic is not sufficient; the server must not send discovery until the browser's exact listener exists. Channel join completion and application listener readiness are distinct lifecycle events.
2. Connection ownership should be visible in function shape. Session joining became difficult to reason about when it contained attachment state, idempotency, cleanup, and readiness details; two small connection-level helpers restored the boundary.
3. An OTP Registry can locate a live owner without becoming the owner. Treating process lookup as durable execution authority would reproduce the same side-effect race under a different noun.
4. Persist before external dispatch preserves a durable recovery identity, but failure to locate an owner after persistence needs explicit resolution policy. Raising loudly is better than silently waiting, yet whole-phase acceptance still needs a product-level unavailable-owner outcome.
5. PubSub is appropriate for catalog observation but not request ownership. Catalog snapshots may be copied to task observers; pending request maps, timers, and terminal authority must remain in exactly one connection process.
6. Tool-call identity needs its full domain. A durable ID without task scope is insufficient for transient deduplication when separate tasks can carry equal IDs.
7. Live and persisted representations should normalize at the connection boundary. Calling a live parser on already-decoded persistence data is both redundant and crash-prone.
8. Executor timeout and transport cancellation must converge on one correlation entry. Persisting a timeout without removing browser ownership leaves a late response able to attempt a second terminal result.
9. Catalog failure is execution state. Logging malformed discovery or listing and retaining a pending state can block every accepted prompt indefinitely; failure must publish a terminal availability decision.
10. Teardown cannot rely only on Registry cleanup. Observers need an explicit catalog transition, timers need cancellation, and browser work needs best-effort request cancellation before the channel disappears.
11. Multiple tabs force an explicit selection policy. A duplicate Registry prevents join crashes, but lookup order is not a sound failover or execution-ownership contract; Phase 5 acceptance must define and test owner choice before Phase 6 adds durable claims.
12. Historical tests are architecture evidence. Tests that push MCP responses into `TaskChannel` are not merely stale syntax; they enumerate every lifecycle behavior that must be re-homed and reproven on `TasksChannel`.
13. Do not delete an obsolete state machine until its application responsibilities have owners. The protocol-initialization concept is dead, but project rules and structure loading still require a replacement workflow before the module can be removed safely.
14. Focused green tests prove the new path can work; the broad red suite shows the migration is not complete. Both facts belong in the plan without converting failures into an expected-failure baseline.

### 2026-08-13 Phase 5 Acceptance Delta

1. The user explicitly approved the completed Phase 5 migration after the final serial gates and independent review. This acceptance covers process-local connection ownership only; it did not yet claim durable execution leases or exactly-once non-idempotent side effects. Accepted Phase 6 later added durable leases without claiming impossible arbitrary exactly-once behavior.
2. `FrontmanServerWeb.TasksChannel` is the sole transient custom-Phoenix MCP owner. `TaskChannel` is an ACP/task observer and execution gate; it no longer initializes MCP, accepts MCP responses, generates request IDs, dispatches browser work from PubSub, or persists browser results.
3. The browser installs one exact MCP listener on the authenticated `tasks` channel only after a successful task-session join, then sends `mcp:ready`. Discovery cannot race ahead of listener installation, and task cleanup cannot remove the connection listener.
4. `FrontmanServer.MCPConnection` remains a small process-local addressing seam rather than durable authority. It selects the oldest live owner deterministically. Successors monitor the selected owner; only the newly selected successor republishes its catalog and drives recovery after graceful or abrupt owner loss.
5. Owner failover invalidates owner-scoped project-context readiness and re-gates task execution. Unresolved persisted tool calls redispatch through exactly one successor. If no successor exists, observers receive a pending empty catalog and affected SwarmAi executions are cancelled to quiescence before live executor ownership is released.
6. Every discovery, listing, ordinary tool, and project-context request has one immutable `600,000 ms` timer. Completion, malformed response, cancellation, timeout, deletion, failover, and teardown remove one pending entry, cancel one timer, and select at most one terminal outcome.
7. One connection owns at most `256` pending requests. Project-context calls share this same bound rather than bypassing it. Catalogs contain at most `256` tools, and one connection tracks at most `256` task-context states.
8. Terminal request records are retained in `FrontmanServer.MCPTerminalRequests`: at most `4,096` records for `900,000 ms`. Records preserve exact JSON ID type, method, request kind, terminal reason/time, and former owner. Exact `4,096/4,097` and `900,000/900,001 ms` vectors prove eviction and expiry without cross-completion.
9. Pending correlation is method- and kind-aware. Malformed catalog responses fail the catalog; malformed ordinary call responses complete only their exact call with a fixed protocol error; unknown, duplicate, cancelled, timed-out, and late responses cannot claim a sibling.
10. Tool execution identity is `{task_id, tool_call_id}` throughout transient request deduplication and `ToolCallRegistry`. Two tasks may reuse the same durable call ID without suppression or cross-delivery. Duplicate registration is an explicit invariant failure rather than an ignored Registry result.
11. Randomized out-of-order completion of ordinary calls preserves one-to-one task-scoped results. Controlled races cover timeout-first, response-first with stale timeout, cancellation, duplicates, late responses, unknown IDs, sibling isolation, timer cleanup, and one persisted terminal outcome.
12. Project-context loading uses ordinary `tools/call` requests only when exact catalog names exist. Rules and structure require canonical `structuredContent`; no serialized text fallback remains. Missing tools, framework policy, validation failure, timeout, or nonfatal peer failure produce an explicit terminal readiness decision.
13. Project context is not marked loaded before validation and persistence finish. Failures remain retryable. Successful content is fingerprinted and bounded: `64` rules, `4,096` path bytes, `65,536` content bytes, `262,144` tree bytes, `64` workspaces, and `4,096` bytes for each workspace name/path.
14. Prompt construction uses the latest rule per path and latest structure rather than appending stale replacements. Task execution cannot start or resume until the selected owner's catalog and required project-context readiness are terminal. The `session/load` response still precedes resulting browser calls.
15. Session deletion synchronously cancels the active SwarmAi lifecycle, waits for quiescence, cancels and forgets ordinary/project-context owner work, clears context tracking, then deletes persistence. A late browser response after deletion is fenced and cannot crash or recreate state.
16. SwarmAi now has one lifecycle coordinator registered for the complete worker-plus-terminal-dispatch lifetime. `run/2` duplicate exclusion and `running?/2` use the same ownership key. The linked inner worker cannot outlive a killed coordinator, and a replacement cannot start while terminal dispatch is still in flight.
17. Task-channel test teardown moved channels under teardown-owned supervision, unlinks them from the ExUnit process, and gracefully quiesces channels and SwarmAi lifecycles before SQL sandbox ownership ends. Synchronous lifecycle event dispatch is the database quiescence barrier; passing assertions no longer hide ownership errors after teardown.
18. Logger metadata was aligned rather than discarded. MCP tool failures retain configured `error_type`, `tool_name`, `tool_call_id`, `task_id`, and `error_code` fields, preserving Sentry reporting without exposing arguments or peer payloads.
19. The converted `TaskChannel` suite passes all `43` tests under ten explicit seeds. Two independently seeded complete server runs pass `772` tests without `DBConnection.ConnectionError`, ownership, owner-exited, or closed-connection diagnostics.
20. Final serial evidence is `772` server tests, `116` SwarmAi tests, `110` frontman-client tests, ReScript build and format, Elixir test-environment warnings-as-errors compilation, strict Credo with zero issues, `git diff --check`, active-source searches showing no initializer or `mcp_initialization_complete`, and independent review with no remaining behavioral finding.

### 2026-08-13 Phase 5 Acceptance Lessons

1. Moving code to a connection topic does not create connection ownership. Request maps, timers, terminal authority, readiness, and teardown must all move together, while task channels lose those responsibilities.
2. Additions without deletion preserve two architectures. Phase 5 was not complete until the initializer, serialized-text parsing, browser no-op, old response handlers, old tests, and stale documentation were removed or explicitly marked historical.
3. A Registry lookup order is not a policy. Multiple tabs require deterministic selection, owner monitoring, successor-only publication, and proof that a departing non-owner cannot clobber the selected catalog.
4. Failover and last-owner loss are different transitions. Failover preserves live execution and redispatches through one successor; last-owner loss must invalidate the catalog and terminate execution that can no longer receive a result.
5. Project context is part of execution readiness, not optional background decoration. Publishing a ready catalog before context hydration can let the model run with stale or absent instructions.
6. A deduplication key is only correct when it contains the full identity domain. Globally keying by `tool_call_id` allowed unrelated tasks to collide; task scope is mandatory in pending and executor registries.
7. A recent-ID list that is never consulted is office furniture. Terminal tracking must actively classify duplicate and late responses, preserve exact ID type, expire by monotonic time, and remain bounded under insertion.
8. Green assertions can coexist with dirty lifecycle behavior. Database ownership diagnostics after a passing suite are failures because they prove processes outlived their test and can do the same in production teardown.
9. `running?` must describe the complete observable lifecycle. Releasing execution ownership when the worker exits but before terminal dispatch completes permits overlapping executions and contradictory state.
10. Killing a lifecycle owner is an adversarial boundary. Monitoring an unlinked worker is insufficient because `:kill` bypasses `terminate/2`; the worker must be linked or supervised so it cannot become an orphan.
11. `:sys.get_state/1` is only a barrier for one mailbox. It does not drain self-enqueued work, a sibling channel, an execution worker, a terminal watcher, PubSub delivery, or database activity. Tests need barriers at the actual lifecycle owner.
12. Test cleanup must follow production ownership. ExUnit links caused channels to die before `on_exit`; teardown-owned supervision and monitored graceful shutdown were required to prove clean database lifecycle behavior.
13. Session deletion is a lifecycle transaction. Cancelling transport correlation without cancelling the waiting execution leaves a live owner targeting deleted persistence.
14. Exact limits must apply to every request kind. Project-context work initially bypassed the pending bound and accepted unbounded peer collections; shared limits and at-limit/one-over tests closed that asymmetry.
15. Nonfatal does not mean permanently suppressed. Project-context failures marked loaded too early and prevented retry; terminal readiness and successful-load state must be separate concepts.
16. Strict result parsing must precede pending removal. An unknown malformed response carrying a nearby ID cannot be allowed to steal a valid pending call.
17. Observability metadata is an API. Removing unconfigured fields made strict logging cleaner but broke Sentry evidence; the correct fix was to configure the established structured fields while keeping sensitive payloads absent.
18. Independent review remained non-ceremonial through the last gate. It found catalog hangs, kind-confused pending entries, stale failover catalogs, deletion leaks, cross-task IDs, orphan workers, context ordering, logger/Sentry drift, and contradictory acceptance prose after focused tests were green.

### 2026-08-12 Phase 3 Browser Client Lessons

1. Preserve the application seam while replacing the wire seam. Keeping the temporary `Relay` module name avoided a noisy cross-application rename, but retaining that name must not be confused with retaining private Relay protocol behavior.
2. HTTP status and JSON-RPC meaning are separate authorities. A required HTTP `400` can still carry a valid correlated `-32020` response that drives client recovery; collapsing every non-2xx response before parsing made the normative relist path unreachable.
3. Never let an untrusted cancellation promise own terminal settlement. Start reader cancellation, observe rejection, release ownership, and preserve the already-selected success, timeout, limit, or cancellation result.
4. Streaming framing must be tested across chunk boundaries, not only with complete strings. Normalizing a trailing carriage return before the next chunk arrived synthesized a false blank line and could dispatch an incomplete SSE event.
5. EOF is a valid SSE event terminator. A final data event without a blank delimiter must be flushed and classified when the stream closes rather than mislabeled as a missing terminal response.
6. Strict `TextDecoder` use requires a final empty decode. Chunk-by-chunk `stream: true` decoding alone does not reject an incomplete trailing multibyte sequence.
7. Response byte and JSON-depth limits apply equally to JSON and SSE. Protecting only the JSON path leaves an attacker free to move the same oversized or deeply nested message into SSE framing.
8. Exact media matching matters. Prefix checks accept unrelated types such as `application/jsonp`; split parameters from the lowercased type/subtype and compare the exact media token.
9. Shared wire schemas intentionally preserve open `resultType` strings, so consumers must enforce the result types they implement. Discovery and listing cannot assume that successful structural parsing means `complete` semantics.
10. Cache lifetime begins when the response is obtained, not after a long pagination sequence. Anchor freshness before network work and choose the minimum TTL without extending earlier pages.
11. Page cache scope is a sequence invariant, not a value to normalize. A mixed-scope listing is malformed peer behavior and must fail without publishing a partial catalog.
12. Strict AJV rejects unknown keywords unless the protocol extension is registered. `x-mcp-header` must be an explicit validator keyword; disabling strictness would hide misspelled or hostile schema fields.
13. Structural schema bounds reduce obvious abuse but do not make synchronous untrusted compilation safe. The approved worker-isolation slice now closes this blocker with a hard per-operation validation budget and pathological-pattern main-thread responsiveness proof.
14. Invalid remote definitions and invalid Frontman-owned definitions have different failure policies. Exclude one hostile remote tool and preserve siblings; crash on malformed owned schemas so server defects remain visible.
15. A private cache inside one immutable client instance is naturally authorization-bound only if request headers are copied at construction and cannot mutate underneath it. Cross-instance sharing requires an explicit cache key and remains prohibited in this slice.
16. Tool output validation belongs after execution but before handing data to the model. Because retrying an output failure could repeat side effects, output-schema failure is terminal and never enters the header-mismatch retry path.
17. Real HTTP tests catch composition defects that mocked Fetch tests cannot: actual lowercased headers, status/body interaction, stream framing, content types, cursor transmission, and request counts all matter.
18. Green tests were not enough. Independent reviews found unreachable recovery, unbounded response accumulation, cross-chunk CRLF corruption, unsafe cancellation awaiting, missing depth parity, cache freshness drift, permissive media matching, open result-type acceptance, and EOF loss after the first suite passed; each became a permanent regression criterion.

### 2026-08-10 Phase 2 Review Lessons

1. Preserve untyped JSON through envelope/direction and mirrored-header stages. Parsing directly into `DiscoverRequest`, `ListToolsRequest`, or `CallToolRequest` would incorrectly move `InvalidParams` ahead of required header errors.
2. A complete exact lowercase `=?base64?...?=` value invokes sentinel decoding. Uppercase `BASE64` and an incomplete lowercase marker are ordinary raw ASCII when otherwise safe. The traceability matrix now records uppercase-marker handling as a positive raw-ASCII vector, not a malformed-sentinel vector.
3. Node accepts permissive and noncanonical Base64 unless the implementation checks syntax and round-trip canonicalization explicitly. UTF-8 validity must be checked before string conversion so replacement decoding cannot hide malformed bytes.
4. Web `ReadableStream` construction may call `pull` before any reader is acquired. Preflight tests therefore prove that the stream remains unlocked and its first chunk remains unread; raw pull-count assertions are invalid.
5. An underlying stream's cancellation callback may not run after the stream has already closed. Cancellation tests use intentionally open streams so they prove the reader invokes cancellation instead of depending on queue prefetch timing.
6. The simplest bounded body accumulator is one fixed 2 MiB buffer plus one final slice. The rejected geometric allocator added code without improving the frozen memory bound, while chunk-array accumulation invited avoidable overhead.
7. Byte-limit checks compare each chunk length against remaining capacity before integer addition. Adding first can overflow a ReScript integer and bypass the limit.
8. Byte limits alone do not bound stream iteration because zero-byte and tiny chunks exist. The additional `4,096`-chunk limit is now frozen and tested at `4,096/4,097`.
9. Idle timing uses monotonic time and checks the deadline both before and after a pending read. Otherwise event-loop delay can let bytes received after the deadline win `Promise.race`.
10. Timeout is terminal at `60,001` milliseconds. Cancellation starts immediately but does not await an untrusted underlying cancellation promise; pending reads are drained only for lock release, and cancellation or loser-read failures are reported categorically without replacing the timeout result.
11. Non-empty bytes and terminal completion at exactly `60,000` milliseconds win; zero-byte chunks do not reset activity. Fake-time tests cover completion, late-byte, cancellation rejection/nonsettlement, timer cleanup, and already-expired races.
12. Web Request composition checks `bodyUsed` and nullable `body` before acquiring a reader. It preserves reader and decoder errors separately and returns arbitrary-root JSON without interpreting JSON-RPC fields.
13. Sury remains the serialization path even in boundary tests. Manual JSON traversal or `JSON.stringifyAny` would weaken the same rule enforced in production code.
14. Route-independent foundations are not transport acceptance. A module is not evidence for `/mcp` behavior until production routing, ordered validation, exact HTTP mapping, no-side-effect tests, adapter cancellation, and black-box conformance all reach it.
15. The shared `Wire.requestSchema` is intentionally too strict for envelope-stage HTTP classification because it requires object-valued `params`. Part 2I-A uses the shared safe ID and cross-message-field logic but preserves arbitrary `params` so malformed method parameters remain step 12 rather than becoming step-8 invalid requests.
16. Sury validation failures are typed `S.Exn` values, not necessarily JavaScript exceptions. Boundary classifiers match `S.Exn` explicitly and rethrow unknown exceptions; `JsExn.fromException` is reserved for actual JavaScript failures.
17. Invalid-envelope ID recovery is a separate operation from envelope acceptance. A wrong JSON-RPC version, missing or wrong method, response discriminant, or mixed request/response shape can still carry a readable ID that must survive the later `-32600` response; recovering that ID never makes the envelope valid.
18. Wide safe numeric IDs must remain `JsonRpc.Id.t` and serialize through `JsonRpc.Id.toJson`. Converting through `toInt` would narrow values that JavaScript can represent safely but ReScript integers cannot.
19. Raw mirrored authorities must remain independently readable. A malformed `_meta` does not erase a readable `params.name`, while scalar `params` yields no invented nested authority. Protocol version, client capabilities, and selected `name` or `uri` remain raw JSON until their ordered validation stages.
20. `Mcp-Name` authority is method-selected: `tools/call` and `prompts/get` use `params.name`, `resources/read` uses `params.uri`, and unrelated methods have no name authority even if stray `name` or `uri` fields exist.
21. Standard-header validation must consume raw body authorities. A missing or non-string body protocol version or name becomes `HeaderMismatch` only after every required header is present; it must not become premature `InvalidParams` or `UnsupportedProtocolVersion`.
22. The decoded-request boundary must advertise its precondition in its API and name. `FrontmanCore__MCP__DecodedRequest` starts only after successful UTF-8 JSON decoding and therefore cannot be cited as proof for Origin, authorization, media negotiation, body reading, parse-error mapping, or an active `/mcp` route.
23. Standard JSON-RPC `ParseError` and `InvalidRequestError` shared schemas validate the nested error object, while MCP-reserved `HeaderMismatchError` and `UnsupportedProtocolVersionError` schemas validate complete response envelopes. Tests must validate each schema at its actual structural level instead of assuming every named error export has the same root shape.
24. MCP permits an omitted error-response ID when a malformed request prevents reading it. Part 2J-A uses Sury to omit `id` for unreadable values and preserve the exact string or safe numeric ID otherwise; it does not emit a fabricated ID or manually serialize a `null` fallback.
25. Decoded-request composition proved the frozen multi-fault order end to end: invalid envelope before headers, all required standard-header presence before body comparison, every header mismatch before supported-version classification, and only then an accepted pre-metadata value.
26. Complete request metadata must be parsed only after standard headers and supported-version classification. Missing client capabilities and malformed known metadata fields are `-32602`; they cannot replace an earlier `-32020` or `-32022` response.
27. Required client capabilities are processing requirements, not global HTTP requirements. The route-independent boundary accepts an explicit aggregate requirement, returns `-32021` only when that requirement is absent or incompatible, and does not impose the custom-Phoenix execution-context extension on framework HTTP clients.
28. Method-specific schemas belong only after complete request metadata and capability checks. Supported-method parameter failures are HTTP 200/`-32602`, while an unsupported RPC method is HTTP 404/`-32601`; neither path selects a tool or validates tool arguments.
29. The shared complete request schemas are correct at the method stage but wrong at the envelope stage. Re-parsing the preserved raw envelope after steps 8-11 reuses the authoritative schema owners without allowing method-parameter failures to jump ahead of header, version, metadata, or capability errors.
30. A client capability is required only when processing actually depends on it. The HTTP boundary accepts an explicit aggregate requirement and otherwise permits `{}` for core-only requests; a custom-Phoenix execution-context capability must never become an accidental global HTTP requirement.
31. Capability-shape failure and extension-payload failure are separate categories. Generic malformed `clientCapabilities` is `-32602`; a generically valid but absent or incompatible processing requirement is `-32021`; any extension payload is validated only by the later behavior that consumes it.
32. Unsupported method classification does not need a method-parameter schema. After successful metadata/capability validation, a method outside the implemented set returns HTTP 404/`-32601` even when its open `params` would not match any known request schema.
33. `x-mcp-header` cannot be validated from the request alone. The selected tool definition supplies the recognized annotation names and exact argument paths, so custom-header validation must follow method parsing and exact tool selection while still preceding selected-tool argument validation and execution.
34. Method-level JSON-RPC errors and transport/protocol boundary errors have different HTTP statuses. Malformed supported-method parameters use HTTP 200/`-32602`; missing metadata, capability, version, and header failures use HTTP 400; unsupported methods use HTTP 404/`-32601`.

### 2026-08-11 Phase 2 Selection And Custom-Header Lessons

1. Exact selection is its own typed stage. Do not represent a selected call as an optional tool attached to a generic request; that permits impossible states. Discovery, listing, and selected calls need distinct variants so later code cannot execute a call without a tool or attach a tool to a non-call request.
2. Unknown-tool lookup must use the registry's exact case-sensitive owner. Do not trim, case-fold, alias, or duplicate lookup logic. The specification classifies an unknown tool as a protocol-level `-32602`, while a selected tool's input-schema rejection is a complete error result under SEP-1302.
3. Ordered validation code should read in the same direction as the protocol. A linear `Result.flatMap` pipeline with shallow stage functions is easier to review than nested switches and makes accidental precedence changes visible in the diff.
4. Selected-schema header discovery must scan the complete JSON Schema tree, not only fields represented by Sury's typed `JSONSchema.t` binding. Otherwise an annotation under an unsupported 2020-12 or vendor keyword can evade forbidden-location detection.
5. A property annotation is recognized only when every path segment from the schema root is a direct `properties` edge. Finding the same key beneath arrays, composition, conditionals, `$ref`, `$defs`, definitions, or an unknown keyword invalidates the owned schema rather than creating a header authority.
6. Custom-header validation is not complete selected-tool argument validation. It inspects only annotated exact paths and primitive wire values. Missing unrelated required fields, invalid sibling fields, bounds, enums, formats, and additional-property rules remain untouched until the SEP-1302 argument-validation stage.
7. Web `Headers` is insufficient evidence for duplicate physical-field rejection because it combines ordinary duplicates. A combined value equal to legitimate comma-containing body data is ambiguous. Raw adapter multiplicity must be preserved and validated before constructing Web `Headers` or activating `/mcp`.
8. Numeric comparison requires lexical exactness before floating-point conversion. `Number.isSafeInteger(Number(text))` alone accepts some fractional texts after rounding. Parse the JSON-number structure, prove its fraction/exponent denotes an exact integer, then convert and enforce the safe range.
9. Numeric safety bounds must be derived from the input representation rather than an arbitrary exponent cutoff. Long mantissas can cancel long negative exponents and still denote a small exact safe integer; fixed cutoffs reject interoperable values without a specification basis.
10. A malformed Frontman-owned annotation is a build/runtime invariant failure, not client misconduct. Crash loudly before argument validation or execution. The later browser client has a different trust boundary and must exclude only the malformed remote tool while retaining valid siblings.
11. Unknown `Mcp-Param-*` fields are ignored by an endpoint server unless the selected schema recognizes them. Forwarding requirements apply only where an adapter is genuinely acting as an intermediary and must not be claimed for the route-independent endpoint validator.
12. Traceability must be updated as part of the slice, including old rows elsewhere that contradict current version or error support. Structural matrix verification proves shape and uniqueness, not semantic freshness; independent documentation review remains necessary.

### 2026-08-11 Phase 2 Selected-Input Lessons

1. A selected tool's schema failure is a tool execution error under SEP-1302 even though execution never begins. It belongs in a successful JSON-RPC response containing a complete `CallToolResult` with `isError: true`, not in a JSON-RPC `-32602` error.
2. Terminal boundary types must distinguish protocol rejection from a completed method result. Reusing `Rejected` for an HTTP 200 JSON-RPC success would make later dispatch and media composition reason about a lie.
3. Complete argument validation must follow selected-schema custom-header comparison. Otherwise an unrelated missing or malformed argument could replace the required HTTP 400/`-32020` response for a recognized custom-header mismatch.
4. Omitted tool arguments have one canonical meaning at this boundary: the empty JSON object. Perform that normalization through Sury, then validate it against the selected schema so all-optional and required-input tools behave consistently with the existing execution helper.
5. Sury-only boundary handling applies to tests and default construction as well as production parsing. Do not manually traverse emitted JSON to assert fields, and do not use `JSON.Encode.object` merely because the dictionary already contains JSON values.
6. Validate an opaque protocol result through its authoritative schema before projecting fields needed by a focused assertion. A narrow test-only Sury schema may inspect `resultType` and `isError`, but it must not replace complete `CallToolResult` validation.
7. Error responses must not disclose validator diagnostics or hostile argument values. A stable category message is sufficient for this route-independent result; richer diagnostics belong only in a future redacted internal observability policy.
8. A test tool whose `execute` fails is weaker no-side-effect evidence than a test tool with an observable invocation counter. Assert the counter on valid selected input, invalid selected input, and omitted-input paths.
9. Enabling complete selected-input validation can reveal old tests that were accepted only because the boundary previously stopped early. Correct stale fixtures to satisfy the real tool schema; never add fallback input or weaken validation to preserve an invalid fixture.
10. Sury transform parser failures are surfaced as `S.Exn`. A test that throws inside a transform parser does not prove the unknown-exception branch; retain exact `S.Exn` handling and rethrow all non-Sury exceptions without inventing misleading coverage.
11. Structural traceability verification cannot detect semantically stale prose. Every completed slice needs targeted searches for old phase endpoints, test counts, planned-status claims, and statements that a newly implemented behavior remains deferred.
12. Part 2K-C is still route-independent. Its HTTP 200 response object proves result construction and status semantics only after decoded-request preconditions; it does not prove content negotiation, active routing, raw header multiplicity, Origin, authorization, execution, or adapter cancellation.

### 2026-08-11 Phase 2 Selected-Execution Lessons

1. Validation and execution need separate typed entry points. `validate` remains synchronous and returns an accepted value only after the complete ordered boundary succeeds; `execute` is asynchronous and accepts that validated value rather than mixing side effects into validation.
2. Execute the selected existential tool directly. Repeating registry lookup after selection could execute a different module if registry ownership changes and would weaken the exact-selection proof established by Part 2K-A.
3. Reuse the existing execution implementation by extracting its selected-tool invocation body, not by duplicating execution logic or calling the name-based helper. The private Relay path and modern MCP path now share parsing and invocation while the MCP path preserves selected identity.
4. A tool-returned `CallToolResult` with `isError: true` is an intentional API or business failure and must survive unchanged. A thrown exception is a different failure domain and must become a fixed complete error result without exposing exception text.
5. Client-visible execution errors use stable categories. `Tool execution failed` replaces thrown diagnostics, while an unexpected post-validation schema discrepancy becomes `Invalid tool arguments`; raw exception messages, Sury diagnostics, and argument values do not cross the boundary.
6. Impossible selected-execution states should crash loudly. `executeSelectedTool` cannot return `ToolNotFound`, so that outcome is treated as a server invariant failure rather than fabricated into a client protocol response.
7. Every emitted call result must validate through `MCP.CallToolResult.schema` before entering the JSON-RPC success envelope. A typed tool return alone is not sufficient evidence at a runtime boundary.
8. Failure classification tests must distinguish returned business errors, returned API errors, and thrown exceptions. Labeling a thrown exception as an API failure hides whether intentional error results are preserved and whether unexpected diagnostics are redacted.
9. Result tests must assert semantic identity, not only `resultType` and `isError`. The success test proves the selected tool's exact text survives invocation, schema conversion, and JSON-RPC response construction.
10. Execution cardinality needs an observable counter. Successful, returned-error, and thrown-error paths each execute exactly once; pre-execution validation failures remain at zero.
11. Shared mutable test evidence must be initialized inside every relevant test. The first full run exposed an execution counter leaking into a later no-execution assertion, so exact-count tests no longer depend on source order or runner scheduling.
12. A route-independent execution response is not active HTTP execution proof. Part 2K-D does not establish Origin or authorization ordering, raw duplicate-header rejection, media/body mapping, adapter abort propagation, absolute deadlines, active-endpoint side-effect behavior, or framework interoperability.
13. Independent review is part of the slice, not ceremonial garnish. It found a real credential-and-diagnostics disclosure risk after the first green implementation, then found missing evidence that successful content and intentional API/business errors remained intact.
14. Part 2K-D is explicitly approved as the validated selected-execution checkpoint. Discovery/list result construction was completed and approved in the subsequent 2K-E slice; active routing and all transport-owned policy remain later work.

### 2026-08-11 Phase 2 Discovery And Listing Lessons

1. Standard MCP tool serialization needs a separate owner from private Relay serialization. Reusing `Relay.remoteTool` would expose Frontman-only `access` and `visibleToAgent` policy instead of producing the standard `MCP.Tool` shape; the existing Relay serializer remains unchanged until Relay removal.
2. Discovery capabilities must describe the framework HTTP server rather than copy the browser custom-Phoenix server. The framework advertises only `tools.listChanged: false`; it must not accidentally advertise `ai.frontman/execution-context` or any optional capability it does not consume on HTTP.
3. Result metadata is protocol data, not an incidental wrapper concern. Discovery and list results both carry exact framework `serverInfo`, `ttlMs: 0`, and private cache scope before they enter the JSON-RPC success envelope.
4. Deterministic catalog order means sorting exact case-sensitive tool names, not preserving registration order. Reversed registries must emit the same name sequence so framework composition order cannot perturb prompts or client caches.
5. Hidden tools are omitted from the standard catalog rather than serialized with a private visibility flag. Internal execution-timing and access policy stay private; only the conservative standard `readOnlyHint` is emitted, with read tools mapped to `true` and write/read-write tools mapped to `false`.
6. A schema-valid serialized tool is not proof that the serializer preserved the right schema. Tests must compare description, input schema, and optional output schema semantically with the source tool module; a wrong but valid object schema would otherwise pass the shared `Tool` contract.
7. The list dispatcher must serialize the same registry snapshot used during validation. Carrying the validation-time registry in the accepted value avoids a second lookup against potentially different registry ownership and extends the selected-tool identity rule to catalog production.
8. Discovery and list dispatch must remain side-effect free. Focused tests use the existing execution counter to prove list construction never invokes a tool, while empty and populated catalogs both produce complete schema-valid responses.
9. Every opaque result must validate through its authoritative Sury result schema before JSON-RPC wrapping. Focused projections may inspect identity, capabilities, caching, ordering, and annotations only after complete `DiscoverResultResponse` or `ListToolsResultResponse` validation.
10. One-page result production and cursor handling are separate responsibilities. Omitting `nextCursor` correctly terminates the initial catalog, but a supplied string cursor is structurally valid input and must receive HTTP 200/`-32602` because this server has no valid continuation cursor; silently returning page one would corrupt cache semantics.
11. Route-independent completion is still not Streamable HTTP acceptance. These results prove behavior only after decoded-request preconditions and do not establish Origin, authorization, Content-Type, Accept negotiation, body failure mapping, raw duplicate fields, disconnect cancellation, or production reachability.
12. Structural traceability verification cannot detect stale meaning. The independent review found rows and phase summaries that still called completed result production planned, so each slice requires semantic searches for old boundaries, checklist state, test counts, approval state, and deferred-work claims.
13. Review should test semantic identity, not merely schema shape. The first independent pass found the missing preservation evidence; subsequent passes found stale summary/checklist claims; only after all were corrected did the final review return PASS.
14. Part 2K-E is explicitly approved as the route-independent discovery/list checkpoint. Part 2K-F subsequently rejects invalid unsolicited cursors, Part 2K-G composes exact pre-decode HTTP responses, and Part 2K-H enforces raw physical custom-header singleton multiplicity for Vite/Astro input. Active routing remains forbidden.

### 2026-08-11 Phase 2 Cursor And Pre-Decode HTTP Lessons

1. Cursor wire validity and server pagination validity are separate. Parse the shared optional opaque string first, then reject every supplied cursor by presence because Frontman emits only one page; never inspect, normalize, or branch on its contents.
2. Returning page one for a supplied cursor is not a harmless fallback. It falsely accepts an unsupported continuation and can corrupt client pagination and cache semantics.
3. Media policy precedes all body access. Unsupported `Content-Type` and unacceptable `Accept` produce exact empty 415/406 responses without acquiring or consuming a body reader.
4. Empty 415, 406, 413, and 408 responses are deliberate Frontman transport/security policy, not MCP-mandated JSON-RPC mappings. Do not fabricate JSON bodies or response media headers for them.
5. Controlled undecodable-body categories map to one fixed ID-less HTTP 400/`-32700`. Recovering an ID from incomplete or malformed bytes was rejected because only a complete decoded JSON value can supply trustworthy request identity.
6. Preserve arbitrary JSON roots through decoding and hand them to `DecodedRequest`. Parsing directly into a request schema would collapse parse errors into invalid-request or method errors and change the frozen validation precedence.
7. Controlled client input and server invariants remain separate. Missing bodies, malformed lengths, fragmentation limits, malformed UTF-8, excessive depth, and malformed JSON are mapped; consumed bodies and unexpected stream exceptions still crash loudly.
8. `HttpRequest` composes validation only. It must not execute an otherwise accepted call; an observable invocation counter is stronger evidence than relying on an `execute` function that merely throws if invoked.
9. Composition tests must prove precedence and resource behavior, not only final status: media before body, preflight 413 without reader acquisition, malformed body before decoded validation, exact empty bodies and headers, arbitrary-root handoff, and zero execution.
10. ReScript verification remains serial because shared clean/build artifacts can race across packages. A focused green test is insufficient without the complete `33`-file/`433`-test suite and the independent review gate.
11. Structural traceability checks cannot detect stale meaning. Each slice needs semantic searches across phase summaries, checklists, status matrices, next-step statements, deferred-work claims, approval state, and test counts.
12. Preserve checkpoint evidence rather than rewriting history. Label old counts and limitations by their part while keeping one unmistakable current aggregate summary.
13. At the Part 2K-G checkpoint, residual risks included adapter-owned allowlist/auth configuration and Next.js raw physical evidence. Part 2K-J subsequently closed those configuration/input blockers, Part 2K-K closed shared pre-body streaming and transport disconnect ownership, Part 2K-L closed configured JavaScript framework reachability, generated Next routing, preflight/method policy, one real authorization integration, focused active-endpoint proof, and changeset gaps, Part 2K-M closed cancellation-aware selected-tool execution and the absolute active-framework deadline, and approved Part 2K-N closed installed real-process framework parity. Official conformance and Relay removal remain.

### 2026-08-11 Phase 2 Raw Physical Header Lessons

1. Web `Headers` is a lossy view and cannot own physical-field multiplicity. Preserve Node's alternating `rawHeaders` name/value list in a separate typed domain before any Web Request or Web `Headers` construction.
2. Capture order is part of the security proof. Reading `rawHeaders` later in the adapter may happen to preserve current values, but it does not prove that no earlier conversion, body operation, or framework behavior can erase the evidence.
3. Adapter tests must invoke the actual adaptation path and inspect what reaches middleware. A direct unit test of `physicalHeaders` proves parsing only; it does not prove capture ordering or propagation.
4. Physical name comparison is case-insensitive, while field values remain exact. Preserve original values for strict sentinel decoding and body comparison rather than normalizing them through Web APIs.
5. Never split recognized custom-header values on commas. One physical field containing `a, b` is a legitimate singleton string; two physical fields are duplicates even if Web `Headers` would fold them into indistinguishable comma-separated text.
6. Duplicate recognition depends on the selected tool schema. Preserve all physical fields through method parsing and exact selection, discover recognized annotation names, then require zero or one matching physical occurrence before complete argument validation.
7. Missing physical evidence for a selected annotated call is a server integration defect, not hostile client input. Crash loudly instead of accepting a folded Web value or fabricating `HeaderMismatch`; calls whose selected schemas contain no annotations remain unaffected.
8. An odd Node `rawHeaders` array is impossible under the platform contract and must crash as an adapter invariant. Do not silently drop an unmatched name or invent an empty value.
9. Duplicate custom-header rejection remains HTTP 400/`-32020`, preserves the readable request ID, names only the canonical header, and occurs before selected-input validation or execution. Observable execution counters are required evidence for the no-side-effect claim.
10. Raw-header support belongs at the shared core boundary, but framework capture remains adapter-owned. Vite and Astro satisfy that contract directly; Part 2K-J proves the Next Node seam and Part 2K-L activates it through the generated Pages API route.
11. Independent review must inspect ordering and evidence quality, not just final values. This slice's first green implementation captured too late, and its first adapter tests proved only a helper; both defects survived ordinary compile and focused core tests.
12. Semantic documentation review remains mandatory. Structural traceability checks passed while an older Phase 1 paragraph still called all raw duplicate validation future work.
13. ReScript verification must remain serial because package builds share generated artifacts. Parallel package builds can clean another package's outputs and manufacture failures unrelated to the slice.
14. The Astro and Vite package `make lint` targets formerly passed rejected directory arguments. They now invoke `rescript format --check` without directory arguments, matching the repaired Next.js target and root aggregate ownership.
15. Part 2K-H is explicitly approved as the Vite/Astro raw physical singleton checkpoint. It did not establish Next.js raw access, Origin, or authorization; Parts 2K-I and 2K-J subsequently closed those blockers, Part 2K-K closed transport cancellation ownership, Part 2K-L closed configured active routing and one real Next authentication integration, Part 2K-M closed cancellation-aware execution and the absolute framework deadline, and approved Part 2K-N closed installed black-box framework interoperability.

### 2026-08-11 Phase 2 Adapter Configuration And Next.js Node Input Lessons

1. Do not infer a framework capability solely from the installed adapter implementation. The initial Next.js Proxy inspection correctly found no physical-header API there, but broader official documentation identified a separate supported Pages API Route seam with the original Node `IncomingMessage`.
2. Next.js Proxy, `NextRequest`, App Route Handlers, and `next/headers` expose Web `Headers`, not physical request fields. They cannot distinguish one comma-containing field from duplicate fields folded into the same value and therefore cannot satisfy `x-mcp-header` singleton proof.
3. Pages API Routes receive `NextApiRequest` as `http.IncomingMessage`, including `rawHeaders`, and continue to work when an application also uses the App Router. The eventual Next integration should use this Node seam rather than private Next symbols, fabricated evidence, or a custom server.
4. Public `/mcp` can later remain the external path through a reviewed internal rewrite to the generated Pages API Route. The rewrite, route file, installer changes, and body-parser configuration belong to active routing and were deliberately not added in Part 2K-J.
5. The generated Next API Route must set `config.api.bodyParser: false`. The adapter independently requires `readableDidRead: false` so an omitted or ineffective setting that actually consumed the stream crashes loudly instead of silently validating reconstructed bytes.
6. Security must precede Web stream construction at the Node boundary. Creating `Readable.toWeb` before Origin/auth validation leaves room for eager source pulling even when no Web reader has been acquired; `HttpSecurity.validateHeaders` exists so adapters can decide security from an isolated header snapshot first.
7. A Web Request with `bodyUsed: false` proves only that the Web body has not been consumed through that Request. It does not prove that an underlying Node source has never buffered or pulled data; documentation and tests must keep those claims distinct.
8. Physical header capture precedes every normalization step. Capture `rawHeaders`, reject odd arrays, and retain exact casing, multiplicity, and unsplit values before constructing Web `Headers` or a Web Request.
9. Do not invent a Host fallback at a security-sensitive adapter boundary. Missing Host is an integration invariant and crashes; substituting `localhost` would create an authority that was never present on the request.
10. Adapter security configuration is explicit and shared. Next.js, Vite, and Astro all map one public three-state callback into `Authorized`, `MissingAuthentication`, or `InsufficientAuthorization`; no package reimplements Origin parsing or 401/403 mapping.
11. `clientUrl`, Frontman's remote Phoenix `host`, request URL, incoming Host, forwarded headers, and JSON-RPC metadata are not trusted Origin allowlists or authentication context. Only explicitly configured origins enter `HttpSecurity.make`.
12. Origin is a browser/DNS-rebinding gate, not authentication. Part 2K-J supplies an adapter-owned callback seam but does not claim a real credential, session, nonce, or principal policy until an application configures and proves one.
13. Keep preparatory configuration inert. Tests cover `/mcp`, `/frontman/mcp`, custom-base aliases, and preflight and assert pass-through with unread Web bodies so adding policy objects cannot accidentally activate a transport.
14. Do not export an adapter helper merely because its internal proof exists. The Next Node adapter remains internal until the generated route, response bridge, cancellation contract, public types, and installer lifecycle define one stable API.
15. Review must challenge resource-order claims, not only returned values. The first reviewed implementation preserved raw fields but constructed `Readable.toWeb` too early; green raw-header tests did not make that ordering safe.
16. Route-independent Next input proof did not solve Vite/Astro at the Part 2K-J checkpoint. Those adapters still buffered matched bodies before core security; accepted Part 2K-K subsequently converged all three frameworks on one streaming Node/Web chassis.
17. ReScript package verification must remain serial because package builds share and clean generated artifacts. Parallel package tests produced false missing-module failures during this session; serial runs established the final evidence counts.
18. Part 2K-J is explicitly approved as the shared adapter-policy and Next.js Node-input checkpoint. Its checkpoint did not establish active routes, real authentication, preflight behavior, response/disconnect cancellation, Vite/Astro streaming, black-box interoperability, or conformance; accepted Part 2K-K subsequently closes only the route-independent streaming and transport-cancellation gaps.

### 2026-08-11 Phase 2 Shared Node/Web Chassis Lessons

1. Request adaptation, response pumping, and disconnect ownership are one lifecycle domain. Splitting them among framework adapters makes it impossible to prove that a response close aborts the matching request, cancels its reader, suppresses late output, and removes every listener exactly once.
2. The sanctioned shared boundary belongs in `frontman-core` with typed Node operations in `FrontmanBindings.NodeHttp`. Vite, Astro, and Next.js should retain only route recognition, framework configuration, and policy selection rather than maintaining transport copies.
3. Capture `IncomingMessage.rawHeaders` before creating Web `Headers`, a Web Request, or a Web body stream. Physical casing, duplicate occurrences, and comma-containing singleton values cannot be reconstructed after normalization.
4. Build the gate's Web `Headers` snapshot from the captured physical fields rather than Node's normalized header dictionary. This keeps the security view derived from the same received evidence while preserving the separate raw list for selected-schema multiplicity checks.
5. A generic adapter cannot invent physical authentication-header rules before a real authentication scheme identifies its authoritative fields. Duplicate Origin values fold into a value rejected by strict Origin parsing; recognized `Mcp-Param-*` multiplicity remains separately enforced from raw evidence. Do not overstate this as complete real authentication.
6. Require exactly one nonempty physical Host field for Web Request URL construction. A hidden `localhost` fallback fabricates request authority and turns an integration defect into accepted input.
7. Security must complete before `Readable.toWeb`. Node's Web-stream conversion may pull eagerly, so merely delaying `getReader` or observing `bodyUsed: false` does not prove that a rejected source remained untouched.
8. An asynchronous gate must participate in cancellation just like dispatch. A client can disconnect while authorization is pending; the chassis must return `Cancelled` without constructing a body or waiting for the gate to settle.
9. Race cancellation against uncooperative gate and dispatch promises, but keep the losing promise observed. Prompt return without an observer trades a hung request for an unhandled late rejection, which is not an improvement despite wearing a smaller hat.
10. One idempotent cancellation owner must handle both Node request `aborted` and response `close`. The first terminal event aborts the Web signal, destroys the Node source, initiates response-reader cancellation, resolves a pending drain wait, and suppresses later output; repeated events do nothing.
11. Listen to request `aborted`, not generic request `close`. Node request close can occur during ordinary lifecycle completion and is not sufficient evidence of client cancellation.
12. Remove the response-close listener before calling `ServerResponse.end` on successful completion. Node may emit `close` as part of the normal end lifecycle; leaving ownership installed would misclassify success as cancellation and destroy an already completed request.
13. Cancellation cannot depend on an untrusted reader-cancellation promise settling. Initiate `reader.cancel`, observe and report rejection, but let the request reach its terminal cancellation outcome even when the underlying source's cancellation promise never resolves.
14. Response bodies are bytes, not text. Astro's former `TextDecoder` bridge could corrupt arbitrary bytes or mishandle split multibyte sequences. The shared chassis writes each `Uint8Array` directly.
15. Node backpressure is a correctness and memory-bound requirement. When `ServerResponse.write` returns `false`, stop reading until `drain`; if response close wins, resolve the wait as cancellation, remove the drain listener, and emit no ending.
16. Reader locks and Node listeners require one cleanup path for success, denial, pass-through, cancellation, read failure, and dispatch failure. Focused assertions on listener counts are stronger than assuming garbage collection will eventually clean up the crime scene.
17. A partial streamed response cannot be replaced with a fresh HTTP 500. Review found Vite's outer error handler always rewrote status and ended with an error body; it now matches Astro by sending the fixed 500 only before headers and otherwise only ending the existing response.
18. Adapter tests must exercise the real chassis delegation path. Direct tests of adapter-local `physicalHeaders` helpers duplicated the raw-header parser's unit tests and did not prove capture order or propagation, so those helpers and tests were removed.
19. Route guards remain outside the chassis. Inactive `/mcp` requests must call the next framework handler without raw-header parsing, Web Request construction, body reads, middleware dispatch, or response writes.
20. Moving existing private Vite/Astro routes from buffered bodies to streaming Web Requests is acceptable only with focused compatibility evidence. Tests assert middleware receives `bodyUsed: false`, can read the exact original body, receives physical headers, and preserves pass-through behavior.
21. At the Part 2K-K checkpoint, transport cancellation ownership was not yet tool cancellation. Part 2K-M now passes the chassis signal into selected tool execution and stops owned child processes cooperatively; filesystem effects already committed before cancellation remain non-transactional.
22. Route-independent transport proof is not active endpoint proof. At the Part 2K-K checkpoint generated Next Pages routing, `bodyParser: false`, rewrites, Vite/Astro route registration, preflight and 405 policy, real authorization, sibling-path policy, active-boundary no-side-effect tests, black-box parity, and official conformance remained mandatory. Parts 2K-L and 2K-M subsequently close active routing, focused active-boundary behavior, cancellation-aware execution, and deadline ownership; approved Part 2K-N closes installed real-process black-box parity and corrects Next routing ownership; approved Part 2K-O closes the non-MCP source-location sibling-path policy. The applicable official conformance checkpoint was subsequently accepted on `2026-08-16`.
23. ReScript package verification must remain serial because shared generated artifacts race under parallel clean/build operations. Final evidence came from serial core, Next.js, Astro, and Vite runs.
24. The repository root formatter is the usable formatter for tracked ReScript files. Astro and Vite package format targets still pass directory arguments rejected by the installed formatter, and the root target does not include untracked files; this tooling limitation must not be mistaken for a protocol failure or silently omitted from verification notes.
25. The tracked-source comment gate enumerates Git files, so newly created untracked authored source requires an explicit scanner invocation until staged. Part 2K-K manually scanned the new chassis and adapter test files in addition to running the repository gate.
26. Independent review should challenge failure paths and nonsettling resources, not just happy-path streaming. This session's review caught partial-response corruption risk and drove explicit vectors for uncooperative gates, late gate rejection, nonsettling reader cancellation, normal end/close ordering, and redundant helper removal.
27. Part 2K-K is explicitly approved as the shared route-independent Node/Web chassis checkpoint. Approval freezes one transport owner, exact-byte response streaming, backpressure, and adapter cancellation semantics. Parts 2K-L and 2K-M subsequently close active-route and cancellation-aware-execution requirements without changing that historical checkpoint.

### 2026-08-11 Phase 2 Active Endpoint Lessons

1. Active method policy must be owned once in the shared endpoint, not reconstructed independently by adapters. POST, OPTIONS, unsupported methods, CORS, execution, and invariant failures need one typed decision domain so framework packages cannot drift.
2. Preserve the raw Node HTTP method decision across Web adaptation. Fetch can canonicalize method spelling, so dispatching from `Request.method` can turn a raw lowercase `post` into an accepted `POST`. The gate now carries `Post`, `Preflight`, or `Unsupported` and lowercase methods remain authenticated 405 requests.
3. Preflight is an Origin decision, not an ordinary authenticated MCP request. Browser preflight does not carry the eventual credential, so OPTIONS validates exact Origin, requested POST method, and requested headers without invoking the application authorization callback.
4. Origin-only preflight does not weaken POST security. Every non-OPTIONS request still performs exact Origin validation and one isolated application authorization decision before `Readable.toWeb`, media policy, body access, parsing, or execution.
5. Authorization must run exactly once. Running it in the chassis gate and again inside `HttpRequest` can make stateful credentials disagree and breaks the proof that one accepted principal authorized one request. `validateAfterSecurity` consumes the validated Origin and begins at media policy.
6. CORS variance is security state. Invalid-Origin responses vary on Origin, and every accepted or rejected preflight varies on Origin, `Access-Control-Request-Method`, and `Access-Control-Request-Headers`; otherwise a shared cache can replay one authority decision for another request.
7. Preflight header policy needs explicit boundaries. The active endpoint accepts required MCP headers, `Authorization`, any syntactically named `Mcp-Param-*` request field, and explicitly configured application headers; unknown application headers fail closed with an empty Origin-bearing 400.
8. Unsupported HTTP methods are not unsupported JSON-RPC methods. After Origin and authorization, non-POST/OPTIONS HTTP methods return empty 405 with `Allow: POST, OPTIONS`; an unsupported JSON-RPC method inside a valid POST remains HTTP 404/`-32601` after complete request validation.
9. Route activation remains explicit. Vite and Astro register exact case-sensitive `/mcp` only when `mcp` security configuration exists. Missing configuration, `/mcp/`, case variants, private `/frontman/mcp`, and custom-base aliases are not silently activated.
10. Next.js must use the documented Pages API Node seam. Proxy and App Route Web Headers cannot prove raw multiplicity, so public `/mcp` uses an installer-owned server rewrite to a generated internal Pages API route that disables body parsing and delegates to exported `createMcpHandler` while keeping the low-level Node adapter internal. Part 2K-N proved Proxy cannot own or pass through the MCP request because it consumes the POST stream.
11. Generated authentication must be real configuration, not an always-authorized sample. The Next route requires `FRONTMAN_MCP_ALLOWED_ORIGINS` and `FRONTMAN_MCP_TOKEN`, rejects missing values at startup, and compares the complete bearer credential with `timingSafeEqual` after a length check.
12. Installer validation cannot be substring security. A string in a comment, an unrelated object, or a partial API route does not prove a safe route. Part 2K-N supersedes the middleware/Proxy rewrite rule: those files must not own `/mcp`, the generated Pages API route must own the default handler with body parsing disabled, and `next.config` must contain the body-preserving `/mcp` to `/api/frontman-mcp` server rewrite.
13. Cached LLM installer output is still untrusted generated source. Cached edits pass the same structural validator as fresh model output before reuse; an old cache entry cannot bypass newly tightened installation rules.
14. Existing generated-route detection must prove both handler ownership and body policy. `createMcpHandler` must supply the default export and exported `config.api.bodyParser` must be false. Partial files require manual repair rather than overwrite, skip, or a false success report.
15. Installer tests must cover rerun and malformed-existing-file behavior, not only clean generation. A generated file that looks vaguely MCP-ish but leaves Next body parsing enabled is worse than no route because it fails only after deployment reaches the stream invariant.
16. Active adapter tests and real-process black-box tests are different evidence. Focused package tests prove the actual adapter path, configured-only route guard, one authorization decision, body consumption, and response ownership; approved Part 2K-N later proves installed server routing, the absence of Proxy from the MCP body path, disconnect recovery, deadlines, and interoperability over sockets.
17. At the Part 2K-L checkpoint, transport cancellation was not yet tool cancellation. Part 2K-M now passes the exact chassis signal through `FrontmanCore__Server.executionContext`, checks it before and after selected execution, and terminates owned child processes cooperatively.
18. Absolute deadlines remain independent of body idle deadlines and disconnect cancellation. Part 2K-M assigns the immutable ten-minute active-framework deadline to the shared chassis from Node ingress through response commitment and proves exact-limit and over-limit races.
19. ReScript package verification must be serial. A parallel core/Next run reproduced shared generated-artifact cleanup races and false missing-module failures. The final package counts come only from serial reruns.
20. Formatting new untracked ReScript files needs direct package formatting because the root formatter enumerates tracked Git files. The final gate used direct `frontman-core` formatting and check in addition to the root formatting workflow.
21. Structural traceability verification does not detect semantic staleness. This slice passed all `443` structural requirements while current prose still called `/mcp` unreachable and route activation future work; targeted current-state searches remain mandatory after every slice.
22. Independent review must follow findings through generated source and installer lifecycle. Review successively found raw-method canonicalization, incomplete preflight variance, weak LLM-output checks, weak existing-route checks, and comment-based false positives before final PASS.
23. Part 2K-L is explicitly approved as the active JavaScript framework endpoint checkpoint. Approval freezes exact configured routing, one security decision, preflight/405 policy, synchronous JSON execution, generated Next Node routing, and installer validation while leaving Phase 2 acceptance gates open.

### 2026-08-12 Phase 2 Cancellation And Deadline Lessons

1. Transport cancellation and tool cancellation need one signal identity. Creating a second controller in the endpoint or tool executor would split ownership and make it impossible to prove that the Node disconnect or deadline stopped the selected work.
2. Keep lifecycle context out of protocol-validation values when the lifecycle owner still has it. `Endpoint.dispatch` already owns the adapted signal after `HttpRequest` validation, so adding it to decoded request types would mix transport state into the wire-domain pipeline for no gain.
3. A required tool-context signal is safer than an optional signal. Optional cancellation lets active framework tools silently execute without lifecycle ownership; legacy request paths can and should pass their real Fetch request signal.
4. Check cancellation both before invocation and after tool completion. The first check prevents already-cancelled work from starting; the second prevents a tool that ignored cancellation and returned late from becoming a successful result.
5. Do not map an abort-related tool rejection to an ordinary execution error after the signal is aborted. Cancellation is transport lifecycle, not a business/API failure and not a `Tool execution failed` result.
6. Disconnect and timeout cannot share one boolean `cancelled` state. Disconnect must suppress all output and destroy the request, while timeout must stop work yet preserve enough response ownership to emit one empty 408.
7. Publish the terminal reason before aborting the controller. Abort listeners run synchronously and can reject the raced promise before the terminal promise wins; without explicit terminal-state recovery, a normal cancellation becomes an adapter exception.
8. Observing a losing promise is necessary but not sufficient. The race must also classify a rejection that occurs after terminal state changes as the established cancellation/timeout outcome, while rethrowing the same rejection if the lifecycle is still active.
9. Absolute deadline semantics require a monotonic post-race check as well as a timer. Event-loop ordering can let work settle after the deadline before the timer callback runs; the lifecycle must compare the actual monotonic time before accepting a race winner.
10. Response creation is not response commitment. Assigning status and headers on a Node response object does not prove bytes reached the socket; clearing the deadline there permits a body stream that never yields to hang forever.
11. The first Node body write commits a nonempty response. An empty response commits only when normal completion owns `end`. Keep the timer armed while waiting for the first body bytes, and let timeout replace uncommitted status/header state with the empty 408.
12. A timeout timer belongs only on the active MCP route unless another endpoint explicitly adopts the same policy. Applying it to the shared chassis unconditionally would silently change private legacy and source-location behavior.
13. Sending `SIGTERM` is not proof that work stopped. A child-process promise must settle after `close`, not immediately after `kill`, and tests must prove a scheduled external side effect never occurs after reported cancellation.
14. Max-buffer termination is another cancellation lifecycle. It must wait for process closure just like request abort; otherwise callers can begin follow-up work while the killed process remains alive.
15. A child process can emit `error` before `close`. Preserve that error category, but settle on `close` so abort, max-buffer, spawn-error, and exit races still have one terminal point and listener cleanup.
16. Once termination begins, stop accumulating stdout and stderr. Continued buffering after a max-buffer kill defeats the memory limit while waiting for process closure.
17. Cooperative cancellation is not transactional rollback. A signal can stop future reads, subprocess work, and uncommitted execution, but it cannot undo filesystem or business side effects already committed before cancellation.
18. Focused fake-time tests must cover exact limit, one millisecond over, stalled response bodies, synchronous abort-aware rejection, late completion, one response ending, and timer cleanup. Happy-path timeout tests alone miss the ordering defects found in review.
19. Independent review should follow cancellation through the lowest resource owner. Reviewing only the chassis would have missed child processes settling before close and sibling max-buffer paths with the same defect.
20. Historical checkpoint prose should remain historical, but current summaries, checklists, implementation tables, next-slice text, and proof gates must name the superseding Part 2K-M behavior explicitly.

### 2026-08-12 Phase 2 Real-Process Framework Lessons

1. Focused adapter tests and real framework processes prove different things. A mocked `IncomingMessage` can prove raw-header capture and untouched adaptation at the Pages API seam, but it cannot prove that a framework rewrite or Proxy preserves that message before it reaches the seam.
2. Next Proxy is not a transparent routing layer for streaming POST bodies. Rewriting or passing through `/mcp` from Proxy consumed the source before the Pages API handler, so security-sensitive streaming transport must use a server-level rewrite that leaves Proxy and middleware out of the path.
3. A generated route is only as sound as every generated hop. Installer acceptance must exercise the exact generated config, route file, public path, package export, and real framework server; validating each template independently allowed an invalid composition to look safe.
4. Next config ownership needs a narrow safe-edit policy. Creating a missing `next.config.mjs` and replacing the common exact `const nextConfig = {};` shape are reviewable; arbitrary config merging is not. Unknown shapes require explicit manual repair rather than regex acrobatics or LLM edits.
5. Middleware and Proxy auto-edit instructions must match their runtime contracts. Asking an LLM to add the unsupported Proxy `runtime` field or MCP rewrite recreates a defect even when clean templates are correct. Generated-source prompts, cached output validation, fixtures, and manual instructions are one product surface.
6. Package exports, not source files, are the black-box subject. Rebuild publishable adapters before launching fixtures so stale bundles cannot make source tests green while shipped behavior differs.
7. Framework default middleware can preempt application security. Vite and Astro development CORS answered OPTIONS before Frontman's endpoint, so adapter activation must control middleware ordering and disable conflicting framework CORS when explicit MCP security owns the route.
8. Disabling framework-wide development CORS is acceptable only when conditional on explicit MCP configuration and backed by application regression tests. Missing `mcp` configuration retains the framework default and leaves `/mcp` untouched.
9. Real-process deadline proof should not make CI sleep for ten minutes. Accelerate only the frozen maximum-duration timer in isolated child processes, keep ordinary requests on real time, and retain focused monotonic fake-time tests as the authority for exact boundary ordering.
10. Controlled time is evidence for wiring, not a replacement for boundary tests. The socket suite proves every adapter arms the deadline and emits one empty 408; the chassis tests prove exact-limit commitment, one-millisecond-over expiry, timer cleanup, and late-result suppression.
11. HTTP framing is not response content. A terminal chunk on an empty chunked response must be decoded before body assertions, or a correct Next response appears to contain five bytes.
12. A disconnect test must prove recovery, not merely local socket closure. After destroying the request socket, issue another complete MCP request and require success so listener leakage, process failure, and connection-wide cancellation become visible.
13. Route-alias tests must assert rejection status. Absence of `Access-Control-Allow-Origin` alone does not prove the route was inactive; an unrelated successful handler could omit CORS and still satisfy that weak assertion.
14. Framework route normalization is an implementation limit, not something tests should disguise. Next server rewrites normalize case and trailing slashes; record the difference and exclude it from exact-alias claims rather than introducing a body-consuming interception layer solely to force parity.
15. Test process ownership includes teardown. Signal the child, wait for its actual exit, escalate only if needed, and restore fixture files afterward. Cleanup that merely calls `kill` can race a still-running dev server and contaminate later tests.
16. A no-secrets protocol suite should remain independent of product E2E infrastructure. MCP adapter parity needs framework binaries and loopback sockets, not Phoenix, PostgreSQL, browser automation, OAuth fixtures, or provider credentials.
17. Source-comment, traceability, and formatting gates can pass while semantic status is stale. Search the plan for every old black-box blocker, next-step statement, checklist item, proof paragraph, and implementation-order entry after acceptance.
18. Real-process synchronous JSON parity does not prove emitted SSE or post-commit streaming. Do not create a test-only streaming producer or public tool-injection API merely to make the matrix look complete; add active streaming black-box vectors with the real feature that introduces streaming.
19. Child-process cancellation and process-tree cancellation are not identical. Waiting for the immediate child `close` proves that owned process stopped, but shell pipelines may have descendants; process-group semantics need explicit implementation and side-effect tests before claiming complete tree termination.
20. Part 2K-N is explicitly approved as the installed JavaScript framework parity checkpoint. It freezes the shared real-process contract, body-preserving Next server routing, framework CORS ordering, controlled deadline wiring, no-secrets CI ownership, and the stated limits without accepting the broader Phase 2 migration.

### 2026-08-12 Phase 2 Source-Location Security Lessons

1. A security-sensitive sibling route must have its own protocol boundary. Reusing MCP `Endpoint` would impose JSON-RPC, mirrored headers, dual Accept negotiation, and method semantics that `/frontman/resolve-source-location` neither speaks nor needs.
2. Sharing a primitive does not mean sharing a policy. Source location correctly reuses canonical Origin parsing, CORS response helpers, media parsing, and bounded body decoding while retaining a separate decision owner and response contract.
3. Origin validation and authentication solve different problems. The source-location browser caller has no MCP bearer token; calling the MCP authorization callback would break it, while accepting wildcard Origin would preserve the DNS-rebinding disclosure. This slice therefore freezes Origin-only access without credential permission.
4. Origin-only access must not become credentialed CORS accidentally. Omitting `Access-Control-Allow-Credentials` is part of the policy, not an incidental missing header, and focused tests must preserve that absence.
5. Missing security configuration must fail closed at the endpoint. Optional adapter configuration cannot mean a return to wildcard CORS; it means every source-location request receives an empty 403 until an allowlist exists.
6. Preflight has a smaller authority than POST. It validates Origin, requested POST method, and only `Content-Type`; it neither invokes MCP authorization nor accepts `Authorization`, MCP standard headers, or custom `Mcp-Param-*` fields.
7. Media policy precedes body ownership on non-MCP JSON routes too. Returning 415 before touching hostile bytes provides the same resource-order guarantee without pretending the response is an MCP transport error.
8. Shared bounded decoding should be factored below protocol interpretation. The MCP decoder was reusable because it returns arbitrary JSON and preserves typed body failures before JSON-RPC classification; source location can consume it without importing MCP wire semantics.
9. Replacing `Request.json` closes more than malformed-JSON 500s. It also centralizes byte, chunk, idle, UTF-8, nesting, cancellation, and lock-release limits that an endpoint-local try/catch would miss.
10. Client-visible error categories must not include source-resolution exceptions. Resolver failures can contain absolute paths and implementation diagnostics; fixed categories prevent the endpoint from becoming a filesystem oracle.
11. Adapter inheritance needs an explicit precedence rule. Reusing the MCP allowlist is a safe default because it is already explicit, while `sourceLocation.allowedOrigins` permits a narrower browser surface and must win when supplied.
12. Next's MCP handler and browser middleware are separate generated owners. Configuring only the generated Pages API route does not configure the source-location middleware; templates, manual instructions, environment inputs, public types, and tests all need the same policy wiring.
13. Runtime ReScript types do not prove the published TypeScript API. Independent review caught missing checked-in Next and Astro declarations after all package tests were green; declaration review is mandatory for every public config addition.
14. Package config tests must prove derived policy, not merely input acceptance. The required vectors are inherited allowlist, explicit override, malformed configured Origin, and no attacker-controlled authority derivation.
15. A passing core endpoint suite is not sufficient adapter evidence. The policy has to survive each package's config conversion and generated/manual integration surfaces before the sibling path is considered closed.
16. Historical baseline prose should stay identifiable as history, but current summaries, checklists, implementation records, proof gates, and next-slice text must name Part 2K-O explicitly. Structural traceability checks cannot catch this semantic drift.
17. Independent review again paid rent. It found both a direct information disclosure and public integration gaps that compilation and focused runtime tests did not reveal.
18. Part 2K-O is explicitly approved as the JavaScript framework source-location security checkpoint. It freezes the separate non-MCP Origin/CORS/media/body policy and adapter configuration contract without claiming WordPress source-location support or broader Phase 2 acceptance.

## Governing Implementation Rules

These rules apply to every phase and override narrower checklist wording:

1. Fix every repository instance of a defect or changed pattern in the same atomic migration. Search `apps/`, `libs/`, `test/`, `scripts/`, `.github/`, generated artifacts, installer templates, fixtures, and documentation before declaring a pattern complete.
2. Solve behavior at the lowest shared layer used by every affected path. Reuse existing protocol, registry, execution, persistence, channel, adapter, and test helpers before adding another abstraction.
3. Replace legacy code in place wherever practical. Do not create a parallel modern contract, broker, transport stack, compatibility module, feature flag, or fallback when the migration can update the existing owner and delete obsolete code.
4. Keep framework packages independent except for sanctioned shared chassis. Protocol-neutral Node/Web request bridging belongs in shared bindings or core chassis; framework routing, registries, and behavior remain package-local.
5. Do not implement optional MCP features without a current caller. Accept required interoperable inputs, but do not advertise or build production machinery for progress, MRTR, emitted SSE, subscriptions, catalog pagination, or optional capabilities until Frontman uses them.
6. Leave no comments in tracked authored repository source: no source comments, docblocks, TODO/FIXME notes, lint/type suppressions, or commented-out code. Platform-required executable directives remain only where the runtime or toolchain consumes their comment syntax and no comment-free equivalent exists; current approved forms are interpreter shebangs, the leading WordPress plugin metadata header, and TypeScript triple-slash reference directives. Standalone prose, licenses, protocol examples, and immutable data are not source comments. Generated artifacts and build outputs are outside this comment policy and may contain comments. Do not vendor upstream source files that contain comments. Complete repository-wide authored-source comment removal as a separate prerequisite change before protocol implementation, then enforce a repository-wide zero-comment gate throughout the migration.
7. Preserve rationale in commits, pull requests, tests, traceability documents, and this plan rather than source comments.
8. Every phase ends with deletion of superseded code and a repository-wide search for sibling patterns. A phase is incomplete while legacy branches or equivalent unfixed call sites remain.

## Authoritative Standard

The official `2026-07-28` specification and schema are the source of truth. Frontman-generated schemas and types are implementation artifacts, not independent evidence of compliance.

### Primary References

- Release announcement: https://blog.modelcontextprotocol.io/posts/2026-07-28/
- Specification index: https://modelcontextprotocol.io/specification/2026-07-28
- Changelog from `2025-11-25`: https://modelcontextprotocol.io/specification/2026-07-28/changelog
- Base protocol: https://modelcontextprotocol.io/specification/2026-07-28/basic
- Versioning and compatibility: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning
- Architecture: https://modelcontextprotocol.io/specification/2026-07-28/architecture
- Schema reference: https://modelcontextprotocol.io/specification/2026-07-28/schema
- Authoritative TypeScript schema pinned by immutable URL and checksum but not vendored because its source comments would violate the repository rule: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts
- Generated JSON Schema used for validation tooling: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.json
- Official conformance project: https://github.com/modelcontextprotocol/conformance
- Documentation index: https://modelcontextprotocol.io/llms.txt

### Transport References

- Transport overview and custom transports: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports
- Streamable HTTP: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http
- Standard input/output transport: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio
- Cancellation: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation
- Progress: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/progress
- Subscriptions: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions

### Framework Transport Research

- Next.js Proxy API and runtime: https://nextjs.org/docs/app/api-reference/file-conventions/proxy
- NextRequest Web API surface: https://nextjs.org/docs/app/api-reference/functions/next-request
- Next.js App Route Handler request surface: https://nextjs.org/docs/app/api-reference/file-conventions/route
- Next.js Pages API Routes and `bodyParser: false`: https://nextjs.org/docs/pages/building-your-application/routing/api-routes
- Pages and App Router coexistence: https://nextjs.org/docs/app/guides/migrating/app-router-migration
- Next.js internal rewrites: https://nextjs.org/docs/pages/api-reference/config/next-config-js/rewrites
- Next.js custom-server alternative rejected for the initial integration: https://nextjs.org/docs/app/guides/custom-server
- Vercel `mcp-handler` Web-handler precedent, which does not supply physical header multiplicity: https://www.npmjs.com/package/mcp-handler

### Server Feature References

- Server discovery: https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- Tools: https://modelcontextprotocol.io/specification/2026-07-28/server/tools
- Caching: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching
- Pagination: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/pagination
- Resources: https://modelcontextprotocol.io/specification/2026-07-28/server/resources
- Prompts: https://modelcontextprotocol.io/specification/2026-07-28/server/prompts
- Logging: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/logging

### Interaction And Extension References

- Message pattern overview: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns
- Multi Round-Trip Requests (MRTR): https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr
- Elicitation: https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation
- Extensions overview: https://modelcontextprotocol.io/extensions/overview
- Tasks extension: https://modelcontextprotocol.io/extensions/tasks/overview
- MCP Apps extension: https://modelcontextprotocol.io/extensions/apps/overview
- Deprecated features: https://modelcontextprotocol.io/specification/2026-07-28/deprecated
- Feature lifecycle policy: https://modelcontextprotocol.io/community/feature-lifecycle

### Authorization And Security References

- Authorization: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization
- Authorization server discovery: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery
- Client registration: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration
- Authorization security considerations: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations
- Security best practices: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices
- Authorization tutorial: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/authorization

### Relevant Specification Enhancement Proposals

- SEP-2106, JSON Schema 2020-12: https://modelcontextprotocol.io/seps/2106-json-schema-2020-12
- SEP-2133, Extensions: https://modelcontextprotocol.io/seps/2133-extensions
- SEP-2243, HTTP header standardization: https://modelcontextprotocol.io/seps/2243-http-standardization
- SEP-1302, input validation errors as tool execution errors: https://modelcontextprotocol.io/seps/1302-input-validation-errors-as-tool-execution-errors
- SEP-2322, Multi Round-Trip Requests: https://modelcontextprotocol.io/seps/2322-MRTR
- SEP-2549, caching TTL: https://modelcontextprotocol.io/seps/2549-TTL-for-list-results
- SEP-2567, sessionless MCP: https://modelcontextprotocol.io/seps/2567-sessionless-mcp
- SEP-2575, stateless MCP: https://modelcontextprotocol.io/seps/2575-stateless-mcp
- SEP-2577, deprecating Roots, Sampling, and Logging: https://modelcontextprotocol.io/seps/2577-deprecate-roots-sampling-and-logging
- SEP-2596, feature lifecycle and deprecation: https://modelcontextprotocol.io/seps/2596-spec-feature-lifecycle-and-deprecation
- SEP-2663, Tasks extension: https://modelcontextprotocol.io/seps/2663-tasks-extension
- SEP-414, OpenTelemetry request metadata: https://modelcontextprotocol.io/seps/414-request-meta

## Current Architecture And Gaps

The product has two MCP runtime boundaries. The shared/custom-Phoenix wire semantics have completed Phase 1, browser request lifecycle and hard execution capacity are accepted in Phase 4, accepted Phase 5 owns transient custom-Phoenix work connection-wide, accepted Phases 6 and 7 own durable claim, deadline, restart, cancellation, completion, and replay authority for the supported single-node Phoenix deployment, browser-to-framework communication uses `/mcp` for JavaScript frameworks and WordPress, and application readiness/question ownership is accepted. Semantic-review remediation, credentialed installed E2E, server precommit `828/828`, and the complete aggregate pass; whole Phases 2 and 3 are explicitly accepted:

```text
Phoenix server acting as MCP client
    |
    | JSON-RPC carried by Phoenix event `mcp:message`
    v
Browser acting as MCP server
    |
    | MCP 2026-07-28 Streamable HTTP POST /mcp
    v
Next.js / Astro / Vite / WordPress framework integration
```

The following list is the pre-migration baseline that motivated the plan, not a current-state inventory. Phase 1 corrected the shared/custom-Phoenix wire items. Approved Phase 2 JavaScript slices implement active secured `/mcp`, cancellation/deadline ownership, installed real-process parity, and source-location sibling security. The approved WordPress slice implements its authenticated synchronous `/mcp` endpoint and removes private WordPress Relay routing/SSE. The approved Phase 3 core slice implements browser Streamable HTTP wire behavior, the accepted application slice fixes ACP readiness and browser-local question lifecycle, and accepted Phase 9 completes canonical persistence, content/media limits, durable output-schema validation, server schema safety, and logging redaction. Remaining current defects are tracked by the status table, package checklists, later phases, and implementation order below:

- Phoenix advertises `DRAFT-2025-v3`.
- ReScript advertises `2025-11-25`.
- The peers perform `initialize` and `notifications/initialized`.
- Requests omit required per-request `_meta` protocol fields.
- Successful results omit required `resultType`.
- The browser does not implement mandatory `server/discover`.
- `tools/list` omits `ttlMs`, `cacheScope`, and pagination behavior.
- `tools/call` requires nonstandard `callId`.
- Tool definitions expose unnamespaced `access`, `visibleToAgent`, and `executionMode` fields.
- `structuredContent` accepts only JSON objects, not arbitrary JSON values.
- Framework endpoints are a custom relay, not Streamable HTTP MCP.
- The legacy framework Relay tool endpoints still use wildcard CORS; active `/mcp` and the source-location sibling now use explicit Origin policies.
- Cancellation does not terminate browser or framework work.
- Multiple task channels can execute the same side-effecting tool call.
- Tool-result conversion does not support every standard MCP content type.
- Tool-result persistence strips modern lifecycle fields and metadata before history replay.
- Historical tool-result reconstruction repeats the empty-content, text/image-only, and raising Base64 behavior found in live execution.
- MCP and relay behavior also remains embedded in generated Phoenix browser-test assets, installer fixtures, CI path filters, and framework-specific route consumers.

## Detailed Historical Implementation Audit

This section records the repository research that produced the migration plan. Its line references and present-tense statements describe the pre-migration baseline and are not current implementation evidence.

The audit below remains the pre-migration baseline. Accepted Phase 1 behavior and current Phase 2 foundations are recorded in their implementation records rather than rewriting historical findings as if the complete atomic migration were already released.

### Phoenix And Elixir Findings

#### Protocol construction

`apps/frontman_server/lib/model_context_protocol.ex` is the Phoenix-side MCP protocol helper.

- Line 27 advertises the nonstandard version `DRAFT-2025-v3`.
- Lines 75-86 construct legacy initialization parameters.
- Lines 94-107 parse only the existing result conventions.
- Lines 109-123 construct `tools/call` with integer JSON-RPC IDs and required `params.callId`.
- Lines 115-122 log complete tool arguments at normal information level, potentially exposing source, credentials, user content, or tokens.

`apps/frontman_server/lib/json_rpc.ex` provides generic JSON-RPC parsing and construction.

- Lines 82-133 parse result and error responses.
- Lines 142-188 build responses, errors, notifications, and requests.
- Current runtime tool response routing accepts only integer IDs even though shared protocol parsing recognizes strings.
- Invalid MCP responses currently cause the channel to send a nonstandard notification whose method is `error` instead of resolving or failing the pending request locally.

#### Historical legacy initialization state machine

Before accepted Phase 5 deleted it, `apps/frontman_server/lib/frontman_server_web/channels/task_channel/mcp_initializer.ex` owned the legacy handshake.

- Lines 36-57 send `initialize` and establish connection-scoped state.
- Lines 59-110 correlate initialization responses and errors.
- Lines 112-130 send `notifications/initialized` followed by `tools/list`.
- Lines 132-140 convert the first tools page and ignore `nextCursor`.
- Lines 149-196 call `load_agent_instructions` as an initialization step.
- Lines 198-257 call `list_tree` as an initialization step.
- Lines 272-295 emit `mcp_initialization_complete` and mark the task channel ready.
- There is no deadline for any initialization request.
- Response maps and individual tool definitions are not validated against the shared or official schemas before use.
- Project-rule list members and workspace members can trigger pattern-match or map-operation failures when malformed.

Accepted Phase 5 removed this module. Project-context loading is now bounded ordinary application work after discovery.

#### Historical task channel transport and request correlation

Before accepted Phase 5, `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex` combined ACP session work, MCP client state, MCP transport, discovery, recovery, and execution routing.

- Lines 38-75 create a separate MCP session and pending-request map for every joined task channel.
- Lines 118-140 parse browser responses and send the nonstandard `error` notification for invalid responses.
- Lines 143-148 push the deferred legacy initialization request.
- Lines 163-185 receive task interactions through PubSub.
- Lines 222-258 route every MCP-classified persisted `ToolCall` received by that channel to the browser.
- Lines 345-405 distinguish initialization responses from tool responses and correlate integer request IDs.
- Lines 408-445 persist successful tool results and publish ACP updates.
- Lines 475-540 handle JSON-RPC errors and convert them to tool errors.
- Lines 898-905 refuse to wake the agent while MCP initialization remains pending.
- Lines 922-967 apply initialization completion or failure.
- Lines 969-999 redispatch unresolved tool calls after reconnect.
- Lines 1001-1026 build and remember `tools/call` requests.

Because Phoenix automatically subscribes each channel process to its topic, every task channel receives task PubSub interactions. `apps/frontman_server/lib/frontman_server/tasks.ex:249-264` broadcasts persisted interactions to that topic. Multiple joined channels therefore execute the same side-effecting MCP tool. The unique tool-result database constraint deduplicates persistence only after external effects have already occurred.

The pending map stores only `request_id => tool_call_id`. It does not record request kind, method, owner, deadline, cancellation state, or enough bounded recent-ID state to reject duplicate and late responses.

#### Tool execution and persistence

The bullets in this subsection preserve the pre-migration defect inventory. The approved `2026-08-12` canonical persisted-result delta supersedes the result-validation, empty-content, content-conversion, and historical-reconstruction defects below. Accepted Phase 9 subsequently removes sensitive argument, decoder-diagnostic, catalog-error, and project-context-error logging; accepted Phase 7 subsequently closes durable timeout survival.

`apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex` bridges LLM tool calls to MCP execution.

- Lines 131-143 register the waiting executor before publishing the MCP tool call.
- Lines 145-190 persist timeout and sibling-cancellation outcomes.
- Lines 193-207 convert only text and image content into model tool-result content.
- Lines 209-227 use a node-local Registry to connect persisted results to the waiting executor.
- Lines 238-249 log the first 500 bytes of malformed arguments, creating a second sensitive-payload logging path beyond the normal MCP call log.

Timeout handling does not notify the MCP transport, remove the channel's pending correlation entry, abort browser execution, or abort a framework HTTP request.

`apps/frontman_server/lib/frontman_server/tasks/execution.ex` delivers recorded results.

- Lines 142-154 only notify a waiting executor when `content` is a non-empty list of maps.
- A valid `content: []` result is persisted but reported as having no executor.
- Lines 156-164 synchronously map each content block before delivery.
- Lines 241-244 support only text and image.
- Audio, resource links, and embedded resources trigger a function-clause failure.
- Invalid image Base64 raises through `Base.decode64!/1`.

`apps/frontman_server/lib/frontman_server/tasks/interaction.ex` persists results and reconstructs historical model messages.

- Lines 920-935 retain only `content`, `structuredContent`, and `isError`, replace `_meta`, and discard modern fields such as `resultType`.
- Lines 1133-1140 accept only non-empty content, so a persisted valid `content: []` result cannot be reconstructed.
- Lines 1170-1174 duplicate the text/image-only conversion and raising Base64 decode used by live delivery.
- Persistence, live executor delivery, historical reconstruction, ACP presentation, and model conversion therefore need one canonical validated result representation rather than separate partial converters.

Current state: `FrontmanServer.Tasks.CanonicalToolResult` and `Interaction.ToolResult.changeset/2` now provide that representation. Complete results are validated before persistence; all standard blocks, empty content, explicit structured null, open fields, and historical error state have focused live/replay/model proof. The one-time migration owns valid legacy rows and fails loudly on malformed rows.

`apps/frontman_server/lib/frontman_server/tasks.ex` persists and resolves tool interactions.

- Lines 665-673 persist client-handled tool calls and broadcast them.
- Lines 686-734 persist results before notifying a waiting executor.
- Lines 708-725 deduplicate repeated result persistence.
- Lines 754-780 locate unresolved active-run tool calls for reconnect.

Persist-before-notify protects durability, but malformed yet persisted content can repeatedly fail delivery. Result schema validation must happen before persistence or produce a canonical protocol-error result that is itself safe to persist.

#### Tool discovery conversion

`apps/frontman_server/lib/frontman_server/tools/mcp.ex` converts browser tool definitions into agent tools.

- Lines 12-20 define the reduced internal tool representation.
- Lines 22-47 derive local timeout policy from the nonstandard `executionMode` field.
- Lines 28-40 accept missing or malformed tool fields without upstream-schema validation.
- Lines 54-56 map every returned entry.
- Lines 58-72 filter hidden tools and create Swarm tools.

At the pre-migration baseline the parser dropped standard fields such as title, icons, annotations, and metadata and accepted arbitrary `inputSchema` and `outputSchema` values without proving JSON Schema validity. Current catalog state preserves the standard definition and accepted Phase 9 compiles input/output schemas with bounded JSON Schema 2020-12 validation before admitting each tool.

#### Phoenix tests affected

- `apps/frontman_server/test/model_context_protocol_test.exs`
- `apps/frontman_server/test/protocols/mcp_contract_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_sentry_test.exs`
- `apps/frontman_server/test/frontman_server/tools/mcp_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_routing_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/tool_executor_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/tool_result_concurrency_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution_image_history_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/agent_client_protocol/content_test.exs`
- `apps/frontman_server/test/protocols/acp_history_test.exs`
- `apps/frontman_server/test/support/channel_case.ex`
- `apps/frontman_server/test/support/protocol_schema.ex`

At this historical checkpoint, existing server tests strongly covered the legacy handshake, reconnect ordering, persistence, and single-channel routing but did not prove modern metadata, discovery, result retention, cancellation propagation, every content type across live and historical paths, primitive structured content through ACP, or single execution across multiple channels. Phase 1 subsequently closed modern metadata, discovery, and basic result retention; the approved canonical persisted-result slice closes all standard content variants, empty content, primitive/null structured content through ACP, and live/historical model projection. Accepted Phases 4-5 close live cancellation propagation and multi-channel single-execution ownership; accepted Phase 6 closes durable claim authority for the supported single-node deployment; accepted Phase 7 implements durable deadlines and the restart-recovery architecture while retaining direct restart seams for release hardening.

### Browser MCP Server Findings

#### JSON-RPC dispatcher

`libs/frontman-client/src/FrontmanClient__MCP.res` is the browser MCP server's transport dispatcher.

- Lines 24-64 distinguish request and notification by presence of `id`.
- Lines 66-84 send success and error responses through `mcp:message`.
- Lines 86-104 implement legacy `initialize` while ignoring request parameters.
- Lines 106-120 implement non-paginated `tools/list`.
- Lines 122-170 parse `tools/call`, require `callId`, and execute the tool.
- Lines 150-159 permit `Suspended` to send no response.
- Lines 172-200 dispatch only initialize, list, and call methods.
- Unknown notifications are silently ignored.
- A top-level exception is logged but does not guarantee a response for a request whose ID was already parsed.
- Lines 202-223 attach and detach the handler from a Phoenix channel.

The browser supports string request IDs in its parsing and tests, while the Phoenix client routes runtime results only for integer IDs.

#### Browser tool registry and execution

`libs/frontman-client/src/FrontmanClient__MCP__Server.res` combines browser-local and relayed tools.

- Lines 20-40 construct the server with local registry, relay, and attachment resolution.
- Lines 46-85 register and serialize local tools.
- Lines 101-137 validate and execute browser-local tools.
- Lines 139-182 rewrite attachment references.
- Lines 186-238 dispatch local tools before relayed tools.
- Lines 240-251 build the legacy initialization result.
- Lines 253-256 return only `{tools}` for `tools/list`.

Local-first dispatch silently hides a remote tool with the same name. The latest Tools specification says aggregated clients should implement an explicit disambiguation strategy. The migration must either reject collisions or namespace tools deterministically.

Attachment rewriting is hard-coded to `write_file` and `wp_upload_media`, coupling tool names across packages instead of using documented schema or extension metadata.

Tool execution receives `taskId` from `handler.sessionId`, not the MCP request. `libs/frontman-client/src/FrontmanClient__ACP.res:306-349` installs one MCP handler per task channel and supplies the ACP session ID as MCP execution context. This violates modern stateless request semantics once Frontman claims `2026-07-28`.

#### Browser tool inventory

`libs/client/src/Client__ToolRegistry.res` registers browser tools:

- `take_screenshot`
- `execute_js`
- `set_device_mode`
- `get_interactive_elements`
- `interact_with_element`
- `get_dom`
- `search_text`
- `question`
- Optional Astro browser audit tooling

These tools expose internal policy fields that must move to standard annotations and a negotiated Frontman extension.

#### Interactive question lifecycle

Historical baseline: `libs/client/src/tools/Client__Tool__Question.res` returned a promise that remained unresolved until UI state invoked one stored resolver callback.

Before the accepted application consumer slice, `Client__Task__Reducer` replaced `pendingQuestion` whenever another `QuestionReceived` action arrived. Reconnect redispatch could overwrite prior callbacks without resolving or rejecting the original promise, and disconnect/task cleanup could discard the callbacks.

The accepted source-level cutover keeps this browser-local call and stores every exact-replay waiter under one durable tool-call ID plus identical payload. Answer, cancellation, agent error, disconnect, task clear, and task deletion settle all waiters. Accepted Phase 4 now routes request-correlated custom-Phoenix cancellation through the same terminal reducer path; Elicitation and MRTR remain a separate future feature.

#### Connection reducer contradiction

Historical baseline: `libs/client/src/Client__ConnectionReducer.res` documented relay failure as nonfatal but behaved otherwise.

- Lines 182-199 expose `RelayError` as user-facing `Error`.
- Lines 267-277 call relay failure nonfatal because browser tools remain available.
- Lines 307-318 allow new session creation only when relay state is `RelayConnected`.
- Line 390 rejects every other `CreateSession` state.
- Lines 342-365 load persisted tasks without the same relay-connected requirement.

The accepted cutover resolves this defect: ACP transport readiness remains available independently of framework success, while session creation waits for discovery to succeed or reach its explicit nonfatal failure state. Create/load behavior preserves browser-only operation after nonfatal framework failure, rejected callbacks terminate, and credentialed installed E2E proves the complete policy.

#### Browser tests affected

- `libs/frontman-client/test/FrontmanClient__MCP.test.res`
- `libs/frontman-client/test/FrontmanClient__JsonRpc.test.res`
- `libs/frontman-client/test/FrontmanClient__Relay.test.res`
- `libs/frontman-client/test/FrontmanClient__SSE.test.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`
- `libs/client/test/Client__ToolRegistry.test.res`
- `libs/client/test/Client__ConnectionReducer.test.res`
- `libs/client/test/Client__Task.test.res`
- `libs/client/test/Client__RelayBaseUrl.test.res`
- `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res`
- `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res`

The modern browser and HTTP client tests cover per-request metadata, discovery, complete result types, remote pagination, caching, JSON/SSE interoperability, local question replay/conflict/cleanup behavior, standard browser-tool annotations, request-correlated custom-transport cancellation, callback-owned listener teardown, sibling concurrency isolation, duplicate/cross-method ID collision handling, late-response suppression, deterministic visible-tool serialization, hard underlying-execution capacity, bounded durable-ID replay handling, and the accepted Phase 5 connection lifecycle. Accepted Phase 6 closes durable claim transfer and cancellation/completion fencing; accepted and explicitly approved Phase 7 implements and release-hardens the single-node restart-recovery architecture.

`libs/frontman-client/src/FrontmanClient__ACP.res` now installs one MCP handler on the connection-wide `tasks` channel after the first successful task-session join, then sends `mcp:ready` only after the exact listener exists. Small connection-level `attachMcp` and `detachMcp` helpers own idempotency and cleanup; session cleanup no longer detaches MCP, while connection shutdown fences and aborts handler-owned work.

Relay replacement also affects direct consumers outside the connection reducer:

- `libs/client/src/Client__FrontmanProvider.res` constructs, injects, and disconnects the relay.
- `libs/client/src/components/frontman/Client__UpdateBanner.res` reads relay server information to determine framework package versions.
- `libs/client/src/Client__RelayBaseUrl.res` constructs WordPress Playground-scoped endpoints.

The Streamable HTTP client must preserve these product behaviors through explicit modern interfaces rather than leaving stale Relay dependencies or silently disabling update notifications.

### Current HTTP Relay Findings

#### Relay protocol

`libs/frontman-protocol/src/FrontmanProtocol__Relay.res` defines a private protocol version `1.0`.

- Lines 8-17 define custom remote tool fields.
- Lines 19-25 define a custom discovery response.
- Lines 27-32 define a custom `{name, arguments}` call body.
- Lines 34-36 reuse MCP-shaped result values without JSON-RPC envelopes.

The relay is not the deprecated MCP HTTP+SSE transport and is not modern Streamable HTTP. It is an application-private transport carrying MCP-shaped data.

The workspace also contains an in-progress parallel `FrontmanProtocol__MCP20260728.res` export, generated schemas, fixtures, and conformance tests while the active `FrontmanProtocol__MCP.res` remains legacy. The parallel types are over-permissive in request IDs, progress and cancellation tokens, icon themes, audiences, MRTR values, resource sizes, and tool schema roots, while selected-fixture tests do not prove equivalence with the upstream accepted domain. Treat these artifacts as migration input only: fold correct definitions into the existing shared modules, add differential tests, update every consumer, and delete the parallel API in Phase 1.

#### Relay client

`libs/frontman-client/src/FrontmanClient__Relay.res` implements the browser side.

- Lines 38-88 issue `GET /frontman/tools`.
- Lines 60-68 parse but do not enforce the returned relay `protocolVersion`.
- Lines 96-120 convert remote tools into the browser's MCP catalog.
- Lines 130-188 issue `POST /frontman/tools/call`.
- Lines 147-160 request only `text/event-stream`, not both required modern response media types.
- Tool execution fetch has no abort signal or timeout.

The modern client must replace this module's wire behavior rather than renaming its existing requests.

#### SSE parser

`libs/frontman-client/src/FrontmanClient__SSE.res` parses private relay events.

- Lines 22-43 parse blocks by LF lines.
- Lines 45-64 treat `event: error` data as an opaque error string.
- Lines 88-130 split complete events only on `\n\n`.
- CRLF event streams are not recognized correctly.
- A terminal event without a trailing blank line is discarded at EOF.
- SSE comments and modern complete JSON-RPC message envelopes are not supported.
- Stream cancellation is not propagated through the reader.

#### Relay server

`libs/frontman-core/src/FrontmanCore__RequestHandlers.res` implements the shared framework handlers.

- Lines 53-68 return custom relay tool discovery.
- Lines 70-141 parse a custom call body and always create a custom SSE response.
- Line 76 parses JSON before the validation catch block; malformed JSON syntax can reject the handler and become an adapter-level 500.
- Lines 112-118 emit tool-not-found, invalid-input, and execution errors as custom SSE error events.
- Lines 123-135 catch rejected tool promises and emit another custom error event.
- At the pre-migration baseline the source-location handler had the same JSON-before-validation defect at line 148. Approved Part 2K-O now routes it through the shared bounded body decoder before typed request parsing.

`libs/frontman-core/src/FrontmanCore__SSE.res` serializes bare results:

- Lines 17-24 emit `event: result` with a bare CallToolResult.
- Lines 26-33 emit `event: error` with a complete CallToolResult encoded as data.

The browser reads an error event as a string and wraps it in another CallToolResult. Agents therefore receive serialized JSON as error text instead of the original typed error.

#### Relay security

`libs/frontman-core/src/FrontmanCore__CORS.res:4-8` sets:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

At the pre-migration baseline, `libs/frontman-core/src/FrontmanCore__Middleware.res:164-180` applied these headers to framework tool and source-location endpoints. Approved Part 2K-O removes source location from that wildcard response path; legacy Relay routes remain scheduled for deletion.

`libs/frontman-core/src/FrontmanCore__ToolRegistry.res:16-28` registers project filesystem tools including read, write, edit, grep, and tree operations.

`libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res:73-108` resolves project paths and can create or overwrite files after its read-before-write guard.

Any hostile origin able to reach the development server can attempt cross-origin project operations. Modern Streamable HTTP explicitly requires Origin validation to address DNS rebinding.

The migration separately defines the Origin and CORS policy for `/frontman/resolve-source-location`. It previously shared the wildcard policy and malformed-JSON pattern but is not an MCP endpoint; the completed policy now fail-closes behind an explicit allowlist and shared bounded decoder so `/mcp` hardening does not leave an information-disclosure sibling unfixed.

#### Relay tests affected

- `libs/frontman-core/test/FrontmanCore__RequestHandlers.test.res`
- `libs/frontman-core/test/FrontmanCore__Middleware.test.res`
- `libs/frontman-core/test/FrontmanCore__SSE.test.res`
- `libs/frontman-core/test/FrontmanCore__CORS.test.res`
- `libs/frontman-core/test/FrontmanCore__ToolRegistry.test.res`
- `libs/frontman-core/test/FrontmanCore__Server.test.res`, if added or present during migration
- `libs/frontman-client/test/FrontmanClient__Relay.test.res`
- `libs/frontman-client/test/FrontmanClient__SSE.test.res`

Current CORS tests explicitly assert wildcard Origin behavior. These assertions must be replaced with absent, allowed, denied, preflight, and credential-sensitive Origin cases.

### Framework Integration Findings

Vite, Astro, and Next.js share `frontman-core` tool execution and therefore inherit the relay protocol and security behavior.

#### Next.js

Relevant files:

- `libs/frontman-nextjs/src/FrontmanNextjs__Middleware.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__Server.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__ToolRegistry.res`
- `libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res`
- `libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__AutoEdit.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__SpanProcessor.res`
- `test/sites/blog-starter/src/proxy.ts`

The Next.js registry combines core tools with route/log tools and framework-specific edit behavior. The installer must explicitly route `/mcp` through body-preserving `next.config` server rewrites to the generated Pages API route; Part 2K-N proves middleware and Proxy cannot own this path because they consume the streaming POST body.

The span processor currently suppresses only `/frontman` traffic. It must also suppress `/mcp` so protocol requests do not pollute application logs or expose request metadata through log tools.

Affected tests:

- `libs/frontman-nextjs/test/FrontmanNextjs__Middleware.test.res`
- `libs/frontman-nextjs/test/FrontmanNextjs__ToolRegistry.test.res`
- `libs/frontman-nextjs/test/cli/FrontmanNextjs__Cli__AutoEdit.test.res`
- `libs/frontman-nextjs/test/cli/FrontmanNextjs__Cli__Install.test.res`
- `libs/frontman-nextjs/test/FrontmanNextjs__SpanProcessor.test.res`
- `test/e2e/tests/nextjs.test.ts`

#### Astro

Relevant files:

- `libs/frontman-astro/src/FrontmanAstro__Middleware.res`
- `libs/frontman-astro/src/FrontmanAstro__Server.res`
- `libs/frontman-astro/src/FrontmanAstro__ToolRegistry.res`
- `libs/frontman-astro/src/FrontmanAstro__Integration.res`
- `libs/frontman-astro/src/FrontmanAstro__ViteAdapter.res`
- `libs/frontman-astro/src/astro-route-rewrite.mjs`

The Astro registry combines core tools with page, route, log, content-collection, and framework-specific edit tools. `/mcp` must run before Astro page routing and must be excluded from trailing-slash or Frontman UI route rewriting. Node request close/abort must propagate into Web API stream cancellation.

Affected tests:

- `libs/frontman-astro/test/FrontmanAstro__Tool__GetContentCollections.test.res`
- `libs/frontman-astro/test/FrontmanAstro__Tool__GetLogs.test.res`
- `libs/frontman-astro/test/FrontmanAstro__Tool__GetResolvedRoutes.test.res`
- `libs/frontman-astro/test/astro-route-rewrite.test.mjs`
- `libs/frontman-astro/test/FrontmanAstro__Integration.test.res`
- `test/e2e/tests/astro.test.ts`
- `test/astro-compat/fixture/tests/dev-server.test.mjs`

#### Vite

Relevant files:

- `libs/frontman-vite/src/FrontmanVite__Middleware.res`
- `libs/frontman-vite/src/FrontmanVite__Server.res`
- `libs/frontman-vite/src/FrontmanVite__Plugin.res`
- `libs/frontman-vite/src/FrontmanVite__ToolRegistry.res`
- `libs/frontman-vite/src/FrontmanVite__Bindings.res`

The Vite registry combines core tools with Vite logs and edit behavior. The plugin's early route guard must recognize `/mcp`. The Node-to-Web request bridge currently needs explicit aborted/close event bindings so Streamable HTTP cancellation reaches tool execution.

Affected tests:

- Create transport, middleware, cancellation, and tool-registry tests under `libs/frontman-vite/test/`; this directory does not currently exist.
- `test/e2e/tests/vite.test.ts`
- `test/e2e/tests/vue-vite.test.ts`

#### Shared framework behavior

`libs/frontman-core/src/FrontmanCore__ToolRegistry.res:36-47` replaces framework-specific tools by name inside one registry, which is explicit. Browser-local versus framework tool collisions are not explicit and currently resolve local-first.

Approved Part 2K-N supplies one shared real-process black-box protocol suite so status codes, headers, errors, discovery, listing, execution, cancellation, deadlines, and Origin behavior cannot drift across Next.js, Astro, and Vite. The approved WordPress slice adds focused protocol vectors and real authenticated subdirectory discovery; WordPress and Playground still join the complete shared vectors during final application E2E acceptance.

The pre-migration Vite/Astro bridge duplication is closed by Part 2K-K's sanctioned shared Node/Web chassis. Part 2K-N proves both installed adapters reach that owner over real sockets; do not reintroduce framework transport copies.

### Historical WordPress Findings

The audit below is the pre-cutover WordPress baseline that motivated the approved `2026-08-12` WordPress Streamable HTTP slice. Its private Relay routes, result SSE, and version claims are historical and no longer describe the current plugin.

#### Router and security

`libs/frontman-wordpress/includes/class-frontman-router.php`:

- Lines 55-87 classify current prefix routes.
- Lines 60-66 require authentication and require a nonce for POST.
- Lines 315-332 return private relay discovery with version `1.0`.
- Lines 334-363 dispatch WordPress tools.
- Lines 365-380 always serialize tool outcomes as `event: result` SSE.

WordPress has materially stronger access control than the JavaScript framework relays. The `/mcp` migration must preserve authenticated session, capability checks, nonce validation, Playground scope handling, and private caching.

#### Tool registry and result shaping

`libs/frontman-wordpress/includes/class-frontman-tools.php`:

- Lines 25-101 define and serialize tools.
- Lines 103-148 manage registry and discovery.
- Lines 150-161 and 227-366 sanitize inputs.
- Lines 163-225 wrap canonical MCP-shaped results.

WordPress exposes post, block, media, menu, options, templates, widgets, cache, Elementor, and WooCommerce tools. It intentionally excludes filesystem/project-context tools; `libs/frontman-wordpress/tests/NoFilesystemToolsTest.php:65-98` enforces that policy.

#### Historical WordPress migration concerns

- Route root and Playground-scoped `/mcp` before UI suffix handling.
- Replace private request bodies with complete JSON-RPC envelopes.
- Return JSON for synchronous operations instead of unconditional SSE.
- Validate required modern headers and body metadata.
- Preserve nonce handling on every MCP POST.
- Return exact HTTP and JSON-RPC error combinations.
- Use `cacheScope: private`.
- Validate Origin in addition to WordPress authentication.
- Keep tool visibility dependent on authorization context where appropriate.

#### WordPress tests affected

- `libs/frontman-wordpress/tests/RouterTest.php`
- `libs/frontman-wordpress/tests/NoFilesystemToolsTest.php`
- `libs/frontman-wordpress/tests/MediaToolsTest.php`
- `libs/frontman-wordpress/tests/ElementorToolsTest.php`
- `libs/frontman-wordpress/tests/WooCommerceToolsTest.php`
- `libs/frontman-wordpress/tests/MutationSnapshotsTest.php`
- `libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php`
- `.github/workflows/wordpress-compatibility.yml`

#### Historical WordPress prerequisite verification status

The standalone comment-removal implementation updates authored PHP and WordPress package source without changing the private relay or implementing `/mcp` behavior.

Verified on `2026-08-07`:

- `make package-wordpress-plugin VERSION=2.0.0` succeeded.
- The build produced the plugin ZIP, WordPress.org tarball, and expanded WordPress.org package under ignored `dist/` output.
- The repository-wide source-aware comment scan passes for tracked WordPress PHP, assets, tests, and packaging source.
- The approved leading metadata header in `libs/frontman-wordpress/frontman.php` is preserved by an exact path- and field-aware scanner exception.
- At this prerequisite checkpoint WordPress protocol migration remained unchecked. The approved `2026-08-12` slice later completes the atomic plugin cutover and removes the private Relay routes.

Additional verification completed on `2026-08-07`:

- `make test-wordpress-core-tools` passed under PHP `8.4.24`, including filesystem-policy, Elementor, media, WooCommerce, mutation snapshot, plugin dependency, and router assertions.
- `make test-wordpress-runtime` passed against WordPress `7.0.2` and PHP `8.4.24` using Docker on OrbStack.
- The source scan, generated-schema diff check, and `git diff --check` passed after both WordPress targets.
- PHP `8.5` compatibility is covered without invoking deprecated reflection accessibility changes; PHP `7.4`, `8.4`, and `8.5` remain the compatibility matrix.

## Existing Defects And Required Regression Tests

These rows preserve the pre-migration defect inventory. Completed items are recorded in the implementation status, package checklists, and implementation records; a historical row may therefore describe a defect whose required regression proof now passes. Later-phase defects remain open until their required proof passes.

| Severity | Defect | Evidence | Required regression proof |
| --- | --- | --- | --- |
| High | Multiple task channels execute one tool call | `task_channel.ex:222-258`, `task_channel.ex:1001-1021`, `tasks.ex:249-264` | Two channels, tabs, and claim contenders produce one owned invocation |
| High | Framework file tools are exposed cross-origin | `FrontmanCore__CORS.res:4-8`, `FrontmanCore__Middleware.res:164-180`, `FrontmanCore__ToolRegistry.res:16-28` | Hostile Origin receives 403 and no tool side effect |
| High | Empty valid content does not notify live executor | `execution.ex:142-154` | `content: []` completes the exact waiting request once |
| High | Empty and modern content fail historical reconstruction | `interaction.ex:1133-1174` | Empty and every official content block replay safely into model history |
| High | Modern result fields are stripped during persistence | `interaction.ex:920-935` | `resultType` and the canonical validated result survive persistence and replay |
| High | Audio and resource content can crash delivery | `execution.ex:156-164`, `execution.ex:241-244`, `tool_executor.ex:193-207`, `interaction.ex:1170-1174` | Every official content block persists and converts without exceptions through every live and historical path |
| High | Relay failure was called nonfatal but blocked new sessions; resolved in accepted application slice | Historical `Client__ConnectionReducer` readiness and create guards | ACP remains ready when framework MCP is unavailable; create/load use the browser-only policy; rejected callbacks terminate |
| High | Adapter changes do not trigger E2E CI | `.github/workflows/e2e.yml:5-15` | Every MCP core, protocol, adapter, fixture, and root verification change triggers its owning E2E suite |
| Medium | Initialization can block prompts forever | `mcp_initializer.ex:36-57`, `task_channel.ex:898-905` | Legacy initializer is removed; every modern request has bounded timeout |
| Medium | Version mismatch is ignored | `model_context_protocol.ex:27`, `FrontmanProtocol__MCP.res:4`, `mcp_initializer.ex:112-129` | Unsupported version returns exact `-32022` and never executes |
| Medium | Required nonstandard `callId` blocks interoperability | `FrontmanProtocol__MCP.res:37-43`, `FrontmanClient__MCP.res:128-139` | Standard `tools/call` works without `callId`; vendor metadata is optional/negotiated |
| Medium | Timed-out work continues and pending map grows | `tool_executor.ex:145-190`, `task_channel.ex:379-387`, `FrontmanClient__Relay.res:130-188` | Timeout aborts actual work, clears pending state, and ignores late result |
| Medium | Interactive reconnect overwrote old resolver; resolved at application and Phase 4 transport boundaries | Historical `Client__Tool__Question` promise and `Client__Task__Reducer` replacement behavior | Exact replay retains all waiters; changed/concurrent payloads reject; answer/cancel/error/disconnect/clear/delete and correlated transport cancellation settle every waiter |
| Medium | Malformed peer payloads can crash channel/state machine | `mcp_initializer.ex:112-140`, `mcp.ex:28-55` | Malformed discovery/list/tool entries produce deterministic protocol failure |
| Medium | Tool arguments are logged without redaction | `model_context_protocol.ex:115-122` | Sensitive fixture values never appear in captured normal logs |
| Medium | SSE parser rejects valid CRLF streams | `FrontmanClient__SSE.res:22-35`, `111-119` | LF, CRLF, comments, split delimiters, and split UTF-8 all pass |
| Medium | Malformed JSON can escape shared handler validation | `FrontmanCore__RequestHandlers.res:76-83`, `FrontmanCore__RequestHandlers.res:148` | Truncated, empty, invalid UTF-8, and invalid JSON return deterministic errors on every endpoint, never 500 |
| Low | SSE error results are double-wrapped | `FrontmanCore__SSE.res:26-32`, `FrontmanClient__SSE.res:62`, `FrontmanClient__MCP__Server.res:223-234` | End-to-end execution error preserves original typed result once |
| Low | Tool-name collisions silently hide relay tools | `FrontmanClient__MCP__Server.res:186-238` | Catalog collision is rejected or deterministically namespaced |
| Low | Attachment rewriting depended on hard-coded names; resolved in accepted Phase 4 | Historical `FrontmanClient__MCP__Server.res` branches for `write_file` and `wp_upload_media` | Complete `ai.frontman/attachment-resolution` metadata drives arbitrary-name browser/core/WordPress proof and malformed metadata fails closed |

## Current Protocol Data Flow And Ownership Analysis

The flows below preserve the pre-cutover baseline used to derive the target ownership model. Phase 1 supersedes its wire behavior, the accepted application slice supersedes its question waiter behavior, accepted Phase 4 supersedes its browser cancellation/listener and execution-capacity behavior, accepted Phase 5 supersedes its per-task transient ownership, accepted Phase 6 supersedes its durable claim/replay ownership, and accepted Phase 7 supersedes its process-local recovery behavior while retaining direct application-restart proof for release hardening.

### Historical pre-cutover connection and discovery flow

```text
1. Client provider creates browser tool registry and private HTTP relay.
2. Browser GETs /frontman/tools and stores relay tools in mutable relay state.
3. ACP creates or joins task:{task_id} Phoenix channel.
4. Browser attaches MCP handler before channel join.
5. Phoenix TaskChannel joins and creates connection-scoped MCP initializer state.
6. Phoenix sends initialize.
7. Browser ignores requested version and returns its own version/capabilities.
8. Phoenix sends notifications/initialized.
9. Phoenix sends tools/list.
10. Browser combines local and relay tools, local-first, and returns one page.
11. Phoenix optionally calls load_agent_instructions and list_tree.
12. Phoenix marks that task channel MCP-ready and wakes queued agent work.
```

Ownership consequences:

- MCP lifecycle is bound to one ACP task channel.
- Every opened task channel repeats discovery and project-context loading.
- Capability/version identity is inferred from prior messages on that channel.
- Tool context is inferred from the ACP session ID stored in the handler.
- A missing response can hold queued prompts indefinitely.

Accepted Phase 5 replaces these first-order ownership consequences: one selected `TasksChannel` owns discovery, catalog, pending calls, timers, cancellation, project-context readiness, and result persistence, while `TaskChannel` consumes owner publication and observes persisted interactions. The historical project-context initializer and its tests are deleted.

### Historical pre-Phase-5 tool-call flow

```text
1. LLM emits a tool call with durable tool_call_id.
2. ToolExecutor registers itself in node-local ToolCallRegistry.
3. Tasks persists ToolCall and broadcasts the interaction to task:{task_id}.
4. Every joined TaskChannel receives the ToolCall.
5. Every receiving TaskChannel classifies it as MCP and creates a fresh integer request ID.
6. Each channel stores request_id => durable tool_call_id.
7. Each channel pushes tools/call with nonstandard params.callId.
8. Each browser handler checks local tools first, then relay tools.
9. Relay execution POSTs a private body and waits for custom SSE.
10. Browser returns a JSON-RPC response to its TaskChannel.
11. TaskChannel maps request ID back to durable tool_call_id.
12. Tasks persists ToolResult; database uniqueness rejects later duplicates.
13. Execution.notify_tool_result converts content and notifies the waiting executor.
14. TaskChannel pushes an ACP tool update and may resume the agent.
```

Ownership consequences:

- Persistence owns the durable tool call, but no component exclusively owns execution.
- TaskChannel owns transient correlation, so disconnect destroys request knowledge.
- Registry owns live waiter delivery only on one node.
- Historically, browser and framework had no cancellation owner. Accepted Phase 2 owns framework HTTP cancellation, accepted Phase 4 owns browser handler-scoped cancellation, accepted Phase 5 owns process-local Phoenix cancellation, and accepted Phase 6 owns durable cancellation/completion fencing.
- Database uniqueness guarantees one stored result, not one external side effect.

Accepted Phases 5-6 supersede the process-local flow above: one selected `TasksChannel` receives direct execution requests and owns transient correlation, while the existing tool-call interaction row owns the durable generation-fenced claim and one transaction persists the canonical result plus terminal claim state. Exactly-once arbitrary non-idempotent side effects remain impossible without tool-level idempotency.

### Historical pre-Phase-5 reconnect flow

The flow below is the historical pre-cutover baseline. The accepted source-level application slice supersedes step 6 by joining exact replay waiters instead of replacing the pending resolver, accepted Phase 4 aborts/fences work owned by a detached browser handler, accepted Phase 6 owns durable claim transfer and replay fencing, and accepted Phase 7 owns the approved single-node recovery architecture and completed release hardening.

```text
1. Browser disconnect leaves unresolved ToolCall persisted.
2. A new task channel joins and repeats legacy initialization.
3. session/load marks the new channel ready for recovery.
4. After MCP readiness, the channel queries unresolved active-run tool calls.
5. It redispatches each unresolved call with a fresh JSON-RPC ID and original callId.
6. Historically, question replay created a new browser promise and replaced current pending UI state.
7. First stored ToolResult wins; duplicate side effects remain possible.
```

Ownership consequences:

- Recovery is a blind replay rather than lease transfer.
- The original browser execution may still be running.
- Interactive resolver callback leakage, browser handler-scoped transport abort, durable request ownership, replay fencing, and the accepted Phase 7 single-node recovery and release-hardening seams are closed.
- Non-idempotent writes may execute again.

### Accepted Phase 5 flow with accepted Phase 6 durable claims

```text
1. Browser attaches one MCP handler to the existing authenticated connection-wide `tasks` channel.
2. The existing Phoenix `TasksChannel` process owns discovery, catalog state, request IDs, and pending state for that browser connection.
3. ToolExecutor requests execution through that connection owner with task and durable tool-call context.
4. Phase 5 selects one live process-local owner; Phase 6 atomically claims the durable tool-call interaction for that connection and owner generation.
5. The connection owner sends one stateless tools/call request with full _meta.
6. Browser deduplicates the durable Frontman tool-call identifier.
7. Browser executes local tool or standard Streamable HTTP call.
8. Cancellation propagates through the connection owner, browser AbortController, HTTP stream, and tool context.
9. The connection owner validates the response by pending request kind before persistence.
10. Tasks atomically persists one canonical result and completes the durable claim in the same transaction.
11. All task channels observe persisted interactions and publish UI updates only.
12. Reconnect requires explicit claim transfer or lease expiry before replay.
```

Target ownership assignments:

| Concern | Owner |
| --- | --- |
| MCP server connection | Browser MCP server instance and existing Phoenix `TasksChannel` connection process |
| Protocol discovery/cache | Existing Phoenix `TasksChannel` connection process |
| HTTP framework discovery/cache | Browser Streamable HTTP MCP client |
| JSON-RPC wire correlation | Issuing MCP client transport |
| Durable agent tool identity | Tasks persistence |
| Exclusive execution claim | Declared namespaced claim state in the existing tool-call interaction JSONB row, keyed by exact interaction UUID and serialized logical identity |
| Live agent waiter | Tool executor with connection-owner-mediated completion |
| Browser-local cancellation | Browser MCP handler AbortController |
| Framework cancellation | Streamable HTTP response stream and tool context signal |
| UI observation | Task channels through persisted interaction broadcasts |

## Package-Specific Migration Checklists

### `libs/frontman-protocol`

- [x] Pin official schema, examples, license, provenance, and checksums.
- [x] Add offline JSON Schema 2020-12 oracle and official-example conformance tests.
- [x] Replace `FrontmanProtocol__MCP.res` in place with the modern latest-only contract; consumers and schemas are cut over, the version is `2026-07-28`, and no `MCP20260728` parallel API remains.
- [x] Consolidate modern content variants into `FrontmanProtocol__ContentBlock.res` and add lossless generic request/notification/result/error response and exclusive message schemas in `FrontmanProtocol__JsonRpc.res`; public consumers are cut over.
- [x] Generalize JSON-RPC IDs without 32-bit narrowing.
- [x] Add bounded generic, request, result, and notification metadata contracts with reserved-field validation and lossless vendor metadata preservation.
- [x] Add exact implementation identity with shared icon reuse, open client/server capability contracts, and namespaced extension maps.
- [x] Add exact cancellation notification and notification metadata wire contracts.
- [x] Add the exact accepted Streamable HTTP SSE message domain.
- [x] Add modern errors required by the initial implementation.
- [x] Add exact discovery, cache-hint, Tool, `tools/list`, and `tools/call` request wire contracts.
- [x] Add lossless `InputResponses` and all three nested InputRequest variant contracts without advertising optional capabilities or adding fulfillment machinery.
- [x] Assemble the exact `InputRequests` union and add `InputRequiredResult` recognition without automatic MRTR fulfillment or retry.
- [x] Keep shared wire recognition free of production MRTR, progress, emitted SSE, server pagination, and subscription machinery until a caller exists.
- [x] Support all content blocks and arbitrary JSON structured content in the shared ReScript wire contract; accepted Phase 9 covers persistence, Elixir, ACP history, deterministic model conversion, exact media/resource limits, and invocation-time output-schema validation.
- [x] Define only the minimal Frontman extension needed for explicit task context and durable tool-call identity.
- [x] Extend browser tool execution with an exact request `AbortSignal` and document `ai.frontman/attachment-resolution` tool metadata without adding an optional MCP capability.
- [x] Remove private Relay protocol types after client/server cutover.
- [x] Replace generated schemas atomically and remove legacy/version-parallel MCP schema exports.
- [x] Differentially validate locally accepted Phase 1 domains against upstream definitions with deterministic generated cases, focused exhaustive vectors, and explicit authoritative-artifact discrepancy tests.
- [x] Add a breaking changeset.

### `libs/frontman-client`

- [x] Remove initialize-era browser dispatcher behavior.
- [x] Implement `server/discover` on the custom Phoenix dispatcher.
- [x] Validate `_meta` on every supported custom Phoenix request.
- [x] Implement modern list/call/result/error behavior on the custom Phoenix dispatcher.
- [x] Add Streamable HTTP request correlation, immutable maximum-timeout abort, fetch/reader cancellation without awaiting untrusted cancellation promises, and late-response suppression; accepted Phase 4 separately adds custom-Phoenix request correlation, AbortSignal propagation, and late-response suppression.
- [x] Remove silent `Suspended` response loss.
- [x] Stop deriving task context from the channel session ID; require explicit execution-context metadata.
- [x] Replace the browser Relay wire behavior with a Streamable HTTP MCP client while retaining the temporary API name for current application consumers.
- [x] Implement required standard and `x-mcp-header` headers.
- [x] Implement bounded strict-UTF-8 JSON and standards-compliant SSE response parsing with LF/CRLF, split delimiters, comments, multi-line data, EOF termination, depth limits, message classification, and terminal correlation.
- [x] Fetch all remote list pages defensively, forward every cursor opaquely including repeated and empty values, enforce frozen page/tool/cursor/definition/catalog limits, reject inconsistent cache scopes, perform at most one client-owned restart after a continuation `-32602`, and cache only fresh complete catalogs inside one authorization-bound client instance.
- [x] Add abort propagation and late-response suppression for Streamable HTTP requests.
- [x] Reject remote tool collisions with browser-local tools by excluding the remote duplicate from the merged catalog.
- [x] Validate default 2020-12 and explicit draft-07 remote schemas, disable network `$ref` resolution by construction, exclude invalid tools individually, validate arguments before send, and validate structured output before model use.
- [x] Move remote schema compilation and instance validation into one interruptible module Worker per operation, using a Blob module bootstrap, explicit ready handshake, bounded startup timeout, typed startup/validation diagnostics, exact `100/101 ms` operation limits, cancellation, lifecycle cleanup, main-thread responsiveness, browser-bundle proof, and no-send/no-retry proof.
- [x] Complete exact response/catalog/page/tool/cursor/definition boundaries, response-idle and absolute-timeout/cancellation/terminal races, authorization isolation, adversarial one-byte chunking, stale/concurrent connect fencing, and exact schema-container `1,024/1,025` proof. Applicable real WordPress root/scoped and genuine Playground scoped-runtime vectors pass, and credentialed installed JavaScript application E2E passes `11/11`.
- [x] Own listener registration by callback reference so ACP/task cleanup cannot remove the connection-wide MCP handler.
- [x] Attach the browser MCP handler once to the connection-wide `tasks` channel only after a successful session join, explicitly signal `mcp:ready`, keep session joining free of transport lifecycle details through `attachMcp`/`detachMcp`, and detach on connection shutdown rather than task cleanup.
- [x] Add focused custom-Phoenix sibling-concurrency, duplicate/cross-method ID collision, cancellation, detach, exact-listener, cursor, and late-response tests; accepted Phase 5 adds connection-wide owner selection/failover, immutable timeout races, terminal fencing, and teardown proof, while accepted Phase 6 adds durable existing-row claim ownership and bounded browser durable-ID replay handling.
- [x] Bound one handler to `256` correlated response owners, preserve one terminal response owner, and abort/fence every handler-owned call on cancellation or detach.
- [x] Bound cancelled-but-unsettled executions by retaining abort-ignoring work in the hard `256` underlying-execution capacity accounting until settlement; durable identity and fingerprint tombstones are independently count- and byte-bounded and fail closed.
- [x] Reject every supplied browser-server list cursor, filter hidden local tools, and sort the merged visible catalog by exact name.
- [x] Remove private relay generated artifacts and tests.
- [x] Add breaking changesets for the custom Phoenix contract cutover, the approved Streamable HTTP browser-client slice, and the accepted Phase 4 request-lifecycle/API changes.

### `libs/client`

- [x] Supply explicit browser MCP server identity and execution-context extension metadata.
- [x] Keep ACP transport readiness independent of framework availability while gating session creation until framework discovery succeeds or reaches an explicit nonfatal failure state.
- [x] Define and test browser-only behavior after framework discovery fails non-fatally or `/mcp` is unavailable.
- [x] Keep Streamable HTTP transport, parsing, cache, correlation, and cancellation in `frontman-client`; the existing `Client__ConnectionReducer` only orchestrates lifecycle and exposes state.
- [x] Make question execution cancellable and reconnect-safe at the application boundary; only identical same-ID replays retain all waiters, changed or concurrent calls fail deterministically, and answer, skip, cancellation, agent error, connection loss, task clear, task deletion, and accepted Phase 4 request cancellation settle pending calls.
- [ ] Decide later whether to advertise Elicitation.
- [x] Preserve attachment resolution through documented `ai.frontman/attachment-resolution` tool metadata rather than hidden name conventions.
- [x] Terminate the interactive question reducer state when the exact custom-Phoenix request signal aborts and remove its abort listener after settlement.
- [x] Preserve provider lifecycle and update-banner server information while removing direct `Relay.t` exposure from React context; the provider exposes only discovered framework identity, and the approved WordPress cutover adds explicit site-base endpoint ownership and real subdirectory `/mcp` proof.
- [x] Update tool registry serialization and policy tests for custom Phoenix and active JavaScript/WordPress Streamable HTTP servers; standard serializers filter hidden tools, map policy to annotations, and sort deterministically. Remote framework tools enter the read-only consent catalog only when their standard definition declares `annotations.readOnlyHint: true`; absent or false hints default to write consent, and annotation classification does not bypass execution authorization.
- [x] Update task recovery tests for framework-unavailable creation, terminal create/load/prompt rejection callbacks, stale parse-failure authority, exact question replay/conflicts, idle cancellation, agent-error settlement, connection loss, task clear, and task deletion; credentialed installed reconnect E2E passes across all four JavaScript fixtures and proves ACP initialization replay, discovery gating, consent, and a real post-reconnect source operation.
- [x] Add a breaking changeset.

### `libs/frontman-core`

- [x] Add a route-independent, exact Streamable HTTP header-value decoder with safe raw ASCII handling, canonical Base64 sentinel decoding, strict UTF-8 validation, and focused boundary vectors.
- [x] Add route-independent standard request-header validation with required-header presence before body comparison, body comparison before protocol support, conditional `Mcp-Name`, case rules, and encoded-name handling.
- [x] Add schema-valid HTTP `400` error responses for `InvalidRequest`, `HeaderMismatch`, and `UnsupportedProtocolVersion`, preserving readable string/numeric IDs, omitting unreadable IDs, and using Sury for all structured data.
- [x] Add Frontman's request/response media policy with strict JSON Content-Type handling, dual exact Accept offers, bounded quality syntax, and quote-aware delimiter safety.
- [x] Add bounded strict UTF-8 JSON decoding with the exact `2,097,152`-byte and depth-`64` limits while preserving arbitrary JSON roots.
- [x] Add streaming request-body collection with `Content-Length` preflight, independent byte counting, overflow-safe remaining-capacity checks, a `4,096`-chunk limit, reader cancellation, and lock release.
- [x] Add the exact `60,000`-millisecond monotonic body idle deadline with late-byte, completion, zero-byte, cancellation, and timer-cleanup race coverage.
- [x] Compose the approved reader and decoder at a typed Web Request boundary with explicit missing/consumed-body errors and preserved reader/decoder categories.
- [x] Add coarse route-independent JSON-RPC request-envelope and incoming-direction classification while preserving open fields and arbitrary method params for later validation.
- [x] Add independent invalid-envelope ID recovery and raw protocol-version, capability, method, and method-selected name authority extraction without advancing complete method-parameter validation.
- [x] Compose the decoded-request stages into ordered HTTP `400` responses for `-32600`, `-32020`, and `-32022` without claiming pre-decode policy, metadata, dispatch, or execution behavior.
- [x] Remove the private request handlers after browser/client cutover.
- [x] Expose the completed discovery, listing, calling, and exact error behavior through the configured production `POST /mcp` dispatcher.
- [x] Integrate the completed standard header foundations with raw body authorities while preserving required-header presence, body comparison, and supported-version precedence and carrying raw client capabilities to their later validation stage.
- [x] Validate complete per-request metadata after standard headers and supported-version classification, then validate any explicit aggregate required client capability with exact HTTP `400`/`-32602` and `-32021` responses.
- [x] Classify the three initially supported methods and parse their complete shared request schemas after metadata/capability validation, returning exact HTTP `200`/`-32602` or `404`/`-32601` method errors without registry access.
- [x] Reject every supplied `tools/list` cursor after shared-schema parsing with exact HTTP `200`/`-32602`, preserving readable IDs and treating empty strings by presence rather than truthiness.
- [x] Compose media validation, Web Request body reading, UTF-8/JSON decoding, and the decoded-request boundary into exact route-independent 400/`-32700`, 406, 408, 413, and 415 responses without executing accepted work.
- [x] Select the exact registry tool only after a typed `tools/call`, return schema-valid HTTP `200`/`-32602` for an unknown tool, and preserve discovery/list variants without beginning argument validation or execution.
- [x] Implement and validate `x-mcp-header` schema discovery, header extraction, typed comparison, exact `-32020` behavior, and adapter-owned raw physical duplicate rejection before active execution.
- [x] Preserve raw physical `Mcp-Param-*` multiplicity at the Vite, Astro, and generated Next.js Node adapters and reject duplicate recognized fields before Web `Headers` folding; prove a legitimate comma-containing singleton remains accepted.
- [x] Add a route-independent strict Origin allowlist and authorization decision boundary before media/body processing, with empty 403/401 classification, exact Origin echo, `Vary: Origin`, and multi-fault no-side-effect proof.
- [x] Add shared explicit adapter Origin/auth configuration and a Next.js Pages API Node input adapter that preserves physical headers and validates security before Web body-stream construction; Part 2K-L activates the generated route and Part 2K-N corrects public routing to an installer-owned body-preserving server rewrite.
- [x] Validate complete selected-tool arguments through the existing Sury input schema only after custom-header validation; map rejection to a complete `CallToolResult` with `isError: true` under SEP-1302 without executing the tool.
- [x] Integrate the approved `HttpRequest` boundary into the production dispatcher and emit its negotiated synchronous JSON success/error responses.
- [x] Return synchronous JSON initially; retain only standards-compliant response plumbing needed to add emitted SSE when a real progress or streaming producer exists.
- [x] Propagate the exact active chassis signal into selected-tool execution, check it before and after invocation, and stop owned child processes cooperatively on disconnect or timeout.
- [x] Enforce the immutable `600,000`-millisecond active-framework deadline from Node ingress through response commitment, with exact-limit completion, one-millisecond-over empty 408, abort-aware rejection, stalled-body, late-result, and timer-cleanup proof.
- [x] Consolidate Node/Web request and response adaptation across Next.js, Astro, and Vite with physical-header capture, security-before-body gating, exact-byte response streaming, backpressure, request-abort/response-close ownership, reader cancellation, late-response suppression, listener cleanup, and tool-context propagation.
- [x] Integrate strict Origin policy into every active JavaScript MCP adapter and the WordPress endpoint; ensure no active MCP response uses wildcard CORS.
- [x] Define and test a non-MCP Origin/CORS policy for `/frontman/resolve-source-location`, fail closed without an explicit allowlist, omit credential permission, and use the shared bounded decoder after Origin and media validation.
- [x] Serialize standard tools with deterministic order.
- [x] Map read behavior to standard annotations, filter hidden tools before serialization, and keep execution timing policy internal.
- [x] Reuse Sury tool schemas and the existing server execution path for route-independent selected-call execution; add generic runtime schema validation only at untyped remote boundaries.
- [x] Classify selected input, returned API/business, and thrown execution failures as complete `CallToolResult` error results while keeping unknown tools at HTTP `200`/`-32602`; Part 2K-L composes these results through the active endpoint.
- [x] Remove relay routes, protocol version, and private SSE helpers.
- [x] Add shared real-process black-box transport and security tests for installed Next.js, Astro, and Vite artifacts; exact Next.js case/trailing-slash rejection remains an explicit framework routing limit.
- [x] Add a major changeset for the active latest-only framework endpoint across core, Next.js, Astro, and Vite.
- [x] Advertise the complete `write_file` attachment-resolution metadata consumed by the accepted browser transport.

### `libs/frontman-nextjs`

- [x] Prove raw physical header and pre-body security access through the documented Pages API Route `IncomingMessage` seam; Proxy and App Route Headers remain invalid evidence, and Part 2K-L generates the active route/rewrite.
- [x] Route `/mcp` through an installer-owned body-preserving `next.config` server rewrite to the generated Node Pages API route; exclude `/mcp` from middleware and Proxy because real-process proof shows both consume the POST stream.
- [x] Update installer, automatic-edit prompts, manual guidance, and validators for the generated route, server rewrite, middleware/Proxy exclusion, body-parser policy, and authentication environment.
- [x] Update checked-in Next.js site fixtures for the generated API route and installer-owned server rewrite.
- [x] Suppress exact `/mcp` and `/api/frontman-mcp` spans while retaining nearby non-MCP routes.
- [x] Remove old server wrapper methods.
- [x] Propagate Node request abort, response close, and the active absolute deadline through the chassis signal into selected-tool execution.
- [x] Run shared MCP black-box acceptance against the exact generated Next integration after moving `/mcp` from body-consuming Proxy/middleware routing to installer-owned server rewrites.
- [x] Update Next.js E2E source for framework-unavailable recovery and the random post-reconnect source-operation gate; credentialed installed recovery passes.
- [x] Update the MCP plan/traceability record and add the shared major framework-endpoint changeset; package user documentation and E2E guidance remain with the later fixture/E2E cutover.

### `libs/frontman-astro`

- [x] Route configured exact `/mcp` before Astro application routing.
- [x] Exclude exact `/mcp` from UI rewrites and preserve its request ownership across Astro `ignore`, `always`, and `never` trailing-slash modes without accepting route aliases.
- [x] Use the consolidated shared Node/Web chassis for request abort, response close, raw-byte streaming, backpressure, and listener cleanup.
- [x] Remove old server wrapper methods.
- [x] Run shared MCP black-box suite against a real Astro dev server.
- [x] Update Astro and Astro-compatibility E2E tests to call the standard authenticated `/mcp` endpoint; the packed Astro 6 consumer passes `ignore`, `always`, and `never`, and credentialed installed recovery passes.
- [x] Update the MCP plan/traceability record and add the shared major framework-endpoint changeset; package user documentation and E2E guidance remain with the later fixture/E2E cutover.

### `libs/frontman-vite`

- [x] Add configured exact `/mcp` to the early plugin route guard.
- [x] Consolidate the duplicated Vite/Astro Node/Web bridge into the shared chassis and remove adapter-owned request buffering and response pumping.
- [x] Propagate Node abort/close cancellation and the active absolute deadline through Web request signals, response readers, and selected-tool execution via that one shared bridge.
- [x] Remove old server wrapper methods.
- [x] Create package transport/middleware tests and run the shared MCP black-box suite against a real Vite dev server.
- [x] Update Vite and Vue-Vite E2E source for framework-unavailable recovery and the random post-reconnect source-operation gate; the installer preserves each fixture's configured host, and credentialed installed recovery passes.
- [x] Update the MCP plan/traceability record and add the shared major framework-endpoint changeset; package user documentation and E2E guidance remain with the later fixture/E2E cutover.

### `libs/frontman-wordpress`

- [x] Add modern exact root and site-scoped `/mcp` route classification.
- [x] Implement JSON-RPC request validation and dispatch.
- [x] Preserve session authentication, capability checks, and nonce validation.
- [x] Add exact site-Origin validation.
- [x] Implement discovery, listing, calling, and modern error envelopes.
- [x] Reject supplied MRTR retry state before execution because WordPress tools do not emit `input_required`; do not advertise or partially implement MRTR.
- [x] Return JSON for synchronous operations.
- [x] Use private cache scope.
- [x] Preserve no-filesystem-tools policy.
- [x] Remove old relay routes and unconditional custom SSE.
- [x] Advertise and test the complete `wp_upload_media` attachment-resolution metadata consumed by the accepted browser transport.
- [x] Run focused protocol vectors plus real authenticated subdirectory discovery and legacy-route absence over WordPress HTTP; broader shared black-box parity remains part of final application E2E acceptance.
- [x] Update runtime, compatibility workflow, docs, and changeset.

### `libs/frontman-astro-browser`

- [x] Verify tool result constructors include modern complete-result fields through the shared constructor.
- [x] Validate Astro audit tool schemas and standard metadata.
- [x] Update registry and result tests.
- [x] Add the published browser serializer and application behavior to their owning package changesets; `@frontman-ai/astro-browser` remains private.

### `apps/frontman_server`

- [x] Replace `DRAFT-2025-v3` with latest-only `2026-07-28` request metadata.
- [x] Remove the unreachable MCP initializer module and tests after moving project-context loading to the connection owner.
- [x] Move transient MCP ownership into the existing authenticated `TasksChannel` without adding a broker process or second connection channel; the complete Phase 5 proof and cleanup gates pass.
- [x] Implement discovery and minimal catalog state first in the historical temporary TaskChannel owner, then supersede it with the approved connection-wide `MCPCatalog` owner in `TasksChannel`.
- [x] Propagate ACP cancellation through the historical temporary owner, then supersede it with connection-owner task/tool cancellation that removes transient correlation before sending exact MCP cancellation notifications.
- [x] Move project-context loading outside protocol initialization into bounded catalog-aware ordinary calls with canonical structured content and readiness gating; delete the old initializer, parser, tests, and browser no-op.
- [x] Remove MCP request dispatch and response ownership from task interaction observers in production; convert the remaining legacy task-channel assertions to the connection owner.
- [x] With BlueHotDog approval, implement declared claim state on the existing tool-call interaction JSONB row without a claim table or migration; preserve row UUID through recovery, serialize logical tool-call identity, and prove database-time CAS/lease/generation/transactional cancellation and completion.
- [x] Complete connection-owner deadline races, bounded terminal-ID classification, task/tool cancellation, reconnect recovery, owner failover, teardown cleanup, durable claims, generation fencing, dispatch ambiguity, claim completion, replay policy, durable absolute deadlines, the accepted single-node recovery architecture, and its approved release-hardening fault vectors. Defer progress and MRTR until they have callers.
- [x] Validate every implemented browser response against its pending method schema on the custom-Phoenix path; `TasksChannel` owns parsing authority and the complete result-type and malformed-peer matrix passes.
- [x] Persist one canonical validated modern result and use it for live delivery, historical reconstruction, ACP presentation, and model conversion; the persistence boundary validates complete results, scrubs result `_meta`, preserves arbitrary structured content including explicit null, and projects unsupported model media without mutating canonical storage.
- [x] Support empty content and every standard content block without Base64 or function-clause failures; canonical Base64, URI, MIME, block-count, decoded-byte, aggregate-byte, embedded-text-byte, and parsed-image-dimension limits run before persistence, and unsupported model media use deterministic non-binary projections.
- [x] Validate arbitrary structured content against the durable invocation-time output schema while preserving every JSON root, including explicit null through ACP.
- [x] Compile untrusted input/output definitions and validate output instances through bounded, process-isolated JSON Schema 2020-12 operations with no external resolver; exclude malformed tools individually while retaining valid catalog siblings.
- [x] Remove tool arguments, malformed argument payloads, decoder diagnostics, and peer-controlled catalog/project-context error messages from logging paths.
- [x] Record multi-node and cross-node Phoenix execution as out of scope for the supported single-node deployment; retain contention proof through independent PostgreSQL backend and pool connections.
- [x] Close and explicitly approve the Phase 7 release-hardening residuals with fresh-BEAM application startup, actual state-owner restart, exact post-commit delivery death, mixed-state marker consumption, supervised-delivery finalization, and atomic cancellation-marker cleanup.
- [x] Replace Phase 1 legacy contract tests with generated-schema, pinned-upstream, and shared ReScript/Elixir parity evidence; broader transport compliance remains later work.
- [x] Add connection-wide randomized correlation, multi-channel, multi-owner, owner-death, session-load ordering, timeout/late-response, transient replay-fencing, durable claim, exact lease, stale-generation, transactional terminal, and browser durable-ID capacity tests.

### Root, E2E, CI, And Documentation

- [x] Expand root `make mcp-verify` beyond protocol-package forwarding into the serial aggregate gate. It preflights `test/e2e/.env`, owns every required package/runtime/generated gate, and one uninterrupted credentialed invocation passes.
- [x] Add shared adapter black-box fixtures and a no-secrets CI target.
- [x] Add and explicitly approve the official `0.2.0-alpha.11` conformance runner as a checksum-pinned offline gate for Frontman's advertised server and client capabilities, with no expected-failure baseline, warnings, or unexpected skips; retain the two malformed upstream client-fixture corrections as disclosed non-pristine evidence limits.
- [x] Add deterministic property tests with `1,000` pull-request cases and a checksum-pinned `10,000`-case scheduled/manual workflow.
- [x] Add bounded fresh-BEAM application startup, exact post-commit/pre-notification caller death, and actual supervised connection-state-owner restart fault-injection tests; multi-node Phoenix scheduling remains out of scope.
- [x] Complete provider-backed installed Next.js, Astro, Vite, and Vue-Vite recovery E2E with valid credentials; all `11/11` scenarios pass.
- [x] Complete applicable real WordPress root/scoped and genuine Playground scoped-runtime shared black-box vectors.
- [x] Correct E2E and WordPress compatibility workflow path ownership for protocol, core, complete client and JavaScript adapter packages, Astro-browser, WordPress, MCP docs/plan, checked-in E2E and Astro-compatibility fixtures, bindings, server runtime/priv/generated-browser inputs, shared MCP helpers, all changesets, root workspace configuration, workflow files, runtime scripts, and root Makefile changes.
- [x] Add serial CI ownership for the Astro, Vite, and Astro-browser package suites and scope E2E cancellation by pull request or ref.
- [x] Repair the Astro, Vite, and Next.js package lint targets to invoke supported ReScript formatting commands and include them in root aggregate ownership.
- [x] Add custom Phoenix transport documentation.
- [x] Add Frontman MCP extension documentation.
- [x] Add Phase 0 implementation limits, normative traceability matrices, and threat model.
- [x] Add the release capability matrix and replace planned traceability locations with final direction-specific code and test evidence.
- [ ] Update `README.md`, architecture docs, integration docs, and marketing language.
- [x] Remove obsolete `docs/mcp_schema.ts` or replace it with an explicit pointer to pinned upstream artifacts.
- [ ] Add migration documentation for the breaking latest-only release.
- [x] Remove or regenerate Phoenix browser-test bundles and every other shipped artifact containing legacy protocol behavior.
- [x] Enforce zero comments, docblocks, suppressions, TODO/FIXME markers, and commented-out code across tracked authored source, allowing only approved platform-required executable directives. The prerequisite is merged and its repository, packaging, WordPress core-tool, and WordPress runtime proof gate is accepted.

## Target Architecture

```text
Phoenix MCP client
    |
    | MCP 2026-07-28 JSON-RPC
    | documented custom Phoenix transport
    v
Browser MCP server and Streamable HTTP MCP client
    |
    | MCP 2026-07-28 Streamable HTTP
    | POST /mcp
    v
Next.js / Astro / Vite / WordPress MCP servers
```

### Role Boundaries

Phoenix remains the MCP client on the custom browser transport.

The browser remains the MCP server for browser-local tools and becomes a standard MCP client for framework tools.

Each framework integration becomes a standard MCP Streamable HTTP server.

ACP remains the application protocol between the UI and the agent orchestrator. ACP task/session concepts must not leak into MCP as implicit connection state.

## Non-Negotiable Design Rules

1. The final implementation supports only protocol version `2026-07-28`.
2. Every MCP request is self-describing and independently validated.
3. No MCP server infers task, user, capability, version, or authorization context from connection history.
4. Every successful result contains `resultType`.
5. Every advertised capability has complete implementation and tests.
6. Unsupported optional features are not advertised or approximated.
7. Frontman-specific data uses documented, negotiated, reverse-DNS-prefixed extensions.
8. All tool schemas use JSON Schema 2020-12 unless explicitly declaring another supported dialect.
9. External `$ref` values are never fetched automatically.
10. Parsing failures, malformed peer data, unsupported content, and cancellation never crash an executor or channel.
11. One durable tool call can cause at most one owned external execution at a time.
12. No test relies on network access to fetch the standard, schema, examples, or conformance runner.
13. Existing shared owners are updated in place; no parallel MCP contract, broker process, adapter bridge, or compatibility fallback survives the migration.
14. Tracked authored repository source contains no comments, docblocks, suppressions, TODO/FIXME markers, or commented-out code other than approved platform-required executable directives; generated artifacts and build outputs are excluded from this rule.

## Prerequisite: Repository-Wide Comment Removal

Complete tracked-authored-source comment removal before protocol implementation so the migration does not mix recurring comment cleanup with behavioral changes.

Search every tracked authored source file, including authored files under `apps/`, `libs/`, `test/`, `scripts/`, `.github/`, installer templates, and fixtures. Remove source comments, documentation comments, lint and type suppression directives, TODO/FIXME notes, and commented-out code. Preserve only approved platform-required executable directives. Exclude generated artifacts and build outputs from comment cleanup and enforcement.

Add one repository-wide source-aware verification command that fails on prohibited comments in tracked authored source and runs in local precommit and CI. The scanner must distinguish source comments from strings, regular expressions, standalone prose, licenses, protocol examples, immutable data, generated artifacts, and build outputs by file type and ownership; do not maintain broad exclusions that can hide authored source.

### Implementation Record

Status: merged and accepted.

- [x] Remove lexical source comments, documentation comments, Elixir documentation attributes, TODO/FIXME notes, and commented-out code from tracked authored source.
- [x] Preserve interpreter shebangs, the exact leading WordPress plugin metadata header, and valid TypeScript triple-slash reference directives.
- [x] Preserve standalone prose, licenses, protocol JSON, immutable fixture data, strings, regular expressions, SVG CDATA, and generated build output.
- [x] Add `scripts/no-comments.mjs` with tracked-file enumeration and exact generated-artifact exclusions.
- [x] Cover ReScript and C-like source, Elixir and HEEx, PHP, HTML/Astro/Vue/SVG/XML, CSS, shell and typed heredocs, Python and docstrings, YAML/TOML/INI/service files, SQL, batch files, Dockerfiles, Makefiles, Caddyfiles, environment files, and executable shebang files.
- [x] Add scanner fixtures and regression tests for directives, regex and string markers, template interpolation, generated installer source, WordPress metadata, SVG CDATA, Elixir docblocks, Python docstrings, Node/Python/SQL/shell heredocs, safe autofix, tracked-file ownership, and exact generated exclusions.
- [x] Make autofix preserve bytes outside detected source comments and preserve syntactically valid Python blocks with `pass` when a removed docstring was the block body.
- [x] Add root `make check-source-comments`.
- [x] Run the check from root Lefthook precommit and an unconditional CI job.
- [x] Preserve Makefile help output without comment-powered parsing.
- [x] Align Credo configuration and commands so the repository policy does not conflict with `Credo.Check.Readability.ModuleDoc`.
- [x] Run the repository source scan, scanner tests, diff checks, shell syntax checks, ReScript build, protocol schema regeneration check, Elixir precommit suites, JavaScript/ReScript package suites, marketing build, Astro package verification, and WordPress packaging.
- [x] Run `make test-wordpress-core-tools` with PHP available.
- [x] Run `make test-wordpress-runtime` with Docker available.
- [x] Rerun the source scan and generated-diff checks after WordPress tests.
- [x] Accept the prerequisite proof gate.
- [x] Commit and merge the standalone change before protocol implementation.

Verification recorded on `2026-08-07`:

- Scanner unit tests: `21` passed.
- Repository source scan: passed with zero reported prohibited comments.
- Root ReScript build: passed.
- `apps/swarm_ai`: warnings-as-errors compile, formatting, Credo, and `112` tests passed.
- `apps/frontman_notifier`: warnings-as-errors compile, formatting, Credo, and `3` tests passed.
- `apps/frontman_server`: warnings-as-errors compile, formatting, Credo, and `727` tests passed.
- `libs/client`: `319` tests passed.
- `libs/frontman-client`: `69` tests passed.
- `libs/frontman-core`: `321` tests passed when rerun serially; an earlier parallel run was invalid because another ReScript clean removed generated modules during Vitest startup.
- `libs/frontman-nextjs`: `182` tests passed.
- `libs/frontman-astro`: `59` tests passed.
- `libs/frontman-astro-browser`: `4` tests passed.
- `libs/logs`: `11` tests passed.
- `libs/react-statestore`: `4` tests passed.
- `apps/marketing`: `28` tests and the production build passed with no diagnostics or broken links.
- `libs/frontman-protocol`: schema export and generated-diff check passed.
- `test/astro-compat`: package verification passed.
- WordPress packaging for version `2.0.0`: passed.
- Changed shell files: `bash -n` passed.
- `git diff --check`: passed.
- Root and package Makefile help targets: passed.
- No standalone license-verification Make target exists; standalone license and prose files are excluded from source-comment cleanup and remain unchanged.
- `libs/frontman-vite`: ReScript build passed, but its existing test target reports no test files; the plan already requires creation of the package test suite during adapter migration.
- WordPress core-tool tests: passed under PHP `8.4.24`.
- WordPress runtime tests: passed against WordPress `7.0.2` and PHP `8.4.24` using Docker on OrbStack.

### Proof Gate

- [x] The repository-wide source-aware comment scan passes on tracked authored source files.
- [x] Existing build, test, license, and packaging checks pass after the standalone cleanup. All defined checks pass; no standalone license-verification target exists.
- [x] The cleanup contains no protocol or behavioral changes. MCP behavior remains unchanged; Makefile help and lint behavior were adjusted only to preserve existing developer workflows under the source-comment policy.

Current proof-gate result: accepted and merged. The source scan, builds, tests, packaging, WordPress core-tool and runtime tests, and generated checks pass. At that `2026-08-07` prerequisite checkpoint the Vite package had no test files; the later MCP adapter suite now passes `7` tests.

## Phase 0: Normative Oracle And Traceability

### Work

Pin the authoritative TypeScript schema and generated `2026-07-28` JSON Schema at the same immutable upstream commit. Treat the TypeScript schema as the source of truth and the JSON Schema as validation tooling. Record the TypeScript schema's immutable URL and checksum without vendoring its commented source; vendor the generated JSON Schema unchanged.

Record both upstream artifacts and vendor the generated JSON Schema unchanged with:

- Upstream repository and commit.
- Original source path and immutable URL.
- SHA-256 checksum.
- Upstream license.
- A statement that local modifications are absent.

Pin official examples and the official conformance runner or a checksum-pinned source archive.

Create a normative traceability matrix with these columns:

| Requirement ID | Normative text | Applicability | Code location | Positive test | Negative test | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

Record every applicable `MUST`, `MUST NOT`, `REQUIRED`, `SHOULD`, and `SHOULD NOT` from:

- Base protocol.
- Versioning.
- Custom transport rules.
- Streamable HTTP.
- Discovery.
- Tools.
- Caching.
- Pagination.
- MRTR, recorded as not implemented unless a later separately approved feature changes applicability.
- Cancellation.
- Progress if implemented.
- Authorization and security.
- Extension negotiation.

Define explicit implementation limits:

- Maximum HTTP body bytes.
- Maximum JSON nesting depth.
- Maximum metadata bytes and keys.
- Maximum tool count and definition bytes.
- Maximum pagination pages, cursor bytes, accumulated tools, and one bounded invalid-cursor restart without cursor interpretation or equality-based rejection.
- Maximum schema depth, subschemas, and validation duration.
- Maximum result content blocks and decoded media bytes.
- Request idle and absolute timeout policies.
- Maximum bounded late-response tracking retained by the chosen minimal correlation design.
- Ownership lease duration.

### Proof Gate

- Vendored artifacts pass checksum verification offline.
- The schema is loaded with a JSON Schema 2020-12 validator.
- Official examples validate against their named upstream definitions.
- The traceability matrix contains every applicable normative requirement.
- Limits have concrete values, measurement and rejection behavior, owners, and exact at-boundary and immediately-over-boundary test vectors. Each owning implementation phase must pass its vectors before acceptance; Phase 0 must not add parallel placeholder runtime owners merely to execute future tests.

### Acceptance Record

- [x] Vendored schema, examples, license, and conformance archive checksums verify offline.
- [x] The unchanged generated schema loads with Ajv's JSON Schema 2020-12 validator.
- [x] All `129` official examples validate against the upstream definition named by their directory.
- [x] The four traceability matrices structurally verify `443` unique requirement IDs with the required evidence columns.
- [x] Initial applicability decisions include explicit non-applicable and deprecated features, core `input_required` recognition without automatic MRTR machinery, latest-only version handling, and no OAuth conformance claim for existing WordPress authentication.
- [x] Every implementation limit has a concrete inclusive maximum, measurement rule, rejection behavior, owner, and exact at-limit and immediately-over-limit proof vector.
- [x] The threat model records assets, trust boundaries, mitigations, current evidence, planned release evidence, and residual risks.
- [x] Root and package `mcp-verify` targets and CI run the offline oracle and traceability gates.

### Implementation Evidence

- Specification release commit: `5f5440bb26a62e2cf3440b92da5a667efa03b267`.
- Authoritative TypeScript schema SHA-256: `742750af0bb8c716e7030c4977c992b55d1adc4407e9e66997db5846baedc2cd`; its immutable URL is recorded without vendoring the commented source.
- Vendored generated JSON Schema SHA-256: `ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203`.
- Conformance source commit: `c321dd32035556e6769d3724a8ee97d87c3faaac`; vendored archive SHA-256: `57ecc92fc89d9a51139713a7ea92e1376929b2a1bcae2b735b4c303e15ed23d9`.
- Provenance, checksums, unchanged schema, official examples, license, and conformance archive: `libs/frontman-protocol/test/mcp-upstream/`.
- Offline oracle verifier: `libs/frontman-protocol/scripts/VerifyMcpOracle.mjs` using Ajv's JSON Schema 2020-12 implementation and `ajv-formats`.
- Oracle regression tests: `libs/frontman-protocol/test/VerifyMcpOracle.test.mjs`, covering changed, omitted, and duplicate manifest artifacts plus an upstream-definition negative case.
- Traceability index and matrices: `docs/mcp/traceability.md` and `docs/mcp/traceability/`.
- Traceability structural verifier and tests: `libs/frontman-protocol/scripts/VerifyMcpTraceability.mjs` and `libs/frontman-protocol/test/VerifyMcpTraceability.test.mjs`.
- Frozen decisions, limits, and threat model: `docs/mcp/phase-0-decisions.md`, `docs/mcp/implementation-limits.md`, and `docs/mcp/threat-model.md`.
- At this Phase 0 checkpoint, the public oracle verification commands were `make -C libs/frontman-protocol mcp-verify` and root `make mcp-verify`; the root command then forwarded only to the package target. The later root aggregate implementation supersedes that historical behavior.
- CI ownership: `.github/workflows/ci.yml` runs the oracle, traceability, and generated-schema checks for protocol, MCP documentation, and root Makefile changes.
- Verification result on `2026-08-08`: six verifier tests passed, all `129` official examples validated, all `443` traceability requirement IDs verified, generated schemas were current, the repository source-comment gate passed, Make help exposed both verification targets, and `git diff --check` passed.

Phase 0 accepted on `2026-08-08`. Runtime rows remain `Planned` until their owning phases replace planned locations with implementation and positive/negative test evidence.

## Phase 1: Shared MCP Wire Contract

### Work

Replace the existing initialization-era `FrontmanProtocol__MCP.res` contract in place and consolidate common values into the existing `FrontmanProtocol__JsonRpc.res` and `FrontmanProtocol__ContentBlock.res` modules. Delete any parallel `MCP20260728` runtime export and its duplicate generated schemas before completing this phase.

Implement exact modern wire contracts required by Frontman's initial methods for:

- JSON-RPC request IDs as string or integral number.
- Request metadata.
- Result metadata.
- Implementations and icons.
- Client and server capabilities.
- Namespaced extensions.
- Cache scope.
- `server/discover` request and result.
- Standard Tool definitions.
- `tools/list` request and result.
- `tools/call` request.
- Complete tool result.
- Input response/request maps and input-required results needed for exact tools-call interoperability.
- Cancellation notification parameters and notification metadata.
- Generic lossless notification, result-response, and error-response envelopes.
- The decoded Streamable HTTP SSE message domain.
- Standard content blocks.
- Modern protocol errors.

Every request must include:

```json
{
  "_meta": {
    "io.modelcontextprotocol/protocolVersion": "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities": {},
    "io.modelcontextprotocol/clientInfo": {
      "name": "frontman",
      "version": "<application-version>"
    }
  }
}
```

Every normal result must include:

```json
{
  "resultType": "complete"
}
```

Complete tool results support:

- Text content.
- Image content.
- Audio content.
- Resource links.
- Embedded text resources.
- Embedded blob resources.
- Arbitrary JSON `structuredContent`, including object, array, string, number, boolean, and null.

Remove from the core MCP schema:

- `initializeParams`.
- `initializeResult`.
- `callId`.
- `Suspended` without a response.
- Unnamespaced Frontman policy fields.

Represent only explicit task context and durable execution identity through one documented extension. This extension is mandatory for the custom Phoenix transport because safe execution ownership has no core-protocol fallback. A peer that does not negotiate it cannot execute a Frontman-owned browser tool call.

Advertise it under `capabilities.extensions`, provisionally:

```json
{
  "capabilities": {
    "extensions": {
      "ai.frontman/execution-context": {
        "version": 1
      }
    }
  }
}
```

Use vendor metadata such as:

```json
{
  "_meta": {
    "ai.frontman/execution-context": {
      "taskId": "...",
      "toolCallId": "..."
    }
  }
}
```

Map read behavior to standard annotations, filter hidden tools before serialization, and keep execution timing and interaction policy internal. Do not put `access`, `visibleToAgent`, or `executionMode` on the wire.

The exact extension shape and missing-extension error must be documented before implementation and tested for negotiation, preservation, and rejection of absent or malformed values. Do not implement a compatibility fallback.

### Proof Gate

- Every emitted wire fixture validates against the pinned official definition.
- Differential/property tests prove that values accepted by local schemas are accepted by upstream schemas, including ID, progress token, cancellation ID, icon theme, audience, resource size, tool input-schema root, and metadata boundaries.
- Required-field deletion tests fail validation.
- Wrong-type mutation tests fail validation.
- Arbitrary valid vendor metadata survives round-trip unchanged.
- Arbitrary JSON `structuredContent` survives round-trip unchanged.
- IDs preserve exact string or numeric type and value within the documented inclusive JavaScript safe-integer domain.
- ReScript and Elixir fixtures are structurally identical.

### Accepted Implementation Record

Status: review slices 1-5, the consumer cutover/evidence slice, deterministic differential generation, and final cleanup review are implemented; Phase 1 is accepted.

The review slices are checkpoints inside one atomic Phase 1 migration. They were not independently releasable states. Shared/custom-Phoenix consumers are cut over, initialization-era MCP schemas and duplicate modern artifacts are deleted, the shared protocol version is current, and the Phase 1 proof gate passes. The private HTTP relay is intentionally unchanged pending Phases 2-3, so Phase 1 acceptance is not complete-product release acceptance.

#### Review Slice 1: JSON-RPC Request IDs

Implemented in the existing `FrontmanProtocol__JsonRpc.res` owner:

- Replaced the internal numeric ID representation from ReScript `int` to JavaScript `float`, preserving exact numeric JSON IDs beyond the signed 32-bit range through both inclusive JavaScript safe-integer limits.
- Preserved string IDs as a distinct variant and retained exact string-versus-number wire type through parse and serialization.
- Changed generic request and response records, constructors, and accessors to use the shared abstract ID type rather than `int`.
- Added an explicit `fromInt` adapter for the existing ACP request counter and an optional `toInt` conversion at the ACP-only response-correlation boundary.
- Kept safe-integer parsing and serialization free of `Float.toInt`; the only narrowing operation is the explicit checked ACP compatibility conversion.
- Attached the local `string | safe integer` JSON Schema to the transformed Sury schema so generated request and response schemas expose the documented inclusive `-9,007,199,254,740,991` through `9,007,199,254,740,991` range rather than signed 32-bit limits or an unconstrained `{}` ID.
- Removed unused public `fromNumber` and `fromString` constructors after review; current callers either originate ACP integer IDs or parse peer IDs through the schema.
- Updated `FrontmanClient__ACP__Protocol.res`, `FrontmanClient__ACP__Client.res`, and existing JSON-RPC tests for the abstract ID boundary.

Evidence:

- `libs/frontman-protocol/test/VerifyMcpJsonRpcId.test.mjs` differentially checks locally accepted and rejected IDs against upstream `RequestId`.
- Accepted vectors include empty and non-empty string IDs, zero, negative one, `2,147,483,648`, and both JavaScript safe-integer limits.
- Rejected vectors include null, booleans, fractional numbers, objects, arrays, NaN, infinity, and the first positive and negative unsafe integers. Focused tests record that upstream's unrestricted integer schema accepts the two unsafe values while Frontman rejects them to prevent ID aliasing.
- Request and response envelope tests preserve string and wide numeric IDs exactly.
- Generated `schemas/jsonrpc/request.json`, `schemas/jsonrpc/response.json`, and every modern dependent schema expose string IDs or integers bounded to the documented JavaScript safe range.

#### Review Slice 2: Content Blocks And Complete Tool Results

Implemented in the existing `FrontmanProtocol__ContentBlock.res`, `FrontmanProtocol__MCP.res`, and `FrontmanProtocol__Tool.res` owners:

- Consolidated text, image, audio, resource-link, embedded-text-resource, and embedded-blob-resource values into the existing shared content module.
- Replaced the old annotation `_meta` placeholder with the official optional `audience`, `priority`, and `lastModified` fields.
- Restricted annotation audiences to `assistant` and `user` and priority to the inclusive `0.0` through `1.0` range.
- Added complete optional resource-link fields: title, description, MIME type, integral size, icons, annotations, and metadata.
- Restricted icon themes to `dark` and `light`.
- Represented resource size as an integral JavaScript number rather than ReScript `int`, avoiding another signed 32-bit narrowing defect.
- Added `_meta` to embedded text and blob resource contents and updated every current ReScript constructor with an explicit value.
- Required every content `_meta` value to be a JSON object.
- Added runtime URI validation for resource and icon locations while exporting the upstream `format: "uri"` schema.
- Added runtime standard-Base64 validation for image, audio, and blob data while exporting the upstream `format: "byte"` schema.
- Changed `CallToolResult.structuredContent` from an object dictionary to arbitrary `JSON.t`.
- Changed structured-result construction to preserve the original JSON value instead of narrowing through `JSON.Decode.object`.
- Required `resultType: "complete"` in the initial complete tool-result schema and every existing result constructor.
- Regenerated the MCP tool-result schema and every ACP schema that embeds the shared content schema.
- Updated browser MCP, ACP content, screenshot, attachment, annotation, and registry fixtures to use the modern result discriminator, embedded-resource metadata field, and valid Base64 data.

Evidence:

- `libs/frontman-protocol/test/VerifyMcpContentBlock.test.mjs` round-trips all official content variants and validates each against its named upstream definition.
- Negative vectors cover unknown audiences, priority above one, fractional resource size, unknown icon theme, non-object metadata, malformed Base64, and malformed URI.
- Structured-content vectors cover object, array, string, number, boolean, and null and validate as upstream `CallToolResult` values.
- Empty `content: []` is accepted by the shared complete tool-result schema.
- Generated `schemas/mcp/callToolResult.json` requires `content` and `resultType`, permits arbitrary `structuredContent`, and carries the constrained nested content schemas.

#### Review Slice 3: Metadata, Identity, Capabilities, And Extension Foundations

Implemented as seven separately reviewed checkpoints in `FrontmanProtocol__MCP.res`, the shared `FrontmanProtocol__MCPMetadata.res` boundary, generated schemas, and focused upstream verifier tests:

1. Added one shared metadata-object validator that preserves arbitrary JSON values while enforcing the normative key grammar, the frozen `64` immediate-key limit, and the frozen `16,384` compact UTF-8 byte limit.
2. Added the exact modern `Implementation` contract with required `name` and `version`, optional title, description, website URI, and reuse of the existing constrained content icon type and schema.
3. Added namespaced extension maps whose identifiers reuse metadata key validation with a mandatory prefix and whose values are JSON settings objects.
4. Added open `ClientCapabilities` validation for elicitation, experimental capabilities, extensions, roots, and sampling while preserving unknown capabilities unchanged.
5. Added open `ServerCapabilities` validation for completions, experimental capabilities, extensions, logging, prompts, resources, and tools while preserving unknown capabilities unchanged.
6. Added exact open request metadata with required protocol version and per-request client capabilities; optional implementation identity, logging level, and string-or-safe-integral local progress token; and lossless vendor metadata preservation.
7. Added exact open result metadata with optional server identity and lossless vendor metadata preservation, then applied it to complete tool results.

Implementation details:

- `FrontmanProtocol__MCPMetadata.res` owns generic metadata shape, grammar, limits, generated-schema constraints, and compact UTF-8 measurement.
- Request and result metadata validate their reserved fields without narrowing or discarding unknown valid metadata.
- The wire schema accepts any string protocol version so dispatch can return exact `UnsupportedProtocolVersionError` behavior instead of misclassifying an unsupported version as malformed JSON.
- Progress tokens reuse the shared string-or-safe-integral-number local JSON domain without adding progress notification state or advertising progress behavior.
- Client and server capability roots are dictionaries validated through known-field schemas rather than ReScript records because Sury record decoding discards unknown fields and MCP explicitly defines both capability sets as open.
- Official MCP extension identifiers under `io.modelcontextprotocol/` remain accepted by the generic extension map; the concrete Frontman execution-context contract separately proves that its own identifier uses the non-reserved `ai.frontman/` prefix.
- Complete tool-result metadata now uses `ResultMeta` rather than an unconstrained dictionary.
- Generated schemas now include `metaObject.json`, `implementation.json`, `extensions.json`, `clientCapabilities.json`, `serverCapabilities.json`, `requestMeta.json`, and `resultMeta.json`; metadata constraints also propagate into `callToolResult.json` and content-bearing dependent schemas.

Evidence:

- `VerifyMcpMetadata.test.mjs` proves valid and malformed key grammar, arbitrary JSON preservation, terminal line-separator rejection, and exact `64/65` key and `16,384/16,385` byte boundaries.
- `VerifyMcpImplementation.test.mjs` proves minimal and complete identity round trips, icon reuse, URI validation, required-field deletion, and malformed optional-field rejection.
- `VerifyMcpExtensions.test.mjs` proves mandatory prefixes, settings-object roots, official and vendor identifiers, arbitrary nested JSON settings, and generated-schema fidelity.
- `VerifyMcpClientCapabilities.test.mjs` and `VerifyMcpServerCapabilities.test.mjs` prove known-field validation, unknown-capability preservation, malformed-field rejection, and extension-identifier enforcement.
- `VerifyMcpRequestMeta.test.mjs` proves required-field deletion, every logging level, progress-token boundaries, malformed reserved-field rejection, vendor round trips, and request metadata limits including required keys.
- `VerifyMcpResultMeta.test.mjs` proves empty metadata, valid and malformed server identity, vendor round trips, metadata limits, and complete tool-result integration.
- Every locally emitted Slice 3 fixture within the pinned generated schema's accepted domain validates against the named upstream definition.
- Focused generated-schema tests compile each exported schema under JSON Schema 2020-12 and apply the same positive and negative vectors as runtime Sury validation.

#### Review Slice 4: Discovery, Tool Catalog, And Input-Response Foundations

Implemented as four separately reviewed checkpoints in the existing `FrontmanProtocol__MCP.res` owner, with minimal schema reuse changes in `FrontmanProtocol__ContentBlock.res`, generated schemas, and focused upstream verifier tests. No runtime dispatcher, caching engine, pagination loop, MRTR workflow, or tool execution behavior was added.

##### Checkpoint 4.1: Server Discovery

- Added exact `DiscoverRequest`, `DiscoverResult`, and `DiscoverResultResponse` wire schemas with required JSON-RPC constants, non-null string-or-safe-integral local IDs, required request metadata, open server capabilities, supported versions, optional instructions/result metadata, and required cache hints.
- Added shared `CacheScope` values for `private` and `public` and a non-negative integral cache TTL domain reaching `Number.MAX_SAFE_INTEGER` in positive tests.
- Preserved the upstream open-string `resultType` domain after independent review caught an initial incorrect narrowing to `"complete"`; Frontman-owned producers will emit `"complete"`, but shared parsers must not contradict the named upstream result schema.
- Kept the existing legacy `protocolVersion` constant and runtime dispatch unchanged because this checkpoint defines wire data only and is not an independently deployable cutover.

Evidence:

- `VerifyMcpDiscovery.test.mjs` round-trips all three official discovery fixtures and differentially validates runtime parsing and generated schemas against `DiscoverRequest`, `DiscoverResult`, and `DiscoverResultResponse`.
- Required-field deletion and wrong-type matrices cover both envelopes, required `_meta`, capabilities, versions, result type, TTL, cache scope, optional instructions, and optional result metadata.
- Cache vectors cover both scopes, zero, positive values, and the maximum safe JavaScript integer.
- Generated schemas are `discoverRequest.json`, `discoverResult.json`, and `discoverResultResponse.json`.

##### Checkpoint 4.2: Standard Tool Definitions

- Added the standard `Tool` contract with required `name` and object-rooted `inputSchema`; optional title, description, output schema, icons, annotations, and metadata; and no Frontman-private wire fields.
- Added open tool-annotation validation for standard title, destructive, idempotent, open-world, and read-only hints while preserving unknown hints unchanged. These hints remain untrusted data and do not drive authorization or execution policy.
- Reused the constrained icon and metadata owners rather than creating duplicate validation.
- Preserved arbitrary JSON Schema keywords. `inputSchema` requires root `type: "object"`; `outputSchema` remains an object containing any valid output schema, including a schema whose described instance root is an array.
- Deliberately did not narrow tool names to the recommended 1-128 character safe subset because the authoritative `Tool` schema accepts any string. Emitted Frontman catalogs still require a later policy check for the normative naming recommendations and uniqueness.

Evidence:

- `VerifyMcpTool.test.mjs` round-trips all six official Tool fixtures: default 2020-12 input, explicit draft-07 input, no parameters, composition, structured object output, and array output.
- The fixture oracle explicitly selects only default JSON Schema 2020-12 or the official draft-07 URI and throws for an unrecognized official-fixture dialect rather than silently treating it as 2020-12.
- Full metadata, icons, standard/unknown annotations, required-field deletion, wrong-type optional fields, invalid input roots, and the upstream broad tool-name string domain are covered.
- Generated `tool.json` matches the local runtime domain and validates the same vectors under AJV 2020-12.
- Full bounded validation of arbitrary untrusted schema keywords and declared dialects is implemented by the accepted Phase 3 browser Worker and accepted Phase 9 server monitored-process validator. The shared wire parser deliberately remains structural and does not perform unbounded runtime compilation.

##### Checkpoint 4.3: Tools List

- Added exact `ListToolsRequest`, `ListToolsResult`, and `ListToolsResultResponse` schemas with required request metadata, optional opaque cursor, Tool arrays, optional next cursor/result metadata, open result type, and required cache hints.
- Extracted discovery's identical TTL validation into one shared `CacheTtl` owner so discovery and list results cannot drift.
- Accepted absent, empty, and arbitrary string cursors exactly. Empty strings are valid cursors and must not be interpreted as end-of-pagination.
- Accepted empty Tool arrays while validating every populated entry through the standard Tool contract.
- Added wire support only. No server pagination machinery, page aggregation, freshness clock, cache key, invalidation, polling, or authorization-context cache was implemented.

Evidence:

- `VerifyMcpListTools.test.mjs` round-trips the official request, result, and response fixtures and validates local/generated/upstream agreement.
- Tests cover exact envelopes, required metadata shape, absent/empty/opaque cursors, empty catalogs, malformed tools, open core/vendor result types, both cache scopes, zero/wide TTLs, optional result metadata, and complete deletion/mutation matrices.
- Generated schemas are `listToolsRequest.json`, `listToolsResult.json`, and `listToolsResultResponse.json`.
- Independent review initially requested schema-level rejection of unsupported protocol-version strings; that request was declined because `RequestMetaObject` intentionally accepts any string and dispatch must return `UnsupportedProtocolVersionError` for a well-formed unsupported version.

##### Checkpoint 4.4: InputResponses Prerequisite

- Investigation of `CallToolRequestParams` showed that exact `tools/call` parsing depends on the complete optional `InputResponses` union, not merely `{name, arguments}`. The work was split at that dependency rather than introducing a permissive placeholder that would accept malformed MRTR retries.
- Added lossless pinned-schema shape validation for the three permitted `InputResponse` values: `ElicitResult`, `CreateMessageResult`, and `ListRootsResult`.
- Added elicitation action and form-value validation for strings, integral numbers, booleans, and string arrays while preserving wide integral values without ReScript `int` narrowing.
- Added sampling result validation for assistant/user roles, model, open stop reason, metadata, single or array text/image/audio/tool-use/tool-result content, complete standard content inside tool results, and arbitrary structured tool-result JSON.
- Added roots result validation with required URI, optional name, and metadata.
- Exposed the existing text, image, and audio component schemas from `FrontmanProtocol__ContentBlock.res` so sampling reuses the canonical validators without widening sampling content to resource links or embedded resources at its top level.
- Used a `preserveJsonWithSchema` boundary for heterogeneous official unions. It validates each value through Sury but returns the original JSON unchanged, preventing open extra fields or future-compatible data from disappearing during decode/encode.
- Added no MRTR retry, elicitation UI, sampling execution, roots execution, request-state parsing, or capability advertisement.

Evidence:

- `VerifyMcpInputResponses.test.mjs` round-trips the official combined InputResponses fixture plus every vendored ElicitResult, CreateMessageResult, and ListRootsResult example.
- Positive vectors cover all permitted response categories, empty roots, maximum-safe integral elicitation values, metadata-bearing values, tool-use arrays, and standard tool-result content.
- Negative vectors cover fractional/null/object elicitation values, invalid roles, forbidden top-level sampling resource links, malformed tool-use/tool-result blocks, missing model, malformed roots, unknown actions, and non-object response maps.
- Generated `inputResponses.json` compiles under AJV 2020-12 and applies the same nested unions and content constraints as runtime validation.
- Review slice 5 part 1 subsequently tightens Root values to the normative `file://` domain and records the pinned generated-schema discrepancy below.

#### Review Slice 5 Part 1: Normative Root URI Restriction

- Added a `ListRootsResult.fileUriSchema` refinement requiring the `file` scheme and `//` delimiter while retaining URI-format validation.
- Extended the generated schema with both `format: "uri"` and a case-insensitive-by-construction file-scheme pattern so runtime and generated validation enforce the same domain.
- Kept Roots deprecated, unadvertised, and non-operational; this change only validates Root-shaped values nested in interoperable `InputResponses`.
- Preserved both official `ListRootsResult` fixtures as positive local, generated, and upstream evidence.
- Added an uppercase-scheme positive vector per RFC 3986, negative HTTP and malformed-file vectors, and an explicit assertion that the pinned generated upstream `InputResponses` schema accepts an HTTP root despite the authoritative TypeScript source and specification prose requiring `file://`.

Documentation:

- [Roots / Root](https://modelcontextprotocol.io/specification/2026-07-28/client/roots#root) states that a Root URI must be a `file://` URI.
- [Immutable authoritative TypeScript schema](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts) states that `Root.uri` must start with `file://`.
- [RFC 3986 section 3.1](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.1) defines URI schemes as case-insensitive, so receivers accept uppercase scheme spelling while producers should use lowercase.
- The pinned generated `Root` definition at `libs/frontman-protocol/test/mcp-upstream/schema.json` describes the requirement but encodes only `format: "uri"`; the focused discrepancy test prevents that omission from widening Frontman's accepted domain.

#### Review Slice 5 Part 2: Tools Call Request

- Added exact `CallToolRequestParams` and `CallToolRequest` schemas with required request metadata and tool name, optional object arguments, validated optional `InputResponses`, and optional opaque string request state.
- Reused the shared request metadata, JSON-RPC ID, and InputResponses owners so protocol-version metadata, capabilities, wide IDs, Root restrictions, and nested MRTR response validation cannot drift.
- Added generated `callToolRequestParams.json` and `callToolRequest.json` schemas.
- Kept the standard parameter object open as upstream defines it; `callId` is neither declared nor required, but unknown extra fields are not rejected by inventing a closed-object restriction.
- Added official request and parameter fixture round trips, complete required-field deletion and wrong-type matrices, absent/empty/nested argument vectors, wide IDs, retry input responses, opaque empty request state, open-object acceptance, and generated-schema proof that private `callId` is absent from the declared contract.
- Added wire support only. No dispatcher, execution, MRTR retry workflow, request-state interpretation, or legacy consumer cutover was implemented.

Documentation:

- [Tools / Calling Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools#calling-tools) defines the initial and MRTR retry request shapes.
- [Schema / CallToolRequest](https://modelcontextprotocol.io/specification/2026-07-28/schema#calltoolrequest) defines the exact envelope and required parameter fields.
- [MRTR / Client Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#client-requirements-basic-workflow) defines exact request-state echoing and independent retry IDs; this slice models those fields but adds no retry behavior.

#### Review Slice 5 Part 3A: List Roots Input Request

- Added the exact nested `ListRootsRequest` contract with required `method: "roots/list"`, optional params, and optional generic metadata.
- Used the existing lossless validated-JSON boundary because official nested request objects are open and the official fixture carries an undeclared `id`; accepted unknown fields survive wire round trip unchanged.
- Added generated `listRootsRequest.json` and focused official-fixture, absent-params, metadata, open-field, required-method, wrong-method, and malformed-params evidence.
- Added wire validation only. Roots remain deprecated and unadvertised, and no roots fulfillment or MRTR machinery was added.
- InputRequests union assembly and InputRequiredResult were completed subsequently in review slice 5 part 3D; the ElicitRequest and CreateMessageRequest variants are completed below.

Documentation:

- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) defines `ListRootsRequest` as one of exactly three permitted nested request variants.
- [Roots / Listing Roots](https://modelcontextprotocol.io/specification/2026-07-28/client/roots#listing-roots) defines the nested `roots/list` method shape.
- [Roots deprecation notice](https://modelcontextprotocol.io/specification/2026-07-28/client/roots) requires new implementations not to adopt Roots; structural recognition here does not advertise or fulfill it.

#### Review Slice 5 Part 3B: Elicitation Input Request

- Added exact lossless `ElicitRequest`, `ElicitRequestFormParams`, and `ElicitRequestURLParams` contracts for nested MRTR request recognition.
- Added the complete restricted `PrimitiveSchemaDefinition` union: string, number/integer, boolean, untitled/titled/legacy single-select enum, and untitled/titled multi-select enum shapes.
- Preserved open fields through validated JSON boundaries and retained wide non-negative integer-valued length/item bounds without ReScript `int` narrowing.
- Accepted omitted form mode as required for backward compatibility, validated URL mode through the shared URI owner, and did not invent an HTTPS-only wire restriction.
- Added four generated schemas and focused official-fixture, every-primitive-variant, omitted-mode, open-field, required-field, wrong-type, malformed-schema, nested-object, enum-array, negative/fractional bound, and invalid-URI evidence.
- Recorded that the pinned TypeScript and generated schemas type length/item bounds as integers without non-negative minima even though these are JSON Schema 2020-12 validation keywords; local runtime and generated schemas enforce the normative non-negative domain, and the focused test proves the upstream artifact discrepancy.
- Added shape recognition only. Frontman does not advertise elicitation, render forms, navigate URLs, collect sensitive data, fulfill requests, or retry automatically.

Documentation:

- [Elicitation / Elicitation Requests](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#elicitation-requests) defines form-mode omission and the form/URL union.
- [Elicitation / Requested Schema](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#requested-schema) defines the complete restricted primitive schema domain.
- [JSON Schema 2020-12 validation keywords](https://json-schema.org/draft/2020-12/json-schema-validation#name-validation-keywords-for-str) define length and item-count bounds as non-negative integers.
- [Elicitation / URL Mode](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#url-mode-elicitation-requests) defines required URL-mode fields and URI validation.
- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) identifies ElicitRequest as one of the three permitted nested request variants.

#### Review Slice 5 Part 3C: Sampling Input Request

- Added exact lossless `CreateMessageRequest` and `CreateMessageRequestParams` contracts with required messages and integral max tokens plus every standard optional sampling field.
- Added SamplingMessage, ModelPreferences, ModelHint, and ToolChoice contracts while reusing shared content, metadata, Tool, priority, and wide-integer owners.
- Preserved single-versus-array content and open fields at the wire boundary while normalizing content only inside the semantic validator.
- Added role-sensitive runtime validation requiring tool uses on assistant messages, tool results on user messages, result-only user messages, immediate adjacency, and one matching result per tool-use ID.
- Added six generated schemas and focused official-fixture, direct nested/open-contract round trips, optional-domain, priority boundary, wide max-token, required-field, wrong-type, message-content, tool-choice, and invalid tool-sequence evidence.
- Recorded that upstream and generated JSON Schemas validate only structure and cannot express cross-message tool sequencing; focused tests prove semantic-invalid vectors remain structurally accepted while local runtime validation rejects them.
- Added shape and semantic recognition only. Sampling remains deprecated and unadvertised; no model call, prompt retention, provider adaptation, tool execution, or fulfillment machinery was added.

Documentation:

- [Sampling / Creating Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#creating-messages) defines the nested request and parameter fields.
- [Sampling / Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#messages) defines roles and permitted content.
- [Sampling / Tool Result Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#tool-result-messages) requires result-only user messages.
- [Sampling / Tool Use and Result Balance](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#tool-use-and-result-balance) requires adjacent one-to-one tool result matching.
- [Sampling deprecation notice](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling) requires new implementations not to adopt Sampling; structural recognition here does not advertise or fulfill it.

#### Review Slice 5 Part 3D: Input Requests And Input-Required Result

- Added the exact `InputRequest` union and string-keyed `InputRequests` map from the completed `CreateMessageRequest`, `ListRootsRequest`, and `ElicitRequest` contracts.
- Added lossless `InputRequiredResult` recognition with required `resultType: "input_required"`, optional result metadata, opaque string `requestState`, and the normative requirement that at least one of `inputRequests` or `requestState` is present.
- Preserved open fields at every nested request and result boundary while validating all known fields through their existing canonical schemas.
- Added generated `inputRequests.json` and `inputRequiredResult.json` schemas whose structural domains match runtime recognition, including the three-variant request union and the at-least-one-field result requirement.
- Recorded that the pinned generated upstream `InputRequiredResult` schema accepts arbitrary string result types and permits both `inputRequests` and `requestState` to be absent even though the base protocol and MRTR requirements prohibit both cases. Focused tests prove the discrepancy while local runtime and generated schemas enforce the normative domain.
- Added recognition only. Frontman does not advertise Roots, Elicitation, or Sampling; fulfill input requests; inspect request state; or automatically retry the original request.

Documentation:

- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) defines the map and its exact three request variants.
- [MRTR / InputRequiredResult](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequiredresult) defines optional input requests and opaque request state.
- [MRTR / Server Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#server-requirements-basic-workflow) requires at least one of `inputRequests` or `requestState` and restricts request values to the three standard variants.
- [Base Protocol / ResultType](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#resulttype) defines `input_required` as the core discriminator for an `InputRequiredResult` and requires clients to reject unrecognized result types.

#### Review Slice 5 Part 3E: Cancellation Notification Contract

- Added lossless `CancelledNotificationParams` and `CancelledNotification` contracts with required string-or-safe-integral `requestId`, optional reason, exact `notifications/cancelled` method, exact JSON-RPC version, and no envelope ID.
- Added `NotificationMeta` as the bounded generic metadata domain plus optional string-or-safe-integral `io.modelcontextprotocol/subscriptionId`, preserving valid vendor metadata unchanged.
- Reused the existing abstract JSON-RPC ID schema for both cancellation request IDs and subscription IDs, so string/numeric preservation and fractional/null rejection cannot drift.
- Added generated `cancelledNotification.json`, `cancelledNotificationParams.json`, and `notificationMeta.json` schemas with matching structural constraints. The runtime-only compact UTF-8 metadata byte limit cannot be represented by JSON Schema and is covered as an explicit procedural boundary.
- Recorded that the pinned generated `CancelledNotification` schema accepts an `id` property even though the base protocol forbids IDs on notifications, and that the pinned generated `NotificationMetaObject` omits the normative generic metadata key constraints. Focused tests prove both artifact discrepancies while local runtime and generated schemas enforce the normative domain.
- Added wire support only. No sender registry, timeout, abort signal, transport disconnect handling, response suppression, subscription machinery, cancellation logging, or UI state was added.

Documentation:

- [Cancellation / Cancellation Flow](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#cancellation-flow) defines the exact notification method, request ID, and optional reason.
- [Cancellation / Behavior Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#behavior-requirements) limits cancellation to previously issued requests believed to remain in progress; enforcement belongs to later transport owners.
- [Cancellation / Transport-Specific Cancellation](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#transport-specific-cancellation) states that Streamable HTTP uses response-stream closure rather than this notification.
- [Base Protocol / Notifications](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#notifications) requires notifications to omit request IDs and receive no response.
- [Base Protocol / Notification metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) defines optional subscription IDs and applies the generic metadata key rules.

#### Review Slice 5 Part 3F: Accepted Streamable HTTP SSE Messages

- Added lossless shared JSON-RPC wire schemas for generic notifications, result responses, error responses, and the exclusive result-or-error response union in the existing `FrontmanProtocol__JsonRpc.res` owner.
- Added `StreamableHttpSseMessage` as exactly `JSONRPCNotification | JSONRPCResponse`; independent JSON-RPC requests are rejected as prohibited on modern Streamable HTTP response streams.
- Required exact JSON-RPC `2.0`, object notification params when present, non-null string-or-safe-integral local IDs on result responses, required result objects with `resultType`, optional IDs on generic error responses, and integral error codes with required messages.
- Preserved valid open fields and arbitrary error data losslessly while rejecting mixed notification/request/response discriminants and responses containing both result and error.
- Added generated `streamableHttpSseMessage.json` with the same structural union and focused official notification, tool-result response, and modern error-response evidence.
- Added only the decoded JSON message domain. SSE line framing, LF/CRLF handling, comments, split UTF-8, byte limits, stream termination, correlation, notification method/capability checks, and cancellation remain later browser transport work. Frontman servers still emit synchronous JSON only.

Documentation:

- [Streamable HTTP / Receiving Messages](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#receiving-messages) permits request-related notifications before the final response and forbids independent requests on the stream.
- [Base Protocol / Notifications](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#notifications) defines ID-less JSON-RPC notifications.
- [Base Protocol / Result Responses](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#result-responses) requires matching IDs, a result object, and `resultType`.
- [Base Protocol / Error Responses](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#error-responses) defines optional readable IDs, required error code/message, and integral error codes.
- [WHATWG Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) governs framing and comment behavior but is intentionally not implemented in this shared decoded-message slice.

#### Review Slice 5 Part 3G: Modern Named Errors

- Added lossless named schemas for the five standard JSON-RPC errors: `ParseError` `-32700`, `InvalidRequestError` `-32600`, `MethodNotFoundError` `-32601`, `InvalidParamsError` `-32602`, and `InternalError` `-32603`.
- Added exact response-envelope schemas for the initially applicable MCP errors: `HeaderMismatchError` `-32020`, `MissingRequiredClientCapabilityError` `-32021`, and `UnsupportedProtocolVersionError` `-32022`.
- Required capability errors to carry `data.requiredCapabilities` through the open shared client-capabilities contract and version errors to carry string `data.requested` plus an array of string `data.supported` versions.
- Preserved open envelope, error, data, and capability fields losslessly while enforcing exact codes and required known fields.
- Exported eight focused generated schemas and added official-fixture, upstream-oracle, generated-schema, wrong-code, required-field deletion, nested-data mutation, open-field round-trip, and reserved-code inventory evidence.
- Added wire contracts only. HTTP `400` pairing, header validation, protocol-version dispatch, capability gating, runtime error construction, and removal of legacy constants remain assigned to later parts and phases.

Documentation:

- [Base Protocol / Error codes](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#error-codes) defines the standard JSON-RPC codes, the MCP-owned `-32020` through `-32099` range, and the prohibition on emitting undefined or legacy codes with modern meanings.
- [Base Protocol / Per-request capabilities](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) defines `MissingRequiredClientCapabilityError`, code `-32021`, and its required capability data.
- [Versioning / Protocol version negotiation](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning#protocol-version-negotiation) defines `UnsupportedProtocolVersionError`, code `-32022`, and the required requested/supported version data.
- [Streamable HTTP / Protocol version header](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#protocol-version-header) and [custom header validation](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#server-behavior-for-custom-headers) define `HeaderMismatchError`, code `-32020`, and the later HTTP `400` behavior.
- The immutable pinned definitions and official examples are `ParseError`, `InvalidRequestError`, `MethodNotFoundError`, `InvalidParamsError`, `InternalError`, `HeaderMismatchError`, `MissingRequiredClientCapabilityError`, and `UnsupportedProtocolVersionError` in `libs/frontman-protocol/test/mcp-upstream/schema.json` and its `examples/` tree.

#### Review Slice 5 Part 3H: Generic JSON-RPC Requests And Message Classification

- Added a lossless generic `JSONRPCRequest` schema with exact `jsonrpc: "2.0"`, a required non-null string-or-safe-integral local ID, a required string method, and optional object-only params.
- Refined the shared numeric ID boundary to the inclusive JavaScript safe-integer range and encoded the same minimum and maximum in generated schemas, preventing distinct unsafe integers from collapsing before correlation.
- Reused the shared ID and open-object preservation boundaries so string/numeric ID type, both safe-integer limits, arbitrary nested parameter JSON, empty methods, and vendor envelope fields survive unchanged.
- Added the complete local `JSONRPCMessage` union over requests, notifications, result responses, and error responses.
- Extended the existing discriminant exclusions so requests reject result/error fields and every decoded message belongs to exactly one local message class.
- Exported focused `jsonRpcRequest.json` and `jsonRpcMessage.json` schemas and added official-fixture, upstream-oracle, generated-schema, required-field deletion, wrong-type, object-params, wide-ID, open-field, exact-classification, and malformed-message evidence.
- Recorded the open-upstream-union refinement explicitly: the pinned generated `JSONRPCMessage` schema accepts mixed request/response fields because its object branches are open, while Frontman's runtime and generated schemas reject ambiguous mixed discriminants.
- Added wire classification only. Method support, request metadata, capability and protocol-version dispatch, correlation, notification handling, and response construction remain consumer responsibilities.

Documentation:

- [Base Protocol / Messages](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#messages) requires all MCP messages to use JSON-RPC 2.0 and defines the request, notification, result-response, and error-response classes.
- [Base Protocol / Requests](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#requests) requires a non-null string or integer ID and defines optional structured parameters.
- [JSON-RPC 2.0 / Request Object](https://www.jsonrpc.org/specification#request_object) defines exact `jsonrpc`, method, structured params, and request-ID semantics.
- [ECMAScript `Number.isSafeInteger`](https://tc39.es/ecma262/#sec-number.issafeinteger) defines the exact numeric domain Frontman's JavaScript transports can preserve without integer aliasing; this is an explicit local implementation limit, not an MCP restriction.
- The immutable pinned `JSONRPCRequest` and `JSONRPCMessage` definitions and official request/notification/result/error examples are under `libs/frontman-protocol/test/mcp-upstream/`.

#### Review Slice 5 Part 3I: Frontman Execution Context Extension

- Defined the concrete `ai.frontman/execution-context` version `1` settings contract and proved that its reverse-DNS identifier is accepted by the shared extension and metadata grammar without using an MCP-reserved prefix.
- Added lossless required client-capability and server-capability schemas for bilateral extension advertisement while preserving unrelated extensions, capabilities, and settings fields.
- Added separate custom-Phoenix-transport schemas for compatible per-request client advertisement and request metadata carrying non-empty opaque `taskId` and durable `toolCallId` values. Keeping these schemas separate preserves the distinction between missing capability `-32021` and malformed context `-32602`.
- Kept the generic request metadata and Streamable HTTP contracts unchanged; only browser execution over the custom Phoenix transport requires this extension.
- Defined exact no-fallback behavior: absent or incompatible browser-server advertisement fails locally as `missing_required_server_extension` before `tools/call`; absent or incompatible per-request client advertisement returns standard `MissingRequiredClientCapabilityError` `-32021`; missing or malformed execution context returns a correlated standard `InvalidParamsError` `-32602` response.
- Kept context parsing separate from capability negotiation so absent client support cannot be misclassified as malformed context.
- Exported five generated schemas and added identifier/version, bilateral negotiation, open-field preservation, absent/incompatible advertisement, malformed context, upstream generic-domain, and exact standard-error evidence.
- Documented the extension's scope, settings, request metadata, lifecycle, errors, fallback prohibition, and security boundary in `docs/mcp/frontman-execution-context-extension.md`.
- Added the shared contract only. Discovery advertisement, per-request assembly, dispatcher validation, durable ownership, replay protection, cancellation wiring, and authorization remain consumer work.

#### Consumer Cutover And Structural Parity Evidence

- Updated the browser custom Phoenix dispatcher to validate modern request envelopes and metadata independently for discovery, list, and call; advertise and require execution-context version `1`; emit modern named errors and complete results; and structurally receive cancellation notifications. Accepted Phase 4 subsequently makes that receiver stateful and abort-capable.
- Updated the temporary Phoenix TaskChannel path to emit discovery, list, call, and cancellation values with modern metadata, correlate string or numeric response IDs, parse results by method, and retain complete result shape through persistence and replay.
- Deleted initialization-era MCP generated schemas and duplicate modern contract exports after active consumers moved to the existing shared MCP and JSON-RPC owners. ACP initialization remains a separate protocol and is not part of this deletion.
- Added `mcp-phase1-parity.json` as one shared deterministic fixture consumed by focused Node and Elixir tests. It covers discovery request/result, list request/result, execution-context-bearing call, complete result, unsupported-version named error, cancellation, and both request-ID wire types.
- Added a major changeset for `@frontman-ai/frontman-protocol` and `@frontman-ai/frontman-client`. No other package is named because this evidence slice establishes no additional public package API break.
- Kept cancellation claims structural: the browser receiver validates cancellation notifications, but does not correlate them, abort executing work, or prove late-response suppression.
- Did not implement or claim Streamable HTTP, framework dispatch, Phase 2 behavior, durable execution ownership, or full runtime cancellation.
- The evidence slice found that the shared ReScript `protocolVersion` export still said `2025-11-25`; the consumer-cutover follow-up corrected it to `2026-07-28`. Literal-version regression evidence remains part of the complete gate.

Documentation:

- [MCP statelessness](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#statelessness) requires explicit identifiers for state spanning requests and prohibits inferring conversation state from a connection.
- [MCP extension negotiation](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning#extension-negotiation) requires prefixed identifiers, bilateral capability advertisement, and documented fallback or rejection behavior.
- [MCP per-request metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) requires client capabilities on every request and defines `MissingRequiredClientCapabilityError` for undeclared required capabilities.
- [Frontman execution-context extension](docs/mcp/frontman-execution-context-extension.md) freezes version `1` behavior and its no-fallback contract.

### Phase 1 Proof Status

| Proof criterion | Current status | Evidence or remaining work |
| --- | --- | --- |
| Emitted fixtures validate upstream | Passing | Focused official/shared fixtures and deterministic generated values pass current Node runtime schemas, generated schemas, and named upstream definitions. |
| Local accepted domain is an upstream subset | Passing with explicit authoritative-artifact discrepancies | Deterministic generation covers every domain named by the Phase 1 proof gate plus tool arguments and arbitrary structured content. Focused structural vectors cover the remaining implemented contracts. Safe numeric IDs and the concrete version `1` extension are intentional local subsets; Root, elicitation-bound, sampling-sequence, input-required discriminator/non-empty, notification-ID, notification-metadata, mixed-envelope, no-request-on-SSE, and recursive `JSONValue` differences have exact discrepancy tests and recorded source-of-truth decisions. |
| Required-field deletion fails | Passing for implemented Phase 1 contracts | Focused exhaustive matrices cover every implemented contract, and deterministic generation deletes required fields across request metadata, cancellation, Tool, tools/call, and complete tool results. |
| Wrong-type mutation fails | Passing for implemented Phase 1 contracts | Focused matrices cover shared domains, discovery/cache hints, tools/input envelopes, cancellation, generic messages, IDs, errors, extension settings/context, and wide integer boundaries. |
| Vendor and open fields round-trip | Passing at shared ReScript boundary for implemented contracts | Generic content metadata, request/result/notification metadata, generic and concrete extension settings/context, unknown capabilities, Tool annotations/metadata, list results, InputResponses, open nested requests, sampling contracts, cancellation, and generic SSE notification/result/error envelopes survive unchanged. Focused Phoenix tests prove `resultType` persistence; broader transport and application behavior remain. |
| Arbitrary structured JSON round-trips | Passing at shared ReScript boundary | Object, array, string, number, boolean, and null pass and validate upstream. Persistence, Elixir, ACP history, and model conversion remain. |
| IDs preserve type and value | Passing at shared and focused cross-language structural boundaries | Existing safe-integer boundary vectors remain, and the shared fixture gives both Node and Elixir the same string and numeric ID values. Broad transport correlation remains. |
| Sampling tool-use/result semantics | Passing at local runtime boundary | Runtime validation enforces role placement, result-only user messages, immediate adjacency, and bidirectional unique one-to-one ID matching. Focused tests explicitly prove these semantic failures remain structurally accepted by upstream/generated JSON Schemas. No sampling fulfillment is implemented. |
| Optional feature non-adoption | Passing for implemented shared shapes | Roots, Elicitation, Sampling, progress tokens, and MRTR retry fields are accepted only as required interoperable wire shapes. No capability advertisement, UI, model invocation, root lookup, URL navigation, progress engine, or automatic retry was added. |
| ReScript and Elixir fixtures match | Passing for the shared Phase 1 fixture | Both focused tests read the exact same JSON file and pass through their runtime and generated-schema boundaries. |

### Decisions And Lessons From Slices 1-5

- ReScript `int` and Sury `S.int` are unsuitable for MCP integer domains that are not explicitly signed 32-bit. They narrow runtime values and emit minimum/maximum constraints that do not exist upstream.
- JavaScript numeric IDs are accepted only in the inclusive safe-integer domain and generated schemas carry matching bounds; focused vectors prove both limits and reject the first unsafe integers even though the unrestricted upstream integer schema accepts them. Resource sizes retain the upstream unrestricted integral-number domain; later persistence and media limits must not be misrepresented as wire-schema constraints.
- Numeric identity restrictions must be enforced in the shared ID owner, not only in transport correlation code. Once an unsafe number has crossed JavaScript JSON decoding, distinct wire integers may already have aliased and no later comparison can repair the loss.
- A Sury transform over `S.json` exports `{}` unless the exact JSON Schema is attached with `extendJSONSchema`. Runtime validation and generated-schema fidelity must therefore be reviewed separately.
- Sury's decoded record representation may contain properties whose value is JavaScript `undefined`; wire round-trip tests normalize through JSON serialization before structural comparison because `undefined` properties are not JSON wire members.
- The pinned upstream `CallToolResult.structuredContent` field intentionally accepts any JSON value. It is not object-only.
- The pinned upstream `ResourceLink.size` field requires an integer but specifies no non-negative minimum. Local validation must not invent a minimum absent from the source of truth.
- The official content union contains exactly five top-level variants; embedded text and blob resources are alternatives inside the embedded-resource variant rather than additional top-level content types.
- Content `_meta` and embedded-resource `_meta` are objects. The former annotation placeholder was not a valid representation of official `Annotations`.
- Exact generated schemas propagate into ACP exports because ACP reuses the shared content owner. Regeneration must include every dependent schema, not only `schemas/mcp/callToolResult.json`.
- The smallest public ID API currently needed is parse-through-schema, `fromInt` for ACP, checked `toInt` for ACP, and `toJson`. Unused convenience constructors were removed rather than retained for hypothetical callers.
- Offline oracle and differential checks remain authored Node tests named `VerifyMcp*.test.mjs`, matching the accepted Phase 0 verifier infrastructure. ReScript runtime tests continue to use generated `*.test.res.mjs` artifacts.
- Review claims must be checked against the pinned artifact. Two automated-review claims were rejected because they contradicted the vendored schema: object-only structured content and a non-negative resource-size minimum.
- Generic metadata is a shared MCP boundary rather than a collection of per-record dictionaries. This is required so key grammar and frozen byte/key limits cannot drift between content, requests, and results.
- JavaScript regular-expression `$` can match before a terminal line separator. Metadata key validation therefore uses an explicit absolute-end guard, with newline, carriage return, U+2028, and U+2029 regression vectors.
- The normative metadata grammar permits an empty name, including an empty key or a prefix-only key such as `a/`. Automated-review requests to reject those values were declined because they contradicted the specification's explicit "unless empty" wording.
- Sury record parsing drops unknown object fields. Open MCP capability sets must validate known fields while returning the original dictionary unchanged; otherwise future and vendor capabilities disappear during round trip.
- Protocol-version schema validation accepts any string. Latest-only support is enforced by method dispatch with `-32022`, which preserves the distinction between malformed metadata and a well-formed unsupported version.
- Progress-token validation does not imply progress support. Frontman accepts strings and locally safe integral numbers through the shared ID domain but does not advertise or implement progress machinery.
- `clientInfo` and `serverInfo` are validated implementation identities only. They remain display/debugging data and cannot influence behavior, disambiguation, authentication, or authorization.
- The authoritative TypeScript and rendered schema define `JSONValue` as string, number, boolean, null, object, or array, but the pinned generated JSON Schema omits null and narrows numbers to integers inside recursive `JSONObject` values. Frontman follows the authoritative TypeScript/rendered contract and accepts recursive null and fractional values. `VerifyMcpExtensions.test.mjs` proves local/generated Frontman preservation and the exact pinned-upstream generated-schema rejection; this recorded exception remains until upstream corrects its generated artifact.
- Named discovery and tools-list result schemas expose `resultType` as an open string. Frontman-owned normal producers emit `"complete"`, but shared parsers must accept the upstream open domain; the first discovery implementation incorrectly narrowed it and independent review caught the mismatch.
- Required cache hints are one structural domain shared by discovery and list results. One `CacheTtl` validator now owns non-negative integral TTL validation, and `CacheScope` owns `private | public`; runtime freshness, cache keys, authorization isolation, and invalidation remain separate behavior.
- Empty pagination cursors are valid opaque tokens. Code must test option presence rather than string truthiness, and no decoder may parse or normalize cursor contents.
- Tool name safety and uniqueness are normative recommendations and server-emission policy, not restrictions in the authoritative Tool JSON Schema. The shared parser retains the upstream string domain; later catalog assembly must enforce deterministic names and collision policy without misrepresenting peer-schema validity.
- A Tool's `inputSchema` root must describe an object, while `outputSchema` is itself a schema object that may describe any JSON result root, including arrays. Object-only output assumptions are incorrect.
- Structural Tool wire parsing is not a safe arbitrary-schema runtime validator. Full declared/default dialect validation must use the bounded Phase 3/9 validator with schema depth limits and network/file/data reference loading disabled; compiling arbitrary peer schemas synchronously in this shared parser would create a denial-of-service boundary.
- Official Tool examples require both default JSON Schema 2020-12 and explicit draft-07 handling in verification. Test helpers must select recognized dialects explicitly and fail unknown dialects rather than silently defaulting them.
- Sury record fields are nominal. An attempted review simplification removing local known-field record declarations failed compilation and was reverted; those declarations are required for object-schema builders.
- `tools/call` cannot be modeled exactly as only name plus arguments. Its params include optional `InputResponses` and opaque `requestState`, so the complete InputResponse union is a prerequisite even though Frontman advertises no MRTR capabilities and implements no automatic retry machinery.
- Heterogeneous official unions can be validated losslessly by parsing through a typed Sury schema and returning the original `JSON.t`. This avoids both `Obj.magic` and field loss from record decoding while retaining exact generated-schema constraints.
- Sampling content is narrower than general MCP ContentBlock at its top level: text, image, audio, tool use, and tool result are permitted, but resource links and embedded resources are only valid inside tool-result content. Reusing the full top-level content union would be over-permissive.
- Review findings must be compared with executed evidence and the pinned contract. A claimed AJV `format: "byte"` compilation failure was rejected after the exact test suite passed with `ajv-formats`; a claimed protocol-version schema defect was rejected because dispatch-level `-32022` behavior requires the schema to accept well-formed unsupported strings.
- The Root definition contains a normative `file://` requirement not encoded by the pinned generated schema's generic URI constraint. Review slice 5 part 1 resolves this with matching local runtime and generated-schema restrictions plus an explicit upstream-discrepancy assertion; Roots remain deprecated and unadvertised.
- URI schemes are case-insensitive under RFC 3986 section 3.1. Root validation accepts `FILE://` and other scheme casing while producers should use canonical lowercase; a literal lowercase prefix test would incorrectly reject a valid URI.
- The legacy `toolCallParams` owner was deleted after consumer cutover. Modern `CallToolRequestParams` neither declares nor requires private `callId`; upstream parameter objects remain open, so an undeclared `callId` is structurally preserved as an unknown peer field rather than acquiring Frontman semantics.
- Open-object acceptance and lossless round trip are separate properties. A typed `S.object` may accept unknown fields but discard them during decode/encode. Open wire contracts that cross public boundaries use `preserveJsonWithSchema`, including nested MRTR requests, ModelHint, ModelPreferences, ToolChoice, and SamplingMessage.
- Official nested request fixtures can carry undeclared open fields. The official ListRootsRequest fixture includes `id` even though the named schema requires only `method`; lossless validators must preserve such fields rather than rebuilding a reduced record.
- Structural recognition of deprecated Roots and Sampling and optional Elicitation does not constitute feature adoption. Frontman must parse required core variants but must not advertise capabilities or add fulfillment, UI, navigation, model calls, root lookup, or retry machinery without a caller.
- `tools/call` request parameters include optional validated InputResponses and opaque requestState. Standard initial calls work without `callId`; MRTR retry field support in the wire schema does not authorize parsing requestState or implementing automatic retries.
- Elicitation form mode may omit `mode`; receivers must treat omission as form. URL mode requires a valid URI, but the wire schema does not impose HTTPS even though HTTPS is recommended outside development.
- JSON Schema 2020-12 length and item-count keywords require non-negative integers. The pinned TypeScript and generated schemas omit those minima, so local runtime/generated schemas enforce them and tests explicitly record that the upstream generated oracle accepts invalid negative values.
- ReScript nominal records with overlapping field names require explicit local type annotations in Sury object builders. Compilation caught ambiguity between titled/untitled multi-select schemas and normalized/lossless SamplingMessage records; removing these annotations is not a simplification.
- Sampling wire content accepts single or array text, image, audio, tool-use, and tool-result blocks. Single-versus-array shape and unknown fields remain lossless on the wire; normalization occurs only inside the semantic sequence validator.
- Sampling tool sequencing is normative behavior that JSON Schema cannot express. Runtime validation must reject wrong-role tool blocks, mixed tool-result user messages, missing or intervening results, unmatched IDs, duplicate tool-use IDs, and duplicate result IDs even though structural upstream/generated schemas accept those values.
- One-to-one ID comparison must prove equal cardinality, bidirectional membership, and uniqueness. Checking only that every expected ID appears once in results allows duplicate expected IDs to hide an unrelated result.
- `InputRequests` is an open string-keyed map, but every value is restricted to exactly `CreateMessageRequest`, `ListRootsRequest`, or `ElicitRequest`. An empty map is structurally valid; capability negotiation and whether requested inputs can be fulfilled are later behavior checks.
- `InputRequiredResult` recognition requires the core `input_required` discriminator and presence of at least one of `inputRequests` or opaque `requestState`. The pinned generated schema omits both restrictions, so local runtime/generated schemas enforce the normative prose and focused tests record the upstream artifact discrepancy.
- Cancellation `requestId` and notification `subscriptionId` are both the ordinary non-null string-or-safe-integral local `RequestId` domain. Runtime ownership checks determine whether an ID refers to active work; every JavaScript boundary must share the documented safe-integer restriction.
- Cancellation notification objects remain open for vendor fields but must reject an `id` member. The pinned generated schema's open object accepts `id`, so local runtime and generated schemas add the base-protocol notification prohibition explicitly.
- `NotificationMetaObject` extends the generic bounded metadata domain and optionally reserves `io.modelcontextprotocol/subscriptionId`. The pinned generated schema omits inherited generic metadata constraints, so local generated schemas restore key grammar and key count while runtime validation additionally enforces the frozen compact UTF-8 byte limit that JSON Schema cannot express.
- Streamable HTTP SSE `data:` carries complete JSON-RPC messages, not bare result values or private event payloads. The accepted decoded domain is notifications plus result/error responses; requests are rejected before method-specific handling.
- Generic wire response parsing preserves open fields but enforces mutually exclusive result/error discriminants. Generic structural acceptance does not authorize an unknown notification method or result type; pending-request and capability-aware consumers perform those semantic checks later.
- Generic error codes use integral JavaScript numbers rather than ReScript `int`, avoiding signed 32-bit narrowing before the named modern error slice applies code-specific meaning.
- Capability negotiation and extension payload validation are different protocol failure classes. Parse generic required metadata first, check required client capability next, and validate extension context only after compatible advertisement so missing support returns `-32021` rather than being absorbed into `-32602`.
- A client-side failure discovered from server capabilities is local state, not a peer JSON-RPC error. The execution-context contract uses the stable local `missing_required_server_extension` classification and forbids fabricating a JSON-RPC response that the browser never emitted.
- Independent review is advisory, not authoritative. Earlier Slice 5 reviews accepted real findings for URI scheme casing, open-contract evidence, required-field mutation coverage, non-negative JSON Schema bounds, duplicate sampling IDs, traceability precision, and nested-schema losslessness; each correction was rerun through the full protocol gate.
- Review slice 5 part 3D passed independent review without findings after proving exact InputRequests variants, the InputRequiredResult discriminator/non-empty invariant, lossless open fields, and no fulfillment behavior.
- Review slice 5 part 3E initially received one medium finding: generated JSON Schema cannot encode the runtime `16,384` compact UTF-8 metadata byte limit, while the plan overstated runtime/generated alignment and lacked a cancellation-specific boundary vector. The plan now records this procedural limit explicitly, focused tests prove `16,384/16,385` runtime behavior and the generated-schema limitation, and resumed independent review passed.
- Review slice 5 part 3F passed independent review without findings after checking notification/response-only SSE acceptance, independent-request rejection, discriminant exclusivity, optional error IDs, wide integral error codes, lossless open fields, and strict separation from framing/parser behavior.
- Review slice 5 part 3G initially received three evidence findings: required-field deletion did not cover every required envelope/error field, open client capabilities were not exercised inside the capability error, and the reserved-code inventory was derived only from test fixtures. The test matrix now deletes every required field, round-trips an unknown nested capability, and checks the centralized production `ModernErrorCode.mcpReserved` inventory against the three MCP contracts; resumed independent review passed. Runtime dispatch and HTTP status behavior remain explicitly outside this structural checkpoint.
- Review slice 5 part 3H initially received one high finding: the inherited numeric ID parser accepted unsafe JavaScript integers that cannot be correlated losslessly. The shared ID schema now uses the inclusive ECMAScript safe-integer domain, generated schemas carry matching bounds, implementation limits document the upstream-compatible narrowing, and focused tests reject both first unsafe integers while proving upstream accepts them; resumed independent review passed. Generic request validation and the four-class decoded-message union otherwise preserve the distinction between upstream structural openness and Frontman's required unambiguous local classification.
- Review slice 5 part 3I initially received one high, one medium, and one low finding: combined context/capability parsing would misclassify missing negotiation as `-32602`, missing browser-server support lacked an exact local failure, and malformed-context evidence covered only a bare error object. Context parsing and capability negotiation are now separate, missing server support uses the stable non-protocol `missing_required_server_extension` classification, and malformed context proves a correlated `-32602` response; resumed independent review passed.

Authoritative definitions used directly by these slices:

- `RequestId`, `JSONRPCRequest`, `JSONRPCNotification`, `JSONRPCResultResponse`, `JSONRPCErrorResponse`, and `JSONRPCResponse` in `libs/frontman-protocol/test/mcp-upstream/schema.json`.
- `Annotations`, `ContentBlock`, `TextContent`, `ImageContent`, `AudioContent`, `ResourceLink`, `EmbeddedResource`, `TextResourceContents`, and `BlobResourceContents` in the same pinned schema.
- `CallToolResult`, whose `structuredContent` property has no object-only type restriction and whose required fields are `content` and `resultType`.
- `MetaObject`, `RequestMetaObject`, `ResultMetaObject`, `Implementation`, `ClientCapabilities`, `ServerCapabilities`, `LoggingLevel`, `ProgressToken`, and `Icon` in the pinned schema and rendered `2026-07-28` schema reference.
- `DiscoverRequest`, `DiscoverResult`, `DiscoverResultResponse`, `Tool`, `ToolAnnotations`, `ListToolsRequest`, `ListToolsResult`, `ListToolsResultResponse`, `CallToolRequest`, `CallToolRequestParams`, `InputRequest`, `InputRequests`, `InputRequiredResult`, `InputResponse`, `InputResponses`, `ElicitResult`, `CreateMessageResult`, `ListRootsResult`, `Root`, `ListRootsRequest`, `ElicitRequest`, `ElicitRequestFormParams`, `ElicitRequestURLParams`, `PrimitiveSchemaDefinition`, `CreateMessageRequest`, `CreateMessageRequestParams`, `SamplingMessage`, `SamplingMessageContentBlock`, `ModelHint`, `ModelPreferences`, `ToolChoice`, `ToolUseContent`, and `ToolResultContent` in the pinned schema and rendered reference.
- `CancelledNotification`, `CancelledNotificationParams`, and `NotificationMetaObject` in the pinned schema, plus the rendered cancellation and base notification requirements where the generated artifact omits inherited or negative constraints.
- `ParseError`, `InvalidRequestError`, `MethodNotFoundError`, `InvalidParamsError`, `InternalError`, `HeaderMismatchError`, `MissingRequiredClientCapabilityError`, and `UnsupportedProtocolVersionError` in the pinned schema and official examples.
- The `_meta` key grammar and per-request/per-response field requirements in the base protocol, plus extension negotiation's mandatory-prefix rule.
- Traceability requirements RPC-003, RPC-005, and RPC-011 in `docs/mcp/traceability/base-versioning.md` for non-null request IDs and response ID preservation.
- Traceability requirements META-001, META-002, META-004, META-005, META-008, META-012 through META-014, and EXT-001 in `docs/mcp/traceability/base-versioning.md`, plus the structural metadata and capability requirements referenced by the Slice 3 verifier fixtures in `docs/mcp/traceability/tools-discovery.md`; dispatch, HTTP status, capability-gating, and identity-behavior requirements remain planned for later phases.

### Verification Record For Slices 1-5

Latest verification completed on `2026-08-10`, including deterministic differential generation and final Phase 1 review:

- Latest `make -C libs/frontman-protocol mcp-verify`: `116` verifier tests passed, all `129` official examples validated, and all `443` traceability requirement IDs structurally verified.
- `VerifyMcpProperty.test.mjs` passed the required `1,000` pull-request profile and the configured `10,000`-case scheduled profile locally with reproducible seed `20260728`; the focused target verifies oracle checksums before executing generated differential cases.
- `.github/workflows/mcp-property.yml` supplies the weekly/manual `10,000`-case hosted gate. Its first hosted execution remains observable CI evidence rather than a prerequisite for the locally completed Phase 1 proof, and cached per-definition upstream validators keep the full local run below two seconds.
- Protocol build and schema export passed; `85` JSON-RPC, MCP, Relay, and dependent ACP schemas were exported. Slice 5 added tools-call, nested input, cancellation, complete generic message classification, accepted SSE messages, modern named errors, execution-context contracts, and their shared supporting schemas while preserving propagated constraints.
- Focused Slice 3 tests compile generated schemas with AJV JSON Schema 2020-12 and compare runtime parsing, generated-schema validation, and named upstream definitions where the pinned generated artifact matches the authoritative type.
- Metadata boundary tests pass exact `64/65` immediate-key and `16,384/16,385` compact UTF-8 byte vectors for generic, request, result, and notification/cancellation metadata. Generated schemas enforce key grammar and count; compact serialized byte size remains a documented runtime-only procedural constraint.
- Independent review checkpoints found the identity, extension, server-capability, request-metadata, and result-metadata contracts aligned after one real terminal-line-separator regex defect was fixed; repeated requests to reject spec-permitted empty metadata names were declined with normative evidence.
- Slice 4 independent review caught the real discovery `resultType` narrowing defect, which was fixed. Tool review clarified structural wire parsing versus the later bounded runtime schema validator and tightened fixture dialect selection. List review added explicit open-result-type coverage while preserving dispatch-level protocol-version handling. InputResponses review passed after executed AJV evidence disproved a false format-registration concern; Slice 5 then resolved the separate normative Root restriction.
- Slice 5 independent reviews caught and drove fixes for case-insensitive URI schemes, missing open-object and required-field mutation evidence, negative JSON Schema bounds, duplicate sampling-ID matching, semantic-versus-structural traceability wording, lossless nested open contracts, compact metadata byte-limit overstatement, incomplete named-error evidence, unsafe numeric IDs, capability/context error conflation, and ambiguous local extension failure semantics. Every corrected checkpoint passed its resumed independent review; Parts 3D and 3F passed without findings.
- `VerifyMcpCallToolRequest.test.mjs`, `VerifyMcpListRootsRequest.test.mjs`, `VerifyMcpElicitRequest.test.mjs`, and `VerifyMcpCreateMessageRequest.test.mjs` add official fixtures, generated-schema validation, upstream differential checks, required-field deletion, wrong-type and boundary vectors, open-field round trips, explicit artifact-discrepancy assertions, and runtime-only sampling semantic checks for Slice 5.
- `VerifyMcpInputRequests.test.mjs` adds official InputRequests and InputRequiredResult fixtures, all three nested request variants, empty/open map behavior, opaque state and metadata preservation, malformed nested values, and explicit generated-artifact discrepancy assertions for the core discriminator and at-least-one-input requirement.
- `VerifyMcpCancellation.test.mjs` adds official cancellation fixtures, the shared string/safe-integral ID domain, lossless open fields, notification metadata/subscription IDs, complete deletion and wrong-type vectors, exact runtime compact UTF-8 byte boundaries, and explicit generated/artifact discrepancy assertions for forbidden envelope IDs and metadata constraints.
- `VerifyMcpSseMessage.test.mjs` adds official progress-notification, tool-result-response, and modern-error fixtures; lossless open fields; safe-range IDs and wide integral error codes; ID-less errors; independent-request rejection; required-field and wrong-type vectors; and exclusive result/error classification.
- `VerifyMcpNamedErrors.test.mjs` adds all eight named contracts, every available official fixture, local/generated/upstream agreement, complete required-field deletion, exact-code and nested-data mutations, open-field and open-capability round trips, and centralized MCP-reserved code inventory evidence.
- `VerifyMcpJsonRpcMessage.test.mjs` adds all four official message classes, lossless request round trips, optional object-params coverage, complete request-field deletion, malformed and mixed envelopes, exact class exclusivity, both safe numeric ID limits, and explicit upstream/local evidence for unsafe-ID and mixed-discriminant refinements.
- `VerifyMcpExecutionContextExtension.test.mjs` adds exact identifier/version settings, bilateral capability negotiation, unrelated-field preservation, separate capability/context classification, required context identifiers, absent/incompatible/malformed vectors, exact standard peer errors, and the stable local missing-server-support failure.
- `VerifyMcpPhase1Parity.test.mjs` passes two focused tests over the shared fixture, round-tripping all eight values through current Sury runtime schemas and generated JSON Schemas and proving both string and numeric IDs.
- `mcp_phase1_parity_test.exs` reads that same fixture and validates all eight values through `ProtocolSchema`, exact-compares emitted discover/list/call/cancellation values with `ModelContextProtocol`, and parses discovery/list/call/named-error responses.
- `jq empty libs/frontman-protocol/test/fixtures/mcp-phase1-parity.json`, `yarn changeset status`, the standalone traceability verifier, and `git diff --check` pass. Changesets recognizes major bumps for the two explicitly named packages; dependent workspace patch propagation is computed by Changesets rather than added as an asserted public break.
- Final serial package evidence: `libs/frontman-client` passed `94` tests after a clean compiler-state rebuild, `libs/frontman-core` passed `321`, `libs/client` passed all `319` authored tests, and `apps/frontman_server` passed all `730` tests.
- Repository source-comment verification passed with `30` scanner tests and zero prohibited authored-source comments.
- ReScript formatting passed for `FrontmanProtocol__MCP.res`, `FrontmanProtocol__JsonRpc.res`, and `ExportSchemas.res`; Slice 5 through Part 3I compiled successfully, all `85` generated schemas are current, and no formatter suppressions or source comments were introduced.
- `git diff --check` passed.
- `libs/client`: all `319` authored tests pass after deleting three orphaned generated test modules whose ReScript sources no longer exist.
- `apps/frontman_server`: all `730` tests pass. Tool-result persistence preserves `resultType`, structured content, and open top-level fields while scrubbing result `_meta` before storage.

### Build And Test Harness Findings

- ReScript packages share build artifacts across the workspace. Parallel clean/build operations can delete or invalidate another package's generated modules; package verification must run serially until the build topology is isolated.
- `libs/client` and `libs/frontman-client` clean targets now run `rescript clean`, preventing orphaned generated tests and compiler-state/output mismatches. Clean rebuilds pass both suites.
- A prior attempt to build multiple ReScript packages in parallel reproduced the known inconsistent-interface and missing-artifact failures. Subsequent protocol, frontman-client, and frontman-core acceptance evidence was collected serially.
- Historical note: `libs/frontman-astro` and `libs/frontman-vite` once passed directory arguments rejected by the installed formatter. Their package lint targets now invoke `rescript format --check` without directory arguments and are part of root `make mcp-verify`.

### Phase 1 Acceptance And Later Cleanup

Consumer inventory/cutover, initialization-era MCP schema deletion, focused shared structural fixtures, deterministic differential generation, the recursive `JSONValue` discrepancy decision, final cleanup searches, and the breaking changeset are complete. Phase 1 is accepted. The items below remain assigned to their owning later runtime phases rather than blocking this wire-contract checkpoint.

- Modern named errors are complete in `FrontmanProtocol__MCP.res` and the custom-Phoenix browser dispatcher constructs them. Phase 2 now composes exact active Origin/auth/media/body/parse responses, preflight and HTTP method policy, unsolicited-cursor rejection, discovery/list success responses, and schema-valid responses for `InvalidRequest`, standard/custom `HeaderMismatch`, `UnsupportedProtocolVersion`, malformed metadata, missing required client capabilities, malformed supported-method parameters, unsupported methods, unknown tools, selected-tool input rejection, successful selected execution, returned API/business failures, and thrown execution failures. Raw duplicate custom-header evidence, pre-body request streaming, exact-byte response streaming, transport cancellation ownership, configured Vite/Astro routing, installer-owned body-preserving Next Node routing, cancellation-aware selected-tool context, cooperative owned-process termination, the absolute framework deadline, installed real-process JavaScript framework parity, the separate source-location sibling security boundary, the approved authenticated WordPress synchronous endpoint, and the applicable real WordPress root/scoped plus genuine Playground scoped-runtime matrices are complete. At this checkpoint Relay removal, provider-backed installed application E2E, and official conformance remained later work; Item 24 and the conformance acceptance subsequently close the first and third.
- Use the completed open client/server capability contracts in discovery and per-request metadata assembly while advertising only Frontman's implemented initial feature set.
- Generic JSON-RPC request fidelity and exclusive four-class message recognition are complete in `FrontmanProtocol__JsonRpc.Wire`; custom-Phoenix consumers now use those owners.
- The version `1` execution-context settings, bilateral capability, custom-transport request metadata, and no-fallback error contracts are complete and used by the custom-Phoenix consumers; accepted Phase 6 adds durable claim authority for those explicit identifiers.
- Cancellation-ID validation and the accepted Phase 4 custom-Phoenix runtime are complete: the browser owns bounded active correlation, request AbortSignals, exact cancellation, detach cleanup, duplicate/cross-method collision protection, late-response suppression, and a hard `256` underlying-execution bound that retains cancelled abort-ignoring work until settlement. Accepted Phase 5 moves Phoenix correlation and cancellation to the selected connection owner, adds immutable `600,000 ms` deadlines, and fences terminal IDs process-locally. Accepted Phase 6 owns durable claim generation, cancellation/completion fencing, and replay policy. Accepted and explicitly approved Phase 7 owns durable deadline survival, the single-node recovery architecture, atomic marker lifecycle, and the executed restart and delivery-death vectors.
- The approved Phase 3 browser transport implements SSE framing, LF/CRLF handling, split delimiters, comments, multi-line data, split UTF-8 with final decoder flush, nonawaited reader cancellation, response-byte/depth limits, EOF terminal handling, message classification, ID correlation, exact response-byte boundaries, monotonic idle/absolute deadlines, request-owned Fetch abort, adversarial one-byte chunk handling, and stale connection-generation fencing. All transport-limit and lifecycle vectors pass, and separately owned installed product E2E passes `11/11`.
- The approved Phase 3 remote trust boundary validates default 2020-12 and explicit draft-07 Tool schemas, enforces structural depth/container limits, supplies no network reference loader, and excludes invalid tools individually. The explicitly approved worker slice adds a Blob module bootstrap, ready handshake, bounded startup timeout, typed diagnostics, `100/101 ms` operation limits, cancellation, complete lifecycle cleanup, browser-bundle emission, main-thread responsiveness, exact `1,024/1,025` container proof, and no-send/no-retry proof; accepted Phase 9 independently completes canonical server-side output-schema safety.
- Keep the accepted deterministic differential/property suite and every authoritative-artifact discrepancy test in the pull-request gate; expand generators when later phases add locally accepted domains.
- Keep repository cleanup searches in every later phase. ACP initialization remains intentionally unrelated to removed MCP initialization, and Item 24 has deleted the private Relay fields and runtime.
- Keep the existing major changeset scoped to the two public packages whose contract broke; add no incidental package bumps without a public API break.

## Phase 2: Framework Streamable HTTP Server

### Work

Replace these custom relay endpoints:

```text
GET  /frontman/tools
POST /frontman/tools/call
```

with:

```text
POST /mcp
```

Implement:

- `server/discover`.
- `tools/list`.
- `tools/call`.
- JSON responses for synchronous calls.
- Stream-close cancellation.
- Deterministic tool ordering.
- One complete tools page with no cursor while the Frontman-owned catalog fits the documented limit.
- Required caching metadata.
- Exact method-specific errors.
- `x-mcp-header` tool schema handling.

Do not implement or expose:

- `initialize`.
- `notifications/initialized`.
- GET streams.
- MCP sessions.
- SSE resumability.
- `Last-Event-ID` behavior.
- Standalone server-to-client JSON-RPC requests.
- `subscriptions/listen` until fully implemented and needed.
- Emitted progress notifications or SSE responses until a real Frontman tool produces progress or streamed output.
- Server-side pagination until a real catalog exceeds the documented single-page limit.

Initially advertise:

```json
{
  "tools": {
    "listChanged": false
  }
}
```

Use `ttlMs: 0` initially so clients revalidate when the catalog is next needed. Increase TTL only after tool-catalog stability and invalidation behavior are proven.

Use `cacheScope: "private"` whenever results depend on authorization, user, project, plugin set, or runtime context. Use `public` only when identical results are provably safe to share across authorization contexts.

### Current Phase 2 Implementation Record

The current working-tree implementation contains route-independent Slices 2A-2H and Parts 2I-A through 2K-K, explicitly approved Parts 2K-L through 2K-O covering the active JavaScript endpoint, cancellation/deadline runtime, installed real-process parity, and separate source-location sibling security, plus the explicitly approved WordPress synchronous endpoint slice:

| Slice | Production module | Focused test | Status |
| --- | --- | --- | --- |
| 2A | `libs/frontman-core/src/FrontmanCore__MCP__HeaderValue.res` | `libs/frontman-core/test/FrontmanCore__MCP__HeaderValue.test.res` | Implemented and independently reviewed |
| 2B | `libs/frontman-core/src/FrontmanCore__MCP__RequestHeaders.res` | `libs/frontman-core/test/FrontmanCore__MCP__RequestHeaders.test.res` | Implemented and independently reviewed |
| 2C | `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res` | `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented and independently reviewed |
| 2D | `libs/frontman-core/src/FrontmanCore__MCP__MediaTypes.res` | `libs/frontman-core/test/FrontmanCore__MCP__MediaTypes.test.res` | Implemented and independently reviewed |
| 2E | `libs/frontman-core/src/FrontmanCore__MCP__BodyDecoder.res` | `libs/frontman-core/test/FrontmanCore__MCP__BodyDecoder.test.res` | Implemented and independently reviewed |
| 2F | `libs/frontman-core/src/FrontmanCore__MCP__BodyReader.res`; `libs/bindings/src/WebStreams.res` | `libs/frontman-core/test/FrontmanCore__MCP__BodyReader.test.res` | Implemented and independently reviewed |
| 2G | `libs/frontman-core/src/FrontmanCore__MCP__BodyReader.res` | `libs/frontman-core/test/FrontmanCore__MCP__BodyReader.test.res` | Implemented and independently reviewed |
| 2H | `libs/frontman-core/src/FrontmanCore__MCP__RequestBody.res` | `libs/frontman-core/test/FrontmanCore__MCP__RequestBody.test.res` | Implemented and independently reviewed |
| 2I-A | `libs/frontman-core/src/FrontmanCore__MCP__RequestEnvelope.res` | `libs/frontman-core/test/FrontmanCore__MCP__RequestEnvelope.test.res` | Implemented and independently reviewed |
| 2I-B | `libs/frontman-core/src/FrontmanCore__MCP__RequestEnvelope.res` | `libs/frontman-core/test/FrontmanCore__MCP__RequestEnvelope.test.res` | Implemented and independently reviewed; user continued to 2I-C |
| 2I-C | `libs/frontman-core/src/FrontmanCore__MCP__RequestAuthorities.res`; `libs/frontman-core/src/FrontmanCore__MCP__RequestHeaders.res` | `libs/frontman-core/test/FrontmanCore__MCP__RequestAuthorities.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__RequestHeaders.test.res` | Implemented and independently reviewed; user continued to 2J-A |
| 2J-A | `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res` | `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented and independently reviewed; user continued to 2J-B |
| 2J-B | `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res`; `libs/frontman-core/src/FrontmanCore__MCP__RequestAuthorities.res` | `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented and independently reviewed; user continued to 2J-C |
| 2J-C | `libs/frontman-core/src/FrontmanCore__MCP__MethodRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res` | `libs/frontman-core/test/FrontmanCore__MCP__MethodRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented and independently reviewed; user continued to 2K-A |
| 2K-A | `libs/frontman-core/src/FrontmanCore__MCP__MethodRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res` | `libs/frontman-core/test/FrontmanCore__MCP__MethodRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented and independently reviewed; user continued to 2K-B |
| 2K-B | `libs/frontman-core/src/FrontmanCore__MCP__CustomHeaders.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res` | `libs/frontman-core/test/FrontmanCore__MCP__CustomHeaders.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` | Implemented, independently reviewed, and explicitly approved; user continued to 2K-C |
| 2K-C | `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res` | `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` | Implemented, independently reviewed, and explicitly approved; user continued to 2K-D |
| 2K-D | `libs/frontman-core/src/FrontmanCore__Server.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res` | `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` | Implemented, independently reviewed, and explicitly approved |
| 2K-E | `libs/frontman-core/src/FrontmanCore__ToolRegistry.res`; `libs/frontman-core/src/FrontmanCore__Server.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res` | `libs/frontman-core/test/FrontmanCore__ToolRegistry.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` | Implemented, independently reviewed with PASS, and explicitly approved |
| 2K-F | `libs/frontman-core/src/FrontmanCore__MCP__MethodRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res` | `libs/frontman-core/test/FrontmanCore__MCP__MethodRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__DecodedRequest.test.res` | Implemented, independently reviewed with PASS, and explicitly approved |
| 2K-G | `libs/frontman-core/src/FrontmanCore__MCP__HttpRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__ErrorResponse.res` | `libs/frontman-core/test/FrontmanCore__MCP__HttpRequest.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__ErrorResponse.test.res` | Implemented, independently reviewed with PASS, and explicitly approved |
| 2K-H | `libs/frontman-core/src/FrontmanCore__MCP__RawHeaders.res`; `libs/frontman-core/src/FrontmanCore__MCP__CustomHeaders.res`; `libs/frontman-core/src/FrontmanCore__MCP__DecodedRequest.res`; `libs/frontman-core/src/FrontmanCore__MCP__HttpRequest.res`; Vite/Astro Node adapters | Core custom-header/decoded/HTTP tests; `FrontmanAstro__ViteAdapter.test.res`; `FrontmanVite__Plugin.test.res` | Implemented, independently reviewed with PASS, and explicitly approved after stale-documentation, adapter-ordering, and adapter-proof findings were corrected |
| 2K-I | `libs/frontman-core/src/FrontmanCore__MCP__HttpSecurity.res`; `libs/frontman-core/src/FrontmanCore__MCP__HttpRequest.res` | `libs/frontman-core/test/FrontmanCore__MCP__HttpSecurity.test.res`; `libs/frontman-core/test/FrontmanCore__MCP__HttpRequest.test.res` | Implemented with exact Origin/auth/media/body precedence and focused no-side-effect proof; independently reviewed with PASS and explicitly approved after malformed-URL normalization and callback-isolation findings were corrected |
| 2K-J | `libs/frontman-core/src/FrontmanCore__MCP__AdapterSecurity.res`; Next.js/Vite/Astro configs; `libs/frontman-nextjs/src/FrontmanNextjs__NodeApiAdapter.res`; `libs/bindings/src/NodeHttp.res` | Shared adapter-security test; three package config tests; Next Node adapter and middleware non-registration tests | Implemented, independently reviewed with PASS, and explicitly approved after eager stream construction, hidden Host fallback, premature public export, consumed-body enforcement, and route-proof findings were corrected |
| 2K-K | `libs/frontman-core/src/FrontmanCore__NodeWebChassis.res`; `libs/bindings/src/NodeHttp.res`; Next.js/Vite/Astro Node adapters | Shared chassis lifecycle tests; focused Next, Vite, and Astro adapter tests | Implemented, independently reviewed with PASS, and explicitly approved after partial-response handling, cancellation-race evidence, and test-only helper findings were corrected |
| 2K-L | `libs/frontman-core/src/FrontmanCore__MCP__Endpoint.res`; active Next.js/Vite/Astro route owners; Next installer route and rewrite templates | Shared endpoint tests; focused active adapter and installer tests | Implemented, independently reviewed with final PASS, and explicitly approved after raw-method, preflight-variance, installer-validation, and stale-documentation findings were corrected |
| 2K-M | `libs/frontman-core/src/FrontmanCore__NodeWebChassis.res`; `FrontmanCore__MCP__Endpoint.res`; `FrontmanCore__Server.res`; `FrontmanCore__ChildProcess.res`; shared Tool context; active Next.js/Vite/Astro adapters; cancellable core tools | Shared chassis deadline/cancellation races; endpoint and selected-execution signal identity; child-process termination and side-effect suppression; complete serial package gates | Implemented, independently reviewed with final PASS, and explicitly approved after terminal ordering, response commitment, process-close, max-buffer, process-error, and stale-documentation findings were corrected |
| 2K-N | Next installer server-rewrite owner; `FrontmanNextjs__NodeApiAdapter`; Vite/Astro pre-CORS adapter configuration; `test/e2e/helpers/mcp.ts`; `test/e2e/tests/mcp-blackbox.test.ts`; `test/e2e/vitest.mcp.config.ts`; root Makefile and E2E CI | Shared `12`-test real-process contract against rebuilt installed Next.js, Astro, and Vite artifacts; raw socket disconnect/deadline vectors; focused installer and adapter regressions | Implemented, independently reviewed, and explicitly approved after Next Proxy body consumption, missing Next deadline wiring, framework CORS preemption, weak alias assertions, deadline-preload scope, teardown waiting, stale auto-edit instructions, and stale documentation were corrected |
| 2K-O | `libs/frontman-core/src/FrontmanCore__SourceLocationEndpoint.res`; shared middleware/config and bounded request-body owners; Next.js/Vite/Astro configuration and generated/manual integration surfaces | `FrontmanCore__SourceLocationEndpoint.test.res`; middleware/request-handler tests; three adapter config suites; public TypeScript declaration and installer/template review | Implemented, independently reviewed with final PASS, and explicitly approved after exception disclosure, direct body-limit evidence, public declaration, Next manual setup, and policy inheritance/precedence findings were corrected |
| WordPress MCP | `libs/frontman-wordpress/includes/class-frontman-mcp.php`; router/tools/UI/runtime configuration; `libs/client` endpoint configuration | `McpTest.php`; `RouterTest.php`; complete isolated WordPress suite; real WordPress 7.0.2 subdirectory HTTP discovery; PHP compatibility matrix | Implemented, independently reviewed with final PASS, and explicitly approved after body-ordering, subdirectory ownership, metadata/open-field/MRTR/header/URI validation, runtime-proof, and compatibility findings were corrected |
| Accepted semantic-review remediation evidence | JavaScript `FrontmanCore__MCP__RateLimiter`, `JsonSchema`, `ToolRegistry`, result metadata merge; WordPress `Frontman_MCP_Rate_Limiter`, registry/schema profile, result metadata, stateless dispatcher; browser/Phoenix active result consumers | JavaScript rate/endpoint/schema/registry suites; WordPress `McpTest.php` rate, schema/registry, identity/statelessness/optional-feature vectors; browser and Phoenix remediation suites | Implemented, independently rereviewed with final `PASS`, and explicitly accepted by BlueHotDog as whole Phase 10; credentialed E2E and the aggregate subsequently passed, and whole Phase 2 was explicitly accepted on `2026-08-20` |

Configured Next.js, Vite, and Astro integrations now register `/mcp` through one shared endpoint and Node/Web chassis. The active MCP boundary validates a configured Origin allowlist and invokes one header-only adapter authorization decision before media or body processing, preserves raw physical fields before normalization, streams exact response bytes, owns Node abort/close cancellation, passes one required signal into selected-tool execution, terminates owned child processes cooperatively, and enforces one immutable ten-minute deadline through response commitment. Vite and Astro activate only when explicit `mcp` configuration exists and retain exact case-sensitive route guards; Next exposes public `/mcp` through an installer-owned body-preserving server rewrite to a Node Pages API route with body parsing disabled and environment-backed bearer authentication, with documented case/trailing-slash normalization. Approved Part 2K-N proves all three installed MCP paths over real sockets. Approved Part 2K-O separately protects `/frontman/resolve-source-location` with an explicit Origin-only policy. The approved WordPress slice independently supplies the same initial synchronous methods through a PHP boundary with authoritative `home_url` routing, site-Origin validation, WordPress session/capability/nonce authorization, bounded buffered input, standard serialization, and no private WordPress Relay fallback. The accepted application consumers use modern `/mcp` wire behavior. Item 24 subsequently removed private JavaScript Relay routes and wrappers, temporary Relay names and types, generated artifacts, stale tests, and checked-in fixture dependencies. No temporary parallel Relay reachability remains. Credentialed installed application E2E and the complete root aggregate pass, and whole Phase 2 is explicitly accepted.

Decisions frozen by these slices:

- Header values use the exact case-sensitive sentinel `=?base64?{canonical Base64}?=`. Decode only when both exact markers are present. Safe raw ASCII remains raw even when it resembles the marker with different case or lacks the closing marker.
- Raw values permit visible ASCII plus interior space or horizontal tab, but not non-ASCII, controls, or leading/trailing whitespace. Sentinel payloads must be canonical Base64 and decode to valid UTF-8.
- Required standard-header presence is one validation stage. Do not compare one header while another required header is still absent. Header/body comparison is the next stage, followed by supported-version and capability checks.
- `Mcp-Name` is required from the body method, not from whether a parsed optional name happened to exist. This prevents a nameless `tools/call`, `resources/read`, or `prompts/get` from bypassing required-header validation.
- Named HTTP protocol errors are built from shared JSON-RPC/MCP contracts. Structured error data and tests use Sury; manual `JSON.Encode.object`, `Dict.get`, and `JSON.Decode.*` boundary logic are prohibited.
- Error messages identify only the failed standard header or error category. They do not echo header/body values.
- Frontman initially emits JSON but still requires clients to offer both JSON and SSE as mandated for Streamable HTTP clients. The dual-offer rule is normative; Frontman's request Content-Type, 415, 406, accepted charset, and narrow media-parameter policy are explicit local HTTP policy.
- The route-independent HTTP boundary returns empty 415 and 406 responses before body access, empty 413 for declared or streamed body-size failures, empty 408 for body idle timeout, and HTTP 400 with a fixed ID-less `-32700` ParseError for controlled undecodable-body categories. A consumed body or unexpected stream exception remains a loud server invariant failure.
- Accept parsing must be quote-aware. Delimiters inside quoted parameters cannot create synthetic media ranges, and malformed/unterminated quoted input fails closed.
- Complete raw request bytes are limited to `2,097,152` before UTF-8 or JSON decoding. UTF-8 is validated without replacement decoding, JSON object/array depth is limited to `64`, structural characters inside strings do not affect depth, and the decoded value retains any JSON root type for later envelope validation.
- A syntactically valid `Content-Length` over `2,097,152` is rejected before reader acquisition. Missing or understated values cannot bypass incremental counting. Malformed, signed, fractional, or comma-joined values fail closed under Frontman's HTTP policy. One body may contain at most `4,096` nonterminal chunks, including zero-byte chunks, so stream iteration remains bounded independently of the byte limit.
- Incoming body inactivity uses monotonic time and expires only after `60,000` milliseconds, allowing non-empty bytes or terminal completion exactly at the deadline. Each non-empty chunk resets the deadline; zero-byte chunks do not. Timeout is terminal even when underlying cancellation rejects or never settles, and late bytes cannot replace it.
- Web Request composition checks `bodyUsed` and nullable `body` before reader acquisition, preserves reader and decoder failure categories, and returns the arbitrary-root JSON value without interpreting JSON-RPC fields. `HttpRequest` maps a missing body to fixed ID-less HTTP 400/`-32700`; an already-consumed body remains a loud server invariant failure.
- Coarse request-envelope classification requires exact JSON-RPC `2.0`, a shared safe string/integer ID, and a string method; forbids response discriminants; preserves unknown fields; and retains arbitrary `params` for method validation. Independent recovery retains only a readable shared safe ID from an invalid envelope and does not inspect mirrored metadata/name authorities.
- Raw body-authority extraction preserves protocol version, client capabilities, and method-selected `params.name` or `params.uri` as untyped JSON. A scalar `params` or `_meta` cannot become a valid request, while independently readable authorities survive malformed siblings. Required standard-header presence still precedes comparison; a missing or non-string body mirror becomes `HeaderMismatch`, not premature `InvalidParams` or `UnsupportedProtocolVersion`.
- The decoded-request boundary begins only after `HttpRequest` successfully produces an arbitrary-root JSON value. It returns HTTP 400/`-32600` for an invalid envelope with an exact recovered ID when readable and omitted ID otherwise; accepted envelopes continue through the complete ordered authority, header, version, metadata, capability, method, selection, custom-header, selected-input, and dispatch stages described below.
- Complete request metadata is then parsed through the shared `RequestMeta` Sury schema. Missing required metadata or malformed known metadata returns HTTP 400/`-32602`. An explicitly supplied aggregate client-capability requirement is checked next; absent or incompatible support returns HTTP 400/`-32021` with the exact required capability object, while no requirement preserves core-only behavior.
- The method boundary parses only `server/discover`, `tools/list`, and `tools/call` through complete shared request schemas. Exact selection follows only for typed calls, selected-schema custom headers are discovered and compared, and complete selected-tool arguments are then validated through the selected Sury schema. A separate asynchronous stage executes validated calls and constructs schema-valid discovery/list success responses from the validation-time registry.
- Selected-input schema rejection returns a successful JSON-RPC response with the original readable ID and a complete `CallToolResult` carrying `resultType: "complete"` and `isError: true`. The boundary exposes this as `Completed`, distinct from accepted requests and protocol rejections.
- Omitted arguments are converted to the empty JSON object through Sury before selected-schema validation. Validation catches only typed `S.Exn` failures; all other exceptions escape unchanged.
- The selected request domain makes discovery, listing, and selected calls distinct variants. Only a selected call carries a registry tool module; exact lookup remains case-sensitive and unknown tools remain HTTP 200/`-32602` protocol errors.
- Custom annotations are discovered by recursively inspecting the complete generated JSON Schema tree. Only `properties` edges establish recognized argument paths; annotation names are RFC 9110 tokens and unique case-insensitively; only string, boolean, and integer properties are eligible.
- Custom strings compare after strict sentinel decoding, booleans use lowercase wire spelling, and integers compare through exact integral JSON-number semantics within the inclusive safe range. Missing, null, and unreachable paths require header omission. Unrelated argument constraints are not evaluated.
- A malformed Frontman-owned annotation crashes as a server invariant failure. Unrecognized custom fields are ignored by the endpoint validator. Vite, Astro, and the internal Next.js Pages API adapter use one chassis that captures Node `rawHeaders` before Web `Headers` construction and streams bodies without adapter buffering. Recognized physical names compare case-insensitively, exactly one field supplies its unsplit value, duplicates return HTTP 400/`-32020`, and unavailable raw evidence crashes before annotated validation. Part 2K-L activates the configured routes and generated Next integration, Part 2K-M completes cancellation-aware execution and the absolute framework deadline, and approved Part 2K-N proves installed black-box parity while correcting Next routing ownership.
- Selected calls execute through the same extracted invocation helper used by the existing server executor. Successful and tool-returned error results are preserved; thrown execution failures are converted to a fixed complete error result without exposing exception text. Every outcome is schema-validated and wrapped in an HTTP 200 JSON-RPC success response with the original ID.
- Discovery emits only the supported protocol version and `tools.listChanged: false`; discovery and list results include exact framework identity, `ttlMs: 0`, and private cache scope and validate through their complete shared result schemas before JSON-RPC wrapping.
- Standard tool serialization is distinct from Relay serialization. It filters hidden tools, emits only standard fields and conservative `readOnlyHint` annotations, preserves source descriptions and input/output schemas, and sorts exact names independently of registry insertion order.
- The accepted decoded-request value retains the validation-time registry for list production. Discovery/list dispatch is side-effect free and emits one complete page without `nextCursor`; every supplied cursor, including the empty string, is rejected at method validation with HTTP 200/`-32602`.
- Active framework execution receives the exact chassis signal through the shared server tool context. The signal is checked before invocation and after tool completion; abort-related failures are not converted into ordinary tool execution errors, and filesystem effects already committed before cancellation remain non-transactional.
- The active framework chassis records one monotonic deadline at Node ingress and never resets it. Completion committed exactly at `600,000` milliseconds wins; at `600,001` milliseconds the chassis aborts work and emits one empty HTTP 408. Disconnect instead emits no response. Terminal reason publication precedes controller abort so synchronous abort-aware rejection cannot replace the established outcome.
- A nonempty response commits on its first Node body write, not when a Web Response is created or status/headers are assigned. An empty response commits at normal completion. Until commitment, the absolute timer remains armed and can replace an uncommitted stalled response with the timeout 408.
- Owned child processes receive the same signal. Abort and max-buffer termination send `SIGTERM`, stop accumulating output after termination begins, preserve their exact terminal category across process `error`, and settle only after `close` so reported cancellation means the owned process has stopped.
- Do not implement the body decoder by immediately parsing `DiscoverRequest`, `ListToolsRequest`, or `CallToolRequest`. First preserve enough untyped body authority to validate envelope/direction, required mirrored headers, type-confused mirrors, version, and capabilities in the frozen order; only then parse method parameters.
- WordPress follows the same externally visible security and protocol order with a dedicated PHP owner. Its router passes a lazy bounded body supplier so Origin, application authorization, media, and declared size precede `php://input`; PHP buffering means Node/Web chunk, deadline, and disconnect semantics remain explicitly non-applicable to that adapter.
- WordPress rejects `inputResponses` and `requestState` before selection because it emits no `input_required` and advertises no MRTR support. It preserves unrelated open extension fields rather than closing protocol objects.
- WordPress browser endpoint ownership comes from the explicit `home_url`-derived `mcpBaseUrl`; pathname-based Playground scope discovery remains a fallback, not the authority for ordinary subdirectory installations.

Normative grounding for Parts 2J-B through 2K-N:

- Required request metadata, HTTP 400/`-32602`, and required-client-capability HTTP 400/`-32021`: https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta
- Per-request version and extension negotiation without connection-state fallback: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning
- Unsupported JSON-RPC method behavior using HTTP 404/`-32601`: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#protocol-version-header
- Exact `DiscoverRequest`: https://modelcontextprotocol.io/specification/2026-07-28/schema#discoverrequest
- Exact `ListToolsRequest`: https://modelcontextprotocol.io/specification/2026-07-28/schema#listtoolsrequest
- Exact `CallToolRequest`: https://modelcontextprotocol.io/specification/2026-07-28/schema#calltoolrequest
- Exact `DiscoverResult`: https://modelcontextprotocol.io/specification/2026-07-28/schema#discoverresult
- Exact `ListToolsResult` and standard `Tool`: https://modelcontextprotocol.io/specification/2026-07-28/schema#listtoolsresult
- Discovery identity and capabilities: https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- Tool advertisement, deterministic ordering, and annotations: https://modelcontextprotocol.io/specification/2026-07-28/server/tools
- Complete-result caching metadata: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching
- Malformed call and unknown-tool protocol errors versus selected-tool execution errors: https://modelcontextprotocol.io/specification/2026-07-28/server/tools#error-handling
- Custom parameter schema annotations and primitive constraints: https://modelcontextprotocol.io/specification/2026-07-28/server/tools#x-mcp-header
- Custom-header extraction, encoding, comparison, and error behavior: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#custom-headers-from-tool-parameters
- Streamable HTTP transport cancellation and suppression of later messages: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#cancellation
- General cancellation timing and transport-specific behavior: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation

Following Phase 2 acceptance, retain current code/test references in `docs/mcp/traceability/http-security.md` and preserve the distinction between MCP requirements and Frontman's 415/406/media policy.

### Completed Phase 2 Acceptance

Parts 2K-L through 2K-O and the WordPress synchronous endpoint are implemented, independently reviewed, and explicitly approved. Applicable WordPress and Playground matrices pass. Credentialed installed Next.js, Astro, Vite, and Vue-Vite application E2E passes `11/11`, server precommit passes `828/828`, and one uninterrupted root `make mcp-verify` passes.

BlueHotDog explicitly approved whole Phase 2 on `2026-08-20`. OAuth remains unimplemented and unclaimed. Remaining release and migration documentation, credential rotation, and final security/release, package, version, and publishing checks remain release blockers; they are not Phase 2 blockers. The JavaScript framework black-box gate retains its documented Next rewrite normalization and no-real-MCP-streaming-producer limits.

### Request Validation Order

1. Recognize that the request targets `/mcp` without producing method-specific behavior.
2. Validate Origin before method handling, authentication-sensitive responses, parsing, or execution.
3. Apply authentication and authorization.
4. Validate `Content-Type`.
5. Validate `Accept` negotiation.
6. Enforce body size.
7. Decode one UTF-8 JSON value.
8. Validate JSON-RPC envelope and direction.
9. Validate required standard MCP headers.
10. Compare standard headers with body values.
11. Validate the matching protocol version.
12. Parse complete request metadata.
13. Validate any processing-specific required client capability.
14. Validate method parameters.
15. Select the requested tool.
16. Discover recognized custom headers and exact argument paths from the selected schema.
17. Require singleton raw physical fields for present recognized custom values, then decode and compare them with body values.
18. Validate complete tool arguments through the selected tool's existing Sury schema.
19. Map selected-tool input rejection to a complete `CallToolResult` with `isError: true` without execution.
20. Execute only after all protocol validation succeeds.

Steps 2-20 are regression-tested through the active JavaScript framework endpoint: `HttpSecurity` validates a canonical exact Origin allowlist before invoking one header-only authorization decision, and `HttpRequest` then validates media before body access, applies bounded body reading and exact pre-decode response mapping, preserves arbitrary JSON roots for envelope classification, and hands successful values plus raw physical fields to the complete decoded pipeline. `DecodedRequest` validates standard headers, body authorities, version, metadata, processing-specific capabilities, typed methods, exact selection, selected-schema custom paths, physical singleton multiplicity, and complete selected input before its separate asynchronous stage executes only accepted calls. Vite and Astro capture step 17 evidence before Web `Headers` folding; the generated Next Node route preserves the same evidence and uses environment-backed bearer authentication. Do not collapse these stages into a schema parse whose failure changes the required error precedence.

Tool input-schema failure is a tool execution error under SEP-1302. Return a successful JSON-RPC response containing a complete `CallToolResult` with `isError: true`; do not return JSON-RPC `-32602`. Reserve `-32602` for malformed method parameters and unknown tools.

### Required Headers

Every POST requires:

```text
MCP-Protocol-Version: 2026-07-28
```

Every JSON-RPC request additionally requires `Mcp-Method: <json-rpc-method>`. The 2026 core defines no client-to-server Streamable HTTP notifications, so do not invent notification header requirements.

`tools/call`, `resources/read`, and `prompts/get` require `Mcp-Name`.

Tools using `x-mcp-header` require matching `Mcp-Param-*` headers.

Header names are case-insensitive. Method and name values are case-sensitive. Values that are not safe plain ASCII use the specification's exact Base64 sentinel encoding.

Only the exact lowercase prefix `=?base64?` together with the exact suffix `?=` denotes encoded content. Marker matching is case-sensitive. A safe raw value beginning with `=?BASE64?`, or beginning with lowercase `=?base64?` without the closing suffix, is compared as raw text. A complete exact sentinel with malformed, noncanonical, or non-UTF-8 payload is a header mismatch.

### Initial Media Policy

The Streamable HTTP specification requires clients to list both `application/json` and `text/event-stream` in `Accept`; it does not itself mandate Frontman's request Content-Type or 415/406 behavior. Frontman applies this local policy before reading the body:

- `Content-Type` must be `application/json`, case-insensitively, either bare or with the single parameter `charset=utf-8`.
- `Accept` must contain exact `application/json` and `text/event-stream` media ranges. Wildcards do not satisfy the explicit dual-offer requirement.
- Each required range may be bare or have one syntactically valid positive `q` weight. `q=0`, malformed, over-precision, out-of-range, or duplicate weights do not offer that representation.
- Media parameters such as `profile` constrain a range and therefore do not establish acceptance of Frontman's bare representation.
- Commas inside valid quoted parameters are data, not range delimiters. Unterminated quotes or escapes fail negotiation.
- Route-independent `HttpRequest` composes Origin and authorization before returning exact empty 415 for unsupported request media or exact empty 406 for unacceptable response media before body access. Active adapters must supply the real policy without changing those mappings.

### Response And Status Matrix

| Condition | HTTP status | JSON-RPC behavior |
| --- | ---: | --- |
| Successful request | 200 | Result or method-level error envelope |
| Client-to-server notification | Not initially accepted | The initial server request envelope rejects notifications; no HTTP 202 behavior is claimed until a supported notification exists. |
| Invalid Origin | 403 | Optional ID-less JSON-RPC error |
| Missing authentication | 401 | Optional JSON-RPC error |
| Insufficient authorization | 403 | Optional JSON-RPC error |
| Unsupported media type | 415 | Empty body |
| Unacceptable response media | 406 | Empty body |
| Body idle timeout | 408 | Empty body |
| Body exceeds byte limit | 413 | Empty body |
| Missing, malformed, or otherwise controlled undecodable body | 400 | Fixed ID-less `-32700` |
| Invalid JSON-RPC request | 400 | `-32600` |
| Invalid method params or unknown tool | 200 | `-32602` |
| Selected tool rejects arguments | 200 | Complete result with `isError: true` |
| Unknown method | 404 | `-32601` |
| Header/body mismatch | 400 | `-32020` |
| Missing required client capability | 400 | `-32021` |
| Unsupported protocol version | 400 | `-32022` with supported versions |
| GET or DELETE `/mcp` | 405 | Frontman policy sets `Allow: POST, OPTIONS` |

Verify exact status requirements against the normative Streamable HTTP text during implementation. The traceability matrix wins over this summary if upstream wording differs.

### Deferred Server SSE Requirements

The initial Frontman server emits JSON only. The browser client must still accept standards-compliant SSE from interoperable remote servers. If a later feature introduces a real Frontman progress or streaming producer, implement server SSE in that feature and apply these requirements:

SSE `data:` fields carry complete JSON-RPC notifications and the final JSON-RPC response. Do not send bare result objects or custom `event: result` and `event: error` payloads.

Required behavior:

- Support LF and CRLF framing.
- Ignore SSE comments.
- Handle UTF-8 sequences split across chunks.
- Emit only notifications related to the originating request.
- Never emit independent server requests.
- Follow the specification recommendation to terminate after the final response.
- Apply the Frontman transport policy `X-Accel-Buffering: no`.
- Treat response-stream closure as cancellation.
- Stop cancellable work as soon as practical and emit no later messages after cancellation.

### Proof Gate

- Black-box tests exercise the actual HTTP boundary.
- Every header/status combination has positive and negative coverage.
- Base64 sentinel edge cases pass.
- JSON response mode passes; server SSE tests become applicable only when emitted SSE is implemented.
- Cancellation races pass.
- Invalid requests cause no tool side effect.
- Official Streamable HTTP conformance tests have no accepted failures.

#### Historical Part 2K-N Proof Checkpoint

The paragraph below is frozen checkpoint prose: its word `Current` refers only to the Part 2K-N state on `2026-08-12`, before approved Part 2K-O and the approved Phase 3 core browser-client slice.

Current partial proof covers route-independent foundations through Part 2K-K, the active explicitly approved Part 2K-L JavaScript framework endpoint, the explicitly approved Part 2K-M cancellation/deadline runtime slice, and the explicitly approved Part 2K-N installed real-process framework parity slice: explicit adapter policy construction, shared streaming Node/Web adaptation, transport cancellation ownership, strict canonical Origin allowlisting, exactly one authorization decision, Origin-only preflight, exact raw HTTP method classification, authenticated 405 policy, focused media/body/stream/decode vectors, exact pre-decode response mapping, ordered decoded-request validation, typed methods, unsolicited-list-cursor rejection, exact selection, selected-schema annotation discovery, raw physical singleton enforcement, custom value decoding/comparison, complete selected-input validation, SEP-1302 input-error result mapping, validated selected-call execution, discovery/list success construction, deterministic visible-tool serialization, installer-owned body-preserving Next Node routing with body parsing disabled, environment-backed bearer authentication, strict installer validation, shared named-schema validation, string/numeric ID retention, cancellation-aware tool context, owned-process termination, one immutable ten-minute framework deadline, and real-process routing/security/interoperability/disconnect/deadline proof across rebuilt installed Next.js, Astro, and Vite artifacts. Final evidence is the shared `12`-test black-box matrix, core `37` files/`468` tests, Next.js `12`/`193`, Astro `11`/`65`, Vite `2`/`6`, all `116` protocol verifier tests, all `129` official examples, all `443` traceability requirements, the `30`-test source-comment gate plus repository scan, focused ReScript formatting, `git diff --check`, and independent focused review. This does not satisfy source-location CORS policy, WordPress endpoint, Relay removal, browser-client cutover, or official-conformance gates above.

The preceding proof paragraph is the preserved Part 2K-N checkpoint. Approved Part 2K-O supersedes only its source-location blocker and evidence counts: the separate endpoint now has fail-closed Origin/preflight/media/body policy with no credential permission or exception disclosure, and current serial evidence is core `38` files/`477` tests, Next.js `12`/`194`, Astro `11`/`66`, Vite `2`/`7`, root ReScript formatting, `git diff --check`, and final independent PASS review. The previously recorded `116` protocol verifier tests, `129` official examples, `443` traceability requirements, and `30` source-comment tests remain the latest protocol-wide evidence because Part 2K-O changes no MCP wire contract. The approved Phase 3 core browser client subsequently closes browser wire behavior inside `frontman-client`; the approved WordPress slice closes plugin routing, application authorization, synchronous dispatch, standard serialization, and private WordPress Relay removal; and the accepted source-level application slice closes ACP readiness and browser-local question lifecycle. Installed application E2E remained incomplete; Item 24 and the later conformance acceptance subsequently closed JavaScript Relay artifact removal and the applicable official runner gate.

#### Current Phase 2 Proof Status

The JavaScript framework endpoint, cancellation/deadline runtime, installed real-process matrix, source-location sibling policy, and WordPress synchronous endpoint are explicitly approved slices. Current WordPress evidence is `1,167` core assertions plus real WordPress `7.0.2` runtime and MCP HTTP runtime verification. The focused authenticated `/blog/mcp` discovery, private route/method absence checks, PHP compatibility matrix, source-comment verification, Changesets status, shell syntax, `git diff --check`, and independent PASS review remain valid.

Phase 2 is accepted and explicitly approved. Applicable WordPress and Playground vectors, packed Astro execution, Item 24 cleanup, official conformance, semantic-review remediation, credentialed installed application E2E `11/11`, server precommit `828/828`, and one uninterrupted root `make mcp-verify` pass. WordPress hosting-owned deadlines and lack of PHP-side disconnect cancellation remain documented adapter limits.

## Phase 3: Browser Streamable HTTP Client

Status: accepted and explicitly approved by BlueHotDog on `2026-08-20`. All previously accepted transport and Worker evidence remains valid, and credentialed installed Next.js, Astro, Vite, and Vue-Vite application execution passes `11/11`.

### Work

`FrontmanClient__MCP__Client` owns the standard Streamable HTTP MCP client. Source-level application consumers are cut over, no React consumer receives the transport object, and Item 24 deletes the temporary Relay API name and remaining private Relay protocol artifacts together with the JavaScript server wrappers, generated artifacts, and fixtures.

Responsibilities:

- [x] Target exact `POST /mcp`.
- [x] Send one full JSON-RPC envelope per HTTP request.
- [x] Send required body metadata and mandatory standard/custom HTTP headers without allowing caller overrides.
- [x] Generate unique safe numeric request IDs and correlate responses through the shared exact string/numeric ID domain without narrowing.
- [x] Call `server/discover`, require a complete result and server identity, and verify `2026-07-28` support.
- [x] Fetch all `tools/list` pages until `nextCursor` is absent.
- [x] Treat cursors as opaque values, forward empty and repeated cursors unchanged, enforce page/tool/cursor/definition/catalog limits, and use the page-count bound rather than cursor equality for loop/resource protection.
- [x] Bind the in-memory catalog cache to one immutable client endpoint and copied authorization-header context.
- [x] Calculate discovery and tools-page freshness from each result's receipt, use the earliest expiry across discovery and every accepted page, require consistent list-page `cacheScope`, and never let pagination extend an earlier response's lifetime.
- [x] Revalidate stale data on demand without automatic polling.
- [x] Validate tool definitions under default 2020-12 or explicit draft-07 with bounded strict AJV and no network loader.
- [x] Reject malformed `x-mcp-header` definitions without rejecting valid sibling tools.
- [x] Generate and encode every required mirrored header, including Unicode and literal-sentinel values.
- [x] Accept exact `application/json` and `text/event-stream` response media types with permitted parameters.
- [x] Validate response envelopes and IDs, normalize an absent `resultType` to `complete`, validate core `input_required` and surface it as unsupported without automatic retry, reject unknown result types, validate method-specific results, and require one terminal response.
- [x] Validate call arguments before transmission and validate declared `outputSchema` for both successful and `isError: true` structured results after receipt; invalid or missing structured output fails terminally without repeating execution.
- [x] Combine caller cancellation with the immutable maximum timeout and propagate it through Fetch, stream reading, and local processing.
- [x] Ignore late responses after cancellation and never await untrusted reader cancellation before settling.
- [x] Run remote schema compilation and input/output validation in interruptible module Workers using a Blob module bootstrap, explicit ready handshake, bounded startup timeout, typed diagnostics, exact operation timing, cancellation, cleanup, and browser-bundle proof.
- [x] Add the response-idle timer required for whole-phase acceptance, with monotonic exact-boundary, zero-byte activity, caller-cancellation, nonsettling reader-cancellation, late-result, reader-release, and timer-cleanup proof.
- [x] Own the outgoing absolute deadline with one monotonic deadline, request controller, clearable timer/listener set, exact `600,000/600,001 ms` behavior, and request-owned Fetch abortion after response/parser failures.
- [x] Process adversarial one-byte JSON and SSE chunking without repeated full-payload copying or rescanning.
- [x] Fence stale and concurrent connection attempts with per-client generations so disconnect or a newer attempt cannot be overwritten by older asynchronous completion.

The client must not automatically dereference network `$ref` values. Any future opt-in resolver requires an allowlist, DNS/IP checks, timeouts, byte limits, redirect controls, and SSRF tests.

### Proof Gate

- [x] Tests run against a real in-process HTTP server rather than replacing `fetch`.
- [x] Discovery, multi-page listing with an empty cursor, fresh reconnect cache reuse, required headers, JSON, CRLF SSE, invalid-tool exclusion, output validation, and pre-send input rejection pass.
- [x] A conforming HTTP `400`/`-32020` response triggers relisting and one bounded retry where the specification recommends it.
- [x] JSON/SSE response byte accounting, strict UTF-8 finalization, depth-64 scanning, exact media selection, request/response correlation, and EOF terminal handling are implemented with focused proof.
- [x] One client instance copies its endpoint and authorization headers and owns one nonshared in-memory cache.
- [x] Exact frozen boundaries for response bytes, pages, tools, cursors, definitions, and catalog bytes pass at limit and fail one beyond; schema container count passes at `1,024` and fails at `1,025`.
- [x] Worker-isolated schema compilation and input/output validation finish at `100 ms`, terminate at `101 ms`, cannot block the browser main thread, clean every post-construction terminal path, bundle for browser consumers, prevent input transmission on timeout, and never retry output timeout. The Worker ready handshake and startup timeout also pass, and startup/validation failures retain typed diagnostics.
- [x] Response-idle, absolute-timeout, caller-cancellation, terminal-response, and late-result races pass under controlled time with no leaked reader or timer.
- [x] Distinct authorization contexts prove that no private response or catalog is reused across client instances, and caller-owned header dictionaries are copied before later mutation.
- [x] Credentialed installed browser/application E2E proves framework-unavailable behavior, terminal discovery gating, ACP reconnect initialization replay, consent, deterministic framework WebSocket failure, and a real post-reconnect browser-tool/source operation across Next.js, Astro, Vite, and Vue-Vite; all `11/11` scenarios pass.

Current evidence: `170` `frontman-client` tests and `334` client tests pass with lint/build checks; the no-secrets matrix, WordPress runtime, credentialed installed E2E `11/11`, server precommit `828/828`, generated browser-asset check, and uninterrupted root aggregate pass.

## Phase 4: Browser MCP Server On Custom Phoenix Transport

Status: accepted, including hard execution capacity. The browser dispatcher owns at most `256` underlying durable executions, including cancelled tools that ignore abort until settlement. Structurally identical durable-ID replays join one execution; changed replays fail; completed replay state and durable fingerprints are independently count- and byte-bounded with fail-closed tombstones. Exact request cancellation, duplicate/cross-method ownership, sibling isolation, callback-specific teardown, AbortSignal propagation, and late-response suppression retain their accepted proof. Accepted Phase 5 moved transient Phoenix ownership into `TasksChannel`, and accepted Phase 6 added durable claim authority.

Phase 4 did not originally make ACP connection/request cleanup or durable task cancellation atomic. Accepted Phase 5 closed process-local ownership and teardown gaps; accepted Phase 6 makes claim cancellation/completion and replay policy durable; accepted and explicitly approved Phase 7 implements the restart-recovery architecture and closes the recorded marker and direct restart seams for the supported single-node deployment.

### Work

Keep Phoenix `mcp:message` as a custom MCP transport while replacing legacy semantics.

Documented custom binding:

- [x] Connection establishment.
- [x] Authentication and authorization inheritance.
- [x] One Phoenix payload equals one JSON-RPC message.
- [x] Message encoding.
- [x] Allowed direction of requests, responses, and notifications.
- [x] Ordering and delivery assumptions.
- [x] Individual request cancellation.
- [x] Connection teardown behavior.
- [x] Retry and replay behavior.
- [x] Size, active-concurrency, and accepted 256-new-underlying-executions-per-60-second server-instance rate-limiter policy.

Removed from the browser transport:

- [x] `initialize` handling.
- [x] `notifications/initialized` handling.
- [x] Connection-scoped negotiated state.
- [x] Task identity inferred from the channel topic.
- [x] Required `callId` in `tools/call` params.
- [x] Silent `Suspended` outcomes.

Implemented:

- [x] Mandatory `server/discover`.
- [x] Independent `_meta` validation for every supported request.
- [x] One deterministic `tools/list` page with required caching fields and rejection of every supplied cursor.
- [x] `tools/call` complete results.
- [x] Full implemented error codes and data.
- [x] Exact-ID request cancellation.
- [x] Bounded in-flight request tracking.
- [x] Bounded cancelled-but-unsettled execution tracking for tools that ignore abort by charging work until settlement.
- [x] Late-response suppression after cancellation and detach.
- [x] Duplicate/cross-method response-ownership protection.
- [x] Deterministic visible standard-tool serialization.
- [x] Explicit Frontman execution-context and attachment-resolution metadata.

Recognize and validate core `input_required`, surface it as unsupported, and perform no automatic MRTR retry. Do not advertise the corresponding optional fulfillment capability. Add MRTR only through the separately approved feature described in Phase 8.

Hidden tools are filtered before serialization. Do not expose `visibleToAgent` as a core field.

Map access conservatively to standard annotations:

- Read-only tools may set `readOnlyHint: true`.
- Writing tools set `readOnlyHint: false`.
- Do not infer destructive, idempotent, or open-world hints without tool-specific evidence.

### Proof Gate

- [x] The custom transport contract is documented and tested on both peers.
- [x] Invalid frames never reach tool execution.
- [x] Every supported request validates its own version and capabilities.
- [x] Concurrent sibling requests preserve exact IDs, contexts, cancellation isolation, and terminal ownership.
- [x] Detaching one handler removes only its exact listener reference and aborts/fences its active work.
- [x] Cancelled or detached requests cannot send late success or error responses.
- [x] Duplicate and cross-method active-ID collisions cannot start duplicate work, abort the original, or emit a second terminal response.
- [x] One-page listing rejects empty and nonempty supplied cursors, filters hidden tools, and sorts exact names deterministically.
- [x] Every standard tool result content type passes through the shared contract and canonical persistence paths.
- [x] Documented attachment metadata replaces hidden tool-name dispatch and has browser/core/WordPress proof.
- [x] Focused verification and independent final re-review pass with the explicit Phase 5-7 limits above.
- [x] Re-review hard execution capacity and prove uncooperative cancelled work remains charged until settlement, with fail-closed admission at `256`.

## Phase 5: Existing Phoenix Connection Owner

Status: accepted on `2026-08-13`. `TasksChannel` is the single connection-wide transient MCP owner; task channels are observers. Discovery, bounded catalog/context handling, exact method/result parsing, task-scoped correlation, cancellation, deadlines, terminal-ID fencing, deterministic multi-owner selection/failover, last-owner cleanup, deletion cleanup, and owner-scoped project-context readiness have controlled proof. Accepted Phase 6 subsequently adds durable existing-row claim authority; accepted and explicitly approved Phase 7 subsequently implements and release-hardens durable deadline survival and the single-node restart-recovery architecture.

### Work

Move MCP request ownership out of task-specific `TaskChannel` processes into the existing authenticated connection-wide `FrontmanServerWeb.TasksChannel` process. Do not add a broker GenServer or another Phoenix channel.

```text
TaskChannel observers ----\
ToolExecutor ------------- existing TasksChannel ---- browser MCP server
```

The existing `TasksChannel` owns in the approved implementation slice:

- `server/discover`.
- The current one-page tool catalog and its caching metadata.
- Request ID generation.
- Pending request correlation.
- Request kind and method-specific parsing.
- [x] One immutable ten-minute request timer for each dispatched browser call, including catalog and project-context work, with controlled deadline-race proof.
- Cancellation.
- Minimal bounded tracking needed to reject cancelled, completed, duplicate, or late response IDs.
- Connection teardown.
- Tool-execution ownership references.

The accepted implementation uses `FrontmanServer.MCPConnectionRegistry` plus `FrontmanServer.MCPConnection` as the smallest live-addressing mechanism that lets a `ToolExecutor` address a connection owner. The Registry contains no duplicate pending-request state and is not durable ownership authority. The oldest live connection is selected deterministically; successors monitor it, republish only when selected, re-gate task observers, and redispatch unresolved durable calls without creating a second execution owner.

Task channels are application observers in production. They no longer execute MCP calls merely because they received the same persisted PubSub interaction, accept `mcp:message`, or own browser result persistence. The converted task/connection suites exercise the connection owner directly.

Project-context loading becomes normal application work after tool discovery:

- Check tool presence before calling `load_agent_instructions`.
- Check tool presence before calling `list_tree`.
- Use normal `tools/call` requests with complete per-request metadata.
- Require canonical structured content from project-context tools and delete legacy serialized-text parsing.
- Keep context-loading failures nonfatal where product behavior requires it.
- Deduplicate loading by task and context fingerprint.

Production no longer emits or consumes `mcp_initialization_complete`. The old initializer, its serialized-text parsing, its tests, and the browser no-op notification branch are deleted after project-context responsibilities moved to ordinary connection-owned calls.

### Result Validation

Dispatch by normalized `resultType` before method-specific parsing:

- `complete`, including an absent discriminator normalized to `complete`: validate the exact expected result schema.
- `input_required`: validate the core shape, terminate the request as unsupported, and perform no automatic MRTR retry.
- Unknown value: reject the peer response.

Do not answer malformed responses with a nonstandard `error` notification. Record a local protocol error, terminate the affected request, and apply the configured connection policy.

### Proof Gate

- [x] Task-channel join starts no MCP handshake; connection discovery begins only after browser `mcp:ready` confirms exact-listener attachment.
- [x] Focused discovery/list/call requests contain valid modern `_meta`, and one full agent MCP round trip passes.
- [x] Implemented responses are parsed against catalog or pending call method ownership.
- [x] Randomized completion order preserves one-to-one task-scoped correlation across the complete connection owner, including identical durable call IDs in different tasks.
- [x] Unknown, duplicate, malformed, cancelled, timed-out, and late responses cannot complete another request under controlled races; terminal records pass exact count and age boundaries.
- [x] Graceful and abrupt channel teardown leave no pending entries, timers, browser work, stale catalog, orphaned lifecycle worker, or unresolved executor ownership under controlled proof.
- [x] Current regression evidence is `790` server tests, `151` frontman-client tests, and `116` SwarmAI tests; ReScript builds, Elixir warnings-as-errors compilation, formatting, and strict Credo pass. The dated Phase 5 acceptance delta above preserves its original `772`/`110` checkpoint.
- [x] The converted task channel suite passes at `43` tests across ten explicit seeds, and two independently seeded complete server runs pass without database ownership diagnostics.
- [x] Project-context loading uses ordinary connection-owned calls, exact catalog presence checks, canonical structured content, bounded task/content fingerprints, latest-value prompt selection, and explicit readiness gating before execution.
- [x] Multiple live tabs have deterministic oldest-owner selection, monitored graceful/abrupt failover, owner-scoped readiness invalidation, and no accidental sharing of transient execution authority.
- [x] Final independent re-review reports no remaining Phase 5 behavioral findings; its final quality findings are corrected by deliberate linked-exit handling, configured logging metadata, and stale-plan/documentation cleanup.

## Phase 6: Durable Execution Ownership

Status: accepted by BlueHotDog on `2026-08-14`. The approved no-DDL design stores namespaced owner, generation, lease, dispatch, resolution, cancellation/completion, and replay state in the existing tool-call interaction JSONB row and declares it in the typed embed. Short transactions serialize logical identity through the task row, lock the exact interaction UUID, use database time, and fence owner generations. No claim table, column, index, constraint, or migration was added. Frontman supports one Phoenix node, so distributed and cross-node acceptance are out of scope; accepted Phase 7 subsequently implements the restart-recovery architecture and its approved direct restart proof.

### Problem

Accepted Phase 5 prevents duplicate process-local task-channel execution by selecting one live connection owner. Accepted Phase 6 closes the durable-authority gap with database-backed leases, generation fencing, dispatch ambiguity, and transactional terminal state. Arbitrary non-idempotent side effects still require conservative ambiguity handling when a server process fails after dispatch.

### Work

Atomic execution claims are keyed by the existing tool-call interaction UUID and durable `tool_call_id`. The existing JSONB row holds declared typed state without database DDL or a separate claim table. Task-row locking serializes logical identity, and acquisition fails loudly unless exactly one matching tool-call interaction exists.

Track:

- Tool call ID.
- Task ID.
- Owning MCP connection ID.
- Lease expiration.
- Ownership generation.
- Dispatch state.
- Resolution state.
- Replay policy.

Rules:

1. Claim atomically before sending `tools/call`.
2. Only the owner sends, retries, cancels, or accepts a response.
3. Duplicate channels and tabs observe but do not execute.
4. Claims renew only while the owner remains healthy.
5. Graceful disconnect transactionally cancels owned work; abrupt loss permits safe takeover or terminal ambiguity after bounded expiry.
6. Resolution and claim completion are transactional with the canonical tool result.
7. Browser execution deduplicates the Frontman durable tool-call identifier.
8. Node-local Elixir Registry is not the ownership authority.
9. Undeclared JSONB claim keys are forbidden because the typed polymorphic embed will not round-trip them safely.
10. Claim acquisition fails loudly unless exactly one logical task/turn/tool-call row owns the interaction identity.

Exactly-once external side effects cannot be guaranteed across arbitrary network partitions unless each tool itself supports idempotency. The enforceable target is one active owner plus durable idempotency identifiers and explicit residual-risk handling.

### Proof Gate

- [x] Task channels observe rather than execute, and connection-owned dispatch produces one browser invocation.
- [x] Two tabs select one live owner and database claims remain the execution authority.
- [x] Independent owner identities, processes, PostgreSQL backend connections, and pool connections produce one database claim winner; distributed Phoenix nodes are out of scope.
- [x] Lease takeover is tested.
- [x] Late results from former owners are ignored.
- [x] Durable replay identifiers are preserved and the browser joins exact replays without a second invocation.
- [x] Non-idempotent takeover becomes an explicit terminal ambiguity rather than automatic replay.
- [x] Typed claim state round-trips through repository load, update, dump, and reload without losing tool-call data or leaking claim internals to public JSON.
- [x] Competing logical duplicate creation/acquisition cannot produce two UUID-scoped owners.
- [x] Database-controlled exact lease and renewal boundaries pass without long-running transactions or pinned pooled connections.
- [x] Phase 6 records the durable state required for crash recovery and fences late former-owner results. Accepted Phase 7 proves process-local and channel-owner-loss vectors, and approved release hardening adds fresh-BEAM application startup plus actual supervised state-owner restart.

## Phase 7: Restart-Safe Cancellation And Timeouts

Status: accepted and explicitly approved by BlueHotDog on `2026-08-16`, including release hardening. Durable start/deadline/recovery state lives in the existing tool-call JSONB claim. Count-bounded supervised recovery, task-then-interaction lock ordering, pre-claim cancellation fencing, persisted recovery markers, reconnect resumption, persisted lease-remainder scheduling, atomic cancellation-marker cleanup, supervised-delivery finalization, mixed recovered/unresolved convergence, fresh-BEAM application recovery, exact post-commit/pre-notification death, and actual monitored-state-owner restart pass the implemented single-node gate. Multi-node and cross-node behavior remains out of scope.

### Work

Accepted Phases 2, 4, and 5 provide live cancellation, deadlines, pending ownership, teardown, and late-result behavior. Accepted Phase 6 provides durable claim, generation, cancellation/completion, dispatch, and replay state. Accepted and explicitly approved Phase 7 implements the single-node restart-recovery architecture, proves durable absolute-deadline and database-race behavior, and closes the recorded release-hardening seams with fresh-process application recovery, exact delivery-death injection, actual state-owner restart, atomic cancellation cleanup, supervised marker finalization, and mixed-state reconnect convergence.

Every durable execution record receives:

- A start timestamp.
- One absolute deadline that survives owner-process loss and server restart.
- The durable cancellation state implemented in Phase 6.
- The durable claim owner and generation implemented in Phase 6.

Live custom-Phoenix cancellation continues to use `notifications/cancelled`, driven by the durable terminal decision.

Live Streamable HTTP cancellation continues to close the response stream and abort Fetch.

Durable timeout behavior:

- Timeout atomically selects one durable terminal outcome before cancelling live work.
- ACP task cancellation durably resolves or cancels every claimed MCP request for that task.
- Disconnect preserves enough claim/deadline state for safe takeover rather than blind replay.
- Process-local bounded terminal IDs remain a transport fence; durable claim generation rejects former-owner and post-restart results.
- Late results cannot persist a second terminal outcome or revive cancelled work.

### Proof Gate

- [x] Cancellation before execution prevents side effects.
- [x] Cancellation during execution stops cancellable work.
- [x] Cancellation after completion is harmless.
- [x] Timeout and completion races yield one terminal result.
- [x] Disconnect and reconnect do not leak promises, fetches, readers, timers, or claims.
- [x] Absolute timeout behavior is deterministic under controlled database time and exact boundary classification.
- [x] Simulated loss of process-local state and abrupt selected channel-owner death preserve durable claim authority.
- [x] Start a fresh separate BEAM with the real application and supervised recovery against an overdue committed claim; preserve one durable terminal authority without inherited process-local state.
- [x] Kill the exact terminal owner after commit and before notification; prove one canonical result, retained recovery evidence, no executor delivery, and later exact marker consumption.
- [x] Finalize the exact marker when supervised recovery successfully notifies a live executor; retain `pending_resume` when no executor exists.
- [x] Consume recovered markers after another unresolved call for the same task completes and execution successfully resumes.
- [x] Make task cancellation and cleanup of pre-existing recovered markers one crash-safe durable transaction.
- [x] Kill and supervisor-restart `MCPConnectionState`; prove a different owner PID and live-channel catalog/project-context repopulation without stale-handle or availability faults.
- [x] Recovery never blindly replays an ambiguous non-idempotent dispatch.
- [x] Multi-node and cross-node Phoenix behavior is explicitly out of scope.

## Phase 8: Deferred MRTR And User Interaction Decision

Status: accepted. The initial migration deliberately advertises no MRTR or Elicitation capability and retains the accepted cancellable browser-local question design.

Do not implement an MRTR state machine, request-state storage, or input capability in the initial migration. Initial client capabilities remain minimal. The browser must not request Roots, Sampling, or Elicitation unless Phoenix advertised the corresponding capability on that request.

Roots and Sampling are deprecated in `2026-07-28`; do not add new support.

### Question Tool Decision

The current question tool runs the user interface inside the browser MCP server. A cancellable long-running tool call is therefore protocol-valid and does not automatically require MRTR.

Two valid designs exist:

1. Keep `question` as a browser-local long-running tool with complete cancellation and reconnect behavior.
2. Advertise `elicitation.form`, return `resultType: "input_required"`, route the elicitation through Phoenix and ACP to the UI, then retry with a new request ID and exact `requestState`.

Initial decision: keep `question` as a browser-local long-running tool and make its current promise lifecycle cancellable, reconnect-safe, and unable to overwrite an unresolved resolver. Complete core conformance without MRTR.

Accepted source-level implementation: ACP carries the custom-Phoenix MCP `tools/call`; explicit execution-context metadata supplies `taskId` and durable `toolCallId`; the browser-local tool owns one promise per delivery; task state aggregates waiters only for an identical replay; and one structured answer or terminal reason settles every waiter. User/turn cancellation also invokes ACP `CancelPrompt`. Phase 4 correlates incoming MCP cancellation, aborts matching browser work, and suppresses late responses. Accepted Phase 5 owns that correlation connection-wide, accepted Phase 6 owns durable claim cancellation/completion and replay fencing, and accepted and explicitly approved Phase 7 owns the hardened single-node recovery architecture.

Add Elicitation and MRTR only in a separate change with a concrete product caller, complete capability negotiation, opaque request-state handling, replay and expiry rules, bounded rounds, and its own conformance review.

### Proof Gate

- Undeclared capabilities are never requested.
- No MRTR state, capability, retry, or fallback exists in the initial runtime.
- [x] Source-level question answer, skip, user/turn cancellation, agent error, reconnect redispatch, changed/concurrent request rejection, disconnect, task clear, and task deletion tests settle every waiter without overwriting resolver callbacks.
- [x] Transport-level custom-Phoenix cancellation correlates the request, aborts browser work, suppresses late responses, and releases handler-owned in-flight state.

## Phase 9: Tool Content And Schema Safety

### Current Status

Phase 9 was explicitly approved by BlueHotDog on `2026-08-14`. New writes validate at `Interaction.ToolResult.changeset/2`; valid historical rows migrate once through `20260812000000_canonicalize_tool_results.exs`; canonical storage feeds live executor delivery, historical model reconstruction, ACP live/replay presentation, `get_tool_result`, and TODO recovery. The accepted schema-safety delta adds bounded media and resource handling, durable invocation-time output schemas, isolated server JSON Schema validation, individual malformed-definition exclusion, and payload-safe logging.

Completed in this slice:

- Exact complete-result validation at the persistence boundary.
- Result `_meta` scrubbing and derived persisted error state.
- Preservation of open fields and arbitrary structured content, including explicit null.
- Text, image, audio, resource-link, embedded-text-resource, and embedded-blob-resource handling.
- Valid empty-content delivery and historical reconstruction.
- Deterministic non-dereferencing model projections for unsupported audio/resource media.
- One-time valid-legacy normalization and fail-loud malformed-row handling.
- Focused migration, persistence, ACP replay, model conversion, Base64, URI, and error-state proof.
- Exact content-block, decoded-media, aggregate-media, embedded-text, MIME, and parsed-image-dimension limits.
- Durable invocation-time output-schema snapshots and canonical structured-output validation.
- Bounded isolated JSON Schema 2020-12 compilation and instance validation without an external resolver.
- Unsupported-dialect rejection, local-reference acceptance, external-reference failure, and valid-sibling catalog retention.
- Sensitive argument, decoder, catalog-error, and project-context-error log redaction.

Accepted and explicitly approved evidence: warnings-as-errors compilation, formatting, strict Credo, all `805` server tests, all `116` SwarmAI tests, `116` MCP verifier tests, `129` official examples, `443` traceability requirements, the `30`-test source-comment gate plus repository scan, Changesets status, `git diff --check`, and final independent PASS review.

### Work

Completed: define one canonical validated modern result at the persistence boundary. Preserve `resultType`, `content`, arbitrary `structuredContent`, `isError`, and open protocol fields; scrub result `_meta` because it can contain provider credentials. Use that representation through live executor delivery, historical reconstruction, ACP presentation, and LLM conversion instead of maintaining separate partial converters.

Completed: persisted legacy ToolResults are a concrete compatibility boundary even though the wire protocol is latest-only. The one-time data migration converts valid stored legacy results to the canonical internal shape by adding `resultType: "complete"` and preserving supported content. Deployment fails visibly on malformed stored rows so they are remediated deliberately; no permanent runtime legacy parser or silent fallback was added.

Completed: support all standard content types through that canonical path with the frozen media, resource, content-count, MIME, and dimension limits.

Text:

- Completed: preserve text exactly within documented size limits.

Images:

- Completed: validate canonical Base64.
- Completed: validate MIME type.
- Completed: enforce decoded byte and dimension limits where available.

Audio:

- Completed: preserve protocol content.
- Completed: convert to a clear textual representation for model runtimes without audio tool-result support.

Resource links:

- Completed: preserve name and validated URI.
- Completed: do not dereference automatically.

Embedded resources:

- Completed: preserve validated URI, MIME type, text, or canonical Base64 blob.
- Completed: enforce byte limits.
- Completed: never execute or dereference embedded content during canonicalization or model projection.

Structured content:

- Completed: accept any JSON value.
- Completed: validate against the invocation-time `outputSchema` when provided.
- Completed: preserve the value without object-only narrowing, including explicit null through ACP.

Schema validation:

- Completed: support JSON Schema 2020-12.
- Completed: reject unsupported explicit dialects gracefully.
- Completed: provide no external resolver for network `$ref` values.
- Completed: bound composition depth, container count, and validation time.
- Completed: exclude malformed tool definitions individually rather than poisoning the whole catalog where the specification requires exclusion.
- Completed in accepted Phase 3: use generic JSON Schema validation for untrusted remote catalogs in `frontman-client`.
- Retain existing Sury schemas for Frontman-owned ReScript tool inputs and typed outputs in `frontman-core`; do not add a second general validator there without an untyped producer.

### Proof Gate

- [x] Every official content variant passes the shared contract, canonical persistence, migration, ACP, and deterministic model projection paths.
- [x] Invalid Base64, URI, MIME, schema, oversized content, and excessive dimensions fail before peer-result persistence.
- [x] Object, array, string, number, boolean, and null structured content survive canonical persistence and ACP; explicit null remains distinct from absence.
- [x] The server has no external schema resolver; local references pass and external `$ref` and `$dynamicRef` families fail closed.
- [x] Existing valid persisted results migrate once and replay through the canonical path; malformed migration fixtures fail explicitly.

## Phase 10: Security And Authorization

Status: accepted and explicitly approved by BlueHotDog on `2026-08-17`. The
earlier security-hardening checkpoint retains its recorded scope, and the dated
443-row semantic/threat-model review remains historical evidence of why whole
Phase 10 was rejected at that checkpoint. The resulting runtime and evidence
remediation was implemented, independently rereviewed with final `PASS`, and
explicitly accepted as whole Phase 10. BlueHotDog also explicitly accepts
`BASE-AUTH-001` as a deliberate application-authentication SHOULD deviation.
Frontman does not claim MCP OAuth conformance; OAuth remains a future separate
feature.

### Framework MCP Servers

- [x] Validate `Origin` on every request, including missing/null/malformed/duplicate cases.
- [x] Reject invalid origins with empty `403` before authorization, parsing, or execution.
- [x] Record framework-owned local listener binding as an accepted embedding-host responsibility where the adapter does not control the listener; no false loopback-only claim is made.
- [x] Remove wildcard CORS from `/mcp`, echo only validated origins, and set `Vary: Origin`.
- [x] Separate source-location/UI-route CORS from MCP endpoint policy.
- [x] Rate-limit authenticated POSTs at 256 per 60 seconds per trusted authorization-policy principal, with exact boundary/expiry/isolation/capacity/fail-closed tests and mixed cookie/bearer rotation proof.
- [x] Redact sensitive arguments, metadata values, credentials, schemas, and decoder/exception diagnostics from normal logs.
- [x] Ignore self-reported client/server identity for authorization, rate principal selection, and protocol behavior.

If remote framework MCP access is required, implement the MCP OAuth protected-resource flow as a separate complete feature. Do not invent an MCP-looking bearer-token subset.

`BASE-AUTH-001` is explicitly accepted for the current application-authenticated deployment. Existing JavaScript bearer/cookie policy and WordPress session/capability/nonce policy remain the authorization authority for their local application endpoints. Focused hostile-challenge evidence proves that the browser does not accidentally enter metadata, registration, authorization, or token flows; it proves intentional absence, not OAuth conformance. Any future remote framework MCP requirement must implement the complete protected-resource profile as a separate reviewed feature rather than extending this deviation piecemeal.

### WordPress

Implemented in the approved WordPress slice and retained as ongoing regression requirements:

- Authenticated WordPress session.
- Required capability checks.
- Nonce validation on every MCP POST.
- Exact Origin validation.
- `cacheScope: "private"`.
- Private cache metadata; no server cache exists initially, and any future cache must use authorization-specific keys.
- No filesystem tools unless explicitly and safely designed.
- 256 supported requests per 60 seconds per blog/user principal, with hashed non-autoloaded storage keys and bounded compare-and-swap retries.
- Registration-time JSON Schema profile validation and atomic 256-tool/64-KiB-definition/1-MiB-catalog limits.
- `serverInfo` on discovery, list, successful call, and call-error results.
- No MCP session state, optional capability advertisement, or optional-method side effects.

### Security Tests

- DNS rebinding and hostile Origin.
- Missing and malformed Origin.
- Unauthorized and insufficiently authorized callers.
- Wrong and replayed nonce.
- Header smuggling and CRLF injection.
- Base64 sentinel confusion.
- Host/header/body mismatch.
- Oversized and deeply nested JSON.
- Expensive JSON Schema composition.
- External `$ref` SSRF.
- Cross-user private-cache reuse.
- Tool argument leakage into logs.
- Request-state tampering and replay if MRTR state is generated.

### Proof Gate

- [x] Current applicable HTTP/tool security `MUST` requirements have focused automated evidence linked from the traceability matrices.
- [x] Threat model and refreshed 443-row semantic mapping received independent review on `2026-08-17`; all resulting runtime and evidence remediation was implemented, independently rereviewed with final `PASS`, and explicitly accepted.
- [x] No sensitive argument values or parser/exception diagnostics appear in normal logs.
- [x] Invalid, rate-limited, oversized, schema-invalid, and unsupported requests have no observable tool side effect.
- [x] Focused independent reviewer accepts the `2026-08-17` Phase 2/10 security-hardening checkpoint after remediation; no remaining correctness defect was found in the reviewed authority, adapter, dependency-disposition, or black-box paths.
- [x] Whole Phase 10 was independently rejected at the dated `2026-08-17` review checkpoint; that finding remains historical evidence. The subsequent complete remediation and `BASE-AUTH-001` decision are independently rereviewed and explicitly accepted as whole Phase 10.
- [x] BlueHotDog explicitly accepted the application-authentication SHOULD deviation without converting OAuth absence into an N/A classification or conformance claim; the complete OAuth profile remains a future separate feature.

## Phase 11: Framework Adapter Cutover

Status: accepted and explicitly approved on `2026-08-20`. Shared real-process adapter proof, credentialed installed JavaScript application E2E `11/11`, WordPress runtime, and genuine Playground scoped-runtime evidence pass.

### Next.js

- Route `/mcp` through the installer-owned `next.config` body-preserving server rewrite to the generated Pages API route.
- Update installer templates and automatic edits.
- Exclude `/mcp` from middleware and Proxy matchers because those layers consume the POST body.
- Retain the documented Next rewrite case/trailing-slash normalization limit until a supported exact-routing seam replaces it.
- Propagate request disconnect to cancellation.

### Astro

- Handle `/mcp` before Astro page routing.
- Prevent trailing-slash and UI rewrite logic from changing `/mcp`.
- Use the consolidated Node/Web chassis to propagate stream closure and request abort.

### Vite

- Handle `/mcp` in the early middleware guard.
- Use the same consolidated Node/Web chassis as Astro for request abort/close, raw-byte response writes, reader cancellation, and no-buffer headers.
- Retain the implemented Vite package tests and shared real-process black-box coverage.

### WordPress

- [x] Route exact root and authoritative `home_url`-scoped `/mcp` correctly, including ordinary subdirectory and Playground-style paths.
- [x] Keep UI suffix routing separate and reject case/trailing-slash/private aliases.
- [x] Return JSON for synchronous tools and remove custom bare SSE.
- [x] Keep emitted SSE absent until actual progress or streaming exists.
- [x] Preserve WordPress authentication, capability, nonce, and Origin checks before body access.
- [x] Supply the browser an explicit site-base MCP URL rather than guessing ordinary subdirectory ownership from the UI pathname.
- [x] Run the applicable shared black-box contract across real WordPress root/scoped paths and a genuine WordPress Playground scoped runtime, with explicit buffered-body, hosting-deadline, and disconnect-cancellation divergences.

### Proof Gate

Run one shared black-box contract suite against:

- Next.js.
- Astro.
- Vite.
- WordPress.
- WordPress Playground scoped paths.

Every adapter must produce identical protocol behavior for the same applicable request vector except for documented authentication, tool-catalog, routing, buffering, timeout, and cancellation limits. The proof must assert each documented divergence explicitly rather than silently skipping it.

## Phase 12: Legacy Removal

Status: accepted through explicitly approved Item 24. Repository searches, generated schema and browser-asset regeneration, rebuilt adapter artifacts, route-absence tests, and the root aggregate prove removal.

Remove in the same breaking release:

```text
initialize
notifications/initialized
DRAFT-2025-v3
2025-11-25 runtime support
GET /frontman/tools
POST /frontman/tools/call
Relay protocol 1.0
custom bare SSE result/error events
required tools/call callId
connection-scoped MCP task context
parallel MCP20260728 runtime and generated schema exports
```

WordPress removal of `GET /frontman/tools`, `POST /frontman/tools/call`, Relay `1.0`, and custom bare result SSE is complete in the approved plugin slice. Item 24 completes equivalent JavaScript framework route/wrapper deletion, removes temporary Relay names and types, deletes generated schemas and legacy tests, updates checked-in fixtures, and rebuilds shipped adapter artifacts without the private protocol.

Obsolete schemas, generated files, tests, helpers, documentation, compatibility branches, installer fixtures, and shipped static browser-test bundles are deleted or regenerated. Repository-wide searches cover legacy versions, methods, routes, event names, Relay symbols, and bare SSE event names rather than relying on this filename inventory.

Acceptance searches include at least:

- `DRAFT-2025-v3`, `2025-11-25`, `MCP20260728`, `initialize`, and `notifications/initialized` in MCP contexts.
- `/frontman/tools`, `/frontman/tools/call`, `FrontmanProtocol__Relay`, `FrontmanClient__Relay`, and Relay state variants.
- `event: result`, `event: error`, private SSE helpers, and generated bundles containing those strings.
- Wire-level `callId`, `visibleToAgent`, `executionMode`, and unnamespaced `access` serialization.
- Per-task `mcp:message` ownership and task-channel MCP execution routing. Broad listener removal is already eliminated by accepted Phase 4 exact-reference teardown.
- JSON body parsing outside the shared decoder, raising Base64 result decoding, non-empty-only content matches, and text/image-only converters.
- Wildcard CORS on tool-capable or source-location endpoints.
- Tool argument payload logging in normal and error paths.
- `/frontman`-only route guards, matcher templates, tracing exclusions, fixtures, and CI filters that must also know `/mcp`.

Each search result must be removed, migrated, or recorded as reviewed non-runtime data with a precise reason.

Do not ship a state in which one peer is modern and the other is initialization-era. Intermediate implementations may coexist only on the feature branch behind tests; deployment and package release are atomic.

Use a breaking changeset for every affected published package.

## Test And Verification Program

### Upstream Schema Tests

- Verify vendored checksums.
- Validate official examples.
- Validate every Frontman-produced request, result, error, and notification against its named upstream definition.
- Differentially generate locally accepted values and reject any value the upstream definition rejects.
- Keep these tests offline.

### Negative Protocol Matrix

Cover at minimum:

| Area | Cases |
| --- | --- |
| JSON-RPC | Wrong or missing version, invalid method, null/boolean/fractional/object/array ID, both result and error |
| Direction | Client response sent to server, server request sent to client |
| Metadata | Missing `_meta`, version, capabilities, or wrong metadata types |
| Versioning | Unknown and unsupported versions, exact `-32022` data |
| Headers | Missing, malformed, encoded, and mismatched standard/custom headers |
| Methods | Unknown methods and capability-gated unsupported methods |
| Tools | Missing name, unknown tool, invalid schema, malformed method params, and selected-tool input rejection with its distinct complete error result |
| Results | Missing/unknown `resultType`, malformed content, invalid cache fields |
| Correlation | Unknown ID, duplicate response, cancelled response, stale owner response |
| Extensions | Unknown valid extension, malformed negotiated extension, reserved-prefix misuse |
| Limits | Oversized body, metadata, catalog, content, schema depth, pagination loop |

Every negative case asserts:

- Exact HTTP status where applicable.
- Exact JSON-RPC error code and required data.
- No tool execution.
- No leaked pending request, timer, stream, claim, or promise.

### Property Tests

Use deterministic seeds and persisted replay paths.

Properties:

- Legal IDs produce exactly one response with the identical ID.
- Arbitrary JSON arguments round-trip unchanged.
- Arbitrary legal vendor metadata round-trips unchanged.
- Arbitrary structured JSON round-trips unchanged.
- Removing a required field causes rejection.
- Replacing typed fields with other JSON classes causes rejection unless permitted.
- Valid serialization never creates `undefined`, NaN, infinity, or non-JSON values.
- Arbitrary parsed input never throws outside the handler.
- Tool execution occurs only after full request validation.
- Concurrent request completion is a one-to-one permutation by ID.

Run at least 1,000 deterministic cases in pull requests and 10,000 in scheduled CI.

### Cross-Language Contract Tests

Create semantic fixtures for:

- Discovery.
- Tool listing with the initial single-page result.
- Tool calls with and without arguments.
- Every content block.
- Arbitrary structured content.
- Tool execution errors.
- Protocol errors.
- Unsupported versions.
- String and numeric IDs.
- Cancellation.

ReScript and Elixir independently emit envelopes. Compare parsed JSON structurally and validate both against the upstream schema.

### Concurrency And Fault Tests

- 100 simultaneous calls with randomized completion order.
- Multiple task channels.
- Multiple browser tabs.
- Server-process crash and restart during each durable execution stage.
- Disconnect during every request stage.
- Cancellation before, during, and after execution.
- Completion racing timeout.
- Lease expiry and takeover.
- Duplicate and late terminal responses.
- Repeated pagination cursors.
- Broken SSE at every byte boundary.
- Proxy buffering and delayed chunks.

### End-To-End Tests

Exercise the full path:

```text
LLM tool call
-> existing Phoenix TasksChannel connection owner
-> browser MCP server
-> browser Streamable HTTP client
-> framework MCP server
-> tool execution
-> validated result
-> persistence
-> ACP update
-> agent continuation
```

Cover:

- Browser-local read tool.
- Browser-local write or interaction tool.
- Framework read tool.
- Framework write tool.
- Tool execution error.
- Protocol error.
- Empty, text, image, audio, resource-link, embedded-resource, and structured results.
- Object, array, string, number, boolean, and null structured content through persistence, ACP, history replay, and model conversion.
- Cancellation.
- Reconnect and owned replay.

### Official Conformance Runner

Status: accepted and explicitly approved on `2026-08-16` for the applicable advertised-capability matrix, with the two pinned-runner client fixture corrections disclosed above and in `docs/mcp/conformance.md`.

Pin an exact official conformance-runner version or immutable source commit that supports `2026-07-28`.

Do not fetch or update it during CI.

Do not accept an expected-failure baseline for the final gate.

The final result must contain:

- Zero failures.
- Zero expected failures.
- Zero skipped applicable cases.
- A recorded runner version and checksum.

The accepted gate satisfies these result requirements. Its seven server scenarios are unchanged official runs. Its six client runner scenarios contain no accepted failed check, expected failure, warning, or unexpected skip, but the isolated command harness corrects malformed upstream discovery identity placement and one schema-invalid null argument. Those corrections are evidence limits and are not represented as pristine official client conformance.

The runner is one proof source, not the only source. Schema validation cannot prove timing, cancellation, security, side-effect ownership, or application correctness.

## CI Gates

Add one package-local protocol verification target and one root aggregate target:

```text
make -C libs/frontman-protocol mcp-verify
make -C libs/frontman-protocol mcp-conformance
make mcp-verify
```

The protocol package's public targets own schema, fixture, differential, property, and official conformance checks. Root `make mcp-verify` composes existing package test targets, adapter black-box tests, custom transport tests, Streamable HTTP tests, concurrency tests, the pinned official conformance runner, relevant E2E tests, the tracked-authored-source zero-comment scan, and generated-diff checks. It fails before expensive work when the credentialed E2E environment is absent. Add another public Make target only when it has distinct setup or independent human callers.

Pull-request CI runs:

- Schema checksum and official examples.
- Shared protocol build and generated-schema check.
- ReScript and Elixir contract tests.
- Negative matrix.
- Property tests with fixed seed.
- Browser custom transport tests.
- Streamable HTTP tests.
- Server and client unit tests.
- Adapter contract tests.
- Checksum-pinned official conformance scenarios and isolation probes.
- Relevant end-to-end tests.
- Tracked-authored-source zero-comment verification.
- Formatting, static analysis, and existing precommit suites.

Correct `.github/workflows/e2e.yml` path filters. Remove the nonexistent `adapters/**` assumption and include `libs/frontman-core/**`, `libs/frontman-protocol/**`, `libs/frontman-nextjs/**`, `libs/frontman-astro/**`, `libs/frontman-vite/**`, `libs/frontman-wordpress/**`, checked-in integration fixtures, generated browser-test assets, root MCP Makefile changes, and shared test harness changes.

Scheduled CI runs:

- Larger property-test counts.
- Single-node server-process crash/restart recovery and lease/terminal-state fault injection.
- Soak tests.
- Fault injection.
- Full adapter and compatibility matrices.

## Documentation Deliverables

Create and maintain:

- [x] MCP custom Phoenix transport specification: `docs/mcp/custom-phoenix-transport.md`.
- [x] Frontman MCP extension specification: `docs/mcp/frontman-execution-context-extension.md`.
- [x] Streamable HTTP endpoint and Origin/authentication guide: `docs/mcp/endpoint-auth.md`.
- [x] Capability support/evidence matrix: `docs/mcp/capability-support.md`.
- [x] Implementation limits: `docs/mcp/implementation-limits.md`.
- [x] 443-row normative traceability index/matrices: `docs/mcp/traceability.md`.
- [x] Threat model: `docs/mcp/threat-model.md`.
- [x] Schema/conformance refresh procedure: `docs/mcp/refresh-procedure.md`.
- [x] Private Relay migration guide: `docs/mcp/private-relay-migration.md`.
- [x] Protocol-safe troubleshooting: `docs/mcp/troubleshooting.md`.

Update architecture and marketing documentation so it distinguishes:

- Phoenix custom MCP transport.
- Browser MCP server.
- Browser Streamable HTTP MCP client.
- Framework Streamable HTTP MCP server.
- ACP application/session protocol.

Do not describe a private relay as MCP.

## Review Process

Require separate reviews for:

1. Wire contract and schema fidelity.
2. Streamable HTTP transport and status/header behavior.
3. Custom Phoenix transport and existing `TasksChannel` connection-owner lifecycle.
4. Concurrency, claims, replay, and side effects.
5. Security and authorization.
6. Question cancellation and proof that deferred MRTR is absent from advertised capabilities and runtime state.
7. Cross-language persistence and content conversion.
8. Documentation and normative traceability.

At least one final reviewer should work from the specification and traceability matrix rather than from the implementation design.

## Release Acceptance Criteria

The implementation must not be labeled MCP `2026-07-28` conformant until all criteria are true:

1. Every applicable normative requirement has a code reference and test reference.
2. Every emitted and accepted wire message validates against the pinned official schema.
3. All official examples pass.
4. Every negative test returns the exact required error and causes no side effect.
5. ReScript and Elixir contract fixtures are structurally identical.
6. All advertised capabilities are fully implemented.
7. No unsupported capability is advertised or silently approximated.
8. The custom Phoenix transport is documented and passes its contract tests.
9. Streamable HTTP passes black-box transport tests.
10. The official conformance runner has zero failures, expected failures, warnings, or skipped applicable cases; every upstream fixture correction is isolated and explicitly disclosed rather than counted as pristine unmodified-fixture conformance.
11. Multi-client, multi-tab, reconnect, timeout, cancellation, lease, server-process-crash, and restart races pass; multi-node and cross-node Phoenix acceptance is out of scope.
12. Security tests and independent threat-model review pass.
13. Next.js, Astro, Vite, WordPress, and Playground end-to-end tests pass.
14. Full existing package and server regression suites pass.
15. Generated source and schemas are clean after regeneration.
16. Breaking changesets and migration documentation are complete.
17. Legacy runtime paths and protocol declarations are removed.
18. No parallel MCP contract, broker process, duplicated Node/Web bridge, legacy project-context parser, or compatibility fallback remains.
19. The source-aware zero-comment gate passes on tracked authored source files; only approved platform-required executable directives remain, and generated artifacts and build outputs are outside the gate.

### Current Release Checklist

Prepared evidence includes the explicitly approved `2026-08-17` security-hardening and whole-Phase-10 remediation checkpoints plus the explicitly approved `2026-08-20` installed-E2E, aggregate, and whole-Phase-2/3 acceptance. Release criteria 1-15 and 17-19 have current evidence. Criterion 16, credential rotation, and final release/package/version/publishing review remain open; release is not accepted:

- [x] 443 unique requirement IDs remain structurally present.
- [x] Current transport evidence distinguishes JavaScript HTTP, WordPress HTTP, browser HTTP, browser custom Phoenix, and Phoenix client behavior.
- [x] Implement, independently rereview, and explicitly accept the semantic-review remediation for rate limiting, result recognition, cursor handling, output-schema validation, `serverInfo`, reserved trace metadata, WordPress standard headers, cache behavior, and focused absence evidence; final runtime and evidence rereviews return `PASS`.
- [x] Replace broad conditional-absence aliases with direction-specific source/test evidence and add focused OAuth challenge/metadata-route/zero-discovery-request vectors.
- [x] Private Relay migration, endpoint/auth, capability, refresh, and troubleshooting documents exist.
- [x] Applicable pinned official conformance is recorded with fixture corrections and without claiming pristine client conformance.
- [x] Implement `TD-TOOLS-005` and `TD-TOOLS-014` through browser-host consent with denial/no-side-effect proof; BlueHotDog explicitly chose the policy, and credentialed E2E executes and asserts both consent classes.
- [x] Record BlueHotDog's reviewed acceptance of `CAN-004`/`CAN-TIMEOUT-CONFIG`, `CAN-012`/`CAN-OBSERVABILITY`, `HTTP-006`, and `SBP-011` as SHOULD deviations or residual host responsibilities.
- [x] Independently reviewed all `443` traceability rows and the threat model on `2026-08-17`; whole Phase 2 and whole Phase 10 were rejected at that dated checkpoint, and those findings remain historical evidence for the subsequently accepted remediation.
- [x] Record BlueHotDog's explicit approval of the whole-corpus review, corrected evidence, rejection decisions, verification, and lessons without widening any accepted runtime scope.
- [x] Run provider-backed installed Next.js, Astro, Vite, and Vue-Vite application E2E with valid credentials; `11/11` pass.
- [x] Run the complete root `make mcp-verify`; one uninterrupted invocation passes after server precommit passes `828/828`.
- [x] Repair Astro, Vite, and Next.js package lint targets and include them in aggregate ownership.
- [x] Refresh notifier security-sensitive HTTP/database dependencies and include notifier lint/test in aggregate ownership.
- [x] Make generated schema and browser-asset checks independent of Git staging state.
- [x] Move JavaScript endpoint rate authority from attacker-controlled credential text to trusted authorization-policy principals and prove mixed cookie/bearer rotation reaches request-257 rejection.
- [x] Restore Vite `mcpBrowserToken` forwarding and prove HttpOnly browser credential provisioning against rebuilt Next.js, Astro, and Vite processes.
- [x] Clear all high-severity JavaScript dependency audit findings and rerun marketing production build, black-box, and official conformance after the final lockfile resolution.
- [x] Upgrade Phoenix through patched Decimal 3, replace cross-BEAM fixture-email counters with UUID-backed addresses, run the complete `828`-test precommit gate, and retain the exact no-patch cowlib/Bandit disposition.
- [x] Record BlueHotDog's explicit approval of the `2026-08-17` Phase 2/10 security-hardening checkpoint and its limits.
- [x] BlueHotDog explicitly accepts the focused-tested `BASE-AUTH-001` application-authentication SHOULD deviation. Application authentication and OAuth-absence evidence do not constitute MCP OAuth conformance; a complete OAuth protected-resource flow remains a future separately approved feature.
- [ ] Complete remaining `README.md`, architecture, integration, and marketing-language updates for the latest-only MCP release.
- [ ] Complete breaking migration documentation required by release criterion 16.
- [ ] Rotate every live credential exposed during this session and remove exposed values from local files, shell history, logs, captured output, and CI artifacts.
- [ ] Complete final security/release review and all ordinary package/version/publishing checks.

## Residual Risks To Record

Even after all gates pass, record these residual risks explicitly:

- Official conformance tooling may itself contain defects or incomplete cases.
- JSON Schema cannot validate prose-only timing and lifecycle requirements.
- Network partitions can make exactly-once non-idempotent side effects impossible without tool-level idempotency.
- Browser scheduling, Chromium WebSocket behavior, and proxy behavior can differ from deterministic tests. Recovery evidence therefore uses explicit routed WebSocket closure rather than browser offline mode.
- Cross-language implementations can share the same misunderstanding; independent upstream validation remains mandatory.
- New upstream errata may require a deliberate schema refresh and review.
- Third-party framework and WordPress environments may alter headers, buffering, routing, or connection-close behavior.
- WordPress PHP request buffering and hosting-server timeouts do not provide the shared Node/Web chassis's chunk-count, idle-deadline, absolute-deadline, or disconnect-cancellation guarantees; those differences remain explicit adapter limits.
- Node's portable permission model does not impose a hard total-RSS limit on external buffers or native allocations. The conformance runner has timeout, V8 heap, Worker-count, and output bounds, but hostile-artifact execution requires an outer isolated CI-worker memory limit.
- The accepted client runner evidence contains two exact malformed-upstream-fixture corrections and therefore is not pristine unmodified-fixture client conformance; a future fixed upstream runner should remove both harness corrections and rerun the same gate.
- The newest published cowlib release still contains `CVE-2026-43966` and `CVE-2026-43969`; the findings are explicitly acknowledged because Cowboy is test/optional tooling and Frontman serves with Bandit. Remove the acknowledgement and upgrade promptly when a patched release exists.
- Root transitive dependency resolutions are a temporary supply-chain control. They must remain major-bounded, be reviewed when parents update, and be removed when upstream ranges naturally resolve patched versions.
- Vite, Astro, Next.js, and marketing framework upgrades can change route ordering, bundler externalization, and module-hoisting behavior even when audits are clean; real-process and production-build gates remain mandatory after lockfile changes.
- Parallel worktrees can collide on fixed host port `5173`; credentialed E2E must verify ownership or allocate an isolated port before treating startup or reconnect failures as product evidence.
- Current verification emits non-failing deprecation or bundler diagnostics for ReScript `Js.typeof`, Vitest `poolOptions`, and Next.js dynamic ripgrep resolution. Track and remove them separately; they are not accepted conformance failures and did not invalidate the passing aggregate.
- The accepted `BASE-AUTH-001` deviation deliberately relies on application authentication rather than MCP OAuth for current local framework endpoints. It must not be generalized to remote framework access or represented as OAuth conformance. Any remote-access requirement must trigger a separately designed, implemented, threat-modeled, and accepted complete OAuth protected-resource feature.

## Current Implementation Order

The original recommendation placed canonical persisted-result work and Node/Web bridge consolidation before the framework server. Phase 2 route-independent foundations began first under explicit review gates. The list below records the actual current order rather than pretending the earlier recommendation was followed.

1. Completed: commit and merge the accepted standalone tracked-authored-source zero-comment cleanup before protocol implementation.
2. Completed: freeze decisions and complete the normative traceability matrix.
3. Completed: pin the upstream TypeScript schema, generated JSON Schema, examples, license, and conformance tooling.
4. Completed: replace the existing shared MCP wire contract in place, consolidate common JSON-RPC/content types, and delete the parallel modern contract.
5. Completed and explicitly approved on `2026-08-20`: accept the synchronous framework `/mcp` server as whole Phase 2 after credentialed installed application E2E `11/11`, server precommit `828/828`, and one uninterrupted root aggregate pass.
6. Completed in Part 2K-K: consolidate Vite, Astro, and Next.js onto the shared Node/Web chassis while preserving physical headers, security-before-body ordering, request/response streaming, and transport cancellation ownership.
7. Completed and explicitly approved in Part 2K-M: propagate active framework cancellation into tool execution, stop owned child processes cooperatively, and enforce the frozen absolute request deadline through response commitment.
8. Completed and explicitly approved in Part 2K-N with explicit limits: real-process Next.js, Astro, and Vite parity passes for installed public routing, security, synchronous interoperability, socket disconnect recovery, and absolute deadline wiring. Next server rewrites normalize case/trailing-slash aliases, and response commitment after first-byte streaming remains core chassis evidence until an MCP streaming producer exists.
9. Completed and explicitly approved in Part 2K-O: protect `/frontman/resolve-source-location` with a separate explicit Origin-only policy, narrow preflight/media/method handling, shared bounded decoding, fixed error categories, adapter inheritance/override configuration, and public integration types.
10. Completed: define and test one canonical persisted tool-result representation across live, historical, ACP, and model paths, including one-time legacy migration and fail-loud malformed-row handling.
11. Completed and explicitly approved as a core slice: implement the reusable browser Streamable HTTP client in `frontman-client` with real loopback HTTP coverage, bounded JSON/SSE responses, remote schema and custom-header validation, complete-result/output validation, authorization-bound caching, cancellation, and one bounded relist/retry.
12. Completed and explicitly approved as the Phase 3 worker-isolation slice: move remote schema compilation and input/output validation into one interruptible module Worker per operation with a Blob module bootstrap, explicit ready handshake, bounded startup timeout, typed diagnostics, exact `100/101 ms` operation limits, cancellation, complete lifecycle cleanup, browser-bundle emission, pathological-pattern main-thread responsiveness, exact `1,024/1,025` container proof, and no-send/no-retry timeout evidence.
13. Completed and explicitly approved by BlueHotDog as whole Phase 3 on `2026-08-20`: exact response/page/tool/cursor/definition/catalog boundaries, monotonic idle and absolute deadlines, request-owned Fetch cancellation, controlled terminal/late-result races, nonsettling cancellation cleanup, authorization-isolated caches, adversarial one-byte chunk handling, stale/concurrent connection fencing, and the conformance-discovered same-version retry regression pass. Credentialed installed recovery passes across Next.js, Astro, Vite, and Vue-Vite; real WordPress and genuine Playground applicable vectors pass.
14. Completed and explicitly approved for the plugin slice: wire exact root/site-scoped WordPress `/mcp`, preserve WordPress application authorization, remove private WordPress Relay routes/custom SSE, add explicit browser site-base configuration, prove real authenticated subdirectory discovery, and subsequently pass real root/scoped Apache plus genuine Playground scoped-runtime vectors. Item 24 completes the checked-in application fixture cleanup.
15. Completed and explicitly approved as the application consumer slice: keep ACP transport readiness independent from framework discovery while gating session creation on terminal discovery, replay ACP initialization after reconnect, terminate rejected lifecycle callbacks, expose framework identity instead of transport ownership, make browser-local question waiters exact-replay-safe and terminal across all cleanup paths, enforce consent classification, and prove Astro audit modern schemas/results. Credentialed installed E2E proves terminal framework-discovery gating, consent, and post-reconnect application behavior; Phase 4 closes request-specific custom-Phoenix cancellation.
16. Completed, independently reviewed, and explicitly approved: accept the browser MCP server on the custom Phoenix transport with bounded exact-ID cancellation, callback-owned listener lifecycle, sibling concurrency and collision proof, deterministic one-page listing, documented attachment metadata, reconnect-safe browser late-response behavior, and a hard `256` underlying-execution bound that charges cancelled abort-ignoring work until settlement.
17. Completed and accepted on `2026-08-13`: connection-wide Phoenix MCP ownership lives in the existing `TasksChannel`; task observers no longer own protocol work. Bounded correlation, project-context readiness, deterministic failover, result validation, teardown/deadline races, converted suites, documentation cleanup, and final review pass.
18. Completed, independently reviewed, and accepted by BlueHotDog on `2026-08-14`: the no-DDL durable-claim design uses declared existing-row JSONB state, logical-identity serialization, database-time CAS, generation fencing, dispatch ambiguity, transactional cancellation/completion, and count- and byte-bounded fail-closed browser durable-ID deduplication. Multi-node Phoenix acceptance is out of scope; accepted Phase 7 subsequently implements the single-node recovery architecture and its later approved release hardening closes the recorded seams.
19. Completed and explicitly approved on `2026-08-20`: provider-backed Next.js, Astro, Vite, and Vue-Vite installed recovery passes `11/11`, including deterministic routed WebSocket failure and a real post-reconnect source operation.
20. Completed, independently reviewed, and explicitly approved by BlueHotDog on `2026-08-14`: canonical content handling, exact media/resource/dimension limits, durable output-schema validation, bounded isolated server JSON Schema 2020-12 safety, malformed-definition exclusion, and sensitive logging cleanup pass all owning gates.
21. Completed, independently reviewed, and accepted by BlueHotDog on `2026-08-16`: immutable durable deadlines, count-bounded supervised recovery, task-then-interaction terminal ordering, pre-claim cancellation fencing, persisted recovery markers, reconnect resumption, persisted lease-remainder scheduling, and monitored connection snapshots establish the Phase 7 single-node architecture. The complete server precommit gate passes `819` tests. Final documentation audit records rather than conceals the marker-lifecycle and direct fault-injection work subsequently closed by item 22.
22. Completed, independently reviewed, and explicitly approved by BlueHotDog on `2026-08-16`: supervised delivery finalizes exact markers, mixed-state reconnect consumes prior markers after successful resumption, cancellation and marker cleanup commit atomically, and direct fresh-BEAM startup, post-commit/pre-notification death, and supervised connection-state-owner restart vectors pass. The complete server gate passes `824` tests.
23. Completed and explicitly approved by BlueHotDog on `2026-08-20`: E2E path ownership and serial per-package Astro, Vite, and Astro-browser CI ownership are corrected. Installed and packed Astro tests use standard authenticated `/mcp`; exact request identity survives all three Astro trailing-slash modes without exposing aliases. The root aggregate owns the expanded package/tooling matrix, repaired Astro/Vite/Next lint targets, and staging-independent generated checks. Credentialed application execution passes `11/11`, so Item 23 is complete.
24. Completed, independently reviewed, explicitly approved by BlueHotDog on `2026-08-16`, and documented above: remove every legacy protocol, Relay, generated, fixture, static-asset, test, and active documentation artifact. The modern browser HTTP client is renamed to `FrontmanClient__MCP__Client`; JavaScript private routes, wrappers, custom SSE, protocol types, schemas, and tests are deleted; checked-in Next.js fixtures use the generated API route and installer-owned rewrite; rebuilt adapter bundles contain no removed symbols or routes; and explicit route-absence tests remain as regression evidence.
25. Completed, independently security-reviewed, and explicitly approved by BlueHotDog on `2026-08-16`: execute the unchanged checksum-pinned official `0.2.0-alpha.11` runner against seven applicable server scenarios through the real Vite Node/Web endpoint and six applicable client runner scenarios through the real browser Streamable HTTP client. No expected-failure baseline exists; failures and warnings fail the gate; only exact conditional checks for unadvertised capabilities may skip. The harness validates archive paths/types, grants narrow read and disposable write permissions, has no child-process permission, runs fixed bounded Workers, contains no `PATH` or application secrets, and blocks non-loopback TCP, DNS, UDP, Unix sockets, custom lookup, arbitrary Worker, and subprocess escapes. Its two pinned-runner fixture corrections and lack of a hard total-RSS bound are documented. Ten focused tests, all scenarios, `129` examples, three aggregate contracts, `git diff --check`, and final independent `PASS` review complete the checkpoint.
26. Completed, focused-independently reviewed, and explicitly approved by BlueHotDog on `2026-08-17`: move endpoint rate authority to trusted authorization-policy principals, classify generated Next.js cookie/bearer principals, close the Vite browser-token plumbing gap, clear high-severity JavaScript dependency findings, move Phoenix to patched Decimal 3, explicitly disposition the two no-patch test/optional cowlib findings, and rerun server, package, marketing-build, black-box, conformance, audit, and diff gates. This is a Phase 2/10 security-hardening checkpoint, not whole-phase or release acceptance.
27. Completed, independently rereviewed, and explicitly approved by BlueHotDog on `2026-08-17`: accept the complete semantic-review remediation as whole Phase 10, including browser time-window limiting, result compatibility, opaque pagination and bounded recovery, receipt-based cache expiry, complete call-result identity/schema handling, reserved trace-field rejection, method-based WordPress `Mcp-Name`, and direction-specific absence evidence. Explicitly accept `BASE-AUTH-001` as an application-authentication SHOULD deviation while retaining OAuth as a future separate feature. This does not accept whole Phase 2 or release.
28. Completed and explicitly approved on `2026-08-20`: provider-backed E2E, whole Phases 2 and 3, the completed Item 23 gate, server precommit `828/828`, generated browser-asset verification, and one uninterrupted root acceptance gate.
29. Complete remaining release and migration documentation, rotate exposed credentials, perform independent final release/package/version/publishing review, and then release as an explicitly breaking latest-only migration.

## Definition Of Done

Frontman is done with the migration when a reviewer can start from the official MCP `2026-07-28` specification, follow every applicable normative requirement through the traceability matrix to implementation and tests, run all checks offline, run the pinned official conformance suite with no failure, expected failure, warning, unexpected applicable skip, or undisclosed fixture correction, and observe no legacy MCP, private relay, parallel contract, duplicate transport chassis, unsupported optional runtime machinery, compatibility fallback, or prohibited comment remaining in the repository or shipped system.
