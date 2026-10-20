<?php
/** Native page assignment, preflight validation, and actual template/part rendering. */
$actor_id = wp_insert_user( [ 'user_login' => 'page-template-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
frontman_runtime_assert( is_int( $actor_id ), 'Page template actor creation failed' );
$cookie = wp_generate_auth_cookie( $actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
wp_set_current_user( $actor_id );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $input, bool $error = false ) use ( $cookie, $nonce ): array {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $input ] );
	frontman_runtime_assert( 200 === $response['status'] && $error === $response['body']['isError'], 'Unexpected page-template outcome: ' . json_encode( $response ) );
	return $error ? $response['body'] : json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$slug = 'frontman-assignment-template';
$part = 'frontman-assignment-header';
$call( 'wp_create_template', [ 'slug' => $part, 'type' => 'wp_template_part', 'area' => 'header', 'title' => 'Assignment header', 'content' => '<!-- wp:paragraph --><p>Frontman assignment HEADER</p><!-- /wp:paragraph -->' ] );
$markup = '<!-- wp:template-part ' . wp_json_encode( [ 'slug' => $part, 'theme' => get_stylesheet(), 'area' => 'header' ] ) . ' /--><!-- wp:paragraph --><p>Frontman assignment LAYOUT</p><!-- /wp:paragraph --><!-- wp:post-content /-->';
$call( 'wp_create_template', [ 'slug' => $slug, 'type' => 'wp_template', 'title' => 'Assignment layout', 'content' => $markup ] );
frontman_runtime_assert( array_key_exists( $slug, wp_get_theme()->get_page_templates( null, 'page' ) ), 'Custom block template absent from native available-page-template API' );
$base = [ 'title' => 'Assigned page', 'post_type' => 'page', 'content' => '<!-- wp:paragraph --><p>Frontman assignment BODY</p><!-- /wp:paragraph -->' ];
$created = $call( 'wp_create_post', $base + [ 'template' => $slug, 'status' => 'publish' ] );
$id = $created['id'];
frontman_runtime_assert( $slug === $created['after']['template'] && $slug === get_post_meta( $id, '_wp_page_template', true ) && $created['after'] === $call( 'wp_read_post', [ 'id' => $id ] ), 'Create did not persist/read actual assignment' );
$permalink = $created['permalink'];
$path = parse_url( $permalink, PHP_URL_PATH ) . ( false !== strpos( $permalink, '?' ) ? '?' . parse_url( $permalink, PHP_URL_QUERY ) : '' );
$rendered = frontman_runtime_http( 'GET', $path );
frontman_runtime_assert( 200 === $rendered['status'] && false !== strpos( $rendered['body'], 'Frontman assignment HEADER' ) && false !== strpos( $rendered['body'], 'Frontman assignment LAYOUT' ) && false !== strpos( $rendered['body'], 'Frontman assignment BODY' ), 'Assigned template/part/page workflow did not render' );
$omitted = $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Assignment omitted' ] );
frontman_runtime_assert( $slug === $omitted['after']['template'], 'Omission lost custom assignment' );
$reset = $call( 'wp_update_post', [ 'id' => $id, 'template' => 'default' ] );
clean_post_cache( $id );
frontman_runtime_assert( $slug === $reset['before']['template'] && 'default' === $reset['after']['template'] && 'default' === get_post_meta( $id, '_wp_page_template', true ), 'Explicit default did not reset assignment' );
$omitted_default = $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Default omitted' ] );
frontman_runtime_assert( 'default' === $omitted_default['after']['template'], 'Default omission changed assignment' );
$assigned = $call( 'wp_update_post', [ 'id' => $id, 'template' => $slug ] );
frontman_runtime_assert( 'default' === $assigned['before']['template'] && $slug === $assigned['after']['template'], 'Update did not assign custom block template' );
foreach ( [ [], [ 'template' => 'default' ] ] as $input ) {
	$plain = $call( 'wp_create_post', $base + $input );
	frontman_runtime_assert( 'default' === $plain['after']['template'], 'Create default/omission readback incorrect' );
}
$post = $call( 'wp_create_post', [ 'title' => 'Nonpage', 'content' => 'Nonpage' ] );
$count = static function() use ( $wpdb ): int { return (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->posts}" ); };
$before_count = $count();
$before = $call( 'wp_read_post', [ 'id' => $id ] );
foreach ( [ null, false, 42, [], '', 'frontman-missing-template', $part, 'index', '<b>' . $slug . '</b>' ] as $bad ) {
	$call( 'wp_create_post', $base + [ 'template' => $bad, 'status' => 'publish' ], true );
	$call( 'wp_update_post', [ 'id' => $id, 'template' => $bad, 'title' => 'Must not persist', 'content' => 'Must not persist', 'status' => 'draft' ], true );
	frontman_runtime_assert( $before_count === $count() && $before === $call( 'wp_read_post', [ 'id' => $id ] ), 'Rejected assignment caused a write' );
}
foreach ( [ 'post', 'fm_author_item' ] as $type ) { $call( 'wp_create_post', [ 'title' => 'Nonpage forbidden', 'content' => 'No write', 'post_type' => $type, 'template' => 'default' ], true ); }
$nonpage = $call( 'wp_read_post', [ 'id' => $post['id'] ] );
$call( 'wp_update_post', [ 'id' => $post['id'], 'title' => 'No write', 'template' => 'default' ], true );
frontman_runtime_assert( null === $nonpage['template'] && $nonpage === $call( 'wp_read_post', [ 'id' => $post['id'] ] ) && $before_count === $count(), 'Nonpage assignment accepted or wrote state' );
$unavailable = static function( array $templates ) use ( $slug ): array { unset( $templates[ $slug ] ); return $templates; };
add_filter( 'theme_page_templates', $unavailable );
try {
	$tool = new Frontman_Tool_Posts();
	foreach ( [ 'create', 'update' ] as $operation ) {
		try {
			if ( 'create' === $operation ) { $tool->create_post( $base + [ 'template' => $slug ] ); }
			else { $tool->update_post( [ 'id' => $id, 'title' => 'Unavailable no-write', 'template' => $slug ] ); }
			throw new RuntimeException( 'Unavailable template accepted' );
		} catch ( Frontman_Tool_Error $e ) { frontman_runtime_assert( false !== strpos( $e->getMessage(), 'not available' ), 'Wrong unavailable template error' ); }
	}
} finally { remove_filter( 'theme_page_templates', $unavailable ); }
frontman_runtime_assert( $before_count === $count() && $before === $call( 'wp_read_post', [ 'id' => $id ] ), 'Unavailable template rejection wrote state' );
$failure_title = 'Frontman blocked template fixture';
foreach ( [ 'create', 'reset', 'assign' ] as $failure ) {
	$input = 'create' === $failure ? array_merge( $base, [ 'title' => $failure_title, 'template' => $slug ] ) : [ 'id' => $id, 'title' => $failure_title, 'template' => 'reset' === $failure ? 'default' : $slug ];
	$error = $call( 'create' === $failure ? 'wp_create_post' : 'wp_update_post', $input, true );
	$message = $error['content'][0]['text'];
	frontman_runtime_assert( 1 === preg_match( '/Post (\d+) was saved/', $message, $match ) && false !== strpos( $message, 'template readback' ) && false !== strpos( $message, 'wp_read_post' ), 'Silent metadata failure claimed success or hid recovery ID' );
	$raw = $call( 'wp_read_post', [ 'id' => (int) $match[1] ] );
	frontman_runtime_assert( $failure_title === $raw['title'] && $input['template'] !== $raw['template'], 'Partial assignment error did not reflect persisted state' );
	if ( 'reset' === $failure ) { $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Allow metadata', 'template' => 'default' ] ); }
}
echo "Page-template assignment, native availability preflight, rendered template/part workflow and partial metadata-save checks passed.\n";
