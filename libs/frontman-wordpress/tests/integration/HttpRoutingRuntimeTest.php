<?php

if ( ! defined( 'ABSPATH' ) ) {
	throw new RuntimeException( 'WordPress must be loaded before the HTTP routing runtime test.' );
}

require_once ABSPATH . 'wp-admin/includes/misc.php';

/**
 * Send a request through Apache to exercise the same routing used by a browser.
 *
 * @return array{status:int, headers:array<string>, body:string}
 */
function frontman_runtime_http_request( string $path, string $cookie = '', string $method = 'GET', string $body = '', string $nonce = '', string $content_type = 'application/json' ): array {
	$headers = [ 'Content-Type: ' . $content_type ];
	if ( '' !== $cookie ) {
		$headers[] = 'Cookie: ' . $cookie;
	}
	if ( '' !== $nonce ) {
		$headers[] = 'X-WP-Nonce: ' . $nonce;
	}

	$context = stream_context_create(
		[
			'http' => [
				'method' => $method,
				'header' => implode( "\r\n", $headers ),
				'content' => $body,
				'ignore_errors' => true,
				'follow_location' => 0,
			],
		]
	);
	$response_body = file_get_contents( 'http://127.0.0.1' . $path, false, $context );
	$response_headers = $http_response_header ?? [];
	$status_line = $response_headers[0] ?? '';
	preg_match( '/\s(\d{3})\s/', $status_line, $matches );

	return [
		'status' => isset( $matches[1] ) ? (int) $matches[1] : 0,
		'headers' => $response_headers,
		'body' => is_string( $response_body ) ? $response_body : '',
	];
}

function frontman_runtime_location( array $headers ): string {
	foreach ( $headers as $header ) {
		if ( 0 === stripos( $header, 'Location:' ) ) {
			return trim( substr( $header, strlen( 'Location:' ) ) );
		}
	}

	return '';
}

$administrator = get_user_by( 'login', 'admin' );
frontman_runtime_assert( $administrator instanceof WP_User, 'Runtime administrator was not found.' );
wp_set_current_user( $administrator->ID );
$expiration = time() + HOUR_IN_SECONDS;
$session_token = WP_Session_Tokens::get_instance( $administrator->ID )->create( $expiration );
$auth_cookie = wp_generate_auth_cookie( $administrator->ID, $expiration, 'auth', $session_token );
$logged_in_cookie = wp_generate_auth_cookie( $administrator->ID, $expiration, 'logged_in', $session_token );
$_COOKIE[ LOGGED_IN_COOKIE ] = $logged_in_cookie;
$cookie = AUTH_COOKIE . '=' . $auth_cookie;
$cookie .= '; ' . LOGGED_IN_COOKIE . '=' . $logged_in_cookie;

$missing_auth = frontman_runtime_http_request(
	'/index.php/frontman/tools/call',
	'',
	'POST',
	wp_json_encode( [ 'name' => 'wp_get_site_info', 'arguments' => [] ] )
);
frontman_runtime_assert( 401 === $missing_auth['status'], 'Plain-permalink tool calls accepted missing authentication.' );

$plain_admin = frontman_runtime_http_request( '/wp-admin/admin.php?page=frontman', $cookie );
frontman_runtime_assert( 302 === $plain_admin['status'], 'Plain-permalink admin entrypoint did not redirect.' );
frontman_runtime_assert(
	home_url( '/index.php/frontman' ) === frontman_runtime_location( $plain_admin['headers'] ),
	'Plain-permalink admin entrypoint did not use the WordPress front controller. Location: ' . frontman_runtime_location( $plain_admin['headers'] )
);

$plain_ui = frontman_runtime_http_request( '/index.php/frontman', $cookie );
frontman_runtime_assert( 200 === $plain_ui['status'], 'Plain-permalink Frontman UI was not reachable.' );
frontman_runtime_assert(
	false !== strpos( $plain_ui['body'], 'data-relay-base-url="' . esc_attr( home_url( '/index.php' ) ) . '"' ),
	'Plain-permalink UI did not expose its relay base URL.'
);
preg_match( '/data-wp-nonce="([^"]+)"/', $plain_ui['body'], $nonce_matches );
$nonce = $nonce_matches[1] ?? '';
frontman_runtime_assert( '' !== $nonce, 'Plain-permalink UI did not expose a nonce.' );

