# Reduce Token Generation for Large File Edits

**Issue:** #745
**Approach:** Prompt guidance (Approach C from the issue)
**Scope:** Tool description and system prompt changes only — no new tools

## Problem

The `edit_file` tool requires the LLM to output both `oldText` (text to match) and `newText` (replacement). For large edits, the model generates the entire original content AND the new content, doubling output tokens. Observed: ~2.5 minutes on a single inference pass generating a full-file rewrite where `oldText` alone was ~5KB.

## Design

Three targeted string changes across three files.

### 1. `edit_file` tool description

**File:** `libs/frontman-core/src/tools/FrontmanCore__Tool__EditFile.res`

Append to the existing `description` string:

> When replacing most of a file, prefer `write_file` instead — it avoids reproducing the original content. Use `edit_file` for surgical changes: a few lines, a function body, a config block. For multiple changes in one file, make several small `edit_file` calls targeting specific sections rather than one large replacement.

### 2. `write_file` tool description

**File:** `libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res`

Append to the existing `description` string:

> Prefer `write_file` over `edit_file` when rewriting most of a file — it's more efficient since you only provide the final content once.

### 3. System prompt — trim and add edit strategy

**File:** `apps/frontman_server/lib/frontman_server/tasks/execution/prompts.ex`

Rewrite `@base_system_prompt` to:
- Merge "Professional Objectivity" section into a single bullet under "Tone & Style"
- Remove redundant filler-phrase bullets (lines 22-23 say the same thing)
- Trim "Response Formatting" from 6 bullets to 3 (drop standard markdown advice)
- Trim "Code Quality" from 5 bullets to 3 (drop points covered by tool descriptions)
- Add edit strategy guidance to the "Rules" section: use `edit_file` for surgical changes, `write_file` for large rewrites, prefer multiple small edits over one large replacement
- Leave "Proactiveness" and "UI & Layout Changes" sections unchanged

Net effect: ~15 fewer lines, plus the new edit strategy bullet.

## Files Changed

| File | Change |
|------|--------|
| `libs/frontman-core/src/tools/FrontmanCore__Tool__EditFile.res` | Append guidance to `description` |
| `libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res` | Append guidance to `description` |
| `apps/frontman_server/lib/frontman_server/tasks/execution/prompts.ex` | Trim prompt + add edit strategy rule |

## Testing

- Verify tool descriptions render correctly by checking the serialized tool schemas (the `description` field in the JSON sent to the LLM)
- Verify system prompt builds correctly via existing `Prompts.build/1` tests (or add one if none exist)
- Manual verification: run a task that triggers a large file edit and observe whether the agent chooses `write_file`

## Future Work

- #748: Optimize old `edit_file` tool calls in message history (strip `oldText` from completed edits)
- Line-range edit tool (`edit_file_lines`) for partial edits without `oldText` reproduction (Approach A from #745)
