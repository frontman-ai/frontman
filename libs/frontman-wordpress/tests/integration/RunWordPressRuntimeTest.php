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
require '/tmp/WordPressRuntimeTest.php';
require '/tmp/CustomCssRuntimeTest.php';
restore_error_handler();

fwrite( STDOUT, 'OK (WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n" );
