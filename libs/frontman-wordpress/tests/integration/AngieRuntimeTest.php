<?php
/** Read-only contract against official Angie packages, not mocked REST handlers. */
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/user.php';

function angie_check( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$tools = Frontman_Tools::instance();
if ( in_array( '--setup', $argv, true ) ) {
	angie_check( null === $tools->get( 'wp_read_angie_snippet' ), 'Inactive Angie must not register the reader.' );
	$result = activate_plugin( 'angie/angie.php' );
	angie_check( ! is_wp_error( $result ), 'Angie activation failed: ' . ( is_wp_error( $result ) ? $result->get_error_message() : '' ) );
	exit( 0 );
}
angie_check( ANGIE_VERSION === getenv( 'EXPECTED_ANGIE_VERSION' ), 'Unexpected Angie version.' );
angie_check( 'read' === $tools->get( 'wp_read_angie_snippet' )->access, 'Reader must be classified read-only.' );
angie_check( null === $tools->get( 'wp_update_angie_snippet' ), 'No Angie writer should be exposed.' );

function angie_call( array $input, bool $error = false ): array {
	global $tools;
	$result = $tools->call( 'wp_read_angie_snippet', $tools->sanitize_input( 'wp_read_angie_snippet', $input ) );
	angie_check( $error === $result['isError'], $result['content'][0]['text'] );
	return $error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
}

$id = wp_insert_post( [ 'post_type' => 'angie_snippet', 'post_title' => 'Reader fixture', 'post_name' => 'reader-fixture', 'post_status' => 'draft' ], true );
angie_check( ! is_wp_error( $id ), 'Cannot create snippet fixture.' );
$source = "<?php\nthrow new RuntimeException('Reading must not execute this source');\n// Contact button: Send — שלום\n";
$files = [ [ 'name' => 'main.php', 'content_b64' => base64_encode( $source ) ] ];
foreach ( [ 'contact button.js', 'כפתור.js', "cafe\u{0301}.js" ] as $filename ) {
	$files[] = [ 'name' => $filename, 'content_b64' => base64_encode( '// ' . $filename ) ];
}
update_post_meta( $id, '_angie_snippet_files', $files );
update_post_meta( $id, '_unrelated_private_meta', 'must not be returned' );
$before = get_post_meta( $id );
angie_check( '' === get_post( $id )->post_content, 'Fixture must reproduce empty post_content.' );
$requests = [];
add_filter( 'rest_pre_dispatch', static function ( $result, $server, $request ) use ( &$requests ) {
	$requests[] = [ $request->get_method(), $request->get_route() ];
	return $result;
}, 10, 3 );

$listing = angie_call( [ 'id' => $id ] );
angie_check( $listing['data']['files'][0]['name'] === 'main.php', 'List stored filenames.' );
angie_check( ! isset( $listing['data']['files'][0]['content'] ), 'Listing must not bulk-read source.' );
$result = angie_call( [ 'id' => $id, 'filename' => 'main.php' ] );
angie_check( $result['data']['content'] === $source, 'Read exact decoded source including Unicode.' );
angie_check( $result['source'] === 'stored_snippet_files_not_verified_production', 'Do not claim this is deployed source.' );
angie_check( false === strpos( wp_json_encode( $result ), 'must not be returned' ), 'Do not expose unrelated metadata.' );
$identifier = ANGIE_VERSION === '1.1.0' ? 'reader-fixture' : (string) $id;
angie_check( $requests === [ [ 'GET', '/angie/v1/snippets/' . $identifier . '/files' ], [ 'GET', '/angie/v1/snippets/' . $identifier . '/files/main.php' ] ], 'Use the installed API route and GET only.' );

foreach ( array_slice( $listing['data']['files'], 1 ) as $file ) {
	$result = angie_call( [ 'id' => $id, 'filename' => $file['name'] ] );
	angie_check( $result['data']['content'] === '// ' . $file['name'], 'Read listed filenames with spaces and Unicode exactly.' );
}
angie_check( count( $listing['data']['files'] ) === count( $files ), 'List every stored filename.' );

angie_call( [ 'id' => $id, 'filename' => 'missing.php' ], true );
foreach ( [ '', '../main.php', '/etc/passwd', 'main.php/../../publish', 'main.php?include_content=true', '%2e%2e', "main.php\n", "main.php\0", 'folder\\main.php' ] as $filename ) {
	angie_call( [ 'id' => $id, 'filename' => $filename ], true );
}
angie_call( [ 'id' => 0 ], true );
angie_call( [ 'id' => -1 ], true );
angie_call( [ 'id' => PHP_INT_MAX ], true );
$page = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Not a snippet' ] );
angie_call( [ 'id' => $page ], true );
$editor = wp_insert_user( [ 'user_login' => 'angie-reader', 'user_pass' => wp_generate_password(), 'role' => 'editor' ] );
angie_check( ! is_wp_error( $editor ), 'Cannot create non-admin fixture.' );
foreach ( [ 0, $editor ] as $user_id ) {
	wp_set_current_user( $user_id );
	angie_call( [ 'id' => $id ], true );
}
wp_set_current_user( $admin->ID );
wp_delete_user( $editor );

$deny = static function ( $endpoints ) {
	foreach ( $endpoints as $route => &$handlers ) {
		if ( 0 === strpos( $route, '/angie/v1/snippets/' ) ) {
			foreach ( $handlers as &$handler ) {
				if ( is_array( $handler ) && isset( $handler['permission_callback'] ) ) {
					$handler['permission_callback'] = static function () { return new WP_Error( 'angie_test_denied', 'Angie denied access.', [ 'status' => 403 ] ); };
				}
			}
			unset( $handler );
		}
	}
	return $endpoints;
};
add_filter( 'rest_endpoints', $deny );
$denied = angie_call( [ 'id' => $id, 'filename' => 'main.php' ], true );
angie_check( false !== strpos( $denied['content'][0]['text'], 'Angie denied access.' ), 'Preserve native permission denial.' );
remove_filter( 'rest_endpoints', $deny );
$unsupported = static function ( $endpoints ) {
	unset( $endpoints['/angie/v1/snippets/(?P<id>\d+)/files'], $endpoints['/angie/v1/snippets/(?P<slug>[a-zA-Z0-9_-]+)/files'] );
	return $endpoints;
};
add_filter( 'rest_endpoints', $unsupported );
angie_call( [ 'id' => $id ], true );
remove_filter( 'rest_endpoints', $unsupported );
angie_check( $before === get_post_meta( $id ), 'Reads must not change snippet metadata.' );
update_post_meta( $id, '_angie_snippet_files', [ [ 'name' => 'main.php', 'content_b64' => base64_encode( str_repeat( 'x', 131073 ) ) ] ] );
$oversized = angie_call( [ 'id' => $id, 'filename' => 'main.php' ], true );
angie_check( false !== strpos( $oversized['content'][0]['text'], '128 KB' ), 'Reject oversized source output.' );
foreach ( $requests as [ $method, $route ] ) {
	angie_check( 'GET' === $method && false !== strpos( $route, '/files' ), 'Never call validation or mutation endpoints.' );
}
angie_check( ! is_dir( WP_CONTENT_DIR . '/angie-snippets/dev/snippet-' . $id ) && ! is_dir( WP_CONTENT_DIR . '/angie-snippets/prod/snippet-' . $id ), 'Reading must not deploy files.' );
wp_delete_post( $id, true );
wp_delete_post( $page, true );
deactivate_plugins( 'angie/angie.php' );
fwrite( STDOUT, 'OK (Angie ' . ANGIE_VERSION . ', WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n" );