$plain_tools = frontman_runtime_http_request( '/index.php/frontman/tools', $cookie );
frontman_runtime_assert( 200 === $plain_tools['status'], 'Plain-permalink tool discovery was not reachable.' );
$tool_payload = json_decode( $plain_tools['body'], true );
frontman_runtime_assert( is_array( $tool_payload ) && ! empty( $tool_payload['tools'] ), 'Plain-permalink tool discovery returned no tools.' );

$missing_nonce = frontman_runtime_http_request(
	'/index.php/frontman/tools/call',
	$cookie,
	'POST',
	wp_json_encode( [ 'name' => 'wp_get_site_info', 'arguments' => [] ] )
);
frontman_runtime_assert( 403 === $missing_nonce['status'], 'Plain-permalink tool calls accepted a missing nonce.' );

$tool_call = frontman_runtime_http_request(
	'/index.php/frontman/tools/call',
	$cookie,
	'POST',
	wp_json_encode( [ 'name' => 'wp_get_site_info', 'arguments' => [] ] ),
	$nonce
);
frontman_runtime_assert( 200 === $tool_call['status'], 'Plain-permalink authenticated tool call failed.' );
frontman_runtime_assert( false !== strpos( $tool_call['body'], 'event: result' ), 'Plain-permalink tool call did not return SSE.' );
frontman_runtime_assert( false !== strpos( $tool_call['body'], '"isError":false' ), 'Plain-permalink tool call returned an error.' );

$permalink_update = frontman_runtime_http_request(
	'/wp-admin/options-permalink.php',
	$cookie,
	'POST',
	http_build_query(
		[
			'_wpnonce' => wp_create_nonce( 'update-permalink' ),
			'_wp_http_referer' => '/wp-admin/options-permalink.php',
			'selection' => '/%postname%/',
			'permalink_structure' => '/%postname%/',
			'category_base' => '',
			'tag_base' => '',
			'submit' => 'Save Changes',
		]
	),
	'',
	'application/x-www-form-urlencoded'
);
frontman_runtime_assert(
	302 === $permalink_update['status'],
	'Could not enable pretty permalinks through WordPress admin. Status: ' . $permalink_update['status'] . ' Location: ' . frontman_runtime_location( $permalink_update['headers'] )
);
$permalink_confirmation = frontman_runtime_http_request( '/wp-admin/options-permalink.php?settings-updated=true', $cookie );
frontman_runtime_assert( 200 === $permalink_confirmation['status'], 'Could not finish the pretty-permalink admin flow.' );
$rewrite_file = file_get_contents( ABSPATH . '.htaccess' );
frontman_runtime_assert(
	is_string( $rewrite_file ) && false !== strpos( $rewrite_file, 'RewriteRule . /index.php [L]' ),
	'Pretty-permalink rewrite rules were not written. Rules: ' . ( is_string( $rewrite_file ) ? $rewrite_file : '(unreadable)' )
);

$pretty_admin = frontman_runtime_http_request( '/wp-admin/admin.php?page=frontman', $cookie );
frontman_runtime_assert( 302 === $pretty_admin['status'], 'Pretty-permalink admin entrypoint did not redirect.' );
frontman_runtime_assert( home_url( '/frontman' ) === frontman_runtime_location( $pretty_admin['headers'] ), 'Pretty-permalink admin entrypoint changed URL.' );

$pretty_ui = frontman_runtime_http_request( '/frontman', $cookie );
frontman_runtime_assert(
	200 === $pretty_ui['status'],
	'Pretty-permalink Frontman UI regressed. Status: ' . $pretty_ui['status'] . ' Location: ' . frontman_runtime_location( $pretty_ui['headers'] )
);
frontman_runtime_assert(
	false !== strpos( $pretty_ui['body'], 'data-relay-base-url="' . esc_attr( home_url() ) . '"' ),
	'Pretty-permalink UI did not expose its relay base URL.'
);

$pretty_tools = frontman_runtime_http_request( '/frontman/tools', $cookie );
frontman_runtime_assert( 200 === $pretty_tools['status'], 'Pretty-permalink tool discovery regressed.' );
