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
$welcome_ui = new Frontman_UI();
$welcome_render = static function() use ( $welcome_ui ): string {
	ob_start();
	$welcome_ui->welcome_notice();
	return ob_get_clean();
};
$welcome_session = static function( int $user_id ): array {
	$token = WP_Session_Tokens::get_instance( $user_id )->create( time() + HOUR_IN_SECONDS );
	$auth = wp_generate_auth_cookie( $user_id, time() + HOUR_IN_SECONDS, 'auth', $token );
	$logged_in = wp_generate_auth_cookie( $user_id, time() + HOUR_IN_SECONDS, 'logged_in', $token );
	wp_set_current_user( $user_id );
	$_COOKIE[ LOGGED_IN_COOKIE ] = $logged_in;
	$nonce = wp_create_nonce( 'frontman_dismiss_welcome' );
	unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
	return [ AUTH_COOKIE . '=' . $auth . '; ' . LOGGED_IN_COOKIE . '=' . $logged_in, $nonce, $token ];
};
$welcome_request = static function( string $cookie, array $fields ): array {
	$context = stream_context_create( [ 'http' => [
		'method' => 'POST',
		'header' => "Host: frontman-runtime.example.test\r\nCookie: " . $cookie . "\r\nContent-Type: application/x-www-form-urlencoded\r\n",
		'content' => http_build_query( $fields ),
		'ignore_errors' => true,
		'follow_location' => 0,
	] ] );
	$body = file_get_contents( 'http://127.0.0.1/wp-admin/admin-post.php', false, $context );
	preg_match( '/\s(\d{3})\s/', $http_response_header[0], $status );
	return [ (int) $status[1], $body, $http_response_header ];
};
try {
	// Elementor's activation redirect runs before admin-post handlers on the first admin request.
	delete_transient( 'elementor_activation_redirect' );
	delete_option( 'frontman_welcome_activated' );
	delete_user_option( $welcome_admin->ID, 'frontman_welcome_dismissed' );
	wp_set_current_user( $welcome_admin->ID );
	frontman_runtime_same( '', $welcome_render(), 'An upgrade without activation must not show the welcome.' );
	deactivate_plugins( $welcome_plugin );
	frontman_runtime_assert( ! is_wp_error( activate_plugin( $welcome_plugin ) ), 'Welcome activation failed.' );
	foreach ( [ '' => '/index.php/frontman', '/index.php/%postname%/' => '/index.php/frontman', '/%postname%/' => '/frontman' ] as $structure => $path ) {
		update_option( 'permalink_structure', $structure );
		$notice = $welcome_render();
		foreach ( [ 'Frontman is active. Start here.', 'live preview', 'Sign in to Frontman', 'connect an AI provider', 'Provider charges may apply', 'open a page', 'backup', 'live site', esc_url( home_url( $path ) ) ] as $text ) {
			frontman_runtime_assert( false !== strpos( $notice, $text ), 'Activation notice missing: ' . $text );
		}
		$links = apply_filters( 'plugin_action_links_' . $welcome_plugin, [] );
		frontman_runtime_assert( false !== strpos( $links[0], esc_url( home_url( $path ) ) ) && false !== strpos( $links[0], 'Open Frontman' ), 'Plugin action uses the active permalink mode.' );
	}
	[ $admin_cookie, $admin_nonce, $admin_token ] = $welcome_session( $welcome_admin->ID );
	[ $subscriber_cookie, $subscriber_nonce, $subscriber_token ] = $welcome_session( $welcome_subscriber->ID );
	frontman_runtime_same( '', $welcome_render(), 'Subscribers must not see the welcome.' );
	$fields = [ 'action' => 'frontman_dismiss_welcome', '_wpnonce' => $subscriber_nonce ];
	$subscriber_response = $welcome_request( $subscriber_cookie, $fields );
	frontman_runtime_same( 403, $subscriber_response[0], 'Subscribers cannot dismiss the welcome: ' . implode( ' | ', $subscriber_response[2] ) );
	$fields['_wpnonce'] = 'invalid';
	frontman_runtime_same( 403, $welcome_request( $admin_cookie, $fields )[0], 'Invalid nonces cannot dismiss the welcome.' );
	unset( $fields['_wpnonce'] );
	frontman_runtime_same( 403, $welcome_request( $admin_cookie, $fields )[0], 'Missing nonces cannot dismiss the welcome.' );
	wp_cache_delete( $welcome_admin->ID, 'user_meta' );
	wp_set_current_user( $welcome_admin->ID );
	frontman_runtime_assert( '' !== $welcome_render(), 'Rejected requests must leave the notice visible.' );
	$fields['_wpnonce'] = $admin_nonce;
	$admin_response = $welcome_request( $admin_cookie, $fields );
	frontman_runtime_same( 302, $admin_response[0], 'Valid dismissal completes through WordPress admin-post.' );
	frontman_runtime_assert( false !== strpos( implode( ' | ', $admin_response[2] ), 'Location: ' . admin_url( 'plugins.php' ) ), 'Valid dismissal redirects to plugins.' );
	wp_cache_delete( $welcome_admin->ID, 'user_meta' );
	frontman_runtime_same( '', $welcome_render(), 'Dismissal persists across requests.' );
	deactivate_plugins( $welcome_plugin );
	frontman_runtime_assert( ! is_wp_error( activate_plugin( $welcome_plugin ) ), 'Reactivation failed.' );
	frontman_runtime_same( '', $welcome_render(), 'Reactivation must not reset a dismissal.' );
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
	wp_set_current_user( $welcome_previous_user );
}
