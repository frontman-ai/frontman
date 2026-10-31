<?php

frontman_runtime_process_case( 'installation-paths' );
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$tools = Frontman_Tools::instance();
$unavailable = frontman_runtime_call( $tools, 'wp_list_languages', [] );
frontman_runtime_assert( empty( $unavailable['isError'] ), 'Language discovery must be safe without Polylang.' );
frontman_runtime_same( false, json_decode( $unavailable['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR )['api_available'], 'Inactive Polylang must be reported unavailable.' );
if ( is_readable( WP_PLUGIN_DIR . '/polylang/polylang.php' ) ) {
	$had_polylang = is_plugin_active( 'polylang/polylang.php' );
	try {
		if ( ! $had_polylang ) {
			frontman_runtime_assert( ! is_wp_error( activate_plugin( 'polylang/polylang.php' ) ), 'Polylang activation failed.' );
		}
		frontman_runtime_process_case( 'polylang-setup' );
		frontman_runtime_process_case( 'polylang' );
	} finally {
		try {
			frontman_runtime_process_case( 'polylang-cleanup' );
			frontman_runtime_process_case( 'polylang-cleanup-verify' );
		} finally {
			if ( ! $had_polylang ) {
				deactivate_plugins( 'polylang/polylang.php' );
			}
		}
		frontman_runtime_same( $had_polylang, is_plugin_active( 'polylang/polylang.php' ), 'Runtime cases must restore Polylang activation state.' );
	}
}
$had_super_cache = is_plugin_active( 'wp-super-cache/wp-cache.php' );
try {
	if ( ! $had_super_cache ) {
		frontman_runtime_assert( ! is_wp_error( activate_plugin( 'wp-super-cache/wp-cache.php' ) ), 'WP Super Cache activation failed.' );
	}
	frontman_runtime_process_case( 'super-cache' );
} finally {
	if ( ! $had_super_cache ) {
		require_once ABSPATH . 'wp-admin/includes/file.php';
		deactivate_plugins( 'wp-super-cache/wp-cache.php' );
	}
	frontman_runtime_same( $had_super_cache, is_plugin_active( 'wp-super-cache/wp-cache.php' ), 'Runtime cases must restore WP Super Cache activation state.' );
}
if ( version_compare( get_bloginfo( 'version' ), '6.1', '>=' ) && is_readable( WP_PLUGIN_DIR . '/directorist/directorist-base.php' ) ) {
	frontman_runtime_same( '8.10.6', get_plugin_data( WP_PLUGIN_DIR . '/directorist/directorist-base.php', false, false )['Version'], 'Installed Directorist must match the verified package.' );
	$had_directorist = is_plugin_active( 'directorist/directorist-base.php' );
	frontman_runtime_assert( $had_directorist || null === Frontman_Tools::instance()->get( 'wp_read_directorist_listing' ), 'Inactive Directorist must not register the reader.' );
	try {
		if ( ! $had_directorist ) {
			frontman_runtime_assert( ! is_wp_error( activate_plugin( 'directorist/directorist-base.php' ) ), 'Directorist activation failed.' );
		}
		frontman_runtime_process_case( 'directorist' );
	} finally {
		if ( ! $had_directorist ) {
			deactivate_plugins( 'directorist/directorist-base.php' );
		}
		frontman_runtime_same( $had_directorist, is_plugin_active( 'directorist/directorist-base.php' ), 'Runtime cases must restore the original Directorist activation state.' );
	}
}
if ( version_compare( get_bloginfo( 'version' ), '6.9', '<' ) ) {
	fwrite( STDOUT, "Skipping SureRank SEO tools: Frontman SEO tools require WordPress 6.9+.\n" );
	return;
}

frontman_runtime_same( '1.10.2', get_plugin_data( WP_PLUGIN_DIR . '/surerank/surerank.php', false, false )['Version'], 'Installed SureRank must match the verified package.' );
$had_yoast = is_plugin_active( 'wordpress-seo/wp-seo.php' );
$had_surerank = is_plugin_active( 'surerank/surerank.php' );
try {
	frontman_runtime_assert( ! is_wp_error( activate_plugin( 'surerank/surerank.php' ) ), 'SureRank activation failed.' );
	if ( $had_yoast ) {
		frontman_runtime_process_case( 'seo-coexistence' );
		deactivate_plugins( 'wordpress-seo/wp-seo.php' );
	}
	frontman_runtime_process_case( 'surerank' );
} finally {
	if ( ! $had_surerank ) {
		deactivate_plugins( 'surerank/surerank.php' );
	}
	if ( $had_yoast ) {
		frontman_runtime_assert( ! is_wp_error( activate_plugin( 'wordpress-seo/wp-seo.php' ) ), 'Could not restore Yoast.' );
	}
	frontman_runtime_same( $had_yoast, is_plugin_active( 'wordpress-seo/wp-seo.php' ), 'Runtime cases must restore the original Yoast activation state.' );
	frontman_runtime_same( $had_surerank, is_plugin_active( 'surerank/surerank.php' ), 'Runtime cases must restore the original SureRank activation state.' );
}
