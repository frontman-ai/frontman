<?php

declare(strict_types=1);

frontman_runtime_same( getenv( 'EXPECTED_YOAST_VERSION' ), WPSEO_VERSION, 'The real pinned Yoast must be loaded on the network.' );
wp_set_current_user( get_user_by( 'login', 'multi-admin' )->ID );
frontman_runtime_assert( current_user_can( 'manage_network' ), 'Use the disposable network administrator.' );
$tools = Frontman_Tools::instance();
$root = get_current_blog_id();
$site = 0;
$root_id = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'draft', 'post_title' => 'Root indexing fixture', 'post_content' => 'Private root body' ], true );
frontman_runtime_assert( is_int( $root_id ), 'Create root indexing fixture.' );
$source = static fn( int $id ): array => [ get_post( $id, ARRAY_A ), get_post_meta( $id ) ];
try {
	$result = frontman_runtime_call( $tools, 'wp_update_seo', [ 'id' => $root_id, 'indexing' => 'noindex' ] );
	frontman_runtime_same( false, $result['isError'], 'Root-site indexing succeeds: ' . wp_json_encode( $result ) );
	$before = $source( $root_id );
	$site = wpmu_create_blog( 'frontman-multisite.example.test', '/seo-indexing/', 'SEO indexing fixture', get_current_user_id() );
	frontman_runtime_assert( is_int( $site ), 'Create a real disposable second site.' );
	switch_to_blog( $site );
	try {
		$id = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'draft', 'post_title' => 'Switched indexing fixture', 'post_content' => 'Private switched body' ], true );
		frontman_runtime_assert( is_int( $id ) && ms_is_switched(), 'Create the switched-site object.' );
		$switched_before = $source( $id );
		$denied = frontman_runtime_call( $tools, 'wp_update_seo', [ 'id' => $id, 'title' => 'Must not save', 'indexing' => 'index' ] );
		frontman_runtime_same( Frontman_Tools::error_result( 'You cannot edit indexing metadata on this site and object.' ), $denied, 'Reject switched-site mixed writes before mutation.' );
		frontman_runtime_same( $switched_before, $source( $id ), 'Switched-site rejection preserves the post and all metadata.' );
		wp_delete_post( $id, true );
	} finally {
		restore_current_blog();
	}
	frontman_runtime_same( $root, get_current_blog_id(), 'Restore the root site.' );
	frontman_runtime_same( $before, $source( $root_id ), 'Switched writes cannot change the root-site object.' );
	$repeat = frontman_runtime_call( $tools, 'wp_update_seo', [ 'id' => $root_id, 'indexing' => 'noindex' ] );
	frontman_runtime_same( false, $repeat['isError'], 'Root indexing resumes after restoring the site: ' . wp_json_encode( $repeat ) );
	$data = json_decode( $repeat['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_same( [ false, true ], [ $data['changed'], $data['indexable_refreshed'] ], 'Root same-value refresh succeeds after a real site switch.' );
} finally {
	while ( ms_is_switched() ) { restore_current_blog(); }
	wp_delete_post( $root_id, true );
	if ( is_int( $site ) && $site > 0 ) {
		require_once ABSPATH . 'wp-admin/includes/ms.php';
		wpmu_delete_blog( $site, true );
	}
	wp_set_current_user( 0 );
}
fwrite( STDOUT, "Yoast real switched-site indexing rejection passed.\n" );
