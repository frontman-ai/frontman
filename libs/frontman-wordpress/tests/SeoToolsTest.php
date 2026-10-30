<?php
define( 'ABSPATH', sys_get_temp_dir() . '/frontman-seo-tools/' );
function __( string $message, string $domain = '' ): string { return $message; }
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-seo.php';
require_once __DIR__ . '/../includes/class-frontman-plugin-dependencies.php';
function get_option( string $key, $default = false ) { return $GLOBALS['active_plugins'] ?? []; }
function did_action( string $hook ): int { return 1; }
function sanitize_meta() { throw new RuntimeException( 'Unavailable handler reached metadata.' ); }
$wp_version = '7.0.2';
$seo   = new Frontman_Tool_Seo();
foreach ( [ [], [ 'wordpress-seo/wp-seo.php' ], [ 'wordpress-seo/wp-seo.php' ] ] as $case => $active_plugins ) {
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
function has_filter( string $hook, $callback ) { return 10; }
if ( null !== Frontman_Tool_Seo::unavailable_reason() ) {
	throw new RuntimeException( 'A valid runtime was rejected for Yoast ' . WPSEO_VERSION );
}
fwrite( STDOUT, "OK (SEO compatibility guards)\n" );
