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
	private const RUNTIME_SCRIPT_HANDLE   = 'frontman-agentic-ai-editor-runtime';
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
		$menu_icon_url = FRONTMAN_PLUGIN_URL . 'assets/frontman-menu-icon.svg';

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
		wp_register_style( self::ADMIN_MENU_STYLE_HANDLE, false, [], FRONTMAN_VERSION );
		wp_enqueue_style( self::ADMIN_MENU_STYLE_HANDLE );
		wp_add_inline_style( self::ADMIN_MENU_STYLE_HANDLE, $this->get_admin_menu_icon_css() );
	}

	/**
	 * Build admin menu icon CSS for wp_add_inline_style().
	 */
	private function get_admin_menu_icon_css(): string {
		$default_icon = $this->get_menu_icon_data_uri( '#a7aaad' );
		$active_icon  = $this->get_menu_icon_data_uri( '#ffffff' );

		return sprintf(
			'#adminmenu .toplevel_page_frontman .wp-menu-image img{display:none;}#adminmenu .toplevel_page_frontman .wp-menu-image{background-image:url("%1$s") !important;background-position:center;background-repeat:no-repeat;background-size:16px 16px;}#adminmenu .toplevel_page_frontman:hover .wp-menu-image,#adminmenu .toplevel_page_frontman.current .wp-menu-image,#adminmenu .toplevel_page_frontman.wp-has-current-submenu .wp-menu-image{background-image:url("%2$s") !important;}',
			esc_attr( $default_icon ),
			esc_attr( $active_icon )
		);
	}

	/**
	 * Build a base64 menu icon data URI for the requested fill color.
	 *
	 * @param string $fill Hex fill color.
	 */
	private function get_menu_icon_data_uri( string $fill ): string {
		$svg = sprintf(
			'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="90 70 230 270" fill="none"><path d="M145.925 316.925C136.175 316.925 129.242 315.517 125.125 312.7C121.008 309.667 118.517 305.875 117.65 301.325C116.783 296.558 116.35 291.792 116.35 287.025V119C116.35 107.733 118.517 100.042 122.85 95.925C127.4 91.5917 135.417 89.425 146.9 89.425H265.85C270.833 89.425 275.492 89.8583 279.825 90.725C284.375 91.5917 288.058 94.0833 290.875 98.2C293.692 102.317 295.1 109.358 295.1 119.325C295.1 129.075 293.583 136.008 290.55 140.125C287.733 144.242 284.05 146.733 279.5 147.6C274.95 148.467 270.183 148.9 265.2 148.9H175.825V177.825H235.625C240.608 177.825 245.05 178.258 248.95 179.125C253.067 179.775 256.208 181.942 258.375 185.625C260.758 189.092 261.95 195.158 261.95 203.825C261.95 212.058 260.758 217.908 258.375 221.375C255.992 224.842 252.742 226.9 248.625 227.55C244.725 228.2 240.283 228.525 235.3 228.525H175.825V287.35C175.825 292.117 175.392 296.775 174.525 301.325C173.658 305.875 171.167 309.667 167.05 312.7C162.933 315.517 155.892 316.925 145.925 316.925Z" fill="%s"/></svg>',
			$fill
		);

		return 'data:image/svg+xml;base64,' . base64_encode( $svg );
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

		// Inline runtime config — same shape as FrontmanCore__UIShell produces
		// for Frontman browser clients. The client reads window.__frontmanRuntime.
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

		$this->enqueue_frontman_page_assets( $client_url, $client_css, $runtime );

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
	<?php wp_print_scripts( [ self::RUNTIME_SCRIPT_HANDLE, self::CLIENT_SCRIPT_HANDLE ] ); ?>
</body>
</html>
		<?php
	}

	/**
	 * Enqueue the standalone Frontman page assets before printing them manually.
	 */
	private function enqueue_frontman_page_assets( string $client_url, string $client_css, array $runtime ): void {
		wp_register_style( self::PAGE_STYLE_HANDLE, false, [], FRONTMAN_VERSION );
		wp_enqueue_style( self::PAGE_STYLE_HANDLE );
		wp_add_inline_style( self::PAGE_STYLE_HANDLE, $this->get_frontman_page_css() );

		if ( '' !== $client_css ) {
			wp_enqueue_style( self::CLIENT_STYLE_HANDLE, $client_css, [], FRONTMAN_VERSION );
		}

		$runtime_json = wp_json_encode( $runtime );
		if ( ! is_string( $runtime_json ) ) {
			$runtime_json = '{}';
		}

		wp_register_script( self::RUNTIME_SCRIPT_HANDLE, '', [], FRONTMAN_VERSION, true );
		wp_enqueue_script( self::RUNTIME_SCRIPT_HANDLE );
		wp_add_inline_script( self::RUNTIME_SCRIPT_HANDLE, 'window.__frontmanRuntime=' . $runtime_json . ';', 'before' );
		wp_add_inline_script( self::RUNTIME_SCRIPT_HANDLE, 'if(typeof process==="undefined"){window.process={env:{NODE_ENV:"production"}}}', 'before' );
		wp_add_inline_script( self::RUNTIME_SCRIPT_HANDLE, $this->get_warning_script() );

		wp_enqueue_script( self::CLIENT_SCRIPT_HANDLE, $client_url, [ self::RUNTIME_SCRIPT_HANDLE ], FRONTMAN_VERSION, true );
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

	/**
	 * Build standalone page CSS for wp_add_inline_style().
	 */
	private function get_frontman_page_css(): string {
		return 'html,body,#root{height:100%;margin:0;padding:0;}#frontman-warning-overlay{position:fixed;inset:0;background:rgba(10,12,16,.74);display:flex;align-items:center;justify-content:center;padding:24px;z-index:99999;}#frontman-warning-card{max-width:560px;width:100%;background:#10151d;color:#f5f7fa;border:1px solid rgba(255,196,87,.25);border-radius:16px;box-shadow:0 18px 60px rgba(0,0,0,.45);padding:24px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;}#frontman-warning-card h2{margin:0;font-size:24px;line-height:1.2;}#frontman-warning-heading{display:flex;align-items:center;gap:14px;margin:0 0 12px;}#frontman-warning-heading img{width:42px;height:42px;border-radius:12px;flex:0 0 auto;}#frontman-warning-card p{margin:0 0 14px;font-size:15px;line-height:1.6;color:#d9e1ea;}#frontman-warning-card ul{margin:0 0 18px 20px;padding:0;color:#d9e1ea;}#frontman-warning-card li{margin-bottom:8px;line-height:1.5;}#frontman-warning-card button{background:#ffc857;color:#1e2329;border:0;border-radius:10px;padding:11px 16px;font-size:14px;font-weight:600;cursor:pointer;}';
	}

	/**
	 * Build the first-run warning behavior for wp_add_inline_script().
	 */
	private function get_warning_script(): string {
		return '(function(){var storageKey="frontman-wordpress-warning-dismissed-v1";var overlay=document.getElementById("frontman-warning-overlay");var button=document.getElementById("frontman-warning-dismiss");if(!overlay||!button){return;}try{if(window.localStorage&&window.localStorage.getItem(storageKey)==="true"){return;}}catch(e){}overlay.hidden=false;button.addEventListener("click",function(){try{if(window.localStorage){window.localStorage.setItem(storageKey,"true");}}catch(e){}overlay.hidden=true;});})();';
	}
}
