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


class Frontman_Tool_Posts {
	private const TAXONOMIES = [ 'categories' => 'category', 'tags' => 'post_tag' ];

	/**
	 * Register all post tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$template_schema = [
			'type' => 'string',
			'description' => 'Pages only: an available native page-template slug/file, or default to reset. Omit on update to preserve. Read the actual assignment in wp_read_post.template.',
		];
		$categories_schema = [
			'type' => 'array',
			'items' => [ 'type' => 'integer', 'minimum' => 1 ],
			'description' => 'Existing category term IDs. Supplied arrays replace assignments; omit on update to preserve. Empty uses the WordPress default category for posts (and filtered default-category post types), except auto-drafts; otherwise clears. Never creates terms. Read IDs with wp_read_post.',
		];
		$tags_schema = [
			'type' => 'array',
			'items' => [ 'type' => 'integer', 'minimum' => 1 ],
			'description' => 'Existing tag term IDs. Supplied arrays replace assignments; empty clears tags. Omit on update to preserve. Never creates terms. Read IDs with wp_read_post.',
		];
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_posts',
			'Lists posts, pages, or custom post types with pagination and filtering. Returns stored slugs, which can be empty for drafts or pending posts. Publication applies WordPress core slug rules.',
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
			'Reads a single post by ID, returning stored post_content (including any block markup), content_sha256 for wp_update_post edit mode, basic post fields, and categories/tags with IDs, names and slugs. Does not return custom post metadata or plugin snippet source. Empty content does not mean a plugin-managed snippet has no code.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id' => [
						'type'        => 'integer',
						'minimum'     => 1,
						'description' => 'The post ID to read.',
					],
				],
				'required' => [ 'id' ],
			],
			[ $this, 'read_post' ],
			null,
			true,
			false,
			static fn( \stdClass $input ): bool => true
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_post',
			'Creates a new post or page. For a user-requested author task, resolve the account with wp_find_users; never guess IDs or choose an ambiguous match. Read back successful author assignment with wp_read_post. Returns the new post ID and permalink. Use wp_duplicate_post when the user asks to duplicate or clone an existing page so Elementor/post metadata is copied.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'title'     => [
						'type'        => 'string',
						'description' => 'The post title.',
					],
					'slug'      => [
						'type'        => 'string',
						'description' => 'Optional permalink slug. WordPress sanitizes it and applies status-specific uniqueness. Empty allows an empty draft/pending slug; published posts derive one from the title. The persisted slug is returned in after.slug.',
					],
					'content'   => [
						'type'        => 'string',
						'description' => 'The post content as HTML or Gutenberg block markup.',
					],
					'author' => [
						'type' => 'integer',
						'minimum' => 1,
						'description' => 'Native WordPress account ID. Omit to use the current user. Requires author support; assigning another account requires edit_others_posts for this post type.',
					],
					'categories' => $categories_schema,
					'tags' => $tags_schema,
					'template' => $template_schema,
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
			'Updates an existing post or page. For a user-requested author task, resolve the account with wp_find_users; never guess IDs or choose an ambiguous match. Read back successful author assignment with wp_read_post. Only the fields you provide will be changed. Do not use content on Elementor-managed pages; use wp_elementor_* tools for Elementor content/layout changes.',
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
					'slug'    => [
						'type'        => 'string',
						'description' => 'Optional permalink slug. Omit to retain the current slug, subject to WordPress status transitions. WordPress sanitizes it and applies uniqueness. Empty allows an empty draft/pending slug; published posts derive one from the title. See after.slug for the persisted value.',
					],
					'content' => [
						'type'        => 'string',
						'description' => 'New post content as HTML or block markup.',
					],
					'mode' => [
						'type' => 'string',
						'enum' => [ 'replace', 'edit' ],
						'default' => 'replace',
						'description' => 'replace accepts full content. For user-authorized fragment changes, use edit after a fresh wp_read_post: supply oldText, newText and content_sha256 as expected_current_sha256, never content. Requires exactly one exact byte match. Supports drafts, freeform HTML and block HTML without parsing or reserializing blocks. Conflict detection is best-effort, not an atomic lock. Elementor content is not supported.',
					],
					'oldText' => [
						'type' => 'string',
						'description' => 'Required in edit mode only: nonempty exact fragment from stored content, occurring exactly once.',
					],
					'newText' => [
						'type' => 'string',
						'description' => 'Required in edit mode only: replacement bytes, different from oldText. Empty deletes the fragment.',
					],
					'expected_current_sha256' => [
						'type' => 'string',
						'pattern' => '^[a-f0-9]{64}$',
						'description' => 'Required in edit mode only: lowercase SHA256 from the fresh wp_read_post.content_sha256. Any content change requires reading again.',
					],
					'status'  => [
						'type'        => 'string',
						'description' => 'New post status.',
						'enum'        => [ 'draft', 'publish', 'pending', 'private', 'trash' ],
					],
					'author' => [
						'type' => 'integer',
						'minimum' => 1,
						'description' => 'Native WordPress account ID. Omit to preserve the current author. Requires author support; an explicit other account requires edit_others_posts even when unchanged.',
					],
					'categories' => $categories_schema,
					'tags' => $tags_schema,
					'template' => $template_schema,
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
			'wp_save_post_preview',
			'Saves proposed content as a native autosave for a published post or page without changing the published content. Open the returned preview_url while signed in as the same user. Existing differing autosaves are preserved and cause an error. After approval use wp_update_post to publish; preview URLs are temporary.',
			[
				'type' => 'object',
				'additionalProperties' => false,
				'properties' => [
					'id' => [ 'type' => 'integer', 'minimum' => 1, 'description' => 'Published post or page ID.' ],
					'content' => [ 'type' => 'string', 'description' => 'Complete proposed HTML or block markup.' ],
				],
				'required' => [ 'id', 'content' ],
			],
			[ $this, 'save_post_preview' ],
			'read-write',
			true,
			true
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

	/** Save only a revision: core's preview handler reads the latest autosave across authors. */
	public function save_post_preview( array $input ): array {
		if ( ! isset( $input['id'] ) || ! is_int( $input['id'] ) || $input['id'] <= 0 ) {
			throw new Frontman_Tool_Error( 'id must be a positive integer.' );
		}
		if ( ! array_key_exists( 'content', $input ) ) {
			throw new Frontman_Tool_Error( 'content is required and must be a string.' );
		}
		$post = get_post( $input['id'] );
		if ( ! $post ) {
			throw new Frontman_Tool_Error( 'Post not found.' );
		}
		$this->check_write_permissions( [], $post->post_type, $post );
		$type = get_post_type_object( $post->post_type );
		if ( 'publish' !== $post->post_status || ! $type || ! is_post_type_viewable( $type ) || ! post_type_supports( $post->post_type, 'revisions' ) ) {
			throw new Frontman_Tool_Error( 'Preview requires a published, publicly viewable post type with revision support.' );
		}
		$this->check_content( $input );
		if ( ( class_exists( 'Frontman_Elementor_Data' ) && Frontman_Elementor_Data::post_uses_elementor( $post->ID ) )
			|| get_post_meta( $post->ID, '_et_pb_use_builder', true ) === 'on'
			|| get_post_meta( $post->ID, '_fl_builder_enabled', true )
			|| get_post_meta( $post->ID, '_bricks_page_content_2', true ) ) {
			throw new Frontman_Tool_Error( 'Builder-managed content cannot be previewed with this tool.' );
		}

		$autosaves = get_posts( [
			'post_type' => 'revision', 'post_status' => 'inherit', 'post_parent' => $post->ID,
			'name' => $post->ID . '-autosave-v1', 'posts_per_page' => -1,
		] );
		foreach ( $autosaves as $autosave ) {
			if ( $autosave->post_content !== $input['content'] || $autosave->post_title !== $post->post_title || $autosave->post_excerpt !== $post->post_excerpt ) {
				throw new Frontman_Tool_Error( 'A differing editor autosave exists. It was preserved; resolve it in WordPress before previewing.' );
			}
		}
		$autosave = wp_get_post_autosave( $post->ID );
		if ( ! $autosave ) {
			$data = get_post( $post->ID, ARRAY_A );
			$data['post_content'] = $input['content'];
			$id = _wp_put_post_revision( $data, true );
			if ( is_wp_error( $id ) || ! $id ) {
				throw new Frontman_Tool_Error( is_wp_error( $id ) ? $id->get_error_message() : 'Could not save the autosave.' );
			}
			$autosave = get_post( $id );
			if ( ! $autosave || $autosave->post_content !== $input['content'] || $autosave->post_title !== $post->post_title || $autosave->post_excerpt !== $post->post_excerpt ) {
				throw new Frontman_Tool_Error( "Autosave {$id} was saved, but readback differs. It was not rolled back; inspect it in WordPress." );
			}
		}
		$autosaves = get_posts( [
			'post_type' => 'revision', 'post_status' => 'inherit', 'post_parent' => $post->ID,
			'name' => $post->ID . '-autosave-v1', 'posts_per_page' => -1,
		] );
		$selected = wp_get_post_autosave( $post->ID );
		if ( ! $selected ) {
			throw new Frontman_Tool_Error( 'The preview autosave is no longer available; inspect autosaves in WordPress.' );
		}
		$autosaves[] = $selected;
		foreach ( $autosaves as $candidate ) {
			if ( $candidate->post_content !== $input['content'] || $candidate->post_title !== $post->post_title || $candidate->post_excerpt !== $post->post_excerpt ) {
				throw new Frontman_Tool_Error( 'A differing editor autosave exists. It was preserved; a new autosave may also have been created. Resolve autosaves in WordPress before previewing.' );
			}
		}
		$autosave = $selected;
		return [
			'parent_id' => $post->ID,
			'autosave_id' => $autosave->ID,
			'preview_url' => get_preview_post_link( $post, [
				'preview_id' => $post->ID,
				'preview_nonce' => wp_create_nonce( 'post_preview_' . $post->ID ),
			] ),
		];
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
				'slug'     => $post->post_name,
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
			'content_sha256' => hash( 'sha256', $post->post_content ),
			'excerpt'   => $post->post_excerpt,
			'status'    => $post->post_status,
			'type'      => $post->post_type,
			'date'      => $post->post_date,
			'modified'  => $post->post_modified,
			'author'    => (int) $post->post_author,
			'slug'      => $post->post_name,
			'template'  => 'page' === $post->post_type ? $this->page_template( $post->ID ) : null,
			'permalink' => get_permalink( $post ),
			'categories' => $this->read_terms( $post, 'category' ),
			'tags'       => $this->read_terms( $post, 'post_tag' ),
		];
	}

	private function read_terms( \WP_Post $post, string $taxonomy ): array {
		if ( ! is_object_in_taxonomy( $post->post_type, $taxonomy ) ) {
			return [];
		}
		$terms = get_the_terms( $post->ID, $taxonomy );
		if ( is_wp_error( $terms ) ) {
			throw new Frontman_Tool_Error( $terms->get_error_message() );
		}
		return array_map( static function( $term ): array {
			return [ 'id' => (int) $term->term_id, 'name' => $term->name, 'slug' => $term->slug ];
		}, array_values( $terms ?: [] ) );
	}

	public static function validate_taxonomy_input( array $input ): void {
		foreach ( self::TAXONOMIES as $field => $taxonomy ) {
			if ( ! array_key_exists( $field, $input ) ) {
				continue;
			}
			$ids = $input[ $field ];
			if ( ! is_array( $ids ) || array_values( $ids ) !== $ids ) {
				throw new Frontman_Tool_Error( "{$field} must be an array of positive integer term IDs." );
			}
			foreach ( $ids as $id ) {
				if ( ! is_int( $id ) || $id <= 0 ) {
					throw new Frontman_Tool_Error( "{$field} must be an array of positive integer term IDs." );
				}
			}
		}
	}

	/** Resolve and authorize all requested assignments before any post or term write. */
	private function check_taxonomies( array $input, string $type, string $status ): array {
		$assignments = [];
		foreach ( self::TAXONOMIES as $field => $taxonomy ) {
			if ( ! array_key_exists( $field, $input ) ) {
				continue;
			}
			if ( ! is_object_in_taxonomy( $type, $taxonomy ) ) {
				throw new Frontman_Tool_Error( "{$taxonomy} is not attached to post type {$type}." );
			}
			if ( ! current_user_can( get_taxonomy( $taxonomy )->cap->assign_terms ) ) {
				throw new Frontman_Tool_Error( "Insufficient permission to assign {$taxonomy} terms." );
			}
			$ids = $input[ $field ];
			if ( 'category' === $taxonomy && [] === $ids && 'auto-draft' !== $status && in_array( $type, array_merge( apply_filters( 'default_category_post_types', [] ), [ 'post' ] ), true ) ) {
				$ids = [ (int) get_option( 'default_category' ) ];
			}
			foreach ( $ids as $id ) {
				$term = get_term( $id, $taxonomy );
				if ( is_wp_error( $term ) || ! $term ) {
					throw new Frontman_Tool_Error( "Term {$id} does not exist in {$taxonomy}." );
				}
				if ( ! current_user_can( 'assign_term', $id ) ) {
					throw new Frontman_Tool_Error( "Insufficient permission to assign {$taxonomy} term {$id}." );
				}
			}
			$assignments[ $taxonomy ] = $ids;
		}
		return $assignments;
	}

	/** Core post writes do not propagate term assignment errors. Assign explicitly and report partial writes. */
	private function assign_and_read( int $id, array $assignments ): array {
		try {
			foreach ( $assignments as $taxonomy => $ids ) {
				$result = 'category' === $taxonomy
					? wp_set_post_categories( $id, $ids )
					: wp_set_object_terms( $id, $ids, $taxonomy, false );
				if ( is_wp_error( $result ) ) {
					throw new Frontman_Tool_Error( "{$taxonomy} assignment failed: " . $result->get_error_message() );
				}
			}
			$after = $this->read_post( [ 'id' => $id ] );
			foreach ( self::TAXONOMIES as $field => $taxonomy ) {
				if ( ! array_key_exists( $taxonomy, $assignments ) ) { continue; }
				$expected = array_values( array_unique( $assignments[ $taxonomy ] ) );
				$actual = array_column( $after[ $field ], 'id' );
				sort( $expected );
				sort( $actual );
				if ( $expected !== $actual ) {
					throw new Frontman_Tool_Error( "{$taxonomy} assignment readback does not match requested term IDs." );
				}
			}
			return $after;
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( "Post {$id} was saved, but taxonomy assignment or readback failed. Partial writes may remain; no rollback was performed. Read wp_read_post before retrying. " . $e->getMessage(), 0, $e );
		}
	}

	/** Validate before registry coercion and for direct handler calls. */
	public static function validate_author_input( array $input ): void {
		if ( array_key_exists( 'author', $input ) && ( ! is_int( $input['author'] ) || $input['author'] <= 0 ) ) {
			throw new Frontman_Tool_Error( 'author must be a positive integer account ID.' );
		}
	}

	/** Native writes do not enforce the REST permission layer. Check permissions before writing. */
	private function check_write_permissions( array $input, string $type, ?\WP_Post $post = null ): void {
		self::validate_author_input( $input );
		$post_type = get_post_type_object( $type );
		if ( ! $post_type ) {
			throw new Frontman_Tool_Error( 'Post type not found.' );
		}
		if ( null === $post ? ! current_user_can( $post_type->cap->create_posts ) : ! current_user_can( 'edit_post', $post->ID ) ) {
			throw new Frontman_Tool_Error( 'Insufficient permission to create or edit this post.' );
		}
		$status = sanitize_key( $input['status'] ?? ( null === $post ? 'draft' : $post->post_status ) );
		if ( ( null === $post || $status !== $post->post_status ) && in_array( $status, [ 'publish', 'future', 'private' ], true ) && ! current_user_can( $post_type->cap->publish_posts ) ) {
			throw new Frontman_Tool_Error( 'Insufficient permission to publish or create private posts of this type.' );
		}
		if ( ! array_key_exists( 'author', $input ) ) {
			return;
		}
		if ( get_current_user_id() !== $input['author'] && ! current_user_can( $post_type->cap->edit_others_posts ) ) {
			throw new Frontman_Tool_Error( 'Insufficient permission to assign another author for this post type.' );
		}
		if ( ! post_type_supports( $type, 'author' ) ) {
			throw new Frontman_Tool_Error( 'This post type does not support author assignment.' );
		}
		if ( ! get_userdata( $input['author'] ) ) {
			throw new Frontman_Tool_Error( 'Author account not found.' );
		}
		if ( is_multisite() && ! is_user_member_of_blog( $input['author'], get_current_blog_id() ) ) {
			throw new Frontman_Tool_Error( 'Author must be a member of the current site.' );
		}
	}

	/** Retain raw values until validated, including null versus omission. */
	public static function validate_template_input( array $input ): void {
		if ( array_key_exists( 'template', $input ) && ! is_string( $input['template'] ) ) {
			throw new Frontman_Tool_Error( 'template must be a string.' );
		}
	}

	private function check_page_template( array $input, string $type, ?\WP_Post $post = null ): void {
		self::validate_template_input( $input );
		if ( ! array_key_exists( 'template', $input ) ) {
			return;
		}
		if ( 'page' !== $type ) {
			throw new Frontman_Tool_Error( 'template assignment is only supported for pages.' );
		}
		if ( 'default' !== $input['template'] && ! array_key_exists( $input['template'], wp_get_theme()->get_page_templates( $post, 'page' ) ) ) {
			throw new Frontman_Tool_Error( 'Requested template is not available for pages in the active theme. No changes were saved.' );
		}
	}

	private function page_template( int $id ): string {
		$template = get_page_template_slug( $id );
		return '' === $template ? 'default' : $template;
	}

	private function verify_page_template( int $id, string $expected ): void {
		if ( $this->page_template( $id ) !== $expected ) {
			throw new Frontman_Tool_Error( "Post {$id} was saved, but page template readback differs from the requested assignment. Partial writes may remain; no rollback was performed. Use wp_read_post before retrying." );
		}
	}

	/** Reject destructive sanitization before any write; native save filters remain enabled. */
	private function check_content( array $input ): void {
		if ( ! array_key_exists( 'content', $input ) ) {
			return;
		}
		if ( ! is_string( $input['content'] ) ) {
			throw new Frontman_Tool_Error( 'content must be a string.' );
		}
		if ( ! current_user_can( 'unfiltered_html' ) && wp_kses_post( $input['content'] ) !== $input['content'] ) {
			throw new Frontman_Tool_Error( 'Content contains HTML not permitted without unfiltered_html. No changes were saved; remove the denied HTML or use an authorized account.' );
		}
	}

	/** Verify the actual stored content, including changes made by native/plugin filters. */
	private function verify_content( int $id, string $expected ): void {
		$post = get_post( $id );
		if ( ! $post || $post->post_content !== $expected ) {
			throw new Frontman_Tool_Error( "Post {$id} was saved, but content readback did not match the requested content. Partial writes may remain; no rollback was performed. Use wp_read_post before retrying." );
		}
	}

	/**
	 * wp_create_post handler.
	 */
	public function create_post( array $input ): array {
		if ( in_array( sanitize_key( $input['post_type'] ?? 'post' ), [ 'wp_template', 'wp_template_part' ], true ) ) {
			throw new Frontman_Tool_Error( 'Use wp_create_template to create theme-linked templates or parts.' );
		}
		self::validate_taxonomy_input( $input );
		$this->check_write_permissions( $input, sanitize_key( $input['post_type'] ?? 'post' ) );
		if ( ! array_key_exists( 'content', $input ) ) {
			throw new Frontman_Tool_Error( 'content is required when creating a post and must be a string.' );
		}
		$this->check_content( $input );
		$this->check_page_template( $input, sanitize_key( $input['post_type'] ?? 'post' ) );
		$assignments = $this->check_taxonomies( $input, sanitize_key( $input['post_type'] ?? 'post' ), sanitize_key( $input['status'] ?? 'draft' ) );
		$post_data = [
			'post_title'   => sanitize_text_field( $input['title'] ),
			'post_content' => $input['content'],
			'post_type'    => sanitize_key( $input['post_type'] ?? 'post' ),
			'post_status'  => sanitize_key( $input['status'] ?? 'draft' ),
		];
		if ( array_key_exists( 'slug', $input ) ) {
			if ( ! is_string( $input['slug'] ) ) {
				throw new Frontman_Tool_Error( 'slug must be a string.' );
			}
			$post_data['post_name'] = $input['slug'];
		}

		if ( array_key_exists( 'author', $input ) ) {
			$post_data['post_author'] = $input['author'];
		}
		if ( array_key_exists( 'template', $input ) ) {
			$post_data['page_template'] = $input['template'];
		}
		$post_id = wp_insert_post( wp_slash( $post_data ), true );

		if ( is_wp_error( $post_id ) ) {
			throw new Frontman_Tool_Error( $post_id->get_error_message() );
		}

		if ( 'page' === $post_data['post_type'] ) {
			$this->verify_page_template( (int) $post_id, $input['template'] ?? 'default' );
		}
		$this->verify_content( (int) $post_id, $post_data['post_content'] );

		return [
			'id'        => $post_id,
			'title'     => $post_data['post_title'],
			'status'    => $post_data['post_status'],
			'type'      => $post_data['post_type'],
			'after'     => $this->assign_and_read( (int) $post_id, $assignments ),
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

		if ( in_array( $source->post_type, [ 'wp_template', 'wp_template_part' ], true ) ) {
			throw new Frontman_Tool_Error( 'Use wp_create_template instead of duplicating templates or parts.' );
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
		self::validate_taxonomy_input( $input );
		$id   = absint( $input['id'] ?? 0 );
		$post = get_post( $id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$id}" );
		}

		$this->check_write_permissions( $input, $post->post_type, $post );
		$input = $this->prepare_content_edit( $input, $post );
		$this->check_content( $input + [ 'content' => $post->post_content ] );
		$this->check_page_template( $input, $post->post_type, $post );
		$assignments = $this->check_taxonomies( $input, $post->post_type, sanitize_key( $input['status'] ?? $post->post_status ) );
		$before = $this->read_post( [ 'id' => $id ] );

		$post_data = [ 'ID' => $id ];
		if ( array_key_exists( 'slug', $input ) ) {
			if ( ! is_string( $input['slug'] ) ) {
				throw new Frontman_Tool_Error( 'slug must be a string.' );
			}
			$post_data['post_name'] = $input['slug'];
		}
		if ( array_key_exists( 'author', $input ) ) {
			$post_data['post_author'] = $input['author'];
		}
		if ( isset( $input['content'] ) && class_exists( 'Frontman_Elementor_Data' ) && Frontman_Elementor_Data::post_uses_elementor( $id ) ) {
			throw new Frontman_Tool_Error( 'Refusing to update post_content for Elementor-managed page ' . $id . '. Use wp_elementor_update_element, wp_elementor_save_page_data, or wp_elementor_restore_rollback for Elementor content/layout changes. wp_update_post may still update title, status, or excerpt without content.' );
		}

		if ( isset( $input['title'] ) ) {
			$post_data['post_title'] = sanitize_text_field( $input['title'] );
		}
		if ( isset( $input['content'] ) ) {
			$post_data['post_content'] = $input['content'];
		}
		if ( isset( $input['status'] ) ) {
			$post_data['post_status'] = sanitize_key( $input['status'] );
		}
		if ( isset( $input['excerpt'] ) ) {
			$post_data['post_excerpt'] = sanitize_textarea_field( $input['excerpt'] );
		}

		if ( array_key_exists( 'template', $input ) ) {
			$post_data['page_template'] = $input['template'];
		}
		$result = wp_update_post( wp_slash( $post_data ), true );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		if ( 'page' === $post->post_type ) {
			$this->verify_page_template( $id, $input['template'] ?? $before['template'] );
		}
		$this->verify_content( $id, $input['content'] ?? $before['content'] );

		return [
			'before' => $before,
			'after'  => $this->assign_and_read( $id, $assignments ),
		];
	}

	/** Prepare exact bytes before any write; the existing writer owns persistence. */
	private function prepare_content_edit( array $input, \WP_Post $post ): array {
		$mode = array_key_exists( 'mode', $input ) ? $input['mode'] : 'replace';
		if ( ! is_string( $mode ) || ! in_array( $mode, [ 'replace', 'edit' ], true ) ) {
			throw new Frontman_Tool_Error( 'mode must be replace or edit.' );
		}
		$fields = [ 'oldText', 'newText', 'expected_current_sha256' ];
		if ( 'replace' === $mode ) {
			foreach ( $fields as $field ) {
				if ( array_key_exists( $field, $input ) ) {
					throw new Frontman_Tool_Error( "{$field} is only allowed in edit mode." );
				}
			}
			return $input;
		}
		if ( array_key_exists( 'content', $input ) ) {
			throw new Frontman_Tool_Error( 'content is not allowed in edit mode.' );
		}
		foreach ( $fields as $field ) {
			if ( ! array_key_exists( $field, $input ) || ! is_string( $input[ $field ] ) ) {
				throw new Frontman_Tool_Error( "{$field} is required in edit mode and must be a string." );
			}
		}
		if ( '' === $input['oldText'] || $input['oldText'] === $input['newText'] ) {
			throw new Frontman_Tool_Error( 'oldText must be nonempty and different from newText.' );
		}
		if ( ! preg_match( '/\A[a-f0-9]{64}\z/', $input['expected_current_sha256'] ) ) {
			throw new Frontman_Tool_Error( 'expected_current_sha256 must be a lowercase SHA256 hash.' );
		}
		if ( hash( 'sha256', $post->post_content ) !== $input['expected_current_sha256'] ) {
			throw new Frontman_Tool_Error( 'Stale content hash. Read wp_read_post before retrying; no changes were saved.' );
		}
		$offset = strpos( $post->post_content, $input['oldText'] );
		if ( false === $offset || false !== strpos( $post->post_content, $input['oldText'], $offset + 1 ) ) {
			throw new Frontman_Tool_Error( 'oldText must match exactly once. No changes were saved.' );
		}
		$input['content'] = substr_replace( $post->post_content, $input['newText'], $offset, strlen( $input['oldText'] ) );
		return $input;
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
