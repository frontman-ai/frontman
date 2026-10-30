<?php
require __DIR__ . '/NativeWordPress.php';
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-seo.php';
require_once __DIR__ . '/../includes/class-frontman-plugin-dependencies.php';
$validation = rest_validate_value_from_schema( [], [ 'type' => 'array', 'minItems' => 1 ], 'items' );
if ( ! is_wp_error( $validation ) || 'rest_too_few_items' !== $validation->get_error_code() ) {
	throw new RuntimeException( 'Native schema validation did not reject too few items.' );
}
wp_cache_set( '1:notoptions', [ 'active_sitewide_plugins' => true ], 'site-options' );
do_action( 'wpseo_loaded' );
function sanitize_meta() { throw new RuntimeException( 'Unavailable handler reached metadata.' ); }
$wp_version = '7.0.2';
$seo   = new Frontman_Tool_Seo();
$tools = new Frontman_Tools();
foreach ( [ [], [ 'wordpress-seo/wp-seo.php' ], [ 'wordpress-seo/wp-seo.php' ] ] as $case => $active_plugins ) {
	wp_cache_set( 'alloptions', [ 'active_plugins' => $active_plugins ], 'options' );
	$expected = 'absent or not loaded';
	if ( 2 === $case ) {
		define( 'WPSEO_VERSION', $argv[1] ?? '28.6' );
		$expected = 'runtime methods';
	}
	$reason = Frontman_Tool_Seo::unavailable_reason();
	if ( ! is_string( $reason ) || false === strpos( $reason, $expected ) ) {
		throw new RuntimeException( 'Missing Yoast or missing runtime API was not diagnosed.' );
	}
	foreach ( [ 'read_seo', 'update_seo' ] as $handler ) {
		try {
			$seo->$handler( [ 'id' => 7 ] + ( 'update_seo' === $handler ? [ 'title' => 'Must not write' ] : [] ) );
			throw new RuntimeException( 'Unavailable handler accessed post state.' );
		} catch ( Frontman_Tool_Error $error ) {
			if ( $reason !== $error->getMessage() ) {
				throw new RuntimeException( 'Handler compatibility reason differs.' );
			}
		}
	}
}
if ( ! isset( $argv[1] ) ) {
	foreach ( [ '28.4', '99.9' ] as $version ) {
		passthru( escapeshellarg( PHP_BINARY ) . ' -d auto_prepend_file=' . escapeshellarg( __DIR__ . '/ErrorHandler.php' ) . ' ' . escapeshellarg( __FILE__ ) . ' ' . escapeshellarg( $version ), $status );
		if ( 0 !== $status ) {
			throw new RuntimeException( 'Runtime-capability check failed for Yoast ' . $version );
		}
	}
}
if ( ! class_exists( 'WPSEO_Meta' ) ) {
	class WPSEO_Meta {
		public static function get_value() {}
		public static function set_value() {}
		public static function delete() {}
		public static function sanitize_post_meta() {}
	}
}
function get_registered_meta_keys( string $type ): array {
	return [
		'_yoast_wpseo_title' => [ 'sanitize_callback' => [ 'WPSEO_Meta', 'sanitize_post_meta' ] ],
		'_yoast_wpseo_metadesc' => [ 'sanitize_callback' => [ 'WPSEO_Meta', 'sanitize_post_meta' ] ],
		'_yoast_wpseo_focuskw' => [ 'sanitize_callback' => [ 'WPSEO_Meta', 'sanitize_post_meta' ] ],
	];
}
foreach ( [ 'title', 'metadesc', 'focuskw' ] as $key ) {
	add_filter( 'sanitize_post_meta__yoast_wpseo_' . $key, [ 'WPSEO_Meta', 'sanitize_post_meta' ] );
}
if ( null !== Frontman_Tool_Seo::unavailable_reason() ) {
	throw new RuntimeException( 'A valid runtime was rejected for Yoast ' . WPSEO_VERSION );
}
$seo->register( $tools );
if ( 1 !== $tools->get( 'wp_read_seo' )->input_schema['properties']['id']['minimum']
	|| [ 'id' ] !== $tools->get( 'wp_update_seo' )->input_schema['required']
	|| false === strpos( $tools->get( 'wp_update_seo' )->description, 'Provide at least one of title, description, or focus_keyphrase.' ) ) {
	throw new RuntimeException( 'SEO schemas do not match runtime requirements.' );
}
$valid = [ 'id' => 7, 'title' => "  Café %%title%% \\ \"quoted\"  ", 'description' => '' ];
if ( $valid !== $tools->sanitize_input( 'wp_update_seo', $valid ) ) {
	throw new RuntimeException( 'Valid raw SEO input changed before the handler.' );
}
$focus = [ 'id' => 7, 'focus_keyphrase' => "  Café \\ \"quoted\"  " ];
if ( $focus !== $tools->sanitize_input( 'wp_update_seo', $focus ) ) {
	throw new RuntimeException( 'Valid raw focus input changed before the handler.' );
}

$invalid = [
	[ 'wp_read_seo', [ 'id' => '7' ] ],
	[ 'wp_read_seo', [ 'id' => 0 ] ],
	[ 'wp_update_seo', [ 'id' => 7 ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'title' => null ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'focus_keyphrase' => 123 ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'focus_keyphrase' => "bad\xC3\x28" ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'title' => "bad\xC3\x28" ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'title' => 'safe', 'meta_key' => '_danger' ] ],
];
foreach ( $invalid as [ $name, $input ] ) {
	try {
		$tools->sanitize_input( $name, $input );
		throw new RuntimeException( 'Invalid raw SEO input was accepted.' );
	} catch ( Frontman_Tool_Error $error ) {
		continue;
	}
}
try {
	$seo->read_seo( [ 'id' => '7' ] );
	throw new RuntimeException( 'Direct SEO input was coerced.' );
} catch ( Frontman_Tool_Error $error ) {
	fwrite( STDOUT, "OK (SEO raw validation, schemas and compatibility guards)\n" );
}
