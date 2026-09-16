<?php
/** Real packaged plugin HTTP author permissions and lookup privacy. */

$wp_rewrite->set_permalink_structure( '' );
$actor_id = wp_insert_user( [ 'user_login' => 'author-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
$target_id = wp_insert_user( [ 'user_login' => 'author-target', 'user_pass' => wp_generate_password(), 'role' => 'subscriber', 'display_name' => 'Author Duplicate' ] );
$twin_id = wp_insert_user( [ 'user_login' => 'author-twin', 'user_pass' => wp_generate_password(), 'role' => 'subscriber', 'display_name' => 'Author Duplicate' ] );
foreach ( [ $actor_id, $target_id, $twin_id ] as $id ) { frontman_runtime_assert( is_int( $id ), 'Author fixture creation failed' ); }
update_user_meta( $target_id, 'frontman_private_fixture', 'Must stay private' );
wp_update_user( [ 'ID' => $target_id, 'user_email' => 'email-only-author-token@example.test' ] );
$actor = new WP_User( $actor_id );
foreach ( [ 'create_fm_items', 'edit_fm_items', 'edit_others_fm_items', 'publish_fm_items', 'edit_published_fm_items', 'edit_private_fm_items', 'edit_fm_primitive' ] as $cap ) { $actor->add_cap( $cap ); }
$actor_cookie = wp_generate_auth_cookie( $actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
wp_set_current_user( $actor_id );
$_COOKIE[ LOGGED_IN_COOKIE ] = $actor_cookie;
$actor_nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $input, bool $error = false ) use ( $actor_cookie, $actor_nonce ): array {
	$response = frontman_runtime_tool( $actor_cookie, $actor_nonce, [ 'name' => $name, 'arguments' => $input ] );
	frontman_runtime_assert( 200 === $response['status'] && $error === $response['body']['isError'], 'Unexpected author tool outcome: ' . $name );
	return $error ? $response['body'] : json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$base = [ 'title' => 'Author original', 'content' => '<p>Original body</p>', 'post_type' => 'fm_author_item' ];
foreach ( [ [], [ 'author' => $actor_id ], [ 'author' => $target_id ] ] as $assignment ) {
	$created = $call( 'wp_create_post', array_merge( $base, $assignment ) );
	$id = $created['id']; $expected = $assignment['author'] ?? $actor_id;
	frontman_runtime_assert( $expected === $created['after']['author'] && $expected === $call( 'wp_read_post', [ 'id' => $id ] )['author'], 'Create author/default/read-back failed' );
}
$omitted = $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Omitted author' ] );
frontman_runtime_assert( $target_id === $omitted['before']['author'] && $target_id === $omitted['after']['author'], 'Omitted update overwrote author' );
foreach ( [ $actor_id, $target_id ] as $author ) {
	$updated = $call( 'wp_update_post', [ 'id' => $id, 'author' => $author ] );
	frontman_runtime_assert( $expected === $updated['before']['author'] && $author === $updated['after']['author'] && $author === $call( 'wp_read_post', [ 'id' => $id ] )['author'], 'Update snapshots/read-back author failed' );
	$expected = $author;
}
$fixture = $call( 'wp_create_post', $base )['id'];
$snapshot = static function( int $id ): array { clean_post_cache( $id ); return get_post( $id, ARRAY_A ); };
$count = static function( string $type = 'fm_author_item' ): int {
	wp_cache_flush();
	return (int) array_sum( (array) wp_count_posts( $type ) );
};
$unchanged = $snapshot( $fixture );
$combined = [ 'id' => $fixture, 'title' => 'Must not persist', 'content' => '<p>Must not persist</p>', 'status' => 'publish' ];
$reject_both = static function( array $override ) use ( $call, $base, $combined, $fixture, $snapshot, $count, $unchanged ): void {
	$before_count = $count();
	$call( 'wp_create_post', array_merge( $base, [ 'status' => 'publish' ], $override ), true );
	$call( 'wp_update_post', array_merge( $combined, $override ), true );
	frontman_runtime_assert( $before_count === $count() && $unchanged === $snapshot( $fixture ), 'Rejected combined request partially wrote a post' );
};
foreach ( [ (string) $target_id, 99999999 ] as $bad ) { $reject_both( [ 'author' => $bad ] ); }
foreach ( [ 'wp_create_post' => array_merge( $base, [ 'status' => 'publish' ] ), 'wp_update_post' => $combined ] as $name => $input ) {
	$input['author'] = 2.0;
	$before_count = $count();
	$response = frontman_runtime_tool( $actor_cookie, $actor_nonce, [], json_encode( [ 'name' => $name, 'arguments' => $input ], JSON_PRESERVE_ZERO_FRACTION ) );
	frontman_runtime_assert( true === $response['body']['isError'] && $before_count === $count() && $unchanged === $snapshot( $fixture ), 'Float author was coerced or wrote state' );
}
foreach ( [ 'create_fm_items', 'edit_fm_items', 'publish_fm_items', 'edit_others_fm_items' ] as $cap ) {
	$actor->add_cap( $cap, false );
	frontman_runtime_assert( user_can( $actor, 'manage_options' ) && ! user_can( $actor, $cap ), 'Custom denial fixture ineffective' );
	$before_count = $count();
	switch ( $cap ) {
		case 'create_fm_items': $call( 'wp_create_post', $base, true ); break;
		case 'edit_fm_items': $call( 'wp_update_post', $combined, true ); break;
		case 'publish_fm_items':
			$reject_both( [ 'author' => $actor_id ] );
			$reject_both( [ 'author' => $actor_id, 'status' => 'private' ] );
			break;
		case 'edit_others_fm_items': $reject_both( [ 'author' => $target_id ] ); break;
	}
	frontman_runtime_assert( $before_count === $count() && $unchanged === $snapshot( $fixture ), 'Permission check ran after write' );
	$actor->add_cap( $cap );
}
foreach ( [ 'publish', 'private' ] as $status ) {
	$id = $call( 'wp_create_post', array_merge( $base, [ 'status' => $status ] ) )['id'];
	$actor->add_cap( 'publish_fm_items', false );
	$receipt = $call( 'wp_update_post', [ 'id' => $id, 'status' => $status, 'author' => $target_id ] );
	frontman_runtime_assert( $status === $receipt['after']['status'] && $target_id === $receipt['after']['author'], 'Unchanged status incorrectly required publish permission' );
	$actor->add_cap( 'publish_fm_items' );
}
$primitive = wp_insert_post( [ 'post_title' => 'Primitive', 'post_status' => 'draft', 'post_type' => 'fm_primitive', 'post_author' => $target_id ], true );
frontman_runtime_assert( current_user_can( 'edit_post', $primitive ) && ! current_user_can( 'edit_others_fm_primitives' ), 'Primitive capability fixture ineffective' );
$call( 'wp_update_post', [ 'id' => $primitive, 'title' => 'Omission allowed' ] );
$primitive_before = $snapshot( $primitive );
$call( 'wp_update_post', [ 'id' => $primitive, 'title' => 'Rejected', 'author' => $target_id ], true );
frontman_runtime_assert( $primitive_before === $snapshot( $primitive ), 'Explicit unchanged other author bypassed permission' );
$unsupported = $call( 'wp_create_post', array_merge( $base, [ 'post_type' => 'fm_no_author' ] ) )['id'];
$unsupported_before = $snapshot( $unsupported );
$unsupported_count = $count( 'fm_no_author' );
$call( 'wp_create_post', array_merge( $base, [ 'post_type' => 'fm_no_author', 'author' => $actor_id ] ), true );
$call( 'wp_update_post', [ 'id' => $unsupported, 'author' => $actor_id, 'title' => 'Rejected', 'content' => 'Rejected', 'status' => 'publish' ], true );
frontman_runtime_assert( $unsupported_before === $snapshot( $unsupported ) && $unsupported_count === $count( 'fm_no_author' ), 'Unsupported authorship wrote state' );
update_post_meta( $fixture, '_elementor_edit_mode', 'builder' );
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-elementor-data.php';
try { ( new Frontman_Tool_Posts() )->update_post( array_merge( $combined, [ 'author' => $target_id ] ) ); throw new RuntimeException( 'Elementor overwrite accepted' ); }
catch ( Frontman_Tool_Error $e ) { frontman_runtime_assert( false !== strpos( $e->getMessage(), 'Elementor' ), 'Wrong Elementor error' ); }
frontman_runtime_assert( $unchanged === $snapshot( $fixture ), 'Elementor rejection wrote state' );

$lookup = [ 'search' => 'Author Duplicate', 'match_by' => 'display_name', 'per_page' => 1 ];
$first = $call( 'wp_find_users', $lookup );
$second = $call( 'wp_find_users', array_merge( $lookup, [ 'page' => 2 ] ) );
frontman_runtime_assert( [ 'users', 'page', 'per_page', 'total', 'total_pages' ] === array_keys( $first ) && 2 === $first['total'] && 2 === $first['total_pages'] && 1 === $first['page'] && 1 === $first['per_page'], 'Lookup pagination metadata' );
frontman_runtime_assert( [ $target_id, $twin_id ] === [ $first['users'][0]['id'], $second['users'][0]['id'] ], 'Duplicate names merged, guessed or unordered' );
frontman_runtime_assert( [] === $call( 'wp_find_users', array_merge( $lookup, [ 'page' => 3 ] ) )['users'], 'Out-of-range page not empty' );
foreach ( [ $first, $second ] as $result ) { foreach ( $result['users'] as $user ) { frontman_runtime_assert( [ 'id', 'login', 'display_name' ] === array_keys( $user ), 'Lookup leaked private fields' ); } }
frontman_runtime_assert( [] === $call( 'wp_find_users', [ 'search' => 'Author Duplicate', 'match_by' => 'login' ] )['users'], 'Display name leaked into login search' );
frontman_runtime_assert( [ $target_id ] === array_column( $call( 'wp_find_users', [ 'search' => 'author-target', 'match_by' => 'login' ] )['users'], 'id' ), 'Login match failed' );
foreach ( [ 'login', 'display_name' ] as $column ) {
	frontman_runtime_assert( [] === $call( 'wp_find_users', [ 'search' => 'email-only-author-token', 'match_by' => $column ] )['users'], 'Lookup implicitly searched email' );
}
$none = $call( 'wp_find_users', [ 'search' => 'nonexistent-author-token', 'match_by' => 'display_name' ] );
frontman_runtime_assert( [] === $none['users'] && 0 === $none['total'] && 0 === $none['total_pages'] && 20 === $none['per_page'], 'Empty/default lookup contract' );
foreach ( [ '%', '_', 'in*terior', "O'Neil", '"quoted"', '0' ] as $index => $literal ) {
	$id = wp_insert_user( [ 'user_login' => 'literal-author-' . $index, 'user_pass' => wp_generate_password(), 'display_name' => 'Needle ' . $literal . ' end' ] );
	$result = $call( 'wp_find_users', [ 'search' => ' ' . $literal . ' ', 'match_by' => 'display_name' ] );
	frontman_runtime_assert( [ $id ] === array_column( $result['users'], 'id' ), 'Literal wildcard/quote search broadened or changed' );
}
for ( $i = 0; $i < 21; $i++ ) { wp_insert_user( [ 'user_login' => 'bounded-author-' . $i, 'user_pass' => wp_generate_password(), 'display_name' => 'Bounded Author' ] ); }
$bounded = $call( 'wp_find_users', [ 'search' => 'Bounded Author', 'match_by' => 'display_name' ] );
frontman_runtime_assert( 20 === count( $bounded['users'] ) && 21 === $bounded['total'] && 2 === $bounded['total_pages'], 'Lookup exceeded bound or lost count' );
foreach ( [ [ 'search' => "\u{2003}*\u{2003}" ], [ 'page' => '1' ] ] as $bad ) { $call( 'wp_find_users', array_merge( $lookup, $bad ), true ); }
$actor->add_cap( 'list_users', false );
$call( 'wp_find_users', $lookup, true );
foreach ( [ $actor_id, $target_id ] as $denied_id ) {
	wp_set_current_user( 0 );
	wp_set_current_user( $denied_id );
	$queries_before = $wpdb->num_queries;
	try { ( new Frontman_Tool_Users() )->find_users( $lookup ); throw new RuntimeException( 'Direct lookup bypassed permissions' ); }
	catch ( Frontman_Tool_Error $e ) { frontman_runtime_assert( false !== strpos( $e->getMessage(), 'requires' ), 'Wrong denied lookup error' ); }
	frontman_runtime_assert( $queries_before === $wpdb->num_queries, 'Denied lookup queried database' );
}
$actor->add_cap( 'list_users' );
$subscriber_cookie = wp_generate_auth_cookie( $target_id, time() + HOUR_IN_SECONDS, 'logged_in' );
$request = [ 'name' => 'wp_find_users', 'arguments' => $lookup ];
frontman_runtime_assert( 403 === frontman_runtime_tool( $subscriber_cookie, null, $request )['status'], 'Subscriber discovered accounts' );
$mutation = [ 'name' => 'wp_update_post', 'arguments' => $combined ];
frontman_runtime_assert( [ 401, 403, 403, 403 ] === array_column( [ frontman_runtime_tool( '', null, $mutation ), frontman_runtime_tool( $subscriber_cookie, null, $mutation ), frontman_runtime_tool( $actor_cookie, null, $mutation ), frontman_runtime_tool( $actor_cookie, 'invalid', $mutation ) ], 'status' ), 'Auth/nonce bypass' );
frontman_runtime_assert( $unchanged === $snapshot( $fixture ), 'Auth/nonce rejection wrote state' );
echo "Author permissions, HTTP raw validation, literal lookup and privacy checks passed.\n";
