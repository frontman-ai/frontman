<?php

define( 'WP_ADMIN', true );
require '/var/www/html/wp-load.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/includes/class-frontman-elementor-data.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/tools/class-tool-elementor.php';
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );

function discovery_assert( bool $ok, string $message ): void {
	if ( ! $ok ) { throw new RuntimeException( $message ); }
}
function discovery_call( Frontman_Tools $tools, string $name, array $input ): array {
	$result = $tools->call( $name, $tools->sanitize_input( $name, $input ) );
	discovery_assert( ! $result['isError'], $result['content'][0]['text'] );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
}
function discovery_reject( Frontman_Tools $tools, array $input, string $message ): void {
	$before = get_theme_mods();
	$result = $tools->call( 'wp_update_theme_mod', $tools->sanitize_input( 'wp_update_theme_mod', $input ) );
	discovery_assert( $result['isError'] && false !== strpos( $result['content'][0]['text'], $message ), 'Expected rejection: ' . $message );
	discovery_assert( $before === get_theme_mods(), 'Rejected write changed persisted theme mods' );
}

function test_customizer_registration_and_save( Frontman_Tools $tools ): void {
	$register = static function( WP_Customize_Manager $manager ): void {
		discovery_assert( null !== $manager->get_setting( 'blogname' ), 'Late bootstrap ran theme callback before core registration' );
		$manager->get_setting( 'blogname' )->transport = 'postMessage';
		$manager->add_setting( 'frontman_label', [
			'sanitize_callback' => 'sanitize_text_field',
			'validate_callback' => static function( $validity, $value ) {
				if ( 'invalid' === $value ) { $validity->add( 'invalid', 'Invalid button label' ); }
				return $validity;
			},
		] );
		$manager->add_setting( 'frontman_denied', [ 'capability' => 'frontman_missing_capability' ] );
		$manager->add_setting( 'frontman_option', [ 'type' => 'option' ] );
		$manager->add_setting( 'frontman_indexed[label]' );
		$manager->add_setting( 'frontman_boolean', [ 'sanitize_callback' => static fn( $value ) => (bool) $value ] );
	};
	add_action( 'customize_register', $register );
	set_theme_mod( 'frontman_label', 'Try Playground' );
	$input = [ 'name' => 'frontman_label', 'value' => '<b>Book Demo</b>', 'stylesheet' => get_stylesheet(), 'confirm' => true ];
	$events = [];
	$before = static function( $manager ) use ( &$events ): void {
		discovery_assert( 'Book Demo' === $manager->get_setting( 'frontman_label' )->post_value(), 'Save hook cannot inspect sanitized input' );
		$events[] = 'before';
	};
	$setting = static function() use ( &$events ): void { $events[] = 'setting'; };
	$after = static function() use ( &$events ): void { $events[] = 'after:' . get_theme_mod( 'frontman_label' ); };
	add_action( 'customize_save', $before );
	add_action( 'customize_save_frontman_label', $setting );
	add_action( 'customize_save_after', $after );
	try {
		$result = discovery_call( $tools, 'wp_update_theme_mod', $input );
		discovery_assert( 'Try Playground' === $result['before'] && 'Book Demo' === $result['after'] && $result['updated'], 'Incorrect persisted save receipt' );
		discovery_assert( [ 'before', 'setting', 'after:Book Demo' ] === $events, 'Save lifecycle order or persisted state incorrect' );
		discovery_assert( 'postMessage' === $GLOBALS['wp_customize']->get_setting( 'blogname' )->transport, 'Core controls registered twice' );
	} finally {
		remove_action( 'customize_register', $register );
		remove_action( 'customize_save', $before );
		remove_action( 'customize_save_frontman_label', $setting );
		remove_action( 'customize_save_after', $after );
	}
	discovery_assert( ! discovery_call( $tools, 'wp_update_theme_mod', $input )['updated'], 'No-op write marked updated' );
	foreach ( [
		[ [ 'value' => 'invalid' ], 'Invalid button label' ],
		[ [ 'value' => null ], 'value is required' ],
		[ [ 'name' => 'unregistered' ], 'registered top-level' ],
		[ [ 'name' => 'frontman_option' ], 'registered top-level' ],
		[ [ 'name' => 'frontman_indexed[label]' ], 'registered top-level' ],
		[ [ 'name' => 'frontman_denied' ], 'cannot edit this' ],
		[ [ 'stylesheet' => 'inactive' ], 'active theme' ],
		[ [ 'confirm' => 'true' ], 'confirm=true' ],
	] as [ $change, $message ] ) { discovery_reject( $tools, array_replace( $input, $change ), $message ); }
	discovery_assert( false === discovery_call( $tools, 'wp_update_theme_mod', array_replace( $input, [ 'name' => 'frontman_boolean', 'value' => false ] ) )['after'], 'Boolean false rejected' );
	$admin = get_current_user_id();
	wp_set_current_user( 0 );
	try { discovery_reject( $tools, $input, 'cannot edit theme options' ); } finally { wp_set_current_user( $admin ); }
}

