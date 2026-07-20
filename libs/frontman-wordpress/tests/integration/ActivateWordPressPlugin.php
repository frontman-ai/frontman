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

$result = activate_plugin( 'frontman-agentic-ai-editor/frontman.php' );
if ( is_wp_error( $result ) ) {
	throw new RuntimeException( $result->get_error_message() );
}

restore_error_handler();
