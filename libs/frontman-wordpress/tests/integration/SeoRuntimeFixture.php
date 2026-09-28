<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
$frontman_seo_test = sanitize_key( wp_unslash( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) );
add_filter( 'redirect_canonical', static fn( $redirect ) => 'render' === $frontman_seo_test ? false : $redirect );
add_action( 'init', static function (): void {
	register_post_type( 'frontman_seo_item', [
		'public'   => true,
		'show_ui'  => true,
		'supports' => [ 'title', 'editor', 'excerpt', 'custom-fields' ],
	] );
} );
add_filter( 'map_meta_cap', static function ( array $caps, string $cap ) use ( $frontman_seo_test ): array {
	if ( ( 'deny-object' === $frontman_seo_test && 'edit_post' === $cap ) || ( 'deny-meta' === $frontman_seo_test && 'edit_post_meta' === $cap ) ) {
		return [ 'do_not_allow' ];
	}
	return $caps;
}, PHP_INT_MAX, 2 );
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
	return 'fail-write' === $frontman_seo_test && '_yoast_wpseo_metadesc' === $key ? false : $check;
}, PHP_INT_MAX, 3 );
add_filter( 'get_post_metadata', static function ( $value, int $id, string $key ) use ( $frontman_seo_test ) {
	global $wpdb;
	if ( 'fail-read' === $frontman_seo_test && '' === $key
		&& $wpdb->get_var( $wpdb->prepare( "SELECT meta_id FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_title'", $id ) ) ) {
		throw new RuntimeException( 'Injected read-back failure.' );
	}
	return $value;
}, PHP_INT_MAX, 3 );
