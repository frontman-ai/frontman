<?php

define( 'ABSPATH', __DIR__ . '/' );
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-elementor-data.php';
require_once __DIR__ . '/../tools/class-tool-options.php';
require_once __DIR__ . '/../tools/class-tool-elementor.php';

function discovery_assert( bool $ok, string $message ): void {
	if ( ! $ok ) { throw new RuntimeException( $message ); }
}
function discovery_error( callable $call, string $message ): void {
	try { $call(); } catch ( Frontman_Tool_Error $e ) {
		discovery_assert( false !== strpos( $e->getMessage(), $message ), 'Unexpected error: ' . $e->getMessage() );
		return;
	}
	throw new RuntimeException( 'Expected error: ' . $message );
}
function sanitize_key( $v ) { return $v; }
function absint( $v ) { return abs( (int) $v ); }
function wp_check_invalid_utf8( $v, $strip = false ) { return $v; }
function wp_json_encode( $v ) { return json_encode( $v ); }
function get_stylesheet() { return 'test-theme'; }
function current_user_can( $cap ) { return $GLOBALS['allowed']; }
function get_theme_mods() { return $GLOBALS['mods']; }
function get_theme_mod( $name, $default = false ) { return $GLOBALS['mods'][$name] ?? $default; }
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function do_action( $name, $manager ) {
	discovery_assert( 'customize_register' === $name, 'Unexpected action' );
	$manager->settings = $GLOBALS['settings'];
}
class WP_Error {
	public function get_error_message() { return 'Invalid setting value'; }
}
class WP_Customize_Manager {
	public array $settings = [];
	public array $values = [];
	public function __construct( $args ) { discovery_assert( false === $args['settings_previewed'], 'Settings preview enabled' ); }
	public function get_setting( $name ) { return $this->settings[$name] ?? null; }
	public function set_post_value( $name, $value ) { $this->values[$name] = $value; }
}
class DiscoverySetting {
	public string $type = 'theme_mod';
	public bool $allowed = true;
	public bool $persist = true;
	public array $keys = [];
	public function id_data() { return [ 'keys' => $this->keys ]; }
	public function check_capabilities() { return $this->allowed; }
	public function validate( $value ) { return 'invalid' === $value ? new WP_Error() : true; }
	public function sanitize( $value ) { return 'rejected' === $value ? null : ( is_string( $value ) ? strip_tags( $value ) : $value ); }
	public function save() {
		if ( $this->persist ) {
			$GLOBALS['mods']['Header_Button_Text'] = $this->sanitize( $GLOBALS['wp_customize']->values['Header_Button_Text'] );
		}
		return null;
	}
}
function get_post_types( $args ) { return [ 'post' => 'post', 'page' => 'page', 'product' => 'product', 'attachment' => 'attachment' ]; }
function get_posts( $args ) {
	$GLOBALS['query'] = $args;
	$types = (array) $args['post_type'];
	$posts = array_values( array_filter( $GLOBALS['posts'], static fn( $post ) => in_array( $post->post_type, $types, true ) && in_array( $post->post_status, $args['post_status'], true ) ) );
	return array_slice( $posts, $args['offset'], $args['posts_per_page'] );
}
function get_post_meta( $id, $key, $single ) { return '_elementor_data' === $key ? ( $GLOBALS['data'][$id] ?? '' ) : ''; }
function get_permalink( $id ) { return 'https://example.test/' . $id; }

$GLOBALS['allowed'] = true;
$GLOBALS['mods'] = [ 'Header_Button_Text' => 'Try Playground' ];
$setting = new DiscoverySetting();
$GLOBALS['settings'] = [ 'Header_Button_Text' => $setting ];
$tools = new Frontman_Tools();
$options = new Frontman_Tool_Options(); $options->register( $tools );
$elementor = new Frontman_Tool_Elementor(); $elementor->register( $tools );
$input = [ 'name' => 'Header_Button_Text', 'stylesheet' => 'test-theme', 'value' => '<b>Book Demo</b>', 'confirm' => true ];
$clean = $tools->sanitize_input( 'wp_update_theme_mod', $input );
discovery_assert( $input == $clean && $input['value'] === $clean['value'], 'Registry altered Customizer input' );
$result = $options->update_theme_mod( $clean );
discovery_assert( 'Try Playground' === $result['before'] && 'Book Demo' === $result['after'] && $result['updated'], 'Sanitized write or before/after incorrect' );
discovery_assert( ! $options->update_theme_mod( $input )['updated'], 'No-op marked updated' );
foreach ( [ false, 'true', 1 ] as $confirm ) {
	discovery_error( static fn() => $options->update_theme_mod( $tools->sanitize_input( 'wp_update_theme_mod', array_replace( $input, [ 'confirm' => $confirm ] ) ) ), 'confirm=true' );
}
discovery_error( static fn() => $options->update_theme_mod( array_replace( $input, [ 'stylesheet' => 'other' ] ) ), 'active theme' );
discovery_error( static fn() => $options->update_theme_mod( array_replace( $input, [ 'name' => 'unregistered' ] ) ), 'registered top-level' );
discovery_error( static fn() => $options->update_theme_mod( array_replace( $input, [ 'name' => '../bad' ] ) ), 'invalid characters' );
$GLOBALS['allowed'] = false;
discovery_error( static fn() => $options->update_theme_mod( $input ), 'cannot edit theme options' );
$GLOBALS['allowed'] = true;
$setting->allowed = false;
discovery_error( static fn() => $options->update_theme_mod( $input ), 'cannot edit this' );
$setting->allowed = true;
$setting->type = 'option';
discovery_error( static fn() => $options->update_theme_mod( $input ), 'registered top-level' );
$setting->type = 'theme_mod'; $setting->keys = [ 'nested' ];
discovery_error( static fn() => $options->update_theme_mod( $input ), 'registered top-level' );
$setting->keys = [];
foreach ( [ [ 'invalid', 'Invalid setting value' ], [ 'rejected', 'rejected' ], [ null, 'value is required' ] ] as [ $value, $error ] ) {
	discovery_error( static fn() => $options->update_theme_mod( array_replace( $input, [ 'value' => $value ] ) ), $error );
}
$setting->persist = false;
discovery_error( static fn() => $options->update_theme_mod( array_replace( $input, [ 'value' => 'Changed' ] ) ), 'could not be verified' );
$setting->persist = true;
foreach ( [ false, 0, [ 'label' => 'Book Demo' ] ] as $value ) {
	discovery_assert( $value === $options->update_theme_mod( array_replace( $input, [ 'value' => $value ] ) )['after'], 'Typed value changed' );
}

