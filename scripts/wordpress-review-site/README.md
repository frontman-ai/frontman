# Frontman reviewer site

This directory contains provisioning scripts for the approved synthetic site:
https://quiet-bat-1b8ea4.instawp.site/.

The site uses the production Frontman connection flow. It does not contain real
customers, payment credentials, or fulfillment integrations.

## Installed configuration

Configuration checked on November 9, 2026:

| Component | Version |
| --- | --- |
| WordPress | 7.1.4 |
| PHP | 8.5 |
| Frontman | 5.8.0 |
| WooCommerce | 11.2.2 |
| Elementor | 4.4.0 |
| Astra, active theme | 4.14.2 |

The original Twenty Twenty-Five theme remains installed.
WooCommerce uses legacy order storage. The seed supports both that storage and HPOS.
The InstaWP plan and expiry status still require a dashboard check.

## Safety

`safety.php` is installed as `wp-content/mu-plugins/frontman-review-safety.php`.
It blocks standard WordPress email through `pre_wp_mail` and removes registered
WooCommerce payment gateways.

Password-reset emails from this WordPress site are also blocked.
Use the authenticated InstaWP management tools for account maintenance.
These hooks do not block arbitrary network requests from other plugins.
Do not add real credentials, email services, or fulfillment integrations.
Do not deploy this MU plugin to a real store.

The option `frontman_review_before_setup` records the original theme, front-page
settings, indexing setting, active plugins, and checksums for original posts 1–3.
This record is not a database backup. No paid snapshot or backup add-on was purchased.

## Fixtures

| Fixture | ID | State |
| --- | --- | --- |
| Review About | 13 | Published |
| Review Gutenberg | 14 | Draft |
| Review Draft A | 15 | Draft post |
| Review Draft B | 16 | Draft post |
| Review Elementor | 17 | Draft |
| Review Notebook | 21 | Synthetic physical product |
| Review Ceramic Mug | 22 | Synthetic physical product |
| Review Canvas Tote | 23 | Synthetic physical product |
| Sample order | 24 | Pending |
| Sample order | 25 | On hold |
| Sample order | 26 | Completed, synthetic only |

`Review Landing` is not precreated. The reviewer creates it in the draft-creation case.
Order email addresses use `example.invalid`.
Search-engine indexing is discouraged. This setting is not access control.

Original posts 1–3 retain their titles, statuses, and content.
Setup-created duplicates 27–31 and temporary write-check page 39 are in trash.
They were not permanently deleted.

## Rerunning the seed

The seed adds missing fixtures. It does not reset existing fixtures or overwrite
their content. It stops on duplicate markers, incomplete orders, or trashed
marked posts. Resetting a reviewer session is a separate, deliberate operation.

1. Authenticate the official InstaWP CLI through its browser login.
2. Upload `seed.php` to a private temporary file through SSH.
3. Run `php -l` against that file.
4. Run `wp eval-file` through the SSH transport with `--user=1`.

Use the same SSH transport for upload and execution. InstaWP's API runner and SSH
runner do not share `/tmp`. API commands also have a 1,000-character limit.
The seed refuses any hostname other than the approved site.

Do not retrieve or print stored credentials. Keep provider authentication outside
the repository, transcript, and recording.

## Checks completed

- Remote PHP syntax check for the seed.
- Seed rerun returned the same fixture IDs after correcting marker lookup.
- Original post titles, statuses, and content checksums matched the saved baseline.
- Public HTTPS access to Review About returned its expected content.
- Unauthenticated Frontman tool discovery returned HTTP 403.
- Authenticated HTTPS discovery returned 190 tools with the three required boolean hints.
- Authenticated HTTPS calls listed draft posts, read Review About, and returned three products and three orders.
- An authenticated HTTPS call created a temporary draft and read its exact content back.
- The temporary draft was moved to trash, and both temporary validation credentials were revoked.
- Email suppression, empty gateway registration, Elementor data, and draft status were checked.

These are direct WordPress endpoint checks, not ChatGPT or hosted MCP acceptance.
The production reviewer-account connection, OpenAI scan, eight conversational
cases, and walkthrough recording still need their own evidence.
