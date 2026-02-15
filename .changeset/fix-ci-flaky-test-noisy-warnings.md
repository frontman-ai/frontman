---
---

Fix CI flaky test and reduce noisy warnings in frontman_server: add sync barriers to eliminate TaskChannelTest race condition, handle empty project rules without spurious decode warnings, convert usage tracking to atomic upsert to prevent ConstraintError crashes, and suppress expected tool call warnings in tests.
