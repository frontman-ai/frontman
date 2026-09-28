<?php

define( 'ABSPATH', __DIR__ . '/' );
define( 'FRONTMAN_PLUGIN_DIR', __DIR__ . '/missing-sdk/' );
function get_option( string $name, $default = false ) { return '1'; }
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-sentry.php';

ob_start();
Frontman_Sentry::capture( new RuntimeException( 'Private tool error' ), 'wp_test' );
$output = ob_get_clean();
if ( '' !== $output || class_exists( 'FrontmanVendor\\Sentry\\ClientBuilder', false ) ) {
	throw new RuntimeException( 'Missing SDK must not load Sentry or corrupt the tool response.' );
}
fwrite( STDOUT, "OK (missing SDK does not break tool error handling)\n" );
