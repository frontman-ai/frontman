<?php
/** Integration contract against the official Redirection 5.10.0 package. */
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

function redirection_check( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$tools = Frontman_Tools::instance();

if ( in_array( '--setup', $argv, true ) ) {
	redirection_check( ! Frontman_Tool_Redirection::is_available(), 'Inactive Redirection must be unavailable.' );
	redirection_check( null === $tools->get( 'wp_create_redirect' ), 'Inactive plugin tools must not be registered.' );
	$result = activate_plugin( 'redirection/redirection.php' );
	redirection_check( ! is_wp_error( $result ), 'Redirection activation failed.' );
	redirection_check( REDIRECTION_VERSION === '5.10.0', 'Unexpected Redirection version.' );
	$result = ( new \Redirection\Database\Schema\Latest() )->install();
	redirection_check( true === $result, 'Redirection database installation failed.' );
	( new \Redirection\Database\Status() )->finish();
	file_put_contents( WPMU_PLUGIN_DIR . '/frontman-redirection-runtime.php', <<<'PHP'
<?php
add_action( 'init', static function () {
	register_post_type( 'neuros_team_member', [ 'public' => true, 'has_archive' => 'team', 'rewrite' => [ 'slug' => 'team' ] ] );
} );
PHP
	);
	update_option( 'permalink_structure', '/%postname%/' );
	file_put_contents( ABSPATH . '.htaccess', "RewriteEngine On\nRewriteBase /\nRewriteRule ^index\\.php$ - [L]\nRewriteCond %{REQUEST_FILENAME} !-f\nRewriteCond %{REQUEST_FILENAME} !-d\nRewriteRule . /index.php [L]\n" );
	exit( 0 );
}

set_error_handler( static function ( int $severity, string $message, string $file, int $line ): bool {
	if ( error_reporting() & $severity ) {
		throw new ErrorException( $message, 0, $severity, $file, $line );
	}
	return false;
} );

function redirection_call( string $name, array $input, bool $expect_error = false ): array {
	global $tools;
	$result = $tools->call( $name, $tools->sanitize_input( $name, $input ) );
	redirection_check( $result['isError'] === $expect_error, $name . ': ' . $result['content'][0]['text'] );
	return $expect_error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
}

function redirection_http( string $path, int $status, ?string $location = null ): void {
	$response = wp_remote_get( 'http://localhost' . $path, [ 'redirection' => 0, 'headers' => [ 'Host' => 'frontman-runtime.example.test' ] ] );
	redirection_check( ! is_wp_error( $response ), 'HTTP request failed: ' . $path );
	redirection_check( $status === wp_remote_retrieve_response_code( $response ), $path . ': expected HTTP ' . $status . ', got ' . wp_remote_retrieve_response_code( $response ) );
	if ( null !== $location ) {
		redirection_check( $location === wp_remote_retrieve_header( $response, 'location' ), 'Unexpected redirect target.' );
	}
}

redirection_check( null !== $tools->get( 'wp_create_redirect' ), 'Active Redirection tools must register on a fresh request.' );
redirection_check( $tools->get( 'wp_list_redirects' )->access === 'read', 'List access classification.' );
redirection_check( $tools->get( 'wp_create_redirect' )->access === 'read-write', 'Create access classification.' );
redirection_check( $tools->get( 'wp_delete_redirect' )->access === 'read-write', 'Delete access classification.' );
$info = redirection_call( 'wp_get_site_info', [] );
$types = array_column( $info['post_types'], null, 'name' );
redirection_check( $types['neuros_team_member']['has_archive'] === 'team', 'Preserve the archive slug, not just a boolean.' );
redirection_check( $types['neuros_team_member']['archive_url'] === home_url( '/team/' ), 'Resolved archive URL.' );
redirection_check( $types['neuros_team_member']['rewrite']['slug'] === 'team', 'Rewrite metadata.' );
redirection_check( true === $types['neuros_team_member']['publicly_queryable'], 'Queryable metadata.' );
redirection_check( false === $types['page']['has_archive'] && null === $types['page']['archive_url'], 'No archive uses null URL.' );

$member = wp_insert_post( [ 'post_type' => 'neuros_team_member', 'post_title' => 'Alice', 'post_name' => 'alice', 'post_status' => 'publish' ], true );
redirection_check( ! is_wp_error( $member ), 'Team member fixture.' );
flush_rewrite_rules( false );
redirection_http( '/team/', 200 );
redirection_http( '/team/alice/', 200 );
$listing = redirection_call( 'wp_list_redirects', [] );
$group = $listing['groups']['items'][0]['id'];
$input = [ 'source' => '/team/', 'code' => 410, 'group_id' => $group, 'confirm' => true ];
foreach ( [
	[ 'confirm' => false ], [ 'confirm' => 'true' ], [ 'source' => '/' ], [ 'source' => '//evil.example' ],
	[ 'source' => '/team/?x=1' ], [ 'source' => '/team/#hash' ], [ 'source' => '/te%61m/' ],
	[ 'source' => '/team/../' ], [ 'source' => '/team/*' ], [ 'source' => "/team/\r\n" ],
	[ 'code' => 500 ], [ 'code' => '410' ], [ 'group_id' => 999999 ], [ 'group_id' => '1' ],
	[ 'target' => '/replacement/' ], [ 'code' => 301 ],
	[ 'code' => 301, 'target' => '/team' ], [ 'code' => 302, 'target' => '/TEAM/' ],
	[ 'code' => 301, 'target' => 'https://evil.example/' ], [ 'code' => 301, 'target' => '//evil.example/' ],
	[ 'code' => 301, 'target' => '/replacement/../team/' ],
] as $invalid ) {
	redirection_call( 'wp_create_redirect', array_replace( $input, $invalid ), true );
}
redirection_call( 'wp_list_redirects', [ 'page' => -1 ], true );
redirection_check( redirection_call( 'wp_list_redirects', [] )['redirects']['total'] === $listing['redirects']['total'], 'Invalid input must not write rules.' );

wp_set_current_user( 0 );
redirection_call( 'wp_list_redirects', [], true );
redirection_call( 'wp_create_redirect', $input, true );
wp_set_current_user( $admin->ID );
$deny = static function ( $capability, $permission ) {
	return in_array( $permission, [ 'redirection_cap_redirect_add', 'redirection_cap_redirect_delete' ], true ) ? 'do_not_allow' : $capability;
};
add_filter( 'redirection_capability_check', $deny, 10, 2 );
redirection_call( 'wp_create_redirect', $input, true );
remove_filter( 'redirection_capability_check', $deny );

$created = redirection_call( 'wp_create_redirect', $input );
$id = $created['after']['id'];
redirection_check( null === $created['before'], 'Create snapshot.' );
add_filter( 'redirection_capability_check', $deny, 10, 2 );
redirection_call( 'wp_delete_redirect', [ 'id' => $id, 'expected_source' => '/team/', 'confirm' => true ], true );
remove_filter( 'redirection_capability_check', $deny );
redirection_call( 'wp_create_redirect', $input, true );
redirection_call( 'wp_create_redirect', array_replace( $input, [ 'source' => '/team' ] ), true );
redirection_http( '/team/', 410 );
redirection_http( '/team', 410 );
redirection_http( '/team/?utm_source=test', 410 );
redirection_http( '/team/alice/', 200 );
redirection_http( '/team/feed/', 200 );
redirection_http( '/team/page/2/', 404 );
redirection_check( get_post_type_object( 'neuros_team_member' )->has_archive === 'team', 'Registration must not be mutated.' );
redirection_call( 'wp_delete_redirect', [ 'id' => $id, 'expected_source' => '/wrong/', 'confirm' => true ], true );
redirection_call( 'wp_delete_redirect', [ 'id' => $id, 'expected_source' => '/team/', 'confirm' => false ], true );
$deleted = redirection_call( 'wp_delete_redirect', [ 'id' => $id, 'expected_source' => '/team/', 'confirm' => true ] );
redirection_check( $deleted['before']['id'] === $id && null === $deleted['after'], 'Delete snapshot.' );
redirection_http( '/team/', 200 );
redirection_call( 'wp_delete_redirect', [ 'id' => $id, 'expected_source' => '/team/', 'confirm' => true ], true );

foreach ( [ 301, 302, 404 ] as $code ) {
	$args = array_replace( $input, [ 'code' => $code ] );
	if ( $code < 400 ) {
		$args['target'] = '/replacement/';
	}
	$rule = redirection_call( 'wp_create_redirect', $args )['after'];
	redirection_http( '/team/?tracking=1', $code, $code < 400 ? '/replacement/' : null );
	redirection_call( 'wp_delete_redirect', [ 'id' => $rule['id'], 'expected_source' => '/team/', 'confirm' => true ] );
}

$seed = [ 'group_id' => $group, 'match_type' => 'url', 'action_type' => 'error', 'action_code' => 410 ];
$existing = Red_Item::create( $seed + [ 'url' => '/team', 'enabled' => false ] );
redirection_check( ! is_wp_error( $existing ), 'Disabled duplicate fixture.' );
for ( $i = 0; $i < 101; $i++ ) {
	redirection_check( ! is_wp_error( Red_Item::create( $seed + [ 'url' => '/team-child-' . $i ] ) ), 'Pagination fixture.' );
}
redirection_call( 'wp_create_redirect', $input, true );
$page = redirection_call( 'wp_list_redirects', [ 'source' => '/team/', 'page' => 1 ] );
redirection_check( count( $page['redirects']['items'] ) === 2, 'Second rule page.' );

restore_error_handler();
fwrite( STDOUT, 'OK (Redirection ' . REDIRECTION_VERSION . ', WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n" );
