<?php
/**
 * Opt-in diagnostics for unexpected Frontman PHP tool exceptions only.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Sentry {
	private const OPTION = 'frontman_php_diagnostics';
	private const DSN = 'https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296';

	public static function register(): void {
		add_action( 'admin_init', [ self::class, 'register_setting' ] );
		add_action( 'admin_menu', static function (): void {
			add_options_page( 'Frontman', 'Frontman', 'manage_options', 'frontman-diagnostics', [ self::class, 'render_settings' ] );
		} );
	}

	public static function sanitize_enabled( $value ): bool {
		return in_array( $value, [ true, 1, '1' ], true );
	}

	public static function register_setting(): void {
		register_setting( 'frontman_diagnostics', self::OPTION, [
			'type' => 'boolean',
			'default' => false,
			'sanitize_callback' => [ self::class, 'sanitize_enabled' ],
		] );
	}

	public static function render_settings(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'Administrator access required.', 'frontman-agentic-ai-editor' ) );
		}
		?>
		<div class="wrap">
			<h1><?php esc_html_e( 'Frontman PHP Diagnostics', 'frontman-agentic-ai-editor' ); ?></h1>
			<form action="options.php" method="post">
				<?php settings_fields( 'frontman_diagnostics' ); ?>
				<input type="hidden" name="frontman_php_diagnostics" value="0">
				<label>
					<input type="checkbox" name="frontman_php_diagnostics" value="1" <?php checked( self::sanitize_enabled( get_option( self::OPTION, false ) ) ); ?>>
					<?php esc_html_e( 'Send unexpected Frontman PHP tool errors to Sentry.', 'frontman-agentic-ai-editor' ); ?>
				</label>
				<p><?php esc_html_e( 'Reports include exception types, sanitized stack traces, tool names, and software versions. They exclude exception messages, tool arguments, source code, site URLs, and user data. Sentry receives the server IP address when delivering reports. You can disable reporting here at any time.', 'frontman-agentic-ai-editor' ); ?></p>
				<p><a href="https://frontman.sh/privacy/" target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Frontman Privacy Policy', 'frontman-agentic-ai-editor' ); ?></a> · <a href="https://sentry.io/privacy/" target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Sentry Privacy Policy', 'frontman-agentic-ai-editor' ); ?></a></p>
				<?php submit_button(); ?>
			</form>
		</div>
		<?php
	}

	public static function capture( \Throwable $exception, string $tool, ?\FrontmanVendor\Sentry\Transport\TransportInterface $transport = null ): void {
		if ( $exception instanceof Frontman_Tool_Error || ! self::sanitize_enabled( get_option( self::OPTION, false ) ) ) {
			return;
		}

		$autoload = FRONTMAN_PLUGIN_DIR . 'vendor/autoload.php';
		if ( ! extension_loaded( 'curl' ) || ! extension_loaded( 'mbstring' ) || ! is_readable( $autoload ) ) {
			error_log( 'Frontman PHP diagnostics unavailable: bundled SDK, cURL, and mbstring are required.' );
			return;
		}

		try {
			require_once $autoload;
			$builder = \FrontmanVendor\Sentry\ClientBuilder::create( [
				'dsn' => self::DSN,
				'release' => 'frontman-wordpress@' . FRONTMAN_VERSION,
				'environment' => wp_get_environment_type(),
				'default_integrations' => false,
				'spotlight' => false,
				'send_default_pii' => false,
				'max_request_body_size' => 'never',
				'context_lines' => 0,
				'server_name' => '',
				'http_connect_timeout' => 1,
				'http_timeout' => 2,
				'before_send' => [ self::class, 'scrub_event' ],
			] );
			if ( null !== $transport ) {
				$builder->setTransport( $transport );
			}
			$scope = new \FrontmanVendor\Sentry\State\Scope();
			$scope->setTags( [
				'service' => 'frontman-wordpress',
				'framework' => 'wordpress',
				'tool_name' => $tool,
				'wordpress_version' => get_bloginfo( 'version' ),
				'php_version' => PHP_VERSION,
			] );
			if ( null === $builder->getClient()->captureException( $exception, $scope ) ) {
				error_log( 'Frontman PHP diagnostics could not deliver an exception report.' );
			}
		} catch ( \Throwable $reporting_error ) {
			error_log( 'Frontman PHP diagnostics failed to report an exception.' );
		}
	}

	public static function scrub_event( \FrontmanVendor\Sentry\Event $event ): \FrontmanVendor\Sentry\Event {
		$event->setRequest( [] );
		$event->setUser( null );
		$event->setServerName( null );
		foreach ( $event->getExceptions() as $exception ) {
			$exception->setValue( 'Unexpected Frontman tool exception (message omitted for privacy).' );
			$exception->setType( explode( '@anonymous', $exception->getType() )[0] );
			$exception->setMechanism( null );
			$stacktrace = $exception->getStacktrace();
			if ( null === $stacktrace ) {
				continue;
			}
			$frames = [];
			foreach ( $stacktrace->getFrames() as $frame ) {
				$file = $frame->getAbsoluteFilePath() ?? $frame->getFile();
				$in_plugin = 0 === strpos( $file, FRONTMAN_PLUGIN_DIR );
				$file = $in_plugin ? 'frontman/' . substr( $file, strlen( FRONTMAN_PLUGIN_DIR ) ) : basename( $file );
				$function = $frame->getFunctionName();
				if ( null !== $function && ( false !== strpos( $function, '@anonymous' ) || false !== strpos( $function, '{closure' ) ) ) {
					$function = '[anonymous]';
				}
				$frames[] = new \FrontmanVendor\Sentry\Frame( $function, $file, $frame->getLine(), null, null, [], $in_plugin );
			}
			$exception->setStacktrace( new \FrontmanVendor\Sentry\Stacktrace( $frames ) );
		}
		return $event;
	}
}
