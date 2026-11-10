# Plan 003: Preserve contact opt-outs with less code

Planned against `f0193998` plus the MCP fix on 2026-11-10.
Status: implemented and reviewed.

## Behavior

Contact writes start with PATCH without subscription fields.
Only a definite 404 permits creation.
Existing signup contacts receive a separate segment-membership POST.
Retries start with reconciliation after an uncertain create result.
The implementation never reads subscription preferences to write them back.

The existing projection, eligibility rechecks, advisory lock, and failure reporting remain intact.
An independent external creator can still race between the 404 and creation.
This implementation does not provide a provider-level atomic create-only guarantee.
The maintainer accepts the existing email-change limitation.

## Code budget

- Production code: 20 lines added, 24 deleted.
- Source and tests: 49 lines added, 51 deleted.
- Counts compare this fix with its task-start contents, excluding the earlier MCP change and plan documents.
- Repeated assertions and contact-write paths were consolidated without removing required coverage.

## Verification

- The maintainer explicitly approved reuse of the existing `Req.Test` doubles.
- No new doubles or dependencies were added.
- Focused worker tests: 17 passed.
- Strict compilation, lint, and full precommit passed.
- Full suite: 1,167 passed, four skipped, two excluded.
- The real replacement provider sequence preserved global and topic opt-outs twice.
- Evidence and the single deployment procedure are recorded in plan 002.
