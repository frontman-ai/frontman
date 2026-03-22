---
description: Set up a containerized worktree for a GitHub issue or PR
---

Set up a containerized worktree, then ask the user to re-open the agent from it.

## Input

The user provided: `$ARGUMENTS`

This can be:
- **Issue URL**: contains `/issues/` (e.g. `https://github.com/frontman-ai/frontman/issues/462`)
- **Issue number**: a plain number (e.g. `462`)
- **PR URL**: contains `/pull/` (e.g. `https://github.com/frontman-ai/frontman/pull/99`)
- **PR number**: prefixed with `#` or context makes it clear it's a PR

## Steps

### 1. Detect input type and determine branch name

- **Issue** (contains `/issues/` or is a plain number):
  ```bash
  gh issue view <NUMBER> --json number,title,body,labels
  ```
  Branch name: `issue-<NUMBER>-<short-slug>` (slug: max 4 words from title, kebab-case)

- **PR** (contains `/pull/`):
  ```bash
  gh pr view <NUMBER> --json number,title,body,headRefName,labels
  ```
  Branch name: use the PR's `headRefName` as-is.
  Fetch the branch: `git fetch origin <branch-name>`

### 2. Set up containerized worktree

1. Check infra: `make wt` — run `make infra-up` if needed
2. Check if pod already exists: `make wt`
   - If running → skip creation
   - If stopped → `make wt-start BRANCH=<branch-name>`
   - If missing → `make wt-new BRANCH=<branch-name>`
3. Verify: `make wt`

### 3. Tell the user to re-open the agent

Print this message (fill in the branch name):

```
Worktree is ready. To start working, open your agent from the worktree directory:

  cd .worktrees/<branch-name>
  # then start your agent (claude, opencode, etc.)

Start the dev servers in another terminal:

   make wt-dev BRANCH=<branch-name>
```

**Do NOT attempt to implement anything.** The agent cannot operate on files in the worktree from the repo root. The user must re-open the agent from the worktree directory.
