# Reduce Edit Token Generation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce wasted output tokens by steering the LLM toward `write_file` for large rewrites and smaller `edit_file` calls for surgical changes.

**Architecture:** Three string changes — two tool descriptions and one system prompt rewrite. No new tools, no new modules.

**Tech Stack:** ReScript (tool descriptions), Elixir (system prompt), ExUnit (tests)

---

### Task 1: Update `edit_file` tool description

**Files:**
- Modify: `libs/frontman-core/src/tools/FrontmanCore__Tool__EditFile.res:20-31`

- [ ] **Step 1: Append guidance to the `edit_file` description**

In `FrontmanCore__Tool__EditFile.res`, change the `description` string from:

```rescript
let description = `Edits a file by replacing text using fuzzy matching.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- oldText (required): The text to find and replace. An empty oldText creates a new file with newText as content.
- newText (required): The replacement text (must differ from oldText)
- replaceAll (optional): If true, replaces all occurrences. Default: false.

The tool uses multiple matching strategies (exact, line-trimmed, whitespace-normalized,
indentation-flexible, etc.) to handle common formatting differences.

IMPORTANT: You must read_file before editing. The tool will reject edits on unread files.`
```

To:

```rescript
let description = `Edits a file by replacing text using fuzzy matching.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- oldText (required): The text to find and replace. An empty oldText creates a new file with newText as content.
- newText (required): The replacement text (must differ from oldText)
- replaceAll (optional): If true, replaces all occurrences. Default: false.

The tool uses multiple matching strategies (exact, line-trimmed, whitespace-normalized,
indentation-flexible, etc.) to handle common formatting differences.

When replacing most of a file, prefer write_file instead — it avoids reproducing the original content. Use edit_file for surgical changes: a few lines, a function body, a config block. For multiple changes in one file, make several small edit_file calls targeting specific sections rather than one large replacement.

IMPORTANT: You must read_file before editing. The tool will reject edits on unread files.`
```

- [ ] **Step 2: Build to verify no syntax errors**

Run: `cd libs/frontman-core && make build`
Expected: Clean build, no errors.

- [ ] **Step 3: Commit**

```bash
git add libs/frontman-core/src/tools/FrontmanCore__Tool__EditFile.res
git commit -m "perf(tools): add write_file guidance to edit_file description (#745)"
```

---

### Task 2: Update `write_file` tool description

**Files:**
- Modify: `libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res:12-23`

- [ ] **Step 1: Append guidance to the `write_file` description**

In `FrontmanCore__Tool__WriteFile.res`, change the `description` string from:

```rescript
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content: Text content to write (mutually exclusive with image_ref)
- image_ref: URI of a user-attached image to save (e.g., "attachment://att_abc123/photo.png"). Use this to save images the user has pasted into the chat. Mutually exclusive with content.
- encoding: Set to "base64" when writing binary data (used internally when image_ref is resolved)

Provide either content OR image_ref, not both.
Creates parent directories if they don't exist. Overwrites existing files.

IMPORTANT: If the file already exists, you MUST read it with read_file first. The tool will reject writes to existing files that haven't been read.`
```

To:

```rescript
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content: Text content to write (mutually exclusive with image_ref)
- image_ref: URI of a user-attached image to save (e.g., "attachment://att_abc123/photo.png"). Use this to save images the user has pasted into the chat. Mutually exclusive with content.
- encoding: Set to "base64" when writing binary data (used internally when image_ref is resolved)

Provide either content OR image_ref, not both.
Creates parent directories if they don't exist. Overwrites existing files.

Prefer write_file over edit_file when rewriting most of a file — it is more efficient since you only provide the final content once.

