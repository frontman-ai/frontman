# Plan 003: Screenshot disclosure investigation

## Status

The actual-tool characterization passed. The reported FAQ expansion did not reproduce.
The investigation ended at the no-minimal-reproduction stop condition, not at an environment blocker.
The production capture code is unchanged. This result does not establish that the reported incident is fixed.

All prescribed commands ran. The test gates passed, but client lint failed in two unchanged files.
The lint failures remain outside this plan's edit scope.

## Environment

- Installed SnapDOM: `@zumer/snapdom` 3.3.3.
- Installed Playwright: 1.64.0.
- Browser: Google Chrome for Testing 156.0.8078.4, through the existing headless Chromium provider.
- The Chromium executable returned its version. The actual browser suite completed.
- The scoped drift check against `e87074a5` returned no differences.

## Coverage and observations

The existing screenshot browser test now contains an additional same-origin iframe fixture.
It includes closed, open, runtime-closed, below-fold, nested, and named-peer disclosures.
An open disclosure remains outside the selected container.

The six new cases cover:

- Default viewport capture.
- Explicit `fullPage:false`.
- `fullPage:true`.
- Container selector capture.
- Closed-details selector capture.
- Full-page capture through the actual registered tool.

Each case decodes the actual MCP JPEG and reads its canvas pixels.
The images contain no closed-answer red pixels. Open answers and downstream markers retain their expected colors and geometry.
Full-page and container images include the below-fold markers.
The orange answer outside the container appears only in the full-page images.
The assertions use channel tolerances for JPEG and scale image coordinates from the actual output dimensions.

Fixture initialization settles before mutation observers and toggle listeners start.
Every case records zero `open` mutations and zero toggle events during capture.
Original nodes retain their `open` properties, attributes, and geometry after completion and after further animation frames.
Input value, text, focus, window scroll, element scroll, and semantic style values also remain unchanged.
The style assertions compare individual properties, not serialized inline-style whitespace.

The full-page run emitted SnapDOM's text-wrap warning about `reconcile:true`.
The disclosure assertions still passed.
Viewport mode uses clipping plus reconciliation. Full-page and selector modes omit those capture options.
No mode-specific defect appeared, so no independent clipping/reconciliation discrimination or clone/render correction was necessary.

## Commands and results

The final command sequence ran sequentially:

| Command | Result |
|---|---|
| `make build` | Exit 0 |
| `make -C libs/client test-screenshots BROWSER_TEST_FILTER=test/browser/Client__Tool__TakeScreenshot.test.res.mjs` | Exit 0, 8 passed |
| `make -C libs/client test-screenshots BROWSER_TEST_FILTER=test/browser/Client__PreviewRecovery.test.res.mjs` | Exit 0, 5 passed |
| `make -C libs/client test TEST_FILTER=test/Client__ToolRegistry.test.res.mjs` | Exit 0, 7 passed |
| `make -C libs/client test-screenshots` | Exit 0, 81 passed across 8 files |
| `make -C libs/client test` | Exit 0, 532 passed and 2 skipped, with 60 passed files and 1 skipped file |
| `make -C libs/client lint` | Exit 2, two existing formatting/import errors |
| `git diff --check` | Exit 0 |

The skipped client file is `test/Client__WordPressBrowser.test.res.mjs`, with two skipped tests.
No prescribed gate was skipped.

Client lint reported:

- `libs/client/rescript.json`: formatting of the `warnings` object.
- `libs/client/test/Client__IntegrationUpdates.test.mjs`: import ordering.
- An informational deprecation notice for the `recommended` Biome field.

The diff for both lint-error files is empty. This plan does not change them.
Initial authoring builds failed on unsupported cleanup syntax and missing case-array type information.
After the authorized continuation corrected these test-only errors, all builds and test gates passed.

## Evidence limits

The synthetic fixture does not reproduce historical, customer-specific, version-specific, or native-browser screenshot behavior.
Further product investigation requires an authorized, sanitized minimal reproduction through the registered tool.
The existing preview recovery and image-result contract tests remain unchanged.

No production fix, dependency upgrade, changeset, index update, Git merge, publication, deployment, production access, or customer-site edit occurred.
These test and documentation changes do not change released behavior, so they have no user-facing changeset.
The parent maintains the plan index and the docs/chore changelog convention.
