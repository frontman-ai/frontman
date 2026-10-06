<?php

define( 'WP_ADMIN', true );
require '/var/www/html/wp-load.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/includes/class-frontman-elementor-data.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/tools/class-tool-elementor.php';
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );

function discovery_runtime_assert( bool $ok, string $message ): void {
	if ( ! $ok ) { throw new RuntimeException( $message ); }
}
function discovery_runtime_error( callable $call, string $message ): void {
	try { $call(); } catch ( Frontman_Tool_Error $error ) {
		discovery_runtime_assert( false !== strpos( $error->getMessage(), $message ), 'Unexpected error: ' . $error->getMessage() );
		return;
	}
	throw new RuntimeException( 'Expected error: ' . $message );
}

add_action( 'customize_register', static function( WP_Customize_Manager $manager ): void {
	$manager->add_setting( 'frontman_header_button_text', [
		'type' => 'theme_mod',
		'capability' => 'edit_theme_options',
		'sanitize_callback' => 'sanitize_text_field',
		'validate_callback' => static function( $validity, $value ) {
			if ( 'invalid' === $value ) { $validity->add( 'invalid', 'Invalid button label' ); }
			return $validity;
		},
	] );
	$manager->add_setting( 'frontman_denied_mod', [ 'capability' => 'frontman_missing_capability' ] );
	$manager->add_setting( 'frontman_option', [ 'type' => 'option' ] );
	$manager->add_setting( 'frontman_indexed[label]', [ 'type' => 'theme_mod' ] );
	$manager->add_setting( 'frontman_boolean', [ 'type' => 'theme_mod', 'sanitize_callback' => static fn( $value ) => (bool) $value ] );
} );
$tool = new Frontman_Tool_Options();
$registry = new Frontman_Tools(); $tool->register( $registry );
set_theme_mod( 'frontman_header_button_text', 'Try Playground' );
$input = [ 'name' => 'frontman_header_button_text', 'value' => '<b>Book Demo</b>', 'stylesheet' => get_stylesheet(), 'confirm' => true ];
$read = $tool->get_theme_mod( [ 'name' => $input['name'] ] );
discovery_runtime_assert( 'Try Playground' === $read['value'], 'Initial theme mod read failed' );
$result = $tool->update_theme_mod( $registry->sanitize_input( 'wp_update_theme_mod', $input ) );
discovery_runtime_assert( 'Try Playground' === $result['before'] && 'Book Demo' === $result['after'] && $result['updated'], 'Customizer write not sanitized/persisted' );
discovery_runtime_assert( ! $tool->update_theme_mod( $input )['updated'], 'No-op write marked updated' );
discovery_runtime_error( static fn() => $tool->update_theme_mod( array_replace( $input, [ 'value' => 'invalid' ] ) ), 'Invalid button label' );
discovery_runtime_assert( 'Book Demo' === get_theme_mod( $input['name'] ), 'Invalid value changed mod' );
foreach ( [ 'unregistered_mod', 'frontman_option', 'frontman_indexed[label]' ] as $name ) {
	discovery_runtime_error( static fn() => $tool->update_theme_mod( array_replace( $input, [ 'name' => $name ] ) ), 'registered top-level' );
}
discovery_runtime_error( static fn() => $tool->update_theme_mod( array_replace( $input, [ 'name' => 'frontman_denied_mod' ] ) ), 'cannot edit this' );
discovery_runtime_error( static fn() => $tool->update_theme_mod( array_replace( $input, [ 'stylesheet' => 'inactive-theme' ] ) ), 'active theme' );
discovery_runtime_error( static fn() => $tool->update_theme_mod( array_replace( $input, [ 'confirm' => false ] ) ), 'confirm=true' );
discovery_runtime_assert( false === $tool->update_theme_mod( array_replace( $input, [ 'name' => 'frontman_boolean', 'value' => false ] ) )['after'], 'Boolean false rejected' );
$admin = get_current_user_id();
wp_set_current_user( 0 );
discovery_runtime_error( static fn() => $tool->update_theme_mod( $input ), 'cannot edit theme options' );
wp_set_current_user( $admin );

register_post_type( 'frontman_search_test', [ 'public' => true ] );
register_post_type( 'elementor_library', [ 'public' => false, 'show_ui' => true ] );
$ids = [];
for ( $i = 0; $i < 205; ++$i ) {
	$id = wp_insert_post( [ 'post_type' => 'frontman_search_test', 'post_title' => 'Search fixture', 'post_status' => 'publish' ], true );
	discovery_runtime_assert( ! is_wp_error( $id ), 'Could not create search fixture' );
	$ids[] = $id;
}
$tree = [ [ 'id' => 'parent', 'elType' => 'container', 'settings' => [], 'elements' => [ [
	'id' => 'button', 'elType' => 'widget', 'widgetType' => 'button',
	'settings' => [ 'text' => 'Try Playground', 'items' => [ [ 'label' => 'TRY PLAYGROUND' ] ] ], 'elements' => [],
] ] ] ];
update_post_meta( $ids[204], '_elementor_data', wp_slash( wp_json_encode( $tree ) ) );
$template = wp_insert_post( [ 'post_type' => 'elementor_library', 'post_title' => 'Search template', 'post_status' => 'private' ], true );
discovery_runtime_assert( ! is_wp_error( $template ), 'Could not create shared template' );
update_post_meta( $template, '_elementor_data', wp_slash( wp_json_encode( $tree ) ) );
$elementor = new Frontman_Tool_Elementor();
$first = $elementor->list_pages( [ 'post_type' => 'frontman_search_test', 'text_search' => 'try playground', 'per_page' => 200 ] );
discovery_runtime_assert( [] === $first['pages'] && 200 === $first['next_offset'], 'Empty batch lost continuation' );
$last = $elementor->list_pages( [ 'post_type' => 'frontman_search_test', 'text_search' => 'try playground', 'per_page' => 200, 'offset' => $first['next_offset'] ] );
discovery_runtime_assert( [ $ids[204] ] === array_column( $last['pages'], 'post_id' ) && null === $last['next_offset'], 'Search missed page beyond 200' );
discovery_runtime_assert( [ 'settings', 'items', 0, 'label' ] === $last['pages'][0]['matches'][1]['setting_path'], 'Repeater path incorrect' );
$found = [];
$offset = 0;
do {
	$batch = $elementor->list_pages( [ 'text_search' => 'Try Playground', 'per_page' => 200, 'offset' => $offset ] );
	$found = array_merge( $found, array_column( $batch['pages'], 'post_id' ) );
	$offset = $batch['next_offset'];
} while ( null !== $offset );
discovery_runtime_assert( in_array( $template, $found, true ) && in_array( $ids[204], $found, true ), 'Default search omitted shared templates or custom post type' );
update_post_meta( $ids[204], '_elementor_data', '{invalid' );
discovery_runtime_error( static fn() => $elementor->list_pages( [ 'post_type' => 'frontman_search_test', 'text_search' => 'Try', 'offset' => 200 ] ), 'Search is incomplete' );
foreach ( array_merge( $ids, [ $template ] ) as $id ) { wp_delete_post( $id, true ); }
foreach ( [ 'frontman_header_button_text', 'frontman_boolean' ] as $name ) { remove_theme_mod( $name ); }
echo "OK (WordPress Customizer theme mods and Elementor source search)\n";
