# WordPress landing-page acceptance

## Scope and status

Use this runbook to assess a WordPress landing-page candidate against supplied baselines and approved references.
It does not authorize site changes, publication, deployment, or external submissions.
Record each run's evidence privately, with sanitized summaries for any shared records.

| Status | Meaning |
|---|---|
| PASS | Candidate-specific evidence meets the stated criterion |
| FAIL | An observation contradicts the stated criterion |
| NOT RUN | No observation occurred. State the reason and remaining work |
| BLOCKED | A required input, dependency, access, or authorization is absent. Name it |

Each result needs a scope, method, criterion, UTC time, and evidence reference or blocker.
Synthetic results apply only to the synthetic fixture.
Actual-draft results need separate authorization, before-state evidence, and approved references.
Automated regressions do not establish manual visual, real-device, customer-draft, or vendor acceptance.

## Evidence and safety rules

1. Use an existing disposable local fixture by default.
2. Keep raw evidence in the approved private evidence store.
3. Use synthetic identifiers and sanitized summaries in repository records.
4. Keep raw task IDs, customer text, accounts, private URLs, credentials, and connection details out of the repository.
5. Use relative source links in repository records.
6. Record reference filenames and SHA-256 checksums privately.
7. Use a sanitized artifact alias in the repository.
8. Obtain separate permission before any form submission, including a synthetic local submission.
9. Do not create an application fixture or change source files under this runbook.
10. Stop before unexpected notifications, emails, CRM entries, or conversions.

Obtain separate authorization for staging, device access, and vendor operations.
Noindex is neither access control nor a guarantee about search-engine indexing.

## Required-input gate

Before observations, record these required inputs as the run header in the private evidence store.

| Required input | Required provenance |
|---|---|
| Candidate | Exact commit, working-tree changes, plugin version, and package checksum |
| Run | Operator role, UTC start/end, environment class, and synthetic fixture identifier |
| Runtime | Actual WordPress, PHP, Yoast, browser, OS, and device versions |
| Existing local landing-page fixture | Repository path and owner-supplied usage documentation |
| Fixture lifecycle | Exact supplied Make startup/stop commands and working directories |
| Frontman preview | Supplied procedure, target identity, and environment isolation |
| Source before-state | Capture time, version, form markup, behavior, and consent baseline |
| Approved visual references | Approval, filenames, checksums, widths, heights, DPR, and FAQ states |
| Candidate draft | Version and private preview/artifact locations for later authorized observations |
| Authorization | Permitted environment, actions, submissions, evidence capture, and cleanup owner |

The fixture must contain the required six-field form and consent area.
It must not unexpectedly send external traffic or live conversions.
The source before-state must predate implementation.
A current screenshot is not a substitute for an approved reference.

1. Obtain every required fixture input from the operator or the existing approved implementation.
2. Record missing fixture, startup/stop procedure, source before-state, or approved references as BLOCKED.
3. Request each missing input by name.
4. Stop the affected acceptance work until those inputs exist.

Do not invent a baseline, reference image, startup command, or stop command.
Do not automatically create a fixture.
A synthetic fixture cannot prove preservation of an actual draft's form or layout.

## Local execution

### Fixture lifecycle

1. Record the supplied fixture path and exact Make commands privately.
2. Record the procedure's availability and a sanitized alias in the run evidence.
3. Check that the commands target only the disposable local environment.
4. Run the supplied Make startup command from its documented directory.
5. Open Frontman through the supplied preview procedure.
6. Check the preview target and candidate version before observations.
7. After observations, run the supplied Make stop command from its documented directory.
8. Record startup and stop outcomes independently.

There is no known landing-page startup command in this runbook.
An absent supplied procedure is BLOCKED, not permission to guess a target.

### Automated regression commands

Run these exact commands from the repository root, sequentially:

```sh
make -C libs/client test-browser-forms
make -C libs/client test-screenshots BROWSER_TEST_FILTER=Client__Tool__TakeScreenshot
make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.6
make check-source-comments
git diff --check
```

