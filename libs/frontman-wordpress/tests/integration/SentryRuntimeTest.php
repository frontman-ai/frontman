<?php

frontman_runtime_assert( is_file( FRONTMAN_PLUGIN_DIR . 'vendor/autoload.php' ), 'Release package must include the scoped SDK.' );
frontman_runtime_assert( false === get_option( 'frontman_php_diagnostics', false ), 'PHP diagnostics must default to off.' );
frontman_runtime_assert( extension_loaded( 'curl' ) && extension_loaded( 'mbstring' ), 'Runtime tests require cURL and mbstring.' );
$original_user_id = get_current_user_id();
wp_set_current_user( $admin->ID );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = wp_create_nonce( Frontman_Auth::nonce_action() );

try {
	foreach ( [ [ false, false, false, 0 ], [ true, false, false, 1 ], [ true, true, false, 0 ], [ true, false, true, 1 ], [ false, false, false, 0 ] ] as [ $enabled, $expected, $fail_reporting, $captures ] ) {
		update_option( 'frontman_php_diagnostics', $enabled );
		update_option( 'frontman_test_sentry_fail', $fail_reporting );
		update_option( 'frontman_test_sentry_count', 0 );
		$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_test_diagnostics', 'arguments' => [ 'expected' => $expected ] ] );
		frontman_runtime_assert( 200 === $response['status'], 'Tool exception changed HTTP status.' );
		frontman_runtime_assert( Frontman_Tools::error_result( $expected ? 'Expected tool failure.' : 'Unexpected tool failure.' ) === $response['body'], 'Diagnostics changed the SSE tool error result.' );
		wp_cache_delete( 'frontman_test_sentry_count', 'options' );
		wp_cache_delete( 'alloptions', 'options' );
		frontman_runtime_assert( $captures === (int) get_option( 'frontman_test_sentry_count' ), 'Router reporting did not respect consent or expected errors: ' . json_encode( [ $enabled, $expected, $fail_reporting, $captures, get_option( 'frontman_test_sentry_count' ) ] ) );
	}
} finally {
	delete_option( 'frontman_php_diagnostics' );
	delete_option( 'frontman_test_sentry_count' );
	delete_option( 'frontman_test_sentry_fail' );
	unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
	wp_set_current_user( $original_user_id );
}
