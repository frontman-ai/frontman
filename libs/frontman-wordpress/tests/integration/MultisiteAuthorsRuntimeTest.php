<?php
set_error_handler( static function( int $severity, string $message, string $file, int $line ): bool {
	if ( error_reporting() & $severity ) { throw new ErrorException( $message, 0, $severity, $file, $line ); }
	return false;
} );
$_SERVER['HTTP_HOST'] = 'frontman-multisite.example.test';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
require '/tmp/frontman-multisite/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$result = activate_plugin( 'frontman-agentic-ai-editor/frontman.php', '', true );
if ( is_wp_error( $result ) ) { throw new RuntimeException( $result->get_error_message() ); }
frontman_init();
function multi_assert( bool $ok, string $message ): void { if ( ! $ok ) { throw new RuntimeException( $message ); } }
multi_assert( is_multisite() && 1 === get_current_blog_id(), 'Multisite fixture not active' );
$actor = wp_insert_user( [ 'user_login' => 'multi-actor', 'user_pass' => wp_generate_password(), 'role' => 'administrator' ] );
$member = wp_insert_user( [ 'user_login' => 'multi-member', 'user_pass' => wp_generate_password(), 'display_name' => 'Multisite Candidate', 'role' => 'subscriber' ] );
$other = wp_insert_user( [ 'user_login' => 'multi-other', 'user_pass' => wp_generate_password(), 'display_name' => 'Multisite Candidate', 'role' => 'subscriber' ] );
$site = wpmu_create_blog( 'frontman-multisite.example.test', '/other/', 'Other', $actor );
multi_assert( is_int( $site ), 'Other-site fixture failed' );
add_user_to_blog( $site, $other, 'subscriber' );
remove_user_from_blog( $other, 1 );
wp_set_current_user( $actor );
multi_assert( ! is_super_admin( $actor ) && is_user_member_of_blog( $member, 1 ) && ! is_user_member_of_blog( $other, 1 ) && is_user_member_of_blog( $other, $site ), 'Membership fixture ineffective' );
$registry = Frontman_Tools::instance();
$call = static function( string $name, array $input, bool $error = false ) use ( $registry ): array {
	try { $result = $registry->call( $name, $registry->sanitize_input( $name, $input ) ); }
	catch ( Frontman_Tool_Error $e ) { $result = Frontman_Tools::error_result( $e->getMessage() ); }
	multi_assert( $error === $result['isError'], 'Multisite tool outcome mismatch: ' . $name );
	return $error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$base = [ 'title' => 'Multisite post', 'content' => 'Original', 'author' => $member ];
$post = $call( 'wp_create_post', $base );
$id = $post['id'];
multi_assert( $member === $post['after']['author'], 'Member assignment failed' );
$receipt = $call( 'wp_update_post', [ 'id' => $id, 'author' => $actor ] );
multi_assert( $member === $receipt['before']['author'] && $actor === $receipt['after']['author'], 'Multisite update snapshots failed' );
$call( 'wp_update_post', [ 'id' => $id, 'author' => $member ] );
$before = get_post( $id, ARRAY_A );
$count = array_sum( (array) wp_count_posts() );
$call( 'wp_create_post', array_merge( $base, [ 'author' => $other, 'status' => 'publish' ] ), true );
$call( 'wp_update_post', [ 'id' => $id, 'author' => $other, 'title' => 'Rejected', 'content' => 'Rejected', 'status' => 'publish' ], true );
clean_post_cache( $id );
multi_assert( $before === get_post( $id, ARRAY_A ) && $count === array_sum( (array) wp_count_posts() ), 'Nonmember rejection partially wrote state' );
$lookup = $call( 'wp_find_users', [ 'search' => 'Multisite Candidate', 'match_by' => 'display_name' ] );
multi_assert( [ $member ] === array_column( $lookup['users'], 'id' ) && 1 === $lookup['total'], 'Current-site lookup disclosed another-site account' );
multi_assert( [ 'id', 'login', 'display_name' ] === array_keys( $lookup['users'][0] ), 'Multisite privacy allowlist failed' );
multi_assert( $member === $call( 'wp_read_post', [ 'id' => $id ] )['author'] && 1 === get_current_blog_id(), 'Readback or blog scope changed' );
echo 'OK (Multisite authors, WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n";
