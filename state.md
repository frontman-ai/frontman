# PR #1069 Review Summary

## Findings

1. `apps/frontman_server/lib/frontman_server_web/play_github/controller.ex:150`
   `next_step/1` only handles `:dev_server_failed`; all normal lifecycle states are commented out. `?command=create` reaches `:sandbox_created`, then crashes with `CaseClauseError` instead of returning `next: ?command=clone`. This breaks launcher flow and contradicts `controller_test.exs:61-68`.

2. `apps/frontman_server/config/runtime.exs:52` + `apps/frontman_server/config/prod.exs:3`
   Prod keeps PlayGithub dark with `hosts: []`, but runtime still requires `DAYTONA_API_KEY`. Merge can break prod boot if Daytona secrets are not already deployed. Dark launch is not truly inert.

3. `plan.md:1`
   PR includes unrelated UGC/SEO plan content. Likely accidental. It dilutes PR scope and may expose draft marketing/outreach strategy.

4. `apps/frontman_server/lib/frontman_server_web/user_auth.ex:64-70` and `:89-105`
   Existing return URL allowlist accepts broad `.com/.net/.org`. PR's PlayGithub login redirect relies more heavily on absolute `return_to`; worth tightening to Frontman-owned hosts only.

## What This PR Tries To Achieve

PR adds first PlayGithub sandbox launch path:

- Route `playgithub.frontman.local/:owner/:repo[/tree/:ref/path]` for authenticated users.
- Parse GitHub-like paths into repo/tree/issue references.
- Create or reuse one persisted Daytona sandbox per user + GitHub target.
- Clone target repo into Daytona `workspace`.
- For tree paths, install/run from requested subdirectory.
- Install dependencies, then run `npx astro add @frontman-ai/astro --yes`.
- Start dev server on port `4321`.
- Proxy sandbox preview through Frontman-controlled PlayGithub host, including Vite assets/websockets.
- Keep prod feature disabled via `hosts: []` while preparing Daytona env/config/deploy plumbing.

## Local State Note

Worktree has uncommitted edits in Daytona toolbox/PlayGithub files plus untracked `frontman-summary.md`. Review above reflects current files and PR diff, but local dirty state may not match GitHub exactly.
