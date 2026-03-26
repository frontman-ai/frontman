<?php

$test_root = sys_get_temp_dir() . '/frontman-wordpress-core-tools-' . uniqid();
mkdir( $test_root, 0777, true );

define( 'ABSPATH', $test_root . '/' );
define( 'DAY_IN_SECONDS', 86400 );

$GLOBALS['frontman_test_transients'] = [];
$GLOBALS['frontman_test_extra_paths'] = [];

if ( ! function_exists( 'untrailingslashit' ) ) {
	function untrailingslashit( string $value ): string {
		return rtrim( $value, '/\\' );
	}
}

if ( ! function_exists( 'trailingslashit' ) ) {
	function trailingslashit( string $value ): string {
		return untrailingslashit( $value ) . '/';
	}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( '__' ) ) {
	function __( string $value ): string {
		return $value;
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'absint' ) ) {
	function absint( $value ): int {
		return abs( (int) $value );
	}
}

if ( ! function_exists( 'wp_mkdir_p' ) ) {
	function wp_mkdir_p( string $target ): bool {
		return is_dir( $target ) || mkdir( $target, 0777, true );
	}
}

if ( ! function_exists( 'get_current_user_id' ) ) {
	function get_current_user_id(): int {
		return 1;
	}
}

if ( ! function_exists( 'set_transient' ) ) {
	function set_transient( string $key, $value ): bool {
		$GLOBALS['frontman_test_transients'][ $key ] = $value;
		return true;
	}
}

if ( ! function_exists( 'get_transient' ) ) {
	function get_transient( string $key ) {
		return $GLOBALS['frontman_test_transients'][ $key ] ?? false;
	}
}

