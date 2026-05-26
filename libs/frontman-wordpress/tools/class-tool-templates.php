<?php
/**
 * WordPress Template tools — site info and template listing.
 *
 * Tools: wp_get_site_info, wp_list_templates, wp_read_template, wp_update_template
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Templates {
	/**
	 * Register all template tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_get_site_info',
			'Returns comprehensive site information including WordPress version, active theme, active plugins, registered post types, and taxonomies.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'get_site_info' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_templates',
			'Lists available block templates or template parts in the active theme.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'type' => [
						'type'        => 'string',
						'description' => 'The template type to list.',
						'enum'        => [ 'wp_template', 'wp_template_part' ],
						'default'     => 'wp_template',
					],
				],
			],
			[ $this, 'list_templates' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_template',
			'Reads the full content and metadata for a template or template part by slug.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'slug' => [ 'type' => 'string', 'description' => 'The template or template part slug.' ],
					'type' => [
						'type'        => 'string',
						'enum'        => [ 'wp_template', 'wp_template_part' ],
						'default'     => 'wp_template',
						'description' => 'The template type to read.',
					],
				],
				'required' => [ 'slug' ],
			],
			[ $this, 'read_template' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_template',
			'Updates the content of a template or template part. Reads the current version first and returns before/after snapshots.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'slug'    => [ 'type' => 'string', 'description' => 'The template or template part slug.' ],
					'type'    => [
						'type'        => 'string',
						'enum'        => [ 'wp_template', 'wp_template_part' ],
						'default'     => 'wp_template',
						'description' => 'The template type to update.',
					],
					'content' => [ 'type' => 'string', 'description' => 'The new template markup.' ],
					'title'   => [ 'type' => 'string', 'description' => 'Optional updated human-readable title.' ],
				],
				'required' => [ 'slug', 'content' ],
			],
			[ $this, 'update_template' ]
		) );
	}

	private function find_template( string $slug, string $type ) {
		foreach ( get_block_templates( [], $type ) as $template ) {
			if ( $template->slug === $slug || $template->id === $slug ) {
				return $template;
			}
		}

		return null;
	}

	private function serialize_template( $template ): array {
		return [
			'id'          => $template->id,
			'slug'        => $template->slug,
			'title'       => $template->title ?? $template->slug,
			'description' => $template->description ?? '',
			'type'        => $template->type,
			'source'      => $template->source,
			'content'     => $template->content ?? '',
			'wp_id'       => isset( $template->wp_id ) ? (int) $template->wp_id : null,
		];
	}

	/**
	 * Get active plugin filesystem paths using WordPress' validated plugin list.
	 */
	private function get_active_plugin_paths(): array {
		$plugin_paths = [];

		if ( function_exists( 'wp_get_active_and_valid_plugins' ) ) {
			$plugin_paths = array_merge( $plugin_paths, wp_get_active_and_valid_plugins() );
		}

		if ( function_exists( 'wp_get_active_network_plugins' ) ) {
			$plugin_paths = array_merge( $plugin_paths, wp_get_active_network_plugins() );
		}

		return array_values( array_unique( array_filter( $plugin_paths, 'is_string' ) ) );
	}

	private function get_active_plugin_info( string $plugin_path ): array {
		$plugin_file = function_exists( 'plugin_basename' ) ? plugin_basename( $plugin_path ) : basename( $plugin_path );
		$data        = function_exists( 'get_file_data' )
			? get_file_data(
				$plugin_path,
				[
					'Name'    => 'Plugin Name',
					'Version' => 'Version',
				],
				'plugin'
			)
			: [];

		return [
			'name'    => sanitize_text_field( $data['Name'] ?? $plugin_file ),
			'version' => sanitize_text_field( $data['Version'] ?? 'unknown' ),
		];
	}

	/**
	 * wp_get_site_info handler.
	 */
	public function get_site_info( array $input ): array {
		$theme = wp_get_theme();

		// Get plugin names from WordPress' validated active plugin paths.
		$plugin_info = [];
		foreach ( $this->get_active_plugin_paths() as $plugin_path ) {
			$plugin_info[] = $this->get_active_plugin_info( $plugin_path );
		}

		// Get post types.
		$post_types = get_post_types( [ 'public' => true ], 'objects' );
		$pt_list    = [];
		foreach ( $post_types as $pt ) {
			$pt_list[] = [
				'name'  => $pt->name,
				'label' => $pt->label,
				'count' => (int) wp_count_posts( $pt->name )->publish,
			];
		}

		// Get taxonomies.
		$taxonomies = get_taxonomies( [ 'public' => true ], 'objects' );
		$tax_list   = [];
		foreach ( $taxonomies as $tax ) {
			$tax_list[] = [
				'name'  => $tax->name,
				'label' => $tax->label,
			];
		}

		return [
			'site_name'    => get_bloginfo( 'name' ),
			'site_url'     => get_site_url(),
			'home_url'     => get_home_url(),
			'wp_version'   => get_bloginfo( 'version' ),
			'php_version'  => phpversion(),
			'theme'        => [
				'name'       => $theme->get( 'Name' ),
				'version'    => $theme->get( 'Version' ),
				'is_block'   => $theme->is_block_theme(),
				'template'   => $theme->get_template(),
				'stylesheet' => $theme->get_stylesheet(),
			],
			'plugins'      => $plugin_info,
			'post_types'   => $pt_list,
			'taxonomies'   => $tax_list,
			'is_multisite' => is_multisite(),
			'language'     => get_bloginfo( 'language' ),
		];
	}

	/**
	 * wp_list_templates handler.
	 */
	public function list_templates( array $input ): array {
		$type = sanitize_key( $input['type'] ?? 'wp_template' );

		if ( ! in_array( $type, [ 'wp_template', 'wp_template_part' ], true ) ) {
			throw new Frontman_Tool_Error( "Invalid template type: {$type}" );
		}

		$templates = get_block_templates( [], $type );
		$result    = [];

		foreach ( $templates as $template ) {
			$result[] = [
				'id'          => $template->id,
				'slug'        => $template->slug,
				'title'       => $template->title ?? $template->slug,
				'description' => $template->description ?? '',
				'type'        => $template->type,
				'source'      => $template->source,
				'has_content' => ! empty( $template->content ),
			];
		}

		return [
			'type'      => $type,
			'count'     => count( $result ),
			'templates' => $result,
		];
	}

	/**
	 * wp_read_template handler.
	 */
	public function read_template( array $input ): array {
		$type     = sanitize_key( $input['type'] ?? 'wp_template' );
		$slug     = sanitize_title( $input['slug'] ?? '' );
		$template = $this->find_template( $slug, $type );

		if ( ! $template ) {
			throw new Frontman_Tool_Error( "Template not found: {$slug}" );
		}

		return $this->serialize_template( $template );
	}

	/**
	 * wp_update_template handler.
	 */
	public function update_template( array $input ): array {
		$type     = sanitize_key( $input['type'] ?? 'wp_template' );
		$slug     = sanitize_title( $input['slug'] ?? '' );
		$content  = (string) ( $input['content'] ?? '' );
		$template = $this->find_template( $slug, $type );

		if ( ! $template ) {
			throw new Frontman_Tool_Error( "Template not found: {$slug}" );
		}

		$before = $this->serialize_template( $template );
		$post_data = [
			'post_type'    => $type,
			'post_status'  => 'publish',
			'post_name'    => $template->slug,
			'post_title'   => sanitize_text_field( $input['title'] ?? ( $template->title ?? $template->slug ) ),
			'post_content' => $content,
		];

		if ( ! empty( $template->wp_id ) ) {
			$post_data['ID'] = (int) $template->wp_id;
		}

		$post_id = wp_insert_post( wp_slash( $post_data ), true );
		if ( is_wp_error( $post_id ) ) {
			throw new Frontman_Tool_Error( $post_id->get_error_message() );
		}

		if ( function_exists( 'wp_set_post_terms' ) ) {
			wp_set_post_terms( $post_id, [ get_stylesheet() ], 'wp_theme' );
		}

		$after_template = $this->find_template( $slug, $type );
		if ( ! $after_template ) {
			throw new Frontman_Tool_Error( 'Template was updated but could not be read back.' );
		}

		return [
			'updated' => true,
			'before'  => $before,
			'after'   => $this->serialize_template( $after_template ),
		];
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
