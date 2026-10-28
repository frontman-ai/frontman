<?php

frontman_runtime_process_case( 'installation-paths' );
if ( version_compare( get_bloginfo( 'version' ), '6.9', '<' ) ) {
	fwrite( STDOUT, "Skipping SureRank SEO tools: Frontman SEO tools require WordPress 6.9+.\n" );
	return;
}

require_once ABSPATH . 'wp-admin/includes/plugin.php';
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
