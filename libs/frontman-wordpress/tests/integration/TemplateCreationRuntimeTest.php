<?php
/** Native theme-linked template discovery through packaged HTTP tools. */
$actor_id = wp_insert_user( [ 'user_login' => 'template-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
frontman_runtime_assert( is_int( $actor_id ), 'Template actor creation failed' );
$actor = new WP_User( $actor_id );
$cookie = wp_generate_auth_cookie( $actor_id, time() + HOUR_IN_SECONDS, 'logged_in' );
wp_set_current_user( $actor_id );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $input, bool $error = false ) use ( $cookie, $nonce ): array {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $input ] );
	frontman_runtime_assert( 200 === $response['status'] && $error === $response['body']['isError'], 'Unexpected template outcome: ' . json_encode( $response ) );
	return $error ? $response['body'] : json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$count = static function() use ( $wpdb ): int { return (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->posts}" ); };
$base = [ 'slug' => 'frontman-webinar', 'type' => 'wp_template', 'title' => 'Webinar É 日本語', 'content' => '<!-- wp:html --><style>.x:before{content:"\\A"}</style><script defer data-test="yes">/* inert */</script><!-- /wp:html -->' ];
$theme = get_stylesheet();
foreach ( [ [ 'type' => 'wp_template' ], [ 'type' => 'wp_template_part', 'area' => 'header' ], [ 'type' => 'wp_template_part', 'area' => 'footer' ], [ 'type' => 'wp_template_part' ] ] as $i => $fields ) {
	$input = array_merge( $base, $fields, [ 'slug' => 'frontman-webinar-' . $i ] );
	$created = $call( 'wp_create_template', $input );
	$after = $created['after']; $id = $after['wp_id'];
	frontman_runtime_assert( true === $created['created'] && $theme . '//' . $input['slug'] === $after['id'] && $input['slug'] === $after['slug'] && $input['type'] === $after['type'] && $theme === $after['theme'] && $input['content'] === $after['content'] && $input['title'] === $after['title'], 'Created template identity/content differs' );
	frontman_runtime_assert( [ $theme ] === wp_get_object_terms( $id, 'wp_theme', [ 'fields' => 'names' ] ), 'Theme relationship missing' );
	if ( 'wp_template_part' === $input['type'] ) {
		frontman_runtime_assert( ( $input['area'] ?? 'uncategorized' ) === $after['area'] && [ $after['area'] ] === wp_get_object_terms( $id, 'wp_template_part_area', [ 'fields' => 'names' ] ), 'Area relationship missing' );
	}
	frontman_runtime_assert( $after === $call( 'wp_read_template', [ 'slug' => $input['slug'], 'type' => $input['type'] ] ) && in_array( $after['id'], array_column( $call( 'wp_list_templates', [ 'type' => $input['type'] ] )['templates'], 'id' ), true ), 'Native list/read omitted created template' );
	$before_count = $count();
	$call( 'wp_create_template', $input, true );
	$call( 'wp_create_post', [ 'title' => 'Orphan forbidden', 'content' => 'Orphan', 'post_type' => $input['type'] ], true );
	$call( 'wp_duplicate_post', [ 'source_id' => $id ], true );
	frontman_runtime_assert( $before_count === $count(), 'Collision/generic creation/duplicate wrote an orphan' );
	$updated = $call( 'wp_update_template', [ 'slug' => $input['slug'], 'type' => $input['type'], 'content' => '<!-- wp:paragraph --><p>Updated</p><!-- /wp:paragraph -->' ] );
	frontman_runtime_assert( $id === $updated['after']['wp_id'] && $after === $updated['before'] && $theme === $updated['after']['theme'] && $after['area'] === $updated['after']['area'], 'Existing update lost identity/area' );
}
foreach ( [ 'wp_template', 'wp_template_part' ] as $type ) {
	foreach ( [ 'draft', 'pending', 'private', 'auto-draft' ] as $status ) {
		$slug = 'frontman-hidden-' . $type . '-' . $status;
		$hidden_id = wp_insert_post( [ 'post_type' => $type, 'post_status' => $status, 'post_name' => $slug, 'post_title' => 'Unpublished template', 'post_content' => '<p>Untouched unpublished content</p>' ], true );
		frontman_runtime_assert( is_int( $hidden_id ) && ! is_wp_error( wp_set_post_terms( $hidden_id, [ $theme ], 'wp_theme' ) ), 'Unpublished fixture creation failed' );
		$row = get_post( $hidden_id, ARRAY_A );
		frontman_runtime_assert( $slug === $row['post_name'] && ! in_array( $slug, array_column( get_block_templates( [], $type ), 'slug' ), true ), 'Fixture is not hidden from native published discovery' );
		$before_count = $count();
		$call( 'wp_create_template', array_merge( $base, [ 'slug' => $slug, 'type' => $type ] ), true );
		clean_post_cache( $hidden_id );
		frontman_runtime_assert( $before_count === $count() && $row === get_post( $hidden_id, ARRAY_A ), 'Unpublished collision wrote a post/revision or changed original row' );
	}
}
$before_count = $count();
$files = array_values( array_filter( get_block_templates( [], 'wp_template' ), static fn( $t ) => 'theme' === $t->source ) );
frontman_runtime_assert( ! empty( $files ), 'Theme-file collision fixture absent' );
$call( 'wp_create_template', array_merge( $base, [ 'slug' => $files[0]->slug ] ), true );
$call( 'wp_update_template', [ 'slug' => 'frontman-not-created', 'content' => 'No upsert' ], true );
foreach ( [ 'slug', 'type', 'title', 'content' ] as $field ) {
	$missing = $base; unset( $missing[ $field ] );
	$call( 'wp_create_template', $missing, true );
	foreach ( [ null, false, 42, [] ] as $bad ) { $call( 'wp_create_template', array_merge( $base, [ $field => $bad ] ), true ); }
}
foreach ( [ [ 'slug' => '' ], [ 'slug' => 'Not Canonical' ], [ 'slug' => str_repeat( 'x', 201 ) ], [ 'type' => 'post' ], [ 'title' => '' ], [ 'title' => '<b>Title</b>' ], [ 'area' => 'header' ], [ 'type' => 'wp_template_part', 'area' => 'sidebar' ], [ 'type' => 'wp_template_part', 'area' => null ] ] as $bad ) { $call( 'wp_create_template', array_merge( $base, $bad ), true ); }
$actor->add_cap( 'edit_theme_options', false );
$call( 'wp_create_template', $base, true );
$call( 'wp_update_template', [ 'slug' => 'frontman-webinar-0', 'content' => 'Denied' ], true );
wp_set_current_user( 0 ); wp_set_current_user( $actor_id );
try { ( new Frontman_Tool_Templates() )->create_template( $base ); throw new RuntimeException( 'Direct template permission bypass' ); }
catch ( Frontman_Tool_Error $e ) { frontman_runtime_assert( false !== strpos( $e->getMessage(), 'edit_theme_options' ), 'Wrong direct permission error' ); }
$actor->remove_cap( 'edit_theme_options' );
wp_set_current_user( 0 ); wp_set_current_user( $actor_id );
frontman_runtime_assert( $before_count === $count(), 'Invalid/missing/capability/collision input wrote state' );
$file_update = $call( 'wp_update_template', [ 'slug' => $files[0]->slug, 'content' => '<!-- wp:paragraph --><p>Theme file override</p><!-- /wp:paragraph -->' ] );
frontman_runtime_assert( 'theme' === $file_update['before']['source'] && 'custom' === $file_update['after']['source'] && $theme === $file_update['after']['theme'] && $files[0]->slug === $file_update['after']['slug'], 'Updating existing theme-file template failed' );

$tool = new Frontman_Tool_Templates();
$before_count = $count();
remove_theme_support( 'block-templates' );
try {
	try { $tool->create_template( $base ); throw new RuntimeException( 'Unsupported block template accepted' ); }
	catch ( Frontman_Tool_Error $e ) { frontman_runtime_assert( false !== strpos( $e->getMessage(), 'block-templates' ), 'Wrong theme support error' ); }
	frontman_runtime_assert( $before_count === $count(), 'Unsupported block template wrote state' );
} finally { add_theme_support( 'block-templates' ); }
$custom_area = static function( array $areas ): array { $areas[] = [ 'area' => 'frontman-sidebar', 'label' => 'Sidebar' ]; return $areas; };
add_filter( 'default_wp_template_part_areas', $custom_area );
try {
	$registry = new Frontman_Tools(); $tool->register( $registry );
	foreach ( get_allowed_block_template_part_areas() as $definition ) {
		$area = $definition['area'];
		$result = $registry->call( 'wp_create_template', array_merge( $base, [ 'slug' => 'frontman-area-' . $area, 'type' => 'wp_template_part', 'area' => $area ] ) );
		frontman_runtime_assert( ! $result['isError'], 'Registered template-part area rejected: ' . $area . json_encode( $result ) );
		$part = $tool->read_template( [ 'slug' => 'frontman-area-' . $area, 'type' => 'wp_template_part' ] );
		frontman_runtime_assert( $area === $part['area'] && in_array( $area, $registry->get( 'wp_create_template' )->input_schema['properties']['area']['enum'], true ), 'Registered area missing from saved part or schema' );
	}
} finally { remove_filter( 'default_wp_template_part_areas', $custom_area ); }
if ( function_exists( 'apply_block_hooks_to_content' ) ) {
	register_block_type( 'frontman/runtime-hook', [ 'api_version' => 2, 'block_hooks' => [ 'core/paragraph' => 'after' ] ] );
	try {
		foreach ( [ 'wp_template', 'wp_template_part' ] as $type ) {
			$input = array_merge( $base, [ 'slug' => 'frontman-hook-' . $type, 'type' => $type, 'content' => '<!-- wp:paragraph --><p>Anchor</p><!-- /wp:paragraph -->' ] );
			$created = $tool->create_template( $input );
			frontman_runtime_assert( $input['content'] === get_post( $created['after']['wp_id'] )->post_content, 'Hooked create changed stored markup' );
			$updated = $tool->update_template( array_merge( $input, [ 'content' => str_replace( 'Anchor', 'Updated anchor', $input['content'] ) ] ) );
			foreach ( [ $created, $updated ] as $result ) {
				frontman_runtime_assert( false !== strpos( $result['after']['content'], 'wp:frontman/runtime-hook' ), 'Hook fixture did not transform discovered content' );
			}
			frontman_runtime_assert( str_replace( 'Anchor', 'Updated anchor', $input['content'] ) === get_post( $updated['after']['wp_id'] )->post_content, 'Hooked update changed stored markup' );
		}
	} finally { unregister_block_type( 'frontman/runtime-hook' ); }
}
foreach ( [ 'theme', 'area', 'content', 'slug' ] as $failure ) {
	$input = array_merge( $base, [ 'slug' => 'frontman-failure-' . $failure, 'type' => 'wp_template_part', 'area' => 'header' ] );
	$taxonomy = 'theme' === $failure ? 'wp_theme' : 'wp_template_part_area';
	$saved_taxonomy = $wp_taxonomies[ $taxonomy ];
	$break_terms = static function() use ( $taxonomy ): void { unset( $GLOBALS['wp_taxonomies'][ $taxonomy ] ); };
	$transform = static function( array $data ) use ( $failure ): array { $data[ 'slug' === $failure ? 'post_name' : 'post_content' ] .= '-filtered'; return $data; };
	if ( in_array( $failure, [ 'theme', 'area' ], true ) ) { add_action( 'wp_after_insert_post', $break_terms ); }
	else { add_filter( 'wp_insert_post_data', $transform ); }
	try { $tool->create_template( $input ); throw new RuntimeException( 'Unverified template save accepted: ' . $failure ); }
	catch ( Frontman_Tool_Error $e ) {
		$message = $e->getMessage();
		frontman_runtime_assert( 1 === preg_match( '/Template post (\d+) was saved/', $message, $match ) && false !== strpos( $message, 'wp_read_post' ) && false !== strpos( $message, 'no rollback' ), 'Partial template failure hid recovery ID: ' . $message );
		$id = (int) $match[1];
	} finally {
		remove_action( 'wp_after_insert_post', $break_terms ); remove_filter( 'wp_insert_post_data', $transform );
		$wp_taxonomies[ $taxonomy ] = $saved_taxonomy;
	}
	$raw = $call( 'wp_read_post', [ 'id' => $id ] );
	frontman_runtime_assert( $id === $raw['id'] && 'wp_template_part' === $raw['type'], 'Raw partial template recovery unavailable' );
	if ( 'slug' === $failure ) { frontman_runtime_assert( $input['slug'] . '-filtered' === get_post( $id )->post_name, 'Slug injection ineffective' ); }
}
echo "Template creation HTTP discovery, collisions, validation, theme/area terms and partial-save recovery passed.\n";
