<?php

set_error_handler(
	static function( int $severity, string $message, string $file, int $line ): bool {
		if ( error_reporting() & $severity ) {
			throw new ErrorException( $message, 0, $severity, $file, $line );
		}
		return false;
	}
);

require '/var/www/html/wp-load.php';
require '/tmp/WordPressRuntimeTest.php';
require '/tmp/CustomCssRuntimeTest.php';
require '/tmp/ElementorSnapshotRuntimeTest.php';
require '/tmp/PostAuthorsRuntimeTest.php';

function frontman_runtime_same( $expected, $actual, string $message ): void {
	frontman_runtime_assert( $expected === $actual, $message . "\nExpected: " . wp_json_encode( $expected ) . "\nActual: " . wp_json_encode( $actual ) );
}

function frontman_runtime_saved_id( string $message ): int {
	frontman_runtime_assert( 1 === preg_match( '/[Pp]ost (\d+) was saved/', $message, $match ), 'Partial save must identify its post: ' . $message );
	frontman_runtime_assert( false !== strpos( $message, 'wp_read_post' ), 'Partial save must explain raw recovery: ' . $message );
	return (int) $match[1];
}

$actor_id = wp_insert_user( [ 'user_login' => 'landing-page-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
frontman_runtime_assert( is_int( $actor_id ), 'Landing-page actor creation failed' );
$actor = new WP_User( $actor_id );
wp_set_current_user( $actor_id );
$cookie = wp_generate_auth_cookie( $actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $input, bool $error = false, string $fixture = '' ) use ( $cookie, $nonce ) {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $input ], null, $fixture );
	frontman_runtime_same( 200, $response['status'], $name . ' HTTP status' );
	frontman_runtime_same( $error, $response['body']['isError'], $name . ': ' . wp_json_encode( $response['body'] ) );
	$text = $response['body']['content'][0]['text'];
	return $error ? $text : json_decode( $text, true, 512, JSON_THROW_ON_ERROR );
};
$reject = static function( string $name, array $input, string $reason, string $fixture = '' ) use ( $call, $wpdb ): void {
	$before = $wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A );
	$message = $call( $name, $input, true, $fixture );
	frontman_runtime_assert( false !== strpos( $message, $reason ), $name . ' expected ' . $reason . ', got: ' . $message );
	$after = $wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A );
	frontman_runtime_assert( $before === $after, $name . ' rejection must not write posts or revisions' );
};
foreach ( [ 'PostContentRuntimeTest.php', 'TemplateCreationRuntimeTest.php', 'PageTemplateRuntimeTest.php' ] as $file ) {
	( static function() use ( $file, $call, $reject, $actor, $cookie ): void { require '/tmp/' . $file; } )();
}
restore_error_handler();

fwrite( STDOUT, 'OK (WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n" );
