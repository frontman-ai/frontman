<?php
/**
 * WordPress Post tools — CRUD operations on posts/pages/CPTs.
 *
 * Tools: wp_list_posts, wp_read_post, wp_create_post, wp_duplicate_post, wp_update_post, wp_delete_post
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 * The registry (Frontman_Tools::call) wraps results into MCP format with _meta.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Posts {
	/**
	 * Register all post tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_posts',
			'Lists posts, pages, or custom post types with pagination and filtering.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_type' => [
						'type'        => 'string',
						'description' => 'Post type slug. Use "page" for pages, or any registered CPT slug.',
						'default'     => 'post',
					],
					'status'    => [
						'type'        => 'string',
						'description' => 'Filter by post status.',
						'enum'        => [ 'publish', 'draft', 'pending', 'private', 'trash', 'any' ],
						'default'     => 'publish',
					],
					'per_page'  => [
						'type'        => 'integer',
						'description' => 'Number of results per page (max 100).',
						'default'     => 20,
					],
					'page'      => [
						'type'        => 'integer',
						'description' => 'Page number for pagination.',
						'default'     => 1,
					],
					'search'    => [
						'type'        => 'string',
						'description' => 'Search query string to filter posts by keyword.',
					],
					'orderby'   => [
						'type'        => 'string',
						'description' => 'Field to sort results by.',
						'enum'        => [ 'date', 'title', 'modified', 'ID' ],
						'default'     => 'date',
					],
					'order'     => [
						'type'        => 'string',
						'description' => 'Sort direction.',
						'enum'        => [ 'ASC', 'DESC' ],
						'default'     => 'DESC',
					],
				],
			],
			[ $this, 'list_posts' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_post',
			'Reads a single post or page by ID, including its full content, metadata, and block markup.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id' => [
						'type'        => 'integer',
						'description' => 'The post ID to read.',
					],
				],
				'required' => [ 'id' ],
			],
			[ $this, 'read_post' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_post',
			'Creates a new post or page. Returns the new post ID and permalink. Use wp_duplicate_post when the user asks to duplicate or clone an existing page so Elementor/post metadata is copied.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'title'     => [
						'type'        => 'string',
						'description' => 'The post title.',
					],
					'content'   => [
						'type'        => 'string',
						'description' => 'The post content as HTML or Gutenberg block markup.',
					],
					'post_type' => [
						'type'        => 'string',
						'description' => 'Post type slug.',
						'default'     => 'post',
					],
					'status'    => [
						'type'        => 'string',
						'description' => 'Initial post status.',
						'enum'        => [ 'draft', 'publish', 'pending', 'private' ],
						'default'     => 'draft',
					],
				],
				'required' => [ 'title', 'content' ],
			],
			[ $this, 'create_post' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_duplicate_post',
			'Duplicates an existing post or page as a draft, copying content and Elementor/page metadata. Use this instead of wp_create_post when cloning a page.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'source_id' => [
						'type'        => 'integer',
						'description' => 'The post/page ID to duplicate.',
					],
					'title'     => [
						'type'        => 'string',
						'description' => 'Optional title for the duplicated post. Defaults to "{source title} Copy".',
					],
				],
				'required' => [ 'source_id' ],
			],
			[ $this, 'duplicate_post' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_post',
			'Updates an existing post or page. Only the fields you provide will be changed.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id'      => [
						'type'        => 'integer',
						'description' => 'The post ID to update.',
					],
					'title'   => [
						'type'        => 'string',
						'description' => 'New post title.',
					],
					'content' => [
						'type'        => 'string',
						'description' => 'New post content as HTML or block markup.',
					],
					'status'  => [
						'type'        => 'string',
						'description' => 'New post status.',
						'enum'        => [ 'draft', 'publish', 'pending', 'private', 'trash' ],
					],
					'excerpt' => [
						'type'        => 'string',
						'description' => 'New post excerpt.',
					],
				],
				'required' => [ 'id' ],
			],
			[ $this, 'update_post' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_delete_post',
			'Deletes a post or page. Ask the user for confirmation first and only call this tool with confirm=true after they approve. By default moves to trash; set force=true to permanently delete.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id'    => [
						'type'        => 'integer',
						'description' => 'The post ID to delete.',
					],
					'force' => [
						'type'        => 'boolean',
						'description' => 'If true, permanently delete instead of moving to trash.',
						'default'     => false,
					],
					'confirm' => [
						'type'        => 'boolean',
						'description' => 'Must be true only after the user explicitly confirms deletion.',
					],
				],
				'required' => [ 'id', 'confirm' ],
			],
			[ $this, 'delete_post' ]
		) );
	}

	/**
	 * wp_list_posts handler.
	 */
	public function list_posts( array $input ): array {
		$args = [
			'post_type'      => sanitize_key( $input['post_type'] ?? 'post' ),
			'post_status'    => sanitize_key( $input['status'] ?? 'publish' ),
			'posts_per_page' => min( absint( $input['per_page'] ?? 20 ), 100 ),
			'paged'          => max( absint( $input['page'] ?? 1 ), 1 ),
			'orderby'        => sanitize_key( $input['orderby'] ?? 'date' ),
			'order'          => strtoupper( sanitize_key( $input['order'] ?? 'DESC' ) ),
		];

		if ( ! empty( $input['search'] ) ) {
			$args['s'] = sanitize_text_field( $input['search'] );
		}

		$query = new \WP_Query( $args );
		$posts = [];

		foreach ( $query->posts as $post ) {
			$posts[] = [
				'id'       => $post->ID,
				'title'    => $post->post_title,
				'status'   => $post->post_status,
				'type'     => $post->post_type,
				'date'     => $post->post_date,
				'modified' => $post->post_modified,
				'excerpt'  => wp_trim_words( $post->post_content, 30 ),
			];
		}

		return [
			'posts'       => $posts,
			'total'       => $query->found_posts,
			'total_pages' => $query->max_num_pages,
			'page'        => $args['paged'],
		];
	}

	/**
	 * wp_read_post handler.
	 */
	public function read_post( array $input ): array {
		$id   = absint( $input['id'] ?? 0 );
		$post = get_post( $id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$id}" );
		}

		return [
			'id'        => $post->ID,
			'title'     => $post->post_title,
			'content'   => $post->post_content,
			'excerpt'   => $post->post_excerpt,
			'status'    => $post->post_status,
			'type'      => $post->post_type,
			'date'      => $post->post_date,
			'modified'  => $post->post_modified,
			'author'    => (int) $post->post_author,
			'slug'      => $post->post_name,
			'permalink' => get_permalink( $post ),
		];
	}

	/**
	 * wp_create_post handler.
	 */
	public function create_post( array $input ): array {
		$post_data = [
			'post_title'   => sanitize_text_field( $input['title'] ),
			'post_content' => wp_kses_post( $input['content'] ),
			'post_type'    => sanitize_key( $input['post_type'] ?? 'post' ),
			'post_status'  => sanitize_key( $input['status'] ?? 'draft' ),
		];

		$post_id = wp_insert_post( wp_slash( $post_data ), true );

		if ( is_wp_error( $post_id ) ) {
			throw new Frontman_Tool_Error( $post_id->get_error_message() );
		}

		return [
			'id'        => $post_id,
			'title'     => $post_data['post_title'],
			'status'    => $post_data['post_status'],
			'type'      => $post_data['post_type'],
			'after'     => $this->read_post( [ 'id' => $post_id ] ),
			'permalink' => get_permalink( $post_id ),
		];
	}

	/**
	 * wp_duplicate_post handler.
	 */
	public function duplicate_post( array $input ): array {
		$source_id = absint( $input['source_id'] ?? 0 );
		$source    = get_post( $source_id );

		if ( ! $source ) {
			throw new Frontman_Tool_Error( "Post not found: {$source_id}" );
		}

		$title  = isset( $input['title'] ) ? sanitize_text_field( $input['title'] ) : trim( (string) $source->post_title ) . ' Copy';

		$post_data = [
			'post_title'   => $title,
			'post_content' => (string) ( $source->post_content ?? '' ),
			'post_excerpt' => (string) ( $source->post_excerpt ?? '' ),
			'post_type'    => sanitize_key( $source->post_type ?? 'post' ),
			'post_status'  => 'draft',
		];

		$post_id = wp_insert_post( wp_slash( $post_data ), true );

		if ( is_wp_error( $post_id ) ) {
			throw new Frontman_Tool_Error( $post_id->get_error_message() );
		}

		foreach ( [ '_elementor_edit_mode', '_elementor_data', '_elementor_template_type', '_elementor_version', '_elementor_page_settings', '_wp_page_template' ] as $key ) {
			foreach ( get_post_meta( $source_id, $key, false ) as $value ) {
				add_post_meta( (int) $post_id, $key, wp_slash( $value ) );
			}
		}

		return [
			'duplicated'       => true,
			'id'               => (int) $post_id,
			'source'           => $this->read_post( [ 'id' => $source_id ] ),
			'after'            => $this->read_post( [ 'id' => (int) $post_id ] ),
			'permalink'        => get_permalink( $post_id ),
		];
	}

	/**
	 * wp_update_post handler.
	 */
	public function update_post( array $input ): array {
		$id   = absint( $input['id'] ?? 0 );
		$post = get_post( $id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$id}" );
		}

		$before = $this->read_post( [ 'id' => $id ] );

		$post_data = [ 'ID' => $id ];

		if ( isset( $input['title'] ) ) {
			$post_data['post_title'] = sanitize_text_field( $input['title'] );
		}
		if ( isset( $input['content'] ) ) {
			$post_data['post_content'] = wp_kses_post( $input['content'] );
		}
		if ( isset( $input['status'] ) ) {
			$post_data['post_status'] = sanitize_key( $input['status'] );
		}
		if ( isset( $input['excerpt'] ) ) {
			$post_data['post_excerpt'] = sanitize_textarea_field( $input['excerpt'] );
		}

		$result = wp_update_post( wp_slash( $post_data ), true );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		$updated_post = get_post( $id );

		return [
			'before' => $before,
			'after'  => $this->read_post( [ 'id' => $updated_post->ID ] ),
		];
	}

	/**
	 * wp_delete_post handler.
	 */
	public function delete_post( array $input ): array {
		$id    = absint( $input['id'] ?? 0 );
		$force = (bool) ( $input['force'] ?? false );
		$post  = get_post( $id );

		if ( empty( $input['confirm'] ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$id}" );
		}

		$before = $this->read_post( [ 'id' => $id ] );

		$result = wp_delete_post( $id, $force );

		if ( ! $result ) {
			throw new Frontman_Tool_Error( "Failed to delete post: {$id}" );
		}

		return [
			'before'  => $before,
			'deleted' => true,
			'id'      => $id,
			'title'   => $post->post_title,
			'trashed' => ! $force,
		];
	}

}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
