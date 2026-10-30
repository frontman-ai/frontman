<?php

define( 'ABSPATH', __DIR__ . '/' );

function get_allowed_block_template_part_areas(): array {
	return [ [ 'area' => 'header' ], [ 'area' => 'footer' ], [ 'area' => 'uncategorized' ] ];
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-posts.php';
require_once __DIR__ . '/../tools/class-tool-blocks.php';
require_once __DIR__ . '/../tools/class-tool-media.php';
require_once __DIR__ . '/../tools/class-tool-menus.php';
require_once __DIR__ . '/../tools/class-tool-options.php';
require_once __DIR__ . '/../tools/class-tool-templates.php';
require_once __DIR__ . '/../tools/class-tool-widgets.php';
require_once __DIR__ . '/../tools/class-tool-cache.php';
require_once __DIR__ . '/../tools/class-tool-public-files.php';

$assert = static function ( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
};
$tools = new Frontman_Tools();
foreach ( [ 'Posts', 'Blocks', 'Media', 'Menus', 'Options', 'Templates', 'Widgets', 'Cache', 'Public_Files' ] as $suffix ) {
	$class = 'Frontman_Tool_' . $suffix;
	( new $class() )->register( $tools );
}
$definitions = $tools->all_definitions();
$tool_names = array_column( $definitions, 'name' );
foreach ( [
	'load_agent_instructions', 'read_file', 'list_files', 'file_exists', 'grep', 'search_files', 'list_tree',
	'wp_get_managed_theme_status', 'wp_create_managed_theme', 'wp_activate_managed_theme',
	'wp_list_managed_theme_files', 'wp_read_managed_theme_file', 'wp_write_managed_theme_file', 'wp_fork_parent_theme_file',
] as $name ) {
	$assert( ! in_array( $name, $tool_names, true ), $name . ' must not be exposed by the WordPress plugin' );
}
foreach ( $definitions as $definition ) {
	$assert( isset( $definition['access'] ) && in_array( $definition['access'], [ 'read', 'write', 'read-write' ], true ), $definition['name'] . ' declares valid access' );
}
$access_by_name = array_column( $definitions, 'access', 'name' );
foreach ( [
	'wp_get_site_info' => 'read', 'wp_read_public_file' => 'read', 'wp_write_public_file' => 'read-write',
	'wp_list_posts' => 'read', 'wp_create_post' => 'write', 'wp_update_post' => 'read-write', 'wp_clear_cache' => 'read-write',
] as $name => $access ) {
	$assert( $access === $access_by_name[ $name ], $name . ' advertised access' );
}

echo "OK (filesystem tools remain blocked; tool access declarations)\n";
