<?php
/**
 * WordPress Block tools — read and manipulate Gutenberg blocks within posts.
 *
 * Tools: wp_list_blocks, wp_read_block, wp_update_block, wp_insert_block,
 * wp_move_block, wp_delete_block
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Blocks {
	/**
	 * Register all block tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_blocks',
			'Lists all Gutenberg blocks in a post\'s content. Returns each block\'s name, attributes, and index.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id' => [
						'type'        => 'integer',
						'description' => 'The post ID to list blocks from.',
					],
				],
				'required' => [ 'post_id' ],
			],
			[ $this, 'list_blocks' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_block',
			'Reads a single Gutenberg block from a post by its zero-based index. Returns full block markup and attributes.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id' => [
						'type'        => 'integer',
						'description' => 'The post ID containing the block.',
					],
					'index'   => [
						'type'        => 'integer',
						'description' => 'Zero-based index of the block to read.',
					],
				],
				'required' => [ 'post_id', 'index' ],
			],
			[ $this, 'read_block' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_block',
			'Replaces a Gutenberg block at a given index in a post with new block markup.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'      => [
						'type'        => 'integer',
						'description' => 'The post ID containing the block.',
					],
					'index'        => [
						'type'        => 'integer',
						'description' => 'Zero-based index of the block to replace.',
					],
					'block_markup' => [
						'type'        => 'string',
						'description' => 'The new block markup (HTML with Gutenberg block comments, e.g. <!-- wp:paragraph --><p>Hello</p><!-- /wp:paragraph -->).',
					],
				],
				'required' => [ 'post_id', 'index', 'block_markup' ],
			],
			[ $this, 'update_block' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_insert_block',
			'Inserts a new Gutenberg block into a post at a given position. Appends to end if index is omitted.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'      => [
						'type'        => 'integer',
						'description' => 'The post ID to insert the block into.',
					],
					'index'        => [
						'type'        => 'integer',
						'description' => 'Zero-based position to insert at. Appends to end if omitted.',
					],
					'block_markup' => [
						'type'        => 'string',
						'description' => 'The block markup to insert (HTML with Gutenberg block comments).',
					],
				],
				'required' => [ 'post_id', 'block_markup' ],
			],
			[ $this, 'insert_block' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_move_block',
			'Moves an existing Gutenberg block to a different index within the same post.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer', 'description' => 'The post ID containing the block.' ],
					'from_index' => [ 'type' => 'integer', 'description' => 'Zero-based source block index.' ],
					'to_index'   => [ 'type' => 'integer', 'description' => 'Zero-based destination block index.' ],
				],
				'required' => [ 'post_id', 'from_index', 'to_index' ],
			],
			[ $this, 'move_block' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_delete_block',
			'Deletes a Gutenberg block from a post. Ask the user for confirmation first and only call this tool with confirm=true after they approve.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'  => [ 'type' => 'integer', 'description' => 'The post ID containing the block.' ],
					'index'    => [ 'type' => 'integer', 'description' => 'Zero-based block index to delete.' ],
					'confirm'  => [ 'type' => 'boolean', 'description' => 'Must be true only after the user explicitly confirms deletion.' ],
				],
				'required' => [ 'post_id', 'index', 'confirm' ],
			],
			[ $this, 'delete_block' ]
		) );
	}

	/**
	 * Parse all blocks from a post, preserving freeform/null-name content.
	 */
	private function get_all_blocks( int $post_id ): array {
		$post = get_post( $post_id );
		if ( ! $post ) {
			return [];
		}

		return parse_blocks( $post->post_content );
	}

	/**
	 * Return visible named blocks with their raw indices preserved.
	 *
	 * @return array<int, array{raw_index:int, block:array}>
	 */
	private function get_visible_blocks( int $post_id ): array {
		$visible = [];
		foreach ( $this->get_all_blocks( $post_id ) as $raw_index => $block ) {
			if ( empty( $block['blockName'] ) ) {
				continue;
			}

			$visible[] = [
				'raw_index' => $raw_index,
				'block'     => $block,
			];
		}

		return $visible;
	}

	/**
	 * Resolve a visible block index to the raw parsed block array.
	 */
	private function resolve_visible_block( int $post_id, int $index ): array {
		$visible = $this->get_visible_blocks( $post_id );
		if ( empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		if ( $index >= count( $visible ) ) {
			throw new Frontman_Tool_Error( "Block index {$index} out of range (post has " . count( $visible ) . ' blocks)' );
		}

		return $visible[ $index ];
	}

	/**
	 * Serialize blocks back to post content string.
	 */
	private function serialize_blocks( array $blocks ): string {
		return implode( "\n\n", array_map( 'serialize_block', $blocks ) );
	}

	/**
	 * Summarize a block for listing.
	 */
	private function summarize_block( array $block, int $index ): array {
		return [
			'index'      => $index,
			'name'       => $block['blockName'],
			'attributes' => $block['attrs'] ?? [],
			'innerText'  => wp_strip_all_tags( $block['innerHTML'] ?? '' ),
		];
	}

	/**
	 * wp_list_blocks handler.
	 */
	public function list_blocks( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$post    = get_post( $post_id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$post_id}" );
		}

		$visible = $this->get_visible_blocks( $post_id );
		$blocks  = array_map(
			static function( array $entry ) {
				return $entry['block'];
			},
			$visible
		);

		return [
			'post_id'     => $post_id,
			'block_count' => count( $blocks ),
			'blocks'      => array_map( [ $this, 'summarize_block' ], $blocks, array_keys( $blocks ) ),
		];
	}

	/**
	 * wp_read_block handler.
	 */
	public function read_block( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$index   = absint( $input['index'] ?? 0 );
		$entry  = $this->resolve_visible_block( $post_id, $index );
		$block  = $entry['block'];

		return [
			'index'        => $index,
			'name'         => $block['blockName'],
			'attributes'   => $block['attrs'] ?? [],
			'innerHTML'    => $block['innerHTML'] ?? '',
			'innerContent' => $block['innerContent'] ?? [],
			'markup'       => serialize_block( $block ),
		];
	}

	/**
	 * wp_update_block handler.
	 */
	public function update_block( array $input ): array {
		$post_id      = absint( $input['post_id'] ?? 0 );
		$index        = absint( $input['index'] ?? 0 );
		$block_markup = $input['block_markup'] ?? '';
		$post         = get_post( $post_id );

		$all_blocks = $this->get_all_blocks( $post_id );
		$entry      = $this->resolve_visible_block( $post_id, $index );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'block'        => $this->read_block( [ 'post_id' => $post_id, 'index' => $index ] ),
		];

		$new_blocks = parse_blocks( $block_markup );
		$new_block  = array_values( array_filter( $new_blocks, function( $b ) { return ! empty( $b['blockName'] ); } ) );

		if ( empty( $new_block ) ) {
			throw new Frontman_Tool_Error( 'Invalid block markup' );
		}

		$all_blocks[ $entry['raw_index'] ] = $new_block[0];
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( [ 'ID' => $post_id, 'post_content' => $content ], true );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'updated' => true,
			'before'  => $before,
			'after'   => [
				'post_id'      => $post_id,
				'post_content' => get_post( $post_id )->post_content,
				'block'        => $this->read_block( [ 'post_id' => $post_id, 'index' => $index ] ),
			],
		];
	}

	/**
	 * wp_insert_block handler.
	 */
	public function insert_block( array $input ): array {
		$post_id      = absint( $input['post_id'] ?? 0 );
		$block_markup = $input['block_markup'] ?? '';
		$post         = get_post( $post_id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$post_id}" );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
		];

		$all_blocks = $this->get_all_blocks( $post_id );
		$visible    = $this->get_visible_blocks( $post_id );

		$new_blocks = parse_blocks( $block_markup );
		$new_block  = array_values( array_filter( $new_blocks, function( $b ) { return ! empty( $b['blockName'] ); } ) );

		if ( empty( $new_block ) ) {
			throw new Frontman_Tool_Error( 'Invalid block markup' );
		}

		$index = isset( $input['index'] ) ? absint( $input['index'] ) : count( $visible );
		$index = min( max( 0, $index ), count( $visible ) );

		if ( $index >= count( $visible ) ) {
			$raw_index = count( $all_blocks );
		} else {
			$raw_index = $visible[ $index ]['raw_index'];
		}

		array_splice( $all_blocks, $raw_index, 0, [ $new_block[0] ] );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( [ 'ID' => $post_id, 'post_content' => $content ], true );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'inserted' => true,
			'before'   => $before,
			'after'    => [
				'post_id'      => $post_id,
				'post_content' => get_post( $post_id )->post_content,
				'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
			],
		];
	}

	/**
	 * wp_move_block handler.
	 */
	public function move_block( array $input ): array {
		$post_id    = absint( $input['post_id'] ?? 0 );
		$from_index = absint( $input['from_index'] ?? 0 );
		$to_index   = absint( $input['to_index'] ?? 0 );
		$post       = get_post( $post_id );
		$all_blocks = $this->get_all_blocks( $post_id );
		$visible    = $this->get_visible_blocks( $post_id );

		if ( ! $post || empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		if ( $from_index >= count( $visible ) || $to_index >= count( $visible ) ) {
			throw new Frontman_Tool_Error( 'Block move indices are out of range' );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
		];

		$from_raw_index = $visible[ $from_index ]['raw_index'];
		$to_raw_index   = $visible[ $to_index ]['raw_index'];
		$block          = $all_blocks[ $from_raw_index ];

		array_splice( $all_blocks, $from_raw_index, 1 );
		if ( $from_raw_index < $to_raw_index ) {
			$to_raw_index--;
		}
		array_splice( $all_blocks, $to_raw_index, 0, [ $block ] );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( [ 'ID' => $post_id, 'post_content' => $content ], true );
		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'moved'  => true,
			'before' => $before,
			'after'  => [
				'post_id'      => $post_id,
				'post_content' => get_post( $post_id )->post_content,
				'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
			],
		];
	}

	/**
	 * wp_delete_block handler.
	 */
	public function delete_block( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$index   = absint( $input['index'] ?? 0 );
		$post    = get_post( $post_id );
		$all_blocks = $this->get_all_blocks( $post_id );
		$visible    = $this->get_visible_blocks( $post_id );

		if ( empty( $input['confirm'] ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		if ( ! $post || empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		if ( $index >= count( $visible ) ) {
			throw new Frontman_Tool_Error( "Block index {$index} out of range" );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'block'        => $this->read_block( [ 'post_id' => $post_id, 'index' => $index ] ),
			'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
		];

		array_splice( $all_blocks, $visible[ $index ]['raw_index'], 1 );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( [ 'ID' => $post_id, 'post_content' => $content ], true );
		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'deleted' => true,
			'before'  => $before,
			'after'   => [
				'post_id'      => $post_id,
				'post_content' => get_post( $post_id )->post_content,
				'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
			],
		];
	}
}
