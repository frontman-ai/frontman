<?php
/**
 * WordPress Options tools — read and modify site options.
 *
 * Tools: wp_get_option, wp_update_option, wp_list_options,
 * wp_get_custom_css, wp_list_custom_css_revisions, wp_get_custom_css_revision,
 * wp_restore_custom_css_revision, wp_update_custom_css, wp_list_theme_mods,
 * wp_get_theme_mod
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}


class Frontman_Tool_Options {
	/**
	 * Options that are safe to read/modify.
	 * We deliberately exclude sensitive options like auth keys, salts, etc.
	 */
	private const READABLE_OPTIONS = [
		'blogname',
		'blogdescription',
		'siteurl',
		'home',
		'admin_email',
		'posts_per_page',
		'date_format',
		'time_format',
		'timezone_string',
		'gmt_offset',
		'permalink_structure',
		'default_category',
		'default_post_format',
		'show_on_front',
		'page_on_front',
		'page_for_posts',
		'blog_public',
		'default_comment_status',
		'thread_comments',
		'thread_comments_depth',
		'comments_per_page',
		'stylesheet',
		'template',
		'sidebars_widgets',
		'widget_text',
		'widget_categories',
		'widget_archives',
		'widget_meta',
		'widget_search',
		'widget_recent-posts',
		'widget_recent-comments',
	];

	private const WRITABLE_OPTIONS = [
		'blogname',
		'blogdescription',
		'siteurl',
		'home',
		'admin_email',
		'posts_per_page',
		'date_format',
		'time_format',
		'timezone_string',
		'gmt_offset',
		'permalink_structure',
		'default_category',
		'default_post_format',
		'show_on_front',
		'page_on_front',
		'page_for_posts',
		'blog_public',
		'default_comment_status',
		'thread_comments',
		'thread_comments_depth',
		'comments_per_page',
		'stylesheet',
		'template',
	];

	/**
	 * Register all options tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_get_option',
			'Reads a WordPress option value by name. Only allows reading from a safe allowlist of options.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'name' => [
						'type'        => 'string',
						'description' => 'The option name to read (e.g. "blogname", "permalink_structure", "posts_per_page").',
					],
				],
				'required' => [ 'name' ],
			],
			[ $this, 'get_option' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_option',
			'Updates a WordPress option value. Only allows modifying a safe allowlist of options.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'name'  => [
						'type'        => 'string',
						'description' => 'The option name to update.',
					],
					'value' => [
						'type'        => 'string',
						'description' => 'The new value for the option. Pass numbers and booleans as strings (e.g. "10", "true").',
					],
				],
				'required' => [ 'name', 'value' ],
			],
			[ $this, 'update_option' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_options',
			'Lists non-sensitive WordPress options that can be read or modified via wp_get_option/wp_update_option, with their current values. Use wp_get_option for explicit reads of options omitted from bulk output.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_options' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_get_custom_css',
			'Reads WordPress Additional CSS for the active theme. Use this for persistent CSS source-of-truth inspection instead of browser-injected style tags.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'stylesheet' => [ 'type' => 'string', 'description' => 'Optional theme stylesheet slug. Defaults to the active stylesheet.' ],
				],
			],
			[ $this, 'get_custom_css' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_custom_css_revisions',
			'Lists revision metadata for the active theme Additional CSS post without returning full revision CSS.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'stylesheet'     => [ 'type' => 'string', 'description' => 'Expected active theme stylesheet slug from wp_get_custom_css.' ],
					'parent_post_id' => [ 'type' => 'integer', 'description' => 'Expected current Custom CSS post ID from wp_get_custom_css.' ],
				],
				'required'             => [ 'stylesheet', 'parent_post_id' ],
			],
			[ $this, 'list_custom_css_revisions' ],
			null,
			true,
			true
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_get_custom_css_revision',
			'Reads one Additional CSS revision after validating the active stylesheet and current Custom CSS parent post.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'stylesheet'     => [ 'type' => 'string', 'description' => 'Expected active theme stylesheet slug from wp_get_custom_css.' ],
					'parent_post_id' => [ 'type' => 'integer', 'description' => 'Expected current Custom CSS post ID from wp_get_custom_css.' ],
					'revision_id'    => [ 'type' => 'integer', 'description' => 'Selected revision ID from wp_list_custom_css_revisions.' ],
				],
				'required'             => [ 'stylesheet', 'parent_post_id', 'revision_id' ],
			],
			[ $this, 'get_custom_css_revision' ],
			null,
			true,
			true
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_restore_custom_css_revision',
			'Restores one plain Additional CSS revision after confirmation and best-effort current-state conflict detection. Never retry automatically after a lost response.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'stylesheet'              => [ 'type' => 'string', 'description' => 'Expected active theme stylesheet slug from wp_get_custom_css.' ],
					'parent_post_id'          => [ 'type' => 'integer', 'description' => 'Expected current Custom CSS post ID from wp_get_custom_css.' ],
					'revision_id'             => [ 'type' => 'integer', 'description' => 'Selected revision ID from wp_list_custom_css_revisions.' ],
					'expected_current_sha256' => [ 'type' => 'string', 'pattern' => '^[a-f0-9]{64}$', 'description' => 'Current persisted_css_sha256 from wp_get_custom_css. This is best-effort conflict detection, not an atomic lock.' ],
					'confirm'                 => [ 'type' => 'boolean', 'description' => 'Must be true after the user approves restoring persistent site CSS.' ],
				],
				'required'             => [ 'stylesheet', 'parent_post_id', 'revision_id', 'expected_current_sha256', 'confirm' ],
			],
			[ $this, 'restore_custom_css_revision' ],
			null,
			true,
			true
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_custom_css',
			'Updates WordPress Additional CSS for the active theme and returns before/after CSS. Use only after inspecting the current CSS; requires confirm=true because it changes site-wide persistent styling.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'css'        => [ 'type' => 'string', 'description' => 'Complete replacement Additional CSS contents for the active theme.' ],
					'stylesheet' => [ 'type' => 'string', 'description' => 'Optional theme stylesheet slug. If provided, it must match the active stylesheet.' ],
					'confirm'    => [ 'type' => 'boolean', 'description' => 'Must be true after the user approves changing persistent site CSS.' ],
				],
				'required'             => [ 'css', 'confirm' ],
			],
			[ $this, 'update_custom_css' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_theme_mods',
			'Lists active theme mods/customizer settings. Use this to inspect theme-rendered source state such as header images, page title options, and layout settings before choosing a mutation path.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_theme_mods' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_get_theme_mod',
			'Reads one active theme mod/customizer setting by name. Use this before changing theme-rendered elements.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'name' => [ 'type' => 'string', 'description' => 'Theme mod name to read.' ],
				],
				'required'             => [ 'name' ],
			],
			[ $this, 'get_theme_mod' ]
		) );
	}

	/**
	 * Check if an option is in the allowlist.
	 */
	private function is_readable( string $name ): bool {
		return in_array( $name, self::READABLE_OPTIONS, true );
	}

	/**
	 * Check if an option can be updated.
	 */
	private function is_writable( string $name ): bool {
		return in_array( $name, self::WRITABLE_OPTIONS, true );
	}

	/**
	 * wp_get_option handler.
	 */
	public function get_option( array $input ): array {
		$name = sanitize_key( $input['name'] ?? '' );

		if ( ! $this->is_readable( $name ) ) {
			throw new Frontman_Tool_Error( "Option not allowed: {$name}" );
		}

		$value = get_option( $name );

		return [
			'name'  => $name,
			'value' => $value,
		];
	}

	/**
	 * wp_update_option handler.
	 */
	public function update_option( array $input ): array {
		$name = sanitize_key( $input['name'] ?? '' );

		if ( ! $this->is_writable( $name ) ) {
			throw new Frontman_Tool_Error( "Option not allowed: {$name}" );
		}

		$value = $input['value'];
		$before = get_option( $name );

		if ( is_string( $value ) ) {
			$value = sanitize_text_field( $value );
		}

		$updated = update_option( $name, $value );

		return [
			'before'  => $before,
			'updated' => $updated,
			'name'    => $name,
			'value'   => get_option( $name ),
		];
	}

	/**
	 * wp_list_options handler.
	 */
	public function list_options( array $input ): array {
		$result = [];

		foreach ( array_diff( self::READABLE_OPTIONS, [ 'admin_email' ] ) as $name ) {
			$value = get_option( $name );
			if ( is_array( $value ) || is_object( $value ) ) {
				$value = '(complex value - use wp_get_option to read)';
			}
			$result[] = [
				'name'  => $name,
				'value' => $value,
			];
		}

		return $result;
	}

	/**
	 * wp_get_custom_css handler.
	 */
	public function get_custom_css( array $input ): array {
		if ( ! function_exists( 'wp_get_custom_css' ) || ! function_exists( 'wp_get_custom_css_post' ) ) {
			throw new Frontman_Tool_Error( 'WordPress custom CSS API is unavailable.' );
		}

		$stylesheet   = $this->stylesheet_from_input( $input, false );
		$post         = wp_get_custom_css_post( $stylesheet );
		if ( null !== $post ) {
			$this->assert_custom_css_post_scope( $post, $stylesheet );
		}
		$persisted_css = null === $post ? '' : (string) $post->post_content;

		return [
			'stylesheet'                  => $stylesheet,
			'css'                         => wp_get_custom_css( $stylesheet ),
			'parent_post_id'              => null === $post ? null : (int) $post->ID,
			'persisted_css_bytes'         => strlen( $persisted_css ),
			'persisted_css_sha256'        => hash( 'sha256', $persisted_css ),
			'post_modified_gmt'           => null === $post ? null : (string) $post->post_modified_gmt,
			'preprocessor_source_present' => null !== $post && '' !== (string) $post->post_content_filtered,
		];
	}

	/**
	 * wp_list_custom_css_revisions handler.
	 */
	public function list_custom_css_revisions( array $input ): array {
		if ( ! function_exists( 'wp_revisions_enabled' ) || ! function_exists( 'wp_get_post_revisions' ) ) {
			throw new Frontman_Tool_Error( 'WordPress revision API is unavailable.' );
		}

		[ $stylesheet, $post ] = $this->custom_css_post_from_expected_scope( $input, 'wp_list_custom_css_revisions' );
		$revisions_enabled = wp_revisions_enabled( $post );
		$revisions = wp_get_post_revisions( $post->ID, [ 'check_enabled' => false ] );

		return [
			'stylesheet'        => $stylesheet,
			'parent_post_id'    => (int) $post->ID,
			'status'            => ! $revisions_enabled ? 'revisions_disabled' : ( [] === $revisions ? 'no_revisions' : 'available' ),
			'revisions_enabled' => $revisions_enabled,
			'revisions'         => array_values( array_map( [ $this, 'custom_css_revision_metadata' ], $revisions ) ),
		];
	}

	/**
	 * wp_get_custom_css_revision handler.
	 */
	public function get_custom_css_revision( array $input ): array {
		[ $stylesheet, $post ] = $this->custom_css_post_from_expected_scope( $input, 'wp_get_custom_css_revision' );
		$revision = $this->custom_css_revision_from_input( $input, (int) $post->ID );
		$metadata = $this->custom_css_revision_metadata( $revision );

		return array_merge(
			[
				'stylesheet' => $stylesheet,
				'css'        => (string) $revision->post_content,
			],
			$metadata
		);
	}

	/**
	 * wp_restore_custom_css_revision handler.
	 */
	public function restore_custom_css_revision( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Additional CSS revision restore requires confirm=true after user approval.' );
		}
		if ( ! function_exists( 'wp_restore_post_revision' ) || ! function_exists( 'clean_post_cache' ) || ! function_exists( 'get_post' ) ) {
			throw new Frontman_Tool_Error( 'WordPress revision restore API is unavailable.' );
		}

		[ $stylesheet, $post ] = $this->custom_css_post_from_expected_scope( $input, 'wp_restore_custom_css_revision' );
		$revision = $this->custom_css_revision_from_input( $input, (int) $post->ID );
		$before = $this->custom_css_post_metadata( $post );
		$expected_hash = $input['expected_current_sha256'] ?? null;
		if ( ! is_string( $expected_hash ) || 1 !== preg_match( '/\A[a-f0-9]{64}\z/', $expected_hash ) ) {
			throw new Frontman_Tool_Error( 'expected_current_sha256 must be a lowercase SHA-256 fingerprint.' );
		}
		if ( $expected_hash !== $before['persisted_css_sha256'] ) {
			throw new Frontman_Tool_Error( 'Current Additional CSS changed after inspection. Read current state again before restoring.' );
		}
		if ( $before['preprocessor_source_present'] ) {
			throw new Frontman_Tool_Error( 'Custom CSS revision restore does not support preprocessor-backed CSS.' );
		}

		$restored_parent_id = wp_restore_post_revision( $revision, [ 'post_content' ] );
		if ( (int) $post->ID !== $restored_parent_id ) {
			throw new Frontman_Tool_Error( 'Custom CSS restoration outcome is ambiguous. Read current state and do not retry automatically.' );
		}

		clean_post_cache( $post->ID );
		$observed_post = get_post( $post->ID );
		if ( null === $observed_post || (int) $post->ID !== (int) $observed_post->ID ) {
			throw new Frontman_Tool_Error( 'Custom CSS restoration could not be verified. Read current state and do not retry automatically.' );
		}
		if ( ! $this->is_custom_css_post_in_scope( $observed_post, $stylesheet ) ) {
			throw new Frontman_Tool_Error( 'Custom CSS restoration scope is ambiguous. Read current state and do not retry automatically.' );
		}
		$after = $this->custom_css_post_metadata( $observed_post );
		if ( $after['preprocessor_source_present'] ) {
			throw new Frontman_Tool_Error( 'Custom CSS restoration produced unsupported preprocessor state. Read current state and do not retry automatically.' );
		}

		return [
			'selected_revision_id' => (int) $revision->ID,
			'before'               => $before,
			'after'                => $after,
		];
	}

	/**
	 * wp_update_custom_css handler.
	 */
	public function update_custom_css( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Additional CSS update requires confirm=true after user approval.' );
		}
		if ( ! function_exists( 'wp_update_custom_css_post' ) || ! function_exists( 'wp_get_custom_css' ) ) {
			throw new Frontman_Tool_Error( 'WordPress custom CSS API is unavailable.' );
		}

		if ( ! array_key_exists( 'css', $input ) || ! is_string( $input['css'] ) ) {
			throw new Frontman_Tool_Error( 'css is required and must be a string.' );
		}

		$stylesheet = $this->stylesheet_from_input( $input, true );
		$before     = wp_get_custom_css( $stylesheet );
		$css        = $input['css'];
		$post       = wp_update_custom_css_post( $css, [ 'stylesheet' => $stylesheet ] );

		if ( function_exists( 'is_wp_error' ) && is_wp_error( $post ) ) {
			throw new Frontman_Tool_Error( $post->get_error_message() );
		}

		return [
			'updated'    => true,
			'stylesheet' => $stylesheet,
			'before'     => $before,
			'after'      => wp_get_custom_css( $stylesheet ),
		];
	}

	/**
	 * wp_list_theme_mods handler.
	 */
	public function list_theme_mods( array $input ): array {
		if ( ! function_exists( 'get_theme_mods' ) ) {
			throw new Frontman_Tool_Error( 'WordPress theme mod API is unavailable.' );
		}

		$mods = get_theme_mods();

		return [
			'stylesheet' => $this->active_stylesheet(),
			'mods'       => is_array( $mods ) ? $mods : [],
		];
	}

	/**
	 * wp_get_theme_mod handler.
	 */
	public function get_theme_mod( array $input ): array {
		if ( ! function_exists( 'get_theme_mod' ) ) {
			throw new Frontman_Tool_Error( 'WordPress theme mod API is unavailable.' );
		}

		$name = $input['name'] ?? '';
		if ( ! is_string( $name ) ) {
			throw new Frontman_Tool_Error( 'name is required.' );
		}
		if ( '' === $name ) {
			throw new Frontman_Tool_Error( 'name is required.' );
		}
		if ( $this->has_control_or_path_separator( $name ) ) {
			throw new Frontman_Tool_Error( 'name contains invalid characters.' );
		}

		return [
			'name'       => $name,
			'stylesheet' => $this->active_stylesheet(),
			'value'      => get_theme_mod( $name, null ),
		];
	}

	private function stylesheet_from_input( array $input, bool $active_only, string $tool_name = 'wp_update_custom_css' ): string {
		$stylesheet = array_key_exists( 'stylesheet', $input ) ? $input['stylesheet'] : $this->active_stylesheet();
		if ( ! is_string( $stylesheet ) ) {
			throw new Frontman_Tool_Error( 'stylesheet must be a string.' );
		}
		if ( '' === $stylesheet ) {
			throw new Frontman_Tool_Error( 'stylesheet could not be determined.' );
		}
		if ( $this->has_control_or_path_separator( $stylesheet ) ) {
			throw new Frontman_Tool_Error( 'stylesheet contains invalid characters.' );
		}

		$active_stylesheet = $this->active_stylesheet();
		if ( $active_only && $stylesheet !== $active_stylesheet ) {
			throw new Frontman_Tool_Error( "{$tool_name} only accesses Additional CSS for the active stylesheet." );
		}
		if ( function_exists( 'wp_get_theme' ) ) {
			$theme = wp_get_theme( $stylesheet );
			if ( method_exists( $theme, 'exists' ) && ! $theme->exists() ) {
				throw new Frontman_Tool_Error( "Theme stylesheet not found: {$stylesheet}" );
			}
		}

		return $stylesheet;
	}

	private function custom_css_post_from_expected_scope( array $input, string $tool_name ): array {
		if ( ! function_exists( 'wp_get_custom_css_post' ) ) {
			throw new Frontman_Tool_Error( 'WordPress custom CSS API is unavailable.' );
		}
		if ( ! array_key_exists( 'stylesheet', $input ) ) {
			throw new Frontman_Tool_Error( 'stylesheet is required.' );
		}

		$stylesheet = $this->stylesheet_from_input( $input, true, $tool_name );
		if ( ! array_key_exists( 'parent_post_id', $input ) || ! is_int( $input['parent_post_id'] ) || 1 > $input['parent_post_id'] ) {
			throw new Frontman_Tool_Error( 'parent_post_id is required and must be a positive integer.' );
		}

		$post = wp_get_custom_css_post( $stylesheet );
		if ( null === $post ) {
			throw new Frontman_Tool_Error( 'Current Custom CSS parent post was not found.' );
		}
		$this->assert_custom_css_post_scope( $post, $stylesheet );
		if ( $input['parent_post_id'] !== (int) $post->ID ) {
			throw new Frontman_Tool_Error( 'Current Custom CSS parent post does not match parent_post_id.' );
		}

		return [ $stylesheet, $post ];
	}

	private function assert_custom_css_post_scope( $post, string $stylesheet ): void {
		if ( ! $this->is_custom_css_post_in_scope( $post, $stylesheet ) ) {
			throw new Frontman_Tool_Error( 'Custom CSS lookup returned an invalid post for the expected stylesheet.' );
		}
	}

	private function is_custom_css_post_in_scope( $post, string $stylesheet ): bool {
		return 'custom_css' === (string) $post->post_type && sanitize_title( $stylesheet ) === (string) $post->post_name;
	}

	private function custom_css_revision_from_input( array $input, int $parent_post_id ) {
		if ( ! function_exists( 'wp_get_post_revision' ) || ! function_exists( 'wp_is_post_revision' ) ) {
			throw new Frontman_Tool_Error( 'WordPress revision API is unavailable.' );
		}
		if ( ! array_key_exists( 'revision_id', $input ) || ! is_int( $input['revision_id'] ) || 1 > $input['revision_id'] ) {
			throw new Frontman_Tool_Error( 'revision_id is required and must be a positive integer.' );
		}

		$revision = wp_get_post_revision( $input['revision_id'] );
		if ( null === $revision ) {
			throw new Frontman_Tool_Error( 'Custom CSS revision not found.' );
		}
		if ( $parent_post_id !== (int) wp_is_post_revision( $revision ) ) {
			throw new Frontman_Tool_Error( 'Selected revision does not belong to the expected Custom CSS parent post.' );
		}

		return $revision;
	}

	private function custom_css_revision_metadata( $revision ): array {
		$css = (string) $revision->post_content;

		return [
			'revision_id'   => (int) $revision->ID,
			'parent_post_id' => (int) $revision->post_parent,
			'post_date'      => (string) $revision->post_date,
			'post_date_gmt'  => (string) $revision->post_date_gmt,
			'css_bytes'      => strlen( $css ),
			'css_sha256'     => hash( 'sha256', $css ),
		];
	}

	private function custom_css_post_metadata( $post ): array {
		$css = (string) $post->post_content;

		return [
			'persisted_css_bytes'         => strlen( $css ),
			'persisted_css_sha256'        => hash( 'sha256', $css ),
			'post_modified_gmt'           => (string) $post->post_modified_gmt,
			'preprocessor_source_present' => '' !== (string) $post->post_content_filtered,
		];
	}

	private function active_stylesheet(): string {
		if ( function_exists( 'get_stylesheet' ) ) {
			return (string) get_stylesheet();
		}

		return (string) get_option( 'stylesheet', '' );
	}

	private function has_control_or_path_separator( string $value ): bool {
		return 1 === preg_match( '/[[:cntrl:]\/\\\\]/', $value );
	}
}
