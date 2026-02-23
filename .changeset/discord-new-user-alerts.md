---
"@frontman/frontman-server-assets": patch
---

Add Discord alerts for new user signups. A PostgreSQL AFTER INSERT trigger on the users table fires pg_notify, which a new Elixir GenServer listens to via Postgrex.Notifications and posts a rich embed to a Discord webhook. Enabled via DISCORD_NEW_USERS_WEBHOOK_URL env var.
