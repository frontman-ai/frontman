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
	'target' => [ '/destination/', 'https://example.org', 'https://example.org?x=%61#section', 'https://example.org/destination?x=1' ],
] as $method => $valid ) {
	$validator = new ReflectionMethod( $adapter, $method );
	$validator->setAccessible( true );
	foreach ( $valid as $value ) {
		$expected = $method === 'target' && substr( $value, 0, 1 ) === '/' ? get_bloginfo( 'url' ) . $value : $value;
		redirects301_check( $expected === $validator->invoke( $adapter, $value ), 'Valid URL changed or rejected.' );
	}
}
foreach ( [
	'path' => [ null, '//evil.test', '/a/../b', '/a?x=1', '/a#b', '/%61', '/a*', "/a\n" ],
	'target' => [
		null, '//evil.test', 'javascript:alert(1)', 'ftp://example.org/', 'https://user:pass@example.org/',
		"https://example.org/\r\n", 'https://example.org/%0d', 'https://example.org/%61',
		'https://example.org/a:b', 'https://example.org/a/../b', 'https://example.org/a*',
		'http://example.org/a/./b', 'http://example.org/a//b',
	],
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
function redirects301_reject( callable $action ): void {
	try {
		$action();
		throw new RuntimeException( 'Invalid mutation accepted.' );
	} catch ( Frontman_Tool_Error $expected ) {
	}
}
$input = [ 'source' => '/frontman-301-old/', 'target' => '/frontman-301-new/', 'confirm' => true ];
foreach ( [ [ 'confirm' => 'true' ], [ 'confirm' => false ], [ 'source' => '/' ],
	[ 'target' => '/frontman-301-old/' ], [ 'target' => 'https://example.org/../unsafe' ] ] as $invalid ) {
	redirects301_reject( static function () use ( $adapter, $input, $invalid ) {
		$adapter->create_redirect( array_replace( $input, $invalid ) );
	} );
}
redirects301_check( $initial === $adapter->list_redirects( [] ), 'Rejected writes changed storage.' );
wp_set_current_user( 0 );
redirects301_reject( static function () use ( $adapter, $input ) { $adapter->create_redirect( $input ); } );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$created = $adapter->create_redirect( $input );
redirects301_check( null === $created['before'] && $created['after']['old_link'] === $input['source'], 'Create snapshot.' );
redirects301_reject( static function () use ( $adapter, $input ) { $adapter->create_redirect( $input ); } );
echo "OK (301 Redirects create)\n";
