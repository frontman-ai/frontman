<?php

require_once ABSPATH . 'wp-admin/includes/plugin.php';
frontman_runtime_same( '3.8.3', get_plugin_data( WP_PLUGIN_DIR . '/polylang/polylang.php', false, false )['Version'], 'Installed Polylang must match the tested package.' );
frontman_runtime_assert( function_exists( 'pll_languages_list' ), 'Polylang public API must load when languages are configured.' );
wp_set_current_user( 1 );
$tools = Frontman_Tools::instance();
$call = static function( string $name, array $arguments ) use ( $tools ): array {
	$result = frontman_runtime_call( $tools, $name, $arguments );
	frontman_runtime_assert( empty( $result['isError'] ), $name . ' failed: ' . ( $result['content'][0]['text'] ?? '' ) );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$reject = static function( string $name, array $arguments, string $reason ) use ( $tools ): void {
	$result = frontman_runtime_call( $tools, $name, $arguments );
	frontman_runtime_assert( ! empty( $result['isError'] ) && false !== strpos( $result['content'][0]['text'], $reason ), $name . ' must reject ' . $reason . ': ' . ( $result['content'][0]['text'] ?? '' ) );
};

$languages = $call( 'wp_list_languages', [] );
frontman_runtime_same( true, $languages['plugin_active'], 'Active Polylang must be detected.' );
frontman_runtime_same( true, $languages['api_available'], 'Configured Polylang must expose its API.' );
frontman_runtime_same( [ 'en', 'fr', 'de' ], $languages['languages'], 'Empty configured languages must be listed.' );
frontman_runtime_same( 'en', $languages['default_language'], 'First fixture language must be the default.' );

$posts = [];
try {
	foreach ( [ 'English', 'Français', 'Other' ] as $title ) {
		$id = wp_insert_post( [ 'post_title' => $title, 'post_type' => 'page', 'post_status' => 'draft' ], true );
		frontman_runtime_assert( ! is_wp_error( $id ) && $id > 0, 'Could not create Polylang test page.' );
		$posts[] = $id;
	}
	[ $en, $fr, $other ] = $posts;
	$reject( 'wp_set_post_language', [ 'id' => $en, 'lang' => 'zz' ], 'Unknown Polylang language' );
	frontman_runtime_same( 'en', $call( 'wp_read_post_language', [ 'id' => $en ] )['lang'], 'Polylang assigns the default language to new pages.' );
	frontman_runtime_same( 'en', $call( 'wp_set_post_language', [ 'id' => $en, 'lang' => 'en' ] )['lang'], 'Language assignment must read back.' );
	frontman_runtime_same( 'fr', $call( 'wp_set_post_language', [ 'id' => $fr, 'lang' => 'fr' ] )['lang'], 'Second language assignment must read back.' );
	frontman_runtime_same( 'en', $call( 'wp_set_post_language', [ 'id' => $en, 'lang' => 'en' ] )['lang'], 'Repeated assignment must be idempotent.' );
	$listed = $call( 'wp_list_posts', [ 'post_type' => 'page', 'status' => 'draft', 'lang' => 'fr', 'per_page' => 100 ] );
	$listed_ids = array_column( $listed['posts'], 'id' );
	frontman_runtime_assert( in_array( $fr, $listed_ids, true ) && ! in_array( $en, $listed_ids, true ), 'Language filtering must distinguish translated drafts.' );
	$reject( 'wp_list_posts', [ 'lang' => 'zz' ], 'configured Polylang language' );
	register_post_type( 'neutral_fixture', [ 'public' => true, 'label' => 'Neutral Fixture' ] );
	$reject( 'wp_list_posts', [ 'post_type' => 'neutral_fixture', 'lang' => 'fr' ], 'does not manage the requested post type' );
	unregister_post_type( 'neutral_fixture' );
	frontman_runtime_same( 'de', $call( 'wp_set_post_language', [ 'id' => $other, 'lang' => 'de' ] )['lang'], 'Third post must receive a new language.' );
	frontman_runtime_same( null, $tools->get( 'wp_link_post_translations' ), 'Unsafe translation linking must not be exposed.' );
	pll_save_post_translations( [ 'en' => $en, 'fr' => $fr, 'de' => $other ] );
	foreach ( $posts as $id ) {
		frontman_runtime_same( [ 'de' => $other, 'en' => $en, 'fr' => $fr ], $call( 'wp_read_post_language', [ 'id' => $id ] )['translations'], 'Post-language reads must expose the group linked by Polylang.' );
	}
	$reject( 'wp_set_post_language', [ 'id' => $en, 'lang' => 'fr' ], 'linked post' );
	wp_set_current_user( 0 );
	$reject( 'wp_set_post_language', [ 'id' => $other, 'lang' => 'de' ], 'Insufficient permission' );
	$reject( 'wp_read_post_language', [ 'id' => $fr ], 'Insufficient permission' );
	wp_set_current_user( 1 );
} finally {
	wp_set_current_user( 1 );
	foreach ( $posts as $id ) {
		wp_delete_post( $id, true );
	}
}
