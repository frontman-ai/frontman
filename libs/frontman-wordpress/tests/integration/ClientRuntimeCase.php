<?php

$path = '/frontman-runtime/client.json';
$client = json_decode( file_get_contents( $path ), true, 512, JSON_THROW_ON_ERROR );
foreach ( [ 'origin', 'api' ] as $key ) {
	frontman_runtime_assert( 1 === preg_match( '~^https://127\.0\.0\.1:\d+$~D', $client[ $key ] ), 'Client endpoints must be HTTPS loopback origins.' );
}
$client['password'] = wp_generate_password( 32, false );
frontman_runtime_assert( false !== file_put_contents( $path, wp_json_encode( $client ), LOCK_EX ), 'Could not save client fixture state.' );
wp_set_password( $client['password'], get_user_by( 'login', 'admin' )->ID );
update_option( 'siteurl', $client['origin'] );
update_option( 'home', $client['origin'] );
update_option( 'frontman_mcp_enabled', false );
$code = "<?php\n";
foreach ( [ 'FRONTMAN_HOST' => substr( $client['api'], 8 ), 'FRONTMAN_CLIENT_URL' => $client['origin'] . '/frontman-client/frontman.es.js', 'FRONTMAN_CLIENT_CSS' => $client['origin'] . '/frontman-client/frontman.css' ] as $name => $value ) {
	$code .= 'define(' . var_export( $name, true ) . ', ' . var_export( $value, true ) . ");\n";
}
frontman_runtime_assert( false !== file_put_contents( '/var/www/html/wp-content/mu-plugins/frontman-runtime-client.php', $code ), 'Could not write runtime client plugin.' );
