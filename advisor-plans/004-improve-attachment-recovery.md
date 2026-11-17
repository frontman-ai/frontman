# Plan 004: Make unsupported attachments easy to recover from

> Executor: Read this plan before implementation. Read complete test files before adding tests.
> Stop at a STOP condition. Update the status in `advisor-plans/README.md` after review.
>
> Drift check: `git diff --stat e87074a5..HEAD -- libs/client/src/components/frontman/Client__PromptInput.res libs/client/src/components/frontman/Client__PromptEditor.res libs/client/src/state/Client__State__Prompt.res libs/frontman-client/src/FrontmanClient__ACP__Protocol.res apps/frontman_server/lib/frontman_server/tasks/interaction.ex`

## Status

- Priority: P3
- Effort: M, approximately one day
- Risk: LOW for recovery guidance, HIGH for any separate PDF ingestion feature
- Depends on: none
- Category: dx
- Planned at: commit `e87074a5`, 2026-11-15

## Why this matters

The client supports PNG, JPEG, GIF, and WebP attachments.
It deliberately rejects PDFs and tells users to paste text or attach images.
This plan makes that recovery visible and adds browser coverage.
It does not treat an unreceived file as proof of an upload defect.

Native PDF ingestion is a separate product decision.
Do not add a parser, provider-specific PDF payload, or new storage path under this plan.

## Current state

