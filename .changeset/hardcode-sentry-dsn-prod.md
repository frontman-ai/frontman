---
---

Hardcode Sentry DSN in prod config and remove SENTRY_DSN env var. Sentry is now only configured in the production environment, simplifying deployment by eliminating the need for a runtime environment variable.
