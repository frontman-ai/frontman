<?php
/** Frontman administrator settings, shared by diagnostics and MCP access. */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Settings {
	public static function register(): void {
		add_action( 'admin_init', [ self::class, 'register_setting' ] );
		add_action( 'admin_menu', static function (): void {
			Frontman_Sentry::boundary( 'diagnostics_admin_menu', static function (): void {
				add_options_page( 'Frontman', 'Frontman', 'manage_options', 'frontman-diagnostics', [ self::class, 'render_settings' ] );
			} );
		} );
	}

	public static function register_setting(): void {
		Frontman_Sentry::boundary( 'admin_init', [ self::class, 'register_options' ] );
	}

	public static function register_options(): void {
		foreach ( [ 'frontman_php_diagnostics', 'frontman_auth_diagnostics', 'frontman_mcp_enabled' ] as $option ) {
			register_setting( 'frontman_diagnostics', $option, [
				'type' => 'boolean',
				'default' => false,
				'sanitize_callback' => [ Frontman_Sentry::class, 'sanitize_enabled' ],
			] );
		}
	}

	public static function render_settings(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'Administrator access required.', 'frontman-agentic-ai-editor' ) );
			return;
		}
		Frontman_Sentry::boundary( 'diagnostics_settings', [ self::class, 'render_settings_form' ] );
	}

	public static function render_settings_form(): void {
		?>
		<div class="wrap">
			<h1><?php esc_html_e( 'Frontman Settings', 'frontman-agentic-ai-editor' ); ?></h1>
			<form action="options.php" method="post">
				<?php settings_fields( 'frontman_diagnostics' ); ?>
				<input type="hidden" name="frontman_mcp_enabled" value="0">
				<label>
					<input type="checkbox" name="frontman_mcp_enabled" value="1" <?php checked( Frontman_Sentry::sanitize_enabled( get_option( 'frontman_mcp_enabled', false ) ) ); ?>>
					<?php esc_html_e( 'Allow MCP connections', 'frontman-agentic-ai-editor' ); ?>
				</label>
				<p><?php esc_html_e( 'Allows authenticated post reads only, not a full MCP transport. Requires HTTPS and a WordPress Application Password for an administrator.', 'frontman-agentic-ai-editor' ); ?></p>
				<input type="hidden" name="frontman_php_diagnostics" value="0">
				<label>
					<input type="checkbox" name="frontman_php_diagnostics" value="1" <?php checked( Frontman_Sentry::sanitize_enabled( get_option( 'frontman_php_diagnostics', false ) ) ); ?>>
					<?php esc_html_e( 'Send unexpected Frontman PHP tool errors to Sentry.', 'frontman-agentic-ai-editor' ); ?>
				</label>
				<p><?php esc_html_e( 'Reports include exception types, sanitized stack traces, tool names, and software versions. They exclude exception messages, tool arguments, source code, site URLs, and user data. Sentry receives the server IP address when delivering reports. You can disable reporting here at any time.', 'frontman-agentic-ai-editor' ); ?></p>
				<p><a href="https://frontman.sh/privacy/" target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Frontman Privacy Policy', 'frontman-agentic-ai-editor' ); ?></a> · <a href="https://sentry.io/privacy/" target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Sentry Privacy Policy', 'frontman-agentic-ai-editor' ); ?></a></p>
				<input type="hidden" name="frontman_auth_diagnostics" value="0">
				<label>
					<input type="checkbox" name="frontman_auth_diagnostics" value="1" <?php checked( Frontman_Sentry::sanitize_enabled( get_option( 'frontman_auth_diagnostics', false ) ) ); ?>>
					<?php esc_html_e( 'Enable authentication diagnostics in the server PHP error log.', 'frontman-agentic-ai-editor' ); ?>
				</label>
				<p><?php esc_html_e( 'Records contain only fixed authentication failure categories and WordPress, PHP, and plugin versions. They exclude credentials, request content, URLs, and user data. Each category is logged at most once every five minutes per site. These records are not sent to Sentry. You can disable logging here at any time.', 'frontman-agentic-ai-editor' ); ?></p>
				<?php submit_button(); ?>
			</form>
		</div>
		<?php
	}
}
