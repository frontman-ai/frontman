<?php

define( 'ABSPATH', __DIR__ );
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-posts.php';
require_once __DIR__ . '/../tools/class-tool-users.php';

function author_assert( bool $ok, string $message ): void {
	if ( ! $ok ) { throw new RuntimeException( $message ); }
}
function author_error( callable $call, string $message ): void {
	try { $call(); } catch ( Frontman_Tool_Error $e ) {
		author_assert( '' === $message || false !== strpos( $e->getMessage(), $message ), 'Unexpected error: ' . $e->getMessage() );
		return;
	}
	throw new RuntimeException( 'Expected error: ' . $message );
}
function sanitize_key( $v ) { return $v; }
function sanitize_text_field( $v ) { return $v; }
function wp_check_invalid_utf8( $v ) { return $v; }
function wp_kses_post( $v ) { return $v; }
function absint( $v ) { return abs( (int) $v ); }
function wp_json_encode( $v ) { return json_encode( $v ); }
function get_current_user_id() { return 1; }
function get_current_blog_id() { return 7; }
function current_user_can( $cap, ...$args ) { return ! in_array( $cap, $GLOBALS['denied'], true ); }
function get_post_type_object( $type ) { return (object) [ 'cap' => (object) [ 'create_posts' => 'create_items', 'publish_posts' => 'publish_items', 'edit_others_posts' => 'edit_others_items' ] ]; }
function post_type_supports( $type, $feature ) { return 'no_author' !== $type; }
function get_userdata( $id ) { return in_array( $id, [ 1, 2, 3 ], true ) ? (object) [ 'ID' => $id ] : false; }
function is_multisite() { return true; }
function is_user_member_of_blog( $id, $blog ) { author_assert( 7 === $blog, 'Wrong blog' ); return 3 !== $id; }
class WP_Post extends stdClass {}
function get_post( $id ) { return $GLOBALS['post']; }
function wp_insert_post( ...$args ) { throw new RuntimeException( 'Unexpected write' ); }
function wp_update_post( ...$args ) { throw new RuntimeException( 'Unexpected write' ); }
class WP_User_Query {
	public function __construct( $args ) { $GLOBALS['queries'][] = $args; }
	public function get_results() { return [ (object) [ 'ID' => '2', 'user_login' => 'second', 'display_name' => 'Same', 'user_email' => 'must-not-return' ], (object) [ 'ID' => '3', 'user_login' => 'third', 'display_name' => 'Same' ] ]; }
	public function get_total() { return 3; }
}
$GLOBALS['denied'] = [];
$GLOBALS['queries'] = [];
$post = new WP_Post();
$post->ID = 9; $post->post_type = 'item'; $post->post_status = 'draft'; $post->post_author = 2;
$GLOBALS['post'] = $post;
$tools = new Frontman_Tools();
$posts = new Frontman_Tool_Posts(); $posts->register( $tools );
$users = new Frontman_Tool_Users(); $users->register( $tools );
foreach ( [ '1', 1.0, true, false, null, 0, -1, [], (object) [] ] as $bad ) {
	foreach ( [ 'wp_create_post' => 'create_post', 'wp_update_post' => 'update_post' ] as $name => $method ) {
		$input = [ 'id' => 9, 'title' => 'Changed', 'content' => 'Changed', 'status' => 'publish', 'author' => $bad ];
		author_error( static fn() => $tools->sanitize_input( $name, $input ), 'positive integer' );
		author_error( static fn() => $posts->$method( $input ), 'positive integer' );
		author_assert( $tools->call( $name, $input )['isError'], 'Direct dispatch accepted invalid author' );
	}
}
author_assert( ! array_key_exists( 'author', $tools->sanitize_input( 'wp_create_post', [ 'title' => 'T', 'content' => 'C' ] ) ), 'Omitted author injected' );
foreach ( [ [ 99, 'not found' ], [ 3, 'current site' ] ] as [ $id, $error ] ) {
	author_error( static fn() => $posts->create_post( [ 'author' => $id ] ), $error );
	author_error( static fn() => $posts->update_post( [ 'id' => 9, 'author' => $id ] ), $error );
}
author_error( static fn() => $posts->create_post( [ 'post_type' => 'no_author', 'author' => 1 ] ), 'does not support' );
foreach ( [ [ 'create_items', 'create_post', [] ], [ 'edit_post', 'update_post', [ 'id' => 9 ] ], [ 'publish_items', 'create_post', [ 'status' => 'private' ] ], [ 'publish_items', 'update_post', [ 'id' => 9, 'status' => 'publish' ] ], [ 'edit_others_items', 'update_post', [ 'id' => 9, 'author' => 2 ] ], [ 'edit_others_items', 'create_post', [ 'author' => 2 ] ] ] as [ $cap, $method, $input ] ) {
	$GLOBALS['denied'] = [ $cap ];
	author_error( static fn() => $posts->$method( $input ), 'permission' );
}
$GLOBALS['denied'] = [];
$base = [ 'search' => 'Same', 'match_by' => 'display_name' ];
$invalid = [ [], [ 'search' => '' ], [ 'search' => '  ' ], [ 'search' => str_repeat( 'é', 101 ) ], [ 'search' => "\xC3\x28" ], [ 'match_by' => 'email' ], [ 'unexpected' => 1 ], [ 'page' => PHP_INT_MAX ] ];
foreach ( [ '*Same', 'Same*', '*', '**', ' *Same ', " Same*\t", "\u{2003}*\u{2003}" ] as $search ) { $invalid[] = [ 'search' => $search ]; }
foreach ( [ null, true, [], 1, 1.0 ] as $bad ) { $invalid[] = [ 'search' => $bad ]; $invalid[] = [ 'match_by' => $bad ]; }
foreach ( [ 'page', 'per_page' ] as $field ) {
	foreach ( [ null, '1', 1.0, true, [], 0, -1 ] as $bad ) { $invalid[] = [ $field => $bad ]; }
}
$invalid[] = [ 'per_page' => 21 ];
foreach ( $invalid as $i => $override ) {
	$input = 0 === $i ? [] : array_merge( $base, $override );
	foreach ( [ static fn() => $tools->sanitize_input( 'wp_find_users', $input ), static fn() => $users->find_users( $input ) ] as $call ) { author_error( $call, '' ); }
}
author_assert( [] === $GLOBALS['queries'], 'Invalid input queried users' );
foreach ( [ 'manage_options', 'list_users' ] as $cap ) {
	$GLOBALS['denied'] = [ $cap ]; author_error( static fn() => $users->find_users( $base ), 'requires' );
}
author_assert( [] === $GLOBALS['queries'], 'Denied lookup queried users' );
$GLOBALS['denied'] = [];
foreach ( [ '%', '_', 'in*terior', "O'Neil", '"quoted"', str_repeat( 'é', 100 ), '0' ] as $search ) {
	$input = $tools->sanitize_input( 'wp_find_users', [ 'search' => ' ' . $search . ' ', 'match_by' => 'login', 'page' => 2, 'per_page' => 2 ] );
	$result = $users->find_users( $input );
	$args = end( $GLOBALS['queries'] );
	author_assert( '*' . $search . '*' === $args['search'], 'Literal search altered' );
	author_assert( [ 'user_login' ] === $args['search_columns'] && 7 === $args['blog_id'] && 2 === $args['number'] && 2 === $args['paged'] && 'ID' === $args['orderby'] && 'ASC' === $args['order'] && true === $args['count_total'], 'Unbounded or incorrect query' );
	author_assert( [ 'ID', 'user_login', 'display_name' ] === $args['fields'], 'Private fields requested' );
	author_assert( [ 'users', 'page', 'per_page', 'total', 'total_pages' ] === array_keys( $result ) && 2 === $result['total_pages'], 'Pagination contract' );
	foreach ( $result['users'] as $user ) { author_assert( [ 'id', 'login', 'display_name' ] === array_keys( $user ) && is_int( $user['id'] ), 'Output allowlist' ); }
	author_assert( [ 2, 3 ] === array_column( $result['users'], 'id' ), 'Ambiguous candidates lost' );
}
$users->find_users( $base );
author_assert( [ 'display_name' ] === end( $GLOBALS['queries'] )['search_columns'], 'Display-name search column' );
author_assert( 'read' === $tools->get( 'wp_find_users' )->access, 'Lookup is not read-only' );
echo "OK (author raw validation, permission preflight, lookup bounds and allowlist)\n";
