<?php
/** Post content must survive the complete packaged-plugin HTTP path. */
$actor_id = wp_insert_user( [ 'user_login' => 'content-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
frontman_runtime_assert( is_int( $actor_id ), 'Content actor creation failed' );
$actor = new WP_User( $actor_id );
$cookie = wp_generate_auth_cookie( $actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
wp_set_current_user( $actor_id );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $input, bool $error = false ) use ( $cookie, $nonce ): array {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $input ] );
	frontman_runtime_assert( 200 === $response['status'] && $error === $response['body']['isError'], 'Unexpected content outcome: ' . json_encode( $response ) );
	return $error ? $response['body'] : json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$content = '<!-- wp:html --><script src="https://js-eu1.hsforms.net/forms/embed/developer/26914208.js" defer data-region="eu1"></script><div class="hs-form-html" data-portal-id="26914208">Été 日本語 \\path\\file "quoted"</div><!-- /wp:html -->';
$base = [ 'title' => 'Authorized embed', 'content' => $content, 'post_type' => 'page', 'status' => 'publish' ];
$created = $call( 'wp_create_post', $base );
$id = $created['id'];
frontman_runtime_assert( $content === $created['after']['content'] && $content === $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Create lost raw markup' );
$permalink = $created['permalink'];
$path = parse_url( $permalink, PHP_URL_PATH ) . ( false !== strpos( $permalink, '?' ) ? '?' . parse_url( $permalink, PHP_URL_QUERY ) : '' );
$rendered = frontman_runtime_http( 'GET', $path );
frontman_runtime_assert( 200 === $rendered['status'] && false !== strpos( $rendered['body'], '<script src="https://js-eu1.hsforms.net/forms/embed/developer/26914208.js" defer data-region="eu1"></script>' ) && false !== strpos( $rendered['body'], '<div class="hs-form-html" data-portal-id="26914208">' ), 'Published embed missing from rendered HTML' );
$next = $content . "\n<p>Updated \\slash</p>";
$updated = $call( 'wp_update_post', [ 'id' => $id, 'content' => $next ] );
frontman_runtime_assert( $content === $updated['before']['content'] && $next === $updated['after']['content'], 'Update lost raw markup' );
$title_only = $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Title only' ] );
frontman_runtime_assert( $next === $title_only['after']['content'], 'Title-only edit changed content' );
$count = static function() use ( $wpdb ): int { return (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->posts}" ); };
$before = $call( 'wp_read_post', [ 'id' => $id ] );
$before_count = $count();
$missing = $call( 'wp_create_post', [ 'title' => 'Missing content' ], true );
frontman_runtime_assert( false !== strpos( $missing['content'][0]['text'], 'content is required' ) && $before_count === $count(), 'Missing create content lacked explicit error or wrote state' );
foreach ( [ null, false, 123, [], [ 'unexpected' => 'object' ] ] as $bad ) {
	$call( 'wp_create_post', [ 'title' => 'Malformed', 'content' => $bad ], true );
	$call( 'wp_update_post', [ 'id' => $id, 'title' => 'Must not persist', 'content' => $bad ], true );
	frontman_runtime_assert( $before_count === $count() && $before === $call( 'wp_read_post', [ 'id' => $id ] ), 'Malformed content caused a write' );
}
$actor->add_cap( 'unfiltered_html', false );
foreach ( [ 'wp_create_post' => $base, 'wp_update_post' => [ 'id' => $id, 'title' => 'Must not persist', 'content' => $content ] ] as $name => $input ) {
	$error = $call( $name, $input, true );
	frontman_runtime_assert( false !== strpos( $error['content'][0]['text'], 'unfiltered_html' ), 'Denied HTML error missing explanation' );
	frontman_runtime_assert( $before_count === $count() && $before === $call( 'wp_read_post', [ 'id' => $id ] ), 'Denied HTML caused a write' );
}
foreach ( [ [ 'title' => 'Restricted title only' ], [ 'status' => 'draft' ] ] as $edit ) {
	$call( 'wp_update_post', [ 'id' => $id ] + $edit, true );
	frontman_runtime_assert( $before === $call( 'wp_read_post', [ 'id' => $id ] ), 'Restricted omitted-content edit destroyed stored embed or changed fields' );
}
$safe = '<!-- wp:paragraph --><p>Allowed É 日本語 \\path</p><!-- /wp:paragraph -->';
$restricted = $call( 'wp_create_post', [ 'title' => 'Restricted safe', 'content' => $safe ] );
frontman_runtime_assert( $safe === $restricted['after']['content'], 'Restricted safe content changed' );
$safe .= '<p>Updated</p>';
$restricted_update = $call( 'wp_update_post', [ 'id' => $restricted['id'], 'content' => $safe ] );
frontman_runtime_assert( $safe === $restricted_update['after']['content'], 'Restricted safe update changed' );
$safe_title = $call( 'wp_update_post', [ 'id' => $restricted['id'], 'title' => 'Restricted safe title only' ] );
frontman_runtime_assert( $safe === $safe_title['after']['content'] && 'Restricted safe title only' === $safe_title['after']['title'], 'Restricted safe title-only edit failed or changed content' );
$actor->remove_cap( 'unfiltered_html' );
foreach ( [ 'wp_create_post' => [ 'content' => $content ], 'wp_update_post' => [ 'id' => $id, 'content' => $next ] ] as $name => $input ) {
	$error = $call( $name, $input + [ 'title' => 'Frontman transformed content fixture' ], true );
	$message = $error['content'][0]['text'];
	frontman_runtime_assert( 1 === preg_match( '/Post (\d+) was saved/', $message, $match ) && false !== strpos( $message, 'readback' ) && false !== strpos( $message, 'no rollback' ), 'Transformed save claimed success or hid post ID' );
	$actual = $call( 'wp_read_post', [ 'id' => (int) $match[1] ] );
	frontman_runtime_assert( $input['content'] . '<p>Plugin transformation</p>' === $actual['content'], 'Native/plugin filter disabled or partial write missing' );
}
echo "Post content HTTP preservation, validation, capability and partial-save checks passed.\n";
