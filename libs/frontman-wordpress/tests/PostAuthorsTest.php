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
function current_user_can( $cap, ...$args ) { throw new RuntimeException( 'Invalid input reached permission checks' ); }
function get_post_type_object( $type ) { throw new RuntimeException( 'Invalid author reached post-type lookup' ); }
class WP_Post extends stdClass {}
function get_post( $id ) { $post = new WP_Post(); $post->post_type = 'post'; return $post; }
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
foreach ( [ '%', '_', 'in*terior', "O'Neil", '"quoted"', str_repeat( 'é', 100 ), '0' ] as $search ) {
	$input = $tools->sanitize_input( 'wp_find_users', [ 'search' => ' ' . $search . ' ', 'match_by' => 'login' ] );
	author_assert( $search === $input['search'], 'Literal search altered' );
}
author_assert( 'read' === $tools->get( 'wp_find_users' )->access, 'Lookup is not read-only' );
echo "OK (author and lookup raw validation)\n";
