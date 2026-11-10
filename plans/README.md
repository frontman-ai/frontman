# First-use campaign plans

Planned against `f0193998` on 2026-11-10.

| Plan | Purpose | Depends on | Status |
| --- | --- | --- | --- |
| [001](001-mcp-activation.md) | Count successful MCP tool use as activation | None | DONE — implemented and reviewed |
| [002](002-first-use-campaign-rollout.md) | Start the campaign in one deploy, including 001 and 003 | 001, 003 | APPROVED — configuration verified; land and deploy together |
| [003](003-preserve-contact-optouts.md) | Preserve opt-outs with a net-negative code change | None | DONE — implemented, reviewed, and provider sequence verified |

## Verification

- Strict compilation and lint passed.
- The full server precommit gate passed with 1,167 tests passed, four skipped, and two excluded.
- The real WordPress SDK cases passed before and after WooCommerce activation.
- SDK coverage includes MCP-then-chat, chat-then-MCP, repeat calls, tool errors, and discovery exclusions.
- The broader WordPress browser gate remains blocked because Playwright Chromium is absent.
- The authorized isolated Resend check failed twice: duplicate creation reset `unsubscribed` from `true` to `false`.
- Product updates topic preferences remained `opt_out` after both duplicate requests.
- The provider request log confirms the duplicate payload omitted `unsubscribed` and `topics`, matching the server.
- The isolated test contact was restored to global and topic opt-outs.
- The replacement PATCH and separate segment-membership sequence preserved both opt-outs after two repeats.
- Empty signup properties also preserved the existing activation property and global unsubscribe.
- The contact fix passed 17 focused worker tests and the full precommit gate.
- The contact fix added 20 production lines and deleted 24. Source and tests added 49 lines and deleted 51.
- The production enrollment configuration uses the fixed cutoff `2026-11-10 15:00:00 UTC`, a 3,600-second lag, and enabled contact sync.
- Full configuration evaluation passed for prod, dev, e2e, and test without starting the application.
- The enrollment change added six production lines and deleted eight. No test source changed.
- The combined release passed strict compilation, lint, and full precommit again.
- No activation events, campaign sends, live production configuration changes, or deployment occurred.

## Decisions

- Email changes can leave the original contact in the campaign. The maintainer accepts this limitation for now.
- A successful WordPress MCP tool call counts as first use.
- Discovery, `list_sites`, rejected calls, and tool error results do not count.
- The existing `first_message_at` column remains the activation milestone. No schema migration is necessary.
- The MCP fix and production enrollment configuration ship in one deploy.
- Enrollment stays disabled until the pre-deploy checks pass and the deploy is approved.
- Uncertain entry jobs remain one-shot. Do not replay them.
- On 2026-11-10, the maintainer authorized landing and deployment, including cutoff adjustment if the rollout window changes.

## Execution order

Plans 001 and 003 are implemented but not deployed.
Enrollment configuration is implemented with the fixed cutoff `2026-11-10 15:00:00 UTC`.
If all instances cannot update before the cutoff, choose a later fixed cutoff before landing.
Keep both fixes and enrollment configuration in one combined deploy under plan 002.
Monitoring follows that deploy without another enablement stage.
Deployment and production enrollment are authorized for this combined release.
Additional test sends or unrelated provider writes still need explicit operator approval.
