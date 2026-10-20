<?php

define( 'ABSPATH', '/private/wordpress/' );
define( 'LOGGED_IN_COOKIE', 'wordpress_logged_in_test' );

$GLOBALS['hooks'] = [];
function add_action( $hook, $callback, $priority = 10, $accepted_args = 1 ): void {
	$GLOBALS['hooks'][ $hook ][] = [ $callback, $accepted_args ];
}
function fire_hook( string $hook, ...$args ): void {
	foreach ( $GLOBALS['hooks'][ $hook ] ?? [] as [ $callback, $accepted_args ] ) {
		$callback( ...array_slice( $args, 0, $accepted_args ) );
	}
}
function did_action( string $hook ): int { return $GLOBALS['resolved'] ? 1 : 0; }
function wp_get_current_user(): void {
	$GLOBALS['resolved'] = true;
	if ( null !== $GLOBALS['failure_hook'] ) {
		fire_hook( $GLOBALS['failure_hook'], 'cookie-secret', [ 'username' => 'username-secret', 'token' => 'token-secret', 'hmac' => 'hash-secret' ] );
	}
}
function is_user_logged_in(): bool { return $GLOBALS['logged_in']; }
function current_user_can( string $capability ): bool {
	check( 'manage_options' === $capability, 'Capability must remain manage_options.' );
	return $GLOBALS['admin'];
}
function get_option( string $name, $default = false ) { return $GLOBALS['options'][ $name ] ?? $default; }
function get_bloginfo( string $name ): string { return '6.0.9'; }
function __( string $message, string $domain ): string { return $message; }
function wp_json_encode( $data ) { return json_encode( $data ); }
function nocache_headers(): void { $GLOBALS['nocache'] = true; }
function wp_send_json( $data, int $status ): void { $GLOBALS['response'] = [ $data, $status ]; }
function wp_create_nonce( string $action ): string {
	check( 'frontman_request' === $action, 'Nonce action must remain unchanged.' );
	$GLOBALS['nonce_created'] = true;
	return 'nonce-secret';
}
function wp_unslash( string $value ): string { return stripslashes( $value ); }
function sanitize_text_field( string $value ): string { return trim( $value ); }
class WP_Error {
	private string $code;
	private string $message;
	private array $data;
	public function __construct( string $code, string $message, array $data ) {
		$this->code = $code;
		$this->message = $message;
		$this->data = $data;
	}
	public function get_error_code(): string { return $this->code; }
	public function get_error_message(): string { return $this->message; }
	public function get_error_data(): array { return $this->data; }
}
function check( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require_once dirname( __DIR__ ) . '/frontman.php';
check( isset( $GLOBALS['hooks']['init'] ), 'Plugin bootstrap must still be scheduled on init.' );
foreach ( [ 'malformed', 'expired', 'bad_username', 'bad_hash', 'bad_session_token' ] as $reason ) {
	$observers = $GLOBALS['hooks'][ 'auth_cookie_' . $reason ] ?? [];
	check( 1 === count( $observers ), 'Observers must exist before init or user resolution.' );
	check( 0 === $observers[0][1], 'Native credentials must never reach observers.' );
}

$log = tempnam( sys_get_temp_dir(), 'frontman-auth-test-' );
$previous_log = ini_set( 'error_log', $log );
function reset_request( $enabled = true, bool $cookie = true, ?string $hook = null ): void {
	foreach ( [ 'cookie_failure' => null, 'diagnostic_logged' => false ] as $name => $value ) {
		$property = new ReflectionProperty( Frontman_Auth::class, $name );
		if ( PHP_VERSION_ID < 80100 ) {
			$property->setAccessible( true );
		}
		$property->setValue( null, $value );
	}
	$GLOBALS['options'] = [ 'frontman_php_diagnostics' => $enabled ];
	$GLOBALS['logged_in'] = false;
	$GLOBALS['admin'] = false;
	$GLOBALS['resolved'] = false;
	$GLOBALS['failure_hook'] = $hook;
	$GLOBALS['nonce_created'] = false;
	$GLOBALS['response'] = null;
	$_COOKIE = $cookie ? [ LOGGED_IN_COOKIE => 'cookie-secret' ] : [];
	$_POST = [ 'content' => 'content-secret', 'css' => 'css-secret', 'arguments' => 'args-secret' ];
	$_SERVER['REQUEST_URI'] = '/private-path?query-secret';
	$_SERVER['HTTP_X_WP_NONCE'] = 'nonce-secret';
	file_put_contents( $GLOBALS['log'], '' );
}
function reject_request(): void {
	$error = Frontman_Auth::check();
	check( $error instanceof WP_Error, 'Anonymous request must be rejected.' );
	check( 'frontman_not_authenticated' === $error->get_error_code(), '401 code must be unchanged.' );
	check( [ 'status' => 401 ] === $error->get_error_data(), '401 status must be unchanged.' );
	Frontman_Auth::send_error( $error );
	check( 401 === $GLOBALS['response'][1], 'API response must retain 401.' );
	check( ! $GLOBALS['nonce_created'], 'Unauthenticated rejection must not mint a nonce.' );
}

try {
	foreach ( [
		[ null, false, 'absent_cookie' ],
		[ 'auth_cookie_malformed', false, 'absent_cookie' ],
		[ 'auth_cookie_expired', false, 'absent_cookie' ],
		[ null, true, 'no_native_reason' ],
		[ 'auth_cookie_malformed', true, 'malformed' ],
		[ 'auth_cookie_expired', true, 'expired' ],
		[ 'auth_cookie_bad_username', true, 'bad_username' ],
		[ 'auth_cookie_bad_hash', true, 'bad_hash' ],
		[ 'auth_cookie_bad_session_token', true, 'bad_session' ],
	] as [ $hook, $cookie, $category ] ) {
		reset_request( true, $cookie, $hook );
		ob_start();
		reject_request();
		reject_request();
		check( '' === ob_get_clean(), 'Diagnostics must not enter the response body.' );
		$payload = file_get_contents( $log );
		check( 1 === substr_count( $payload, 'Frontman auth diagnostics: ' ), 'One diagnostic per request only.' );
		$json = substr( $payload, strpos( $payload, 'Frontman auth diagnostics: ' ) + strlen( 'Frontman auth diagnostics: ' ) );
		check( [ 'category' => $category, 'wordpress_version' => '6.0.9', 'php_version' => PHP_VERSION, 'plugin_version' => FRONTMAN_VERSION ] === json_decode( trim( $json ), true ), 'Log must contain only the categorical allowlist and versions.' );
		foreach ( [ 'cookie-secret', 'username-secret', 'token-secret', 'hash-secret', 'nonce-secret', 'content-secret', 'css-secret', 'args-secret', 'private-path', 'query-secret', ABSPATH ] as $secret ) {
			check( false === strpos( $payload, $secret ), 'Log must not contain request or credential data.' );
		}
	}
	foreach ( [ null, false, 0, '0', 'false', 'yes', [], [ '1' ] ] as $disabled ) {
		reset_request( $disabled, true, 'auth_cookie_bad_hash' );
		reject_request();
		check( '' === file_get_contents( $log ), 'Diagnostics require explicit opt-in.' );
	}
	foreach ( [ true, 1, '1' ] as $enabled ) {
		reset_request( $enabled );
		reject_request();
		check( '' !== file_get_contents( $log ), 'Saved explicit opt-in must work.' );
	}
	reset_request( true, true, 'auth_cookie_bad_hash' );
	wp_get_current_user();
	fire_hook( 'auth_cookie_malformed', '', 'auth' );
	reject_request();
	check( false !== strpos( file_get_contents( $log ), 'bad_hash' ), 'Unrelated empty malformed attempts must not overwrite a specific reason.' );

	reset_request( true, true, 'auth_cookie_expired' );
	wp_get_current_user();
	check( '' === file_get_contents( $log ), 'Native failures on ordinary WordPress traffic must not log.' );
	Frontman_Auth::check();
	check( '' === file_get_contents( $log ), 'A check alone (also used for UI) must not log.' );
	$GLOBALS['logged_in'] = true;
	$error = Frontman_Auth::check();
	check( 'frontman_forbidden' === $error->get_error_code() && [ 'status' => 403 ] === $error->get_error_data(), 'Permission rejection must remain 403.' );
	Frontman_Auth::send_error( $error );
	check( 403 === $GLOBALS['response'][1], 'Permission response must remain 403.' );
	$GLOBALS['admin'] = true;
	check( true === Frontman_Auth::check(), 'Authenticated administrators must still pass.' );
	check( 'nonce-secret' === Frontman_Auth::request_nonce(), 'Nonce header reading must remain unchanged.' );
	foreach ( [ 'frontman_missing_nonce', 'frontman_invalid_nonce' ] as $code ) {
		Frontman_Auth::send_error( new WP_Error( $code, 'Nonce rejected', [ 'status' => 403 ] ) );
		check( $GLOBALS['nonce_created'] && 403 === $GLOBALS['response'][1] && $code === $GLOBALS['response'][0]['code'], 'Authenticated nonce rejection must retain 403 and replacement nonce creation.' );
	}
	check( '' === file_get_contents( $log ), 'Successful auth, permission and nonce rejections must not log cookie diagnostics.' );
} finally {
	ini_set( 'error_log', $previous_log );
	unlink( $log );
}

fwrite( STDOUT, "OK (early auth observers, opt-in, categories, deduplication, privacy, unchanged 401/403 and nonces)\n" );
