<?php
/** Real WordPress source-read -> draft-create -> readback and taxonomy write safety. */

$taxonomy_actor_id = wp_insert_user( [ 'user_login' => 'taxonomy-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
wp_set_current_user( $taxonomy_actor_id );
$taxonomy_cookie = wp_generate_auth_cookie( $taxonomy_actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
$_COOKIE[ LOGGED_IN_COOKIE ] = $taxonomy_cookie;
$taxonomy_nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$taxonomy_call = static function( string $name, array $input, bool $error = false ) use ( $taxonomy_cookie, $taxonomy_nonce ): array {
	$response = frontman_runtime_tool( $taxonomy_cookie, $taxonomy_nonce, [ 'name' => $name, 'arguments' => $input ] );
	frontman_runtime_assert( 200 === $response['status'] && $error === $response['body']['isError'], 'Unexpected taxonomy outcome: ' . json_encode( $response ) );
	return $error ? $response['body'] : json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$term_ids = [];
foreach ( [ 'category', 'post_tag' ] as $taxonomy ) {
	foreach ( [ 'One', 'Two' ] as $name ) {
		$term = wp_insert_term( 'Taxonomy ' . $name, $taxonomy );
		frontman_runtime_assert( ! is_wp_error( $term ), 'Term fixture failed' );
		$term_ids[ $taxonomy ][] = (int) $term['term_id'];
	}
}
$base = [ 'title' => 'Taxonomy source', 'content' => '<p>Source body</p>' ];
$source_id = wp_insert_post( [ 'post_title' => $base['title'], 'post_content' => $base['content'], 'post_status' => 'draft' ], true );
wp_set_post_categories( $source_id, $term_ids['category'] );
wp_set_object_terms( $source_id, $term_ids['post_tag'], 'post_tag' );
$source = $taxonomy_call( 'wp_read_post', [ 'id' => $source_id ] );
foreach ( [ 'categories' => 'category', 'tags' => 'post_tag' ] as $field => $taxonomy ) {
	foreach ( $source[ $field ] as $term ) {
		$native = get_term( $term['id'], $taxonomy );
		frontman_runtime_assert( [ 'id' => (int) $native->term_id, 'name' => $native->name, 'slug' => $native->slug ] === $term, 'Readback term fields differ from WordPress' );
	}
}
$matching = [ 'categories' => array_column( $source['categories'], 'id' ), 'tags' => array_column( $source['tags'], 'id' ) ];
$created = $taxonomy_call( 'wp_create_post', array_merge( $base, $matching ) );
$id = $created['id'];
$read = $taxonomy_call( 'wp_read_post', [ 'id' => $id ] );
frontman_runtime_assert( 'draft' === $read['status'] && $created['after'] === $read && $source['categories'] === $read['categories'] && $source['tags'] === $read['tags'], 'Source -> draft -> readback lost taxonomy assignments' );
$omitted = $taxonomy_call( 'wp_update_post', [ 'id' => $id, 'title' => 'Taxonomy omitted' ] );
frontman_runtime_assert( $read === $omitted['before'] && $read['categories'] === $omitted['after']['categories'] && $read['tags'] === $omitted['after']['tags'], 'Omission changed assignments or before snapshot' );
$replacement = [ 'categories' => [ $term_ids['category'][1], $term_ids['category'][1] ], 'tags' => [ $term_ids['post_tag'][1] ] ];
$updated = $taxonomy_call( 'wp_update_post', array_merge( [ 'id' => $id ], $replacement ) );
frontman_runtime_assert( $omitted['after'] === $updated['before'] && [ $term_ids['category'][1] ] === array_column( $updated['after']['categories'], 'id' ) && $replacement['tags'] === array_column( $updated['after']['tags'], 'id' ), 'Replacement did not replace/deduplicate assignments' );
$default = (int) get_option( 'default_category' );
$default_post = $taxonomy_call( 'wp_create_post', $base );
frontman_runtime_assert( [ $default ] === array_column( $default_post['after']['categories'], 'id' ) && [] === $default_post['after']['tags'], 'Omitted create taxonomy defaults changed' );
foreach ( [ 'wp_create_post' => $base, 'wp_update_post' => [ 'id' => $id ] ] as $name => $input ) {
	$empty = $taxonomy_call( $name, array_merge( $input, [ 'categories' => [], 'tags' => [] ] ) );
	frontman_runtime_assert( [ $default ] === array_column( $empty['after']['categories'], 'id' ) && [] === $empty['after']['tags'], 'Empty arrays did not apply default category/clear tags' );
}
$taxonomy_snapshot = static function(): array {
	global $wpdb;
	wp_cache_flush();
	return [ $wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A ), $wpdb->get_results( "SELECT * FROM {$wpdb->term_relationships} ORDER BY object_id, term_taxonomy_id", ARRAY_A ), $wpdb->get_results( "SELECT * FROM {$wpdb->terms} ORDER BY term_id", ARRAY_A ) ];
};
$unchanged = $taxonomy_snapshot();
foreach ( [ [ 'categories' => [ 99999999 ] ], [ 'tags' => [ 99999999 ] ], [ 'categories' => [ $term_ids['post_tag'][0] ] ], [ 'tags' => [ $term_ids['category'][0] ] ], [ 'categories' => [ $term_ids['category'][0] ], 'tags' => [ 99999999 ] ], [ 'categories' => null ], [ 'tags' => [ '1' ] ], [ 'categories' => (object) [] ], [ 'tags' => (object) [] ], [ 'categories' => (object) [ '0' => $default ] ], [ 'tags' => true ] ] as $bad ) {
	$taxonomy_call( 'wp_create_post', array_merge( $base, [ 'status' => 'publish' ], $bad ), true );
	$taxonomy_call( 'wp_update_post', array_merge( [ 'id' => $id, 'title' => 'Must not persist', 'content' => 'Rejected', 'status' => 'publish' ], $bad ), true );
	frontman_runtime_assert( $unchanged === $taxonomy_snapshot(), 'Invalid assignment changed posts, relationships, or created terms' );
}
foreach ( [ 'wp_create_post' => $base, 'wp_update_post' => [ 'id' => $id ] ] as $name => $input ) {
	$request = [ 'name' => $name, 'arguments' => array_merge( $input, [ 'categories' => [ (float) $default ] ] ) ];
	$response = frontman_runtime_tool( $taxonomy_cookie, $taxonomy_nonce, [], json_encode( $request, JSON_PRESERVE_ZERO_FRACTION ) );
	frontman_runtime_assert( true === $response['body']['isError'] && $unchanged === $taxonomy_snapshot(), 'HTTP float term ID was coerced or wrote state' );
}

$response = frontman_runtime_tool( $taxonomy_cookie, $taxonomy_nonce, [ 'name' => 'WP_UPDATE_POST', 'input' => [ 'id' => $id, 'tags' => (object) [] ] ] );
frontman_runtime_assert( true === $response['body']['isError'] && $unchanged === $taxonomy_snapshot(), 'Input alias/object bypassed raw validation' );

$taxonomy_tools = new Frontman_Tools();
( new Frontman_Tool_Posts() )->register( $taxonomy_tools );
$direct = static function( string $name, array $input, bool $error = false ) use ( $taxonomy_tools ): array {
	$result = $taxonomy_tools->call( $name, $taxonomy_tools->sanitize_input( $name, $input ) );
	frontman_runtime_assert( $error === $result['isError'], 'Unexpected direct taxonomy result: ' . json_encode( $result ) );
	return $error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$auto_draft_id = wp_insert_post( [ 'post_title' => 'Auto draft taxonomy', 'post_status' => 'auto-draft' ], true );
$auto_draft = $direct( 'wp_update_post', [ 'id' => $auto_draft_id, 'categories' => [], 'tags' => [] ] );
frontman_runtime_assert( [] === $auto_draft['after']['categories'] && [] === $auto_draft['after']['tags'], 'Auto-draft empty arrays should not assign default category' );
$page = $direct( 'wp_create_post', array_merge( $base, [ 'post_type' => 'page' ] ) );
frontman_runtime_assert( [] === $page['after']['categories'] && [] === $page['after']['tags'], 'Unsupported taxonomies not empty on read' );
$unchanged = $taxonomy_snapshot();
foreach ( [ 'categories', 'tags' ] as $field ) {
	$direct( 'wp_create_post', array_merge( $base, [ 'post_type' => 'page', $field => [] ] ), true );
	$direct( 'wp_update_post', [ 'id' => $page['id'], 'title' => 'Rejected', $field => [] ], true );
}
frontman_runtime_assert( $unchanged === $taxonomy_snapshot(), 'Unattached taxonomy wrote state' );
register_post_type( 'fm_taxonomy_item', [ 'public' => true, 'supports' => [ 'title', 'editor' ], 'taxonomies' => [ 'category', 'post_tag' ] ] );
$cpt = $direct( 'wp_create_post', array_merge( $base, $matching, [ 'post_type' => 'fm_taxonomy_item' ] ) );
$empty = $direct( 'wp_update_post', [ 'id' => $cpt['id'], 'categories' => [], 'tags' => [] ] );
frontman_runtime_assert( [] === $empty['after']['categories'] && [] === $empty['after']['tags'], 'CPT empty arrays must clear' );
$default_filter = static fn( $types ) => array_merge( $types, [ 'fm_taxonomy_item' ] );
add_filter( 'default_category_post_types', $default_filter );
$empty = $direct( 'wp_update_post', [ 'id' => $cpt['id'], 'categories' => [] ] );
frontman_runtime_assert( [ $default ] === array_column( $empty['after']['categories'], 'id' ), 'Filtered default-category CPT rule ignored' );
remove_filter( 'default_category_post_types', $default_filter );
foreach ( [ 'categories' => 'category', 'tags' => 'post_tag' ] as $field => $taxonomy ) {
	$cap = get_taxonomy( $taxonomy )->cap->assign_terms;
	get_taxonomy( $taxonomy )->cap->assign_terms = 'frontman_denied_assign_terms';
	$unchanged = $taxonomy_snapshot();
	foreach ( [ [], [ $term_ids[ $taxonomy ][0] ] ] as $ids ) {
		$direct( 'wp_create_post', array_merge( $base, [ $field => $ids ] ), true );
		$direct( 'wp_update_post', [ 'id' => $id, 'title' => 'Rejected', $field => $ids ], true );
	}
	frontman_runtime_assert( $unchanged === $taxonomy_snapshot(), 'Denied assignment partially wrote' );
	get_taxonomy( $taxonomy )->cap->assign_terms = $cap;
}
$deny_term = static function( $caps, $cap, $user_id, $args ) use ( $default ) {
	return 'assign_term' === $cap && $default === $args[0] ? [ 'do_not_allow' ] : $caps;
};
add_filter( 'map_meta_cap', $deny_term, 10, 4 );
$unchanged = $taxonomy_snapshot();
$direct( 'wp_create_post', array_merge( $base, [ 'categories' => [] ] ), true );
$direct( 'wp_update_post', [ 'id' => $id, 'title' => 'Rejected', 'categories' => [ $default ] ], true );
frontman_runtime_assert( $unchanged === $taxonomy_snapshot(), 'Default or per-term denial wrote state' );
remove_filter( 'map_meta_cap', $deny_term );

update_option( 'default_category', 99999999 );
$unchanged = $taxonomy_snapshot();
$direct( 'wp_create_post', array_merge( $base, [ 'categories' => [] ] ), true );
$direct( 'wp_update_post', [ 'id' => $id, 'categories' => [], 'title' => 'Rejected' ], true );
frontman_runtime_assert( $unchanged === $taxonomy_snapshot(), 'Invalid default category wrote state' );
update_option( 'default_category', $default );

$fail_assignment = static function( $object_id, $tt_id, $taxonomy ): void {
	if ( 'post_tag' === $taxonomy ) { throw new RuntimeException( 'Injected relationship failure' ); }
};
add_action( 'added_term_relationship', $fail_assignment, 10, 3 );
$error = $direct( 'wp_update_post', [ 'id' => $id, 'title' => 'Partial write persisted', 'categories' => $matching['categories'], 'tags' => $matching['tags'] ], true );
remove_action( 'added_term_relationship', $fail_assignment );
frontman_runtime_assert( false !== strpos( $error['content'][0]['text'], "Post {$id} was saved" ) && false !== strpos( $error['content'][0]['text'], 'no rollback' ) && 'Partial write persisted' === get_post( $id )->post_title, 'Partial write was not reported accurately' );
$taxonomy_backup = get_taxonomy( 'post_tag' );
$remove_taxonomy = static function(): void { unset( $GLOBALS['wp_taxonomies']['post_tag'] ); };
add_action( 'save_post', $remove_taxonomy );
$error = $direct( 'wp_create_post', array_merge( $base, [ 'tags' => $matching['tags'] ] ), true );
remove_action( 'save_post', $remove_taxonomy );
$GLOBALS['wp_taxonomies']['post_tag'] = $taxonomy_backup;
frontman_runtime_assert( false !== strpos( $error['content'][0]['text'], 'was saved' ) && false !== strpos( $error['content'][0]['text'], 'post_tag assignment failed' ), 'Native assignment error swallowed' );
$delete_term = static function() use ( $matching ): void { wp_delete_term( $matching['tags'][1], 'post_tag' ); };
add_action( 'save_post', $delete_term );
$error = $direct( 'wp_create_post', array_merge( $base, [ 'tags' => $matching['tags'] ] ), true );
remove_action( 'save_post', $delete_term );
frontman_runtime_assert( false !== strpos( $error['content'][0]['text'], 'was saved' ) && false !== strpos( $error['content'][0]['text'], 'readback does not match' ), 'Silently skipped native assignment reported success' );
$read_failure = static fn() => new WP_Error( 'injected_read_failure', 'Injected term read failure' );
add_filter( 'get_the_terms', $read_failure );
$error = $direct( 'wp_create_post', $base, true );
remove_filter( 'get_the_terms', $read_failure );
frontman_runtime_assert( false !== strpos( $error['content'][0]['text'], 'was saved' ) && false !== strpos( $error['content'][0]['text'], 'Injected term read failure' ), 'Post-write read error swallowed' );
echo "Post taxonomy read/create/readback, replacement, empty/default, validation, permission and partial-write checks passed.\n";
