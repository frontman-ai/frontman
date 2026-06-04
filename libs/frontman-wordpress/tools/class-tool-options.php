<?php
/**
 * WordPress Options tools — read and modify site options.
 *
 * Tools: wp_get_option, wp_update_option, wp_list_options,
 * wp_get_custom_css, wp_update_custom_css, wp_list_theme_mods, wp_get_theme_mod
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

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
		// Complex widget/sidebar state can be inspected but should not be
		// overwritten through a plain string-valued generic option editor.
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
			'Lists all WordPress options that can be read or modified via wp_get_option/wp_update_option, with their current values.',
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

		// Intentionally limited to WordPress core options in WRITABLE_OPTIONS.
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

		foreach ( self::READABLE_OPTIONS as $name ) {
			$value = get_option( $name );
			// Skip complex/serialized values for readability.
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
		if ( ! function_exists( 'wp_get_custom_css' ) ) {
			throw new Frontman_Tool_Error( 'WordPress custom CSS API is unavailable.' );
		}

		$stylesheet = $this->stylesheet_from_input( $input, false );

		return [
			'stylesheet' => $stylesheet,
			'css'        => wp_get_custom_css( $stylesheet ),
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

	private function stylesheet_from_input( array $input, bool $active_only ): string {
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
			throw new Frontman_Tool_Error( 'wp_update_custom_css only updates Additional CSS for the active stylesheet.' );
		}
		if ( function_exists( 'wp_get_theme' ) ) {
			$theme = wp_get_theme( $stylesheet );
			if ( method_exists( $theme, 'exists' ) && ! $theme->exists() ) {
				throw new Frontman_Tool_Error( "Theme stylesheet not found: {$stylesheet}" );
			}
		}

		return $stylesheet;
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

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
