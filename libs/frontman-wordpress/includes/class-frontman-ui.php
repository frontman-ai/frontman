<?php
/**
 * UI — serves the Frontman client at /frontman.
 *
 * This page is served directly by the router's parse_request interception,
 * not via wp-admin. The client JS fetches /frontman/tools and
 * /frontman/tools/call at the same origin as the WordPress site.
 *
 * Auth is already verified by the router before render_page() is called.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_UI {
	private const ADMIN_MENU_STYLE_HANDLE = 'frontman-agentic-ai-editor-admin-menu';
	private const PAGE_STYLE_HANDLE       = 'frontman-agentic-ai-editor-page';
	private const PAGE_SCRIPT_HANDLE      = 'frontman-agentic-ai-editor-page-script';
	private const CLIENT_STYLE_HANDLE     = 'frontman-agentic-ai-editor-client';
	private const CLIENT_SCRIPT_HANDLE    = 'frontman-agentic-ai-editor-client';

	/**
	 * Register admin menu items.
	 *
	 * We keep a menu entry so admins can find Frontman in the sidebar,
	 * but it links to /frontman (the direct path) rather than a wp-admin page.
	 */
	public function register(): void {
		add_action( 'admin_menu', [ $this, 'add_admin_menu_link' ] );
		add_action( 'admin_enqueue_scripts', [ $this, 'enqueue_admin_assets' ] );
	}

	/**
	 * Load branded admin menu icon styling.
	 *
	 * @param string $hook_suffix Current admin page hook suffix.
	 */
	public function enqueue_admin_assets( string $hook_suffix ): void {
		unset( $hook_suffix );
		$this->enqueue_admin_menu_icon_style();
	}

	/**
	 * Add a menu link that points to /frontman (external to wp-admin).
	 */
	public function add_admin_menu_link(): void {
		$menu_icon_url = esc_url( FRONTMAN_PLUGIN_URL . 'assets/frontman-menu-icon.svg' );

		add_menu_page(
			__( 'Frontman', 'frontman-agentic-ai-editor' ),
			__( 'Frontman', 'frontman-agentic-ai-editor' ),
			'manage_options',
			'frontman',
			'__return_null', // Callback unused — we redirect below.
			$menu_icon_url,
			81,
		);

		// Redirect the wp-admin menu click to /frontman.
		add_action( 'load-toplevel_page_frontman', function (): void {
			wp_safe_redirect( home_url( '/frontman' ) );
			exit;
		} );
	}

	/**
	 * Enqueue admin menu icon styling so the Frontman icon matches
	 * the native WordPress admin menu color scheme without raw style tags.
	 */
	private function enqueue_admin_menu_icon_style(): void {
		wp_enqueue_style(
			self::ADMIN_MENU_STYLE_HANDLE,
			FRONTMAN_PLUGIN_URL . 'assets/frontman-admin-menu.css',
			[],
			FRONTMAN_VERSION
		);
	}

	/**
	 * Render the full Frontman client page.
	 *
	 * Called directly by the router — this outputs a complete HTML document
	 * (no wp-admin chrome). The client is loaded from the production CDN.
	 *
	 * @param string|null $preview_path Path to load in the web preview iframe.
	 *                                  null or '/' means homepage. '/about' previews /about.
	 *                                  Set by suffix-based routing: /about/frontman → '/about'.
	 */
	public function render_page( ?string $preview_path = null ): void {
		$logo_url    = FRONTMAN_PLUGIN_URL . 'assets/frontman-logo.svg';
		$host        = 'api.frontman.sh';
		$base_js_url = 'https://app.frontman.sh/frontman.es.js';
		$client_css  = 'https://app.frontman.sh/frontman.css';

		// The client reads host + clientName from import.meta.url query params.
		// This is how all Frontman adapters pass the Frontman server host to the client bundle.
		$client_url = add_query_arg(
			[
				'host'       => $host,
				'clientName' => 'wordpress',
			],
			$base_js_url
		);

		// Runtime config — same shape as FrontmanCore__UIShell produces
		// for Frontman browser clients. The page script reads this into window.__frontmanRuntime.
		// basePath is used by Client__BrowserUrl.syncBrowserUrl() to keep the
		// browser URL in sync as the user navigates within the preview iframe.
		$runtime = [
			'framework' => 'wordpress',
			'basePath'  => 'frontman',
			'wpNonce'   => Frontman_Auth::create_nonce(),
		];

		// Build the entrypoint URL for the web preview iframe.
		// When suffix routing is used (e.g. /about/frontman), this points the
		// preview at /about. The client reads this from the DOM via getInitialUrl().
		$entrypoint_url = null;
		if ( $preview_path !== null && $preview_path !== '/' ) {
			$entrypoint_url = home_url( $preview_path );
		}

		$this->enqueue_frontman_page_assets( $client_url, $client_css );

		status_header( 200 );
		header( 'Content-Type: text/html; charset=utf-8' );
		?>
<!DOCTYPE html>
<html lang="en" class="dark">
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title><?php esc_html_e( 'Frontman', 'frontman-agentic-ai-editor' ); ?></title>
		<link rel="icon" type="image/svg+xml" href="<?php echo esc_url( $logo_url ); ?>">
		<?php wp_print_styles( [ self::PAGE_STYLE_HANDLE, self::CLIENT_STYLE_HANDLE ] ); ?>
</head>
	<body>
	<div
		id="frontman-runtime-config"
		hidden
		data-framework="<?php echo esc_attr( $runtime['framework'] ); ?>"
		data-base-path="<?php echo esc_attr( $runtime['basePath'] ); ?>"
		data-wp-nonce="<?php echo esc_attr( $runtime['wpNonce'] ); ?>"
	></div>
	<?php if ( $entrypoint_url ) : ?>
	<span id="frontman-entrypoint-url" hidden><?php echo esc_url( $entrypoint_url ); ?></span>
	<?php endif; ?>
	<div id="frontman-warning-overlay" hidden>
		<div id="frontman-warning-card" role="dialog" aria-modal="true" aria-labelledby="frontman-warning-title">
			<div id="frontman-warning-heading">
				<img src="<?php echo esc_url( $logo_url ); ?>" alt="" aria-hidden="true">
				<h2 id="frontman-warning-title"><?php esc_html_e( 'Use Frontman Carefully', 'frontman-agentic-ai-editor' ); ?></h2>
			</div>
			<p><?php esc_html_e( 'Frontman for WordPress is experimental. The agent can change real content, templates, styles, menus, widgets, and settings on your site.', 'frontman-agentic-ai-editor' ); ?></p>
			<ul>
				<li><?php esc_html_e( 'Make sure you have a current backup before using it on an important site.', 'frontman-agentic-ai-editor' ); ?></li>
				<li><?php esc_html_e( 'Review each change carefully. The agent may not always do exactly what you intended.', 'frontman-agentic-ai-editor' ); ?></li>
				<li><?php esc_html_e( 'When possible, start on a staging site first.', 'frontman-agentic-ai-editor' ); ?></li>
			</ul>
			<button type="button" id="frontman-warning-dismiss"><?php esc_html_e( 'I Understand', 'frontman-agentic-ai-editor' ); ?></button>
		</div>
	</div>
	<div id="root"></div>
	<?php wp_print_scripts( [ self::PAGE_SCRIPT_HANDLE, self::CLIENT_SCRIPT_HANDLE ] ); ?>
</body>
</html>
		<?php
	}

	/**
	 * Enqueue the standalone Frontman page assets before printing them manually.
	 */
	private function enqueue_frontman_page_assets( string $client_url, string $client_css ): void {
		wp_enqueue_style(
			self::PAGE_STYLE_HANDLE,
			FRONTMAN_PLUGIN_URL . 'assets/frontman-page.css',
			[],
			FRONTMAN_VERSION
		);

		if ( '' !== $client_css ) {
			wp_enqueue_style( self::CLIENT_STYLE_HANDLE, $client_css, [], FRONTMAN_VERSION );
		}

		wp_enqueue_script(
			self::PAGE_SCRIPT_HANDLE,
			FRONTMAN_PLUGIN_URL . 'assets/frontman-page.js',
			[],
			FRONTMAN_VERSION,
			true
		);

		wp_enqueue_script( self::CLIENT_SCRIPT_HANDLE, $client_url, [ self::PAGE_SCRIPT_HANDLE ], FRONTMAN_VERSION, true );
		add_filter( 'script_loader_tag', [ $this, 'add_module_type_to_client_script' ], 10, 3 );
	}

	/**
	 * Mark the Frontman client bundle as a JavaScript module.
	 */
	public function add_module_type_to_client_script( string $tag, string $handle, string $src ): string {
		if ( self::CLIENT_SCRIPT_HANDLE !== $handle ) {
			return $tag;
		}

		return sprintf(
			'<scr' . 'ipt type="module" src="%1$s" id="%2$s-js"></scr' . 'ipt>' . "\n",
			esc_url( $src ),
			esc_attr( $handle )
		);
	}

}
