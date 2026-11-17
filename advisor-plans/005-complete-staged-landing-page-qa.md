# Plan 005: Define and perform staged landing-page acceptance

> Executor: This is an acceptance plan, not permission to edit a customer site.
> Use synthetic local fixtures by default. Obtain explicit authorization before staging writes or external submissions.
> Update the status in `advisor-plans/README.md` after review.
>
> Drift check: `git diff --stat e87074a5..HEAD -- docs/wordpress-mcp-release-acceptance.md libs/client/test/browser/Client__Tool__FormDiscovery.test.res libs/client/test/browser/Client__Tool__FormFill.test.res libs/client/test/browser/Client__Tool__TakeScreenshot.test.res`

## Status

- Priority: P2 for task completion, P3 for reusable documentation
- Effort: M, plus operator time for real-device and vendor checks
- Risk: LOW locally, MED for explicitly authorized external submissions
- Depends on: Plan 001 for handoff acceptance, Plan 002 for robots acceptance, Plan 003 for screenshot acceptance
- Category: tests
- Planned at: commit `e87074a5`, 2026-11-15

## Why this matters

A saved draft is not proof of visual quality, accessibility, or correct lead tracking.
The acceptance record must distinguish completed checks from unperformed checks.
The workflow must also respect staged delivery: complete one draft before creating sector variants.

This plan closes the remaining QA items without labeling each item as a product defect.
It does not authorize deployment, publication, or test leads on a customer site.

## Current state and existing patterns

