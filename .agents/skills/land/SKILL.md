---
name: land
description: >-
  Land requested Frontman changes through a verified GitHub pull request.
  Invoke only when the user explicitly requests landing or merging, including
  an explicit /land invocation, not for review, preparation, passing checks,
  or installation of this skill.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Land Frontman changes

An explicit invocation supplies permission to land the requested change. Proceed
through verification and merging without asking for the same permission again.
Stop for genuine blockers, ambiguous scope, unsafe changes, or unmet requirements.

## Establish scope and destination

1. Work only in the attached Frontman repository. Read current root and applicable
   nested `AGENTS.md`/`AGENT.md` instructions, `CONTRIBUTING.md`,
   `.github/pull_request_template.md`, and relevant workflows before proceeding.
2. Inspect status, staged and unstaged diffs, branch, remotes, and recent history.
   Identify the requested change and any existing PR. Preserve unrelated files
   and commits; do not stash, reset, clean, or overwrite someone else's work.
   Ask a focused question if the requested scope is unclear.
3. Verify the publication remote is `frontman-ai/frontman` on GitHub. The inspected
   remote is `origin`; `local` is a backlink, never a publication destination.
   Use authenticated `gh` and SSH Git access, checking availability without
   printing credentials.
4. Inspect repository merge settings, destination rulesets, classic protection,
   PR base and head, and any merge queue at execution time. The established
   destination is `main`, and squash is currently the only enabled merge method.
   A missing classic protection rule is not permission to ignore repository policy.
   If settings or intended destination conflict with this workflow, stop rather
   than guessing. Never change protection, bypass checks, or use `--admin`.

## Prepare the requested change

- If needed, create a feature branch from the intended base without rewriting
  shared history. Do not commit on or push directly to `main`.
- Review the complete PR diff, not just the latest commit. Keep it below 500
  net-new lines as required by root instructions; stop to split an oversized
  change instead of expanding scope.
- Include relevant tests and documentation. User-facing changes need changeset
  coverage for affected publishable packages. A direct applicable changelog update
  can satisfy the CI alternative. Restrict `skip-changelog` to genuinely
  chore/docs-only changes; never use it to conceal missing user-facing coverage.
  Sources: `AGENTS.md`, `CONTRIBUTING.md`,
  `.github/workflows/changelog-check.yml`.
- Fill out the PR description, related issue when applicable, and testing checklist.
  Preserve honest disclosure of tests not run, including the local development
  checklist item; do not invent issue links or claim a workflow was exercised.
  Sources: `.github/pull_request_template.md`, `CONTRIBUTING.md`.
- Check first-contribution CLA status through the existing signature/check.
  Do not ask an already-covered contributor to sign again. If signature is missing,
  stop for the contributor to complete it personally; never submit legal assent
  for them. Sources: `CLA.md`, `CONTRIBUTING.md`,
  `.github/workflows/cla.yml`.
- Obtain maintainer review and any applicable required approvals, including
  code-owner requirements. Evaluate review comments against the actual code;
  address valid findings, report disagreements clearly, and do not resolve
  comments merely to silence a gate. Never fabricate a human review.
  Sources: `CONTRIBUTING.md`, `.github/CODEOWNERS`, current destination rules.
- Stage only the intended files. Keep commit hooks enabled. Use non-interactive
  commits such as `GIT_EDITOR=true git commit -m "fix(wordpress): describe change"`;
  choose a truthful subject matching the scope and existing history, not that
  example verbatim. Preserve configured signing requirements. Source for hook
  checks: `lefthook.yml`.
- Push the feature branch to the verified publication remote without force.
  Create or update the matching PR and ensure all requested commits are included.
  Use `gh pr create`/`gh pr edit` with explicit non-interactive title/body inputs.
  Source for submission content and process: `CONTRIBUTING.md` and
  `.github/pull_request_template.md`.

## Integrate the destination safely

Fetch the current destination before integrating. If an update is needed, prefer
a normal merge of the destination into the feature branch over rebasing published
commits. Use `GIT_EDITOR=true git merge --no-edit origin/main` only after confirming
`origin` and `main` are the intended source and destination.

Resolve conflicts automatically only when intent is clear from both sides.
Preserve unrelated work and both sides' intended behavior. Stop and describe
ambiguous conflicts instead of choosing arbitrarily. Do not force-push.
After any integration or fix, rerun affected checks and require fresh remote
verification for the resulting head.

## Verify the exact changes

Use Make targets rather than yarn/npm scripts directly. Verify runtime
requirements against current manifests and workflows, not executable presence
alone. Current pins include Node 24.9.0 and Yarn 4.18.0 in `mise.toml`;
`package.json` specifies Yarn 4.18.0. CI currently also uses Node 24.4.1.
For server changes consult `mise.toml`, server manifests and nested instructions.
Do not silently substitute an unsupported runtime or install system tools.

Run proportional local checks for changed areas, retaining prior passing evidence
only when it covers the exact unchanged content and relevant configuration.
Local evidence never substitutes for required remote checks.

Verified project commands and their definitions:

