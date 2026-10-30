<?php

$base = [ 'title' => 'Layout É 日本語', 'content' => '<!-- wp:paragraph --><p>Layout \\path</p><!-- /wp:paragraph -->' ];
foreach ( [ 'wp_template', 'wp_template_part' ] as $type ) {
	$input = $base + [ 'slug' => 'landing-' . $type, 'type' => $type ];
	$created = $call( 'wp_create_template', $input )['after'];
	$id = $created['wp_id'];
	frontman_runtime_same( get_stylesheet() . '//' . $input['slug'], $created['id'], 'Created template belongs to the active theme' );
	frontman_runtime_same( [ get_stylesheet() ], wp_get_object_terms( $id, 'wp_theme', [ 'fields' => 'names' ] ), 'Native theme relationship persists' );
	frontman_runtime_same( $input['content'], $call( 'wp_read_template', [ 'slug' => $input['slug'], 'type' => $type ] )['content'], 'Created template is discoverable without changing markup' );
	$updated = $call( 'wp_update_template', array_replace( $input, [ 'content' => '<p>Updated layout</p>' ] ) );
	frontman_runtime_same( '<p>Updated layout</p>', $updated['after']['content'], 'Update persists replacement markup' );
	frontman_runtime_same( $created, $updated['before'], 'Update snapshots the existing template' );
	frontman_runtime_same( $id, $updated['after']['wp_id'], 'Update reuses the template post' );
	$reject( 'wp_create_template', $input, 'already exists' );
	$reject( 'wp_create_post', [ 'title' => 'Orphan', 'content' => '', 'post_type' => $type ], 'wp_create_template' );
	$reject( 'wp_duplicate_post', [ 'source_id' => $id ], 'wp_create_template' );

	$draft = wp_insert_post( [ 'post_type' => $type, 'post_status' => 'draft', 'post_name' => 'hidden-' . $type, 'post_title' => 'Draft layout' ], true );
	frontman_runtime_assert( is_int( $draft ), 'Draft template fixture must exist' );
	wp_set_post_terms( $draft, [ get_stylesheet() ], 'wp_theme' );
	$reject( 'wp_create_template', array_replace( $input, [ 'slug' => 'hidden-' . $type ] ), 'already exists' );
}
$input = $base + [ 'slug' => 'new-layout', 'type' => 'wp_template' ];
$files = array_values( array_filter( get_block_templates( [], 'wp_template' ), static fn( $t ) => 'theme' === $t->source ) );
frontman_runtime_assert( [] !== $files, 'Theme must provide a file-backed template' );
$reject( 'wp_create_template', array_replace( $input, [ 'slug' => $files[0]->slug ] ), 'already exists' );
$override = $call( 'wp_update_template', [ 'slug' => $files[0]->slug, 'content' => $base['content'] ] );
frontman_runtime_same( 'theme', $override['before']['source'], 'File override starts from a theme file' );
frontman_runtime_same( 'custom', $override['after']['source'], 'File override becomes a native custom template' );
$reject( 'wp_update_template', [ 'slug' => 'missing-layout', 'content' => '' ], 'Template not found' );
foreach ( [
	[ [ 'slug' => 'Not Canonical' ], 'canonical WordPress slug' ],
	[ [ 'title' => '<b>Layout</b>' ], 'plain text' ],
	[ [ 'content' => null ], 'content' ],
	[ [ 'area' => 'header' ], 'only supported for parts' ],
	[ [ 'type' => 'wp_template_part', 'area' => 'unknown' ], 'area' ],
] as [ $invalid, $reason ] ) {
	$reject( 'wp_create_template', array_replace( $input, $invalid ), $reason );
}
$reject( 'wp_create_template', $input, 'block-templates', 'no-block-templates' );
$actor->add_cap( 'edit_theme_options', false );
try {
	$reject( 'wp_create_template', $input, 'edit_theme_options' );
	$reject( 'wp_update_template', [ 'slug' => 'landing-wp_template', 'content' => '' ], 'edit_theme_options' );
} finally {
	$actor->remove_cap( 'edit_theme_options' );
}

$catalog = frontman_runtime_http( 'GET', '/index.php/frontman/tools', $cookie, null, null, 'custom-area' );
$definitions = array_column( json_decode( $catalog['body'], true, 512, JSON_THROW_ON_ERROR )['tools'], null, 'name' );
$areas = $definitions['wp_create_template']['inputSchema']['properties']['area']['enum'];
frontman_runtime_assert( in_array( 'frontman-sidebar', $areas, true ), 'Schema advertises plugin-defined areas' );
foreach ( $areas as $area ) {
	$part = $call( 'wp_create_template', $base + [ 'slug' => 'area-' . $area, 'type' => 'wp_template_part', 'area' => $area ], false, 'custom-area' );
	frontman_runtime_same( $area, $part['after']['area'], 'Native and custom template-part areas persist' );
}
if ( function_exists( 'apply_block_hooks_to_content' ) ) {
	foreach ( [ 'wp_template', 'wp_template_part' ] as $type ) {
		$hooked = [ 'slug' => 'hook-' . $type, 'type' => $type, 'title' => 'Hooked layout', 'content' => '<!-- wp:paragraph --><p>Anchor</p><!-- /wp:paragraph -->' ];
		foreach ( [ 'wp_create_template', 'wp_update_template' ] as $name ) {
			$saved = $call( $name, $hooked, false, 'hooked-block' )['after'];
			$raw = $call( 'wp_read_post', [ 'id' => $saved['wp_id'] ] );
			frontman_runtime_same( $hooked['content'], $raw['content'], 'Hooked save preserves stored markup' );
			frontman_runtime_assert( false !== strpos( $saved['content'], 'wp:frontman/runtime-hook' ), 'Native discovery inserts the registered hooked block' );
			$hooked['content'] = str_replace( 'Anchor', 'Updated anchor', $hooked['content'] );
		}
	}
}
$message = $call( 'wp_create_template', $input, true, 'transform-content' );
$raw = $call( 'wp_read_post', [ 'id' => frontman_runtime_saved_id( $message ) ] );
frontman_runtime_same( $input['content'] . '<p>Plugin transformation</p>', $raw['content'], 'Failed template verification exposes the persisted raw post' );
echo "OK (template lifecycle, collisions, registered areas and hooked blocks)\n";
