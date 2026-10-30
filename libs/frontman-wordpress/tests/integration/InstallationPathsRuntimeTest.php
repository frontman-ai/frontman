<?php

frontman_runtime_same( $runtime_alias . '/', ABSPATH, 'WordPress bootstrap must preserve the configured installation alias.' );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$tools = Frontman_Tools::instance();
$call = static function ( array $input ) use ( $tools ): array {
	$result = $tools->call( 'wp_get_site_info', $tools->sanitize_input( 'wp_get_site_info', $input ) );
	frontman_runtime_assert( false === $result['isError'], 'Site info must succeed with the real WordPress runtime.' );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$default = $call( [] );
frontman_runtime_assert( ! array_key_exists( 'installation', $default ) && $default === $call( [ 'include_installation_paths' => false ] ), 'Default and explicit false must omit paths.' );
try {
	$call( [ 'include_installation_paths' => true, 'path' => '/must-not-be-used' ] );
	throw new RuntimeException( 'Unexpected path argument was accepted.' );
} catch ( Frontman_Tool_Error $e ) {
	frontman_runtime_assert( false !== strpos( $e->getMessage(), 'path' ), 'Path rejection did not identify the field.' );
}
$info = $call( [ 'include_installation_paths' => true ] );
frontman_runtime_same( [
	'abspath' => ABSPATH,
	'resolved_abspath' => realpath( '/var/www/html' ) . '/',
], $info['installation'], 'Configured and resolved symlink paths must remain distinct with trailing slashes.' );
unset( $info['installation'] );
frontman_runtime_same( $default, $info, 'Path opt-in must not change other site information.' );
frontman_runtime_assert( unlink( $runtime_alias ), 'Could not remove the installation alias.' );
clearstatcache( true );
frontman_runtime_same( [
	'abspath' => ABSPATH,
	'resolved_abspath' => null,
], $call( [ 'include_installation_paths' => true ] )['installation'], 'Failed resolution must return null, not an inferred root.' );
