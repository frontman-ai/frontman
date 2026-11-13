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

At review, check fixed releases, cipher/type usage, and `mix deps.tree --only prod --format plain`.
Upgrade and delete acknowledgments when fixes become available.

## Temporary test-only Git pins

As of 2026-11-06, the latest Hex releases are Cowboy 2.20.0 and Cowlib 2.21.0.
Both have memory-exhaustion advisories without fixed Hex releases.
The test dependency tree uses these upstream fixes instead:

| Dependency | Pinned fix | Advisory |
| --- | --- | --- |
| Cowboy | [`3a630c07`](https://github.com/ninenines/cowboy/commit/3a630c07e1521abf63a1b9ea080509aa1337b60d): stop buffering pipelined HTTP/1 data during an active request | EEF-CVE-2026-115701 |
| Cowlib | [`a3b15e29`](https://github.com/ninenines/cowlib/commit/a3b15e29b3067644bfd580246c87f7af7a90b3b8): enforce the decoded HTTP/2 header-list size limit | EEF-CVE-2026-113431 |

The overrides apply only to tests through Bypass. Production uses Bandit.
The Ranch override preserves the existing Hex release, 1.8.1, instead of the Git source requested by Cowboy.

Hex does not audit Git dependencies. A successful Hex audit alone does not validate these pins.
The HTTP security regression tests exercise both fixes against the actual protocol implementations.
The previous test-only Cowlib acknowledgment, EEF-CVE-2026-43966, no longer matches a Hex dependency and is removed from `ignore_advisories`.
Its production-exclusion rationale still applies.

When fixed Hex releases become available, replace the Git pins and remove the temporary Ranch override.
Run the security audit and HTTP security regression tests.
Check that Cowboy, Cowlib, and Ranch remain absent from the production dependency tree.
