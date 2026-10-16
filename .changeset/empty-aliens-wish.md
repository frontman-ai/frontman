---
"@frontman-ai/client": minor
"@frontman/frontman-server-assets": minor
---

Allow five AI runs before a Frontman trial is required. Users must connect their own AI provider; provider access is validated before a turn is claimed for both subscribers and allowance users. The allowance is shared across projects and does not reset when conversations are deleted. Claimed turns can retry and recover without another charge, even after subscription access ends. Pre-turn failures do not offer turn retry; saving provider credentials resumes queued work. Billing status now exposes `can_start_turn` instead of `access_allowed` to distinguish new-turn eligibility from continuation.
