---
"@frontman-ai/client": patch
---

### Fixed
- **Annotation enrichment failures are no longer silent** — the three async enrichment fields (`selector`, `screenshot`, `sourceLocation`) now use `result<option<T>, string>` instead of `option<T>`, capturing per-field error details for debugging.
- **Send-before-ready race condition** — the submit button is now disabled while any annotation is still enriching, preventing empty annotation stubs from being sent to the LLM.
- **Missing error dispatch on outer catch** — when the entire `FetchAnnotationDetails` promise chain fails, a `Failed` status with error details is now dispatched instead of only logging to console.

### Added
- `enrichmentStatus` field on `Annotation.t` (`Enriching | Enriched | Failed({error: string})`) to track the enrichment lifecycle.
- `hasEnrichingAnnotations` selector for gating the send button.
- Visual feedback on annotation markers: pulsing badge while enriching, amber badge with error tooltip on failure.
- Status indicator in the selected element display (spinner while enriching, warning icon on failure).
