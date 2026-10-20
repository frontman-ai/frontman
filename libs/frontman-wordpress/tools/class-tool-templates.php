<?php
/**
 * WordPress Template tools — site info and template listing.
 *
 * Tools: wp_get_site_info, wp_list_templates, wp_read_template, wp_create_template, wp_update_template
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}


class Frontman_Tool_Templates {
	/**
	 * Register all template tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_get_site_info',
			'Returns comprehensive site information including WordPress version, active theme, active plugins, registered public post types with archive URLs and rewrite settings, and taxonomies. CPT archives are generated routes, not backing pages/posts.',
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
			'wp_create_template',
			'Creates a new block template or part linked to the active theme. Never overwrites existing templates, including theme files. Use wp_update_template for existing slugs.',
			[
				'type' => 'object',
				'additionalProperties' => false,
				'properties' => [
					'slug' => [ 'type' => 'string', 'description' => 'Canonical template slug (no theme prefix).' ],
					'type' => [ 'type' => 'string', 'enum' => [ 'wp_template', 'wp_template_part' ] ],
					'title' => [ 'type' => 'string', 'description' => 'Human-readable title.' ],
					'content' => [ 'type' => 'string', 'description' => 'Block markup.' ],
					'area' => [ 'type' => 'string', 'enum' => [ 'header', 'footer', 'uncategorized' ], 'description' => 'Parts only; defaults to uncategorized.' ],
				],
				'required' => [ 'slug', 'type', 'title', 'content' ],
			],
			[ $this, 'create_template' ]
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
			'theme'       => $template->theme ?? null,
			'area'        => $template->area ?? null,
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

		$plugin_info = [];
		foreach ( $this->get_active_plugin_paths() as $plugin_path ) {
			$plugin_info[] = $this->get_active_plugin_info( $plugin_path );
		}

		$post_types = get_post_types( [ 'public' => true ], 'objects' );
		$pt_list    = [];
		foreach ( $post_types as $pt ) {
			$pt_list[] = [
				'name'               => $pt->name,
				'label'              => $pt->label,
				'count'              => (int) wp_count_posts( $pt->name )->publish,
				'has_archive'        => $pt->has_archive,
				'archive_url'        => get_post_type_archive_link( $pt->name ) ?: null,
				'rewrite'            => $pt->rewrite,
				'publicly_queryable' => $pt->publicly_queryable,
			];
		}

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
			'seo_unavailable_reason' => Frontman_Tool_Seo::unavailable_reason(),
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

	/** Validate raw arguments before registry coercion and direct handler writes. */
	public static function validate_create_input( array $input ): void {
		foreach ( [ 'slug', 'type', 'title', 'content' ] as $field ) {
			if ( ! array_key_exists( $field, $input ) || ! is_string( $input[ $field ] ) ) {
				throw new Frontman_Tool_Error( "{$field} is required and must be a string." );
			}
		}
		if ( '' === $input['slug'] || strlen( $input['slug'] ) > 200 || sanitize_title( $input['slug'] ) !== $input['slug'] ) {
			throw new Frontman_Tool_Error( 'slug must be a nonempty canonical WordPress slug of at most 200 bytes.' );
		}
		if ( ! in_array( $input['type'], [ 'wp_template', 'wp_template_part' ], true ) ) {
			throw new Frontman_Tool_Error( 'type must be wp_template or wp_template_part.' );
		}
		if ( '' === trim( $input['title'] ) || sanitize_text_field( $input['title'] ) !== $input['title'] ) {
			throw new Frontman_Tool_Error( 'title must be nonempty plain text.' );
		}
		if ( array_key_exists( 'area', $input ) && ( 'wp_template_part' !== $input['type'] || ! in_array( $input['area'], [ 'header', 'footer', 'uncategorized' ], true ) ) ) {
			throw new Frontman_Tool_Error( 'area is only supported for parts and must be header, footer, or uncategorized.' );
		}
	}

	public function create_template( array $input ): array {
		self::validate_create_input( $input );
		if ( ! current_user_can( 'edit_theme_options' ) ) {
			throw new Frontman_Tool_Error( 'Creating templates requires edit_theme_options.' );
		}
		if ( $this->find_template( $input['slug'], $input['type'] ) ) {
			throw new Frontman_Tool_Error( 'Template already exists; use wp_update_template.' );
		}
		$existing = get_posts( [
			'post_type' => $input['type'],
			'post_status' => array_values( array_diff( get_post_stati(), [ 'trash' ] ) ),
			'name' => $input['slug'],
			'fields' => 'ids',
			'numberposts' => 1,
			'tax_query' => [ [ 'taxonomy' => 'wp_theme', 'field' => 'name', 'terms' => get_stylesheet() ] ],
		] );
		if ( $existing ) {
			throw new Frontman_Tool_Error( 'A template post with this slug already exists in the active theme. Inspect or edit the existing post in WordPress before proceeding.' );
		}
		$after = $this->save_template( [
			'post_type' => $input['type'],
			'post_status' => 'publish',
			'post_name' => $input['slug'],
			'post_title' => $input['title'],
			'post_content' => $input['content'],
		], $input['slug'], $input['type'], 'wp_template_part' === $input['type'] ? ( $input['area'] ?? 'uncategorized' ) : null );
		return [ 'created' => true, 'after' => $after ];
	}

	/** Shared native save -> explicit theme/area terms -> verified discovery path. */
	private function save_template( array $post_data, string $slug, string $type, ?string $area ): array {
		$theme = get_stylesheet();
		$post_id = wp_insert_post( wp_slash( $post_data ), true );
		if ( is_wp_error( $post_id ) ) {
			throw new Frontman_Tool_Error( $post_id->get_error_message() );
		}
		try {
			$terms = wp_set_post_terms( $post_id, [ $theme ], 'wp_theme' );
			if ( is_wp_error( $terms ) ) {
				throw new Frontman_Tool_Error( 'theme assignment failed: ' . $terms->get_error_message() );
			}
			if ( null !== $area ) {
				$terms = wp_set_post_terms( $post_id, [ $area ], 'wp_template_part_area' );
				if ( is_wp_error( $terms ) ) {
					throw new Frontman_Tool_Error( 'area assignment failed: ' . $terms->get_error_message() );
				}
			}
			$after = $this->find_template( $slug, $type );
			if ( ! $after || (int) ( $after->wp_id ?? 0 ) !== (int) $post_id ) {
				throw new Frontman_Tool_Error( 'could not be read back as the active template' );
			}
			if ( $after->content !== $post_data['post_content'] ) {
				throw new Frontman_Tool_Error( 'its observed content differs from the requested content' );
			}
			if ( $after->id !== $theme . '//' . $slug || $after->slug !== $slug || $after->type !== $type || ( $after->theme ?? null ) !== $theme || $after->title !== $post_data['post_title'] || ( null !== $area && ( $after->area ?? null ) !== $area ) ) {
				throw new Frontman_Tool_Error( 'observed template identity, theme, title or area differs from the request' );
			}
			return $this->serialize_template( $after );
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( "Template post {$post_id} was saved but " . $e->getMessage() . ". Partial writes may remain; no rollback was performed. Read the template before retrying. If discovery failed, use wp_read_post with id {$post_id} for raw recovery.", 0, $e );
		}
	}

	/**
	 * wp_update_template handler.
	 */
	public function update_template( array $input ): array {
		if ( ! current_user_can( 'edit_theme_options' ) ) {
			throw new Frontman_Tool_Error( 'Updating templates requires edit_theme_options.' );
		}
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

		$after = $this->save_template( $post_data, $slug, $type, 'wp_template_part' === $type ? ( $template->area ?? 'uncategorized' ) : null );

		return [
			'updated' => true,
			'before'  => $before,
			'after'   => $after,
		];
	}
}
