<?php

declare(strict_types=1);

( static function (): void {
	$read = [ true, false, false, true ];
	$write = [ false, true, true, false ];
	$expected_catalog = frontman_runtime_core_annotations() + [
		'wp_test_diagnostics' => $write,
		'wp_test_annotations_false' => [ false, false, false, false ],
		'wp_test_annotations_read' => [ true, false, false, false ],
		'wp_test_annotations_destructive' => [ false, true, false, false ],
		'wp_test_annotations_open' => [ false, false, true, false ],
		'wp_test_annotations_idempotent' => [ false, false, false, true ],
		'wp_test_annotations_true' => [ true, true, true, true ],
	];
	$providers = [
		[ true, [
			'wp_list_languages' => $read, 'wp_read_post_language' => $read, 'wp_set_post_language' => $write,
		] ],
		[ Frontman_Tool_Angie::is_available(), [ 'wp_read_angie_snippet' => $read ] ],
		[ Frontman_Tool_Code_Snippets::is_available(), [
			'wp_search_code_snippets' => $read, 'wp_read_code_snippet' => $read,
		] ],
		[ Frontman_Tool_Directorist::is_available(), [ 'wp_read_directorist_listing' => $read ] ],
		[ Frontman_Tool_Redirection::is_available(), [
			'wp_list_redirects' => $read, 'wp_create_redirect' => $write, 'wp_delete_redirect' => $write,
		] ],
		[ Frontman_Tool_301_Redirects::is_available(), [
			'wp_301_redirects_list' => $read, 'wp_301_redirects_create' => $write, 'wp_301_redirects_delete' => $write,
		] ],
	];
	$seo = [];
	if ( null === Frontman_Tool_Seo::read_unavailable_reason() ) { $seo['wp_read_seo'] = $read; }
	if ( null === Frontman_Tool_Seo::unavailable_reason() ) { $seo['wp_update_seo'] = $write; }
	foreach ( [ 'term', 'post_type_archive' ] as $target ) {
		if ( null === Frontman_Tool_Seo::archive_unavailable_reason( $target ) ) { $seo[ 'wp_read_' . $target . '_seo' ] = $read; }
		if ( null === Frontman_Tool_Seo::archive_unavailable_reason( $target, true ) ) { $seo[ 'wp_update_' . $target . '_seo' ] = $write; }
	}
	$providers[] = [ true, $seo ];
	if ( Frontman_Plugin_Dependencies::is_available( 'elementor/elementor.php', '\Elementor\Plugin' ) ) {
		$providers[] = [ true, [
			'wp_elementor_list_pages' => $read, 'wp_elementor_get_page_structure' => $read,
			'wp_elementor_get_page_data' => $read, 'wp_elementor_get_element' => $read,
			'wp_elementor_list_rollbacks' => $read, 'wp_elementor_generate_element' => $read,
			'wp_elementor_list_widgets' => $read, 'wp_elementor_get_widget_schema' => $read,
			'wp_elementor_save_page_data' => $write, 'wp_elementor_update_element' => $write,
			'wp_elementor_add_element' => $write, 'wp_elementor_wrap_element' => $write,
			'wp_elementor_remove_element' => $write, 'wp_elementor_restore_rollback' => $write,
			'wp_elementor_duplicate_element' => $write, 'wp_elementor_move_element' => $write,
			'wp_elementor_flush_css' => $write,
		] ];
	}
	foreach ( $providers as [ $available, $expected ] ) {
		if ( $available ) {
			frontman_runtime_same( [], array_keys( array_intersect_key( $expected_catalog, $expected ) ), 'Each reviewed provider must own distinct tool names.' );
			$expected_catalog += $expected;
		}
	}
	if ( Frontman_Plugin_Dependencies::is_available( 'woocommerce/woocommerce.php', '\WooCommerce' ) ) {
		$expected_catalog += frontman_runtime_woocommerce_annotations();
	}
	frontman_runtime_assert_annotations( Frontman_Tools::instance(), $expected_catalog );
	fwrite( STDOUT, "OK (complete reviewed catalog and conditional registration)\n" );
} )();

if ( '' === $runtime_case && class_exists( 'Frontman_Tool_Elementor' ) ) {
	( static function(): void {
		$actor = get_current_user_id();
		wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
		$post = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Integration safety', 'post_status' => 'publish' ], true );
		frontman_runtime_assert( is_int( $post ), 'Create a real published Elementor fixture.' );
		$tools = Frontman_Tools::instance();
		$call = static function( string $name, array $input ) use ( $tools ): array {
			$result = frontman_runtime_call( $tools, 'wp_elementor_' . $name, $input );
			frontman_runtime_same( false, $result['isError'], $name . ': ' . wp_json_encode( $result ) );
			return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
		};
		try {
			$element = $call( 'generate_element', [ 'type' => 'heading', 'title' => 'Safety original' ] );
			$tree = [ $element ];
			$call( 'save_page_data', [ 'post_id' => $post, 'data' => $tree, 'confirm' => true ] );
			$tree = $call( 'get_page_data', [ 'post_id' => $post ] )['data'];
			wp_cache_delete( $post, 'post_meta' );
			$before = get_post_meta( $post );
			$call( 'get_page_data', [ 'post_id' => $post ] );
			$call( 'get_page_structure', [ 'post_id' => $post ] );
			$call( 'get_element', [ 'post_id' => $post, 'element_id' => $element['id'] ] );
			$call( 'generate_element', [ 'type' => 'heading', 'title' => 'Safety original' ] );
			wp_cache_delete( $post, 'post_meta' );
			frontman_runtime_same( $before, get_post_meta( $post ), 'Stored reads and pure generation do not persist page changes.' );
			$updated = $call( 'update_element', [ 'post_id' => $post, 'element_id' => $element['id'], 'settings' => [ 'title' => 'Safety public replacement' ] ] );
			$public = frontman_runtime_http( 'GET', '/?page_id=' . $post );
			frontman_runtime_same( 200, $public['status'], 'Published Elementor fixture is publicly accessible.' );
			frontman_runtime_assert( false !== strpos( $public['body'], 'Safety public replacement' ), 'Element mutation changes real public output despite retaining a rollback.' );
			$call( 'restore_rollback', [ 'post_id' => $post, 'rollback_id' => $updated['rollback_id'], 'confirm' => true ] );
			frontman_runtime_same( $tree, $call( 'get_page_data', [ 'post_id' => $post ] )['data'], 'Rollback overwrites stored data with the earlier tree.' );
			$first = $call( 'duplicate_element', [ 'post_id' => $post, 'element_id' => $element['id'] ] );
			$second = $call( 'duplicate_element', [ 'post_id' => $post, 'element_id' => $element['id'] ] );
			frontman_runtime_assert( $first['new_element_id'] !== $second['new_element_id'], 'Repeated identical duplication persists additional elements.' );
			frontman_runtime_same( 3, count( $call( 'get_page_data', [ 'post_id' => $post ] )['data'] ), 'Both repeated mutations remain stored.' );
			fwrite( STDOUT, "OK (Elementor read/generation purity, public overwrite, rollback and repeated writes)\n" );
		} finally {
			wp_delete_post( $post, true );
			wp_set_current_user( $actor );
		}
	} )();
}
