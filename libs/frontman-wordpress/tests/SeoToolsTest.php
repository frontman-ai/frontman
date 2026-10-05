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
$tools = new Frontman_Tools();
$seo->register( $tools );
if ( 1 !== $tools->get( 'wp_read_seo' )->input_schema['properties']['id']['minimum']
	|| isset( $tools->get( 'wp_read_seo' )->input_schema['anyOf'] )
	|| [ [ 'required' => [ 'title' ] ], [ 'required' => [ 'description' ] ] ] !== $tools->get( 'wp_update_seo' )->input_schema['anyOf'] ) {
	throw new RuntimeException( 'SEO schemas do not match runtime requirements.' );
}
foreach ( [ [], [ 'wordpress-seo/wp-seo.php' ], [ 'wordpress-seo/wp-seo.php' ] ] as $case => $active_plugins ) {
	$expected = 'absent or not loaded';
	if ( 2 === $case ) {
		define( 'WPSEO_VERSION', $argv[1] ?? '28.4' );
		$expected = isset( $argv[1] ) ? 'Unsupported Yoast SEO version 99.9; tested versions: 28.4, 19.9.' : 'runtime methods';
	}
	$reason = Frontman_Tool_Seo::unavailable_reason();
	if ( ! is_string( $reason ) || false === strpos( $reason, $expected ) ) {
		throw new RuntimeException( 'Missing Yoast, unsupported version or missing runtime API was not diagnosed.' );
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
	passthru( escapeshellarg( PHP_BINARY ) . ' -d auto_prepend_file=' . escapeshellarg( __DIR__ . '/ErrorHandler.php' ) . ' ' . escapeshellarg( __FILE__ ) . ' 99.9', $status );
	if ( 0 !== $status ) {
		throw new RuntimeException( 'Unsupported-version check failed.' );
	}
}
$valid = [ 'id' => 7, 'title' => "  Café %%title%% \\ \"quoted\"  ", 'description' => '' ];
if ( $valid !== $tools->sanitize_input( 'wp_update_seo', $valid ) ) {
	throw new RuntimeException( 'Valid raw SEO input changed before the handler.' );
}

$invalid = [
	[ 'wp_read_seo', [ 'id' => '7' ] ],
	[ 'wp_read_seo', [ 'id' => 0 ] ],
	[ 'wp_update_seo', [ 'id' => 7 ] ],
	[ 'wp_update_seo', [ 'id' => 7, 'title' => null ] ],
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
