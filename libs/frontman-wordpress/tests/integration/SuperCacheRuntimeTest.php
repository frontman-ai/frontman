<?php

require_once ABSPATH . 'wp-admin/includes/plugin.php';
frontman_runtime_assert( ! is_multisite(), 'WP Super Cache regression requires a single-site installation.' );
frontman_runtime_same( '3.0.3', get_plugin_data( WP_PLUGIN_DIR . '/wp-super-cache/wp-cache.php', false, false )['Version'], 'Installed WP Super Cache must match the tested package.' );
frontman_runtime_assert( function_exists( 'wp_cache_clear_cache' ), 'WP Super Cache purge function must be loaded.' );

$tools = Frontman_Tools::instance();
$plugins = frontman_runtime_call( $tools, 'wp_list_cache_plugins', [] );
frontman_runtime_assert( empty( $plugins['isError'] ), 'Cache-plugin discovery must succeed.' );
$discovered = json_decode( $plugins['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
frontman_runtime_same( 'wp-super-cache', $discovered['plugins'][0]['slug'], 'WP Super Cache must be discovered.' );
frontman_runtime_same( true, $discovered['plugins'][0]['clearSupport'], 'WP Super Cache must advertise purge support.' );

global $cache_path;
$cache_root = realpath( WP_CONTENT_DIR ) . '/cache/';
frontman_runtime_assert( is_string( $cache_path ) && trailingslashit( $cache_path ) === $cache_root, 'Purge must target the disposable runtime cache directory.' );
$fixture_dir = $cache_root . 'supercache/frontman-runtime.example.test/frontman-purge-regression';
$fixture = $fixture_dir . '/index.html';
frontman_runtime_assert( wp_mkdir_p( $fixture_dir ), 'Could not create cached-page fixture.' );
frontman_runtime_assert( false !== file_put_contents( $fixture, 'cached fixture' ) && is_file( $fixture ), 'Could not seed a cached page.' );
try {
	$purge = frontman_runtime_call( $tools, 'wp_clear_cache', [] );
	frontman_runtime_assert( empty( $purge['isError'] ), 'WP Super Cache purge failed: ' . ( $purge['content'][0]['text'] ?? '' ) );
	$data = json_decode( $purge['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( in_array( 'wp-super-cache', $data['clearedPlugins'], true ), 'Purge must report WP Super Cache.' );
	clearstatcache( true, $fixture );
	frontman_runtime_assert( ! file_exists( $fixture ), 'Purge must delete the cached page, not only report success.' );
} finally {
	if ( is_file( $fixture ) ) {
		unlink( $fixture );
	}
}