IMPORTANT: If the file already exists, you MUST read it with read_file first. The tool will reject writes to existing files that haven't been read.`
```

- [ ] **Step 2: Build to verify no syntax errors**

Run: `cd libs/frontman-core && make build`
Expected: Clean build, no errors.

- [ ] **Step 3: Commit**

```bash
git add libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res
git commit -m "perf(tools): add edit_file guidance to write_file description (#745)"
```

---

### Task 3: Trim and update system prompt

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/execution/prompts.ex:17-73`
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/prompts_test.exs:72-82`

- [ ] **Step 1: Rewrite `@base_system_prompt` in `prompts.ex`**

Replace the entire `@base_system_prompt` (lines 17-73) with:

```elixir
  @base_system_prompt """
  ## Tone & Style

  - Be concise and direct. Match response length to task complexity.
  - No filler — skip "Sure!", "Of course!", "Great question!", "Certainly!", etc. Jump straight to the substance.
  - Prioritize technical accuracy over reassurance. If the user's approach has problems, say so directly. Investigate before confirming assumptions.
  - Use GitHub-flavored markdown. Backticks for paths, functions, and commands.
  - Only use emojis if explicitly asked.

  ## Proactiveness

  - Default to doing the work. Don't ask "Should I proceed?" or "Do you want me to...?" — just proceed with the most reasonable approach and state what you did.
  - Only ask questions when genuinely blocked:
    - The request is ambiguous in a way that would produce materially different results
    - The action is destructive or irreversible
    - You need a credential or value that cannot be inferred from context
  - If you must ask: complete all non-blocked work first, then use the `question` tool. Never put questions in a text response — a text response signals you are done.

  ## Rules

  - Use paths as provided. If given an absolute path, use it as-is.
  - List → Read → Modify. Never edit unseen files.
  - Keep diffs small and targeted. For file edits: use `edit_file` for surgical changes. When rewriting most of a file, use `write_file` — avoid reproducing large blocks of original content. For multiple changes in one file, prefer several small edits over one large replacement.
  - After 2 failed tool calls on the same tool, try an alternative approach. After 3 total failures, use the `question` tool to ask about the error.
  - Each tool's description explains when to use it and when to prefer alternatives.

  ## Response Formatting

  - Lead with what changed and why. Reference file paths — don't dump full file contents.
  - After edits, summarize: what changed, why, trade-offs, alternatives. For UI changes, suggest visual verification. Never complete silently.
  - Reference files as `src/app.ts:42`. Use numbered lists for multiple options.

  ## Code Quality

  - Implement completely. No placeholders or TODOs.
  - Do what's asked, no more. Match existing code style.
  - Add comments only for non-obvious logic.

  ## UI & Layout Changes

  When asked to modify visual appearance, layout, or spacing:
  - **Before editing**: Use `take_screenshot` to capture the current visual state and `get_dom` to inspect the rendered page structure. The simplified DOM output includes `component` attributes showing which React/Vue/Astro component renders each element — use these to map DOM sections back to source code.
  - **Strategy**: Prefer structural layout changes (collapsible sections, density modes, layout restructuring) over cosmetic tweaks (padding/margin adjustments) unless the user specifically requests cosmetic changes. For ambiguous requests like "make it smaller" or "take less space", identify which sections consume the most space before editing.
  - **After editing**: Use `take_screenshot` again to verify the result visually. Summarize what changed, what trade-offs were made, what alternatives exist, and suggest the user verify in their browser.
  """
```

- [ ] **Step 2: Update test assertions in `prompts_test.exs`**

The test at line 72-82 asserts `## Professional Objectivity` exists as a section. Since we merged it into Tone & Style, update the test:

Change the `"base prompt always includes core sections"` test from:

```elixir
    test "base prompt always includes core sections" do
      prompt = Prompts.build([])

      assert prompt =~ "## Tone & Style"
      assert prompt =~ "## Professional Objectivity"
      assert prompt =~ "## Proactiveness"
      assert prompt =~ "## Rules"
      assert prompt =~ "## Response Formatting"
      assert prompt =~ "## Code Quality"
      assert prompt =~ "## UI & Layout Changes"
    end
```

To:

```elixir
    test "base prompt always includes core sections" do
      prompt = Prompts.build([])

      assert prompt =~ "## Tone & Style"
      assert prompt =~ "## Proactiveness"
      assert prompt =~ "## Rules"
      assert prompt =~ "## Response Formatting"
      assert prompt =~ "## Code Quality"
      assert prompt =~ "## UI & Layout Changes"
    end
```

- [ ] **Step 3: Add test for edit strategy guidance**

Add a new test to the `"build/1"` describe block in `prompts_test.exs`:

```elixir
    test "includes edit strategy guidance in rules" do
      prompt = Prompts.build([])

      assert prompt =~ "edit_file"
      assert prompt =~ "write_file"
      assert prompt =~ "surgical changes"
    end
```

- [ ] **Step 4: Run the tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/prompts_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution/prompts.ex apps/frontman_server/test/frontman_server/tasks/execution/prompts_test.exs
git commit -m "perf(prompts): trim system prompt and add edit strategy guidance (#745)"
```
