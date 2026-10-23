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
if ( in_array( '--coexist', $argv, true ) ) {
	redirects301_check( Frontman_Tool_301_Redirects::is_available() && Frontman_Tool_Redirection::is_available(), 'Both plugins must be active.' );
	$registry = new Frontman_Tools();
	( new Frontman_Tool_Redirection() )->register( $registry );
	( new Frontman_Tool_301_Redirects() )->register( $registry );
	foreach ( [ 'wp_list_redirects', 'wp_create_redirect', 'wp_delete_redirect', 'wp_301_redirects_list', 'wp_301_redirects_create', 'wp_301_redirects_delete' ] as $name ) {
		redirects301_check( null !== $registry->get( $name ) && null !== $tools->get( $name ), 'Missing coexisting tool: ' . $name );
	}
	echo "OK (both real redirect adapters coexist)\n";
	exit( 0 );
}
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
	$input = [ 'source' => '/frontman-large-store/', 'target' => '/frontman-target/', 'confirm' => true ];
	redirects301_reject( static function () use ( $adapter, $input ) {
		$adapter->create_redirect( array_replace( $input, [ 'source' => '/frontman-pagination-104' ] ) );
	} );
	$before = $wpdb->get_results( "SELECT * FROM {$wpdb->prefix}ts_redirects ORDER BY id ASC", ARRAY_A );
	$site_filter = static function ( $url ) { return trailingslashit( $url ); };
	add_filter( 'bloginfo_url', $site_filter );
	try {
		foreach ( [ $input['source'], untrailingslashit( get_bloginfo( 'url' ) ) . $input['source'] ] as $self ) {
			redirects301_reject( static function () use ( $adapter, $input, $self ) {
				$adapter->create_redirect( array_replace( $input, [ 'target' => $self ] ) );
			} );
		}
		$created = $adapter->create_redirect( $input );
		$id = (int) $created['after']['id'];
		$inserted_ids[] = $id;
		redirects301_check( $created['after']['new_link'] === untrailingslashit( get_bloginfo( 'url' ) ) . $input['target'], 'Trailing-slash target.' );
		redirects301_check( $before === $wpdb->get_results( "SELECT * FROM {$wpdb->prefix}ts_redirects WHERE id != $id ORDER BY id ASC", ARRAY_A ), 'Large-store preservation.' );
		redirects301_reject( static function () use ( $adapter, $input ) { $adapter->create_redirect( $input ); } );
		$deleted = $adapter->delete_redirect( [ 'id' => $id, 'expected_source' => $input['source'], 'confirm' => true ] );
		redirects301_check( $deleted['before'] === $created['after'] && null === $deleted['after'], 'Delete beyond first page.' );
		redirects301_check( $before === $wpdb->get_results( "SELECT * FROM {$wpdb->prefix}ts_redirects ORDER BY id ASC", ARRAY_A ), 'Large-store delete preservation.' );
		$adapter->delete_redirect( [ 'id' => $inserted_ids[0], 'expected_source' => '/frontman-pagination-0', 'confirm' => true ] );
		$expected = array_values( array_filter( $before, static function ( $row ) use ( $inserted_ids ) { return (int) $row['id'] !== $inserted_ids[0]; } ) );
		redirects301_check( $expected === $wpdb->get_results( "SELECT * FROM {$wpdb->prefix}ts_redirects ORDER BY id ASC", ARRAY_A ), 'First-page delete preservation.' );
	} finally {
		remove_filter( 'bloginfo_url', $site_filter );
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
$delete = [ 'id' => (int) $created['after']['id'], 'expected_source' => $input['source'], 'confirm' => true ];
foreach ( [ [ 'id' => '1' ], [ 'expected_source' => '/wrong/' ], [ 'confirm' => 1 ] ] as $invalid ) {
	redirects301_reject( static function () use ( $adapter, $delete, $invalid ) {
		$adapter->delete_redirect( array_replace( $delete, $invalid ) );
	} );
}
wp_set_current_user( 0 );
redirects301_reject( static function () use ( $adapter, $delete ) { $adapter->delete_redirect( $delete ); } );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$deleted = $adapter->delete_redirect( $delete );
redirects301_check( $deleted['before'] === $created['after'] && null === $deleted['after'], 'Delete snapshot.' );
redirects301_check( $initial === $adapter->list_redirects( [] ), 'Unrelated rules changed.' );
redirects301_reject( static function () use ( $adapter, $delete ) { $adapter->delete_redirect( $delete ); } );
echo "OK (301 Redirects mutations)\n";
