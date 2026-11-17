# Agent workflow and WordPress acceptance plans

Prepared on 2026-11-15 against commit `e87074a5`.
These plans cover handoff guidance, per-page indexing, screenshot behavior, attachment recovery, and remaining landing-page acceptance.
They contain no production connection details or customer payloads.

The root `plans/` directory already documents a reducer architecture decision.
This plan set uses `advisor-plans/` to preserve that document.

## Execution order and status

| Plan | Outcome | Priority | Effort | Depends on | Status |
|---|---|---|---|---|---|
| [001](001-clarify-planner-handoff.md) | Explain the existing Planner-to-Executor handoff | P1 | S | None | DONE |
| [002](002-support-per-page-yoast-indexing.md) | Add allowlisted per-page Yoast indexing preferences | P2 | L | None | DONE — final matrix and independent review passed |
| [003](003-characterize-screenshot-disclosure-state.md) | Reproduce screenshot behavior and fix only a proven defect | P2 | S/M | None | DONE — characterization passed, no defect reproduced |
| [004](004-improve-attachment-recovery.md) | Improve image-only recovery and record the PDF decision | P3 | M | None | DONE |
| [005](005-complete-staged-landing-page-qa.md) | Record and perform staged landing-page acceptance | P2/P3 | M | 001, 002, 003 for final acceptance | BLOCKED — runbook complete, operational inputs absent |

Status values: TODO, IN PROGRESS, DONE, BLOCKED, REJECTED.
Add a short reason beside BLOCKED or REJECTED.
Mark a plan DONE only after its checks and review.
The user authorized implementation on 2026-11-15.
The user later authorized the lint cleanup, feature-branch publication, and a combined PR.
That authorization does not include deployment, shared-branch landing, package publication, or external submissions.

## Execution boundaries

- Start with Plan 001. It fixes confirmed guidance friction without changing permissions.
- Plans 002 and 003 can proceed in separate isolated worktrees.
- Plan 003 has a reproduction gate. Passing characterization can end the plan without a capture change.
- Plan 004 does not add native PDF ingestion. Its final step records the separate product decision.
- Plan 005 documentation can start immediately.
- Complete its dependent acceptance checks after the relevant product changes are available.
- Keep real-device and vendor checks distinct from local automated results.
- Obtain explicit authorization before staging writes, publication, or external test leads.
- Use Make targets and real dependencies. Do not add test doubles without explicit permission.
- Keep client builds and WordPress runtime targets sequential within each checkout.
- Include user-facing changesets for implementation changes.
- Do not merge, push, deploy, or publish without explicit authorization.

## Evidence and validation level

The preceding investigation established expected Planner restrictions and successful Executor recovery.
It also established a missing per-page robots field.
The plans use only sanitized conclusions from that investigation.
Task identities, private URLs, account identifiers, and raw diagnostic output do not belong here.

The screenshot report remains unconfirmed.
A planning-time direct SnapDOM probe preserved disclosure state.
That probe did not replace the compiled-tool browser suite.

Commands in the plans were checked against repository Makefiles and CI configuration.
The implementation and acceptance commands were not run while writing these plans.
Earlier diagnostic tests are not acceptance for future implementation.

## Implementation evidence

- Plan 005 documentation passed parent review, relative-link/anchor checks, and whitespace checks.
- Parent reran `make check-source-comments`: all 30 scanner tests and the repository scan passed.
- The [runbook](../docs/wordpress-landing-page-acceptance.md#L1) and [results record](005-acceptance-results.md#L1) are available.
- Operational landing-page, physical-device, and vendor acceptance remain blocked or not run.
- The required fixture, baseline, approved references, candidate artifacts, and separate external authorization are not supplied.
- Plans 001, 003, and 004 passed source review and independent integrated validation in an isolated review worktree.
- Independent gates passed: `make build`, 86 Chromium tests, 532 client tests with two skipped, 115 shared-client tests, and 132 focused server tests.
- Full server precommit passed on retry: 1,195 passed, five skipped, and two excluded.
- Its first run had one 100ms assertion timeout in an unchanged MCP diagnostics test.
- The same-file/same-seed rerun and the full retry passed without timeout changes.
- Client lint initially reported two baseline errors in `libs/client/rescript.json` and `libs/client/test/Client__IntegrationUpdates.test.mjs`.
- The user later authorized those two formatting fixes. Client lint now passes.
- The focused integration-update suite passed all six tests after the lint correction.
- Parent's temporary-index source-policy check included all new browser sources and passed all 30 scanner tests plus the scan.
- The final generic dismiss-label revision separately passed all four attachment browser cases.
- Plan 002 passed all eight existing WordPress/PHP/Yoast runtime matrix rows on the final source.
- Independent review reran the primary WordPress 7.0.2 / PHP 8.4 / Yoast 28.6 command and found no remaining material issue.
- Review found a native nonthrowing SQL-error preflight gap. A real-database regression reproduced it before the correction.
- The correction rejects before authored writes and preserves successful empty-row recovery.
- The final source and regression blobs matched the reviewed versions during reconciliation on 2026-11-17.
- Optional SDK/client runtime branches and the standalone PHP unit suite were not run.
- The [implementation results](implementation-results.md#L1) record the final gates and limits.

## Considered and rejected

- Grant Planner write access: violates the intended agent boundary.
- Switch agents automatically after approval text: unnecessary and ambiguous.
- Add another duplication or page-editing tool: existing tools already provide those operations.
- Treat all missing sector drafts as failure: staged delivery requires feedback before cloning variants.
- Force all FAQs closed during capture: changes intended page state and can conceal the actual defect.
- Add a generic post-meta writer for robots: broader access is unnecessary.
- Treat noindex as access control or a search-engine guarantee: neither claim is valid.
- Add native PDF ingestion without a separate contract: format, budget, security, and provider choices remain undecided.
- Claim PNG upload failure from missing attachments: absence from accepted messages does not establish a transport defect.
- Substitute local form tests for real tracking acceptance: external integration behavior requires authorized vendor evidence.

## Not covered

This plan set is not a repository-wide audit.
It does not assess unrelated SEO providers, full application security, every screenshot renderer, or every third-party form integration.
It does not authorize another production investigation or reuse of diagnostic credentials.