function test_filtered_persistence_and_failed_write( Frontman_Tools $tools ): void {
	$input = [ 'name' => 'frontman_label', 'value' => 'filtered label', 'stylesheet' => get_stylesheet(), 'confirm' => true ];
	$calls = 0;
	$normalize = static function( $value ) use ( &$calls ) { ++$calls; return strtoupper( $value ); };
	add_filter( 'pre_set_theme_mod_frontman_label', $normalize, PHP_INT_MAX );
	try {
		$result = discovery_call( $tools, 'wp_update_theme_mod', $input );
		discovery_assert( 'FILTERED LABEL' === $result['after'] && $result['after'] === get_theme_mod( 'frontman_label' ), 'Receipt did not honor persistence filter' );
		discovery_assert( 1 === $calls, 'Persistence filter ran more than once' );
	} finally { remove_filter( 'pre_set_theme_mod_frontman_label', $normalize, PHP_INT_MAX ); }
	$block = static fn( $new, $old ) => $old;
	$option_filter = 'pre_update_option_theme_mods_' . get_stylesheet();
	add_filter( $option_filter, $block, 10, 2 );
	try { discovery_reject( $tools, array_replace( $input, [ 'value' => 'not persisted' ] ), 'could not be verified' ); }
	finally { remove_filter( $option_filter, $block ); }
	discovery_assert( ! has_filter( 'pre_set_theme_mod_frontman_label' ), 'Write observer leaked after success or failure' );
}