The [browser targets](../libs/client/Makefile#L35-L40) build shared client output.
The [WordPress runtime target](../Makefile#L693-L694) uses the existing real runtime runner.
Do not run overlapping builds or WordPress targets in the same checkout.
Use local dependencies and a fresh `MIX_TEST_DB_SUFFIX` for each independent database run.
Do not reset an existing developer database.
The [release runbook](wordpress-mcp-release-acceptance.md#L45-L66) explains the database and sequencing constraints.

The expected command result is exit 0.
Also record executed cases, skips, exclusions, and actual dependency versions.
Missing required dependency cases mean BLOCKED coverage, even with exit 0.
The explicit `YOAST_VERSION=28.6` pin is required for this SEO gate.
The default no-Yoast run is not SEO coverage.

Form regressions cover discovery and fill tools.
Screenshot regressions cover the capture tool.
Neither command establishes landing-page visual acceptance.
A runtime pass does not establish staging, vendor, or real-device acceptance.

### Form and consent preservation

1. Obtain the six-field source before-state captured before implementation.
2. Record each field's order, label, name, type, required flag, default, and validation behavior.
3. Record consent text, links, required state, defaults, and error behavior.
4. Record the form destination and existing integrations privately.
5. Compare each value with the candidate after-state.
6. Record differences and their authorization.
7. Inspect validation without a submission only where that action has no external side effect.
8. Leave submission-dependent validation NOT RUN until separate submission permission exists.

Acceptance requires unchanged six-field order, required flags, validation, labels, and consent behavior unless a separate change has explicit approval.
An absent before-state means BLOCKED preservation, not an inferred match.

### Manual visual and accessibility observations

Use widths 360, 390, and 430 CSS pixels, plus a separately recorded desktop viewport.
Record viewport height, DPR, zoom, browser version, and loaded fonts for each observation.
Use the approved reference for that same viewport and FAQ state.

| Area | Required observation and criterion |
|---|---|
| Overflow | Compare document scroll width with viewport width. No unintended horizontal overflow |
| Fonts | Record computed input sizes and loaded fonts. No clipped text or inaccessible zoom behavior |
| Touch targets | Measure target dimensions and spacing against the agreed accessibility criterion |
| Sections | Inspect hero, trust strip, form, FAQ, and footer against approved references |
| Focus | Inspect visible focus, logical order, labels, errors, and no keyboard trap |
| Contrast | Record sampled colors, ratios, and criteria. Use WCAG 2.2 AA unless requirements are stricter |
| FAQ | Exercise pointer and keyboard controls. Inspect accessible names and expanded state |
| Sticky CTA | Inspect before hero, after hero, before form, at form, and after form |
| CTA obstruction | No hidden fields, FAQ controls, footer content, or focus targets |
| Capture | Compare actual image pixels and geometry with references, not DOM measurements alone |

For WCAG 2.2 AA, record text contrast against 4.5:1, or 3:1 for qualifying large text.
Record applicable non-text contrast against 3:1.
Record target-size coverage against the 24-by-24 CSS-pixel minimum and applicable exceptions.
Do not label a complete accessibility audit from these limited observations.

1. Capture the current closed FAQ state without forcing unrelated disclosures closed.
2. Capture a deliberately expanded FAQ state.
3. Use Frontman's registered [screenshot tool](../libs/client/src/tools/Client__Tool__TakeScreenshot.res#L49-L88) with `fullPage: true`.
4. Retain the complete image result, including the requested 390px full-page image.
5. Record image dimensions, scale, checksum, viewport, and candidate privately.
6. Compare visible answers and downstream geometry with the live state.
7. Inspect disclosure state, focus, input values, and scroll position before and after capture.
8. Record manual observations separately from automated regression results.

The [real capture path](../libs/client/src/tools/Client__Tool__TakeScreenshot.res#L100-L115) uses SnapDOM and image scaling.
A direct library probe or native browser screenshot does not replace this path.
Originally open disclosures must remain open.
An image difference does not by itself prove a live-state mutation.

## Authorized staging and SEO observations

No staging actions are authorized by this document.
Obtain explicit permission for the designated synthetic staging page and each permitted write.
Keep the normal candidate workflow in draft status.
Do not publish a customer draft to inspect public output.

Use the existing [`wp_read_seo` and `wp_update_seo` tools](../libs/frontman-wordpress/tools/class-tool-seo.php#L32-L61).
For supported Yoast objects, `wp_update_seo` accepts optional `indexing`: `default`, `noindex`, or `index`.
Omission preserves the stored preference.
`default` clears the object override and inherits the provider policy.
`index` is a stored preference, not an indexing guarantee.
Obtain approval before writes.
After a failed write, reread with `wp_read_seo` before any retry.

Record each layer independently:

| Layer | Required evidence |
|---|---|
| Stored preference | Native readback and normalized `default`, `noindex`, or `index` value |
| Derived indexable | Persisted identity, noindex state, and refresh result, including disabled or failed persistence |
| Rendered HTML | Fresh anonymous response, all global and bot-specific robots directives |
| HTTP headers | All relevant `X-Robots-Tag` directives, including bot-specific directives |
| Public sitemap | Actual response from the relevant native sitemap and observed page inclusion/exclusion |
| Draft privacy | Draft status and anonymous non-disclosure, separate from public indexing evidence |

An explicit `index` preference cannot override every broader noindex directive.
Stored preferences and successful indexable refresh do not prove rendered output or sitemap behavior.
A draft preview is not evidence of public indexing.

1. Use the real local published synthetic fixture from the existing runtime for public sitemap observations.
2. Record its candidate, provider version, anonymous response, and observation time.
3. Distinguish absent sitemap output, stale cache output, observed inclusion, and observed exclusion.
4. Report stale native output separately.
5. Do not add a sitemap writer or purge global caches.
6. If the required runtime fixture is unavailable, record public sitemap acceptance as BLOCKED.

A local runtime result applies only to that local fixture.
Authorized staging needs its own candidate-specific observations.

## Real-device observations

Use an operator-approved staging preview and separate device authorization.
Record actual-draft and synthetic-fixture observations separately.
Inspect iOS Safari and Android Chrome on physical devices.
When campaign requirements include them, inspect Facebook and Instagram in-app browsers.
If campaign requirements are unknown, record that input as BLOCKED.

1. Record the device, OS, browser/app version, viewport, orientation, and candidate.
2. Inspect field focus and the on-screen keyboard without a form submission.
3. Inspect sticky-CTA visibility with the keyboard open and closed.
4. Inspect safe-area spacing and orientation changes.
5. Inspect scroll behavior and form visibility.
6. Exercise FAQ controls and available keyboard or assistive navigation.
7. Record focus visibility and accessible FAQ state.
8. Retain device-specific proof in the private evidence store.

Unavailable required devices are NOT RUN.
Desktop emulation is not a real-device pass.
Missing device access or preview authorization remains a separate BLOCKED gate.

## Vendor tracking and consent observations

No vendor submission is authorized by this document.
Inspect existing scripts and authorized tag-manager configuration before proposing tracking changes.
Record existing pixel, form, dataset, and event integrations privately.
Missing inline JavaScript does not prove that a Lead event is absent.
Mocks, stubs, and synthetic local event assertions are not vendor acceptance.

Before any external test lead:

1. Obtain explicit authorization for the external submission and event count.
2. Identify the designated vendor development account privately.
3. Agree on synthetic test details and the cleanup owner.
4. Record possible notifications, emails, CRM entries, and conversion side effects.
5. Obtain agreement for those side effects and the cleanup procedure.
6. If isolation, access, or authorization is absent, stop.

For the authorized vendor run:

1. Inspect denied consent without bypassing consent controls.
2. Inspect granted consent through the normal user flow.
3. Submit only the agreed synthetic lead within the approved submission count.
4. Record the actual successful form event.
5. Inspect actual vendor Lead events after the agreed observation interval.
6. Record event names, counts, timing, and browser/server deduplication evidence privately.
7. Compare the observed counts with the agreed expectation for each consent state.
8. Record the cleanup outcome and any residual side effects.

A button click, visible success message, or network request alone does not prove a vendor Lead.
An absent event needs an observation interval and vendor evidence, not an inline-script inference.
Missing authorization or vendor access means BLOCKED.
Do not add another dataset, analytics package, or event under this runbook.

## Generic-first review gate and closure

The first deliverable is one Generic draft, not a set of sector clones.

1. Deliver its private preview through the approved channel.
2. Deliver its 390px full-page screenshot.
3. Deliver a concise summary with every FAIL, NOT RUN, and BLOCKED result.
4. Obtain explicit layout feedback before any sector clone.
5. Record approval privately and use a sanitized decision in any shared summary.

Missing sector variants are expected before this gate.
Do not create variants to make an incomplete acceptance record look complete.
Close acceptance only after the required operational evidence and review meet the agreed criteria.

Stop and report the blocker for missing inputs, unauthorized writes, unexpected side effects, or out-of-scope source defects.
Request a separately scoped product change rather than editing the application.
