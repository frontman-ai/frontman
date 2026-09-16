<?php

use FrontmanVendor\Sentry\Event;
use FrontmanVendor\Sentry\Options;
use FrontmanVendor\Sentry\Serializer\PayloadSerializer;
use FrontmanVendor\Sentry\Transport\Result;
use FrontmanVendor\Sentry\Transport\ResultStatus;
use FrontmanVendor\Sentry\Transport\TransportInterface;

define( 'ABSPATH', '/private/site-owner/wordpress/' );
define( 'FRONTMAN_PLUGIN_DIR', dirname( __DIR__ ) . '/' );
define( 'FRONTMAN_VERSION', '5.0.0' );

function get_option( string $name, $default = false ) { return $GLOBALS['options'][ $name ] ?? $default; }
function get_bloginfo( string $name ): string { return '6.0.9'; }
function wp_get_environment_type(): string { return 'staging'; }
function register_setting( string $group, string $name, array $args ): void { $GLOBALS['setting'] = [ $group, $name, $args ]; }
function check( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$site_first = in_array( '--site-first', $argv, true );
if ( $site_first ) {
	require_once dirname( __DIR__, 3 ) . '/dist/wordpress-dependencies-source/vendor/autoload.php';
}

require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-tools.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-sentry.php';

Frontman_Sentry::capture( new RuntimeException( 'Not opted in' ), 'wp_test' );
check( ! class_exists( 'FrontmanVendor\\Sentry\\ClientBuilder', false ), 'Disabled reporting must not load the SDK.' );
Frontman_Sentry::register_setting();
check( false === $GLOBALS['setting'][2]['default'], 'Diagnostics must default to off.' );
check( is_callable( $GLOBALS['setting'][2]['sanitize_callback'] ), 'Consent must have a settings sanitizer.' );
foreach ( [ null, false, 0, '0', 'false', 'yes', [], [ '1' ] ] as $value ) {
	check( ! Frontman_Sentry::sanitize_enabled( $value ), 'Only explicit opt-in should enable reporting.' );
}
foreach ( [ true, 1, '1' ] as $value ) {
	check( Frontman_Sentry::sanitize_enabled( $value ), 'Saved opt-in should enable reporting.' );
}

require_once FRONTMAN_PLUGIN_DIR . 'vendor/autoload.php';
check( ! class_exists( 'Sentry\\ClientBuilder', false ), 'Bundled SDK must not expose unprefixed Sentry classes.' );
check( $site_first === function_exists( 'Sentry\\init' ), 'Bundled SDK must not expose global Sentry functions.' );

class MemoryTransport implements TransportInterface {
	public array $events = [];
	public bool $fail = false;
	public function send( Event $event ): Result {
		$this->events[] = $event;
		if ( $this->fail ) {
			throw new RuntimeException( 'Private transport credentials' );
		}
		return new Result( ResultStatus::success(), $event );
	}
	public function close( ?int $timeout = null ): Result { return new Result( ResultStatus::success() ); }
}

$GLOBALS['options']['frontman_php_diagnostics'] = '1';
$standalone_transport = new MemoryTransport();
Frontman_Sentry::capture( new RuntimeException( 'Standalone SDK' ), 'wp_test', $standalone_transport );
check( 1 === count( $standalone_transport->events ), 'Scoped SDK must work without another plugin providing polyfills.' );

require_once dirname( __DIR__, 3 ) . '/dist/wordpress-dependencies-source/vendor/autoload.php';
\Sentry\init( [ 'default_integrations' => false, 'dsn' => null ] );
$site_hub = \Sentry\SentrySdk::getCurrentHub();
$site_client = $site_hub->getClient();
$previous_handler = set_error_handler( static function (): bool { return false; } );
$our_handler = set_error_handler( static function (): bool { return false; } );
restore_error_handler();

$GLOBALS['options']['frontman_php_diagnostics'] = '1';
$transport = new MemoryTransport();
$_COOKIE['auth'] = 'cookie-secret';
$_POST['content'] = 'private-page-content';
$_SERVER['HTTP_AUTHORIZATION'] = 'Bearer authorization-secret';
$_SERVER['HTTP_X_WP_NONCE'] = 'nonce-secret';
$_SERVER['REQUEST_URI'] = '/private-page?secret=query-secret';

function throw_private_error( string $argument ): void {
	throw new RuntimeException( 'customer@example.test ' . $argument, 12345, new LogicException( 'previous-secret' ) );
}
try {
	throw_private_error( 'argument-secret' );
} catch ( Throwable $exception ) {
	ob_start();
	Frontman_Sentry::capture( $exception, 'wp_test', $transport );
	check( '' === ob_get_clean(), 'Reporting must not write into the SSE response.' );
}
check( 1 === count( $transport->events ), 'A thrown exception must produce exactly one event.' );
$event = $transport->events[0];
check( 'frontman-wordpress@5.0.0' === $event->getRelease(), 'Release must identify the plugin version.' );
check( 'staging' === $event->getEnvironment(), 'Environment must come from WordPress.' );
check( 'wp_test' === $event->getTags()['tool_name'], 'Event must identify the tool.' );
check( 'frontman-wordpress' === $event->getTags()['service'], 'Event must identify the PHP plugin.' );
check( '6.0.9' === $event->getTags()['wordpress_version'], 'Event must identify WordPress version.' );
check( PHP_VERSION === $event->getTags()['php_version'], 'Event must identify PHP version.' );
check( 2 === count( $event->getExceptions() ), 'Chained exceptions must retain their types and stacks.' );
$frames = $event->getExceptions()[0]->getStacktrace()->getFrames();
check( count( $frames ) > 0, 'Exception must retain a PHP stack trace.' );
foreach ( $frames as $frame ) {
	check( [] === $frame->getVars(), 'Frame arguments must be removed.' );
	check( null === $frame->getAbsoluteFilePath(), 'Absolute file paths must be removed.' );
	check( null === $frame->getContextLine(), 'Source code must be removed.' );
}
$payload = str_replace( '\\/', '/', ( new PayloadSerializer( new Options() ) )->serialize( $event ) );
foreach ( [ 'cookie-secret', 'private-page-content', 'authorization-secret', 'nonce-secret', 'query-secret', 'argument-secret', 'previous-secret', 'customer@example.test', FRONTMAN_PLUGIN_DIR, ABSPATH, '"code":12345' ] as $secret ) {
	check( false === strpos( $payload, $secret ), 'Event leaked sensitive data: ' . $secret );
}
check( false !== strpos( $payload, 'frontman/tests/SentryTest.php' ), 'Plugin-relative stack paths must survive scrubbing.' );
check( $site_hub === \Sentry\SentrySdk::getCurrentHub() && $site_client === $site_hub->getClient(), 'Reporting must not replace another plugin\'s Sentry hub or client.' );
$current_handler = set_error_handler( static function (): bool { return false; } );
restore_error_handler();
check( $our_handler === $current_handler, 'Reporting must not install a global error handler.' );
restore_error_handler();

Frontman_Sentry::capture( new Frontman_Tool_Error( 'Expected validation failure' ), 'wp_test', $transport );
check( 1 === count( $transport->events ), 'Expected tool errors must not be reported.' );
$GLOBALS['options']['frontman_php_diagnostics'] = '0';
Frontman_Sentry::capture( new RuntimeException( 'Consent revoked' ), 'wp_test', $transport );
check( 1 === count( $transport->events ), 'Revoking consent must stop reporting immediately.' );
$GLOBALS['options']['frontman_php_diagnostics'] = '1';
$transport->fail = true;
ob_start();
Frontman_Sentry::capture( new RuntimeException( 'Tool failure' ), 'wp_test', $transport );
check( '' === ob_get_clean(), 'Transport failures must not corrupt the SSE response.' );
check( 2 === count( $transport->events ), 'Failing transport must have been exercised.' );

fwrite( STDOUT, "OK (Sentry consent, privacy, SDK isolation, exception capture, transport failure)\n" );
