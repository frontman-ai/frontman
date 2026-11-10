# Implementation plans

This index records plans, not authorization to implement or deploy.

| Plan | Title | Priority | Effort | Depends on | Status |
| --- | --- | --- | --- | --- | --- |
| [001](001-expose-woocommerce-maintenance-actions.md) | Expose WooCommerce maintenance actions individually | P1 | M–L | None | CI VERIFIED — eight compatibility jobs passed at `694860a5`; external OpenAI acceptance remains pending |

## Decisions

- Reuse the existing registry and native WooCommerce REST dispatcher.
- Expose fixed public operations, not a generic model-facing executor.
- Reuse the native extension filter for explicit metadata.
- Replace mock-based tests with equivalent real-runtime coverage.
- Require more deleted code than added code across production, tests, and task runners.
- Keep production and test line totals visible separately.

## Rejected approaches

- A core-only permanent architecture prevents extension coverage.
- An enum or renamed executor retains the flagged model-facing pattern.
- Automatic conservative annotations do not establish truthful effects.
- Another registry or arbitrary schema framework duplicates existing infrastructure.
- Test deletion without equivalent coverage does not satisfy the size constraint.
