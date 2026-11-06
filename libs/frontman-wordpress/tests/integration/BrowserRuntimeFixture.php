<?php

require '/var/www/html/wp-load.php';

$state_file = '/tmp/frontman-browser-state.json';
$config_file = '/var/www/html/wp-content/mu-plugins/frontman-browser-runtime.php';

if ( 'setup' === $argv[1] ) {
	$origin = getenv( 'FRONTMAN_BROWSER_ORIGIN' );
	$host = getenv( 'FRONTMAN_BROWSER_SERVER_HOST' );
	if ( ! preg_match( '~^https://127\.0\.0\.1:\d+$~', $origin ) || ! preg_match( '~^127\.0\.0\.1:\d+$~', $host ) ) {
		throw new RuntimeException( 'Browser runtime requires loopback fixture endpoints.' );
	}
	file_put_contents( $state_file, wp_json_encode( [
		'siteurl' => get_option( 'siteurl' ),
		'home' => get_option( 'home' ),
		'mcp_enabled' => get_option( 'frontman_mcp_enabled' ),
	] ) );
	update_option( 'siteurl', $origin );
	update_option( 'home', $origin );
	update_option( 'frontman_mcp_enabled', false );
	$password = bin2hex( random_bytes( 24 ) );
	wp_set_password( $password, get_user_by( 'login', 'admin' )->ID );
	file_put_contents( '/tmp/frontman-browser-password', $password );
	chmod( '/tmp/frontman-browser-password', 0600 );
	$config = "<?php\n"
		. 'define( "FRONTMAN_HOST", ' . var_export( $host, true ) . " );\n"
		. 'define( "FRONTMAN_CLIENT_URL", ' . var_export( $origin . '/frontman-browser/frontman.es.js', true ) . " );\n"
		. 'define( "FRONTMAN_CLIENT_CSS", ' . var_export( $origin . '/frontman-browser/frontman.css', true ) . " );\n";
	file_put_contents( $config_file, $config );
} elseif ( 'verify' === $argv[1] ) {
	$user = get_user_by( 'login', 'admin' );
	$passwords = WP_Application_Passwords::get_user_application_passwords( $user->ID );
	$frontman = array_values( array_filter( $passwords, static function ( $password ) {
		return 'Frontman MCP' === $password['name'];
	} ) );
	if ( 2 !== count( $frontman ) || ! get_option( 'frontman_mcp_enabled' ) ) {
		throw new RuntimeException( 'Browser flow must create one saved and one failed-approval password.' );
	}
	if ( true !== WP_Application_Passwords::delete_application_password( $user->ID, $frontman[1]['uuid'] ) ) {
		throw new RuntimeException( 'Could not remove the failed-approval password.' );
	}
	$remaining = WP_Application_Passwords::get_user_application_passwords( $user->ID );
	if ( ! in_array( $frontman[0]['uuid'], array_column( $remaining, 'uuid' ), true ) ) {
		throw new RuntimeException( 'The saved connection password must remain.' );
	}
} elseif ( 'restore' === $argv[1] ) {
	$state = json_decode( file_get_contents( $state_file ), true, 512, JSON_THROW_ON_ERROR );
	update_option( 'siteurl', $state['siteurl'] );
	update_option( 'home', $state['home'] );
	update_option( 'frontman_mcp_enabled', $state['mcp_enabled'] );
	unlink( $config_file );
	unlink( $state_file );
	unlink( '/tmp/frontman-browser-password' );
} else {
	throw new RuntimeException( 'Unknown browser runtime operation.' );
}
