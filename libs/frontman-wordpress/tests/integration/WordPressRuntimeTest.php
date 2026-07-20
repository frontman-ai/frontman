<?php

if ( ! defined( 'ABSPATH' ) ) {
	throw new RuntimeException( 'WordPress must be loaded before the runtime test.' );
}

function frontman_runtime_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

frontman_runtime_assert( '7.0.2' === get_bloginfo( 'version' ), 'Runtime must use WordPress 7.0.2.' );
frontman_runtime_assert( defined( 'FRONTMAN_VERSION' ), 'Frontman plugin was not activated.' );
frontman_runtime_assert( null !== Frontman_Tools::instance()->get( 'wp_list_navigation_menus' ), 'Plugin bootstrap did not register navigation tools during init.' );

$block_tool = new Frontman_Tool_Blocks();
$content = '<!-- wp:group --><div class="wp-block-group"><!-- wp:paragraph --><p>Nested one</p><!-- /wp:paragraph --><!-- wp:group --><div class="wp-block-group"><!-- wp:paragraph --><p>Nested two</p><!-- /wp:paragraph --></div><!-- /wp:group --></div><!-- /wp:group --><!-- wp:paragraph --><p>Top level</p><!-- /wp:paragraph -->';
$post_id = wp_insert_post(
	[
		'post_type' => 'page',
		'post_status' => 'publish',
		'post_title' => 'Frontman WordPress 7 Runtime',
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

fwrite( STDOUT, "OK (WordPress 7.0.2, PHP " . PHP_VERSION . ")\n" );
