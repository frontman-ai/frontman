<?php

if ( ! defined( 'ABSPATH' ) ) {
	throw new RuntimeException( 'WordPress must be loaded before the MCP runtime setup.' );
}

$user = get_user_by( 'login', 'admin' );
if ( ! $user instanceof WP_User ) {
	throw new RuntimeException( 'Runtime administrator is missing.' );
}

wp_set_current_user( $user->ID );
$cookie = wp_generate_auth_cookie( $user->ID, time() + 3600, 'logged_in' );
$cookie_name = LOGGED_IN_COOKIE;
$_COOKIE[ $cookie_name ] = $cookie;
$nonce = wp_create_nonce( Frontman_Auth::nonce_action() );

fwrite( STDOUT, wp_json_encode( [ 'nonce' => $nonce, 'cookieName' => $cookie_name, 'cookie' => $cookie ] ) );
