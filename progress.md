PR #1069 adds authenticated `playgithub.frontman.local` routing, GitHub-shaped path parsing, deterministic Daytona sandbox get-or-create by repo target, and repo cloning into relative `workspace`.

Refresh behavior is safe: same repo reuses same sandbox, clone is skipped after `frontman.playgithub.cloned=true`, and refresh during clone returns `clone_state: cloning` instead of starting a duplicate clone.

Current manual flow is explicit: `?command=create` creates/reuses the sandbox, `?command=start` starts an existing stopped/archived sandbox without cloning/installing, `?command=clone` marks `clone_state=cloning` and starts clone into Daytona `workspace` in a supervised background task, `?command=install` marks `frontman_install_state=installing` and runs `npx astro add @frontman-ai/astro --yes` in a supervised background task, and `?command=dev` starts `npm run dev -- --host 0.0.0.0 --port 4321` in the target workspace path. Dev responses include a Daytona signed preview URL, Frontman proxy URL, and `/tmp/frontman-dev-server.log`.

GitHub tree paths now use their own Daytona sandbox names, separate from the root repo sandbox. For paths like `/owner/repo/tree/main/apps/marketing`, clone still uses the repo root but checks out the requested ref, responses include `github_ref`, `repo_path`, and `workspace_path`, and install runs from `workspace/apps/marketing` after verifying that subdirectory exists. Missing subdirectories mark `frontman_install_state=install_failed` with `frontman_install_error=Path workspace/apps/marketing does not exist`.

Fresh Daytona clones now install package dependencies before running Astro add, because `npx astro add` cannot load `astro.config.mjs` when `astro/config` is not installed yet. Repo-root URLs install from `workspace`; tree URLs require `workspace_path/package.json`, install from `workspace_path`, then run the unchanged Astro command in `workspace_path`.

Dependency install uses `corepack yarn install` / `corepack pnpm install` directly for projects whose selected install directory has those lockfiles, not `corepack enable`, because Daytona users cannot create global package-manager symlinks under `/usr/bin`.

If dependency install resolves `@frontman-ai/astro` as an unbuilt workspace package, PlayGithub builds that package before running Astro add. This handles repo configs that already import `@frontman-ai/astro` while the git clone lacks untracked `dist/` files.

Install progress now writes live logs inside Daytona to `/tmp/frontman-install.log`. The dependency install stage resets the file, the Astro add stage appends to it, both commands echo the log back to Daytona execute for failure capture, and install responses include `frontman_install_log: /tmp/frontman-install.log`.

Dev code reload caveat handled: if the running VM has not restarted with `FrontmanServer.PlayGithub.TaskSupervisor` in the supervision tree, clone/install falls back to `Task.start/1` instead of crashing the request. Fresh boots use the named task supervisor.

Stopped sandbox caveat handled: stale `frontman.playgithub.clone_state=cloning` is treated as active only when Daytona reports `state=started`; stopped sandboxes now queue Daytona `POST /sandbox/{id}/start` and continue clone/install in the same background job after the sandbox reaches `started`.

Clone failure caveat handled: PlayGithub no longer uses Daytona's deprecated git clone endpoint for state. Clone now runs as `git clone` through Daytona process execute, checks `exitCode`, writes `clone_state=failed` on non-zero exit, and writes `clone_started_at` so legacy/stale `cloning` labels can be retried by `?command=clone`.

Install failure caveat handled: `frontman_install_state=install_failed` is now reported explicitly instead of being hidden by automatic retry. `installing` writes `frontman_install_started_at`; legacy/stale `installing` labels are retried by `?command=install`, and process `exitCode != 0` writes `install_failed`.

Install failure reasons now surface in PlayGithub: non-zero Daytona execute output is compacted into `frontman.playgithub.frontman_install_error`, and `?command=install` prints `frontman_install_error: ...` when available.

Long failure reasons keep the tail of the output instead of the head, so the visible `frontman_install_error` shows the final command error rather than early Yarn warnings. Full install output remains available in `/tmp/frontman-install.log`.

To debug older install failures that have no stored error label, run `?command=install&retry=true`; this reruns install, captures non-zero execute output, stores `frontman.playgithub.frontman_install_error`, and subsequent `?command=install` prints the reason.

Focused PlayGithub tests pass: `mix test test/frontman_server/play_github/daytona_test.exs test/frontman_server/play_github_test.exs test/frontman_server_web/play_github/controller_test.exs`. Server precommit passes: `make precommit`.
