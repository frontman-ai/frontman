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

	/**
	 * Report unexpected entry-point failures without changing WordPress error handling.
	 *
	 * Action callbacks keep their registered identity, priority and accepted arguments.
	 * This opt-in boundary installs no global handlers and emits no response output.
	 * Deferred callbacks run after bootstrap, not inside its boundary.
	 */
	public static function boundary( string $entry_point, callable $callback ): void {
		try {
			$callback();
		} catch ( \Throwable $exception ) {
			self::capture( $exception, $entry_point );
			throw $exception;
		}
	}

	public static function sanitize_enabled( $value ): bool {
		return in_array( $value, [ true, 1, '1' ], true );
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
