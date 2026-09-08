<?php

if ( ! defined( 'ABSPATH' ) ) {
	throw new RuntimeException( 'WordPress must be loaded before the runtime test.' );
}

function frontman_runtime_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

function frontman_runtime_http( string $method, string $path, string $cookie = '', ?string $nonce = null, ?string $body = null, string $test = '' ): array {
	$headers = [ 'Host: frontman-runtime.example.test' ];
	$headers[] = '' === $test ? '' : 'X-Frontman-Seo-Test: ' . $test;
	if ( '' !== $cookie ) {
		$headers[] = 'Cookie: ' . LOGGED_IN_COOKIE . '=' . $cookie;
	}
	if ( null !== $nonce ) {
		$headers[] = 'X-WP-Nonce: ' . $nonce;
	}
	$response = file_get_contents(
		'http://127.0.0.1' . $path,
		false,
		stream_context_create( [ 'http' => [
			'content' => $body ?? '',
			'header' => implode( "\r\n", array_filter( $headers ) ) . "\r\nContent-Type: application/json\r\n",
			'ignore_errors' => true, 'follow_location' => 0,
			'method' => $method,
		] ] )
	);
	preg_match_all( '/^HTTP\/\S+\s+(\d{3})/m', implode( "\n", $http_response_header ?? [] ), $status );
	preg_match( '/<title[^>]*>(.*?)<\/title>/is', (string) $response, $title );
	preg_match( "~<meta\\s+[^>]*name=[\"']description[\"'][^>]*content=([\"'])(.*?)\\1[^>]*>~is", (string) $response, $description );
	return [ 'body' => (string) $response, 'status' => (int) ( end( $status[1] ) ?: 0 ), 'title' => isset( $title[1] ) ? html_entity_decode( trim( wp_strip_all_tags( $title[1] ) ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) : null, 'description' => isset( $description[2] ) ? html_entity_decode( $description[2], ENT_QUOTES | ENT_HTML5, 'UTF-8' ) : null ];
}
function frontman_runtime_tool( string $cookie, ?string $nonce, array $request, ?string $raw = null, string $test = '' ): array {
	$response = frontman_runtime_http( 'POST', '/index.php/frontman/tools/call', $cookie, $nonce, $raw ?? wp_json_encode( $request ), $test );
	if ( 200 !== $response['status'] ) {
		return $response;
	}
	frontman_runtime_assert( 1 === preg_match( '/^data: (.+)$/m', $response['body'], $match ), 'Tool response contained no SSE data event.' );
	return [ 'body' => json_decode( $match[1], true, 512, JSON_THROW_ON_ERROR ), 'status' => 200 ];
}

$expected_wordpress_version = getenv( 'EXPECTED_WORDPRESS_VERSION' );
frontman_runtime_assert( false !== $expected_wordpress_version, 'Expected WordPress version was not provided.' );
frontman_runtime_assert( $expected_wordpress_version === get_bloginfo( 'version' ), 'Runtime WordPress version does not match the requested version.' );
frontman_runtime_assert( defined( 'FRONTMAN_VERSION' ), 'Frontman plugin was not activated.' );
frontman_runtime_assert( null !== Frontman_Tools::instance()->get( 'wp_list_navigation_menus' ), 'Plugin bootstrap did not register navigation tools during init.' );
frontman_runtime_assert( home_url( '/index.php/frontman' ) === Frontman_UI::url( '/frontman' ), 'Plain permalink URL skipped the front controller.' );
$http_context = stream_context_create( [ 'http' => [ 'ignore_errors' => true ] ] );
file_get_contents( 'http://127.0.0.1/index.php/frontman/tools', false, $http_context );
frontman_runtime_assert( false !== strpos( $http_response_header[0] ?? '', ' 401 ' ), 'Plain permalink API route did not reach Frontman.' );
file_get_contents( 'http://127.0.0.1/index.php/frontman/plugin-update', false, $http_context );
frontman_runtime_assert( false !== strpos( $http_response_header[0] ?? '', ' 401 ' ), 'Update status must require authentication.' );
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$plugin = plugin_basename( FRONTMAN_PLUGIN_FILE );
$admin = get_user_by( 'login', 'admin' );
$cookie = wp_generate_auth_cookie( $admin->ID, time() + HOUR_IN_SECONDS, 'logged_in' );
$authenticated_context = stream_context_create( [ 'http' => [
	'ignore_errors' => true,
	'header' => 'Cookie: ' . LOGGED_IN_COOKIE . '=' . $cookie,
] ] );
foreach ( [ false, true, false ] as $enabled ) {
	update_site_option( 'auto_update_plugins', $enabled ? [ $plugin ] : [] );
	set_site_transient( 'update_plugins', (object) [
		'last_checked' => time(),
		'checked' => array_map( static fn( $data ) => $data['Version'], get_plugins() ),
		'response' => $enabled ? [] : [ $plugin => (object) [ 'new_version' => '999.0.0' ] ],
	] );
	$response = file_get_contents( 'http://127.0.0.1/index.php/frontman/plugin-update', false, $authenticated_context );
	frontman_runtime_assert( false !== strpos( $http_response_header[0] ?? '', ' 200 ' ), 'Authenticated update status request failed.' );
	$status = json_decode( $response, true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( FRONTMAN_VERSION === $status['installedVersion'], 'Update endpoint reported the wrong installed version.' );
	frontman_runtime_assert( ( $enabled ? FRONTMAN_VERSION : '999.0.0' ) === $status['latestVersion'], 'Update endpoint did not use native WordPress update status.' );
	frontman_runtime_assert( $enabled === $status['autoUpdateEnabled'], 'Update endpoint did not reflect the saved auto-update setting.' );
}
update_option( 'permalink_structure', '/index.php/%postname%/' );
frontman_runtime_assert( home_url( '/index.php/frontman' ) === Frontman_UI::url( '/frontman' ), 'PATHINFO permalink URL skipped the front controller.' );

$block_tool = new Frontman_Tool_Blocks();
$content = '<!-- wp:group --><div class="wp-block-group"><!-- wp:paragraph --><p>Nested one</p><!-- /wp:paragraph --><!-- wp:group --><div class="wp-block-group"><!-- wp:paragraph --><p>Nested two</p><!-- /wp:paragraph --></div><!-- /wp:group --></div><!-- /wp:group --><!-- wp:paragraph --><p>Top level</p><!-- /wp:paragraph -->';
$post_id = wp_insert_post(
	[
		'post_type' => 'page',
		'post_status' => 'publish',
		'post_title' => 'Frontman WordPress Runtime',
		'post_content' => $content,
	],
	true
);
frontman_runtime_assert( ! is_wp_error( $post_id ), 'Could not create runtime block fixture.' );

$listed = $block_tool->list_blocks( [ 'post_id' => $post_id ] );
frontman_runtime_assert( 2 === $listed['block_count'], 'Top-level block count changed.' );
frontman_runtime_assert( 5 === $listed['total_block_count'], 'Nested blocks were not recursively listed.' );
frontman_runtime_assert( [ 0, 1, 0 ] === $listed['all_blocks'][3]['path'], 'Nested block path is incorrect.' );

$block_tool->update_block(
	[
		'post_id' => $post_id,
		'path' => [ 0, 1, 0 ],
		'block_markup' => '<!-- wp:paragraph --><p>Updated nested</p><!-- /wp:paragraph -->',
	]
);
$block_tool->insert_block(
	[
		'post_id' => $post_id,
		'parent_path' => [ 0, 1 ],
		'index' => 1,
		'block_markup' => '<!-- wp:paragraph --><p>Inserted nested</p><!-- /wp:paragraph -->',
	]
);
$block_tool->move_block(
	[
		'post_id' => $post_id,
		'from_path' => [ 0, 0 ],
		'to_parent_path' => [ 0, 1 ],
		'to_index' => 0,
	]
);
$block_tool->delete_block( [ 'post_id' => $post_id, 'path' => [ 0, 0, 1 ], 'confirm' => true ] );

$saved_content = get_post( $post_id )->post_content;
frontman_runtime_assert( false !== strpos( $saved_content, 'Nested one' ), 'Moving a nested block lost its content.' );
frontman_runtime_assert( false !== strpos( $saved_content, 'Inserted nested' ), 'Nested insertion was not serialized.' );
frontman_runtime_assert( false === strpos( $saved_content, 'Updated nested' ), 'Nested deletion was not serialized.' );
frontman_runtime_assert( false !== strpos( $saved_content, 'Top level' ), 'Nested mutations lost a top-level sibling.' );

$menu_tool = new Frontman_Tool_Menus();
$registry = new Frontman_Tools();
$menu_tool->register( $registry );
$navigation_markup = '<!-- wp:navigation-link {"label":"Home","url":"/"} /-->';
$sanitized_navigation = $registry->sanitize_input(
	'wp_create_navigation_menu',
	[ 'title' => 'Runtime Navigation', 'content' => $navigation_markup ]
);
frontman_runtime_assert( $navigation_markup === $sanitized_navigation['content'], 'Tool sanitization changed navigation block markup.' );
$created = $menu_tool->create_navigation_menu(
	[
		'title' => 'Runtime Navigation',
		'content' => $navigation_markup,
	]
);
frontman_runtime_assert( 'wp_navigation' === get_post_type( $created['id'] ), 'Navigation tool did not create a wp_navigation post.' );

$updated = $menu_tool->update_navigation_menu(
	[
		'id' => $created['id'],
		'title' => 'Updated Runtime Navigation',
		'content' => '<!-- wp:navigation-link {"label":"About","url":"/about"} /-->',
	]
);
frontman_runtime_assert( 'Updated Runtime Navigation' === $updated['after']['title'], 'Navigation tool did not update the title.' );
frontman_runtime_assert( 1 <= count( $menu_tool->list_navigation_menus( [] ) ), 'Navigation tool did not list wp_navigation posts.' );

$deleted = $menu_tool->delete_navigation_menu( [ 'id' => $created['id'], 'confirm' => true ] );
frontman_runtime_assert( 'Updated Runtime Navigation' === $deleted['before']['title'], 'Navigation deletion did not preserve its snapshot.' );
frontman_runtime_assert( null === get_post( $created['id'] ), 'Navigation tool did not permanently delete the post.' );
$yoast = getenv( 'EXPECTED_YOAST_VERSION' );
if ( false === $yoast || '' === $yoast ) {
	frontman_runtime_assert( null === Frontman_Tools::instance()->get( 'wp_read_seo' ), 'SEO tools were registered without Yoast.' );
	return;
}
frontman_runtime_assert( defined( 'WPSEO_VERSION' ) && $yoast === WPSEO_VERSION, 'Loaded Yoast version differs from the verified package.' );
$runtime_permalink = get_option( 'permalink_structure' );
$wp_rewrite->set_permalink_structure( '' );
wp_set_current_user( $admin->ID );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
wp_set_current_user( 0 );
$catalog   = json_decode( frontman_runtime_http( 'GET', '/index.php/frontman/tools', $cookie )['body'], true, 512, JSON_THROW_ON_ERROR );
$seo_names = array_values( array_filter( array_column( $catalog['tools'], 'name' ), static fn( string $name ): bool => false !== strpos( $name, 'seo' ) || false !== strpos( $name, 'yoast' ) ) );
frontman_runtime_assert( [ 'wp_read_seo', 'wp_update_seo' ] === $seo_names, 'SEO catalog is not provider-neutral.' );
$fixtures = [];
foreach ( [ [ 'post', 'publish' ], [ 'page', 'publish' ], [ 'frontman_seo_item', 'publish' ], [ 'post', 'draft' ], [ 'post', 'private' ] ] as [ $type, $status ] ) {
	$id = wp_insert_post( [ 'post_type' => $type, 'post_status' => $status, 'post_title' => "Runtime $type $status", 'post_content' => 'Unchanged body' ], true );
	frontman_runtime_assert( ! is_wp_error( $id ), "Could not create $type/$status SEO fixture." );
	update_post_meta( $id, '_frontman_runtime_unrelated', 'keep' );
	$fixtures[] = [ 'id' => $id, 'status' => $status, 'title' => get_the_title( $id ), 'type' => $type ];
}
$snapshot = static function ( int $id ) use ( $wpdb ): array {
	return [
		'post' => $wpdb->get_row( $wpdb->prepare( "SELECT post_title, post_content, post_status, post_type FROM {$wpdb->posts} WHERE ID = %d", $id ), ARRAY_A ),
		'unrelated' => $wpdb->get_var( $wpdb->prepare( "SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_frontman_runtime_unrelated'", $id ) ),
		'options' => $wpdb->get_results( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name IN ('blogname','blogdescription','wpseo_titles','wpseo_social') ORDER BY option_name", ARRAY_A ),
		'title' => $wpdb->get_var( $wpdb->prepare( "SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_title'", $id ) ),
		'description' => $wpdb->get_var( $wpdb->prepare( "SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_metadesc'", $id ) ),
	];
};
$target = $fixtures[0]['id']; $unchanged = $snapshot( $target );
$valid             = [ 'name' => 'wp_update_seo', 'arguments' => [ 'id' => $target, 'title' => 'Blocked' ] ];
$subscriber_cookie = wp_generate_auth_cookie( wp_create_user( 'runtime-subscriber', wp_generate_password(), 'runtime-subscriber@example.test' ), time() + HOUR_IN_SECONDS, 'logged_in' );
$invalid = [
	frontman_runtime_tool( '', null, $valid ),
	frontman_runtime_tool( $subscriber_cookie, null, $valid ),
	frontman_runtime_tool( $cookie, null, $valid ),
	frontman_runtime_tool( $cookie, 'invalid', $valid ),
];
frontman_runtime_assert( [ 401, 403, 403, 403 ] === array_column( $invalid, 'status' ), 'Authentication or nonce checks allowed an SEO mutation.' );
foreach ( [ [ 'id' => (string) $target, 'title' => 'Bad type' ], [ 'id' => $target, 'title' => 'Bad key', 'meta_key' => '_private' ] ] as $arguments ) {
	$result = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_update_seo', 'arguments' => $arguments ] );
	frontman_runtime_assert( true === $result['body']['isError'], 'Invalid SEO arguments were accepted.' );
}
$malformed = frontman_runtime_tool( $cookie, $nonce, [], '{"name":"wp_update_seo","arguments":{"id":' . $target . ',"title":"bad' . "\xC3\x28" . '"}}' );
frontman_runtime_assert( true === $malformed['body']['isError'], 'Malformed SEO JSON was accepted.' );
frontman_runtime_assert( $unchanged === $snapshot( $target ), 'Rejected requests changed SQL state.' );
$failure = [ 'name' => 'wp_update_seo', 'input' => [ 'id' => $target, 'title' => 'Partial', 'description' => 'Description' ] ];
frontman_runtime_assert( true === frontman_runtime_tool( $cookie, $nonce, $failure, null, 'fail-sanitizer' )['body']['isError'] && $unchanged === $snapshot( $target ), 'Second-field preflight failure wrote state.' );
$silent = frontman_runtime_tool( $cookie, $nonce, $failure, null, 'silent-title' )['body'];
frontman_runtime_assert( true === $silent['isError'] && $unchanged === $snapshot( $target ), 'Silent first-write failure wrote state or allowed the next write.' );
$partial = frontman_runtime_tool( $cookie, $nonce, $failure, null, 'fail-write' )['body']; $partial_state = $snapshot( $target );
frontman_runtime_assert( true === $partial['isError'] && 'Partial [runtime-filter]' === $partial_state['title'] && null === $partial_state['description'], 'Second-field failure did not preserve only the first write.' );
frontman_runtime_assert( false !== strpos( $partial['content'][0]['text'], '"before":{"title":"","description":""}' ) && false !== strpos( $partial['content'][0]['text'], '"actualAfter":{"title":"Partial [runtime-filter]","description":""}' ), 'Partial error snapshots are inaccurate.' );
foreach ( [ 'deny-object', 'deny-meta' ] as $denial ) {
	$denied = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_read_seo', 'arguments' => [ 'id' => $target ] ], null, $denial )['body'];
	frontman_runtime_assert( true === $denied['isError'] && false === strpos( $denied['content'][0]['text'], 'Partial' ) && $partial_state === $snapshot( $target ), 'Denied read disclosed or changed SEO state.' );
}
frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_update_seo', 'input' => [ 'id' => $target, 'title' => '' ] ] );
$read_failure = frontman_runtime_tool( $cookie, $nonce, $failure, null, 'fail-read' )['body']; $read_failure_state = $snapshot( $target );
frontman_runtime_assert( true === $read_failure['isError'] && 'Partial [runtime-filter]' === $read_failure_state['title'] && null === $read_failure_state['description'], 'Failed first-field read-back allowed the next write: ' . wp_json_encode( $read_failure_state ) );
frontman_runtime_assert( $unchanged['post'] === $read_failure_state['post'] && $unchanged['unrelated'] === $read_failure_state['unrelated'] && $unchanged['options'] === $read_failure_state['options'], 'Failure paths changed core, unrelated, or option state.' );
frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_update_seo', 'input' => [ 'id' => $target, 'title' => '' ] ] );
$safety = static fn( array $state ): array => [ $state['post'], $state['unrelated'], $state['options'] ];
foreach ( $fixtures as $fixture ) {
	$id      = $fixture['id'];
	$request = static fn( array $arguments ): array => frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_update_seo', 'input' => $arguments ] )['body'];
	$safe    = $safety( $snapshot( $id ) );
	$read    = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_read_seo', 'arguments' => [ 'id' => $id ] ] )['body'];
	$read    = json_decode( $read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( $id === $read['id'] && 'yoast' === $read['provider'] && '' === $read['title'] && '' === $read['description'], 'SEO read contract failed.' );
	$default = 'publish' === $fixture['status'] ? frontman_runtime_http( 'GET', str_replace( home_url(), '', get_permalink( $id ) ), '', null, null, 'render' ) : null;
	$updated = json_decode( $request( [ 'id' => $id, 'description' => 'Runtime “Café” \\ path' ] )['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	$updated = json_decode( $request( [ 'id' => $id, 'title' => 'SEO %%title%% — "Café" \\ path' ] )['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( 'SEO %%title%% — "Café" \\ path [runtime-filter]' === $updated['after']['title'] && 'Runtime “Café” \\ path' === $updated['after']['description'], 'Title-only update changed the seeded description or skipped custom sanitization.' );
	$readback = json_decode( frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wp_read_seo', 'arguments' => [ 'id' => $id ] ] )['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( $updated['after'] === [ 'title' => $readback['title'], 'description' => $readback['description'] ], 'Quotes, slashes, or Unicode changed on persisted read-back.' );
	frontman_runtime_assert( $safe === $safety( $snapshot( $id ) ), 'Successful SEO update changed core, unrelated, or option SQL state.' );
	$repeat = json_decode( $request( [ 'id' => $id, 'title' => 'SEO %%title%% — "Café" \\ path', 'description' => 'Runtime “Café” \\ path' ] )['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( false === $repeat['changed'], 'Repeated SEO update was not idempotent.' );
	if ( 'publish' === $fixture['status'] ) {
		$html = frontman_runtime_http( 'GET', str_replace( home_url(), '', get_permalink( $id ) ), '', null, null, 'render' );
		frontman_runtime_assert( false !== strpos( $html['title'], 'SEO ' . $fixture['title'] . ' — "Café"' ), 'A later request did not render the SEO title tag for ' . $fixture['type'] . '/' . $fixture['status'] . ': ' . var_export( $html['title'], true ) );
		frontman_runtime_assert( false !== strpos( $html['description'], 'Runtime “Café”' ), 'A later request did not render the SEO description meta tag.' );
	} else {
		$restricted = frontman_runtime_http( 'GET', str_replace( home_url(), '', get_permalink( $id ) ), '', null, null, 'render' );
		frontman_runtime_assert( 404 === $restricted['status'] && false === strpos( $restricted['body'], 'Café' ) && false === strpos( $restricted['body'], '\\ path' ), 'Restricted SEO data rendered anonymously.' );
	}
	$cleared = json_decode( $request( [ 'id' => $id, 'title' => '', 'description' => '' ] )['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	$repeat  = json_decode( $request( [ 'id' => $id, 'title' => '', 'description' => '' ] )['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( [ 'title' => '', 'description' => '' ] === $cleared['after'] && false === $repeat['changed'], 'SEO clear or repeated clear failed.' );
	frontman_runtime_assert( $safe === $safety( $snapshot( $id ) ), 'SEO clear changed core, unrelated, or option SQL state.' );
	if ( 'publish' === $fixture['status'] ) {
		$default_after_clear = frontman_runtime_http( 'GET', str_replace( home_url(), '', get_permalink( $id ) ), '', null, null, 'render' );
		frontman_runtime_assert( $default['title'] === $default_after_clear['title'] && null === $default_after_clear['description'], 'Clearing did not restore later rendered defaults: ' . wp_json_encode( [ 'before' => [ $default['title'], $default['description'] ], 'after' => [ $default_after_clear['title'], $default_after_clear['description'] ] ] ) );
	}
}
$wp_rewrite->set_permalink_structure( $runtime_permalink );
fwrite( STDOUT, "Yoast $yoast HTTP SEO checks passed.\n" );
