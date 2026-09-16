<?php
define( 'ABSPATH', sys_get_temp_dir() . '/frontman-seo-tools/' );
function __( string $message, string $domain = '' ): string { return $message; }
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-seo.php';
$seo   = new Frontman_Tool_Seo();
$tools = new Frontman_Tools();
$seo->register( $tools );
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
	fwrite( STDOUT, "OK (8 assertions)\n" );
}
