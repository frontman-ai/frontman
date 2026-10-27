<?php

function installation_paths_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$alias = sys_get_temp_dir() . '/frontman-installation-' . getmypid();
installation_paths_assert( ! file_exists( $alias ) && ! is_link( $alias ), 'Installation alias must not already exist.' );
installation_paths_assert( symlink( '/var/www/html', $alias ), 'Could not create the WordPress installation alias.' );
try {
	define( 'ABSPATH', $alias . '/' );
	require '/var/www/html/wp-load.php';
	installation_paths_assert( $alias . '/' === ABSPATH, 'WordPress bootstrap must preserve the configured installation alias.' );
	wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
	$tools = Frontman_Tools::instance();
	$call = static function ( array $input ) use ( $tools ): array {
		$result = $tools->call( 'wp_get_site_info', $tools->sanitize_input( 'wp_get_site_info', $input ) );
		installation_paths_assert( false === $result['isError'], 'Site info must succeed with the real WordPress runtime.' );
		return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	};
	$default = $call( [] );
	installation_paths_assert( ! array_key_exists( 'installation', $default ) && $default === $call( [ 'include_installation_paths' => false ] ), 'Default and explicit false must omit paths.' );
	$info = $call( [ 'include_installation_paths' => true, 'path' => '/must-not-be-used' ] );
	installation_paths_assert( [
		'abspath' => ABSPATH,
		'resolved_abspath' => realpath( '/var/www/html' ) . '/',
	] === $info['installation'], 'Configured and resolved symlink paths must remain distinct with trailing slashes.' );
	unset( $info['installation'] );
	installation_paths_assert( $default === $info, 'Path opt-in must not change other site information.' );
	installation_paths_assert( unlink( $alias ), 'Could not remove the installation alias.' );
	clearstatcache( true );
	installation_paths_assert( [
		'abspath' => ABSPATH,
		'resolved_abspath' => null,
	] === $call( [ 'include_installation_paths' => true ] )['installation'], 'Failed resolution must return null, not an inferred root.' );
} finally {
	if ( is_link( $alias ) ) {
		unlink( $alias );
	}
}
echo "OK (real WordPress installation alias, opt-in and failed resolution)\n";
