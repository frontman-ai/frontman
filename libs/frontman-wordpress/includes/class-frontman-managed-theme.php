<?php
/**
 * Frontman-managed child theme helpers.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Managed_Theme {
	private const OPTION_KEY = 'frontman_managed_theme';
	private const MANIFEST_FILE = 'frontman-managed.json';
	private const STYLESHEET_PREFIX = 'frontman-managed-';
	private const MUTABLE_EXTENSIONS = [ 'css', 'json', 'html' ];
	private const MAX_FILE_BYTES = 262144;

	/**
	 * Return the current managed-theme status.
	 */
	public static function status(): array {
		$managed  = null;
		$orphaned = null;

		try {
			$managed = self::locate_managed_theme();
		} catch ( Frontman_Tool_Error $e ) {
			$orphaned = self::safe_orphaned_theme( $e->getMessage() );
		}

		if ( null === $managed && null === $orphaned ) {
			$orphaned = self::safe_orphaned_theme();
		}

		return [
			'exists'                => null !== $managed,
			'active_theme'          => self::active_theme_summary(),
			'managed_theme'         => null !== $managed ? self::serialize_theme( $managed ) : null,
			'orphaned_managed_theme'=> $orphaned,
		];
	}

	/**
	 * Create the managed child theme if needed.
	 */
	public static function create(): array {
		$managed = self::locate_managed_theme();
		if ( null !== $managed ) {
			return [
				'created' => false,
				'theme'   => self::serialize_theme( $managed ),
				'files'   => self::serialize_files( $managed ),
			];
		}

		$active_theme       = wp_get_theme();
		$parent_stylesheet  = sanitize_key( $active_theme->get_template() );
		$active_stylesheet  = sanitize_key( $active_theme->get_stylesheet() );
		$parent_name        = (string) $active_theme->get( 'Name' );
		$is_block_theme     = method_exists( $active_theme, 'is_block_theme' ) ? (bool) $active_theme->is_block_theme() : false;
		$managed_stylesheet = self::STYLESHEET_PREFIX . $parent_stylesheet;
		$managed_name       = 'Frontman Managed (' . $parent_name . ')';
		$root_path          = self::theme_root() . '/' . $managed_stylesheet;
		$existing_manifest  = self::read_manifest_if_exists( $root_path );
		$ownership_token    = uniqid( 'frontman-managed-', true );

		if ( $managed_stylesheet === $active_stylesheet ) {
			throw new Frontman_Tool_Error( 'The active theme already uses the Frontman-managed stylesheet, but its manifest could not be found.' );
		}

		if ( $parent_stylesheet !== $active_stylesheet ) {
			throw new Frontman_Tool_Error( 'Frontman cannot create a managed child theme while another child theme is active. Switch to the parent theme first or migrate the needed files manually.' );
		}

		if ( ! $is_block_theme ) {
			throw new Frontman_Tool_Error( 'Frontman managed-theme editing currently supports block themes only. This site can still use read-only inspection and the WordPress-native content tools.' );
		}

		if ( null !== $existing_manifest ) {
			throw new Frontman_Tool_Error( 'A Frontman-managed theme directory already exists, but it is not registered to this site. Inspect wp_get_managed_theme_status and delete it manually before creating a new managed theme.' );
		}

		if ( is_dir( $root_path ) && ! file_exists( self::manifest_path( $root_path ) ) ) {
			throw new Frontman_Tool_Error( 'A theme directory already exists at ' . $managed_stylesheet . ' but it is not managed by Frontman.' );
		}

		if ( ! wp_mkdir_p( $root_path ) ) {
			throw new Frontman_Tool_Error( 'Failed to create the Frontman-managed theme directory.' );
		}

		$created_at = gmdate( 'c' );
		$manifest   = [
			'version'           => 1,
			'name'              => $managed_name,
			'stylesheet'        => $managed_stylesheet,
			'parent_stylesheet' => $parent_stylesheet,
			'ownership_token'   => $ownership_token,
			'created_at'        => $created_at,
			'files'             => [
				'style.css' => [ 'origin' => 'system', 'writable' => true, 'created_at' => $created_at ],
			],
		];

		try {
			self::write_file_contents( $root_path . '/style.css', self::generated_style_css( $managed_name, $parent_stylesheet ) );
			self::write_manifest( $root_path, $manifest );

			if ( ! update_option(
				self::OPTION_KEY,
				[
					'stylesheet'        => $managed_stylesheet,
					'parent_stylesheet' => $parent_stylesheet,
					'ownership_token'   => $ownership_token,
					'name'              => $managed_name,
				]
			) ) {
				throw new Frontman_Tool_Error( 'Failed to register the Frontman-managed theme in WordPress options.' );
			}
		} catch ( \Throwable $e ) {
			self::delete_tree( $root_path );
			throw $e;
		}

		$managed = self::managed_from_manifest( $root_path, $manifest );

		return [
			'created' => true,
			'theme'   => self::serialize_theme( $managed ),
			'files'   => self::serialize_files( $managed ),
		];
	}

	/**
	 * Activate the managed child theme.
	 */
	public static function activate( bool $confirm ): array {
		if ( ! $confirm ) {
			throw new Frontman_Tool_Error( 'Managed theme activation requires explicit confirmation. Call this tool only after the user confirms.' );
		}

		$managed = self::require_managed_theme();
		$before  = self::active_theme_summary();

		if ( $managed['stylesheet'] !== $before['stylesheet'] ) {
			self::switch_to_theme( $managed['stylesheet'] );
		}

		$after = self::active_theme_summary();
		if ( $after['stylesheet'] !== $managed['stylesheet'] ) {
			throw new Frontman_Tool_Error( 'WordPress did not activate the Frontman-managed theme.' );
		}

		return [
			'activated' => true,
			'before'    => $before,
			'after'     => $after,
			'theme'     => self::serialize_theme( self::require_managed_theme() ),
		];
	}

	/**
	 * List tracked files in the managed theme.
	 */
	public static function list_files(): array {
		$managed = self::require_managed_theme();

		return [
			'theme' => self::serialize_theme( $managed ),
			'count' => count( $managed['manifest']['files'] ),
			'files' => self::serialize_files( $managed ),
		];
	}

	/**
	 * Read a tracked managed-theme file.
	 */
	public static function read_file( string $relative_path ): array {
		$managed  = self::require_managed_theme();
		$relative = self::normalize_relative_path( $relative_path );
		$entry    = self::manifest_entry( $managed['manifest'], $relative );
		$path     = self::resolve_under_root( $managed['root_path'], $relative );

		if ( ! file_exists( $path ) || ! is_file( $path ) ) {
			throw new Frontman_Tool_Error( 'Managed theme file does not exist: ' . $relative );
		}

		$content = file_get_contents( $path );
		if ( false === $content ) {
			throw new Frontman_Tool_Error( 'Failed to read managed theme file: ' . $relative );
		}

		self::assert_content_size( $relative, $content, 'Managed theme file is too large to read through this tool.' );

		return [
			'path'     => $relative,
			'content'  => $content,
			'origin'   => $entry['origin'],
			'writable' => (bool) $entry['writable'],
			'size'     => filesize( $path ),
		];
	}

	/**
	 * Create or update a tracked managed-theme file.
	 */
	public static function write_file( string $relative_path, string $content ): array {
		$managed  = self::require_managed_theme();
		$relative = self::normalize_relative_path( $relative_path );
		$path     = self::resolve_under_root( $managed['root_path'], $relative );
		$manifest = $managed['manifest'];

		self::assert_mutable_path( $relative );

		$tracked   = isset( $manifest['files'][ $relative ] );
		$exists    = file_exists( $path );
		$before    = null;
		$created   = ! $tracked;

		if ( $tracked && empty( $manifest['files'][ $relative ]['writable'] ) ) {
			throw new Frontman_Tool_Error( 'Managed theme file is read-only: ' . $relative );
		}

		if ( $exists && ! $tracked ) {
			throw new Frontman_Tool_Error( 'Managed theme file already exists but is not tracked by Frontman: ' . $relative );
		}

		if ( $exists ) {
			$before = file_get_contents( $path );
			if ( false === $before ) {
				throw new Frontman_Tool_Error( 'Failed to read the existing managed theme file before writing: ' . $relative );
			}
		}

		$content = self::prepare_write_content( $managed, $relative, $content );
		self::assert_content_size( $relative, $content, 'Managed theme file is too large to write through this tool.' );

		try {
			self::write_file_contents( $path, $content );

			if ( ! $tracked ) {
				$manifest['files'][ $relative ] = [
					'origin'     => 'created',
					'writable'   => true,
					'created_at' => gmdate( 'c' ),
				];
				self::write_manifest( $managed['root_path'], $manifest );
				$managed['manifest'] = $manifest;
			}
		} catch ( \Throwable $e ) {
			if ( ! $tracked ) {
				self::delete_file_if_exists( $path );
			}

			throw $e;
		}

		return [
			'created' => $created,
			'path'    => $relative,
			'before'  => null !== $before ? [ 'content' => $before ] : null,
			'after'   => [ 'content' => $content ],
			'file'    => self::serialize_file( $managed, $relative, $managed['manifest']['files'][ $relative ] ?? $manifest['files'][ $relative ] ),
		];
	}

	/**
	 * Copy a supported parent-theme file into the managed child theme.
	 */
	public static function fork_parent_file( string $relative_path ): array {
		$managed     = self::require_managed_theme();
		$relative    = self::normalize_relative_path( $relative_path );
		$parent_root = self::parent_theme_root( $managed );
		$source_path = self::resolve_under_root( $parent_root, $relative );
		$target_path = self::resolve_under_root( $managed['root_path'], $relative );

		self::assert_mutable_path( $relative, 'Only CSS, JSON, and HTML theme files can be forked into the Frontman-managed theme.' );

		if ( isset( $managed['manifest']['files'][ $relative ] ) || file_exists( $target_path ) ) {
			throw new Frontman_Tool_Error( 'Managed theme file already exists: ' . $relative );
		}

		if ( ! file_exists( $source_path ) || ! is_file( $source_path ) ) {
			throw new Frontman_Tool_Error( 'Parent theme file not found: ' . $relative );
		}

		$content = file_get_contents( $source_path );
		if ( false === $content ) {
			throw new Frontman_Tool_Error( 'Failed to read parent theme file: ' . $relative );
		}

		self::assert_content_size( $relative, $content, 'Parent theme file is too large to fork through this tool.' );

		$manifest = $managed['manifest'];

		try {
			self::write_file_contents( $target_path, $content );

			$manifest['files'][ $relative ] = [
				'origin'           => 'forked',
				'writable'         => true,
				'created_at'       => gmdate( 'c' ),
				'forked_from_path' => $relative,
			];
			self::write_manifest( $managed['root_path'], $manifest );
			$managed['manifest'] = $manifest;
		} catch ( \Throwable $e ) {
			self::delete_file_if_exists( $target_path );
			throw $e;
		}

		return [
			'copied'           => true,
			'path'             => $relative,
			'forked_from_path' => $relative,
			'after'            => self::serialize_file( $managed, $relative, $manifest['files'][ $relative ] ),
		];
	}

	/**
	 * Return the current active theme summary.
	 */
	private static function active_theme_summary(): array {
		$theme = wp_get_theme();

		return [
			'name'          => (string) $theme->get( 'Name' ),
			'version'       => (string) $theme->get( 'Version' ),
			'template'      => sanitize_key( $theme->get_template() ),
			'stylesheet'    => sanitize_key( $theme->get_stylesheet() ),
			'is_block_theme'=> method_exists( $theme, 'is_block_theme' ) ? (bool) $theme->is_block_theme() : false,
		];
	}

	/**
	 * Locate the existing managed theme, if present.
	 */
	private static function locate_managed_theme(): ?array {
		$stored = get_option( self::OPTION_KEY, [] );

		if ( is_array( $stored ) && ! empty( $stored['stylesheet'] ) ) {
			$stylesheet        = sanitize_key( $stored['stylesheet'] );
			$stored_parent     = sanitize_key( $stored['parent_stylesheet'] ?? '' );
			$root_path         = self::theme_root() . '/' . $stylesheet;
			$manifest          = self::read_manifest_if_exists( $root_path );
			$manifest_slug     = null !== $manifest ? sanitize_key( $manifest['stylesheet'] ?? '' ) : '';
			$manifest_parent   = null !== $manifest ? sanitize_key( $manifest['parent_stylesheet'] ?? '' ) : '';

			if ( null !== $manifest ) {
				$stored_token = (string) ( $stored['ownership_token'] ?? '' );
				if ( '' === $stored_token || $stored_token !== (string) ( $manifest['ownership_token'] ?? '' ) ) {
					throw new Frontman_Tool_Error( 'Frontman managed-theme ownership mismatch. Refusing to adopt this theme automatically.' );
				}

				if ( $stylesheet !== $manifest_slug || ( '' !== $stored_parent && $stored_parent !== $manifest_parent ) ) {
					throw new Frontman_Tool_Error( 'Frontman managed-theme ownership mismatch. Refusing to adopt this theme automatically.' );
				}

				if ( ! file_exists( $root_path . '/style.css' ) || ! is_file( $root_path . '/style.css' ) ) {
					throw new Frontman_Tool_Error( 'Frontman managed-theme bootstrap file is missing. The child theme needs repair before it can be used.' );
				}

				return self::managed_from_manifest( $root_path, $manifest );
			}
		}

		return null;
	}

	/**
	 * Detect an orphaned managed-theme directory for the current parent theme.
	 */
	private static function detect_orphaned_theme( string $reason_override = '' ): ?array {
		$stored = get_option( self::OPTION_KEY, [] );

		if ( is_array( $stored ) && ! empty( $stored['stylesheet'] ) ) {
			$stylesheet = sanitize_key( $stored['stylesheet'] );
			$root_path  = self::theme_root() . '/' . $stylesheet;
			$manifest   = self::read_manifest_if_exists( $root_path );

			if ( null !== $manifest || '' !== $reason_override || is_dir( $root_path ) || ! empty( $stylesheet ) ) {
				return [
					'stylesheet' => $stylesheet,
					'reason'     => '' !== $reason_override ? $reason_override : 'Managed theme registration exists, but Frontman cannot verify the corresponding child theme files.',
				];
			}
		}

		$active_theme      = wp_get_theme();
		$parent_stylesheet = sanitize_key( $active_theme->get_template() );
		$active_stylesheet = sanitize_key( $active_theme->get_stylesheet() );

		if ( 0 === strpos( $active_stylesheet, self::STYLESHEET_PREFIX ) ) {
			$root_path = self::theme_root() . '/' . $active_stylesheet;
			$manifest  = self::read_manifest_if_exists( $root_path );

			if ( null !== $manifest || ! empty( $reason_override ) || is_dir( $root_path ) ) {
				return [
					'stylesheet' => null !== $manifest ? sanitize_key( $manifest['stylesheet'] ) : $active_stylesheet,
					'reason'     => '' !== $reason_override ? $reason_override : 'A Frontman-managed child theme is active, but Frontman does not recognize it as owned by this site.',
				];
			}
		}

		if ( $parent_stylesheet !== $active_stylesheet ) {
			return null;
		}

		$stylesheet = self::STYLESHEET_PREFIX . $parent_stylesheet;
		$root_path  = self::theme_root() . '/' . $stylesheet;
		$manifest   = self::read_manifest_if_exists( $root_path );

		if ( null === $manifest ) {
			return null;
		}

		return [
			'stylesheet' => sanitize_key( $manifest['stylesheet'] ),
			'reason'     => 'Managed theme files exist on disk, but Frontman does not recognize them as owned by this site.',
		];
	}

	/**
	 * Downgrade orphan detection failures into a readable status payload.
	 */
	private static function safe_orphaned_theme( string $reason_override = '' ): ?array {
		try {
			return self::detect_orphaned_theme( $reason_override );
		} catch ( Frontman_Tool_Error $e ) {
			$stored = get_option( self::OPTION_KEY, [] );
			if ( is_array( $stored ) && ! empty( $stored['stylesheet'] ) ) {
				return [
					'stylesheet' => sanitize_key( $stored['stylesheet'] ),
					'reason'     => '' !== $reason_override ? $reason_override : $e->getMessage(),
				];
			}

			$active_stylesheet = sanitize_key( get_stylesheet() );
			if ( 0 === strpos( $active_stylesheet, self::STYLESHEET_PREFIX ) ) {
				return [
					'stylesheet' => $active_stylesheet,
					'reason'     => '' !== $reason_override ? $reason_override : $e->getMessage(),
				];
			}

			$active_theme      = wp_get_theme();
			$parent_stylesheet = sanitize_key( $active_theme->get_template() );
			$expected_slug     = self::STYLESHEET_PREFIX . $parent_stylesheet;
			$expected_root     = self::theme_root() . '/' . $expected_slug;

			if ( is_dir( $expected_root ) ) {
				return [
					'stylesheet' => $expected_slug,
					'reason'     => '' !== $reason_override ? $reason_override : $e->getMessage(),
				];
			}

			return null;
		}
	}

	/**
	 * Require an existing managed theme.
	 */
	private static function require_managed_theme(): array {
		$managed = self::locate_managed_theme();

		if ( null === $managed ) {
			throw new Frontman_Tool_Error( 'Frontman managed theme has not been created yet. Call wp_create_managed_theme first.' );
		}

		return $managed;
	}

	/**
	 * Convert a manifest into the runtime shape.
	 */
	private static function managed_from_manifest( string $root_path, array $manifest ): array {
		return [
			'root_path'         => Frontman_Core_Path::normalize( $root_path ),
			'name'              => (string) $manifest['name'],
			'stylesheet'        => sanitize_key( $manifest['stylesheet'] ),
			'parent_stylesheet' => sanitize_key( $manifest['parent_stylesheet'] ),
			'ownership_token'   => (string) ( $manifest['ownership_token'] ?? '' ),
			'created_at'        => (string) $manifest['created_at'],
			'manifest'          => $manifest,
		];
	}

	/**
	 * Serialize the managed-theme summary.
	 */
	private static function serialize_theme( array $managed ): array {
		return [
			'name'              => $managed['name'],
			'stylesheet'        => $managed['stylesheet'],
			'parent_stylesheet' => $managed['parent_stylesheet'],
			'active'            => sanitize_key( get_stylesheet() ) === $managed['stylesheet'],
			'file_count'        => count( $managed['manifest']['files'] ),
			'created_at'        => $managed['created_at'],
		];
	}

	/**
	 * Serialize all tracked files.
	 */
	private static function serialize_files( array $managed ): array {
		$result = [];

		foreach ( $managed['manifest']['files'] as $relative => $entry ) {
			$result[] = self::serialize_file( $managed, $relative, $entry );
		}

		usort(
			$result,
			static function( array $left, array $right ): int {
				return strcmp( $left['path'], $right['path'] );
			}
		);

		return $result;
	}

	/**
	 * Serialize a single tracked file.
	 */
	private static function serialize_file( array $managed, string $relative, array $entry ): array {
		$path = self::resolve_under_root( $managed['root_path'], $relative );

		return [
			'path'              => $relative,
			'origin'            => (string) $entry['origin'],
			'writable'          => ! empty( $entry['writable'] ),
			'exists'            => file_exists( $path ),
			'size'              => file_exists( $path ) ? filesize( $path ) : null,
			'created_at'        => $entry['created_at'] ?? null,
			'forked_from_path'  => $entry['forked_from_path'] ?? null,
		];
	}

	/**
	 * Get a manifest entry or fail.
	 */
	private static function manifest_entry( array $manifest, string $relative ): array {
		if ( empty( $manifest['files'][ $relative ] ) || ! is_array( $manifest['files'][ $relative ] ) ) {
			throw new Frontman_Tool_Error( 'Managed theme file is not tracked by Frontman: ' . $relative );
		}

		return $manifest['files'][ $relative ];
	}

	/**
	 * Get the active parent theme root for the managed theme.
	 */
	private static function parent_theme_root( array $managed ): string {
		$path = Frontman_Core_Path::normalize( self::theme_root() . '/' . $managed['parent_stylesheet'] );

		if ( ! is_dir( $path ) ) {
			throw new Frontman_Tool_Error( 'Parent theme directory is missing: ' . $managed['parent_stylesheet'] );
		}

		return $path;
	}

	/**
	 * Resolve the WordPress theme root.
	 */
	private static function theme_root(): string {
		$root = function_exists( 'get_theme_root' ) ? call_user_func( 'get_theme_root' ) : ABSPATH . 'wp-content/themes';

		return Frontman_Core_Path::normalize( rtrim( (string) $root, '/\\' ) );
	}

	/**
	 * Switch to a theme if WordPress supports it in this runtime.
	 */
	private static function switch_to_theme( string $stylesheet ): void {
		if ( ! function_exists( 'switch_theme' ) ) {
			throw new Frontman_Tool_Error( 'WordPress cannot switch themes in this runtime.' );
		}

		call_user_func( 'switch_theme', $stylesheet );
	}

	/**
	 * Build the manifest path.
	 */
	private static function manifest_path( string $root_path ): string {
		return Frontman_Core_Path::normalize( $root_path . '/' . self::MANIFEST_FILE );
	}

	/**
	 * Read the manifest if present.
	 */
	private static function read_manifest_if_exists( string $root_path ): ?array {
		$manifest_path = self::manifest_path( $root_path );

		if ( ! file_exists( $manifest_path ) ) {
			return null;
		}

		$content = file_get_contents( $manifest_path );
		if ( false === $content ) {
			throw new Frontman_Tool_Error( 'Failed to read the Frontman managed-theme manifest.' );
		}

		$data = json_decode( $content, true );
		if ( ! is_array( $data ) || empty( $data['stylesheet'] ) || empty( $data['parent_stylesheet'] ) || empty( $data['ownership_token'] ) || ! array_key_exists( 'files', $data ) || ! is_array( $data['files'] ) ) {
			throw new Frontman_Tool_Error( 'The Frontman managed-theme manifest is invalid.' );
		}

		return $data;
	}

	/**
	 * Preserve the required child-theme header when writing style.css.
	 */
	private static function prepare_write_content( array $managed, string $relative_path, string $content ): string {
		if ( 'style.css' !== $relative_path ) {
			return $content;
		}

		$body = preg_replace( '/^\s*\/\*.*?\*\/\s*/s', '', $content, 1 );
		if ( null === $body ) {
			throw new Frontman_Tool_Error( 'Failed to prepare style.css for writing.' );
		}

		return self::generated_style_css( $managed['name'], $managed['parent_stylesheet'] ) . ltrim( $body );
	}

	/**
	 * Cap managed-theme payload sizes.
	 */
	private static function assert_content_size( string $relative_path, string $content, string $message ): void {
		if ( strlen( $content ) > self::MAX_FILE_BYTES ) {
			throw new Frontman_Tool_Error( $message . ' (' . $relative_path . ')' );
		}
	}

	/**
	 * Persist the manifest.
	 */
	private static function write_manifest( string $root_path, array $manifest ): void {
		$encoded = wp_json_encode( $manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES );
		if ( ! is_string( $encoded ) ) {
			throw new Frontman_Tool_Error( 'Failed to encode the Frontman managed-theme manifest.' );
		}

		self::write_file_contents( self::manifest_path( $root_path ), $encoded . "\n" );
	}

	/**
	 * Write file contents or fail.
	 */
	private static function write_file_contents( string $path, string $content ): void {
		$filesystem = self::filesystem();
		$directory = dirname( $path );
		if ( ! $filesystem->is_dir( $directory ) && ! wp_mkdir_p( $directory ) ) {
			throw new Frontman_Tool_Error( 'Failed to create the destination directory for ' . basename( $path ) );
		}

		$temp_path = self::temp_file_path( $path, $directory );
		if ( false === $temp_path ) {
			throw new Frontman_Tool_Error( 'Failed to allocate a temporary file for ' . basename( $path ) );
		}

		if ( ! $filesystem->put_contents( $temp_path, $content ) ) {
			self::delete_file_if_exists( $temp_path );
			throw new Frontman_Tool_Error( 'Failed to write file: ' . basename( $path ) );
		}

		if ( ! $filesystem->move( $temp_path, $path, true ) ) {
			self::delete_file_if_exists( $temp_path );
			throw new Frontman_Tool_Error( 'Failed to finalize file write: ' . basename( $path ) );
		}
	}

	/**
	 * Remove a file if it exists.
	 */
	private static function delete_file_if_exists( string $path ): void {
		$filesystem = self::filesystem();

		if ( $filesystem->exists( $path ) && $filesystem->is_file( $path ) ) {
			$filesystem->delete( $path, false, 'f' );
		}
	}

	/**
	 * Remove a directory tree best-effort.
	 */
	private static function delete_tree( string $root_path ): void {
		$filesystem = self::filesystem();

		if ( ! $filesystem->is_dir( $root_path ) ) {
			return;
		}

		$filesystem->delete( $root_path, true, 'd' );
	}

	/**
	 * Load the WordPress file API and chmod constants when available.
	 */
	private static function bootstrap_filesystem_api(): void {
		$file_api_path = ABSPATH . 'wp-admin/includes/file.php';

		if ( ( ! function_exists( 'wp_tempnam' ) || ! defined( 'FS_CHMOD_FILE' ) || ! defined( 'FS_CHMOD_DIR' ) ) && file_exists( $file_api_path ) ) {
			require_once $file_api_path;
		}

		if ( ! defined( 'FS_CHMOD_DIR' ) ) {
			define( 'FS_CHMOD_DIR', 0755 );
		}

		if ( ! defined( 'FS_CHMOD_FILE' ) ) {
			define( 'FS_CHMOD_FILE', 0644 );
		}
	}

	/**
	 * Get a filesystem adapter suitable for local plugin-managed files.
	 */
	private static function filesystem() {
		self::bootstrap_filesystem_api();

		if ( ! class_exists( 'WP_Filesystem_Direct' ) ) {
			require_once ABSPATH . 'wp-admin/includes/class-wp-filesystem-base.php';
			require_once ABSPATH . 'wp-admin/includes/class-wp-filesystem-direct.php';
		}

		$class_name = 'WP_Filesystem_Direct';

		return new $class_name( null );
	}

	/**
	 * Create a temporary file path in the target directory.
	 *
	 * @return string|false
	 */
	private static function temp_file_path( string $path, string $directory ) {
		self::bootstrap_filesystem_api();

		if ( ! function_exists( 'wp_tempnam' ) ) {
			throw new Frontman_Tool_Error( 'WordPress filesystem helpers are unavailable for temporary file creation.' );
		}

		return wp_tempnam( basename( $path ), $directory );
	}

	/**
	 * Ensure the relative path stays under the managed-theme root.
	 */
	private static function resolve_under_root( string $root_path, string $relative_path ): string {
		$relative = self::normalize_relative_path( $relative_path );
		$root     = Frontman_Core_Path::normalize( $root_path );
		$resolved = self::canonicalize( $root . '/' . $relative );

		if ( ! self::is_under_root( $root, $resolved ) ) {
			throw new Frontman_Tool_Error( 'Path escapes the Frontman managed theme: ' . $relative );
		}

		return $resolved;
	}

	/**
	 * Normalize a managed-theme relative path.
	 */
	private static function normalize_relative_path( string $relative_path ): string {
		if ( self::is_absolute_path( $relative_path ) ) {
			throw new Frontman_Tool_Error( 'Managed theme paths must be relative.' );
		}

		$relative = Frontman_Core_Path::normalize( ltrim( str_replace( '\\', '/', trim( $relative_path ) ), '/' ) );

		if ( '' === $relative || '.' === $relative || '..' === $relative || 0 === strpos( $relative, '../' ) || false !== strpos( $relative, '/../' ) ) {
			throw new Frontman_Tool_Error( 'Invalid managed theme path: ' . $relative_path );
		}

		return $relative;
	}

	/**
	 * Restrict mutable files to CSS, JSON, and HTML.
	 */
	private static function assert_mutable_path( string $relative_path, string $message = '' ): void {
		$basename  = basename( $relative_path );
		$extension = strtolower( pathinfo( $relative_path, PATHINFO_EXTENSION ) );

		if ( self::MANIFEST_FILE === $relative_path || self::MANIFEST_FILE === $basename ) {
			throw new Frontman_Tool_Error( 'The Frontman managed-theme manifest cannot be edited directly.' );
		}

		if ( 0 === strpos( $basename, '.' ) || false !== strpos( $relative_path, '/.' ) ) {
			throw new Frontman_Tool_Error( 'Hidden files are not writable in the Frontman managed theme.' );
		}

		if ( ! in_array( $extension, self::MUTABLE_EXTENSIONS, true ) ) {
			throw new Frontman_Tool_Error( '' !== $message ? $message : 'Only CSS, JSON, and HTML files are writable in the Frontman managed theme.' );
		}
	}

	/**
	 * Normalize an absolute/relative path against its real parent.
	 */
	private static function canonicalize( string $path ): string {
		$normalized = Frontman_Core_Path::normalize( $path );

		if ( file_exists( $normalized ) ) {
			$real = realpath( $normalized );
			return false !== $real ? Frontman_Core_Path::normalize( $real ) : $normalized;
		}

		$pending = [];
		$probe   = $normalized;

		while ( ! file_exists( $probe ) ) {
			$parent = dirname( $probe );
			if ( $parent === $probe ) {
				return $normalized;
			}

			array_unshift( $pending, basename( $probe ) );
			$probe = $parent;
		}

		$real_base = realpath( $probe );
		if ( false === $real_base ) {
			return $normalized;
		}

		$resolved = Frontman_Core_Path::normalize( $real_base );
		foreach ( $pending as $segment ) {
			$resolved = Frontman_Core_Path::normalize( $resolved . '/' . $segment );
		}

		return $resolved;
	}

	/**
	 * Check whether a path is absolute.
	 */
	private static function is_absolute_path( string $path ): bool {
		$path = str_replace( '\\', '/', $path );
		return '/' === substr( $path, 0, 1 ) || 1 === preg_match( '/^[A-Za-z]:\//', $path );
	}

	/**
	 * Check whether the resolved path stays within the root.
	 */
	private static function is_under_root( string $root_path, string $resolved_path ): bool {
		return $resolved_path === $root_path || 0 === strpos( $resolved_path, trailingslashit( $root_path ) );
	}

	/**
	 * Build the generated child-theme stylesheet.
	 */
	private static function generated_style_css( string $name, string $parent_stylesheet ): string {
		return "/*\nTheme Name: {$name}\nTemplate: {$parent_stylesheet}\nVersion: 0.1.0\nText Domain: frontman-managed\n*/\n\n";
	}

}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
