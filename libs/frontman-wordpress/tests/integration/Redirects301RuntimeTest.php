<?php
/** Contract against the pinned official WebFactory 301 Redirects 1.05 package. */
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

function redirects301_check( bool $ok, string $message ): void {
	if ( ! $ok ) {
		throw new RuntimeException( $message );
	}
}

wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$tools = Frontman_Tools::instance();
if ( in_array( '--setup', $argv, true ) ) {
	redirects301_check( ! Frontman_Tool_301_Redirects::is_available(), 'Inactive plugin available.' );
	redirects301_check( null === $tools->get( 'wp_301_redirects_list' ), 'Inactive tool registered.' );
	redirects301_check( ! is_wp_error( activate_plugin( '301-redirects/301-redirects.php' ) ), 'Activation failed.' );
	$GLOBALS['redirectsplugins']->getAll(); // Plugin-owned initialization, not adapter behavior.
	exit( 0 );
}

$adapter = new Frontman_Tool_301_Redirects();
redirects301_check( Frontman_Tool_301_Redirects::is_available(), 'Pinned plugin unavailable.' );
redirects301_check( 'read' === $tools->get( 'wp_301_redirects_list' )->access, 'List classification.' );
$initial = $adapter->list_redirects( [] );
redirects301_check( is_array( $initial['redirects'] ), 'List response.' );
wp_set_current_user( 0 );
try {
	$adapter->list_redirects( [] );
	throw new RuntimeException( 'Anonymous read accepted.' );
} catch ( Frontman_Tool_Error $expected ) {
}
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
foreach ( [
	'path' => [ '/', '/literal/', '/case-sensitive' ],
	'target' => [ '/destination/', 'https://example.org/destination?x=1' ],
] as $method => $valid ) {
	$validator = new ReflectionMethod( $adapter, $method );
	$validator->setAccessible( true );
	foreach ( $valid as $value ) {
		redirects301_check( is_string( $validator->invoke( $adapter, $value ) ), 'Valid URL rejected.' );
	}
}
foreach ( [
	'path' => [ null, '//evil.test', '/a/../b', '/a?x=1', '/a#b', '/%61', '/a*', "/a\n" ],
	'target' => [ null, '//evil.test', 'javascript:alert(1)', 'ftp://example.org/', 'https://user:pass@example.org/', "https://example.org/\r\n", 'https://example.org/%0d' ],
] as $method => $invalid ) {
	$validator = new ReflectionMethod( $adapter, $method );
	$validator->setAccessible( true );
	foreach ( $invalid as $value ) {
		try {
			$validator->invoke( $adapter, $value );
			throw new RuntimeException( 'Unsafe URL accepted.' );
		} catch ( Frontman_Tool_Error $expected ) {
		}
	}
}
echo "OK (301 Redirects read)\n";
