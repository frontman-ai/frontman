Added Phoenix host-scoped `playgithub.frontman.local` authenticated route, SSL cert setup, tests, changeset, committed, pushed, and opened PR #1069.

Added PlayGithub string parser structs/routes for repo, tree, issues paths; printed parsed parts; tested auth, parsing, invalid issues.

Added `PlayGithub.github_url/1` from parsed GitHub path struct and printed/tested it.

Added tested Daytona repo clone primitive; not wired into controller yet.

Moved browser-facing local Frontman auth flow to `frontman.local`/`playgithub.frontman.local` with shared `.frontman.local` cookie domain.

Added Daytona org header; PlayGithub sandbox creation now works manually.

Added deterministic PlayGithub Daytona sandbox naming from repo URL, repo URL labels, and get-or-create reuse so refresh returns the same sandbox status.

Wired PlayGithub started Daytona sandboxes to clone the GitHub repo into relative `workspace`, mark the sandbox cloned via labels, and skip duplicate clone on refresh.

Added a `frontman.playgithub.clone_state=cloning` label before clone so refresh during clone returns `clone_state: cloning` instead of starting a duplicate clone.
