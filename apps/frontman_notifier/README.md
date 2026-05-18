# Frontman Notifier

Production-only worker that posts Discord notifications for:

- New GitHub stargazers on `frontman-ai/frontman`.
- Recent production tasks after they have been idle for 30 minutes.

The worker is intentionally separate from `apps/frontman_server`. It reads the production database over the local Postgres connection and stores notification state in a DETS file under `FRONTMAN_NOTIFIER_STATE_DIR`.

## Runtime Environment

Required:

- `DATABASE_URL` or `FRONTMAN_NOTIFIER_DATABASE_URL` - local production Postgres URL.
- `DISCORD_STARGAZERS_WEBHOOK_URL` - Discord webhook for stargazer alerts.
- `DISCORD_TASK_SUMMARIES_WEBHOOK_URL` - Discord webhook for task summaries.

Optional:

- `GITHUB_TOKEN` - GitHub API token for higher rate limits.
- `FRONTMAN_NOTIFIER_GITHUB_REPOSITORY` - defaults to `frontman-ai/frontman`.
- `FRONTMAN_NOTIFIER_STATE_DIR` - defaults to `./var/frontman_notifier`.
- `FRONTMAN_NOTIFIER_CHECK_INTERVAL_MS` - defaults to one hour.
- `FRONTMAN_NOTIFIER_TASK_LOOKBACK_HOURS` - defaults to `24`.
- `FRONTMAN_NOTIFIER_TASK_IDLE_MINUTES` - defaults to `30`.
- `FRONTMAN_NOTIFIER_TASK_MAX_PER_RUN` - defaults to `20`.
- `FRONTMAN_NOTIFIER_GITHUB_STARGAZER_PAGES` - defaults to `3` pages of 100 stargazers.

On the first stargazer run, the worker records the current stargazer set without posting, so deployment does not spam historical stars. Task summaries do not baseline; eligible tasks from the last day are posted once and then marked as seen.

## Deployment

The production deployment is independent from the web server deployment:

- Workflow: `.github/workflows/deploy-notifier.yml`.
- Trigger paths: `apps/frontman_notifier/**`, `infra/production/notifier/**`, and the workflow file.
- Server root: `/opt/frontman-notifier`.
- Systemd unit: `frontman-notifier.service`.

Run `infra/production/notifier/setup.sh` once on the production server, then fill `/opt/frontman-notifier/env` with real Discord webhook URLs and an optional GitHub token. Pushes to `main` that touch the notifier path deploy the release automatically.
