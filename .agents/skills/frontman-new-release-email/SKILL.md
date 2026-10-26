---
name: frontman-new-release-email
description: >-
  Prepare a personal Frontman release email from Danni for a published release.
  Use when explicitly asked to prepare a release announcement with meaningful
  user-facing features. Create a Resend draft only when supported and authorized.
  Never send, schedule, publish a release, or change subscription preferences.
disable-model-invocation: true
---

# Prepare a Frontman release email

## Scope

This skill runs manually after publication. Publication never triggers this skill.
The goal is excitement that brings users back to Frontman and encourages feature use.
The audience includes registered users, paying customers, and newsletter subscribers.
Subscription preferences and suppression still apply.

The operator workflow has three steps:

1. Prepare the announcement through the coding agent.
2. Review and edit the draft in Resend.
3. Send manually from Resend.

Creating or editing this skill does not authorize a campaign draft.
An explicit request to prepare a release email authorizes an unsent draft.
A request for a sample or discussion authorizes text in the conversation only.
Never send or schedule an email through this skill.
Never send test emails without a separate request.
Never implement missing tools as part of preparing an announcement.
This skill does not supply a draft helper or Make target.

## Prepare the source material

1. Read the applicable repository instructions.
2. Resolve the requested version against `CHANGELOG.md` and the published release.
   If no version is supplied, ask which release to use.
   If "previous" is ambiguous, state the selected version before proceeding.
3. Use the exact selected release section, not the entire changelog.
   Exclude `[Unreleased]` entries.
4. Read relevant package notes or associated changes to resolve unclear claims.
   Deduplicate changes repeated across packages.
5. Identify meaningful user-facing features and useful supporting fixes.
   If none exist, recommend skipping the announcement.
   Do not create a provider draft without a meaningful announcement.
6. Report evidence of announced feature availability.
   A tag alone does not prove deployment or package availability.
   If availability remains unknown, label the draft as not ready to send.
7. Find relevant existing posts and documentation in `apps/marketing/src/content/`.
   Use `apps/marketing/writing-style.md` for route and publication conventions.
   Distinguish background articles from explanations of this specific release.
8. Check public links before describing them as verified.
   If live access is unavailable, disclose that limitation outside the email.

Useful repository references:

- `CHANGELOG.md`: release content and version boundaries.
- `.github/workflows/release-pr.yml`: release preparation.
- `.github/workflows/release-tag.yml`: tag and release publication.
- `apps/marketing/src/content/blog/`: existing posts.
- `apps/marketing/src/content/docs/`: existing documentation.
- `apps/frontman_server/config/config.exs`: configured contact segment.
- `apps/frontman_server/lib/frontman_server/workers/sync_resend_contact.ex`:
  contact synchronization and its preference limitations.
- `apps/frontman_server/lib/frontman_server/accounts/user_notifier.ex`:
  existing sender identity.

If earlier unannounced releases contain relevant features, propose their inclusion.
Require an explicit release range before expanding the announcement.
Never imply that an older capability first appeared in the selected version.

## Write the announcement

Read [the approved V5.4.0 example](examples/v5.4.0.md).
Use its structure and voice, not its feature claims, for other releases.
Write one recommended email rather than a list of alternatives.

### Fixed editorial rules

- Use the sender name `Danni from Frontman`.
- Resolve the sender address from existing authorized configuration.
- Start the subject with `New in Frontman V{version} - `.
- Add a specific feature headline after that prefix.
- Start the body with `Hey,`, followed by this exact release sentence:

  `We just released a new version of Frontman - V{version} - here are some cool things this version enables.`

- Replace `{version}` with the numeric release version, without a second `V` or `v`.
- Write personally, directly, and enthusiastically.
- Build excitement. Hype is acceptable, but feature claims must remain accurate.
- Explain what users can do, rather than internal implementation details.
- Include a concrete example where useful.
- Do not require a demo or demo assets.
- Exclude pricing, plans, trials, credits, usage allowances, and billing.
- Exclude dependency updates and routine internal maintenance.
- Preserve important permission, compatibility, and recovery limits.
- Use short feature sections and a few supporting improvements.
- Aim for 200–350 body words without padding thin releases.
- Use one primary CTA: `Visit Frontman`, linked to `https://frontman.sh/`.
- Include relevant existing blog and documentation links.
- Include the full release notes link.
- Do not invent links or create companion blog posts.
- End with a reply invitation and `Danni`, followed by `Founder, Frontman`.
- Keep the preference/unsubscribe footer separate from the editorial body.
- Never require artwork to complete the copy.
- Do not generate artwork in this workflow unless separately requested.

### Content handoff

Keep these fields distinct from rendering and provider operations:

| Field | Content |
| --- | --- |
| Release | Exact version or explicitly agreed release range |
| Subject headline | Variable suffix after the fixed subject prefix |
| Preview text | Short inbox summary |
| Feature sections | Headings, benefits, examples, and necessary limits |
| Primary CTA | Fixed label and website URL |
| Resource links | Labels and existing destinations |
| Artwork reference | Optional, independently replaceable |

Use a fixed template for the opening, branding, CTA, sign-off, and footer when available.
Do not invent a new layout for each release.
If no template exists, report that limitation instead of implementing one.
Keep evidence, omissions, and unresolved questions outside the customer-facing copy.

## Prepare the provider draft

1. Discover existing draft tools or repository helpers.
   Use Make targets for repository tasks.
   Do not assume a proposed helper exists.
2. Read the available tool schema before creating or updating a draft.
   If draft-only behavior is unclear, stop before making a write.
3. Resolve the configured Product Updates segment against the provider.
   Do not substitute the WordPress-only segment or all provider contacts.
   If audience coverage is unclear, report the gap.
   Do not import or subscribe contacts to fill that gap.
4. Resolve the Product updates topic and applicable subscription preferences.
   Respect global unsubscribes, topic opt-outs, and suppression.
   Do not infer topic eligibility from a global unsubscribe flag alone.
   Do not assume default opt-in proves individual eligibility.
   If preference enforcement is unavailable, stop before creating a targeted draft.
5. Check the provider draft editor and preview support for the chosen format.
   Use its supported preference/unsubscribe mechanism.
   If the footer mechanism is unknown, stop before creating the provider draft.
6. Find any existing draft for the selected release.
   Prefer a recorded release-to-draft association when available.
   If matching is ambiguous, ask which draft to use.
   Reuse an existing draft rather than creating a duplicate.
   Treat provider edits as authoritative.
   Require explicit permission before replacing existing draft content.
7. Create an unsent, unscheduled draft through the existing supported path.
   Do not use transactional sending as a substitute for a campaign draft.
8. Record the provider draft ID and release association through existing supported storage.
   Report missing durable association support rather than adding infrastructure.
9. Return the provider draft link exactly as supplied.
   If no link is supplied, return its identifier without inventing a URL.

If these operations are unavailable, return the complete email in the conversation.
State which capability blocks provider draft creation.
Never bypass a missing preference control or send the email to work around a limitation.
Never expose contact addresses or credentials in the preparation summary.

## Final review and handoff

Check the version, subject prefix, exact opening, CTA, sign-off, and excluded topics.
Check that every capability has supporting release evidence.
Check that resource descriptions match their destinations.
Check the provider state before claiming that a draft exists.

Return:

- The selected version and editorial angle.
- The draft link, or the complete conversation-only draft.
- A short list of material omissions or unresolved blockers.
- The actual availability and link checks performed.
- An explicit statement that nothing was sent or scheduled.

Leave content review, test sends, and the final audience send to the operator in Resend.
