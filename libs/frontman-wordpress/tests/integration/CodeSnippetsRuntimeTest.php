<?php
/** Integration coverage for read-only Code Snippets tools with the real plugin. */
require_once ABSPATH . 'wp-admin/includes/user.php';
global $wpdb;

$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$tools = Frontman_Tools::instance();
frontman_runtime_same( '4.0.0', get_plugin_data( WP_PLUGIN_DIR . '/code-snippets/code-snippets.php', false, false )['Version'], 'Test the verified Code Snippets release.' );
frontman_runtime_same( 'read', $tools->get( 'wp_search_code_snippets' )->access, 'Search must be read-only.' );
frontman_runtime_same( 'read', $tools->get( 'wp_read_code_snippet' )->access, 'Detail must be read-only.' );
frontman_runtime_assert( null === $tools->get( 'wp_update_code_snippet' ), 'Do not expose a writer.' );

$call = static function ( string $name, array $input, bool $error = false ) use ( $tools ): array {
	$response = frontman_runtime_call( $tools, $name, $input );
	frontman_runtime_same( $error, $response['isError'], 'Unexpected Code Snippets tool result: ' . $response['content'][0]['text'] );
	return $error ? $response : json_decode( $response['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};

$ids = [];
$editor = 0;
try {
	$code = "add_shortcode('innerchange_contact_form_8e526ba5', function () { return 'form'; });\n// Do not execute on read.";
	$snippet = \Code_Snippets\save_snippet( new \Code_Snippets\Model\Snippet( [
		'name' => 'Contact shortcode',
		'code' => $code,
		'scope' => 'front-end',
		'active' => false,
	] ) );
	frontman_runtime_assert( $snippet && $snippet->id > 0, 'Create an inactive real-plugin snippet.' );
	$ids[] = $snippet->id;

	$result = $call( 'wp_search_code_snippets', [ 'search' => 'innerchange_contact_form_8e526ba5' ] );
	frontman_runtime_same( 1, count( $result['snippets'] ), 'Search stored code, not only titles.' );
	frontman_runtime_same( $snippet->id, $result['snippets'][0]['id'], 'Search returns the real snippet ID.' );
	frontman_runtime_same( false, $result['snippets'][0]['active'], 'Inactive status must be preserved.' );
	frontman_runtime_assert( false === strpos( wp_json_encode( $result ), 'add_shortcode' ), 'Search must not return source code.' );
	frontman_runtime_same( [], $call( 'wp_search_code_snippets', [ 'search' => '%_no_match' ] )['snippets'], 'Treat SQL wildcard characters literally.' );
	frontman_runtime_same( [], $call( 'wp_search_code_snippets', [ 'search' => str_repeat( 'λ', 150 ) ] )['snippets'], 'The search limit counts Unicode characters, not bytes.' );

	$detail = $call( 'wp_read_code_snippet', [ 'id' => $snippet->id ] );
	frontman_runtime_same( $code, $detail['code'], 'Return exact stored code without executing it.' );
	frontman_runtime_same( 'front-end', $detail['scope'], 'Return the execution scope.' );
	frontman_runtime_same( false, $detail['active'], 'Return stored activation state.' );
	frontman_runtime_same( 'unavailable', $detail['error_status'], 'A missing stored error is not proof of successful execution.' );
	frontman_runtime_same( null, $detail['code_error'], 'Do not fabricate error details.' );
	frontman_runtime_same( false, \Code_Snippets\get_snippet( $snippet->id )->active, 'Reads must not activate snippets.' );

	$active = \Code_Snippets\save_snippet( new \Code_Snippets\Model\Snippet( [
		'name' => 'Active shortcode',
		'code' => "add_shortcode('frontman_runtime_fixture', function () { return 'ok'; });",
		'scope' => 'front-end',
		'active' => false,
	] ) );
	frontman_runtime_assert( $active && $active->id > 0, 'Create a second fixture.' );
	$ids[] = $active->id;
	frontman_runtime_assert( \Code_Snippets\activate_snippet( $active->id ) instanceof \Code_Snippets\Model\Snippet, 'Activate the safe fixture through the real plugin.' );
	frontman_runtime_same( true, $call( 'wp_read_code_snippet', [ 'id' => $active->id ] )['active'], 'Report active snippets.' );
	frontman_runtime_assert( \Code_Snippets\trash_snippet( $active->id ), 'Trash the fixture through the real plugin.' );
	frontman_runtime_same( true, $call( 'wp_read_code_snippet', [ 'id' => $active->id ] )['trashed'], 'Do not mistake trashed for inactive.' );
	frontman_runtime_same( true, $call( 'wp_search_code_snippets', [ 'search' => 'Active shortcode' ] )['snippets'][0]['trashed'], 'Search must distinguish trashed snippets.' );

	for ( $i = 0; $i < 21; ++$i ) {
		$match = \Code_Snippets\save_snippet( new \Code_Snippets\Model\Snippet( [
			'name' => 'frontman-limit-fixture-' . $i,
			'code' => '// inert search fixture',
			'active' => false,
		] ) );
		frontman_runtime_assert( $match && $match->id > 0, 'Create bounded-search fixture.' );
		$ids[] = $match->id;
	}
	$page = $call( 'wp_search_code_snippets', [ 'search' => 'frontman-limit-fixture-' ] );
	frontman_runtime_same( 20, count( $page['snippets'] ), 'Search must limit its returned matches.' );
	frontman_runtime_same( true, $page['has_more'], 'Search must disclose truncated matches.' );

	$call( 'wp_read_code_snippet', [ 'id' => $snippet->id + 1000000 ], true );
	$call( 'wp_search_code_snippets', [ 'search' => '' ], true );
	$call( 'wp_read_code_snippet', [ 'id' => 0 ], true );
	$call( 'wp_read_code_snippet', [ 'id' => $snippet->id, 'network' => true ], true );
	$call( 'wp_search_code_snippets', [ 'search' => 'Contact', 'network' => true ], true );

	$storage = \Code_Snippets\code_snippets()->db;
	$table = $storage->table;
	try {
		$storage->table = $table . '_does_not_exist';
		$prior_errors = $wpdb->suppress_errors( true );
		$call( 'wp_search_code_snippets', [ 'search' => 'Contact' ], true );
		$call( 'wp_read_code_snippet', [ 'id' => $snippet->id ], true );
	} finally {
		$storage->table = $table;
		$wpdb->suppress_errors( $prior_errors );
	}

	$editor = wp_insert_user( [ 'user_login' => 'snippet-reader-denied', 'user_pass' => wp_generate_password(), 'role' => 'editor' ] );
	frontman_runtime_assert( ! is_wp_error( $editor ), 'Create an editor fixture.' );
	wp_set_current_user( $editor );
	$call( 'wp_search_code_snippets', [ 'search' => 'Contact' ], true );
	$call( 'wp_read_code_snippet', [ 'id' => $snippet->id ], true );
	wp_set_current_user( $admin->ID );

	$oversized = \Code_Snippets\save_snippet( new \Code_Snippets\Model\Snippet( [
		'name' => 'Oversized source',
		'code' => str_repeat( 'x', 131073 ),
		'active' => false,
	] ) );
	frontman_runtime_assert( $oversized && $oversized->id > 0, 'Create oversized fixture.' );
	$ids[] = $oversized->id;
	\Code_Snippets\get_snippets();
	$queries = [];
	$record_query = static function ( $query ) use ( &$queries ) {
		$queries[] = $query;
		return $query;
	};
	add_filter( 'query', $record_query );
	try {
		$call( 'wp_read_code_snippet', [ 'id' => $oversized->id ], true );
		frontman_runtime_assert( strlen( $call( 'wp_read_code_snippet', [ 'id' => $snippet->id ] )['code'] ) === strlen( $code ), 'An oversized neighbor must not affect targeted reads.' );
	} finally {
		remove_filter( 'query', $record_query );
	}
	$read_queries = array_values( array_filter( $queries, static fn( $query ) => false !== strpos( $query, 'OCTET_LENGTH(code)' ) ) );
	frontman_runtime_same( 2, count( $read_queries ), 'Both reads must use a bounded code projection, even with a warm plugin collection cache.' );
	foreach ( $read_queries as $query ) {
		frontman_runtime_assert( false !== strpos( $query, 'CASE WHEN OCTET_LENGTH(code)' ) && false === strpos( $query, 'SELECT *' ), 'Never load full plugin rows for snippet detail.' );
	}
} finally {
	wp_set_current_user( $admin->ID );
	if ( $editor ) {
		wp_delete_user( $editor );
	}
	foreach ( $ids as $id ) {
		\Code_Snippets\delete_snippet( $id );
	}
}
