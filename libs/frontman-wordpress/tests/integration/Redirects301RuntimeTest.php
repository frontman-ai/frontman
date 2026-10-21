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
	$GLOBALS['redirectsplugins']->getAll();
	exit( 0 );
}

$adapter = new Frontman_Tool_301_Redirects();
redirects301_check( Frontman_Tool_301_Redirects::is_available(), 'Pinned plugin unavailable.' );
redirects301_check( 'read' === $tools->get( 'wp_301_redirects_list' )->access, 'List classification.' );
$initial = $adapter->list_redirects( [] );
redirects301_check( is_array( $initial['redirects'] ), 'List response.' );
redirects301_check( 0 === $initial['page'] && 100 === $initial['per_page'], 'Default pagination.' );
global $wpdb;
$inserted_ids = [];
try {
	for ( $i = 0; $i < 105; $i++ ) {
		redirects301_check( false !== $wpdb->insert( "{$wpdb->prefix}ts_redirects", [
			'title' => 'Pagination fixture', 'section' => '',
			'old_link' => "/frontman-pagination-$i", 'new_link' => '/frontman-target',
		] ), 'Fixture insertion failed.' );
		$inserted_ids[] = (int) $wpdb->insert_id;
	}
	$first = $adapter->list_redirects( [] );
	redirects301_check( 100 === count( $first['redirects'] ), 'First page bound.' );
	redirects301_check( $initial['total'] + 105 === $first['total'], 'Total count.' );
	$ids = [];
	for ( $page = 0; $page * 100 < $first['total']; $page++ ) {
		$result = $adapter->list_redirects( [ 'page' => $page ] );
		redirects301_check( $page === $result['page'] && 100 === $result['per_page'], 'Page metadata.' );
		redirects301_check( min( 100, $first['total'] - $page * 100 ) === count( $result['redirects'] ), 'Page size.' );
		$ids = array_merge( $ids, array_map( 'intval', array_column( $result['redirects'], 'id' ) ) );
	}
	redirects301_check( count( array_unique( $ids ) ) === $first['total'], 'Missing or duplicate rows.' );
	$sorted = $ids;
	sort( $sorted, SORT_NUMERIC );
	redirects301_check( $ids === $sorted, 'Stable ID ordering.' );
	redirects301_check( [] === $adapter->list_redirects( [ 'page' => $page ] )['redirects'], 'Empty page.' );
	foreach ( [ -1, '1', 1.5, true, PHP_INT_MAX ] as $invalid ) {
		try {
			$adapter->list_redirects( [ 'page' => $invalid ] );
			throw new RuntimeException( 'Invalid page accepted.' );
		} catch ( Frontman_Tool_Error $expected ) {
		}
	}
} finally {
	foreach ( $inserted_ids as $id ) {
		$wpdb->delete( "{$wpdb->prefix}ts_redirects", [ 'id' => $id ], [ '%d' ] );
	}
}
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