[The release acceptance document](../docs/wordpress-mcp-release-acceptance.md#L5-L7) states:

```text
Release acceptance is incomplete. The user reports that staging was tested.
The available record does not identify the tested candidate or the results.
Local checks do not replace evidence for the staging OAuth acceptance.
```

Use that distinction for landing-page acceptance.
Do not add another claim of success without candidate-specific evidence.
The same document requires fresh test database suffixes at lines 47–49.
Its automation commands appear at lines 53–60.
It also requires sequential WordPress targets because they share package output.

The repository already has:

- `libs/client/test/browser/Client__Tool__FormDiscovery.test.res`
- `libs/client/test/browser/Client__Tool__FormFill.test.res`
- `libs/client/test/browser/Client__Tool__TakeScreenshot.test.res`
- The unified real WordPress runtime target in the root Makefile

Read those complete files before extending them.
Prefer observable browser and real-plugin behavior.
Do not substitute a fake HubSpot response for a real vendor acceptance result.

## Scope and conventions

Create or modify only:

- `docs/wordpress-landing-page-acceptance.md` (new runbook)
- `advisor-plans/005-acceptance-results.md` (new sanitized result template)

Implementation defects discovered through this procedure require separate scoped changes.
Existing test files are read-only references under this plan.
Do not modify customer pages, consent text, field requirements, or tracking configuration.
Do not add analytics packages, external accounts, or new testing frameworks.
Keep private URLs, customer content, credentials, account identifiers, and raw sessions out of repository documents.

## Required acceptance inputs

This documentation scope does not include creation of a new landing-page fixture.
The generic form and screenshot regressions are not substitutes for that fixture.
Before Step 2, obtain these inputs from the operator or an existing approved implementation:

1. A disposable local landing-page fixture with the required six-field form and consent area.
2. Its repository path, exact Make startup/stop commands, and Frontman preview procedure.
3. A source baseline captured before implementation, including form markup and relevant behavior.
4. Approved visual-reference images and their intended viewport sizes.
5. The candidate draft and artifact locations for any later authorized staging acceptance.

Record reference filenames and checksums in the private acceptance record.
Keep the actual source export, private URLs, and customer images outside the public repository.
Run the supplied fixture's documented Make startup command before observations.
Do not invent startup commands, visual references, or a source baseline.
If these inputs are absent, mark visual acceptance BLOCKED and request the specific missing input.
Do not create a fixture or edit a site under this documentation-only scope.

Synthetic fixture results establish only synthetic acceptance.
They do not establish visual fidelity or form preservation for an actual customer draft.
Actual-draft acceptance needs its own approved references, baseline, and authorization.

## Commands

Run the commands sequentially.
Use local dependencies and a fresh test database suffix.

| Purpose | Command | Expected result |
|---|---|---|
| Form browser regressions | `make -C libs/client test-browser-forms` | Exit 0 |
| Screenshot browser regressions | `make -C libs/client test-screenshots BROWSER_TEST_FILTER=Client__Tool__TakeScreenshot` | Exit 0 |
| Real WordPress/Yoast acceptance | `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.6` | Exit 0, required dependency cases execute |
| Source policy | `make check-source-comments` | Exit 0 |
| Document hygiene | `git diff --check` | Exit 0 |

These commands do not perform real-device or vendor tracking acceptance.
The result record must state that distinction.
If a dependency is unavailable, record BLOCKED rather than a pass or a silent skip.
An unqualified runtime run does not establish Yoast coverage.

## Steps

### 1. Create the acceptance runbook and result template

Record these fields for every acceptance run:

- Candidate commit and plugin version
- UTC run time
- Environment class: local fixture, authorized staging, or real device
- Synthetic fixture identifier, without a private site URL
- Browser and device versions
- Each check's result: PASS, FAIL, NOT RUN, or BLOCKED
- Sanitized evidence location
- Remaining work and required authorization

Give the runbook separate local, staging, and real-device sections.
Include the required-input gate and supplied fixture startup procedure.
Do not present a plan as a completed acceptance result.

Verify: inspect the template for all fields.
Run `git diff --check`.

### 2. Perform local structural and visual acceptance

First apply the required-input gate.
Use only the supplied disposable fixture and its documented startup procedure.
Record the form's field order, required flags, labels, validation, and consent links before any authorized implementation.
Compare those values after implementation.
Do not submit the form in this step.

At widths 360, 390, and 430 CSS pixels:

- Measure horizontal overflow.
- Inspect input font sizes and touch targets.
- Inspect the hero, trust strip, form, FAQ, and footer.
- Exercise FAQ controls by pointer and keyboard.
- Inspect focus visibility and focus order.
- Inspect sticky-CTA visibility before and after the hero and form.
- Capture the current closed FAQ state and a deliberately expanded state.
- Retain the requested full-page image as an acceptance artifact.

Inspect desktop separately.
Use the real capture path from Plan 003.
Do not claim pixel fidelity from DOM measurements alone.
Perform a visual comparison against synthetic approved references.
Record contrast measurements and the criteria used.

Verify: run form and screenshot browser commands.
Record manual observations separately from automated results.
Those commands cover tool regressions, not the landing page's visual acceptance.
If the fixture or baseline is unavailable, record BLOCKED instead of inferring a pass.

### 3. Perform authorized staging robots acceptance

First obtain explicit permission for the designated staging fixture and permitted writes.
Use only a synthetic page on that environment.
Preserve the draft status during the normal draft workflow.
A draft preview's robots tag does not prove public crawlability.

Use Plan 002 to record stored robots preferences and the effective rendered result.
Use the separate published local fixture for public sitemap behavior.
Do not publish a customer draft to make the test easier.
Distinguish absent sitemap output, sitemap cache state, and confirmed exclusion.

Verify: run the real WordPress runtime command.
Record stored, rendered, and sitemap results independently.
A local runtime pass does not establish an authorized staging result.

### 4. Perform real-device acceptance

Use an operator-approved staging URL.
Inspect iOS Safari and Android Chrome.
Inspect Facebook and Instagram in-app browsers if campaign requirements include them.

Record:

- Input focus and keyboard behavior
- Sticky-CTA visibility while the keyboard is open
- Safe-area spacing
- Scroll behavior and form visibility
- FAQ operation and focus
- Device, OS, browser, and viewport

If a required device is unavailable, record NOT RUN.
Do not substitute desktop emulation for a real-device pass.

Verify: complete the device rows in the result record.
Attach only sanitized evidence through an approved private artifact location.

### 5. Perform tracking and consent acceptance

First inspect the existing page scripts and authorized tag-manager configuration.
Record the existing pixel and form integrations without adding another dataset or event.
Do not infer an absent Lead event solely from missing inline JavaScript.

Before a submission:

1. Obtain explicit authorization for the external test lead.
2. Identify the designated vendor development environment.
3. Agree on synthetic test details and cleanup ownership.
4. Record whether notifications, emails, CRM entries, or conversions can occur.

With that authorization, inspect consent denied and consent granted states.
Submit one agreed synthetic lead.
Inspect the actual successful form event and resulting Lead events.
Record event counts and deduplication evidence.
Do not bypass consent, enter customer data, or infer success from a button click.

If authorization or vendor access is absent, record BLOCKED.
Do not replace the vendor with a stub and report the result as external integration acceptance.

Verify: complete the tracking rows with event evidence or a named blocker.

### 6. Respect the staged review gate

Deliver the first draft's preview, mobile screenshot, and concise result summary.
State every incomplete check.
Wait for explicit layout feedback before cloning sector variants.
Record that missing variants are expected before this review gate.

Verify: the acceptance record links the requested deliverables to the first draft.
Run document hygiene and source-policy commands.

## Done criteria

- [ ] The runbook distinguishes automated, manual, vendor, and real-device evidence.
- [ ] Visual acceptance identifies the supplied fixture, startup procedure, baseline, and approved references.
- [ ] Every required check has a status and evidence or a named blocker.
- [ ] The first draft has a preview and requested screenshot artifact.
- [ ] Form and consent preservation have recorded before/after evidence.
- [ ] Robots storage, rendered tags, and sitemap results remain separate.
- [ ] No unauthorized lead, publication, or customer-site mutation occurred.
- [ ] Sector variants remain behind the agreed review gate.
- [ ] Repository documents contain no private operational or customer data.

## STOP conditions

- A check requires customer-site writes or an external submission without explicit authorization.
- The fixture, documented startup procedure, source baseline, or approved visual references are absent.
- The fixture can send real customer notifications or live conversions unexpectedly.
- The candidate version or test environment cannot be identified.
- Required devices, vendor access, or real dependencies are unavailable.
- A product defect requires source changes outside this documentation scope.

## Git workflow and maintenance

Use a documentation-only branch or an attached isolated Delta worktree.
Do not merge, deploy, publish, or send leads without explicit authorization.
Keep raw evidence private and retain only sanitized summaries in the repository.
Update the runbook when the form integration, screenshot path, or supported SEO provider changes.
