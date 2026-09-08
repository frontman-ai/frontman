<?php
/** Test-only post types with real custom capabilities, loaded in CLI and HTTP requests. */
add_action( 'init', static function(): void {
	register_post_type( 'fm_author_item', [
		'public' => true, 'supports' => [ 'title', 'editor', 'author' ],
		'capability_type' => [ 'fm_item', 'fm_items' ], 'map_meta_cap' => true,
		'capabilities' => [ 'create_posts' => 'create_fm_items' ],
	] );
	register_post_type( 'fm_no_author', [ 'public' => true, 'supports' => [ 'title', 'editor' ] ] );
	register_post_type( 'fm_primitive', [
		'public' => true, 'supports' => [ 'title', 'editor', 'author' ],
		'capability_type' => [ 'fm_primitive', 'fm_primitives' ], 'map_meta_cap' => false,
	] );
} );
