<?php

set_error_handler(
	static function( int $severity, string $message, string $file, int $line ): bool {
		if ( error_reporting() & $severity ) {
			throw new ErrorException( $message, 0, $severity, $file, $line );
		}
		return false;
	}
);

require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$yoast = getenv( 'EXPECTED_YOAST_VERSION' );
if ( false !== $yoast && '' !== $yoast ) {
	if ( $yoast !== get_plugin_data( WP_PLUGIN_DIR . '/wordpress-seo/wp-seo.php', false, false )['Version'] ) {
		throw new RuntimeException( 'Installed Yoast version does not match the verified package.' );
	}
	$result = activate_plugin( 'wordpress-seo/wp-seo.php' );
	if ( is_wp_error( $result ) ) {
		throw new RuntimeException( $result->get_error_message() );
	}
}
$result = activate_plugin( 'frontman-agentic-ai-editor/frontman.php' );
if ( is_wp_error( $result ) ) {
	throw new RuntimeException( $result->get_error_message() );
}

restore_error_handler();