function test_elementor_pagination_and_unicode( Frontman_Tools $tools ): void {
	register_post_type( 'frontman_search_test', [ 'public' => true ] );
	register_post_type( 'elementor_library', [ 'public' => false, 'show_ui' => true ] );
	$ids = [];
	try {
		for ( $i = 0; $i <= 200; ++$i ) {
			$id = wp_insert_post( [ 'post_type' => 'frontman_search_test', 'post_title' => 'Same title', 'post_status' => 'publish' ], true );
			discovery_assert( ! is_wp_error( $id ), 'Could not create pagination fixture' );
			$ids[] = $id;
		}
		$context = str_repeat( '界', 20 ) . "\n" . str_repeat( '界', 19 );
		$excerpt = $context . 'Book Démo' . str_repeat( '🙂', 40 );
		$tree = [ [ 'id' => 'parent', 'elType' => 'container', 'settings' => [], 'elements' => [ [
			'id' => 'button', 'elType' => 'widget', 'widgetType' => 'button', 'elements' => [],
			'settings' => [ 'text' => 'Try Playground', 'items' => [ [ 'label' => 'TRY PLAYGROUND' ] ], 'unicode' => str_repeat( '界', 10 ) . $excerpt . str_repeat( '🙂', 10 ), 'literal' => 'Try.* / Playground' ],
		] ] ] ];
		update_post_meta( $ids[200], '_elementor_data', wp_slash( wp_json_encode( $tree ) ) );
		$scope = [ 'post_type' => 'frontman_search_test', 'text_search' => 'try playground', 'per_page' => 200 ];
		$first = discovery_call( $tools, 'wp_elementor_list_pages', $scope );
		discovery_assert( [] === $first['pages'] && 200 === $first['next_offset'], 'Empty batch lost continuation' );
		$last = discovery_call( $tools, 'wp_elementor_list_pages', $scope + [ 'offset' => $first['next_offset'] ] );
		discovery_assert( [ $ids[200] ] === array_column( $last['pages'], 'post_id' ) && null === $last['next_offset'], 'Search missed page beyond 200' );
		discovery_assert( [ 'settings', 'items', 0, 'label' ] === $last['pages'][0]['matches'][1]['setting_path'], 'Repeater path incorrect' );
		$unicode = discovery_call( $tools, 'wp_elementor_list_pages', array_replace( $scope, [ 'text_search' => 'book démo', 'offset' => 200 ] ) );
		discovery_assert( $excerpt === $unicode['pages'][0]['matches'][0]['excerpt'], 'Unicode excerpt lost context or split a character' );
		$literal = discovery_call( $tools, 'wp_elementor_list_pages', array_replace( $scope, [ 'text_search' => 'Try.* /', 'offset' => 200 ] ) );
		discovery_assert( 'Try.* / Playground' === $literal['pages'][0]['matches'][0]['excerpt'], 'Search did not treat metacharacters literally' );
		$list = [ 'post_type' => 'frontman_search_test', 'per_page' => 2 ];
		discovery_assert( array_slice( $ids, 0, 2 ) === array_column( discovery_call( $tools, 'wp_elementor_list_pages', $list )['pages'], 'post_id' ), 'Ordinary listing changed' );
		discovery_assert( array_slice( $ids, 2, 2 ) === array_column( discovery_call( $tools, 'wp_elementor_list_pages', $list + [ 'offset' => 2 ] )['pages'], 'post_id' ), 'Tie-break ordering duplicated or skipped posts' );
		$template = wp_insert_post( [ 'post_type' => 'elementor_library', 'post_title' => 'Private header', 'post_status' => 'private' ], true );
		discovery_assert( ! is_wp_error( $template ), 'Could not create template fixture' );
		$ids[] = $template;
		update_post_meta( $template, '_elementor_data', wp_slash( wp_json_encode( $tree ) ) );
		$found = []; $offset = 0;
		do {
			$batch = discovery_call( $tools, 'wp_elementor_list_pages', [ 'text_search' => 'try playground', 'per_page' => 200, 'offset' => $offset ] );
			$found = array_merge( $found, array_column( $batch['pages'], 'post_id' ) );
			$offset = $batch['next_offset'];
		} while ( null !== $offset );
		discovery_assert( in_array( $template, $found, true ) && in_array( $ids[200], $found, true ), 'Default search omitted templates or custom posts' );
		update_post_meta( $ids[200], '_elementor_data', '{invalid' );
		$error = $tools->call( 'wp_elementor_list_pages', $scope + [ 'offset' => 200 ] );
		discovery_assert( $error['isError'] && false !== strpos( $error['content'][0]['text'], 'Search is incomplete' ), 'Malformed source silently omitted' );
	} finally { foreach ( $ids as $id ) { wp_delete_post( $id, true ); } }
}

$tools = new Frontman_Tools();
(new Frontman_Tool_Options())->register( $tools );
(new Frontman_Tool_Elementor())->register( $tools );
try {
	test_customizer_registration_and_save( $tools );
	test_filtered_persistence_and_failed_write( $tools );
	test_elementor_pagination_and_unicode( $tools );
} finally { foreach ( [ 'frontman_label', 'frontman_boolean' ] as $name ) { remove_theme_mod( $name ); } }
echo "OK (WordPress Customizer lifecycle, filtered persistence and Unicode source search)\n";
