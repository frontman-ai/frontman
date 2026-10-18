# Drip campaign contracts — #515

## Status and evidence limits

**BLOCKED: no owner approval appears in the reviewed evidence.** This record approves no implementation or launch.
Review base: `cf3fc44a48e1e138e0ec82209786cbc12372f081`. Tiqet #515–550 are open specifications, not deployed contracts.
Owners below are required roles, not named assignees or recorded approvals. The manager must identify the accountable people.
No provider account, production system, credentials, or delivery experiment was accessed. Public documentation describes capability, not account behavior.

## Confirmed source facts

Paths in this section are relative to `apps/frontman_server/`.
- `lib/frontman_server/accounts/workos.ex:304–325`: new-account Multi inserts user/identity and welcome/contact/Discord jobs. Existing login/link branches differ.
- `lib/frontman_server/accounts/user.ex:51–73`: OAuth confirmation records verified email, not optional-email consent. No consent or opt-out field exists here.
- `lib/frontman_server/workers/sync_resend_contact.ex:48–64`: contact sync explicitly sends `unsubscribed: false`.
  Its uniqueness/upsert claims are not external-delivery guarantees. #523 removes the explicit subscription write, not proof of preference preservation.
- `lib/frontman_server/accounts/user_notifier.ex:27–61`: Swoosh sends directly and discards provider metadata. No Contacts preference check guards this path.
- `lib/frontman_server/workers/send_welcome_email.ex:14–22`: Oban uniqueness does not settle acceptance after a lost response.
- `config/config.exs:160–185`: local defaults disable welcome/contact workers and prune Oban jobs after seven days. These are not deployed-state evidence.
- `lib/frontman_server/tasks.ex:124–135,475–509,555–579`: prompt acceptance differs from execution. Task deletion and unqueue can delete evidence.
  Retained history cannot prove lifetime inactivity. #518 alone cannot establish complete first-message observation.
- `mix.lock:69` pins Swoosh 1.28.0. Its [Resend adapter][adapter] supports `:idempotency_key` and extracts the provider ID.

## Public documentation evidence

- [Resend idempotency][dedup]: keys last 24 hours. Changed payload returns `409 invalid_idempotent_request`.
  Concurrent requests can return `409 concurrent_idempotent_requests`. Acceptance is not inbox delivery or exactly-once delivery.
- [Contacts preferences][preferences]: global unsubscribe stops Broadcasts/Automations, not ordinary transactional API/SMTP sends.
  Documentation describes a `topic_id` exception. The pinned adapter/selected send path requires separate compatibility evidence before relying on it.
- [Suppressions][suppression]: team-wide bounce/complaint/manual suppression covers transactional and Broadcast sends.
  Not all mailbox providers report complaints. This supports provider-owned deliverability suppression, not permission to send optional mail.
- [Transactional unsubscribe][unsubscribe]: application-managed lists need their own unsubscribe action. POST returns blank 200/202, GET shows a page.
- [Create Contact][contact] documents the optional subscription field, but does not establish duplicate-create omission semantics for this account.

## Recommended minimal contract — NOT approved choices

- Permission: confirmed signup alone is insufficient. Unknown permission or prior preference means no optional send. Authentication mail remains separate.
- Preference: prefer one app-managed monotonic optional-email opt-out for the existing Swoosh path.
  Prior Resend opt-outs need an approved reconciliation/check before eligibility. Local null never means consent. Unknown reconciliation blocks sends.
- Deliverability: prefer Resend-owned suppression without a local mirror. No automatic unsuppression or provider mutation belongs to this campaign.
  A controlled, separately authorized check must establish coverage and response semantics for the actual team/path before launch.
- Identity: one user plus globally versioned fixed step, also encoded in one stable provider key. No replacement key after uncertainty.
- Receipt: recommend `pending`, `attempting`, `accepted`, `skipped`, `unknown`, with constrained transitions and provider ID required for `accepted`.
  `pending` means no external attempt yet, not permission to resend. `accepted` and `skipped` are terminal for automatic sends.
- Claim: one atomic claimant freezes the payload and records first-attempt time before HTTP. No database lock spans HTTP.
  Claim ownership/expiry must prevent duplicate authorization. Lost ownership cannot overwrite a later terminal result.
  A stale claim becomes uncertain, never a fresh unattempted row. Recovery uses the same frozen payload/key and original attempt time.
- Payload: freeze recipient, sender, subject, bodies, headers, unsubscribe token/URL, and all provider options before the first attempt.
  A hash alone cannot reconstruct the request. Retries cannot rerender current templates, mint tokens, or substitute a changed email address.
  Prefer durable payload storage with restricted access. Retention, account deletion, and old-address eligibility need privacy approval before migration.
