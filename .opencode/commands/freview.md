---
description: Prepare PR with CI checks and Devin AI review loop
---

You are running the Frontman full review workflow. Follow these steps precisely.

Before starting, read and internalize the project guidelines:
- @CLAUDE.md
- @apps/frontman_server/AGENTS.md

---

## Phase 1: Branch & Issue Setup

1. Check the current git branch:
   !`git branch --show-current`

2. Check current git status:
   !`git status --short`

3. **Determine the issue:**
   - If the current branch is already named `issue-XXX` or `issue-XXX-*`, extract the issue number from it.
   - If the user provided an issue number as an argument (`$ARGUMENTS`), use that.
   - If neither applies, **ask the user**: "What GitHub issue are we working on? Please provide the issue number (e.g. 247)."
   - Once you have the issue number, if you are NOT already on an `issue-XXX` branch, create and switch to one:
     ```
     git checkout -b issue-XXX
     ```

---

## Phase 2: Rebase & Squash

1. **Pull latest main and rebase:**
   ```
   git fetch origin main
   git rebase origin/main
   ```
   If there are conflicts, resolve them and continue the rebase.

2. **Squash all commits on this branch into a single commit:**
   - Count the commits ahead of main:
     ```
     git rev-list --count origin/main..HEAD
     ```
   - If more than 1 commit, perform an interactive-free squash:
     ```
     git reset --soft origin/main
     git commit -m "issue-XXX: <brief summary of changes>"
     ```
   - Use the issue title from GitHub as the commit summary if available.

3. **Create the changeset** (required by CI):
   - Run `yarn changeset` and create the appropriate changeset entry for the changes made.
   - If unsure about the changeset scope, review the files changed and categorize appropriately.

---

## Phase 3: Push & Open PR

1. **Force-push the squashed branch:**
   ```
   git push --force-with-lease origin issue-XXX
   ```

2. **Open a Pull Request** (if one doesn't already exist for this branch):
   - Use `gh pr create` with:
     - Title: `fix/feat: <description> (#XXX)` (match the change type)
     - Body: reference the issue with `Closes #XXX`
     - Base: `main`
   - If a PR already exists, note the PR number.

3. **Get the PR number** for subsequent steps:
   ```
   gh pr view --json number -q .number
   ```

---

## Phase 4: Devin AI Review

1. **Browse to the Devin review page** using the opencode-browser plugin:
   - Navigate to: `https://app.devin.ai/review/frontman-ai/frontman/pull/<PR_NUMBER>`
   - **Wait for Devin to finish processing** before extracting anything:
     - The page will show a processing/loading indicator while Devin is still analyzing the PR
     - Poll the page by taking screenshots or reading page content every 15-20 seconds
     - Look for signs that processing is complete (e.g. the loading spinner disappears, a review summary appears, or the status changes from "processing"/"analyzing" to a completed state)
     - **Do NOT extract findings while Devin is still processing** — the results will be incomplete
     - Only proceed once the review is fully rendered and no loading indicators remain

2. **Extract the review findings** from the fully loaded Devin review page:
   - Take a screenshot or read the page content
   - Look for the review sections that contain bugs, issues, or suggestions
   - **Only extract actual bugs and issues** - ignore style nits, minor suggestions, or praise
   - Create a structured list of actionable items

3. **If Devin found bugs/issues:**
   - For each bug/issue identified:
     a. Fix the issue in the codebase
     b. Verify the fix is correct
   - After all fixes are applied:
     a. Amend the squashed commit with the fixes
     b. Force-push to the PR branch
     c. **Go back to Phase 4** (re-check Devin review)

4. **If Devin review is clean (no bugs/issues):**
   - Proceed to Phase 5

---

## Phase 5: Wait for CI Checks

1. **Poll CI status** until all checks complete:
   ```
   gh pr checks <PR_NUMBER> --watch
   ```

2. **If CI fails:**
   - Read the failing check logs
   - Fix the issues in the codebase
   - Amend the commit and force-push again
   - **Go back to Phase 4** (Devin review again after the fix)

3. **CI must be fully green before proceeding.**

---

## Phase 6: Final Verification

1. Confirm that:
   - Devin review has no outstanding bugs/issues
   - CI checks are all green
   - The PR is ready for human review

2. **Report to the user:**
   - PR URL
   - Summary of changes
   - Number of review iterations it took
   - Any remaining Devin suggestions that were intentionally skipped (with reasoning)

---

## Important Notes

- **Never skip the Devin review** - always browse to the review page and extract findings
- **Never skip CI checks** - always wait for them to complete
- **Loop until clean** - the Devin review + CI checks cycle must repeat until BOTH pass without issues
- **Changeset is required** - the changelog CI check will fail without it
- If the user provided `$ARGUMENTS`, treat the first argument as the issue number
- Use `--force-with-lease` (not `--force`) for safety when force-pushing
