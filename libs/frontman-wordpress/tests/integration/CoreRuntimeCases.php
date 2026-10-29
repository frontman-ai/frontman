<?php

require '/tmp/WordPressRuntimeTest.php';
require '/tmp/CustomCssRuntimeTest.php';
require '/tmp/ElementorSnapshotRuntimeTest.php';
require '/tmp/PostAuthorsRuntimeTest.php';

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

$mcp_post = wp_insert_post( [ 'post_title' => 'MCP private fixture', 'post_content' => 'Private MCP bytes', 'post_status' => 'draft' ] );
$mcp_password = WP_Application_Passwords::create_new_application_password( $actor_id, [ 'name' => 'Runtime MCP' ] );
frontman_runtime_assert( is_array( $mcp_password ), 'Application Password creation failed' );
$mcp_credentials = 'landing-page-actor:' . $mcp_password[0];
$mcp_discover = static function( string $credentials, string $browser_cookie = '', ?string $browser_nonce = null ): array {
	return frontman_runtime_http( 'GET', '/?rest_route=/frontman/v1/tools', $browser_cookie, $browser_nonce, null, '', $credentials );
};
$mcp_request = static function( string $credentials, string $name = 'wp_read_post', ?int $id = null, string $browser_cookie = '', ?string $browser_nonce = null ) use ( $mcp_post ): array {
	return frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', $browser_cookie, $browser_nonce, wp_json_encode( [ 'name' => $name, 'arguments' => [ 'id' => $id ?? $mcp_post, 'content' => 'Unauthorized mutation' ] ] ), '', $credentials );
};
$mcp_denied = static function( array $response ): void {
	frontman_runtime_assert( in_array( $response['status'], [ 401, 403 ], true ), 'MCP request must be denied' );
	frontman_runtime_assert( false === strpos( $response['body'], 'Private MCP bytes' ), 'Denied MCP response leaked content' );
	frontman_runtime_assert( false === strpos( $response['body'], '"tools"' ), 'Denied MCP response leaked catalog' );
};
try {
	require_once ABSPATH . 'wp-admin/includes/template.php';
	do_action( 'admin_init' );
	ob_start();
	Frontman_Settings::render_settings();
	frontman_runtime_assert( false !== strpos( ob_get_clean(), 'Allow MCP connections' ), 'MCP setting appears on the existing settings page' );
	$mcp_denied( $mcp_request( $mcp_credentials ) );
	$mcp_denied( $mcp_discover( $mcp_credentials ) );
	update_option( 'frontman_mcp_enabled', true );
	$catalog = $mcp_discover( $mcp_credentials );
	frontman_runtime_same( 200, $catalog['status'], 'Application Password discovery without cookies succeeds' );
	$catalog = json_decode( $catalog['body'], true, 512, JSON_THROW_ON_ERROR );
	$definitions = array_values( array_filter( Frontman_Tools::instance()->all_definitions(), static fn( $tool ) => 'wp_read_post' === $tool['name'] ) );
	frontman_runtime_same( [ 'tools' => $definitions ], $catalog, 'Discovery preserves exactly the registered read definition and argument schema' );
	$response = $mcp_request( $mcp_credentials, $catalog['tools'][0]['name'], $mcp_post );
	frontman_runtime_same( 200, $response['status'], 'Application Password HTTP request without cookies succeeds' );
	$result = json_decode( $response['body'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_same( false, $result['isError'], 'MCP read succeeds' );
	frontman_runtime_same( 'Private MCP bytes', json_decode( $result['content'][0]['text'], true )['content'], 'MCP preserves raw content' );
	foreach ( [ '{"id":[999]}', '{"id":true}', '{"id":"1"}', '{"id":1.5}', '{"id":0}', '{"id":-1}', '{"id":9223372036854775808}', '{}', '[]', 'true', 'null' ] as $arguments ) {
		$invalid = frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', '', null, '{"name":"wp_read_post","arguments":' . $arguments . '}', '', $mcp_credentials );
		frontman_runtime_same( 400, $invalid['status'], 'Malformed MCP arguments must not execute a read: ' . $arguments );
		frontman_runtime_assert( false === strpos( $invalid['body'], 'Private MCP bytes' ), 'Malformed MCP request leaked content' );
	}
	$failure = json_decode( $mcp_request( $mcp_credentials, 'wp_read_post', PHP_INT_MAX )['body'], true );
	frontman_runtime_assert( $failure['isError'] && false !== strpos( $failure['content'][0]['text'], 'Post not found' ), 'MCP preserves handler failures' );
	$mcp_denied( $mcp_request( '' ) );
	$mcp_denied( $mcp_request( 'landing-page-actor:invalid' ) );
	foreach ( [ '', 'landing-page-actor:invalid' ] as $credentials ) {
		$mcp_denied( $mcp_discover( $credentials ) );
	}
	$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
	$rest_nonce = wp_create_nonce( 'wp_rest' );
	unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
	$mcp_denied( $mcp_request( '', 'wp_read_post', null, $cookie, $rest_nonce ) );
	$mcp_denied( $mcp_discover( '', $cookie, $rest_nonce ) );
	$actor->set_role( 'subscriber' );
	$mcp_denied( $mcp_request( $mcp_credentials ) );
	$mcp_denied( $mcp_discover( $mcp_credentials ) );
	$actor->set_role( 'administrator' );
	foreach ( array_merge( array_column( Frontman_Tools::instance()->all_definitions(), 'name' ), [ 'unknown', 'WP_READ_POST' ] ) as $name ) {
		if ( 'wp_read_post' !== $name ) {
			$mcp_denied( $mcp_request( $mcp_credentials, $name ) );
		}
	}
	frontman_runtime_same( 'Private MCP bytes', $wpdb->get_var( $wpdb->prepare( "SELECT post_content FROM {$wpdb->posts} WHERE ID = %d", $mcp_post ) ), 'Denied tools did not mutate the post' );
	update_option( 'frontman_mcp_enabled', false );
	$mcp_denied( $mcp_request( $mcp_credentials ) );
	$mcp_denied( $mcp_discover( $mcp_credentials ) );
	update_option( 'frontman_mcp_enabled', true );
	WP_Application_Passwords::delete_application_password( $actor_id, $mcp_password[1]['uuid'] );
	$mcp_denied( $mcp_request( $mcp_credentials ) );
	$mcp_denied( $mcp_discover( $mcp_credentials ) );
} finally {
	$actor->set_role( 'administrator' );
	WP_Application_Passwords::delete_all_application_passwords( $actor_id );
	delete_option( 'frontman_mcp_enabled' );
	wp_delete_post( $mcp_post, true );
}
