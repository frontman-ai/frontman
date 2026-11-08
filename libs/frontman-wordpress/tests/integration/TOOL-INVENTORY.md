# WordPress tool inventory

## Evidence

The runtime inventory matches all **202 production WordPress tool names** found
in the source registrations. The union covers multiple configurations, not one
installation with every integration active.

The hosted server adds `list_sites`, for **203 potential production names**.
This report does not certify their annotations, behavior, or hosted availability
across all configurations.

The successful inventory run used:

```sh
YOAST_VERSION=28.4 make test-wordpress-runtime
```

Environment: WordPress 7.0.2, PHP 8.4.27, Frontman 5.7.0.
This run used the PHP suite without the optional hosted SDK checks.

The existing runtime cases emit `FRONTMAN_INVENTORY` JSON records. Each record
contains the checkpoint, WordPress/PHP versions, active plugin versions, and
sorted names from the actual singleton registry.

The source comparison includes literal constructor names, Redirection array
keys, WooCommerce helper arguments, and its nine generated metadata operations.
All 202 names occurred in the runtime union. No production names were missing.
The only extra name was `wp_test_diagnostics`, registered by
`SentryRuntimeFixture.php`, not production code.

## Observed configurations

Counts below exclude that fixture-only tool. Every configuration includes
Elementor 3.18.3, Frontman 5.7.0, and Max Mega Menu 3.10.7.

| Checkpoint | Additional active integrations | Production names |
|---|---|---:|
| Baseline | Yoast 28.4 | 81 |
| Code Snippets | Yoast 28.4, Code Snippets 4.0.0 | 83 |
| Polylang | Yoast 28.4, Polylang 3.8.3 | 81 |
| Super Cache | Yoast 28.4, WP Super Cache 3.0.3 | 81 |
| Directorist | Yoast 28.4, Directorist 8.10.6 | 82 |
| SEO coexistence | Yoast 28.4, SureRank 1.10.2 | 79 |
| SureRank | SureRank 1.10.2, without Yoast | 80 |
| WooCommerce | Yoast 28.4, WooCommerce 10.4.3 | 192 |
| 301 Redirects | Yoast 28.4, WebFactory 301 Redirects 1.05 | 84 |
| Redirect coexistence | Yoast 28.4, 301 Redirects 1.05, Redirection 5.10.0 | 87 |
| Angie, each version | Previous row plus Angie 1.1.0 or 1.1.16 | 88 |

WooCommerce contributed exactly 111 names. Code Snippets contributed two,
Directorist one, each redirect adapter three, and Angie one.
Polylang and cache tools were already registered in the baseline.
Yoast exposed both SEO tools; SureRank exposed only the reader.
The SEO coexistence configuration exposed neither.

## Hosted verification remains separate

The SDK-enabled runtime run passed the discovery, invalid-catalog, outage,
selected-site execution, and recovery scenario before WooCommerce activation.
The later WooCommerce SDK run failed with a database sandbox connection error
after discovery cancellation. It did not establish hosted parity for every
configuration above.

No generated catalog is used in production. These records are test evidence.
