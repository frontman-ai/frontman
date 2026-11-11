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

declare(strict_types=1);

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
		add_action( 'wp_enqueue_scripts', [ $this, 'enqueue_preview_bridge' ] );
		add_action( 'admin_notices', [ $this, 'welcome_notice' ] );
		add_action( 'admin_post_frontman_dismiss_welcome', [ $this, 'dismiss_welcome' ] );
		add_filter( 'plugin_action_links_' . plugin_basename( FRONTMAN_PLUGIN_FILE ), [ $this, 'plugin_action_links' ] );
		add_filter( 'network_admin_plugin_action_links_' . plugin_basename( FRONTMAN_PLUGIN_FILE ), [ $this, 'plugin_action_links' ] );
	}

	/**
	 * Record first activation without resetting existing dismissals.
	 * Network activation uses one network marker instead of iterating over sites.
	 */
	public static function activate( bool $network_wide = false ): void {
		if ( is_multisite() && $network_wide ) {
			add_site_option( 'frontman_welcome_activated', 1 );
		} else {
			add_option( 'frontman_welcome_activated', 1, '', false );
		}
	}

	public function welcome_notice(): void {
		$network_plugins = is_multisite() ? (array) get_site_option( 'active_sitewide_plugins', [] ) : [];
		$network_active = isset( $network_plugins[ plugin_basename( FRONTMAN_PLUGIN_FILE ) ] );
		if ( ! current_user_can( 'manage_options' )
			|| get_user_option( 'frontman_welcome_dismissed' )
			|| ( ! get_option( 'frontman_welcome_activated' ) && ! ( $network_active && get_site_option( 'frontman_welcome_activated' ) ) )
		) {
			return;
		}
		?>
		<div class="notice notice-info">
			<h2><?php esc_html_e( 'Frontman is active. Start here.', 'frontman-agentic-ai-editor' ); ?></h2>
			<p><?php esc_html_e( 'Sign in to Frontman and connect an AI provider, then open a page in the live preview and describe your change. Provider charges may apply.', 'frontman-agentic-ai-editor' ); ?></p>
			<p><?php esc_html_e( 'Frontman can change your live site. Make a current backup and use staging for higher-risk changes.', 'frontman-agentic-ai-editor' ); ?></p>
			<p><a class="button button-primary" href="<?php echo esc_url( self::url( '/frontman' ) ); ?>"><?php esc_html_e( 'Open Frontman', 'frontman-agentic-ai-editor' ); ?></a></p>
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="frontman_dismiss_welcome">
				<?php wp_nonce_field( 'frontman_dismiss_welcome' ); ?>
				<p><button class="button" type="submit"><?php esc_html_e( 'Dismiss welcome', 'frontman-agentic-ai-editor' ); ?></button></p>
			</form>
		</div>
		<?php
	}

	public function dismiss_welcome(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You cannot dismiss this notice.', 'frontman-agentic-ai-editor' ), '', [ 'response' => 403 ] );
		}
		check_admin_referer( 'frontman_dismiss_welcome' );
		update_user_option( get_current_user_id(), 'frontman_welcome_dismissed', 1 );
		wp_safe_redirect( admin_url( 'plugins.php' ) );
		exit;
	}

	public function plugin_action_links( array $links ): array {
		if ( current_user_can( 'manage_options' ) ) {
			array_unshift( $links, '<a href="' . esc_url( self::url( '/frontman' ) ) . '">' . esc_html__( 'Open Frontman', 'frontman-agentic-ai-editor' ) . '</a>' );
		}
		return $links;
	}

	public function enqueue_preview_bridge(): void {
		Frontman_Sentry::boundary( 'wp_enqueue_scripts', function (): void {
			$this->enqueue_preview_bridge_assets();
		} );
	}

	private function enqueue_preview_bridge_assets(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			return;
		}
		wp_enqueue_script(
			'frontman-preview-bridge',
			FRONTMAN_PLUGIN_URL . 'assets/bridge.js',
			[],
			FRONTMAN_VERSION,
			true
		);
	}

	/**
	 * Load branded admin menu icon styling.
	 *
	 * @param string $hook_suffix Current admin page hook suffix.
	 */
	public function enqueue_admin_assets( string $hook_suffix ): void {
		Frontman_Sentry::boundary( 'admin_enqueue_scripts', function () use ( $hook_suffix ): void {
			unset( $hook_suffix );
			$this->enqueue_admin_menu_icon_style();
		} );
	}

	/**
	 * Add a menu link that points to /frontman (external to wp-admin).
	 */
	public function add_admin_menu_link(): void {
		Frontman_Sentry::boundary( 'admin_menu', function (): void {
			$this->register_admin_menu_link();
		} );
	}

	private function register_admin_menu_link(): void {
		$menu_icon_url = esc_url( FRONTMAN_PLUGIN_URL . 'assets/frontman-menu-icon.svg' );

		add_menu_page(
			__( 'Frontman', 'frontman-agentic-ai-editor' ),
			__( 'Frontman', 'frontman-agentic-ai-editor' ),
			'manage_options',
			'frontman',
			'__return_null',
			$menu_icon_url,
			3,
		);

		add_action( 'load-toplevel_page_frontman', function (): void {
			Frontman_Sentry::boundary( 'load-toplevel_page_frontman', static function (): void {
				wp_safe_redirect( self::url( '/frontman' ) );
				exit;
			} );
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
	 * (no wp-admin chrome). The client defaults to the production CDN.
	 *
	 * @param string|null $preview_path Path to load in the web preview iframe.
	 *                                  null or '/' means homepage. '/about' previews /about.
	 *                                  Set by suffix-based routing: /about/frontman → '/about'.
	 */
	public function render_page( ?string $preview_path = null ): void {
		$logo_url    = FRONTMAN_PLUGIN_URL . 'assets/frontman-logo.svg';
		$host        = defined( 'FRONTMAN_HOST' ) ? FRONTMAN_HOST : 'api.frontman.sh';
		$base_js_url = defined( 'FRONTMAN_CLIENT_URL' ) ? FRONTMAN_CLIENT_URL : 'https://app.frontman.sh/frontman.es.js';
		$client_css  = defined( 'FRONTMAN_CLIENT_CSS' ) ? FRONTMAN_CLIENT_CSS : 'https://app.frontman.sh/frontman.css';

		$client_url = add_query_arg(
			[
				'host'       => $host,
				'clientName' => 'wordpress',
			],
			$base_js_url
		);

		$runtime = [
			'framework'    => 'wordpress',
			'basePath'     => 'frontman',
			'relayBaseUrl' => self::url( '' ),
			'wpNonce'      => Frontman_Auth::create_nonce(),
			'wordpressPluginsUrl' => network_admin_url( 'plugins.php' ),
			'wordpressSettingsUrl' => admin_url( 'options-general.php?page=frontman-diagnostics' ),
			'wordpressLoginUrl' => wp_login_url( self::url( '/frontman' ) ),
		];

		$entrypoint_url = null;
		if ( $preview_path !== null && $preview_path !== '/' ) {
			$entrypoint_url = home_url( $preview_path );
		}

		$this->enqueue_frontman_page_assets( $client_url, $client_css );

		status_header( 200 );
		nocache_headers();
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
		data-preview-bridge="page-context-v1"
		data-framework="<?php echo esc_attr( $runtime['framework'] ); ?>"
		data-base-path="<?php echo esc_attr( $runtime['basePath'] ); ?>"
		data-relay-base-url="<?php echo esc_attr( $runtime['relayBaseUrl'] ); ?>"
		data-wp-nonce="<?php echo esc_attr( $runtime['wpNonce'] ); ?>"
		data-wordpress-plugins-url="<?php echo esc_url( $runtime['wordpressPluginsUrl'] ); ?>"
		data-wordpress-settings-url="<?php echo esc_url( $runtime['wordpressSettingsUrl'] ); ?>"
		data-wordpress-login-url="<?php echo esc_url( $runtime['wordpressLoginUrl'] ); ?>"
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
			<p><?php esc_html_e( 'Frontman for WordPress is production-ready. The agent can change real content, templates, styles, menus, widgets, and settings on your site.', 'frontman-agentic-ai-editor' ); ?></p>
			<ul>
				<li><?php esc_html_e( 'Make sure you have a current backup before using it on an important site.', 'frontman-agentic-ai-editor' ); ?></li>
				<li><?php esc_html_e( 'Review each change carefully. The agent may not always do exactly what you intended.', 'frontman-agentic-ai-editor' ); ?></li>
				<li><?php esc_html_e( 'Use a staging site for higher-risk changes.', 'frontman-agentic-ai-editor' ); ?></li>
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
	 * Return a Frontman URL for the active permalink mode.
	 */
	public static function url( string $path ): string {
		$permalink_structure = (string) get_option( 'permalink_structure' );
		$front_controller = '' === $permalink_structure || 0 === strpos( $permalink_structure, '/index.php' ) ? '/index.php' : '';
		return home_url( $front_controller . $path );
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
