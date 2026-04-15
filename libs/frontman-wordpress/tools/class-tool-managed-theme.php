<?php
/**
 * Frontman-managed child theme tools.
 *
 * Tools: wp_get_managed_theme_status, wp_create_managed_theme,
 * wp_activate_managed_theme, wp_list_managed_theme_files,
 * wp_read_managed_theme_file, wp_write_managed_theme_file,
 * wp_fork_parent_theme_file
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Managed_Theme {
	/**
	 * Register all managed-theme tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_get_managed_theme_status',
			'Returns the current Frontman-managed child theme status, including whether it exists and whether it is active.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'get_status' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_managed_theme',
			'Creates a Frontman-managed child theme for the current block theme. This is the only theme file area that Frontman can mutate directly.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'create_theme' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_activate_managed_theme',
			'Activates the Frontman-managed child theme. Ask the user for confirmation first and only call this tool with confirm=true after they approve the theme switch.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'confirm' => [
						'type'        => 'boolean',
						'description' => 'Must be true only after the user explicitly confirms switching to the Frontman-managed child theme.',
					],
				],
				'required' => [ 'confirm' ],
			],
			[ $this, 'activate_theme' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_managed_theme_files',
			'Lists the Frontman-tracked files inside the managed child theme, including whether each file is writable.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_files' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_managed_theme_file',
			'Reads a Frontman-tracked file from the managed child theme.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'path' => [
						'type'        => 'string',
						'description' => 'The relative path to a Frontman-tracked file inside the managed child theme.',
					],
				],
				'required' => [ 'path' ],
			],
			[ $this, 'read_file' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_write_managed_theme_file',
			'Creates or updates a CSS, JSON, or HTML file inside the Frontman-managed child theme. Existing unmanaged files cannot be overwritten.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'path'    => [
						'type'        => 'string',
						'description' => 'The relative path inside the Frontman-managed child theme.',
					],
					'content' => [
						'type'        => 'string',
						'description' => 'The full file contents to write.',
					],
				],
				'required' => [ 'path', 'content' ],
			],
			[ $this, 'write_file' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_fork_parent_theme_file',
			'Copies a CSS, JSON, or HTML file from the managed theme\'s recorded parent theme into the Frontman-managed child theme so Frontman can safely edit the copy.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'path' => [
						'type'        => 'string',
						'description' => 'The relative path to copy from the parent theme into the Frontman-managed child theme.',
					],
				],
				'required' => [ 'path' ],
			],
			[ $this, 'fork_parent_file' ]
		) );
	}

	/**
	 * wp_get_managed_theme_status handler.
	 */
	public function get_status( array $input ): array {
		return Frontman_Managed_Theme::status();
	}

	/**
	 * wp_create_managed_theme handler.
	 */
	public function create_theme( array $input ): array {
		return Frontman_Managed_Theme::create();
	}

	/**
	 * wp_activate_managed_theme handler.
	 */
	public function activate_theme( array $input ): array {
		return Frontman_Managed_Theme::activate( true === ( $input['confirm'] ?? false ) );
	}

	/**
	 * wp_list_managed_theme_files handler.
	 */
	public function list_files( array $input ): array {
		return Frontman_Managed_Theme::list_files();
	}

	/**
	 * wp_read_managed_theme_file handler.
	 */
	public function read_file( array $input ): array {
		return Frontman_Managed_Theme::read_file( $this->string_input( $input, 'path' ) );
	}

	/**
	 * wp_write_managed_theme_file handler.
	 */
	public function write_file( array $input ): array {
		return Frontman_Managed_Theme::write_file(
			$this->string_input( $input, 'path' ),
			$this->string_input( $input, 'content' )
		);
	}

	/**
	 * wp_fork_parent_theme_file handler.
	 */
	public function fork_parent_file( array $input ): array {
		return Frontman_Managed_Theme::fork_parent_file( $this->string_input( $input, 'path' ) );
	}

	/**
	 * Require a string input field.
	 */
	private function string_input( array $input, string $key ): string {
		if ( ! array_key_exists( $key, $input ) || ! is_string( $input[ $key ] ) ) {
			throw new Frontman_Tool_Error( 'Expected `' . $key . '` to be a string.' );
		}

		return $input[ $key ];
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
