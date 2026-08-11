# Implementation Plan: WordPress Task Demonstration

## Approach

Reuse existing local video and poster. Correct task description, add explicit acquisition paths, and extend consent analytics only enough to measure completed playback.

## Tasks

- [x] Add failing analytics tests for consent-gated, once-per-page video completion.
- [x] Add generic media-completion tracking to existing analytics runtime.
- [x] Align demonstration copy and analytics metadata with recorded FAQ-title task.
- [x] Link header-and-footer tutorial to demonstration and instrument final install action.
- [x] Run tests, build, browser verification, and diff review.

## Risks

- `ended` does not bubble. Use delegated capture handling and prove behavior in JSDOM.
- Replayed video can overcount completion. Deduplicate tracked media per page load.
- Cross-article link can imply unsupported header/footer behavior. State demonstration shows workflow only.
