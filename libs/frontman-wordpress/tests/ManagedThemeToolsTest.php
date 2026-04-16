<?php

$test_root = sys_get_temp_dir() . '/frontman-wordpress-managed-theme-' . uniqid();
mkdir( $test_root, 0777, true );

register_shutdown_function(
	static function() use ( $test_root ) {
		if ( ! is_dir( $test_root ) ) {
			return;
		}

		$iterator = new RecursiveIteratorIterator(
			new RecursiveDirectoryIterator( $test_root, RecursiveDirectoryIterator::SKIP_DOTS ),
			RecursiveIteratorIterator::CHILD_FIRST
		);

		foreach ( $iterator as $entry ) {
			if ( $entry->isDir() ) {
				rmdir( $entry->getPathname() );
			} else {
				unlink( $entry->getPathname() );
			}
		}

		rmdir( $test_root );
	}
);

define( 'ABSPATH', $test_root . '/' );

$GLOBALS['frontman_test_options'] = [];
$GLOBALS['frontman_test_active_theme'] = [
	'name'           => 'Parent Theme',
	'version'        => '1.2.3',
	'template'       => 'parent-theme',
	'stylesheet'     => 'parent-theme',
	'is_block_theme' => true,
];

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

if ( ! function_exists( 'wp_tempnam' ) ) {
	function wp_tempnam( string $filename = '', string $dir = '' ) {
		$directory = '' !== $dir ? $dir : sys_get_temp_dir();
		return tempnam( $directory, 'frontman-' );
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

if ( ! function_exists( 'wp_mkdir_p' ) ) {
	function wp_mkdir_p( string $target ): bool {
		return is_dir( $target ) || mkdir( $target, 0777, true );
	}
}

if ( ! class_exists( 'WP_Filesystem_Direct' ) ) {
	class WP_Filesystem_Direct {
		public function __construct( $arg ) {
		}

		public function exists( string $path ): bool {
			return file_exists( $path );
		}

		public function is_dir( string $path ): bool {
			return is_dir( $path );
		}

		public function is_file( string $path ): bool {
			return is_file( $path );
		}

		public function put_contents( string $path, string $content ): bool {
			return false !== file_put_contents( $path, $content );
		}

		public function move( string $source, string $destination, bool $overwrite = false ): bool {
			if ( $overwrite && file_exists( $destination ) ) {
				unlink( $destination );
			}

			return rename( $source, $destination );
		}

		public function delete( string $path, bool $recursive = false, $type = false ): bool {
			if ( ! file_exists( $path ) ) {
				return true;
			}

			if ( is_file( $path ) || is_link( $path ) ) {
				return unlink( $path );
			}

			if ( ! $recursive ) {
				return rmdir( $path );
			}

			$iterator = new RecursiveIteratorIterator(
				new RecursiveDirectoryIterator( $path, RecursiveDirectoryIterator::SKIP_DOTS ),
				RecursiveIteratorIterator::CHILD_FIRST
			);

			foreach ( $iterator as $entry ) {
				if ( $entry->isDir() ) {
					rmdir( $entry->getPathname() );
				} else {
					unlink( $entry->getPathname() );
				}
			}

			return rmdir( $path );
		}
	}
}

if ( ! function_exists( 'get_option' ) ) {
	function get_option( string $name, $default = false ) {
		return $GLOBALS['frontman_test_options'][ $name ] ?? $default;
	}
}

if ( ! function_exists( 'update_option' ) ) {
	function update_option( string $name, $value ): bool {
		$GLOBALS['frontman_test_options'][ $name ] = $value;
		return true;
	}
}

if ( ! function_exists( 'get_theme_root' ) ) {
	function get_theme_root(): string {
		return ABSPATH . 'wp-content/themes';
	}
}

if ( ! function_exists( 'get_stylesheet' ) ) {
	function get_stylesheet(): string {
		return $GLOBALS['frontman_test_active_theme']['stylesheet'];
	}
}

if ( ! function_exists( 'get_template' ) ) {
	function get_template(): string {
		return $GLOBALS['frontman_test_active_theme']['template'];
	}
}

if ( ! function_exists( 'switch_theme' ) ) {
	function switch_theme( string $stylesheet ): void {
		$stylesheet = sanitize_key( $stylesheet );
		if ( $stylesheet === ( $GLOBALS['frontman_test_options']['frontman_managed_theme']['stylesheet'] ?? '' ) ) {
			$config = $GLOBALS['frontman_test_options']['frontman_managed_theme'];
			$GLOBALS['frontman_test_active_theme'] = [
				'name'           => $config['name'],
				'version'        => '0.1.0',
				'template'       => $config['parent_stylesheet'],
				'stylesheet'     => $config['stylesheet'],
				'is_block_theme' => true,
			];
			return;
		}

		$GLOBALS['frontman_test_active_theme']['stylesheet'] = $stylesheet;
		$GLOBALS['frontman_test_active_theme']['template'] = $stylesheet;
	}
}

if ( ! function_exists( 'wp_get_theme' ) ) {
	function wp_get_theme( ?string $stylesheet = null ) {
		$state = $GLOBALS['frontman_test_active_theme'];
		if ( null !== $stylesheet && '' !== $stylesheet ) {
			$stylesheet = sanitize_key( $stylesheet );
			if ( $stylesheet === ( $GLOBALS['frontman_test_options']['frontman_managed_theme']['stylesheet'] ?? '' ) ) {
				$config = $GLOBALS['frontman_test_options']['frontman_managed_theme'];
				$state = [
					'name'           => $config['name'],
					'version'        => '0.1.0',
					'template'       => $config['parent_stylesheet'],
					'stylesheet'     => $config['stylesheet'],
					'is_block_theme' => true,
				];
			} elseif ( $stylesheet === 'parent-theme' ) {
				$state = [
					'name'           => 'Parent Theme',
					'version'        => '1.2.3',
					'template'       => 'parent-theme',
					'stylesheet'     => 'parent-theme',
					'is_block_theme' => true,
				];
			}
		}

		return new class( $state ) {
			private array $state;

			public function __construct( array $state ) {
				$this->state = $state;
			}

			public function get( string $field ) {
				switch ( $field ) {
					case 'Name':
						return $this->state['name'];
					case 'Version':
						return $this->state['version'];
					default:
						return '';
				}
			}

			public function is_block_theme(): bool {
				return (bool) $this->state['is_block_theme'];
			}

			public function get_template(): string {
				return $this->state['template'];
			}

			public function get_stylesheet(): string {
				return $this->state['stylesheet'];
			}
		};
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-core-path.php';
require_once __DIR__ . '/../includes/class-frontman-managed-theme.php';
require_once __DIR__ . '/../tools/class-tool-managed-theme.php';

class Frontman_Managed_Theme_Tools_Test_Runner {
	private Frontman_Tool_Managed_Theme $tool;
	private int $assertions = 0;

	public function __construct() {
		$this->tool = new Frontman_Tool_Managed_Theme();
	}

	public function run(): void {
		$this->seed_parent_theme();
		$this->test_status_reports_missing_directory_as_orphaned();
		$this->test_status_reports_corrupt_manifest_as_orphaned();
		$this->test_status_reports_missing_bootstrap_file_as_orphaned();
		$this->test_status_reports_orphaned_managed_theme();
		$this->test_status_reports_token_mismatch_as_orphaned();
		$this->test_create_managed_theme_rejects_non_block_theme();
		$this->test_create_managed_theme_rejects_existing_child_theme();
		$this->test_create_managed_theme_bootstraps_filesystem_api();
		$this->test_create_managed_theme();
		$this->test_activate_managed_theme_requires_confirmation();
		$this->test_write_managed_theme_file_tracks_owned_files();
		$this->test_fork_parent_theme_file();
		$this->test_reject_unmanaged_or_unsupported_writes();
		$this->test_read_and_fork_enforce_size_limits();
		$this->test_symlink_escape_is_rejected();
		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function seed_parent_theme(): void {
		$this->write_fixture( 'wp-content/themes/parent-theme/style.css', "/*\nTheme Name: Parent Theme\n*/\n" );
		$this->write_fixture( 'wp-content/themes/parent-theme/theme.json', "{\"version\": 3}\n" );
		$this->write_fixture( 'wp-content/themes/parent-theme/templates/home.html', "<!-- wp:paragraph --><p>Parent Home</p><!-- /wp:paragraph -->\n" );
		$this->write_fixture( 'wp-content/themes/parent-theme/assets/css/base.css', ".hero { color: red; }\n" );
		$this->write_fixture( 'wp-content/themes/parent-theme/functions.php', "<?php\n// parent bootstrap\n" );
	}

	private function test_create_managed_theme(): void {
		$status = $this->tool->get_status( [] );
		$this->assert_true( false === $status['exists'], 'Managed theme status starts empty' );
		$this->assert_same( null, $status['orphaned_managed_theme'], 'Managed theme status starts without an orphaned theme hint' );

		$created = $this->tool->create_theme( [] );
		$this->assert_true( true === $created['created'], 'wp_create_managed_theme creates the child theme' );
		$this->assert_same( 'frontman-managed-parent-theme', $created['theme']['stylesheet'], 'Managed theme stylesheet is derived from the parent theme' );
		$this->assert_true( file_exists( get_theme_root() . '/frontman-managed-parent-theme/style.css' ), 'Managed theme style.css is created' );
		$this->assert_true( file_exists( get_theme_root() . '/frontman-managed-parent-theme/frontman-managed.json' ), 'Managed theme manifest is created' );

		$list = $this->tool->list_files( [] );
		$this->assert_true( in_array( 'style.css', array_column( $list['files'], 'path' ), true ), 'Managed theme lists the required bootstrap stylesheet' );

		$second = $this->tool->create_theme( [] );
		$this->assert_true( false === $second['created'], 'wp_create_managed_theme is idempotent when the managed theme already exists' );
	}

	private function test_status_reports_orphaned_managed_theme(): void {
		$orphan_root = get_theme_root() . '/frontman-managed-parent-theme';
		$this->write_fixture( 'wp-content/themes/frontman-managed-parent-theme/style.css', "/*\nTheme Name: Orphaned\nTemplate: parent-theme\n*/\n" );
		$this->write_fixture(
			'wp-content/themes/frontman-managed-parent-theme/frontman-managed.json',
			json_encode(
				[
					'version' => 1,
					'name' => 'Orphaned',
					'stylesheet' => 'frontman-managed-parent-theme',
					'parent_stylesheet' => 'parent-theme',
					'ownership_token' => 'orphaned-token',
					'created_at' => '2026-04-14T00:00:00Z',
					'files' => [
						'style.css' => [ 'origin' => 'system', 'writable' => true, 'created_at' => '2026-04-14T00:00:00Z' ],
					],
				],
				JSON_PRETTY_PRINT
			) . "\n"
		);

		try {
			$status = $this->tool->get_status( [] );
			$this->assert_true( false === $status['exists'], 'An orphaned managed theme is not treated as owned' );
			$this->assert_same( 'frontman-managed-parent-theme', $status['orphaned_managed_theme']['stylesheet'], 'Status reports the orphaned managed theme stylesheet' );
			$this->assert_error_contains(
				function() {
					$this->tool->create_theme( [] );
				},
				'not registered to this site',
				'Create rejects orphaned managed-theme directories'
			);
		} finally {
			unlink( $orphan_root . '/frontman-managed.json' );
			unlink( $orphan_root . '/style.css' );
			rmdir( $orphan_root );
		}
	}

	private function test_status_reports_corrupt_manifest_as_orphaned(): void {
		$root = get_theme_root() . '/frontman-managed-parent-theme';
		$this->write_fixture( 'wp-content/themes/frontman-managed-parent-theme/frontman-managed.json', '{invalid-json' );
		$GLOBALS['frontman_test_options']['frontman_managed_theme'] = [
			'stylesheet' => 'frontman-managed-parent-theme',
			'parent_stylesheet' => 'parent-theme',
			'ownership_token' => 'broken-token',
			'name' => 'Broken',
		];

		try {
			$status = $this->tool->get_status( [] );
			$this->assert_true( false === $status['exists'], 'Corrupt manifests do not surface as owned managed themes' );
			$this->assert_same( 'frontman-managed-parent-theme', $status['orphaned_managed_theme']['stylesheet'], 'Status still reports the corrupt managed theme stylesheet' );
		} finally {
			unset( $GLOBALS['frontman_test_options']['frontman_managed_theme'] );
			unlink( $root . '/frontman-managed.json' );
			rmdir( $root );
		}
	}

	private function test_status_reports_missing_bootstrap_file_as_orphaned(): void {
		$root = get_theme_root() . '/frontman-managed-parent-theme';
		$this->write_fixture(
			'wp-content/themes/frontman-managed-parent-theme/frontman-managed.json',
			json_encode(
				[
					'version' => 1,
					'name' => 'Broken Bootstrap',
					'stylesheet' => 'frontman-managed-parent-theme',
					'parent_stylesheet' => 'parent-theme',
					'ownership_token' => 'bootstrap-token',
					'created_at' => '2026-04-14T00:00:00Z',
					'files' => [
						'style.css' => [ 'origin' => 'system', 'writable' => true, 'created_at' => '2026-04-14T00:00:00Z' ],
					],
				],
				JSON_PRETTY_PRINT
			) . "\n"
		);
		$GLOBALS['frontman_test_options']['frontman_managed_theme'] = [
			'stylesheet' => 'frontman-managed-parent-theme',
			'parent_stylesheet' => 'parent-theme',
			'ownership_token' => 'bootstrap-token',
			'name' => 'Broken Bootstrap',
		];

		try {
			$status = $this->tool->get_status( [] );
			$this->assert_true( false === $status['exists'], 'Missing bootstrap files do not surface as a healthy managed theme' );
			$this->assert_true( false !== strpos( $status['orphaned_managed_theme']['reason'], 'bootstrap file is missing' ), 'Status reports missing bootstrap files as an orphaned managed theme state' );
		} finally {
			unset( $GLOBALS['frontman_test_options']['frontman_managed_theme'] );
			unlink( $root . '/frontman-managed.json' );
			rmdir( $root );
		}
	}

	private function test_status_reports_missing_directory_as_orphaned(): void {
		$GLOBALS['frontman_test_options']['frontman_managed_theme'] = [
			'stylesheet' => 'frontman-managed-missing-theme',
			'parent_stylesheet' => 'parent-theme',
			'ownership_token' => 'missing-token',
			'name' => 'Missing Theme',
		];

		try {
			$status = $this->tool->get_status( [] );
			$this->assert_true( false === $status['exists'], 'Missing managed-theme directories do not surface as owned themes' );
			$this->assert_same( 'frontman-managed-missing-theme', $status['orphaned_managed_theme']['stylesheet'], 'Status reports stale managed-theme registrations even when the directory is gone' );
		} finally {
			unset( $GLOBALS['frontman_test_options']['frontman_managed_theme'] );
		}
	}

	private function test_status_reports_token_mismatch_as_orphaned(): void {
		$root = get_theme_root() . '/frontman-managed-parent-theme';
		$this->write_fixture( 'wp-content/themes/frontman-managed-parent-theme/style.css', "/*\nTheme Name: Managed\nTemplate: parent-theme\n*/\n" );
		$this->write_fixture(
			'wp-content/themes/frontman-managed-parent-theme/frontman-managed.json',
			json_encode(
				[
					'version' => 1,
					'name' => 'Managed',
					'stylesheet' => 'frontman-managed-parent-theme',
					'parent_stylesheet' => 'parent-theme',
					'ownership_token' => 'manifest-token',
					'created_at' => '2026-04-14T00:00:00Z',
					'files' => [
						'style.css' => [ 'origin' => 'system', 'writable' => true, 'created_at' => '2026-04-14T00:00:00Z' ],
					],
				],
				JSON_PRETTY_PRINT
			) . "\n"
		);
		$GLOBALS['frontman_test_options']['frontman_managed_theme'] = [
			'stylesheet' => 'frontman-managed-parent-theme',
			'parent_stylesheet' => 'parent-theme',
			'ownership_token' => 'wrong-token',
			'name' => 'Managed',
		];

		try {
			$status = $this->tool->get_status( [] );
			$this->assert_true( false === $status['exists'], 'Token mismatch does not surface as an owned managed theme' );
			$this->assert_true( false !== strpos( $status['orphaned_managed_theme']['reason'], 'ownership mismatch' ), 'Status reports ownership mismatch as an orphaned managed theme state' );
			$this->assert_error_contains(
				function() {
					$this->tool->write_file( [
						'path' => 'assets/css/frontman.css',
						'content' => ".hero { color: red; }\n",
					] );
				},
				'ownership mismatch',
				'Managed-theme writes stay blocked when ownership tokens do not match'
			);
		} finally {
			unset( $GLOBALS['frontman_test_options']['frontman_managed_theme'] );
			unlink( $root . '/frontman-managed.json' );
			unlink( $root . '/style.css' );
			rmdir( $root );
		}
	}

	private function test_create_managed_theme_rejects_non_block_theme(): void {
		$previous = $GLOBALS['frontman_test_active_theme'];
		try {
			$GLOBALS['frontman_test_active_theme'] = [
				'name'           => 'Classic Parent Theme',
				'version'        => '1.0.0',
				'template'       => 'parent-theme',
				'stylesheet'     => 'parent-theme',
				'is_block_theme' => false,
			];

			$this->assert_error_contains(
				function() {
					Frontman_Managed_Theme::create();
				},
				'block themes only',
				'Frontman refuses to create a managed theme for non-block themes in v1'
			);
		} finally {
			$GLOBALS['frontman_test_active_theme'] = $previous;
		}
	}

	private function test_create_managed_theme_rejects_existing_child_theme(): void {
		$previous = $GLOBALS['frontman_test_active_theme'];
		try {
			$GLOBALS['frontman_test_active_theme'] = [
				'name'           => 'Existing Child Theme',
				'version'        => '1.0.0',
				'template'       => 'parent-theme',
				'stylesheet'     => 'existing-child-theme',
				'is_block_theme' => true,
			];

			$this->assert_error_contains(
				function() {
					Frontman_Managed_Theme::create();
				},
				'another child theme is active',
				'Frontman refuses to create a managed theme on top of an existing child theme'
			);
		} finally {
			$GLOBALS['frontman_test_active_theme'] = $previous;
		}
	}

	private function test_create_managed_theme_bootstraps_filesystem_api(): void {
		$missing_filesystem_constants = ! defined( 'FS_CHMOD_FILE' ) || ! defined( 'FS_CHMOD_DIR' );
		$this->write_fixture(
			'wp-admin/includes/file.php',
			"<?php\n" .
			"\$GLOBALS['frontman_test_file_api_loaded'] = true;\n" .
			"if ( ! defined( 'FS_CHMOD_DIR' ) ) {\n" .
			"\tdefine( 'FS_CHMOD_DIR', 0755 );\n" .
			"}\n" .
			"if ( ! defined( 'FS_CHMOD_FILE' ) ) {\n" .
			"\tdefine( 'FS_CHMOD_FILE', 0644 );\n" .
			"}\n"
		);

		$root = get_theme_root() . '/frontman-managed-parent-theme';

		try {
			$created = $this->tool->create_theme( [] );
			$this->assert_true( true === $created['created'], 'Managed theme creation succeeds even when the runtime starts without the filesystem chmod constants' );

			if ( $missing_filesystem_constants ) {
				$this->assert_true( true === ( $GLOBALS['frontman_test_file_api_loaded'] ?? false ), 'Managed theme creation loads the WordPress file API before writing files' );
				$this->assert_true( defined( 'FS_CHMOD_FILE' ), 'Managed theme creation bootstraps the WordPress file chmod constant' );
			}
		} finally {
			unset( $GLOBALS['frontman_test_options']['frontman_managed_theme'] );
			unset( $GLOBALS['frontman_test_file_api_loaded'] );

			if ( file_exists( $root . '/frontman-managed.json' ) ) {
				unlink( $root . '/frontman-managed.json' );
			}

			if ( file_exists( $root . '/style.css' ) ) {
				unlink( $root . '/style.css' );
			}

			if ( is_dir( $root ) ) {
				rmdir( $root );
			}
		}
	}

	private function test_activate_managed_theme_requires_confirmation(): void {
		$this->assert_error_contains(
			function() {
				$this->tool->activate_theme( [ 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_activate_managed_theme requires confirm=true'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->activate_theme( [ 'confirm' => 'false' ] );
			},
			'explicit confirmation',
			'wp_activate_managed_theme requires a literal boolean true confirmation'
		);

		$activated = $this->tool->activate_theme( [ 'confirm' => true ] );
		$this->assert_same( 'parent-theme', $activated['before']['stylesheet'], 'Theme activation captures the previous active theme' );
		$this->assert_same( 'frontman-managed-parent-theme', $activated['after']['stylesheet'], 'Theme activation switches to the managed theme' );
		$this->assert_true( true === $activated['activated'], 'Theme activation reports success only after the managed theme is active' );
	}

	private function test_write_managed_theme_file_tracks_owned_files(): void {
		$created = $this->tool->write_file( [
			'path'    => 'assets/css/frontman.css',
			'content' => ".hero { color: blue; }\n",
		] );
		$this->assert_true( true === $created['created'], 'wp_write_managed_theme_file can create new managed CSS files' );
		$this->assert_same( null, $created['before'], 'New managed files have no before snapshot' );

		$updated = $this->tool->write_file( [
			'path'    => 'assets/css/frontman.css',
			'content' => ".hero { color: green; }\n",
		] );
		$this->assert_true( false === $updated['created'], 'wp_write_managed_theme_file updates existing tracked files' );
		$this->assert_true( false !== strpos( $updated['before']['content'], 'blue' ), 'Managed file updates capture the previous content' );

		$read = $this->tool->read_file( [ 'path' => 'assets/css/frontman.css' ] );
		$this->assert_true( false !== strpos( $read['content'], 'green' ), 'wp_read_managed_theme_file reads tracked files' );

		$json = $this->tool->write_file( [
			'path'    => 'theme.json',
			'content' => "{\n  \"version\": 3\n}\n",
		] );
		$this->assert_true( true === $json['created'], 'wp_write_managed_theme_file can create theme.json inside the managed theme' );

		$style = $this->tool->write_file( [
			'path'    => 'style.css',
			'content' => "/*\nTheme Name: Malicious\nTemplate: evil-parent\n*/\n.hero { color: purple; }\n",
		] );
		$this->assert_true( 0 === strpos( $style['after']['content'], "/*\nTheme Name: Frontman Managed (Parent Theme)\nTemplate: parent-theme" ), 'Managed style.css writes rebuild the canonical child-theme header' );
		$this->assert_true( false !== strpos( $style['after']['content'], 'Template: parent-theme' ), 'Managed style.css writes preserve the child-theme header' );
		$this->assert_true( false === strpos( $style['after']['content'], 'evil-parent' ), 'Managed style.css writes strip hostile incoming theme headers' );
		$this->assert_true( false !== strpos( $style['after']['content'], '.hero { color: purple; }' ), 'Managed style.css writes append the edited CSS body' );
	}

	private function test_fork_parent_theme_file(): void {
		$forked = $this->tool->fork_parent_file( [ 'path' => 'templates/home.html' ] );
		$this->assert_true( true === $forked['copied'], 'wp_fork_parent_theme_file copies parent theme files into the managed theme' );
		$this->assert_same( 'forked', $forked['after']['origin'], 'Forked files are tracked with forked origin' );

		$updated = $this->tool->write_file( [
			'path'    => 'templates/home.html',
			'content' => "<!-- wp:paragraph --><p>Forked Home</p><!-- /wp:paragraph -->\n",
		] );
		$this->assert_true( false !== strpos( $updated['before']['content'], 'Parent Home' ), 'Forked files become writable managed copies' );
	}

	private function test_reject_unmanaged_or_unsupported_writes(): void {
		$this->write_fixture( 'wp-content/themes/frontman-managed-parent-theme/assets/css/manual.css', ".manual { color: black; }\n" );

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => 'assets/css/manual.css',
					'content' => ".manual { color: white; }\n",
				] );
			},
			'not tracked by Frontman',
			'Existing unmanaged child-theme files cannot be overwritten'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->read_file( [ 'path' => 'assets/css/manual.css' ] );
			},
			'not tracked by Frontman',
			'Untracked child-theme files are not exposed for reads'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->fork_parent_file( [ 'path' => 'functions.php' ] );
			},
			'Only CSS, JSON, and HTML',
			'PHP parent theme files cannot be forked into the managed theme'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => 'templates/index.php',
					'content' => "<?php echo 'no';\n",
				] );
			},
			'Only CSS, JSON, and HTML files are writable',
			'PHP files are not writable inside the managed theme'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => '../outside.css',
					'content' => ".outside { color: red; }\n",
				] );
			},
			'Invalid managed theme path',
			'Path traversal is rejected for managed theme writes'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => 'frontman-managed.json',
					'content' => "{}\n",
				] );
			},
			'manifest cannot be edited',
			'The managed-theme manifest is not writable through the tool'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => [ 'not-a-string' ],
					'content' => ".bad { color: red; }\n",
				] );
			},
			'Expected `path` to be a string',
			'Managed-theme handlers reject non-string path inputs'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => '/absolute.css',
					'content' => ".absolute { color: red; }\n",
				] );
			},
			'Managed theme paths must be relative',
			'Absolute managed-theme paths are rejected'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => '.hidden.css',
					'content' => ".hidden { color: red; }\n",
				] );
			},
			'Hidden files are not writable',
			'Hidden managed-theme files are rejected'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->write_file( [
					'path'    => 'assets/css/huge.css',
					'content' => str_repeat( 'a', 300000 ),
				] );
			},
			'too large to write',
			'Managed-theme writes are capped to a reasonable size'
		);
	}

	private function test_read_and_fork_enforce_size_limits(): void {
		$this->write_fixture( 'wp-content/themes/parent-theme/assets/css/huge.css', str_repeat( 'b', 300000 ) );
		$this->write_fixture( 'wp-content/themes/frontman-managed-parent-theme/assets/css/huge-read.css', str_repeat( 'c', 300000 ) );

		$manifest_path = get_theme_root() . '/frontman-managed-parent-theme/frontman-managed.json';
		$manifest = json_decode( file_get_contents( $manifest_path ), true );
		$manifest['files']['assets/css/huge-read.css'] = [
			'origin' => 'created',
			'writable' => true,
			'created_at' => '2026-04-14T00:00:00Z',
		];
		file_put_contents( $manifest_path, json_encode( $manifest, JSON_PRETTY_PRINT ) . "\n" );

		$this->assert_error_contains(
			function() {
				$this->tool->read_file( [ 'path' => 'assets/css/huge-read.css' ] );
			},
			'too large to read',
			'Managed-theme reads are capped to a reasonable size'
		);

		$this->assert_error_contains(
			function() {
				$this->tool->fork_parent_file( [ 'path' => 'assets/css/huge.css' ] );
			},
			'too large to fork',
			'Managed-theme forks are capped to a reasonable size'
		);
	}

	private function test_symlink_escape_is_rejected(): void {
		if ( ! function_exists( 'symlink' ) ) {
			return;
		}

		$outside = sys_get_temp_dir() . '/frontman-managed-outside-' . uniqid();
		mkdir( $outside, 0777, true );
		file_put_contents( $outside . '/escape.css', ".escape { color: black; }\n" );

		$managed_assets = get_theme_root() . '/frontman-managed-parent-theme/assets';
		if ( ! is_dir( $managed_assets ) ) {
			mkdir( $managed_assets, 0777, true );
		}

		$symlink_path = $managed_assets . '/outside-link';
		symlink( $outside, $symlink_path );

		try {
			$this->assert_error_contains(
				function() {
					$this->tool->write_file( [
						'path' => 'assets/outside-link/escape.css',
						'content' => ".escape { color: red; }\n",
					] );
				},
				'Path escapes the Frontman managed theme',
				'Symlinked managed-theme paths are rejected'
			);
		} finally {
			unlink( $symlink_path );
			unlink( $outside . '/escape.css' );
			rmdir( $outside );
		}
	}

	private function write_fixture( string $relative_path, string $content ): void {
		$absolute_path = ABSPATH . $relative_path;
		$directory = dirname( $absolute_path );
		if ( ! is_dir( $directory ) ) {
			mkdir( $directory, 0777, true );
		}

		file_put_contents( $absolute_path, $content );
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

	private function assert_error_contains( callable $fn, string $needle, string $message ): void {
		$this->assertions++;
		try {
			$fn();
			throw new RuntimeException( $message . ' (expected error)' );
		} catch ( Frontman_Tool_Error $e ) {
			if ( false === strpos( $e->getMessage(), $needle ) ) {
				throw new RuntimeException( $message . ' (wrong error: ' . $e->getMessage() . ')' );
			}
		}
	}
}

( new Frontman_Managed_Theme_Tools_Test_Runner() )->run();
