<?php

set_error_handler(
	static function( int $severity, string $message, string $file, int $line ): bool {
		if ( error_reporting() & $severity ) {
			throw new ErrorException( $message, 0, $severity, $file, $line );
		}
		return false;
	}
);