if ( ! function_exists( 'delete_transient' ) ) {
	function delete_transient( string $key ): bool {
		unset( $GLOBALS['frontman_test_transients'][ $key ] );
		return true;
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-core-path.php';
require_once __DIR__ . '/../includes/class-frontman-core-file-tracker.php';
require_once __DIR__ . '/../includes/class-frontman-core-tools.php';

class Frontman_Core_Tools_Test_Runner {
	private Frontman_Tools $tools;
	private int $assertions = 0;

	public function __construct() {
		$this->tools = new Frontman_Tools();
		( new Frontman_Core_Tools() )->register( $this->tools );
	}

	public function run(): void {
		$this->seed_files();
		$this->test_clear_all_file_tracker_records();
		$this->test_core_path_semantics();
		$this->test_list_files_and_search_files();
		$this->test_read_write_and_edit_guards();
		$this->test_grep_and_list_tree();
		$this->test_load_agent_instructions();
		$this->test_file_exists();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function seed_files(): void {
		$this->write_fixture( 'workspace/app/index.php', "<?php\necho 'hello';\nneedle here\n" );
		$this->write_fixture( 'workspace/app/nested/theme.css', ".hero { color: red; }\n" );
		$this->write_fixture( 'workspace/app/nested/edit-me.txt', "alpha\nbeta\ngamma\n" );
		$this->write_fixture( 'workspace/app/nested/repeat.txt', "needle\nneedle\nneedle\n" );
		$this->write_fixture( 'workspace/app/Agents.md', "# App Instructions\n" );
		$this->write_fixture( 'workspace/app/.claude/CLAUDE.md', "# Should be skipped\n" );
		$this->write_fixture( 'workspace/CLAUDE.md', "# Root Claude\n" );
		$this->write_fixture( 'workspace/app/node_modules/ignore.js', "ignored\n" );
		$this->write_fixture(
			'workspace/package.json',
			json_encode(
				[
					'name'       => 'workspace-root',
					'workspaces' => [ 'packages/*' ],
				],
				JSON_PRETTY_PRINT
			)
		);
		$this->write_fixture(
			'workspace/packages/site/package.json',
			json_encode( [ 'name' => 'site-workspace' ], JSON_PRETTY_PRINT )
		);
		$this->write_fixture( 'workspace/packages/site/site.js', "console.log('workspace');\n" );
	}

	private function test_clear_all_file_tracker_records(): void {
		$GLOBALS['frontman_test_transients'] = [
			'frontman_file_tracker_1' => [ 'foo' => 'bar' ],
			'frontman_file_tracker_2' => [ 'baz' => 'qux' ],
		];
		$GLOBALS['wpdb'] = new class() {
			public string $options = 'wp_options';

			public function esc_like( string $value ): string {
				return $value;
			}

			public function prepare( string $query, string ...$patterns ): array {
				return [ 'query' => $query, 'patterns' => $patterns ];
			}

			public function query( array $prepared ): void {
				foreach ( array_keys( $GLOBALS['frontman_test_transients'] ) as $key ) {
					$transient_option = '_transient_' . $key;
					$timeout_option   = '_transient_timeout_' . $key;
					foreach ( $prepared['patterns'] as $pattern ) {
						$prefix = rtrim( $pattern, '%' );
						if ( 0 === strpos( $transient_option, $prefix ) || 0 === strpos( $timeout_option, $prefix ) ) {
							unset( $GLOBALS['frontman_test_transients'][ $key ] );
							break;
						}
					}
				}
			}
		};

		Frontman_Core_File_Tracker::clear_all();

		$this->assert_same( [], $GLOBALS['frontman_test_transients'], 'clear_all removes file tracker records for all users' );
		unset( $GLOBALS['wpdb'] );
	}

	private function test_core_path_semantics(): void {
		$resolved = Frontman_Core_Path::resolve( 'workspace/app/index.php' );
		$this->assert_same( 'workspace/app/index.php', $resolved['relativePath'], 'resolve returns relative path context' );
		$this->assert_same( Frontman_Core_Path::source_root() . '/workspace/app/index.php', Frontman_Core_Path::resolve( Frontman_Core_Path::source_root() . '/workspace/app/index.php' )['resolvedPath'], 'resolve accepts absolute in-root paths' );
		$this->assert_same( Frontman_Core_Path::source_root(), Frontman_Core_Path::resolve_search_path( null ), 'resolve_search_path defaults to source root' );
		$this->assert_same( Frontman_Core_Path::source_root() . '/workspace/app', Frontman_Core_Path::resolve_search_dir( 'workspace/app/index.php' ), 'resolve_search_dir uses parent directory for files' );

		try {
			Frontman_Core_Path::resolve( '../outside.txt' );
			throw new RuntimeException( 'Expected path traversal to fail' );
		} catch ( Frontman_Tool_Error $e ) {
			$this->assert_true( false !== strpos( $e->getMessage(), 'Path escapes source root' ), 'resolve rejects traversal outside source root' );
		}

		if ( function_exists( 'symlink' ) ) {
			$outside = sys_get_temp_dir() . '/frontman-outside-' . uniqid();
			mkdir( $outside, 0777, true );
			$GLOBALS['frontman_test_extra_paths'][] = $outside;
			symlink( $outside, ABSPATH . 'workspace/app/link-out' );
			try {
				Frontman_Core_Path::resolve( 'workspace/app/link-out/secret.txt' );
				throw new RuntimeException( 'Expected symlink escape to fail' );
			} catch ( Frontman_Tool_Error $e ) {
				$this->assert_true( false !== strpos( $e->getMessage(), 'Path escapes source root' ), 'resolve rejects symlink escapes outside source root' );
			}
		}

		try {
			Frontman_Core_Path::resolve( '/tmp/outside-frontman-test.txt' );
			throw new RuntimeException( 'Expected absolute outside path to fail' );
		} catch ( Frontman_Tool_Error $e ) {
			$this->assert_true( false !== strpos( $e->getMessage(), 'Absolute path must be under source root' ), 'resolve rejects absolute paths outside the source root' );
		}
	}

	private function test_list_files_and_search_files(): void {
		$list = $this->call_success( 'list_files', [ 'path' => 'workspace/app' ] );
		$paths = array_column( $list, 'path' );
		$this->assert_true( in_array( 'workspace/app/index.php', $paths, true ), 'list_files includes immediate files' );
		$this->assert_true( in_array( 'workspace/app/nested', $paths, true ), 'list_files includes immediate directories' );

		$search = $this->call_success( 'search_files', [ 'path' => 'workspace', 'pattern' => '*.css' ] );
		$this->assert_same( 1, $search['totalResults'], 'search_files finds css file without git repo' );
		$this->assert_same( 'workspace/app/nested/theme.css', $search['files'][0], 'search_files returns relative path' );

		$from_file = $this->call_success( 'list_files', [ 'path' => 'workspace/app/index.php' ] );
		$this->assert_true( in_array( 'workspace/app/nested', array_column( $from_file, 'path' ), true ), 'list_files with file path falls back to parent directory' );

		$limited = $this->call_success( 'search_files', [ 'path' => 'workspace', 'pattern' => '*', 'max_results' => 1 ] );
		$this->assert_true( true === $limited['truncated'], 'search_files truncates when max_results is exceeded' );
	}

	private function test_read_write_and_edit_guards(): void {
		Frontman_Core_File_Tracker::clear();
		$partial = $this->call_success( 'read_file', [ 'path' => 'workspace/app/nested/edit-me.txt', 'offset' => 1, 'limit' => 1 ] );
		$this->assert_same( 'beta', $partial['content'], 'read_file respects offset and limit' );
		$this->assert_true( true === $partial['hasMore'], 'read_file reports remaining content' );

		Frontman_Core_File_Tracker::clear();
		$error = $this->call_error( 'edit_file', [
			'path'    => 'workspace/app/nested/edit-me.txt',
			'oldText' => 'beta',
			'newText' => 'BETA',
		] );
		$this->assert_true( false !== strpos( $error, 'File must be read before editing' ), 'edit_file requires prior read' );

		$this->call_success( 'read_file', [ 'path' => 'workspace/app/nested/edit-me.txt' ] );
		$edit = $this->call_success( 'edit_file', [
			'path'    => 'workspace/app/nested/edit-me.txt',
			'oldText' => 'beta',
			'newText' => 'BETA',
		] );
		$this->assert_true( false !== strpos( $edit['message'], 'Edit applied successfully.' ), 'edit_file succeeds after read_file' );
		$this->assert_same( "alpha\nBETA\ngamma\n", file_get_contents( ABSPATH . 'workspace/app/nested/edit-me.txt' ), 'edit_file updates file content' );

		Frontman_Core_File_Tracker::clear();
		$error = $this->call_error( 'write_file', [
			'path'    => 'workspace/app/index.php',
			'content' => "<?php\necho 'updated';\n",
		] );
		$this->assert_true( false !== strpos( $error, 'File must be read before editing' ), 'write_file requires read before overwriting existing file' );

		$this->call_success( 'read_file', [ 'path' => 'workspace/app/index.php' ] );
		$this->call_success( 'write_file', [
			'path'    => 'workspace/app/index.php',
			'content' => "<?php\necho 'updated';\n",
		] );
		$this->assert_same( "<?php\necho 'updated';\n", file_get_contents( ABSPATH . 'workspace/app/index.php' ), 'write_file overwrites after read' );

		$this->call_success( 'write_file', [
			'path'    => 'workspace/app/generated/new.txt',
			'content' => "fresh\n",
		] );
		$this->assert_same( "fresh\n", file_get_contents( ABSPATH . 'workspace/app/generated/new.txt' ), 'write_file creates parent directories for new files' );

		Frontman_Core_File_Tracker::clear();
		$this->call_success( 'read_file', [ 'path' => 'workspace/app/nested/edit-me.txt', 'offset' => 0, 'limit' => 1 ] );
		$warning = $this->call_success( 'edit_file', [
			'path'    => 'workspace/app/nested/edit-me.txt',
			'oldText' => 'gamma',
			'newText' => 'GAMMA',
		] );
		$this->assert_true( false !== strpos( $warning['message'], 'Warning:' ), 'edit_file includes coverage warning outside read range' );

		Frontman_Core_File_Tracker::clear();
		$this->call_success( 'read_file', [ 'path' => 'workspace/app/nested/repeat.txt' ] );
		$ambiguous = $this->call_error( 'edit_file', [
			'path'    => 'workspace/app/nested/repeat.txt',
			'oldText' => 'needle',
			'newText' => 'PIN',
		] );
		$this->assert_true( false !== strpos( $ambiguous, 'multiple matches' ), 'edit_file rejects ambiguous duplicate matches without replaceAll' );

		Frontman_Core_File_Tracker::clear();
		$this->call_success( 'read_file', [ 'path' => 'workspace/app/nested/repeat.txt' ] );
		$this->call_success( 'edit_file', [
			'path'       => 'workspace/app/nested/repeat.txt',
			'oldText'    => 'needle',
			'newText'    => 'PIN',
			'replaceAll' => true,
		] );
		$this->assert_same( "PIN\nPIN\nPIN\n", file_get_contents( ABSPATH . 'workspace/app/nested/repeat.txt' ), 'edit_file replaceAll updates all occurrences' );
	}

	private function test_grep_and_list_tree(): void {
		$grep = $this->call_success( 'grep', [
			'path'         => 'workspace',
			'pattern'      => 'workspace',
			'literal'      => true,
			'max_results'  => 20,
		] );
		$this->assert_true( $grep['totalMatches'] >= 1, 'grep finds literal matches' );
		$this->assert_true( in_array( 'workspace/packages/site/site.js', array_column( $grep['files'], 'path' ), true ), 'grep reports relative file paths' );

		$single = $this->call_success( 'grep', [
			'path'             => 'workspace/packages/site/site.js',
			'pattern'          => 'WORKSPACE',
			'literal'          => true,
			'case_insensitive' => true,
		] );
		$this->assert_same( 'workspace/packages/site/site.js', $single['files'][0]['path'], 'grep supports file-path searches' );

		$no_matches = $this->call_success( 'grep', [
			'path'    => 'workspace',
			'pattern' => 'definitely-not-present',
			'literal' => true,
		] );
		$this->assert_same( 0, $no_matches['totalMatches'], 'grep returns empty success when there are no matches' );

		$tree = $this->call_success( 'list_tree', [ 'path' => 'workspace', 'depth' => 3 ] );
		$this->assert_true( false !== strpos( $tree['tree'], 'packages/' ), 'list_tree includes nested directories' );
		$this->assert_same( 'npm-workspaces', $tree['monorepoType'], 'list_tree detects npm workspaces' );
		$this->assert_same( 'site-workspace', $tree['workspaces'][0]['name'], 'list_tree reads workspace package names' );
		$this->assert_true( false === strpos( $tree['tree'], 'node_modules/' ), 'list_tree excludes noise directories' );
	}

	private function test_load_agent_instructions(): void {
		$instructions = $this->call_success( 'load_agent_instructions', [ 'startPath' => 'workspace/app/nested' ] );
		$this->assert_same( '# App Instructions' . "\n", $instructions[0]['content'], 'load_agent_instructions prefers Agents.md at a directory level' );
		$this->assert_true( false !== strpos( $instructions[1]['fullPath'], 'workspace/CLAUDE.md' ), 'load_agent_instructions continues walking upward' );
		$this->assert_true( 2 === count( $instructions ), 'load_agent_instructions stops at the WordPress source root' );
	}

	private function test_file_exists(): void {
		$this->assert_true( true === $this->call_success( 'file_exists', [ 'path' => 'workspace/app/index.php' ] ), 'file_exists returns true for files' );
		$this->assert_true( false === $this->call_success( 'file_exists', [ 'path' => 'workspace/app/missing.php' ] ), 'file_exists returns false for missing files' );
	}

	private function call_success( string $name, array $input ) {
		$result = $this->tools->call( $name, $input );
		if ( ! empty( $result['isError'] ) ) {
			throw new RuntimeException( 'Expected success for ' . $name . ': ' . $result['content'][0]['text'] );
		}

		$text = $result['content'][0]['text'];
		$data = json_decode( $text, true );
		return ( null === $data && 'null' !== $text ) ? $text : $data;
	}

	private function call_error( string $name, array $input ): string {
		$result = $this->tools->call( $name, $input );
		if ( empty( $result['isError'] ) ) {
			throw new RuntimeException( 'Expected error for ' . $name );
		}

		return $result['content'][0]['text'];
	}

	private function write_fixture( string $relative_path, string $content ): void {
		$full_path = ABSPATH . $relative_path;
		$dir = dirname( $full_path );
		if ( ! is_dir( $dir ) ) {
			mkdir( $dir, 0777, true );
		}
		file_put_contents( $full_path, $content );
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . "\nExpected: " . var_export( $expected, true ) . "\nActual: " . var_export( $actual, true ) );
		}
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}
}

register_shutdown_function(
	static function() use ( $test_root ): void {
		$iterator = new RecursiveIteratorIterator(
			new RecursiveDirectoryIterator( $test_root, FilesystemIterator::SKIP_DOTS ),
			RecursiveIteratorIterator::CHILD_FIRST
		);

		foreach ( $iterator as $item ) {
			if ( is_link( $item->getPathname() ) || $item->isFile() ) {
				unlink( $item->getPathname() );
			} else {
				rmdir( $item->getPathname() );
			}
		}

		@rmdir( $test_root );

		foreach ( $GLOBALS['frontman_test_extra_paths'] as $extra_path ) {
			@rmdir( $extra_path );
		}
	}
);

( new Frontman_Core_Tools_Test_Runner() )->run();
