# Plan 001: Count successful MCP tool use as activation

Planned against `f0193998` on 2026-11-10.
Status: implemented and reviewed.

## Behavior

Chat prompts and successful WordPress MCP tool calls use one atomic account operation.
The operation records first product use and queues the Resend activation exit together.
The existing `first_message_at` column remains the milestone.
Repeated calls preserve the first timestamp and do not queue another exit.

Discovery, `list_sites`, authentication failures, rejected calls, and tool errors do not activate accounts.
Network calls stay outside the activation transaction.
Rejected chat messages roll back the milestone and exit job.

## Verification

- Strict compilation, lint, and full server precommit passed.
- Full server suite: 1,167 passed, four skipped, two excluded.
- Real WordPress SDK cases passed before and after WooCommerce activation.
- SDK cases cover MCP-then-chat, chat-then-MCP, repeated calls, and tool errors.
- Database cases cover repeat activation and transaction rollback.
- The broader browser gate remains blocked because Playwright Chromium is absent.

The maintainer accepts the existing email-change limitation.
Future first-use entry points must use the same atomic operation.
Deployment is part of the single release in plan 002.
