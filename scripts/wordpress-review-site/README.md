# Frontman reviewer site

These scripts support only the synthetic reviewer site:
https://quiet-bat-1b8ea4.instawp.site/.

## Safety

Never install `safety.php` on a real store. It blocks standard WordPress email,
including password resets, and removes registered WooCommerce payment gateways.
It does not block arbitrary network requests. Use sample data only.
Keep credentials outside the repository, transcript, and recording.

## Seed the site

1. Activate WooCommerce and Elementor.
2. Install `safety.php` as `wp-content/mu-plugins/frontman-review-safety.php`.
3. Authenticate the official InstaWP CLI through its browser login.
4. Upload `seed.php` to a private temporary file through SSH.
5. Run `php -l` against that file.
6. Run `wp eval-file` with `--user=1` through the same SSH transport.

The API and SSH runners do not share `/tmp`. The seed checks the hostname and
administrator permissions. It supports legacy order storage and HPOS.
Reruns add missing fixtures without resetting existing content. Duplicate markers,
incomplete orders, and trashed marked posts require manual resolution.
