<?php

require_once __DIR__ . '/ErrorHandler.php';
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$yoast = getenv( 'EXPECTED_YOAST_VERSION' );
if ( false !== $yoast && '' !== $yoast ) {
	if ( $yoast !== get_plugin_data( WP_PLUGIN_DIR . '/wordpress-seo/wp-seo.php', false, false )['Version'] ) {
		throw new RuntimeException( 'Installed Yoast version does not match the verified package.' );
	}
	$result = activate_plugin( 'wordpress-seo/wp-seo.php' );
	if ( is_wp_error( $result ) ) {
		throw new RuntimeException( $result->get_error_message() );
	}
}
foreach ( [ 'megamenu/megamenu.php', 'frontman-agentic-ai-editor/frontman.php', 'elementor/elementor.php' ] as $plugin ) {
	$result = activate_plugin( $plugin );
	if ( is_wp_error( $result ) ) {
		throw new RuntimeException( $result->get_error_message() );
	}
}

require_once __DIR__ . '/RuntimeTestSupport.php';
$admin = get_user_by( 'login', 'admin' );
$token = WP_Session_Tokens::get_instance( $admin->ID )->create( time() + HOUR_IN_SECONDS );
$cookie = wp_generate_auth_cookie( $admin->ID, time() + HOUR_IN_SECONDS, 'auth', $token ) . '; ' . LOGGED_IN_COOKIE . '=' . wp_generate_auth_cookie( $admin->ID, time() + HOUR_IN_SECONDS, 'logged_in', $token );
try {
	for ( $attempt = 0; $attempt < 5; ++$attempt ) {
		$response = frontman_runtime_http( 'GET', '/wp-admin/profile.php', $cookie, null, null, '', '', AUTH_COOKIE );
		if ( 200 === $response['status'] ) {
			break;
		}
		frontman_runtime_same( 302, $response['status'], 'Activation admin request: ' . implode( ' | ', $response['headers'] ) );
		$locations = preg_grep( '/^Location: /i', $response['headers'] );
		$location = substr( reset( $locations ), 10 );
		frontman_runtime_assert( in_array( $location, [ admin_url( 'admin.php?page=wpseo_installation_successful_free' ), admin_url( 'admin.php?page=elementor-app#onboarding' ) ], true ), 'Unexpected activation redirect: ' . $location );
	}
	frontman_runtime_same( 200, $response['status'], 'Activation redirects must finish: ' . implode( ' | ', $response['headers'] ) );
} finally {
	WP_Session_Tokens::get_instance( $admin->ID )->destroy( $token );
}

restore_error_handler();
