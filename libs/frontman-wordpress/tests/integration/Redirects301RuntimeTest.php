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
echo "OK (301 Redirects read)\n";