[The shared protocol error](../libs/frontman-client/src/FrontmanClient__ACP__Protocol.res#L17-L20) already provides the correct recovery:

```rescript
let maxMessageBytes = 8_000_000
let envelopeReserveBytes = 4096
let promptSizeError = "Prompt and attachments are too large. Remove images or shorten the text and try again (8 MB message limit)."
let unsupportedAttachmentError = "Documents, including PDFs, are not supported. Paste the document text or attach PNG, JPEG, GIF, or WebP images instead."
```

[The editor](../libs/client/src/components/frontman/Client__PromptEditor.res#L588-L600) reports unsupported files through `onFileSizeError`.
The same callback reports file-size errors.
[The input](../libs/client/src/components/frontman/Client__PromptInput.res#L362-L369) clears every such error after three seconds:

```rescript
  React.useEffect1(() => {
    switch fileSizeError {
    | Some(_) =>
      let timeoutId = setTimeout(() => setFileSizeError(_ => None), 3000)
      Some(() => clearTimeout(timeoutId))
    | None => None
    }
  }, [fileSizeError])
```

The error container at lines 410–418 has no alert role.
The accepted picker types are defined at `Client__PromptEditor.res:50`.
The server independently restricts new attachments at `interaction.ex:176–182`.
Historical PDFs produce an explicit unsupported-content notice at `interaction.ex:1244–1261`.
Preserve those boundaries.

## Scope and conventions

Modify only:

- `libs/client/src/components/frontman/Client__PromptInput.res`
- `libs/client/src/components/frontman/Client__PromptEditor.res`, only if browser evidence requires an input-path correction
- `libs/client/test/browser/Client__PromptAttachments.test.res` (new)
- `advisor-plans/004-pdf-support-decision.md` (new decision note, not a claim of shipped support)
- One user-facing changeset generated through `yarn changeset`

Read-only reference files:

- `libs/client/src/state/Client__State__Prompt.res`
- `libs/frontman-client/src/FrontmanClient__ACP__Protocol.res`
- `libs/client/test/Client__PromptEditor.test.res`
- `libs/client/test/browser/Client__PromptEditorUpdates.test.res`
- `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs`

Use ReScript and existing typed browser APIs.
Keep message submission in the existing state/reducer path.
Do not create a parallel upload service or add test doubles.
Use real browser `File` objects and the actual prompt editor.

## Commands

| Purpose | Command | Expected result |
|---|---|---|
| New real-browser cases | `make -C libs/client test-screenshots BROWSER_TEST_FILTER=Client__PromptAttachments` | Exit 0 |
| Editor regressions | `make -C libs/client test TEST_FILTER=Client__PromptEditor` | Exit 0 |
| Shared protocol regressions | `make -C libs/frontman-client test` | Exit 0 |
| Server attachment regressions | `make -C apps/frontman_server test TEST_ARGS="test/frontman_server/tasks/interaction_test.exs test/frontman_server_web/channels/task_channel_test.exs"` | Exit 0 |
| Client lint | `make -C libs/client lint` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |

Run client build targets sequentially.
The existing browser editor test provides the React mount and cleanup pattern.
The channel suite includes PDF rejection through the real acceptance boundary.
Do not introduce another mocked transport test.

## Steps

### 1. Add browser cases for supported and unsupported inputs

Mount the real input/editor components in Chromium.
Use a tiny valid synthetic PNG and a synthetic PDF file.
Exercise the actual drop path and the attachment-picker path where browser bindings permit it.
Do not use a filename in prompt text as a substitute for a file.

Assert these outcomes:

- A supported PNG appears as an attachment chip.
- A PDF produces the existing recovery message.
- The rejected PDF does not become an attachment chip.
- Rejection does not delete existing prompt text or supported attachment chips.
- A mixed PNG/PDF batch keeps the PNG and reports the rejected PDF.
- A rejected submission preserves the draft editor content.

Verify: run the browser command.
Record which cases fail before a production change.

### 2. Keep the recovery message visible and accessible

Remove the unconditional three-second dismissal.
Keep the message visible until the user dismisses it.
Add an accessible dismiss button and an appropriate alert role.
Reuse the shared protocol error text rather than copying a second message.
Keep existing local composer-state conventions.
Do not rename callback types across packages solely to improve the current callback name.

Add concise image-only help beside the attachment control.
State the supported formats and the text-paste alternative.
Do not promise PDF extraction or acceptance.

Verify: extend the browser cases to assert the alert, dismissal, and retained draft.
Run the browser command and editor regressions.

### 3. Protect attachment continuity without redesign

Use the real serializer to inspect a submitted PNG resource.
Assert a nonempty blob, filename, MIME type, and attachment URI.
Assert that text-only **Execute plan** does not remove earlier image-bearing conversation messages.
Reuse the existing message-history and handoff contracts.

If the continuity assertion fails, stop with the failing boundary.
Do not invent a new attachment store or change persistence under this plan.

Verify: run shared protocol and server attachment regressions.
Record that passing these tests does not prove support for documents.

### 4. Record the PDF decision gate

Create a short decision note with these facts:

- PDF rejection is intentional current behavior.
- A text-paste and PNG workflow already exists.
- The new recovery interface is complete without PDF ingestion.
- Native PDF support requires an explicit product decision.

If PDF support becomes a requirement, propose a separate implementation plan.
Recommend provider-neutral extraction with explicit page and byte limits.
The proposal must define text PDFs, scanned PDFs, password protection, and malformed documents separately.
It must also define output provenance, extraction failure messages, retention, and model-size budgets.
Compare local extraction with provider-native document input.
Do not select a dependency or upload customer documents during this decision.

Verify: review the note against the preserved protocol and server rejection tests.
Run `git diff --check`.

### 5. Finish the change

Run all command-table gates.
Add the changeset.
Summarize completed recovery work separately from the deferred PDF decision.

## Done criteria

- [ ] Unsupported-file errors remain visible until dismissal.
- [ ] The alert and dismiss control have accessible roles and names.
- [ ] PNG acceptance and mixed-file behavior pass in a real browser.
- [ ] Existing text and accepted attachments survive a rejection.
- [ ] Serialization retains the PNG resource fields.
- [ ] Server and shared protocol PDF rejection remain unchanged.
- [ ] The PDF decision note does not claim that PDF support shipped.

## STOP conditions

- The live code already supports PDFs through a different documented contract.
- A proposed change alters the message-size budget or persistence schema.
- Implementation requires JavaScript, a new package, or a new upload endpoint.
- Attachment continuity fails outside the scoped input components.
- A real dependency is unavailable, or a gate fails twice.

## Git workflow and maintenance

Use one focused feature branch or attached isolated Delta worktree.
Do not publish, deploy, or submit customer files.
Keep format guidance aligned with the shared protocol and server allowlist.
Review every future file-format addition at all three boundaries.