$GLOBALS['posts'] = [];
$GLOBALS['data'] = [];
for ( $id = 1; $id <= 205; ++$id ) {
	$GLOBALS['posts'][] = (object) [ 'ID' => $id, 'post_type' => 'page', 'post_title' => 'Page', 'post_name' => 'page-' . $id, 'post_status' => 'publish' ];
}
$GLOBALS['posts'][] = (object) [ 'ID' => 206, 'post_type' => 'elementor_library', 'post_title' => 'Header', 'post_name' => 'header', 'post_status' => 'private' ];
$GLOBALS['posts'][] = (object) [ 'ID' => 207, 'post_type' => 'product', 'post_title' => 'Product', 'post_name' => 'product', 'post_status' => 'draft' ];
$tree = [ [ 'id' => 'container', 'elType' => 'container', 'settings' => [], 'elements' => [ [ 'id' => 'button', 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [ 'text' => 'Try Playground', 'items' => [ [ 'label' => 'TRY PLAYGROUND' ] ], 'numeric' => 123 ] ] ] ] ];
$GLOBALS['data'][205] = json_encode( $tree );
$GLOBALS['data'][206] = $tree;
$GLOBALS['data'][207] = $tree;
$first = $elementor->list_pages( [] );
discovery_assert( 100 === count( $first['pages'] ) && 100 === $first['next_offset'], 'Default listing changed or pagination missing' );
discovery_assert( ! array_key_exists( 'matches', $first['pages'][0] ), 'No-search listing includes matches' );
$first = $elementor->list_pages( [ 'text_search' => 'try playground', 'per_page' => 200 ] );
discovery_assert( [] === $first['pages'] && 200 === $first['next_offset'], 'Empty batch lost continuation' );
$last = $elementor->list_pages( [ 'text_search' => 'try playground', 'per_page' => 200, 'offset' => $first['next_offset'] ] );
discovery_assert( [ 205, 206, 207 ] === array_column( $last['pages'], 'post_id' ) && null === $last['next_offset'], 'Missed late page, shared template or custom post type' );
$matches = $last['pages'][0]['matches'];
discovery_assert( 2 === count( $matches ) && 'button' === $matches[0]['element_id'], 'Nested settings not matched' );
discovery_assert( [ 'settings', 'items', 0, 'label' ] === $matches[1]['setting_path'], 'Repeater setting path incorrect' );
discovery_assert( 'TRY PLAYGROUND' === $matches[1]['excerpt'], 'Excerpt incorrect' );
discovery_assert( 1 === count( $elementor->list_pages( [ 'text_search' => 'Try Playground', 'post_type' => 'elementor_library' ] )['pages'] ), 'Template-only scope ignored' );
discovery_assert( [] === $elementor->list_pages( [ 'text_search' => 'Try.*', 'offset' => 200 ] )['pages'], 'Search interpreted regex' );
foreach ( [ '', '  ', null, false, [], str_repeat( 'x', 201 ) ] as $bad ) {
	discovery_error( static fn() => $elementor->list_pages( [ 'text_search' => $bad ] ), 'text_search' );
}
foreach ( [ -1, '1', false ] as $bad ) { discovery_error( static fn() => $elementor->list_pages( $tools->sanitize_input( 'wp_elementor_list_pages', [ 'offset' => $bad ] ) ), 'offset' ); }
$GLOBALS['data'][205] = [ [ 'id' => 'unicode', 'settings' => [ 'text' => 'DÉMO / Book Demo' ] ] ];
discovery_assert( 1 === count( $elementor->list_pages( [ 'text_search' => 'démo /', 'offset' => 200 ] )['pages'] ), 'Unicode case-insensitive or literal slash matching failed' );
discovery_error( static fn() => $elementor->list_pages( [ 'text_search' => "\xC3\x28" ] ), 'UTF-8' );
$GLOBALS['data'][205] = '{broken json';
discovery_error( static fn() => $elementor->list_pages( [ 'text_search' => 'Try', 'offset' => 200 ] ), 'Search is incomplete' );
discovery_assert( 'read-write' === $tools->get( 'wp_update_theme_mod' )->access && 'read' === $tools->get( 'wp_elementor_list_pages' )->access, 'Tool access incorrect' );
echo "OK (theme mods and paginated Elementor text search)\n";
