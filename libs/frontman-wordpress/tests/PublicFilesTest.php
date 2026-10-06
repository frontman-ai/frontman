<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-public-files-' . getmypid() . '/' );
define( 'FS_CHMOD_FILE', 0644 );
if ( isset( $argv[1] ) ) { define( 'DISALLOW_FILE_EDIT', true ); }
mkdir( ABSPATH );
function __( string $message, string $domain = '' ): string { return $message; }
function wp_json_encode( $value, int $flags = 0 ) { return json_encode( $value, $flags ); }
function current_user_can( $cap ): bool { return ! in_array( $cap, $GLOBALS['denied'], true ); }
function wp_is_file_mod_allowed( $context ): bool { return $GLOBALS['allowed']; }
function is_multisite(): bool { return $GLOBALS['multisite']; }
function home_url( $path = '' ): string { return $GLOBALS['home'] . $path; }
function site_url( $path = '' ): string { return $GLOBALS['site'] . $path; }
function get_home_path(): string { return $GLOBALS['root']; }
function untrailingslashit( $value ): string { return rtrim( $value, '/\\' ); }
function wp_parse_url( $value ) { return parse_url( $value ); }
function wp_tempnam( $name, $directory ) { return $directory . basename( tempnam( $directory, $name ) ); }
function get_filesystem_method( ...$args ): string { return $GLOBALS['transport']; }
function WP_Filesystem( ...$args ): bool { return true; }
function get_option( $key, $default = false ) { return $GLOBALS['options'][ $key ] ?? $default; }
function update_option( $key, $value, $autoload = null ): bool {
	if ( 'backup_fail' === $GLOBALS['fault'] || ( $GLOBALS['recovery_fail'] ?? false ) ) { return false; }
	$GLOBALS['options'][ $key ] = $value;
	$GLOBALS['autoload'] = $autoload;
	return true;
}
function delete_option( $key ): bool {
	if ( $GLOBALS['recovery_fail'] ?? false ) { return false; }
	unset( $GLOBALS['options'][ $key ] );
	return true;
}
function wp_safe_remote_get( $url, $args ) {
	$GLOBALS['http_args'] = $args;
	if ( isset( $GLOBALS['post_fault'] ) && ! $GLOBALS['post_fault'] instanceof RuntimeException && 'Saved but unverified' === file_get_contents( ABSPATH . basename( $url ) ) ) {
		return $GLOBALS['post_fault'];
	}
	return $GLOBALS['remote'] ?? [ 'response' => [ 'code' => file_exists( ABSPATH . basename( $url ) ) ? 200 : 404 ], 'body' => file_exists( ABSPATH . basename( $url ) ) ? file_get_contents( ABSPATH . basename( $url ) ) : '' ];
}
class WP_Error { public function get_error_message(): string { return 'Public timeout'; } }
function is_wp_error( $value ): bool { return $value instanceof WP_Error; }
function wp_remote_retrieve_response_code( $value ) { return $value['response']['code']; }
function wp_remote_retrieve_body( $value ) { return $value['body']; }
class WP_Filesystem_Direct {
	public $method = 'direct';
	public function get_contents( $path ) {
		if ( ( $GLOBALS['post_fault'] ?? null ) instanceof RuntimeException && ABSPATH . 'llms.txt' === $path && 'Saved but unverified' === file_get_contents( $path ) ) { throw $GLOBALS['post_fault']; }
		return file_get_contents( $path );
	}
	public function put_contents( $path, $content, $mode = false ): bool {
		file_put_contents( $path, 'short_write' === $GLOBALS['fault'] ? substr( $content, 0, 1 ) : $content );
		if ( $GLOBALS['race'] ) { file_put_contents( ABSPATH . 'llms.txt', 'External writer' ); }
		return true;
	}
	public function is_writable( $path ): bool { return is_writable( $path ); }
	public function chmod( $path, $mode ): bool {
		if ( 0600 !== $mode ) {
			if ( $GLOBALS['fault'] === 'recovery_fail' ) { $GLOBALS['recovery_fail'] = true; }
			if ( $GLOBALS['fault'] === 'backup_race' ) { $GLOBALS['options']['frontman_public_file_previous_llms.txt'] = 'Independent backup'; }
			if ( $GLOBALS['fault'] === 'final_fail' ) { $GLOBALS['allowed'] = false; }
			if ( $GLOBALS['fault'] === 'late_race' ) { file_put_contents( ABSPATH . 'llms.txt', 'External writer' ); }
			if ( in_array( $GLOBALS['fault'], [ 'rename_fail', 'recovery_fail', 'backup_race' ], true ) ) { return unlink( $path ); }
		}
		return chmod( $path, $mode );
	}
	public function delete( $path ): bool { return unlink( $path ); }
}
require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-public-files.php';
$denied = [];
$allowed = true;
$multisite = false;
$home = $site = 'https://public.example.test';
$root = ABSPATH;
$transport = 'direct';
$options = [];
$race = $recovery_fail = false;
$fault = '';
$wp_filesystem = new WP_Filesystem_Direct();
$tools = new Frontman_Tools();
( new Frontman_Tool_Public_Files() )->register( $tools );
$assert = static function ( bool $condition, string $message ): void {
	if ( ! $condition ) { throw new RuntimeException( $message ); }
};
$call = static function ( string $name, array $input, bool $error = false, bool $invalid = false ) use ( $tools, $assert ): array {
	try {
		$input = $tools->sanitize_input( $name, $input );
		$assert( ! $invalid, 'Invalid raw input reached the handler.' );
		$result = $tools->call( $name, $input );
	} catch ( Frontman_Tool_Error $failure ) {
		$assert( $error, $failure->getMessage() );
		return [ 'message' => $failure->getMessage() ];
	}
	$assert( $error === $result['isError'], $name . ': ' . json_encode( $result ) );
	return $error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
$read = static fn( $name = 'llms.txt' ) => $call( 'wp_read_public_file', [ 'name' => $name ] );
$write = static fn( $revision, $content = 'replacement', $error = false ) => $call( 'wp_write_public_file', [ 'name' => 'llms.txt', 'content' => $content, 'expected_revision' => $revision, 'confirm' => true ], $error );
if ( isset( $argv[1] ) ) {
	$assert( ! $read()['writable'], 'DISALLOW_FILE_EDIT did not block writes.' );
	$write( $read()['revision'], 'denied by constant', true );
	rmdir( ABSPATH );
	exit( 0 );
}
try {
	$valid = [ 'name' => 'llms.txt', 'content' => "  # Café\r\n[Docs](https://example.test/?a=1&b=2)\t \\ \"quoted\"\r\n", 'expected_revision' => str_repeat( 'a', 64 ), 'confirm' => true ];
	foreach ( [ 'robots.txt', 'llms.txt', 'llms-full.txt' ] as $name ) {
		$state = $read( $name );
		$assert( ! $state['exists'], 'Allowlisted absent file was not readable.' );
		$call( 'wp_write_public_file', [ 'name' => $name, 'content' => '', 'expected_revision' => $state['revision'], 'confirm' => true ] );
		$assert( 0644 === ( fileperms( ABSPATH . $name ) & 0777 ) && ! $read( $name )['previous']['exists'], 'New-file mode or absent backup incorrect.' );
		unlink( ABSPATH . $name );
	}
	$assert( $valid === $tools->sanitize_input( 'wp_write_public_file', $valid ), 'Raw bytes changed in registry.' );
	foreach ( [ 'name' => [ '../robots.txt', '/llms.txt', 'LLMS.txt', 'https://public.example.test/llms.txt', null, 7 ], 'content' => [ null, false, [], "bad\xC3\x28", "bad\0", "bad\x01", str_repeat( 'x', 131073 ) ], 'confirm' => [ false, 'true', 1 ], 'expected_revision' => [ null, 7, '', str_repeat( 'A', 64 ) ] ] as $key => $values ) {
		foreach ( $values as $value ) {
			$call( 'wp_write_public_file', array_merge( $valid, [ $key => $value ] ), true, true );
			if ( 'name' === $key ) { $call( 'wp_read_public_file', [ 'name' => $value ], true, true ); }
		}
		$missing = $valid;
		unset( $missing[ $key ] );
		$call( 'wp_write_public_file', $missing, true, true );
	}
	$call( 'wp_write_public_file', $valid + [ 'root' => '/tmp' ], true, true );
	$call( 'wp_read_public_file', [ 'name' => 'llms.txt', 'extra' => true ], true, true );
	$absent = $read();
	file_put_contents( ABSPATH . 'llms.txt', '' );
	$empty = $read();
	$assert( $absent['revision'] !== $empty['revision'], 'Missing and empty revisions collided.' );
	$write( $absent['revision'], 'stale', true );
	chmod( ABSPATH . 'llms.txt', 0640 );
	$saved = $write( $empty['revision'], $valid['content'] );
	$assert( 0640 === ( fileperms( ABSPATH . 'llms.txt' ) & 0777 ), 'Existing mode was not preserved.' );
	$assert( $saved['saved'] && $saved['verified'] && $valid['content'] === file_get_contents( ABSPATH . 'llms.txt' ), 'Literal replacement failed.' );
	$assert( [ 'exists' => true, 'content' => '' ] === $read()['previous'] && false === $autoload, 'Previous snapshot/autoload incorrect.' );
	$write( $read()['revision'], $read()['previous']['content'] );
	$assert( '' === file_get_contents( ABSPATH . 'llms.txt' ), 'Same-path restoration failed.' );
	foreach ( [ 'denied' => [ 'edit_files' ], 'allowed' => false, 'transport' => 'ftpext', 'multisite' => true, 'home' => 'https://public.example.test/sub', 'site' => 'https://other.example.test', 'root' => dirname( ABSPATH ) ] as $key => $value ) {
		$old = $GLOBALS[ $key ];
		$GLOBALS[ $key ] = $value;
		$write( $empty['revision'], 'blocked', true );
		$GLOBALS[ $key ] = $old;
	}
	$denied = [ 'manage_options' ];
	$call( 'wp_read_public_file', [ 'name' => 'llms.txt' ], true );
	$denied = [];
	symlink( ABSPATH, ABSPATH . 'root-alias' );
	$root = ABSPATH . 'root-alias';
	$call( 'wp_read_public_file', [ 'name' => 'llms.txt' ], true );
	$root = ABSPATH;
	unlink( ABSPATH . 'root-alias' );
	$key = 'frontman_public_file_previous_llms.txt';
	foreach ( [ null, [ 'exists' => true, 'content' => 'A' ] ] as $previous ) {
		foreach ( [ 'backup_fail', 'short_write', 'rename_fail', 'final_fail', 'late_race', 'recovery_fail', 'backup_race' ] as $fault ) {
			$options = null === $previous ? [] : [ $key => $previous ];
			file_put_contents( ABSPATH . 'llms.txt', 'B' );
			$error = $write( $read()['revision'], 'Attempt C', true );
			$recovery_fail = false;
			$allowed = true;
			$expected = 'recovery_fail' === $fault ? [ 'exists' => true, 'content' => 'B' ] : ( 'backup_race' === $fault ? 'Independent backup' : $previous );
			$assert( $expected === get_option( $key, null ) && ( null !== $expected || ! array_key_exists( $key, $options ) ), 'Failure lost the prior backup or clobbered an independent change.' );
			$assert( 'late_race' === $fault ? 'External writer' === file_get_contents( ABSPATH . 'llms.txt' ) : 'B' === file_get_contents( ABSPATH . 'llms.txt' ), 'Failure destroyed target content.' );
			$assert( ! in_array( $fault, [ 'recovery_fail', 'backup_race' ], true ) || false !== strpos( json_encode( $error ), 'snapshot recovery failed' ), 'Recovery failure was not reported.' );
			$assert( [ 'llms.txt' ] === array_values( array_diff( scandir( ABSPATH ), [ '.', '..' ] ) ), 'Failure leaked a staging file.' );
		}
	}
	$fault = '';
	$write( $read()['revision'], 'C' );
	$assert( [ 'exists' => true, 'content' => 'B' ] === get_option( $key ), 'Success did not rotate the snapshot to B.' );
	$race = true;
	$write( $read()['revision'], 'must not overwrite race', true );
	$race = false;
	$assert( 'External writer' === file_get_contents( ABSPATH . 'llms.txt' ), 'Conflict detection overwrote another actor.' );
	foreach ( [ 'directory', 'symlink', 'dangling', 'hardlink', 'oversize' ] as $kind ) {
		unlink( ABSPATH . 'llms.txt' );
		if ( 'directory' === $kind ) { mkdir( ABSPATH . 'llms.txt' ); }
		elseif ( 'hardlink' === $kind ) { file_put_contents( ABSPATH . 'outside', '' ); link( ABSPATH . 'outside', ABSPATH . 'llms.txt' ); }
		elseif ( 'oversize' === $kind ) { file_put_contents( ABSPATH . 'llms.txt', str_repeat( 'x', 131073 ) ); }
		else { symlink( 'symlink' === $kind ? __FILE__ : ABSPATH . 'missing', ABSPATH . 'llms.txt' ); }
		$call( 'wp_read_public_file', [ 'name' => 'llms.txt' ], true );
		if ( 'directory' === $kind ) { rmdir( ABSPATH . 'llms.txt' ); } else { unlink( ABSPATH . 'llms.txt' ); }
		file_put_contents( ABSPATH . 'llms.txt', '' );
	}
	$remote = [ 'response' => [ 'code' => 200 ], 'body' => 'upstream' ];
	$write( $read()['revision'], 'host-controlled', true );
	unlink( ABSPATH . 'llms.txt' );
	$generated = $read();
	$remote['body'] = 'changed generated output';
	$write( $generated['revision'], 'stale takeover', true );
	$remote = new WP_Error();
	$write( $read()['revision'], 'must not create', true );
	$remote = [ 'response' => [ 'code' => 200 ], 'body' => str_repeat( 'x', 131073 ) ];
	$call( 'wp_read_public_file', [ 'name' => 'llms.txt' ], true );
	$write( $valid['expected_revision'], 'oversized public', true );
	unset( $remote );
	foreach ( [ new RuntimeException( 'Local readback failed' ), new WP_Error(), [ 'response' => [ 'code' => 200 ], 'body' => 'Upstream mismatch' ], [ 'response' => [ 'code' => 503 ], 'body' => '' ], [ 'response' => [ 'code' => 200 ], 'body' => str_repeat( 'x', 131073 ) ] ] as $post_fault ) {
		file_put_contents( ABSPATH . 'llms.txt', 'Before save' );
		$unverified = $write( $read()['revision'], 'Saved but unverified' );
		$expected_after = $post_fault instanceof RuntimeException ? null : [ 'exists' => true, 'content' => 'Saved but unverified' ];
		$assert( $unverified['saved'] && ! $unverified['verified'] && null !== $unverified['reason'] && $expected_after === $unverified['after'], 'Post-save readback failure concealed persistence.' );
	}
	unset( $post_fault );
	$options += array_fill_keys( [ 'frontman_settings', 'frontman_php_diagnostics', 'frontman_public_file_previous_robots.txt', 'frontman_public_file_previous_llms-full.txt', 'unrelated', 'frontman_public_file_previous_other.txt' ], 'keep' );
	define( 'WP_UNINSTALL_PLUGIN', true );
	require __DIR__ . '/../uninstall.php';
	$assert( [ 'unrelated' => 'keep', 'frontman_public_file_previous_other.txt' => 'keep' ] === $options && 'Saved but unverified' === file_get_contents( ABSPATH . 'llms.txt' ), 'Uninstall left snapshots or removed unrelated data/files.' );
	$assert( 0 === $http_args['redirection'] && 131073 === $http_args['limit_response_size'], 'Public fetch was not bounded/no-redirect.' );
	passthru( escapeshellarg( PHP_BINARY ) . ' -d auto_prepend_file=' . escapeshellarg( __DIR__ . '/ErrorHandler.php' ) . ' ' . escapeshellarg( __FILE__ ) . ' --file-edit-denied', $status );
	$assert( 0 === $status, 'File-edit prohibition child failed.' );
	fwrite( STDOUT, "OK (public file validation, revisions, policy and filesystem boundaries)\n" );
} finally {
	foreach ( glob( ABSPATH . '*' ) as $path ) { unlink( $path ); }
	rmdir( ABSPATH );
}
