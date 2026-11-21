<?php

declare(strict_types=1);

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
$frontman_seo_test = sanitize_key( wp_unslash( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) );
add_filter( 'redirect_canonical', static fn( $redirect ) => in_array( $frontman_seo_test, [ 'render', 'broader-noindex' ], true ) ? false : $redirect );
add_filter( 'Yoast\WP\SEO\should_index_indexables', static fn() => 'no-archive-persistence' !== $frontman_seo_test );
add_filter( 'wpseo_should_save_indexable', static fn( $save ) => 'silent-archive-refresh' === $frontman_seo_test ? false : $save );
add_filter( 'Yoast\WP\SEO\should_index_indexables', static function( $save ) use ( $frontman_seo_test ) {
	if ( 'fail-indexing-preflight' === $frontman_seo_test && did_action( 'parse_request' ) > 0 ) { throw new RuntimeException( 'Injected indexing preflight failure.' ); }
	return 'no-indexing-persistence' === $frontman_seo_test ? false : $save;
} );
add_filter( 'wpseo_sanitize_post_meta__yoast_wpseo_meta-robots-noindex', static function( $value ) use ( $frontman_seo_test ) {
	if ( 'fail-indexing-sanitizer' === $frontman_seo_test ) { throw new RuntimeException( 'Injected indexing sanitizer failure.' ); }
	return $value;
} );
add_filter( 'option_wpseo', static function( $options ) use ( $frontman_seo_test ) {
	if ( 'open-advanced' === $frontman_seo_test ) { $options['disableadvanced_meta'] = false; }
	return $options;
} );
add_filter( 'query', static function( string $query ) use ( $frontman_seo_test ): string {
	global $wpdb;
	if ( did_action( 'parse_request' ) > 0 && preg_match( '/^\s*SELECT\b.*\bFROM\s+`?' . preg_quote( $wpdb->prefix . 'yoast_indexable', '/' ) . '`?\s/is', $query ) ) {
		if ( 'fail-indexing-select' === $frontman_seo_test ) {
			$wpdb->suppress_errors( true );
			return 'SELECT frontman_indexing_missing_column FROM ' . $wpdb->prefix . 'yoast_indexable';
		}
		if ( 'stale-indexing-error' === $frontman_seo_test && empty( $GLOBALS['frontman_indexing_prior_error'] ) ) {
			$suppressed = $wpdb->suppress_errors( true );
			$wpdb->query( 'SELECT frontman_indexing_prior_error' );
			$GLOBALS['frontman_indexing_prior_error'] = '' !== $wpdb->last_error;
			$wpdb->suppress_errors( $suppressed );
		}
	}
	if ( 'silent-indexing-refresh' === $frontman_seo_test && preg_match( '/^\s*UPDATE\s+`?[^ ]*yoast_indexable`?\s/i', $query ) ) {
		throw new RuntimeException( 'Injected indexable persistence failure.' );
	}
	return $query;
} );
add_filter( 'wpseo_should_save_indexable', static function( $save, $indexable ) use ( $frontman_seo_test ) {
	if ( 'missing-indexing-refresh' === $frontman_seo_test && 'post' === $indexable->object_type ) {
		if ( $indexable->id ) { $indexable->delete(); }
		throw new RuntimeException( 'Injected missing indexable persistence failure.' );
	}
	return $save;
}, PHP_INT_MAX, 2 );
add_action( 'init', static function() use ( $frontman_seo_test ): void {
	if ( 'missing-indexing-sanitizer' === $frontman_seo_test ) {
		remove_filter( 'sanitize_post_meta__yoast_wpseo_meta-robots-noindex', [ 'WPSEO_Meta', 'sanitize_post_meta' ] );
	}
}, PHP_INT_MAX );
add_filter( 'delete_post_metadata', static fn( $check, $id, $key ) => 'fail-indexing-delete' === $frontman_seo_test && '_yoast_wpseo_meta-robots-noindex' === $key ? false : $check, PHP_INT_MAX, 3 );
add_action( 'updated_post_meta', static function( $meta_id, $id, $key ) use ( $frontman_seo_test ): void {
	if ( 'read-indexing' === $frontman_seo_test && '_yoast_wpseo_meta-robots-noindex' === $key ) { $GLOBALS['frontman_indexing_read_failure'] = true; }
}, 10, 3 );
add_action( 'wp_head', static function() use ( $frontman_seo_test ): void {
	if ( 'broader-noindex' === $frontman_seo_test ) {
		echo '<meta content="noindex, follow" name="robots"><meta name="robots" content="max-snippet:20"><meta name="googlebot" content="noindex">';
	}
} );
add_action( 'send_headers', static function() use ( $frontman_seo_test ): void {
	if ( 'broader-noindex' === $frontman_seo_test ) { header( 'X-Robots-Tag: bingbot: noindex', false ); }
} );
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
	if ( in_array( $frontman_seo_test, [ 'deny-advanced', 'open-advanced' ], true ) ) { $caps['wpseo_edit_advanced_metadata'] = false; $caps['wpseo_manage_options'] = false; }
	return $caps;
} );
add_filter( 'map_meta_cap', static function ( array $caps, string $cap, int $user_id, array $args ) use ( $frontman_seo_test ): array {
	if ( ( 'deny-object' === $frontman_seo_test && 'edit_post' === $cap ) || ( 'deny-meta' === $frontman_seo_test && 'edit_post_meta' === $cap ) || ( 'deny-term' === $frontman_seo_test && 'edit_term' === $cap ) ) {
		return [ 'do_not_allow' ];
	}
	if ( 'deny-focus' === $frontman_seo_test && 'edit_post_meta' === $cap && '_yoast_wpseo_focuskw' === ( $args[1] ?? '' ) ) {
		return [ 'do_not_allow' ];
	}
	if ( 'deny-indexing' === $frontman_seo_test && 'edit_post_meta' === $cap && '_yoast_wpseo_meta-robots-noindex' === ( $args[1] ?? '' ) ) { return [ 'do_not_allow' ]; }
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
	if ( 'fail-indexing-write' === $frontman_seo_test && '_yoast_wpseo_meta-robots-noindex' === $key ) { return false; }
	if ( 'silent-title' === $frontman_seo_test && '_yoast_wpseo_title' === $key ) {
		return true;
	}
	return ( 'fail-write' === $frontman_seo_test && '_yoast_wpseo_metadesc' === $key )
		|| ( 'fail-focus' === $frontman_seo_test && '_yoast_wpseo_focuskw' === $key ) ? false : $check;
}, PHP_INT_MAX, 3 );
add_filter( 'get_post_metadata', static function ( $value, int $id, string $key ) use ( $frontman_seo_test ) {
	global $wpdb;
	if ( ! empty( $GLOBALS['frontman_indexing_read_failure'] ) && '' === $key ) { throw new RuntimeException( 'Injected indexing readback failure.' ); }
	if ( 'fail-read' === $frontman_seo_test && '' === $key
		&& $wpdb->get_var( $wpdb->prepare( "SELECT meta_id FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_title'", $id ) ) ) {
		throw new RuntimeException( 'Injected read-back failure.' );
	}
	if ( 'read-focus' === $frontman_seo_test && '' === $key && $wpdb->get_var( $wpdb->prepare( "SELECT meta_id FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = '_yoast_wpseo_focuskw'", $id ) ) ) {
		throw new RuntimeException( 'Injected focus read-back failure.' );
	}
	return $value;
}, PHP_INT_MAX, 3 );
