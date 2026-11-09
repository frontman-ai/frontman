<?php

declare(strict_types=1);

require_once ABSPATH . 'wp-admin/includes/plugin.php';
$welcome_plugin = plugin_basename( FRONTMAN_PLUGIN_FILE );
$welcome_admin = get_user_by( 'login', 'admin' );
$welcome_subscriber = get_user_by( 'login', 'runtime-subscriber' );
$welcome_previous_user = get_current_user_id();
$welcome_permalink = get_option( 'permalink_structure' );
$welcome_marker = get_option( 'frontman_welcome_activated' );
$welcome_dismissed = get_user_option( 'frontman_welcome_dismissed', $welcome_admin->ID );
$welcome_active_plugins = get_option( 'active_plugins' );
$welcome_transient = get_option( '_transient_elementor_activation_redirect' );
$welcome_transient_timeout = get_option( '_transient_timeout_elementor_activation_redirect' );
$welcome_session = static function( int $user_id ): array {
	$token = WP_Session_Tokens::get_instance( $user_id )->create( time() + HOUR_IN_SECONDS );
	$auth = wp_generate_auth_cookie( $user_id, time() + HOUR_IN_SECONDS, 'auth', $token );
	return [ $auth, $token ];
};
$welcome_request = static function( string $cookie, array $fields ): array {
	return frontman_runtime_http( 'POST', '/wp-admin/admin-post.php', $cookie, null, http_build_query( $fields ), '', '', AUTH_COOKIE, false, 'application/x-www-form-urlencoded' );
};
try {
	// Elementor's activation redirect runs before admin-post handlers on the first admin request.
	delete_transient( 'elementor_activation_redirect' );
	delete_option( 'frontman_welcome_activated' );
	delete_user_option( $welcome_admin->ID, 'frontman_welcome_dismissed' );
	[ $admin_cookie, $admin_token ] = $welcome_session( $welcome_admin->ID );
	[ $subscriber_cookie, $subscriber_token ] = $welcome_session( $welcome_subscriber->ID );
	$welcome_page = static function( string $cookie ): string {
		$response = frontman_runtime_http( 'GET', '/wp-admin/profile.php', $cookie, null, null, '', '', AUTH_COOKIE );
		frontman_runtime_same( 200, $response['status'], 'Admin page must load.' );
		return $response['body'];
	};
	wp_set_current_user( $welcome_admin->ID );
	frontman_runtime_assert( false === strpos( $welcome_page( $admin_cookie ), 'Frontman is active. Start here.' ), 'An upgrade without activation must not show the welcome.' );
	deactivate_plugins( $welcome_plugin );
	frontman_runtime_assert( ! is_wp_error( activate_plugin( $welcome_plugin ) ), 'Welcome activation failed.' );
	foreach ( [ '' => '/index.php/frontman', '/index.php/%postname%/' => '/index.php/frontman', '/%postname%/' => '/frontman' ] as $structure => $path ) {
		update_option( 'permalink_structure', $structure );
		$notice = $welcome_page( $admin_cookie );
		foreach ( [ 'Frontman is active. Start here.', 'live preview', 'Sign in to Frontman', 'connect an AI provider', 'Provider charges may apply', 'open a page', 'backup', 'live site', esc_url( home_url( $path ) ) ] as $text ) {
			frontman_runtime_assert( false !== strpos( $notice, $text ), 'Activation notice missing: ' . $text );
		}
		frontman_runtime_assert( 1 === preg_match( '~<form method="post" action="' . preg_quote( esc_url( admin_url( 'admin-post.php' ) ), '~' ) . '">\\s*<input type="hidden" name="action" value="frontman_dismiss_welcome">\\s*<input type="hidden" id="_wpnonce" name="_wpnonce" value="([^"]+)"~', $notice, $nonce_match ), 'Welcome form must submit its action and nonce to admin-post.' );
		$admin_nonce = $nonce_match[1];
		$links = apply_filters( 'plugin_action_links_' . $welcome_plugin, [] );
		frontman_runtime_assert( false !== strpos( $links[0], esc_url( home_url( $path ) ) ) && false !== strpos( $links[0], 'Open Frontman' ), 'Plugin action uses the active permalink mode.' );
	}
	frontman_runtime_assert( false === strpos( $welcome_page( $subscriber_cookie ), 'Frontman is active. Start here.' ), 'Subscribers must not see the welcome.' );
	$fields = [ 'action' => 'frontman_dismiss_welcome', '_wpnonce' => $admin_nonce ];
	$subscriber_response = $welcome_request( $subscriber_cookie, $fields );
	frontman_runtime_same( 403, $subscriber_response['status'], 'Subscribers cannot dismiss the welcome: ' . implode( ' | ', $subscriber_response['headers'] ) );
	$fields['_wpnonce'] = 'invalid';
	frontman_runtime_same( 403, $welcome_request( $admin_cookie, $fields )['status'], 'Invalid nonces cannot dismiss the welcome.' );
	unset( $fields['_wpnonce'] );
	frontman_runtime_same( 403, $welcome_request( $admin_cookie, $fields )['status'], 'Missing nonces cannot dismiss the welcome.' );
	wp_cache_delete( $welcome_admin->ID, 'user_meta' );
	wp_set_current_user( $welcome_admin->ID );
	frontman_runtime_assert( false !== strpos( $welcome_page( $admin_cookie ), 'Frontman is active. Start here.' ), 'Rejected requests must leave the notice visible.' );
	$fields['_wpnonce'] = $admin_nonce;
	$admin_response = $welcome_request( $admin_cookie, $fields );
	frontman_runtime_same( 302, $admin_response['status'], 'Valid dismissal completes through WordPress admin-post.' );
	frontman_runtime_assert( false !== strpos( implode( ' | ', $admin_response['headers'] ), 'Location: ' . admin_url( 'plugins.php' ) ), 'Valid dismissal redirects to plugins.' );
	wp_cache_delete( $welcome_admin->ID, 'user_meta' );
	frontman_runtime_assert( false === strpos( $welcome_page( $admin_cookie ), 'Frontman is active. Start here.' ), 'Dismissal persists across requests.' );
	deactivate_plugins( $welcome_plugin );
	frontman_runtime_assert( ! is_wp_error( activate_plugin( $welcome_plugin ) ), 'Reactivation failed.' );
	frontman_runtime_assert( false === strpos( $welcome_page( $admin_cookie ), 'Frontman is active. Start here.' ), 'Reactivation must not reset a dismissal.' );
	frontman_runtime_assert( false !== strpos( apply_filters( 'plugin_action_links_' . $welcome_plugin, [] )[0], 'Open Frontman' ), 'Plugin action remains after dismissal.' );
} finally {
	if ( isset( $admin_token ) ) {
		WP_Session_Tokens::get_instance( $welcome_admin->ID )->destroy( $admin_token );
	}
	if ( isset( $subscriber_token ) ) {
		WP_Session_Tokens::get_instance( $welcome_subscriber->ID )->destroy( $subscriber_token );
	}
	if ( false === $welcome_marker ) {
		delete_option( 'frontman_welcome_activated' );
	} else {
		update_option( 'frontman_welcome_activated', $welcome_marker );
	}
	if ( false === $welcome_dismissed ) {
		delete_user_option( $welcome_admin->ID, 'frontman_welcome_dismissed' );
	} else {
		update_user_option( $welcome_admin->ID, 'frontman_welcome_dismissed', $welcome_dismissed );
	}
	update_option( 'permalink_structure', $welcome_permalink );
	update_option( 'active_plugins', $welcome_active_plugins );
	foreach ( [ '_transient_elementor_activation_redirect' => $welcome_transient, '_transient_timeout_elementor_activation_redirect' => $welcome_transient_timeout ] as $option => $value ) {
		if ( false === $value ) {
			delete_option( $option );
		} else {
			update_option( $option, $value );
		}
	}
	wp_set_current_user( $welcome_previous_user );
}
