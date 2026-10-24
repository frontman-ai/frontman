<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-installation-' . getmypid() );

function wp_json_encode( $value ) { return json_encode( $value ); }
function wp_normalize_path( string $path ): string { return str_replace( '\\', '/', $path ); }
function trailingslashit( string $path ): string { return rtrim( $path, '/\\' ) . '/'; }
function get_bloginfo( string $field ): string { return $field; }
function get_site_url(): string { return 'https://example.test/wordpress'; }
function get_home_url(): string { return 'https://example.test'; }
function get_post_types( array $args, string $output ): array { return []; }
function get_taxonomies( array $args, string $output ): array { return []; }
function is_multisite(): bool { return false; }
function wp_get_theme() {
	return new class() {
		public function get( string $field ): string { return $field; }
		public function is_block_theme(): bool { return true; }
		public function get_template(): string { return 'test-theme'; }
		public function get_stylesheet(): string { return 'test-theme'; }
	};
}
class Frontman_Tool_Seo {
	public static function unavailable_reason(): ?string { return 'Not tested here.'; }
}

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

$property = $tools->get( 'wp_get_site_info' )->input_schema['properties']['include_installation_paths'];
$assert( 'boolean' === $property['type'] && false === $property['default'], 'Installation paths require a boolean opt-in.' );
$call = static function ( array $input ) use ( $tools, $assert ): array {
	$result = $tools->call( 'wp_get_site_info', $tools->sanitize_input( 'wp_get_site_info', $input ) );
	$assert( false === $result['isError'], 'Site info must succeed.' );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$default = $call( [] );
$assert( ! array_key_exists( 'installation', $default ) && $default === $call( [ 'include_installation_paths' => false ] ), 'Default and explicit false must omit paths.' );
foreach ( [ null, 0, 1, 'true', 'false', [], (object) [] ] as $invalid ) {
	try {
		$call( [ 'include_installation_paths' => $invalid ] );
		throw new RuntimeException( 'Non-boolean path opt-in was accepted.' );
	} catch ( Frontman_Tool_Error $error ) {
		$assert( 'include_installation_paths must be a boolean.' === $error->getMessage(), 'Path opt-in error must identify the field.' );
	}
}

$assert( ! file_exists( ABSPATH ) && ! is_link( ABSPATH ), 'Installation fixture must not already exist.' );
symlink( __DIR__, ABSPATH );
try {
	$info = $call( [ 'include_installation_paths' => true, 'path' => '/must-not-be-used' ] );
	$assert( [ 'abspath' => ABSPATH . '/', 'resolved_abspath' => realpath( __DIR__ ) . '/' ] === $info['installation'], 'Configured and resolved symlink paths must remain distinct with trailing slashes.' );
	unset( $info['installation'] );
	$assert( $default === $info, 'Path opt-in must not change other site information.' );
} finally {
	unlink( ABSPATH );
	clearstatcache( true );
}
$assert( [ 'abspath' => ABSPATH . '/', 'resolved_abspath' => null ] === $call( [ 'include_installation_paths' => true ] )['installation'], 'Failed resolution must return null, not an inferred root.' );
echo "OK (filesystem tools remain blocked; installation paths require opt-in)\n";
