# Disposable local Astra fixture

This fixture extends `scripts/test-wordpress-plugin-runtime.sh`.
It uses the existing Dockerfile, plugin package, database, and WooCommerce installation.
It does not create another stack or a root Make target.

The pinned dependencies are WordPress 7.0.2, WooCommerce 10.4.3, and Astra 4.12.3.
The runtime checks the official Astra ZIP against SHA-256:

```text
18b0b13f23b7ea793235b3ef8e9c62a032cff81646fca562aed2db2a83945a12
```

Astra 4.12.3 is a fixed synthetic baseline, not an assumption about the customer version.
The fixture does not reproduce a customer database, plugins, child theme, or Astra Pro.

## Requirements

Use the normal project toolchain, Composer dependency build, Docker or rootless Podman, and Playwright Chromium.
The existing client test infrastructure supplies Playwright.
The host needs a free loopback port, 8887 by default.

Install the project dependencies:

```sh
make install
```

## Start, check, and stop

Run the disposable fixture and browser acceptance test:

```sh
CONTAINER_RUNTIME=podman WORDPRESS_FIXTURE=astra make test-wordpress-runtime
```

For Docker, use `CONTAINER_RUNTIME=docker`.
The command removes its containers, image, network, and temporary directory after the test.
Screenshots remain in the ignored `dist/astra-fixture/` directory.
The Astra mode stops after the WooCommerce suites and browser test.
It does not run the later multisite, redirect, or Angie suites.
The normal runtime command still runs those suites.

For an interactive local site, keep the same command in a terminal:

```sh
CONTAINER_RUNTIME=podman WORDPRESS_FIXTURE=astra \
  WORDPRESS_FIXTURE_KEEP_ALIVE=1 WORDPRESS_FIXTURE_PORT=8887 \
  make test-wordpress-runtime
```

After the browser test passes, open:

- Shop: `http://127.0.0.1:8887/?post_type=product`
- Product: `http://127.0.0.1:8887/?product=amber`
- Cart: `http://127.0.0.1:8887/?pagename=synthetic-cart`
- Checkout: `http://127.0.0.1:8887/?pagename=synthetic-checkout`
- Frontman: `http://127.0.0.1:8887/frontman`

The runtime installs the native WordPress front controller in `.htaccess`.
Frontman routes require a real WordPress administrator login.
The automated test uses a private, random credential inside its disposable container.

For interactive use, set your own local admin password from a private Bash terminal.
Replace `CONTAINER` with the fixture container name printed at startup:

```bash
read -r -s -p 'New local WordPress admin password: ' PASSWORD
printf '\n'
printf '%s' "$PASSWORD" | podman exec -i CONTAINER php -r '
$password = stream_get_contents(STDIN);
if (strlen($password) < 16) { throw new RuntimeException("Use at least 16 characters."); }
require "/var/www/html/wp-load.php";
$admin = get_user_by("login", "admin");
if (!$admin) { throw new RuntimeException("Local admin was not found."); }
wp_set_password($password, $admin->ID);
echo "Local administrator password updated.\n";
'
unset PASSWORD
```

The command transfers the password through stdin, not command arguments or logs.
Use a unique password from your password manager.
Then log in as `admin` at `/wp-login.php`.
Open `/frontman` after login.
The password reset invalidates existing WordPress sessions.

The default plugin still loads the hosted client from `app.frontman.sh` and connects to `api.frontman.sh`.
This fixture does not bundle the current local client changes or select a local backend.
Hosted Frontman authentication is separate from the WordPress administrator login.
Chat requires an explicit backend/client choice and the appropriate service login.
The browser regression blocks nonlocal browser requests and checks the authenticated HTML shell, not the hosted application.

Press Ctrl+C in that terminal to stop the fixture.
Cleanup targets only the resource names from that run.
It removes the WordPress container before the database because Podman shares the database network namespace.
It does not prune images, volumes, networks, or containers from other runs.

For a port conflict, choose another `WORDPRESS_FIXTURE_PORT`.
For a failed browser test, read the error and restart the same command.
Each start creates a fresh database.

## Browser acceptance

The ReScript harness starts a new Chromium context without history cookies.
It visits two real product pages and adds a product through the storefront.
It never inserts a recently-viewed cookie.

The test checks these observable results:

1. The cart has no recently-viewed widget before product visits.
2. The native WooCommerce widget shows both products in the Astra WooCommerce sidebar.
3. The exclusion rule hides the widget on a real checkout form.
4. The cart retains the widget.
5. Reset restores the widget on checkout.
6. Products, categories, and both modes preserve the shop introduction.
7. Astra archive title layout 1 hides the native introduction independently of catalog mode.
8. Reset of that theme variation restores the introduction.

Tool mutations use the initialized Frontman registry through `sanitize_input` and `call` in a theme-loaded PHP process.
Storefront assertions and screenshots use real HTTP pages in Chromium.
The harness also checks an unauthenticated API rejection and the `/frontman` login redirect.
It completes the real WordPress login, then checks the authenticated page and HTTP tool discovery.
It does not exercise SSE mutations or chat.

The cold catalog path registers the two native WooCommerce settings directly.
It does not replay arbitrary theme `customize_register` hooks after frontend theme initialization.
An existing manager retains its registered settings.
Native capability, validation, sanitation, save hooks, and persistence checks still apply.

## Safety and retained state

The only published endpoint binds to `127.0.0.1`.
The database has no host port.
Credentials are ephemeral and are not printed.
The fixture uses synthetic virtual products and no payment gateway.
It disables WordPress email delivery and outbound WordPress HTTP after the base suites.
The base image has no mail transport.
No external analytics service is configured.
Downloads use official WordPress archives.

After success, the fixture retains products mode, unrestricted widget visibility, and the default archive title behavior.
The browser test closes its own session.
An interactive browser must visit product pages to create its own history.
Checkout requires a product in that browser's cart.
