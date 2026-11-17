# Attachment recovery and the PDF decision

## Current decision

PDF rejection is intentional. The [shared protocol](../libs/frontman-client/src/FrontmanClient__ACP__Protocol.res#L17-L20) accepts image attachments, not documents.
The [editor allowlist](../libs/client/src/components/frontman/Client__PromptEditor.res#L50) contains PNG, JPEG, GIF, and WebP.
Users can paste document text and attach PNG screenshots today.

Plan 004 completes the recovery interface without native PDF ingestion.
Attachment errors remain visible until dismissal, with an alert role and a named dismiss button.
The attachment control states the image formats and the text-paste alternative.
Browser tests cover real files, retained drafts, and PNG resource serialization.
No PDF parser, document storage, provider payload, dependency, or endpoint ships with this change.
The existing size limits and server rejection contracts remain unchanged.

## Separate product decision

Native PDF support requires explicit product approval and a separate implementation plan.
The next decision must compare these approaches:

| Approach | Benefits | Costs and boundaries |
|---|---|---|
| Provider-neutral extraction | One document contract across models. Consistent text limits, provenance, and errors. | Requires extraction infrastructure. Scans require a separate OCR path. Layout can be lost. |
| Provider-native documents | Can preserve page layout and use provider document capabilities. | Model support varies. Upload formats, page accounting, costs, and retention depend on the provider. |

The recommended starting point for a future plan is provider-neutral extraction with hard page and byte limits.
This recommendation does not select a dependency or authorize implementation.
Provider-native documents remain an alternative if layout or scan quality justifies their restrictions.

## Requirements before implementation

The separate plan must define:

- **Budgets:** Numeric limits for input pages, input bytes, extracted UTF-8 bytes, and OCR time.
  Each supported model needs an input-token limit with room for history and output.
  Extraction must stop before a limit, not silently truncate content.
  The existing 8 MB message budget remains a separate constraint.
- **Text PDFs:** Extraction order, page boundaries, and handling for missing or unusable text.
- **Scanned PDFs:** An explicit OCR decision, supported languages, quality expectations, and failure behavior.
  Text extraction alone must not count as scan support.
- **Password protection:** An explicit rejection or an approved password workflow.
  Passwords must not enter conversation history or logs.
- **Malformed documents:** Bounded processing, isolation, and a clear rejection.
- **Provenance:** Original filename, page references, extraction method, and warnings.
  Extracted text must remain identifiable as document content.
- **Failures:** Actionable messages for unsupported models, page limits, byte limits, OCR failures, and corrupt files.
  A failure must preserve the draft and accepted attachments.
- **Retention:** Where original files and extracted content reside, who can access them, and when deletion occurs.
  Provider-native uploads require a separate review of provider retention.

This decision requires no customer documents or uploads.
Passing the attachment regression suites does not establish PDF support.
