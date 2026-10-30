<?php

require_once __DIR__ . '/RuntimeTestSupport.php';

set_error_handler(
	static function( int $severity, string $message, string $file, int $line ): bool {
		if ( error_reporting() & $severity ) {
			throw new ErrorException( $message, 0, $severity, $file, $line );
		}
		return false;
	}
);

$runtime_case = $argv[1] ?? '';
$cases = frontman_runtime_isolated_cases();
frontman_runtime_assert( '' === $runtime_case || isset( $cases[ $runtime_case ] ), 'Unknown runtime case: ' . $runtime_case );
$runtime_alias = $argv[2] ?? '';
frontman_runtime_assert( '' === $runtime_alias || ( '' !== $runtime_case && $cases[ $runtime_case ]['root_alias'] ), 'This runtime case does not use a root alias.' );
if ( '' !== $runtime_alias ) {
	frontman_runtime_assert( is_link( $runtime_alias ) && realpath( $runtime_alias ) === realpath( '/var/www/html' ), 'Runtime root alias must point to WordPress.' );
	define( 'ABSPATH', $runtime_alias . '/' );
}
try {
	require '/var/www/html/wp-load.php';
	$schema = [ 'type' => 'array', 'items' => [ 'type' => 'integer' ], 'minItems' => 1 ];
	frontman_runtime_same( true, rest_validate_value_from_schema( [ 1 ], $schema, 'items' ), 'WordPress schema must accept a valid value.' );
	$invalid = rest_validate_value_from_schema( [], $schema, 'items' );
	frontman_runtime_assert( is_wp_error( $invalid ) && 'rest_too_few_items' === $invalid->get_error_code(), 'WordPress schema must reject too few items.' );
	if ( '' === $runtime_case ) {
		require __DIR__ . '/CoreRuntimeCases.php';
		require __DIR__ . '/IsolatedRuntimeCases.php';
	} else {
		require __DIR__ . '/' . $cases[ $runtime_case ]['file'];
	}
} finally {
	if ( '' !== $runtime_alias ) {
		if ( ! is_link( $runtime_alias ) ) {
			frontman_runtime_assert( symlink( '/var/www/html', $runtime_alias ), 'Could not restore the runtime root alias for WordPress shutdown.' );
		}
		clearstatcache( true );
	}
}

fwrite( STDOUT, 'OK (WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ( '' === $runtime_case ? '' : ', case ' . $runtime_case ) . ")\n" );
