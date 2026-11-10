<?php

declare(strict_types=1);

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
$frontman_seo_test = sanitize_key( wp_unslash( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) );
add_filter( 'redirect_canonical', static fn( $redirect ) => 'render' === $frontman_seo_test ? false : $redirect );
// Exercise persisted indexables in the local runtime, as Yoast does in production.
add_filter( 'Yoast\WP\SEO\should_index_indexables', static fn() => 'no-archive-persistence' !== $frontman_seo_test );
add_filter( 'wpseo_should_save_indexable', static fn( $save ) => 'silent-archive-refresh' === $frontman_seo_test ? false : $save );
add_action( 'init', static function (): void {
	register_post_type( 'frontman_seo_item', [
		'public'   => true,
		'show_ui'  => true,
		'has_archive' => 'frontman-runtime-archive',
		'supports' => [ 'title', 'editor', 'excerpt', 'custom-fields' ],
	] );
	register_taxonomy( 'frontman_seo_topic', 'frontman_seo_item', [
		'public' => true, 'show_ui' => true,
	] );
	register_post_type( 'fm_seo_no_archive', [ 'public' => true, 'show_ui' => true, 'has_archive' => false ] );
} );
add_filter( 'user_has_cap', static function ( array $caps ) use ( $frontman_seo_test ): array {
	if ( 'deny-yoast-options' === $frontman_seo_test ) { $caps['wpseo_manage_options'] = false; }
	return $caps;
} );
add_filter( 'map_meta_cap', static function ( array $caps, string $cap, int $user_id, array $args ) use ( $frontman_seo_test ): array {
	if ( ( 'deny-object' === $frontman_seo_test && 'edit_post' === $cap ) || ( 'deny-meta' === $frontman_seo_test && 'edit_post_meta' === $cap ) || ( 'deny-term' === $frontman_seo_test && 'edit_term' === $cap ) ) {
		return [ 'do_not_allow' ];
	}
	if ( 'deny-focus' === $frontman_seo_test && 'edit_post_meta' === $cap && '_yoast_wpseo_focuskw' === ( $args[1] ?? '' ) ) {
		return [ 'do_not_allow' ];
	}
	return $caps;
}, PHP_INT_MAX, 4 );
add_filter( 'pre_update_option_wpseo_titles', static function ( $value, $old ) use ( $frontman_seo_test ) {
	return 'partial-archive-save' === $frontman_seo_test && $value['metadesc-ptarchive-frontman_seo_item'] !== $old['metadesc-ptarchive-frontman_seo_item'] ? $old : $value;
}, PHP_INT_MAX, 2 );
add_filter( 'pre_update_option_wpseo_taxonomy_meta', static fn( $value, $old ) => 'deny-term-save' === $frontman_seo_test ? $old : $value, PHP_INT_MAX, 2 );
add_filter( 'wpseo_sanitize_post_meta__yoast_wpseo_focuskw', static fn( string $value ): string => $value . ' [focus-filter]' );
add_filter( 'wpseo_sanitize_post_meta__yoast_wpseo_title', static function ( string $value ): string {
	return $value . ' [runtime-filter]';
} );
add_filter( 'wpseo_sanitize_post_meta__yoast_wpseo_metadesc', static function ( string $value ) use ( $frontman_seo_test ): string {
	if ( 'fail-sanitizer' === $frontman_seo_test ) {
		throw new RuntimeException( 'Injected sanitizer failure.' );
	}
	return $value;
} );
add_filter( 'update_post_metadata', static function ( $check, int $id, string $key ) use ( $frontman_seo_test ) {
	if ( 'silent-title' === $frontman_seo_test && '_yoast_wpseo_title' === $key ) {
		return true;
	}
	return ( 'fail-write' === $frontman_seo_test && '_yoast_wpseo_metadesc' === $key )
		|| ( 'fail-focus' === $frontman_seo_test && '_yoast_wpseo_focuskw' === $key ) ? false : $check;
}, PHP_INT_MAX, 3 );
add_filter( 'get_post_metadata', static function ( $value, int $id, string $key ) use ( $frontman_seo_test ) {
	global $wpdb;
	if ( 'fail-read' === $frontman_seo_test && '' === $key
		&& $wpdb->get_var( $wpdb->prepare( "SELECT meta_id FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_title'", $id ) ) ) {
		throw new RuntimeException( 'Injected read-back failure.' );
	}
	if ( 'read-focus' === $frontman_seo_test && '' === $key && $wpdb->get_var( $wpdb->prepare( "SELECT meta_id FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_focuskw'", $id ) ) ) {
		throw new RuntimeException( 'Injected focus read-back failure.' );
	}
	return $value;
}, PHP_INT_MAX, 3 );
