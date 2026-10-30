# Security exceptions

Owner: server maintainers. Review CSP and Hex exceptions by 2026-12-01, or before changes to affected code.
This deadline is not enforced automatically.

## Sobelow

`.sobelow-skips` accepts only these findings:

| Location | Reason and constraint |
| --- | --- |
| `config/prod.exs`: HTTPS | Caddy enforces HTTPS. IPv4/IPv6 firewalls block public backend ports, but permit tailnet access. |
| `config/e2e.exs`: HSTS and four secrets | Isolated test fixtures. Never expose E2E or reuse its credentials in production. Its database can contain real OAuth tokens. |
| `endpoint.ex:19`: `/live` | Inherits the production origin allowlist. All allowed subdomains must remain trusted. |
| `endpoint.ex:24`: `/socket` | Requires a bearer token bound to the actual handshake origin. Rejects forged, missing, duplicate, and mismatched origins. |
| `endpoint.ex:53`: live reload | Development-only. Production must disable code reloading. |
| `router.ex:18`: CSP (temporary) | Phoenix supplies only `base-uri 'self'; frame-ancestors 'self'`. |

CSP follow-up: add report-only restrictions, address inline styles, exercise browser flows, then enforce the policy and delete its exception.
Cover login, OAuth, popup approval, LiveView, settings, billing returns, and HTML errors.

Production Caddy changes add one-year HSTS after deployment.
Check successful, redirect, and error responses after deployment and rollback.

Review exceptions with `mix sobelow --no-config --exit`.
The normal gate uses `mix sobelow --config --exit`.
Fingerprints do not include secret values. Review changes at accepted locations even if CI passes.

## Hex

CI installs the latest compatible Hex because older versions can silently skip advisory checks.
No fixed Hex releases existed at review. `mix.exs` acknowledges only these IDs:

| Advisory | Reason |
| --- | --- |
| [EEF-CVE-2026-95105](https://osv.dev/vulnerability/EEF-CVE-2026-95105) | Vault uses AES-GCM, not affected AES-CTR. |
| [EEF-CVE-2026-94206](https://osv.dev/vulnerability/EEF-CVE-2026-94206) | Uses `Cloak.Ecto.Binary`, not affected PBKDF2. |
| [EEF-CVE-2026-43966](https://osv.dev/vulnerability/EEF-CVE-2026-43966) | Cowlib is test-only through Bypass, absent from the production dependency tree. |

At review, check fixed releases, cipher/type usage, and `mix deps.tree --only prod --format plain`.
Upgrade and delete acknowledgments when fixes become available.