- Retry: use bounded HTTP timeouts and retry only inside a conservative deadline strictly shorter than documented deduplication coverage.
  The original first-attempt time never resets. Deadline checks must include clock/transport margin, eligibility expiry, and in-flight request bounds.
  Unknown outcomes outside coverage stop for reconciliation. Prefer missed optional mail over duplicate risk. Never automatically reset unknown receipts.
- Final checks: reload activation, permission, preference, enrollment arm, and recipient validity before transport.
  Opt-out/activation can race an in-flight request, which no later database check can recall. Owner acceptance must state this limit.
- Experiment: recommend one immutable version, fixed deterministic 50/50 allocation, signup as origin, and first follow-up at signup+24h.
  Both arms persist regardless of later activation, opt-out, suppression, or send outcome. No historical backfill.
  Recommend seven-day intention-to-treat outcomes: `[origin, origin+7 days)`, mature at `origin+7 days <= as_of`.
  Explicit UTC enrollment start/end, maximum lateness, allocation vectors, and version/copy freeze remain owner decisions.
- Links: purpose-bound non-email capability, monotonic POST only, non-mutating GET, no account disclosure, and no authentication-token reuse.
  Lifetime and key continuity remain undecided. Published links require compatible routes/verification on rollback throughout their approved lifetime.

## Required decisions and contradictions

| Required owner role | Unconfirmed decision / affected tickets |
| --- | --- |
| Product + privacy/legal | Optional-mail permission and evidence, preference authority, historical Resend opt-outs, email-change/recreated-account policy (#524–527, #535). |
| Deliverability operator | Provider-owned suppression approval and authorized account evidence, or explicit local-mirror requirement (#528–531). |
| Backend + privacy | Receipt states/claim recovery, immutable payload, attempt timing, retention and user-FK deletion policy (#521–522, #532–535, #537). |
| Product + experiment owner | Version, allocation, origin, enrollment interval, send lateness, outcome window, copy freeze (#537–542, #549). |
| Security + release operator | Token lifetime/key continuity, outstanding-link support floor, kill-switch/backlog policy and approved rollback version (#525–527, #536, #540, #550). |

#521–522 cannot remain minimal state-only storage while #533/#535 require durable claims, timing, and reproducible payloads.
Recommended splits: approve the model first, then separately counted additive storage/constraints, payload persistence, claim transitions, and send composition.
Each slice needs its own tests and measured additions PLUS deletions <=100, including changesets. Ticket estimates certify no budget.
#535 lists app-preference prerequisites even though #524 is conditional. A provider-preference choice requires an explicit prerequisite rescope.
#528–531 stay unapproved unless the mirror path wins. Provider-owned suppression does not remove preference reconciliation.
#538 and #541 must use the same origin/window. #543–546 require a separate prospective 24h-only versus 24h+72h experiment.
#547–548 remain evidence-gated. #549 needs copy approval and a freeze before enrollment, or deferral until mature outcomes.
#539 calls linked E2E tickets `a35e7043966cce68be100570d6835861` and `aaaab212a860996eecc6b7eda35c1144` open.
Both currently show completed. Status alone supplies no live-run evidence and authorizes no provider access here.

## Deployment and rollback floor

This documentation deploys no behavior. Later migrations precede readers. All prompt writers precede the trustworthy cohort cutoff.
Old-writer rollback invalidates observation coverage. Compatible consumers deploy everywhere before producers enqueue contracts.
Enrollment and execution gates remain default-off. Disabled/expired jobs must not accumulate a surprise backlog on re-enable.
Rollback stops producers and delivery, preserves milestone/preference/enrollment/receipt data, and drains or cancels incompatible jobs.
After link publication, rollback cannot remove unsubscribe support. An approved compatible binary/key floor is still absent.
#550 remains blocked until owners approve these choices and integrated/deployed evidence exists. Launch requires separate authorization.

[adapter]: https://raw.githubusercontent.com/swoosh/swoosh/v1.28.0/lib/swoosh/adapters/resend.ex
[dedup]: https://resend.com/docs/dashboard/emails/idempotency-keys
[preferences]: https://resend.com/docs/dashboard/contacts/managing-unsubscribe-list.md
[suppression]: https://resend.com/docs/dashboard/emails/email-suppressions.md
[unsubscribe]: https://resend.com/docs/dashboard/emails/add-unsubscribe-to-transactional-emails.md
[contact]: https://resend.com/docs/api-reference/contacts/create-contact.md