- `make check-source-comments` runs the comment-policy tests and repository
  scanner. Run it before publishing, including skills/docs-only changes, and fix
  policy violations rather than disabling hooks.
  Source: root `Makefile`, `check-source-comments`; `lefthook.yml`;
  `.github/workflows/ci.yml`, `source-comments`.
- For ReScript changes, `make build RESCRIPT_FLAGS="--warn-error +a"` is the CI
  build invocation. Run `make -C libs/client test`,
  `make -C libs/frontman-client test`, `make -C libs/frontman-core test`,
  `make -C libs/frontman-nextjs test`, `make -C libs/frontman-protocol test`,
  `make -C libs/frontman-preview-bridge test`, or
  `make -C libs/react-statestore test` for affected libraries, not all libraries
  unconditionally. Sources: root `Makefile`, `build`; the named library
  `Makefile` files, `test`; `.github/workflows/ci.yml`, `build`.
- For WordPress changes use `make test-wordpress-core-tools`,
  `make test-wordpress-sentry`, and
  `PHP_VERSION=7.4 make test-wordpress-sentry`.
  Runtime-affecting changes also need `make test-wordpress-runtime` or the
  applicable passing remote runtime matrix. Sources: root `Makefile`,
  `test-wordpress-core-tools`, `test-wordpress-sentry`,
  `test-wordpress-runtime`; `.github/workflows/wordpress-compatibility.yml`.

### WordPress portability fallback

The dependency build uses Docker/Composer and checks a pinned PHP Scoper checksum
with `sha256sum --check --status`; it also needs `curl` and `rsync`.
Source: `scripts/build-wordpress-dependencies.sh`, called by the root
`build-wordpress-dependencies` target.

On macOS, if the available checksum implementation lacks those flags, use a
temporary PATH wrapper limited to that invocation which runs
`shasum -a 256 -c -s` on the same checksum input. This is a compatibility
translation, not permission to skip validation. Do not commit the wrapper.

The core-tools target invokes host `php`; a host PHP 8.5 can fail existing
reflection tests on deprecations. Use supported PHP 8.4 rather than suppressing
warnings. A temporary `php` PATH wrapper may execute Docker PHP 8.4 CLI with the
repository mounted read-only at its current absolute path and that path as the
working directory, forwarding every PHP argument unchanged. Do not imply this
wrapper supports other Docker or PHP operations. Linux container temporary
directories also avoid macOS `/var` symlink issues. If running on the host,
use a canonical temporary directory. Sources: root `Makefile`,
`test-wordpress-core-tools`; `.github/workflows/wordpress-compatibility.yml`,
isolated PHP container test step and PHP 8.4 matrix entries.

If a needed tool, authentication, supported runtime, or compatible environment is
unavailable, report the exact blocker. Do not weaken assertions, hide warnings,
edit build scripts solely to pass locally, or treat an unrun test as passing.

### Remote checks and review gate

After the final push, capture the PR head SHA and inspect its checks and statuses.
Discover the expected applicable jobs from current workflows and destination
rules, including `ci.yml`, CLA, changelog, security/dependency workflows, and the
WordPress matrix when its path filter applies. Inspect review decisions and
maintainer feedback too. Do not assume all workflows are mandatory on every path,
or confuse skipped conditional jobs with executed tests.

All required checks must have passed for the exact changes being landed under
the repository's rules. Repository contribution policy requires CI to pass even
where GitHub protection does not enforce it. Inspect all applicable workflow
results, not merely a subset returned by a required-checks filter.
Pending, failing, missing, cancelled, stale, or unverifiable required checks are
not success. Expected skipped jobs require a verified, applicable condition.
Do not use auto-merge as a shortcut around this verification.

Use bounded `gh pr checks`/`gh run view` inspection to obtain evidence. For a
failure, inspect logs and make only in-scope, understood fixes, then repeat
verification on the new head. Stop on an unrelated or ambiguous failure and
explain that the change has not landed. Do not bypass a failing check just
because it is not enforced by branch protection.

## Land and confirm

1. Immediately before merging, re-read the PR head, base, check results, rules,
   and review state. If the head changed, verify the new version before proceeding.
2. Squash the verified PR using
   `gh pr merge <PR-number> --repo frontman-ai/frontman --squash --match-head-commit <verified-head-SHA>`.
   Replace both placeholders with the discovered PR and exact verified SHA.
   The head-match flag prevents landing a concurrently changed PR.
   If a queue is required, obey it and verify the eventual completed merge;
   enqueueing alone is not success. Never use administrative bypass.
3. Verify GitHub reports `MERGED` into the intended base, record its merge
   commit, fetch the remote base, and confirm that commit is an ancestor of
   `origin/main`. A successful command, published branch, or green checks alone
   is not proof of landing.
4. Leave the user's checkout and unrelated branches intact. Do not reset local
   `main`, remove worktrees, or delete local branches as automatic cleanup.
   The repository may delete the remote head automatically after merge.
5. Report the PR, landed commit, verification performed, and any remaining
   limitations. If blocked or queued, state plainly that landing is incomplete.
   Do not publish packages, create release tags, or run release/deployment
   commands as an extra step; separate authorization is required.
