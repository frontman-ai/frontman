<?php

declare(strict_types=1);

require '/tmp/WordPressRuntimeTest.php';
require '/tmp/CustomCssRuntimeTest.php';
require '/tmp/ElementorSnapshotRuntimeTest.php';
require '/tmp/PostAuthorsRuntimeTest.php';

$permalink_structure = get_option( 'permalink_structure' );
try {
	delete_option( 'permalink_structure' );
	frontman_runtime_same( false, get_option( 'permalink_structure' ), 'Missing permalink option uses the native WordPress false value' );
	frontman_runtime_same( home_url( '/index.php/frontman' ), Frontman_UI::url( '/frontman' ), 'Missing permalink option preserves plain Frontman URLs in strict mode' );
} finally {
	if ( false === $permalink_structure ) {
		delete_option( 'permalink_structure' );
	} else {
		update_option( 'permalink_structure', $permalink_structure );
	}
}
$home = get_option( 'home' );
$request_uri = $_SERVER['REQUEST_URI'] ?? null;
try {
	update_option( 'home', untrailingslashit( $home ) . '/wordpress' );
	$router = new Frontman_Router( Frontman_Tools::instance(), new Frontman_UI() );
	foreach ( [ '/wordpress', '/wordpress?query=1', '/wordpress/' ] as $path ) {
		$_SERVER['REQUEST_URI'] = $path;
		ob_start();
		$router->intercept( new WP() );
		frontman_runtime_same( '', ob_get_clean(), 'The subdirectory home request passes through without a strict PHP path error: ' . $path );
	}
} finally {
	update_option( 'home', $home );
	if ( null === $request_uri ) {
		unset( $_SERVER['REQUEST_URI'] );
	} else {
		$_SERVER['REQUEST_URI'] = $request_uri;
	}
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
	frontman_runtime_same( 200, $response['status'], $name . ' HTTP status: ' . wp_json_encode( $response['body'] ) );
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
$elementor_post = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Elementor wire fixture', 'post_status' => 'draft' ], true );
frontman_runtime_assert( ! is_wp_error( $elementor_post ), 'Could not create Elementor wire fixture.' );
try {
	$generate = static function( array $input ) use ( $cookie, $nonce ) {
		$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_elementor_generate_element', 'arguments' => $input ] );
		frontman_runtime_same( 200, $response['status'], 'Elementor generation HTTP status' );
		frontman_runtime_same( false, $response['body']['isError'], 'Elementor generation succeeds: ' . wp_json_encode( $response['body'] ) );
		return json_decode( $response['body']['content'][0]['text'], false, 512, JSON_THROW_ON_ERROR );
	};
	$spacer = $generate( [ 'type' => 'widget', 'widget_type' => 'spacer' ] );
	frontman_runtime_assert( $spacer->settings instanceof stdClass && [] === (array) $spacer->settings, 'Empty settings must be a JSON object.' );
	$added = $call( 'wp_elementor_add_element', [ 'post_id' => $elementor_post, 'element' => $spacer ] );
	frontman_runtime_assert( $added['success'], 'Generated spacer must be addable.' );
	$companion = $generate( [ 'type' => 'widget', 'widget_type' => 'spacer' ] );
	$wrapped = $call( 'wp_elementor_wrap_element', [ 'post_id' => $elementor_post, 'element_id' => $added['element_id'], 'element_after' => $companion ] );
	frontman_runtime_assert( $wrapped['success'], 'Generated spacer must be usable as a wrap companion.' );
	wp_cache_delete( $elementor_post, 'post_meta' );
	$tree = Frontman_Elementor_Data::get_page_data( $elementor_post );
	frontman_runtime_same( [ $added['element_id'], $wrapped['added_element_id'] ], array_column( $tree[0]['elements'], 'id' ), 'Added and companion spacers persist in order.' );
	$row = $generate( [ 'type' => 'row', 'children' => [ [ 'elType' => 'container', 'settings' => (object) [], 'elements' => [ [ 'elType' => 'widget', 'widgetType' => 'spacer', 'settings' => (object) [], 'elements' => [] ] ] ] ] ] );
	frontman_runtime_assert( $row->elements[0]->settings instanceof stdClass && $row->elements[0]->elements[0]->settings instanceof stdClass, 'Empty descendant settings must be JSON objects.' );
	frontman_runtime_assert( $call( 'wp_elementor_add_element', [ 'post_id' => $elementor_post, 'element' => $row ] )['success'], 'Generated nested subtree must be addable.' );
	$heading = $generate( [ 'type' => 'heading', 'title' => 'Keep settings' ] );
	frontman_runtime_same( 'Keep settings', $heading->settings->title, 'Nonempty settings must be preserved.' );
	$with_list = $generate( [ 'type' => 'widget', 'widget_type' => 'spacer', 'settings' => [ 'items' => [] ] ] );
	frontman_runtime_same( [], $with_list->settings->items, 'List-valued settings must remain arrays.' );
} finally {
	wp_delete_post( $elementor_post, true );
}
foreach ( [ 'PostContentRuntimeTest.php', 'TemplateCreationRuntimeTest.php', 'PageTemplateRuntimeTest.php' ] as $file ) {
	( static function() use ( $file, $call, $reject, $actor, $cookie ): void { require '/tmp/' . $file; } )();
}
( static function() use ( $call, $actor, $cookie, $nonce ): void { require '/tmp/CustomizerRuntimeTest.php'; } )();

require_once ABSPATH . 'wp-admin/includes/template.php';
do_action( 'admin_init' );
$eligibility_render = static function(): string {
	ob_start();
	Frontman_Settings::render_settings();
	return ob_get_clean();
};
$siteurl = get_option( 'siteurl' );
$https = $_SERVER['HTTPS'] ?? null;
$passwords_before = WP_Application_Passwords::get_user_application_passwords( $actor_id );
try {
	update_option( 'siteurl', 'https://example.com/wordpress' );
	$_SERVER['HTTPS'] = 'on';
	update_option( 'frontman_mcp_enabled', false );
	frontman_runtime_assert( str_contains( $eligibility_render(), 'Enable MCP access' ), 'Disabled MCP explains how to proceed' );
	frontman_runtime_assert( str_contains( $eligibility_render(), 'including tools that change or delete site content' ), 'MCP disclosure includes destructive tools' );
	update_option( 'frontman_mcp_enabled', true );
	frontman_runtime_assert( ! str_contains( $eligibility_render(), 'Enable MCP access' ), 'Saved MCP setting updates feedback' );
	frontman_runtime_assert( ! str_contains( $eligibility_render(), 'Application Passwords are unavailable' ), 'Eligible administrator has no password blocker' );
	$_SERVER['HTTPS'] = 'off';
	frontman_runtime_assert( ! str_contains( $eligibility_render(), 'HTTPS site URL' ), 'HTTPS site remains eligible on an HTTP admin request' );
	$_SERVER['HTTPS'] = 'on';
	add_filter( 'wp_is_application_passwords_available_for_user', '__return_false' );
	frontman_runtime_assert( str_contains( $eligibility_render(), 'Application Passwords are unavailable' ), 'Disabled Application Passwords are explained' );
	remove_filter( 'wp_is_application_passwords_available_for_user', '__return_false' );
	$deny_password = static function( array $caps, string $cap ): array {
		return 'create_app_password' === $cap ? [ 'do_not_allow' ] : $caps;
	};
	add_filter( 'map_meta_cap', $deny_password, 10, 2 );
	frontman_runtime_assert( str_contains( $eligibility_render(), 'Application Passwords are unavailable' ), 'Password creation permission is required' );
	remove_filter( 'map_meta_cap', $deny_password, 10 );
	frontman_runtime_assert( ! str_contains( $eligibility_render(), 'Application Passwords are unavailable' ), 'Restored permission clears the blocker' );
	update_option( 'siteurl', 'http://example.com/wordpress' );
	frontman_runtime_assert( str_contains( $eligibility_render(), 'HTTPS site URL' ), 'HTTP site URL is explained' );
	frontman_runtime_same( true, (bool) get_option( 'frontman_mcp_enabled' ), 'Rendering does not change MCP setting' );
	frontman_runtime_same( $passwords_before, WP_Application_Passwords::get_user_application_passwords( $actor_id ), 'Rendering creates no credentials' );
} finally {
	remove_filter( 'wp_is_application_passwords_available_for_user', '__return_false' );
	update_option( 'siteurl', $siteurl );
	if ( null === $https ) { unset( $_SERVER['HTTPS'] ); } else { $_SERVER['HTTPS'] = $https; }
	delete_option( 'frontman_mcp_enabled' );
}

$connect = static function( string $method, string $auth_cookie, ?string $request_nonce, bool $tls = true ): array {
	return frontman_runtime_http( $method, '/index.php/frontman/mcp/connect', $auth_cookie, $request_nonce, '{}', '', '', 'wordpress_logged_in_' . md5( get_option( 'siteurl' ) ), $tls );
};
$mcp_status = static function( string $auth_cookie ): array {
	return frontman_runtime_http( 'GET', '/index.php/frontman/mcp/status', $auth_cookie, null, null, '', '', 'wordpress_logged_in_' . md5( get_option( 'siteurl' ) ), true );
};
$mcp_access = static function( string $action, string $method, string $auth_cookie, ?string $request_nonce ): array {
	return frontman_runtime_http( $method, '/index.php/frontman/mcp/' . $action, $auth_cookie, $request_nonce, '{}', '', '', 'wordpress_logged_in_' . md5( get_option( 'siteurl' ) ), true );
};
try {
	$secure_url = 'https://frontman-runtime.example.test/wordpress';
	update_option( 'siteurl', $secure_url );
	update_option( 'frontman_mcp_enabled', false );
	$before = WP_Application_Passwords::get_user_application_passwords( $actor_id );
	$page = frontman_runtime_http( 'GET', '/index.php/frontman', $cookie, null, null, '', '', 'wordpress_logged_in_' . md5( get_option( 'siteurl' ) ), true );
	frontman_runtime_same( 200, $page['status'], 'Administrator can open the Frontman page' );
	frontman_runtime_assert( 1 === preg_match( '~data-wordpress-settings-url="[^"]*/wp-admin/options-general\.php\?page=frontman-diagnostics"~', $page['body'] ), 'Runtime exposes the native settings URL' );
	$status = $mcp_status( $cookie );
	frontman_runtime_same( 200, $status['status'], 'Disabled MCP status is available to the administrator without a nonce' );
	frontman_runtime_same( false, json_decode( $status['body'], true )['enabled'], 'Status reports disabled MCP' );
	frontman_runtime_assert( false !== stripos( implode( "\n", $status['headers'] ), 'no-store' ), 'Status must not be stored' );
	frontman_runtime_same( 401, $mcp_status( '' )['status'], 'Status requires authentication' );
	$actor->set_role( 'subscriber' );
	frontman_runtime_same( 403, $mcp_status( $cookie )['status'], 'Status requires administrator access' );
	$actor->set_role( 'administrator' );
	wp_cache_delete( $actor_id, 'user_meta' );
	frontman_runtime_same( $before, WP_Application_Passwords::get_user_application_passwords( $actor_id ), 'Status creates no credentials' );
	$rejected = $connect( 'POST', $cookie, $nonce, false );
	frontman_runtime_same( 403, $rejected['status'], 'HTTP request must reject connection even with an HTTPS site URL' );
	frontman_runtime_same( 'frontman_https_required', json_decode( $rejected['body'], true )['code'], 'HTTP rejection identifies HTTPS requirement' );
	foreach ( [
		[ 'GET', $cookie, $nonce ],
		[ 'POST', '', $nonce ],
		[ 'POST', $cookie, null ],
		[ 'POST', $cookie, 'invalid' ],
	] as $request ) {
		frontman_runtime_assert( 200 !== $connect( ...$request )['status'], 'Unapproved connect request must fail' );
	}
	update_option( 'siteurl', 'http://frontman-runtime.example.test/wordpress' );
	$rejected = $connect( 'POST', $cookie, $nonce );
	frontman_runtime_same( 403, $rejected['status'], 'HTTP site URL must reject connection' );
	frontman_runtime_same( 'frontman_invalid_site_url', json_decode( $rejected['body'], true )['code'], 'Invalid site URL rejection has an actionable code' );
	update_option( 'siteurl', $secure_url );
	$actor->set_role( 'subscriber' );
	frontman_runtime_same( 403, $connect( 'POST', $cookie, $nonce )['status'], 'Non-administrator must be rejected' );
	$actor->set_role( 'administrator' );
	wp_cache_delete( $actor_id, 'user_meta' );
	frontman_runtime_same( $before, WP_Application_Passwords::get_user_application_passwords( $actor_id ), 'Rejected requests create no credentials' );
	wp_cache_delete( 'alloptions', 'options' );
	wp_cache_delete( 'notoptions', 'options' );
	wp_cache_delete( 'frontman_mcp_enabled', 'options' );
	frontman_runtime_same( false, (bool) get_option( 'frontman_mcp_enabled' ), 'Rejected requests do not enable MCP' );
	$response = $connect( 'POST', $cookie, $nonce );
	frontman_runtime_same( 200, $response['status'], 'Approved connection succeeds' );
	wp_cache_delete( 'alloptions', 'options' );
	wp_cache_delete( 'notoptions', 'options' );
	wp_cache_delete( 'frontman_mcp_enabled', 'options' );
	frontman_runtime_same( true, (bool) get_option( 'frontman_mcp_enabled' ), 'Approval enables MCP without a separate settings change' );
	frontman_runtime_assert( false !== stripos( implode( "\n", $response['headers'] ), 'no-store' ), 'Credential response must not be stored' );
	$result = json_decode( $response['body'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_same( [ 'catalog_url', 'call_url', 'username', 'password' ], array_keys( $result ), 'Connection response has the agreed schema' );
	$status = $mcp_status( $cookie );
	frontman_runtime_same( [ 'catalog_url' => $result['catalog_url'], 'enabled' => true ], json_decode( $status['body'], true ), 'Status reports the saved setting and exact catalog without credentials' );
	$wp_rewrite->init();
	$_SERVER['HTTPS'] = 'on';
	frontman_runtime_same( get_rest_url( null, 'frontman/v1/tools' ), $result['catalog_url'], 'Connection returns WordPress REST catalog URL' );
	frontman_runtime_same( get_rest_url( null, 'frontman/v1/tools/call' ), $result['call_url'], 'Connection returns WordPress REST call URL' );
	if ( null === $https ) { unset( $_SERVER['HTTPS'] ); } else { $_SERVER['HTTPS'] = $https; }
	frontman_runtime_same( $actor->user_login, $result['username'], 'Connection returns current username' );
	wp_cache_delete( $actor_id, 'user_meta' );
	$created = WP_Application_Passwords::get_user_application_passwords( $actor_id );
	frontman_runtime_same( count( $before ) + 1, count( $created ), 'Approval creates exactly one credential' );
	frontman_runtime_same( 'Frontman MCP', $created[0]['name'], 'Credential has a dedicated name' );
	$matches = method_exists( 'WP_Application_Passwords', 'check_password' )
		? WP_Application_Passwords::check_password( $result['password'], $created[0]['password'] )
		: wp_check_password( $result['password'], $created[0]['password'] );
	frontman_runtime_assert( $matches, 'Returned credential matches the stored WordPress password hash' );
	$auth = $result['username'] . ':' . $result['password'];
	$catalog = static function() use ( $auth ): array {
		return frontman_runtime_http( 'GET', '/?rest_route=/frontman/v1/tools', '', null, null, '', $auth, null, true );
	};
	frontman_runtime_same( 200, $catalog()['status'], 'Created password authenticates to the gateway over TLS' );
	foreach ( [ 'disable' => false, 'enable' => true ] as $action => $enabled ) {
		foreach ( [
			[ [ 'GET', $cookie, $nonce ], 404, [ 'error' => 'Not found' ] ],
			[ [ 'POST', '', $nonce ], 401, [ 'code' => 'frontman_not_authenticated' ] ],
			[ [ 'POST', $cookie, null ], 403, [ 'code' => 'frontman_missing_nonce' ] ],
			[ [ 'POST', $cookie, 'invalid' ], 403, [ 'code' => 'frontman_invalid_nonce' ] ],
		] as [ $request, $expected_status, $expected_body ] ) {
			$rejected = $mcp_access( $action, ...$request );
			frontman_runtime_same( $expected_status, $rejected['status'], 'Unapproved MCP access change status' );
			$body = json_decode( $rejected['body'], true, 512, JSON_THROW_ON_ERROR );
			foreach ( $expected_body as $key => $value ) {
				frontman_runtime_same( $value, $body[ $key ], 'Unapproved MCP access change response' );
			}
			frontman_runtime_same( ! $enabled, json_decode( $mcp_status( $cookie )['body'], true )['enabled'], 'Rejected request does not change MCP access' );
		}
		$actor->set_role( 'subscriber' );
		$rejected = $mcp_access( $action, 'POST', $cookie, $nonce );
		frontman_runtime_same( 403, $rejected['status'], 'Non-administrator cannot change MCP access' );
		frontman_runtime_same( 'frontman_forbidden', json_decode( $rejected['body'], true )['code'], 'Non-administrator rejection identifies permission failure' );
		$actor->set_role( 'administrator' );
		frontman_runtime_same( ! $enabled, json_decode( $mcp_status( $cookie )['body'], true )['enabled'], 'Non-administrator request does not change MCP access' );
		foreach ( [ 1, 2 ] as $_ ) {
			$access = $mcp_access( $action, 'POST', $cookie, $nonce );
			frontman_runtime_same( 200, $access['status'], 'MCP access change and repeated request succeed' );
			frontman_runtime_same( [ 'enabled' => $enabled ], json_decode( $access['body'], true ), 'Access response reports saved state' );
			frontman_runtime_assert( false !== stripos( implode( "\n", $access['headers'] ), 'no-store' ), 'Access response must not be stored' );
		}
		frontman_runtime_same( $enabled, json_decode( $mcp_status( $cookie )['body'], true )['enabled'], 'Status reflects access change' );
		frontman_runtime_same( $enabled ? 200 : 403, $catalog()['status'], 'Access change controls the existing credential' );
		wp_cache_delete( $actor_id, 'user_meta' );
		$current = WP_Application_Passwords::get_user_application_passwords( $actor_id );
		frontman_runtime_same( $created[0]['uuid'], $current[0]['uuid'], 'Access change preserves credential UUID' );
		frontman_runtime_same( $created[0]['password'], $current[0]['password'], 'Access change preserves credential hash' );
	}
	WP_Application_Passwords::delete_application_password( $actor_id, $created[0]['uuid'] );
	frontman_runtime_assert( 200 !== $catalog()['status'], 'Native credential revocation denies gateway access' );
} finally {
	if ( null === $https ) { unset( $_SERVER['HTTPS'] ); } else { $_SERVER['HTTPS'] = $https; }
	$actor->set_role( 'administrator' );
	WP_Application_Passwords::delete_all_application_passwords( $actor_id );
	update_option( 'siteurl', $siteurl );
	delete_option( 'frontman_mcp_enabled' );
}

$mcp_post = wp_insert_post( [ 'post_title' => 'MCP private fixture', 'post_content' => 'Private MCP bytes', 'post_status' => 'draft' ] );
$mcp_password = WP_Application_Passwords::create_new_application_password( $actor_id, [ 'name' => 'Runtime MCP' ] );
frontman_runtime_assert( is_array( $mcp_password ), 'Application Password creation failed' );
$mcp_credentials = 'landing-page-actor:' . $mcp_password[0];
$mcp_discover = static function( string $credentials, string $browser_cookie = '', ?string $browser_nonce = null ): array {
	return frontman_runtime_http( 'GET', '/?rest_route=/frontman/v1/tools', $browser_cookie, $browser_nonce, null, '', $credentials );
};
$mcp_request = static function( string $credentials, string $name = 'wp_read_post', ?int $id = null, string $browser_cookie = '', ?string $browser_nonce = null ) use ( $mcp_post ): array {
	return frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', $browser_cookie, $browser_nonce, wp_json_encode( [ 'name' => $name, 'arguments' => [ 'id' => $id ?? $mcp_post ] ] ), '', $credentials );
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
	foreach ( [ '0', '1' ] as $enabled ) {
		update_option( 'frontman_mcp_enabled', $enabled );
		frontman_runtime_same( '1' === $enabled ? 200 : 403, $mcp_discover( $mcp_credentials )['status'], 'Stored WordPress string flags retain their explicit MCP access semantics' );
	}
	update_option( 'frontman_mcp_enabled', true );
	$catalog = $mcp_discover( $mcp_credentials );
	frontman_runtime_same( 200, $catalog['status'], 'Application Password discovery without cookies succeeds' );
	$catalog = json_decode( $catalog['body'], true, 512, JSON_THROW_ON_ERROR );
	$browser_catalog = frontman_runtime_http( 'GET', '/index.php/frontman/tools', $cookie, $nonce, null );
	frontman_runtime_same( json_decode( $browser_catalog['body'], true )['tools'], $catalog['tools'], 'Discovery preserves the browser catalog and argument schemas' );
	$response = $mcp_request( $mcp_credentials, 'wp_read_post', $mcp_post );
	frontman_runtime_same( 200, $response['status'], 'Application Password HTTP request without cookies succeeds' );
	$result = json_decode( $response['body'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_same( false, $result['isError'], 'MCP read succeeds' );
	frontman_runtime_same( 'Private MCP bytes', json_decode( $result['content'][0]['text'], true )['content'], 'MCP preserves raw content' );
	$write = frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', '', null, wp_json_encode( [ 'name' => 'wp_update_post', 'arguments' => [ 'id' => $mcp_post, 'title' => 'MCP updated fixture' ] ] ), '', $mcp_credentials );
	frontman_runtime_same( 200, $write['status'], 'MCP write request succeeds' );
	frontman_runtime_same( false, json_decode( $write['body'], true )['isError'], 'MCP write succeeds' );
	frontman_runtime_same( 'MCP updated fixture', json_decode( json_decode( $mcp_request( $mcp_credentials )['body'], true )['content'][0]['text'], true )['title'], 'MCP read sees the write' );
	foreach ( [ false, true, 'false', 0, 1, null ] as $include_paths ) {
		$request = [ 'name' => 'wp_get_site_info', 'arguments' => [ 'include_installation_paths' => $include_paths ] ];
		$browser = frontman_runtime_tool( $cookie, $nonce, $request );
		$remote = frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', '', null, wp_json_encode( $request ), '', $mcp_credentials );
		$result = json_decode( $remote['body'], true, 512, JSON_THROW_ON_ERROR );
		if ( is_bool( $include_paths ) ) {
			frontman_runtime_same( 200, $remote['status'], 'Native JSON booleans remain valid through the strict REST boundary' );
			foreach ( [ $browser['body'], $result ] as $read ) {
				frontman_runtime_same( false, $read['isError'], 'Native JSON boolean succeeds on both transports' );
				$data = json_decode( $read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
				frontman_runtime_same( $include_paths, isset( $data['installation'] ), 'Both transports preserve the boolean opt-in without coercion' );
			}
		} else {
			frontman_runtime_same( true, $browser['body']['isError'], 'Browser rejects non-boolean opt-ins as tool errors' );
			frontman_runtime_same( 400, $remote['status'], 'REST rejects non-boolean opt-ins as input errors, not TypeErrors' );
			frontman_runtime_same( 'frontman_mcp_arguments', $result['code'], 'REST preserves the expected input error contract' );
		}
	}
	$elementor = new Frontman_Tools(); ( new Frontman_Tool_Elementor() )->register( $elementor );
	$float = $elementor->sanitize_input( 'wp_elementor_save_page_data', json_decode( '{"post_id":1,"data":[{"id":"a","elType":"widget","settings":{"slider":{"size":1.0}}}],"confirm":true}' ), true );
	frontman_runtime_same( 1.0, $float['data'][0]['settings']['slider']['size'], 'Nested free-form whole float retains its JSON type' );
	$button = [ 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [], 'elements' => [] ];
	$button_without_elements = [ 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [] ];
	$nested = [ 'elType' => 'container', 'elements' => [ [ 'elType' => 'container', 'elements' => [ $button ] ] ] ];
	$mixed = $nested;
	$mixed['id'] = '0';
	$mixed['elements'][0]['elements'][0]['id'] = ' supplied ';
	$companion = [ 'elType' => 'container', 'elements' => [ [ 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [ 'text' => 'New' ] ] ] ];
	$valid = [
		[ 'wp_elementor_list_pages', [ 'post_type' => 'context_test', 'text_search' => 'Book Demo', 'include_context' => true ] ],
		[ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => $nested ] ],
		[ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => $mixed ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'children' => [ $button ] ] ],
		[ 'wp_elementor_duplicate_element', [ 'post_id' => 47, 'element_id' => 'row', 'settings' => [ 'link' => [ 'url' => '/new' ] ] ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'settings' => [], 'children' => [ $button ] ] ],
		[ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => $button ] ],
		[ 'wp_elementor_wrap_element', [ 'post_id' => 47, 'element_id' => 'root4700', 'settings' => [], 'element_after' => $button ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'settings' => [], 'children' => [ $button_without_elements ] ] ],
		[ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => $button_without_elements ] ],
		[ 'wp_elementor_wrap_element', [ 'post_id' => 47, 'element_id' => 'root4700', 'settings' => [], 'element_after' => $button_without_elements ] ],
	];
	foreach ( [ 'a', 'b', 'c', 'row' ] as $anchor ) {
		$valid[] = [ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => [ 'elType' => 'container', 'elements' => [ [ 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [ 'text' => 'Original', 'link' => [ 'url' => '/old', 'external' => true ] ], 'elements' => [] ] ] ], 'after_element_id' => $anchor ] ];
	}
	foreach ( [ 'target', 'row', 'leaf' ] as $id ) {
		$wrap = [ 'post_id' => 47, 'element_id' => $id, 'settings' => [ 'flex_direction_mobile' => 'column', 'flex_wrap' => 'nowrap' ] ];
		$valid[] = [ 'wp_elementor_wrap_element', $wrap ];
		$valid[] = [ 'wp_elementor_wrap_element', $wrap + [ 'element_after' => $companion ] ];
	}
	foreach ( $valid as [ $name, $input ] ) {
		frontman_runtime_same( $input, $elementor->sanitize_input( $name, $input ), $name . ' preserves valid inputs' );
	}
	$invalid_root = array_replace( $button, [ 'settings' => [ 'bad' ] ] );
	$invalid_descendant = [ 'elType' => 'container', 'settings' => [], 'elements' => [ $invalid_root ] ];
	$invalid = [
		[ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => [ 'elType' => 'container', 'elements' => false ] ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'children' => false ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'children' => [ [ 'elType' => 'container', 'elements' => null ] ] ] ],
		[ 'wp_elementor_generate_element', [ 'type' => 'row', 'settings' => [ 'bad' ] ] ],
	];
	foreach ( [ $invalid_root, $invalid_descendant ] as $element ) {
		$invalid[] = [ 'wp_elementor_add_element', [ 'post_id' => 47, 'element' => $element ] ];
		$invalid[] = [ 'wp_elementor_generate_element', [ 'type' => 'row', 'children' => [ $element ] ] ];
		$invalid[] = [ 'wp_elementor_wrap_element', [ 'post_id' => 47, 'element_id' => 'root4700', 'element_after' => $element ] ];
	}
	foreach ( [ [ 'settings' => null ], [ 'settings' => 'bad' ], [ 'settings' => [ 1 ] ], [ 'element_after' => false ], [ 'element_after' => [ 'elType' => 'container', 'elements' => [ false ] ] ] ] as $input ) {
		$invalid[] = [ 'wp_elementor_wrap_element', $input + [ 'post_id' => 47, 'element_id' => 'target' ] ];
	}
	foreach ( $invalid as [ $name, $input ] ) {
		$rejected = false;
		try {
			$elementor->sanitize_input( $name, $input );
		} catch ( Frontman_Tool_Error $error ) {
			$rejected = true;
		}
		frontman_runtime_assert( $rejected, $name . ' rejects malformed input: ' . wp_json_encode( $input ) );
	}
	$before = $wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A );
	foreach ( [
		'{"title":"Rejected"}',
		'{"id":[' . $mcp_post . '],"title":"Rejected"}',
		'{"id":"' . $mcp_post . '","title":"Rejected"}',
		'{"id":' . $mcp_post . ',"title":"Rejected","tags":["1"]}',
		'{"id":' . $mcp_post . ',"title":"Rejected","tags":{}}',
	] as $index => $arguments ) {
		$name = 0 === $index ? 'wp_create_post' : 'wp_update_post';
		$browser = frontman_runtime_tool( $cookie, $nonce, [], '{"name":"' . $name . '","arguments":' . $arguments . '}' );
		frontman_runtime_assert( $browser['body']['isError'], 'Browser mutation must reject invalid arguments: ' . $arguments );
		$remote = frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', '', null, '{"name":"' . $name . '","arguments":' . $arguments . '}', '', $mcp_credentials );
		frontman_runtime_same( 400, $remote['status'], 'MCP mutation must reject invalid arguments: ' . $arguments );
		frontman_runtime_same( $before, $wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A ), 'Invalid mutation must not write posts or revisions' );
	}
	foreach ( [ '{"id":[999]}', '{"id":{}}', '{"id":null}', '{"id":true}', '{"id":"1"}', '{"id":1.0}', '{"id":1.5}', '{"id":0}', '{"id":-1}', '{"id":9223372036854775808}', '{"id":' . $mcp_post . ',"unexpected":true}', '{}', '[]', 'true', 'null' ] as $arguments ) {
		$browser = frontman_runtime_tool( $cookie, $nonce, [], '{"name":"wp_read_post","arguments":' . $arguments . '}' );
		frontman_runtime_assert( $browser['body']['isError'], 'Browser read must reject invalid arguments: ' . $arguments );
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
	foreach ( [ 'unknown', 'WP_READ_POST' ] as $name ) {
		$mcp_denied( $mcp_request( $mcp_credentials, $name ) );
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
