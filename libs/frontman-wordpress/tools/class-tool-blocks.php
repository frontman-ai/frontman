<?php

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}


class Frontman_Tool_Blocks {
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_blocks',
			'Lists Gutenberg blocks in a post. The blocks field preserves top-level indices; all_blocks recursively includes every named block with its path.',
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
					'path'    => $this->path_schema( 'Raw block-tree path returned by wp_list_blocks. Use this for nested blocks.' ),
				],
				'required' => [ 'post_id' ],
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
					'path'         => $this->path_schema( 'Raw block-tree path returned by wp_list_blocks. Use this for nested blocks.' ),
					'block_markup' => [
						'type'        => 'string',
						'description' => 'The new block markup (HTML with Gutenberg block comments, e.g. <!-- wp:paragraph --><p>Hello</p><!-- /wp:paragraph -->).',
					],
				],
				'required' => [ 'post_id', 'block_markup' ],
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
					'parent_path'  => $this->path_schema( 'Raw path of the parent block. Omit to insert at the top level.' ),
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
					'from_path'  => $this->path_schema( 'Raw source path returned by wp_list_blocks.' ),
					'to_parent_path' => $this->path_schema( 'Raw destination parent path. Omit for the top level.' ),
				],
				'required' => [ 'post_id', 'to_index' ],
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
					'path'     => $this->path_schema( 'Raw block-tree path returned by wp_list_blocks. Use this for nested blocks.' ),
					'confirm'  => [ 'type' => 'boolean', 'description' => 'Must be true only after the user explicitly confirms deletion.' ],
				],
				'required' => [ 'post_id', 'confirm' ],
			],
			[ $this, 'delete_block' ]
		) );
	}

	private function path_schema( string $description ): array {
		return [
			'type'        => 'array',
			'description' => $description,
			'items'       => [ 'type' => 'integer' ],
		];
	}

	private function get_all_blocks( int $post_id ): array {
		$post = get_post( $post_id );
		if ( ! $post ) {
			return [];
		}

		return parse_blocks( $post->post_content );
	}

	private function get_visible_blocks( int $post_id ): array {
		$visible = [];
		$this->append_visible_blocks( $this->get_all_blocks( $post_id ), [], $visible );
		return $visible;
	}

	private function append_visible_blocks( array $blocks, array $parent_path, array &$visible ): void {
		$top_level_index = 0;
		foreach ( $blocks as $raw_index => $block ) {
			$path = array_merge( $parent_path, [ $raw_index ] );
			if ( ! empty( $block['blockName'] ) ) {
				$entry = [ 'path' => $path, 'block' => $block ];
				if ( empty( $parent_path ) ) {
					$entry['index'] = $top_level_index;
					$top_level_index++;
				}
				$visible[] = $entry;
			}

			if ( ! empty( $block['innerBlocks'] ) && is_array( $block['innerBlocks'] ) ) {
				$this->append_visible_blocks( $block['innerBlocks'], $path, $visible );
			}
		}
	}

	private function resolve_visible_block( int $post_id, int $index ): array {
		$visible = array_values( array_filter( $this->get_visible_blocks( $post_id ), static function( array $entry ) {
			return 1 === count( $entry['path'] );
		} ) );
		if ( empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		if ( $index >= count( $visible ) ) {
			throw new Frontman_Tool_Error( "Block index {$index} out of range (post has " . count( $visible ) . ' blocks)' );
		}

		return $visible[ $index ];
	}

	private function resolve_block( int $post_id, array $input, string $index_key = 'index', string $path_key = 'path' ): array {
		if ( isset( $input[ $path_key ] ) ) {
			$path = $this->sanitize_path( $input[ $path_key ] );
			$block = $this->block_at_path( $this->get_all_blocks( $post_id ), $path );
			if ( empty( $block['blockName'] ) ) {
				throw new Frontman_Tool_Error( 'Block path does not identify a named block' );
			}
			if ( 1 === count( $path ) ) {
				foreach ( $this->get_visible_blocks( $post_id ) as $entry ) {
					if ( isset( $entry['index'] ) && $path === $entry['path'] ) {
						return $entry;
					}
				}
			}
			return [ 'path' => $path, 'block' => $block ];
		}

		if ( ! isset( $input[ $index_key ] ) ) {
			throw new Frontman_Tool_Error( "Provide {$index_key} or {$path_key}" );
		}

		return $this->resolve_visible_block( $post_id, absint( $input[ $index_key ] ) );
	}

	private function sanitize_path( $path, bool $allow_empty = false ): array {
		if ( ! is_array( $path ) || ( empty( $path ) && ! $allow_empty ) ) {
			throw new Frontman_Tool_Error( 'Block path must be a non-empty array of indices' );
		}

		return array_map( 'absint', array_values( $path ) );
	}

	private function block_at_path( array $blocks, array $path ): array {
		$cursor = $blocks;
		$block  = null;
		foreach ( $path as $raw_index ) {
			if ( ! isset( $cursor[ $raw_index ] ) || ! is_array( $cursor[ $raw_index ] ) ) {
				throw new Frontman_Tool_Error( 'Block path is out of range' );
			}
			$block  = $cursor[ $raw_index ];
			$cursor = isset( $block['innerBlocks'] ) && is_array( $block['innerBlocks'] ) ? $block['innerBlocks'] : [];
		}

		return $block;
	}

	private function replace_block_at_path( array &$blocks, array $path, array $replacement ): void {
		$raw_index = array_shift( $path );
		if ( empty( $path ) ) {
			$blocks[ $raw_index ] = $replacement;
			return;
		}

		$this->replace_block_at_path( $blocks[ $raw_index ]['innerBlocks'], $path, $replacement );
	}

	private function remove_block_at_path( array &$blocks, array $path ): array {
		$raw_index = array_shift( $path );
		if ( empty( $path ) ) {
			$removed = $blocks[ $raw_index ];
			array_splice( $blocks, $raw_index, 1 );
			return $removed;
		}

		$child_index = $path[0];
		$removed = $this->remove_block_at_path( $blocks[ $raw_index ]['innerBlocks'], $path );
		if ( 1 === count( $path ) ) {
			$this->remove_inner_content_slot( $blocks[ $raw_index ], $child_index );
		}
		return $removed;
	}

	private function insert_block_at_path( array &$blocks, array $parent_path, int $index, array $block ): void {
		if ( empty( $parent_path ) ) {
			array_splice( $blocks, $index, 0, [ $block ] );
			return;
		}

		$raw_index = array_shift( $parent_path );
		if ( empty( $parent_path ) ) {
			$inner_content = $blocks[ $raw_index ]['innerContent'] ?? null;
			if ( ! is_array( $inner_content ) || ! in_array( null, $inner_content, true ) ) {
				throw new Frontman_Tool_Error( 'Parent block does not support nested blocks' );
			}
			$children = $blocks[ $raw_index ]['innerBlocks'] ?? [];
			$index = min( $index, count( $children ) );
			array_splice( $children, $index, 0, [ $block ] );
			$blocks[ $raw_index ]['innerBlocks'] = $children;
			$this->insert_inner_content_slot( $blocks[ $raw_index ], $index );
			return;
		}

		$this->insert_block_at_path( $blocks[ $raw_index ]['innerBlocks'], $parent_path, $index, $block );
	}

	private function remove_inner_content_slot( array &$parent, int $child_index ): void {
		$parent['innerContent'] = isset( $parent['innerContent'] ) && is_array( $parent['innerContent'] ) ? $parent['innerContent'] : [];
		$seen = 0;
		foreach ( $parent['innerContent'] as $content_index => $chunk ) {
			if ( null === $chunk ) {
				if ( $seen === $child_index ) {
					array_splice( $parent['innerContent'], $content_index, 1 );
					return;
				}
				$seen++;
			}
		}
	}

	private function insert_inner_content_slot( array &$parent, int $child_index ): void {
		$parent['innerContent'] = isset( $parent['innerContent'] ) && is_array( $parent['innerContent'] ) ? $parent['innerContent'] : [];
		$seen = 0;
		foreach ( $parent['innerContent'] as $content_index => $chunk ) {
			if ( null === $chunk ) {
				if ( $seen === $child_index ) {
					array_splice( $parent['innerContent'], $content_index, 0, [ null ] );
					return;
				}
				$seen++;
			}
		}

		$insert_at = max( count( $parent['innerContent'] ) - 1, 0 );
		array_splice( $parent['innerContent'], $insert_at, 0, [ null ] );
	}

	private function adjust_path_after_removal( array $path, array $removed_path ): array {
		$removed_parent = array_slice( $removed_path, 0, -1 );
		$removed_index = $removed_path[ count( $removed_path ) - 1 ];
		if ( count( $path ) <= count( $removed_parent ) || array_slice( $path, 0, count( $removed_parent ) ) !== $removed_parent ) {
			return $path;
		}

		$affected_depth = count( $removed_parent );
		if ( $path[ $affected_depth ] > $removed_index ) {
			$path[ $affected_depth ]--;
		}
		return $path;
	}

	private function serialize_blocks( array $blocks ): string {
		return implode( "\n\n", array_map( 'serialize_block', $blocks ) );
	}

	private function summarize_block( array $entry ): array {
		$summary = [
			'path'       => $entry['path'],
			'name'       => $entry['block']['blockName'],
			'attributes' => $entry['block']['attrs'] ?? [],
			'innerText'  => wp_strip_all_tags( $entry['block']['innerHTML'] ?? '' ),
		];
		if ( isset( $entry['index'] ) ) {
			$summary['index'] = $entry['index'];
		}
		return $summary;
	}

	public function list_blocks( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$post    = get_post( $post_id );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found: {$post_id}" );
		}

		$visible = $this->get_visible_blocks( $post_id );
		$top_level = array_values( array_filter( $visible, static function( array $entry ) {
			return 1 === count( $entry['path'] );
		} ) );
		return [
			'post_id'           => $post_id,
			'block_count'       => count( $top_level ),
			'blocks'            => array_map( [ $this, 'summarize_block' ], $top_level ),
			'total_block_count' => count( $visible ),
			'all_blocks'        => array_map( [ $this, 'summarize_block' ], $visible ),
		];
	}

	public function read_block( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$entry  = $this->resolve_block( $post_id, $input );
		$block  = $entry['block'];

		$result = [
			'path'         => $entry['path'],
			'name'         => $block['blockName'],
			'attributes'   => $block['attrs'] ?? [],
			'innerHTML'    => $block['innerHTML'] ?? '',
			'innerContent' => $block['innerContent'] ?? [],
			'markup'       => serialize_block( $block ),
		];
		if ( isset( $entry['index'] ) ) {
			$result['index'] = $entry['index'];
		}
		return $result;
	}

	public function update_block( array $input ): array {
		$post_id      = absint( $input['post_id'] ?? 0 );
		$block_markup = $input['block_markup'] ?? '';
		$post         = get_post( $post_id );

		$all_blocks = $this->get_all_blocks( $post_id );
		$entry      = $this->resolve_block( $post_id, $input );

		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'block'        => $this->read_block( [ 'post_id' => $post_id, 'path' => $entry['path'] ] ),
		];

		$new_blocks = parse_blocks( $block_markup );
		$new_block  = array_values( array_filter( $new_blocks, function( $b ) { return ! empty( $b['blockName'] ); } ) );

		if ( empty( $new_block ) ) {
			throw new Frontman_Tool_Error( 'Invalid block markup' );
		}

		$this->replace_block_at_path( $all_blocks, $entry['path'], $new_block[0] );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( wp_slash( [ 'ID' => $post_id, 'post_content' => $content ] ), true );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'updated' => true,
			'before'  => $before,
			'after'   => [
				'post_id'      => $post_id,
				'post_content' => get_post( $post_id )->post_content,
				'block'        => $this->read_block( [ 'post_id' => $post_id, 'path' => $entry['path'] ] ),
			],
		];
	}

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
		$visible    = array_values( array_filter( $this->get_visible_blocks( $post_id ), static function( array $entry ) { return 1 === count( $entry['path'] ); } ) );

		$new_blocks = parse_blocks( $block_markup );
		$new_block  = array_values( array_filter( $new_blocks, function( $b ) { return ! empty( $b['blockName'] ); } ) );

		if ( empty( $new_block ) ) {
			throw new Frontman_Tool_Error( 'Invalid block markup' );
		}

		$parent_path = isset( $input['parent_path'] ) ? $this->sanitize_path( $input['parent_path'] ) : [];
		if ( empty( $parent_path ) ) {
			$index = isset( $input['index'] ) ? absint( $input['index'] ) : count( $visible );
			$index = min( $index, count( $visible ) );
			$raw_index = $index >= count( $visible ) ? count( $all_blocks ) : $visible[ $index ]['path'][0];
		} else {
			$parent = $this->block_at_path( $all_blocks, $parent_path );
			$index = min( absint( $input['index'] ?? count( $parent['innerBlocks'] ?? [] ) ), count( $parent['innerBlocks'] ?? [] ) );
			$raw_index = $index;
		}

		$this->insert_block_at_path( $all_blocks, $parent_path, $raw_index, $new_block[0] );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( wp_slash( [ 'ID' => $post_id, 'post_content' => $content ] ), true );

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

	public function move_block( array $input ): array {
		$post_id    = absint( $input['post_id'] ?? 0 );
		$to_index   = absint( $input['to_index'] ?? 0 );
		$post       = get_post( $post_id );
		$all_blocks = $this->get_all_blocks( $post_id );
		$visible    = array_values( array_filter( $this->get_visible_blocks( $post_id ), static function( array $entry ) { return 1 === count( $entry['path'] ); } ) );

		if ( ! $post || empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		$source = $this->resolve_block( $post_id, $input, 'from_index', 'from_path' );
		$from_path = $source['path'];
		$to_parent_path = isset( $input['to_parent_path'] ) ? $this->sanitize_path( $input['to_parent_path'] ) : [];
		$is_legacy_move = ! isset( $input['from_path'] );
		if ( $is_legacy_move ) {
			if ( ! empty( $to_parent_path ) || $to_index >= count( $visible ) ) {
				throw new Frontman_Tool_Error( 'Block move indices are out of range' );
			}
			$to_index = $visible[ $to_index ]['path'][0];
		}
		if ( count( $to_parent_path ) >= count( $from_path ) && array_slice( $to_parent_path, 0, count( $from_path ) ) === $from_path ) {
			throw new Frontman_Tool_Error( 'Cannot move a block into itself or one of its descendants' );
		}
		$destination_parent = empty( $to_parent_path ) ? [ 'innerBlocks' => $all_blocks ] : $this->block_at_path( $all_blocks, $to_parent_path );
		if ( $to_index > count( $destination_parent['innerBlocks'] ?? [] ) ) {
			throw new Frontman_Tool_Error( 'Block move destination is out of range' );
		}

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
		];

		$from_parent_path = array_slice( $from_path, 0, -1 );
		$from_raw_index = $from_path[ count( $from_path ) - 1 ];
		$block = $this->remove_block_at_path( $all_blocks, $from_path );
		$to_parent_path = $this->adjust_path_after_removal( $to_parent_path, $from_path );
		if ( $is_legacy_move && $from_parent_path === $to_parent_path && $from_raw_index < $to_index ) {
			$to_index--;
		}
		$this->insert_block_at_path( $all_blocks, $to_parent_path, $to_index, $block );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( wp_slash( [ 'ID' => $post_id, 'post_content' => $content ] ), true );
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

	public function delete_block( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		$post    = get_post( $post_id );
		$all_blocks = $this->get_all_blocks( $post_id );
		$visible    = $this->get_visible_blocks( $post_id );

		if ( empty( $input['confirm'] ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		if ( ! $post || empty( $visible ) ) {
			throw new Frontman_Tool_Error( "Post not found or has no blocks: {$post_id}" );
		}

		$entry = $this->resolve_block( $post_id, $input );

		$before = [
			'post_id'      => $post_id,
			'post_content' => $post->post_content,
			'block'        => $this->read_block( [ 'post_id' => $post_id, 'path' => $entry['path'] ] ),
			'blocks'       => $this->list_blocks( [ 'post_id' => $post_id ] ),
		];

		$this->remove_block_at_path( $all_blocks, $entry['path'] );
		$content = $this->serialize_blocks( $all_blocks );

		$result = wp_update_post( wp_slash( [ 'ID' => $post_id, 'post_content' => $content ] ), true );
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
