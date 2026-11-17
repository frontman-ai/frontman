# Plan 003: Preserve disclosure state during screenshot capture

> Executor: This is a reproduction-first plan. Do not assume that FAQ expansion is a confirmed defect.
> Read complete browser test files before modification.
> Stop at a STOP condition. Update the status in `advisor-plans/README.md` after review.
>
> Drift check: `git diff --stat e87074a5..HEAD -- libs/client/src/tools/Client__Tool__TakeScreenshot.res libs/client/test/browser/Client__Tool__TakeScreenshot.test.res libs/bindings/src/Bindings__Snapdom.res libs/client/test/browser/Client__PreviewRecovery.test.res`

## Status

- Priority: P2 for characterization, conditional priority for a fix
- Effort: S for tests, M if a narrow defect reproduces
- Risk: LOW for coverage, MED for a capture change
- Depends on: none
- Category: tests
- Planned at: commit `e87074a5`, 2026-11-15

## Why this matters

A full-page screenshot must reflect the page's current disclosure state.
Opening every FAQ changes both the visible content and page geometry.
However, a report alone does not justify a state-mutation patch.
First exercise the real tool and distinguish image artifacts from changes to the live page.

## Current state and evidence limits

The registered tool uses SnapDOM, not Playwright's native full-page screenshot API.
[The binding](../libs/bindings/src/Bindings__Snapdom.res#L18-L20) calls:

```rescript
@module("@zumer/snapdom")
external snapdom: (WebAPI.DomTypes.element, ~options: captureOptions=?) => promise<captureResult> =
  "snapdom"
```

[Capture options](../libs/client/src/tools/Client__Tool__TakeScreenshot.res#L102-L115) differ by mode:

```rescript
            let (options, scale, dpr) = switch viewport {
            | Some(clip) => (
                Some({FrontmanBindings.Bindings__Snapdom.clip, reconcile: true}),
```

```rescript
            | None => (None, Client__ImageLimits.computeScale(element, limits.maxDimension), None)
            }
            let captureResult = await FrontmanBindings.Bindings__Snapdom.snapdom(element, ~options?)
            let jpgImage = await captureResult.toJpg({scale, quality: limits.quality, ?dpr})
            imageResultFromDataUrl(jpgImage.src)
```

Full-page mode removes viewport clipping.
It also differs from viewport mode in `reconcile`, not only image dimensions.
The wrapper contains no explicit `details.open` mutation.
It returns an MCP image block through `imageResultFromDataUrl`.

[Existing browser tests](../libs/client/test/browser/Client__Tool__TakeScreenshot.test.res#L22-L105) inspect image pixels and scroll preservation.
They cover body margins and fixed headers with default viewport capture.
They do not cover full-page or selector disclosure behavior.
[Preview recovery tests](../libs/client/test/browser/Client__PreviewRecovery.test.res#L81-L119) cover stale preview contexts.

A planning probe used installed SnapDOM 3.3.3 and Chromium 156.0.8078.4.
It captured a same-origin iframe with closed, open, runtime-closed, and below-fold disclosures.
Viewport, full-page, and selector captures preserved their states.
Closed answer pixels were absent, and no `open` attribute mutations occurred.
This probe did not run the compiled Frontman tool or the Make browser suite.
It is evidence against an unconditional library defect, not proof that every site renders correctly.

The dependency performs temporary live style/text preparation.
One probe observed equivalent inline-style serialization with different whitespace.
Do not define success as byte-for-byte DOM equality.
Do not edit installed dependency bundles.

## Scope and conventions

Initial scope:

- `libs/client/test/browser/Client__Tool__TakeScreenshot.test.res`
- `advisor-plans/003-screenshot-reproduction.md` (new sanitized result note)

Conditional implementation scope, only after a failing real-tool reproduction:

- `libs/client/src/tools/Client__Tool__TakeScreenshot.res`
- `libs/bindings/src/Bindings__Snapdom.res`, only for a proven per-capture option
- One user-facing changeset generated through `yarn changeset`, only for a behavior change

Use ReScript and existing typed browser bindings.
Reuse the current same-origin iframe and real image-decode/pixel assertion pattern.
Do not add JavaScript, dependency doubles, or another screenshot framework.

Out of scope:

- Customer markup, source FAQ behavior, or production-site reproduction
- Global SnapDOM plugins or arbitrary dependency upgrades
- Closing every disclosure or forcing every disclosure open
- Annotation capture, unrelated form controls, or screenshot schema changes
- General cancellation infrastructure or unrelated DOM restoration

## Commands

Run builds and browser targets sequentially.
Use the actual Chromium suite, not only Node unit tests.

| Purpose | Command | Expected result |
|---|---|---|
| Workspace build | `make build` | Exit 0 |
| Disclosure capture tests | `make -C libs/client test-screenshots BROWSER_TEST_FILTER=test/browser/Client__Tool__TakeScreenshot.test.res.mjs` | Exit 0 |
| Stale-preview regressions | `make -C libs/client test-screenshots BROWSER_TEST_FILTER=test/browser/Client__PreviewRecovery.test.res.mjs` | Exit 0 |
| Image result contract | `make -C libs/client test TEST_FILTER=test/Client__ToolRegistry.test.res.mjs` | Exit 0 |
| Full browser regressions | `make -C libs/client test-screenshots` | Exit 0 |
| Client regressions | `make -C libs/client test` | Exit 0 |
| Client lint | `make -C libs/client lint` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |

The browser configuration includes `test/browser/**/*.test.res.mjs`.
It runs headless Chromium through the existing Playwright provider.
If the browser dependency is unavailable, report BLOCKED.
Do not substitute image mocks.

## Steps

### 1. Extend the real-tool fixture

Keep the current fixture lifecycle and store cleanup.
Add:

- Initially closed and initially open disclosures
- A markup-open disclosure closed at runtime
- A closed disclosure below the fold
- Nested disclosures and named peer disclosures
- An unrelated disclosure outside the selected capture target

Give closed and open answers distinct solid colors.
Add geometry markers immediately after the disclosures.
Include input-value, text, focus, and scroll sentinels.
Include a `content-visibility:auto` sentinel.
Settle fixture initialization before recording toggle events.

Invoke `Client__Tool__TakeScreenshot.execute`, not an equivalent direct library call.
Exercise default mode, explicit `fullPage:false`, `fullPage:true`, a container selector, and a closed-details selector.
If feasible within the existing fixture, exercise a real registry dispatch too.
Do not add a new transport harness.

Verify: run the focused disclosure command.
Save the result and exact versions in the reproduction note.

### 2. Assert image output and live state separately

Decode the returned MCP image through the current image/canvas path.
Assert that closed answer colors are absent and open answer colors remain visible.
Use tolerances suitable for JPEG compression.
Assert downstream geometry and below-fold markers.
Account for the tool's existing image scaling.

Record original nodes, `open` properties, and attributes.
Observe `open` mutations and capture-induced toggle events after fixture initialization.
Inspect state after completion and after another animation frame.
Assert unchanged semantic scroll, focus, input, text, and relevant style values.
Do not fail solely because equivalent inline style text has different whitespace.

Verify: run the focused disclosure command.
A passing final-state assertion alone is insufficient.
The image and mutation assertions must also pass.

### 3. Classify a reproduced difference

Use this decision table:

| Observation | Next action |
|---|---|
| Image is wrong, live disclosure state is unchanged | Investigate clone/computed-style/rasterization behavior |
| Live disclosure state changes during or after capture | Identify the exact preparation step or application observer |
| Only native Playwright/browser capture is wrong | Keep the registered SnapDOM path unchanged |
| Only a historical or customer-specific version fails | Request an authorized sanitized minimal fixture |
| The real-tool fixture passes without a minimal reproduction | Retain useful coverage and stop before a speculative fix |

For a mode-specific difference, compare clipping and `reconcile` independently.
Do not attribute the result to full-page size alone.
Do not edit a customer site to produce the fixture.

Verify: rerun the focused command with the minimal failing case.
Record one discriminating observation before choosing a production change.

### 4. Apply only a proven narrow correction

Prefer an existing per-capture dependency option.
If necessary, expose a typed clone-only hook in the existing binding.
Preserve original open and closed states in the clone.
Keep any plugin registration local to one capture.
Do not hide all FAQ content or change the source page.

If a necessary live mutation is proven, snapshot only operation-owned values by node reference.
Restore those values on capture and export success or rejection.
Do not overwrite concurrent user/application changes.
Do not find replacement nodes in a newly navigated document.
Preserve the original error.

The current tool ignores its abort signal.
A never-settling promise does not reach `finally`.
`Promise.race` does not cancel late capture work.
If correctness requires live mutation across an unbounded await, stop and reconsider a clone-only correction.
Do not add a broad restoration or cancellation subsystem under this plan.

Verify: the minimal case must fail without the correction and pass with it.
Run focused capture, preview recovery, and image-result contract commands.

### 5. Complete coverage and record the outcome

Run the remaining command-table gates.
Record either:

- A reproduced defect, its responsible layer, and a passing regression
- No reproduced defect, characterization coverage, and the evidence still required

Do not declare that the incident defect is fixed solely because the synthetic fixture passes.
If only characterization changes, describe the release accordingly.

## Done criteria

- [ ] The real tool has full-page and selector disclosure coverage.
- [ ] Image content, geometry, and transient/final live state have separate assertions.
- [ ] Originally open disclosures remain open.
- [ ] Unrelated state remains semantically unchanged.
- [ ] Any production correction has a failing-before/passing-after reproduction.
- [ ] If no defect reproduces, the result note states that limit and no speculative patch exists.
- [ ] Browser, contract, lint, and diff gates pass.

## STOP conditions

- The real-tool fixture passes and no sanitized minimal reproduction exists.
- Reproduction requires production access or customer-site edits.
- The failure belongs only to another capture path or deployment.
- A proposed correction changes originally open disclosures or unrelated page state.
- A safe fix requires new cancellation, concurrency, or capture infrastructure.
- A deterministic failure case requires a new test double without permission.
- A gate fails twice after a reasonable correction.

## Git workflow and maintenance

Use one focused feature branch or attached isolated Delta worktree.
Do not merge, publish, deploy, or capture customer content without authorization.
Run disclosure regressions after SnapDOM updates or changes to image scaling.
Keep tests tolerant of image encoding and equivalent style serialization, but not disclosure-state changes.
