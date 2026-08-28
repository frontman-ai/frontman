# Project Context Limits

## Objective

Bound MCP project context before persistence to limit database, memory, prompt-token, and query
amplification. Limit violations raise before any write so supervision reports user impact.

## Limits

- Rules: 32 stored per task, enforced by `Tasks`.
- Rule path and content: 65,536 UTF-8 bytes each, enforced by rule changeset.
- Workspaces: 128 per structure response, enforced before formatting.
- Project structure summary: 524,288 UTF-8 bytes, enforced by structure changeset.

## Success Criteria

1. Over-limit payloads raise with actual and allowed values and write nothing.
2. Accepted rule batches are atomic, preserve path deduplication, and emit at most 40 queries.
3. Broadcasts happen only after commit.
4. Focused tests and `mix precommit` pass.

Malformed project-context shapes remain outside this spec and are tracked by issue #1548.

## Verification

From `apps/frontman_server`, run focused tests followed by `mix precommit`.
