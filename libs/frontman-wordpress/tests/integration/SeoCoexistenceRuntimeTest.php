<?php

require_once ABSPATH . 'wp-admin/includes/plugin.php';
frontman_runtime_assert( defined( 'SURERANK_VERSION' ) && '1.10.2' === SURERANK_VERSION, 'Real pinned SureRank must be loaded.' );
frontman_runtime_assert( defined( 'WPSEO_VERSION' ) && is_plugin_active( 'wordpress-seo/wp-seo.php' ), 'Real Yoast must coexist.' );
$tools = Frontman_Tools::instance();
$seo = new Frontman_Tool_Seo();
$info = ( new Frontman_Tool_Templates() )->get_site_info( [] );
frontman_runtime_assert( null === $tools->get( 'wp_read_seo' ) && null === $tools->get( 'wp_update_seo' ), 'Conflicting providers must not advertise SEO tools.' );
frontman_runtime_assert( null === $info['seo_capabilities']['provider'] && false === $info['seo_capabilities']['read'] && false === $info['seo_capabilities']['write'], 'Conflict capabilities are misleading.' );
frontman_runtime_assert( is_string( Frontman_Tool_Seo::read_unavailable_reason() ), 'Conflict read reason missing.' );
foreach ( [ 'read_seo', 'update_seo' ] as $handler ) {
	try {
		$seo->$handler( [ 'id' => 1 ] + ( 'update_seo' === $handler ? [ 'title' => 'Must not save' ] : [] ) );
		throw new RuntimeException( 'Direct conflicting-provider operation accepted.' );
	} catch ( Frontman_Tool_Error $error ) {
		frontman_runtime_same( Frontman_Tool_Seo::read_unavailable_reason(), $error->getMessage(), 'Conflict direct guard differs.' );
	}
}
