<?php
/**
 * Elementor tools for reading and editing Elementor page data.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Elementor {
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_pages',
			'Lists WordPress pages and whether each page has Elementor builder data. Use this to find the post_id for Elementor tools.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_type' => [ 'type' => 'string', 'default' => 'page' ],
					'per_page'  => [ 'type' => 'integer', 'default' => 100 ],
				],
			],
			[ $this, 'list_pages' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_page_structure',
			'Gets a compact Elementor page tree with element IDs, element types, widget types, and key text/style hints. Start here before editing Elementor content.',
			$this->post_id_schema(),
			[ $this, 'get_page_structure' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_page_data',
			'Gets the full Elementor element tree for a post. Prefer wp_elementor_get_page_structure unless you need complete settings.',
			$this->post_id_schema(),
			[ $this, 'get_page_data' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_save_page_data',
			'Replaces the full Elementor element tree for a post after saving the previous tree as a private rollback snapshot. Ask the user for confirmation first and only call with confirm=true after approval. Use granular element tools when possible; call wp_elementor_flush_css after visual changes.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id' => [ 'type' => 'integer' ],
					'data'    => [
						'type'        => 'array',
						'description' => 'Full Elementor element tree.',
						'items'       => [
							'type'                 => 'object',
							'additionalProperties' => true,
							'properties'           => new \stdClass(),
						],
					],
					'confirm' => [ 'type' => 'boolean', 'description' => 'Must be true only after the user explicitly confirms replacing the full Elementor page data.' ],
				],
				'required'             => [ 'post_id', 'data', 'confirm' ],
			],
			[ $this, 'save_page_data' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_element',
			'Gets one Elementor element by post_id and element_id. Selected Elementor elements include these IDs in the selected-element context.',
			$this->element_id_schema(),
			[ $this, 'get_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_update_element',
			'Updates one Elementor element after saving a private rollback snapshot. For normal Elementor elements, merge changed settings. For Elementor HTML widgets, provide old_html and new_html to replace an exact fragment inside settings.html; the tool inspects the element type and applies the correct update path.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'settings'   => [
						'type'                 => 'object',
						'description'          => 'Elementor settings keys to merge for non-HTML-fragment updates.',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
					'old_html'   => [ 'type' => 'string', 'description' => 'Exact HTML fragment currently present in an Elementor HTML widget settings.html.' ],
					'new_html'   => [ 'type' => 'string', 'description' => 'Replacement HTML fragment for an Elementor HTML widget. Use an empty string to remove the exact fragment.' ],
					'occurrence' => [ 'type' => 'integer', 'description' => '1-based occurrence to replace when old_html appears more than once.' ],
				],
				'required'             => [ 'post_id', 'element_id' ],
			],
			[ $this, 'update_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_add_element',
			'Adds a new Elementor element at the root or inside a parent container after saving the previous page tree as a private rollback snapshot. Use wp_elementor_generate_element or widget schema output to build valid element JSON.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element'    => [
						'type'                 => 'object',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
					'parent_id'  => [ 'type' => 'string' ],
					'position'   => [ 'type' => 'integer', 'default' => -1 ],
				],
				'required'             => [ 'post_id', 'element' ],
			],
			[ $this, 'add_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_remove_element',
			'Removes a whole Elementor element and all of its children after saving the previous element as a private rollback snapshot. Only use when the user explicitly requested removing the whole Elementor widget/container. Ask the user for confirmation first and only call with confirm=true after approval.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'scope'      => [ 'type' => 'string', 'enum' => [ 'whole_element' ], 'description' => 'Must be whole_element to confirm the intent is deleting the complete Elementor element, not nested rendered DOM.' ],
					'confirm'    => [ 'type' => 'boolean' ],
				],
				'required'             => [ 'post_id', 'element_id', 'scope', 'confirm' ],
			],
			[ $this, 'remove_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_rollbacks',
			'Lists private Elementor rollback snapshots for a post. Use this to find rollback_id values before restoring.',
			$this->post_id_schema(),
			[ $this, 'list_rollbacks' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_restore_rollback',
			'Restores a private Elementor rollback snapshot by rollback_id. Ask the user for confirmation first and only call with confirm=true after approval. Restore one rollback at a time; wait for the result before restoring another rollback.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'     => [ 'type' => 'integer' ],
					'rollback_id' => [ 'type' => 'string' ],
					'confirm'     => [ 'type' => 'boolean' ],
				],
				'required'             => [ 'post_id', 'rollback_id', 'confirm' ],
			],
			[ $this, 'restore_rollback' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_duplicate_element',
			'Duplicates an Elementor element next to the original after saving the previous page tree as a private rollback snapshot, assigning new IDs to the clone and its children.',
			$this->element_id_schema(),
			[ $this, 'duplicate_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_move_element',
			'Moves an Elementor element to the root or into another parent element at a position after saving the previous page tree as a private rollback snapshot. position=-1 appends.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'parent_id'  => [ 'type' => 'string' ],
					'position'   => [ 'type' => 'integer', 'default' => -1 ],
				],
				'required'             => [ 'post_id', 'element_id' ],
			],
			[ $this, 'move_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_generate_element',
			'Generates a valid Elementor element JSON object. Supports container, row, column, heading, text, image, button, and generic widget.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'type'          => [
						'type' => 'string',
						'enum' => [ 'container', 'row', 'column', 'heading', 'text', 'image', 'button', 'widget' ],
					],
					'settings'      => [
						'type'                 => 'object',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
					'children'      => [
						'type'  => 'array',
						'items' => [
							'type'                 => 'object',
							'additionalProperties' => true,
							'properties'           => new \stdClass(),
						],
					],
					'widget_type'   => [ 'type' => 'string' ],
					'is_inner'      => [ 'type' => 'boolean', 'default' => false ],
					'width'         => [ 'type' => 'number', 'default' => 50 ],
					'title'         => [ 'type' => 'string' ],
					'tag'           => [ 'type' => 'string', 'default' => 'h2' ],
					'content'       => [ 'type' => 'string' ],
					'attachment_id' => [ 'type' => 'integer' ],
					'button_text'   => [ 'type' => 'string', 'default' => 'Click' ],
					'url'           => [ 'type' => 'string', 'default' => '#' ],
				],
				'required'             => [ 'type' ],
			],
			[ $this, 'generate_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_widgets',
			'Lists registered Elementor widgets with names, titles, icons, and categories.',
			[ 'type' => 'object', 'additionalProperties' => false, 'properties' => new \stdClass() ],
			[ $this, 'list_widgets' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_widget_schema',
			'Gets Elementor control schema for one widget type. Use before creating or updating unfamiliar widget settings.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [ 'widget_name' => [ 'type' => 'string' ] ],
				'required'             => [ 'widget_name' ],
			],
			[ $this, 'get_widget_schema' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_flush_css',
			'Flushes Elementor CSS cache. Call this after Elementor visual changes so the preview reflects the update.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [ 'post_id' => [ 'type' => 'integer' ] ],
			],
			[ $this, 'flush_css' ]
		) );
	}

	public function list_pages( array $input ): array {
		$post_type = sanitize_key( $input['post_type'] ?? 'page' );
		$per_page  = min( max( absint( $input['per_page'] ?? 100 ), 1 ), 200 );
		$posts     = get_posts(
			[
				'post_type'      => $post_type,
				'post_status'    => [ 'publish', 'draft', 'pending', 'private' ],
				'posts_per_page' => $per_page,
				'orderby'        => 'menu_order title',
				'order'          => 'ASC',
			]
		);

		return [
			'pages' => array_map(
				function ( $post ) {
					return [
						'post_id'       => (int) $post->ID,
						'title'         => $post->post_title,
						'slug'          => $post->post_name,
						'status'        => $post->post_status,
						'url'           => get_permalink( $post->ID ),
						'has_elementor' => Frontman_Elementor_Data::post_uses_elementor( (int) $post->ID ),
					];
				},
				$posts
			),
		];
	}

	public function get_page_structure( array $input ): array {
		$post_id   = $this->require_post_id( $input );
		$structure = Frontman_Elementor_Data::get_page_structure( $post_id );
		if ( null === $structure ) {
			throw new Frontman_Tool_Error( 'No Elementor data found for post_id ' . $post_id );
		}

		return [ 'post_id' => $post_id, 'title' => get_the_title( $post_id ), 'structure' => $structure ];
	}

	public function get_page_data( array $input ): array {
		$post_id = $this->require_post_id( $input );
		$data    = $this->require_page_data( $post_id );
		return [ 'post_id' => $post_id, 'title' => get_the_title( $post_id ), 'data' => $data ];
	}

	public function save_page_data( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Full Elementor page replacement requires confirm=true after user approval.' );
		}

		$post_id = $this->require_post_id( $input );
		$data    = $input['data'] ?? null;
		if ( ! is_array( $data ) ) {
			throw new Frontman_Tool_Error( 'data must be an Elementor element tree array.' );
		}
		$this->validate_full_element_tree( $data );

		$current  = Frontman_Elementor_Data::get_page_data( $post_id );
		$rollback = is_array( $current ) ? Frontman_Elementor_Data::make_page_rollback( 'saved_page_data', $current ) : null;
		if ( null !== $rollback ) {
			Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		}
		$this->save_elementor_data( $post_id, $data );

		return [ 'success' => true, 'post_id' => $post_id, 'sections' => count( $data ), 'rollback_id' => $rollback['rollback_id'] ?? null ];
	}

	public function get_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$element    = Frontman_Elementor_Data::get_element( $this->require_page_data( $post_id ), $element_id );
		if ( null === $element ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		return $element;
	}

	public function update_element( array $input ): array {
		$post_id      = $this->require_post_id( $input );
		$element_id   = $this->require_element_id( $input );
		$has_settings = array_key_exists( 'settings', $input );
		$has_old_html = array_key_exists( 'old_html', $input );
		$has_new_html = array_key_exists( 'new_html', $input );
		$has_fragment = $has_old_html || $has_new_html;

		if ( ! $has_settings && ! $has_fragment ) {
			throw new Frontman_Tool_Error( 'Provide settings or old_html/new_html changes.' );
		}
		if ( $has_settings && ! is_array( $input['settings'] ) ) {
			throw new Frontman_Tool_Error( 'settings must be an object.' );
		}
		if ( $has_fragment && ( ! $has_old_html || ! $has_new_html ) ) {
			throw new Frontman_Tool_Error( 'old_html and new_html must be provided together.' );
		}

		$settings = $has_settings ? $input['settings'] : [];
		$old_html = $has_old_html ? (string) $input['old_html'] : '';
		$new_html = $has_new_html ? (string) $input['new_html'] : '';

		if ( $has_fragment && '' === $old_html ) {
			throw new Frontman_Tool_Error( 'old_html must be a non-empty exact fragment.' );
		}
		if ( $has_fragment && [] !== $settings ) {
			throw new Frontman_Tool_Error( 'Use either settings or old_html/new_html in one update call.' );
		}
		if ( ! $has_fragment && [] === $settings ) {
			throw new Frontman_Tool_Error( 'settings must include at least one changed setting.' );
		}

		$data    = $this->require_page_data( $post_id );
		$element = Frontman_Elementor_Data::get_element( $data, $element_id );
		if ( null === $element ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		$is_html_widget = 'widget' === (string) ( $element['elType'] ?? '' ) && 'html' === (string) ( $element['widgetType'] ?? '' );

		if ( $has_fragment ) {
			if ( ! $is_html_widget ) {
				throw new Frontman_Tool_Error( 'old_html/new_html can only be used with Elementor HTML widgets: ' . $element_id );
			}

			return $this->update_html_fragment( $post_id, $data, $element_id, $element, $old_html, $new_html, $input );
		}

		$current_settings = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
		if ( $is_html_widget && array_key_exists( 'html', $settings ) ) {
			throw new Frontman_Tool_Error( 'Use old_html and new_html on wp_elementor_update_element to edit an Elementor HTML widget settings.html fragment.' );
		}
		if ( array_merge( $current_settings, $settings ) === $current_settings ) {
			throw new Frontman_Tool_Error( 'settings do not change the Elementor element.' );
		}

		$rollback = Frontman_Elementor_Data::make_element_rollback( 'updated', $data, $element_id );
		if ( null === $rollback ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		if ( ! Frontman_Elementor_Data::update_element_settings( $data, $element_id, $settings ) ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	private function update_html_fragment( int $post_id, array &$data, string $element_id, array $element, string $old_html, string $new_html, array $input ): array {
		$settings = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
		$html     = $settings['html'] ?? null;
		if ( ! is_string( $html ) ) {
			throw new Frontman_Tool_Error( 'Elementor HTML widget does not have a settings.html string.' );
		}

		$matches = substr_count( $html, $old_html );
		if ( 0 === $matches ) {
			throw new Frontman_Tool_Error( 'old_html fragment was not found in settings.html for Elementor HTML widget ' . $element_id . '. Inspect sibling HTML widgets before retrying.' );
		}

		$has_occurrence = array_key_exists( 'occurrence', $input );
		$occurrence     = $has_occurrence ? (int) $input['occurrence'] : 1;
		if ( $matches > 1 && ! $has_occurrence ) {
			throw new Frontman_Tool_Error( 'old_html fragment appears more than once; provide occurrence to choose which match to replace.' );
		}
		if ( $occurrence < 1 || $occurrence > $matches ) {
			throw new Frontman_Tool_Error( 'occurrence must be between 1 and ' . $matches . '.' );
		}
		if ( trim( $old_html ) === trim( $html ) && '' === trim( $new_html ) ) {
			throw new Frontman_Tool_Error( 'Refusing to delete the entire settings.html value with old_html/new_html.' );
		}

		$updated_html = $this->replace_nth_occurrence( $html, $old_html, $new_html, $occurrence );
		if ( null === $updated_html || $updated_html === $html ) {
			throw new Frontman_Tool_Error( 'Replacement does not change settings.html.' );
		}

		$rollback = Frontman_Elementor_Data::make_element_rollback( 'updated_html_fragment', $data, $element_id );
		if ( null === $rollback ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		if ( ! Frontman_Elementor_Data::update_element_settings( $data, $element_id, [ 'html' => $updated_html ] ) ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [
			'success'           => true,
			'post_id'           => $post_id,
			'element_id'        => $element_id,
			'occurrence'        => $occurrence,
			'matches_before'    => $matches,
			'matches_remaining' => substr_count( $updated_html, $old_html ),
			'rollback_id'       => $rollback['rollback_id'],
		];
	}

	public function add_element( array $input ): array {
		$post_id = $this->require_post_id( $input );
		$element = $input['element'] ?? null;
		if ( ! is_array( $element ) ) {
			throw new Frontman_Tool_Error( 'element must be an object.' );
		}
		if ( empty( $element['id'] ) ) {
			$element['id'] = Frontman_Elementor_Data::generate_id();
		}

		$data      = Frontman_Elementor_Data::get_page_data( $post_id ) ?? [];
		$rollback  = Frontman_Elementor_Data::make_page_rollback( 'added_element', $data );
		$parent_id = isset( $input['parent_id'] ) ? sanitize_text_field( $input['parent_id'] ) : null;
		$position  = (int) ( $input['position'] ?? -1 );
		if ( ! Frontman_Elementor_Data::insert_element( $data, $element, $parent_id, $position ) ) {
			throw new Frontman_Tool_Error( 'Parent element not found: ' . $parent_id );
		}
		$this->validate_full_element_tree( $data );

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element['id'] ?? '', 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function remove_element( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Element removal requires confirm=true after user approval.' );
		}
		if ( 'whole_element' !== sanitize_key( $input['scope'] ?? '' ) ) {
			throw new Frontman_Tool_Error( 'Element removal requires scope=whole_element to confirm the whole Elementor element should be deleted.' );
		}

		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_element_rollback( 'removed', $data, $element_id );
		if ( null === $rollback ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		if ( ! Frontman_Elementor_Data::remove_element( $data, $element_id ) ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function list_rollbacks( array $input ): array {
		$post_id = $this->require_post_id( $input );
		return [ 'post_id' => $post_id, 'rollbacks' => Frontman_Elementor_Data::list_rollbacks( $post_id ) ];
	}

	public function restore_rollback( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Rollback restore requires confirm=true after user approval.' );
		}

		$post_id     = $this->require_post_id( $input );
		$rollback_id = $this->require_rollback_id( $input );
		$result      = Frontman_Elementor_Data::restore_rollback( $post_id, $rollback_id );
		if ( null === $result ) {
			throw new Frontman_Tool_Error( 'Rollback not found: ' . $rollback_id );
		}
		if ( empty( $result['success'] ) ) {
			throw new Frontman_Tool_Error( $result['error'] ?? 'Unable to restore rollback.' );
		}

		return array_merge( [ 'post_id' => $post_id ], $result );
	}

	public function duplicate_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_page_rollback( 'duplicated_element', $data );
		$new_id     = Frontman_Elementor_Data::duplicate_element( $data, $element_id );
		if ( null === $new_id ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'new_element_id' => $new_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function move_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$parent_id  = isset( $input['parent_id'] ) ? sanitize_text_field( $input['parent_id'] ) : null;
		$position   = (int) ( $input['position'] ?? -1 );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_page_rollback( 'moved_element', $data );
		if ( ! Frontman_Elementor_Data::move_element( $data, $element_id, $parent_id, $position ) ) {
			throw new Frontman_Tool_Error( 'Unable to move element: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'parent_id' => $parent_id, 'position' => $position, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function generate_element( array $input ): array {
		return Frontman_Elementor_Data::generate_element( $input );
	}

	public function list_widgets( array $input ): array {
		return [ 'widgets' => Frontman_Elementor_Data::list_widgets() ];
	}

	public function get_widget_schema( array $input ): array {
		$widget_name = sanitize_key( $input['widget_name'] ?? '' );
		if ( '' === $widget_name ) {
			throw new Frontman_Tool_Error( 'widget_name is required.' );
		}

		$schema = Frontman_Elementor_Data::get_widget_schema( $widget_name );
		if ( null === $schema ) {
			throw new Frontman_Tool_Error( 'Widget not found or Elementor is not loaded: ' . $widget_name );
		}

		return [ 'widget_name' => $widget_name, 'schema' => $schema ];
	}

	public function flush_css( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		Frontman_Elementor_Data::flush_css( $post_id );
		return [ 'success' => true, 'scope' => $post_id > 0 ? 'post-' . $post_id : 'all' ];
	}

	private function post_id_schema(): array {
		return [
			'type'                 => 'object',
			'additionalProperties' => false,
			'properties'           => [ 'post_id' => [ 'type' => 'integer', 'description' => 'WordPress post/page ID.' ] ],
			'required'             => [ 'post_id' ],
		];
	}

	private function element_id_schema(): array {
		$schema                                  = $this->post_id_schema();
		$schema['properties']['element_id']      = [ 'type' => 'string', 'description' => 'Elementor element ID from page structure or selected-element context.' ];
		$schema['required']                      = [ 'post_id', 'element_id' ];
		return $schema;
	}

	private function require_post_id( array $input ): int {
		$post_id = absint( $input['post_id'] ?? 0 );
		if ( 0 === $post_id ) {
			throw new Frontman_Tool_Error( 'post_id is required.' );
		}

		return $post_id;
	}

	private function require_element_id( array $input ): string {
		$element_id = sanitize_text_field( $input['element_id'] ?? '' );
		if ( '' === $element_id ) {
			throw new Frontman_Tool_Error( 'element_id is required.' );
		}

		return $element_id;
	}

	private function require_rollback_id( array $input ): string {
		$rollback_id = sanitize_text_field( $input['rollback_id'] ?? '' );
		if ( '' === $rollback_id ) {
			throw new Frontman_Tool_Error( 'rollback_id is required.' );
		}

		return $rollback_id;
	}

	private function save_elementor_data( int $post_id, array $data ): void {
		try {
			Frontman_Elementor_Data::save_page_data( $post_id, $data );
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( 'Failed to save Elementor data: ' . $e->getMessage() );
		}
	}

	private function require_page_data( int $post_id ): array {
		$data = Frontman_Elementor_Data::get_page_data( $post_id );
		if ( null === $data ) {
			throw new Frontman_Tool_Error( 'No Elementor data found for post_id ' . $post_id );
		}

		return $data;
	}

	private function validate_full_element_tree( array $elements ): void {
		if ( [] === $elements ) {
			throw new Frontman_Tool_Error( 'data must contain at least one Elementor element.' );
		}

		$seen_ids = [];
		$this->validate_element_tree( $elements, 'data', $seen_ids );
	}

	private function validate_element_tree( array $elements, string $path, array &$seen_ids ): void {
		foreach ( $elements as $index => $element ) {
			$element_path = $path . '[' . $index . ']';
			if ( ! is_array( $element ) ) {
				throw new Frontman_Tool_Error( $element_path . ' must be an Elementor element object.' );
			}

			$id = $element['id'] ?? '';
			if ( ! is_string( $id ) || '' === trim( $id ) ) {
				throw new Frontman_Tool_Error( $element_path . '.id is required.' );
			}
			if ( isset( $seen_ids[ $id ] ) ) {
				throw new Frontman_Tool_Error( 'Duplicate Elementor element ID: ' . $id );
			}
			$seen_ids[ $id ] = true;

			$el_type = $element['elType'] ?? '';
			if ( ! is_string( $el_type ) || '' === trim( $el_type ) ) {
				throw new Frontman_Tool_Error( $element_path . '.elType is required.' );
			}
			if ( 'widget' === $el_type ) {
				$widget_type = $element['widgetType'] ?? '';
				if ( ! is_string( $widget_type ) || '' === trim( $widget_type ) ) {
					throw new Frontman_Tool_Error( $element_path . '.widgetType is required for widget elements.' );
				}
			}

			if ( isset( $element['settings'] ) && ! is_array( $element['settings'] ) ) {
				throw new Frontman_Tool_Error( $element_path . '.settings must be an object.' );
			}
			if ( isset( $element['elements'] ) ) {
				if ( ! is_array( $element['elements'] ) ) {
					throw new Frontman_Tool_Error( $element_path . '.elements must be an array.' );
				}
				$this->validate_element_tree( $element['elements'], $element_path . '.elements', $seen_ids );
			}
		}
	}

	private function replace_nth_occurrence( string $html, string $old_html, string $new_html, int $occurrence ): ?string {
		$offset   = 0;
		$position = false;
		for ( $index = 1; $index <= $occurrence; $index++ ) {
			$position = strpos( $html, $old_html, $offset );
			if ( false === $position ) {
				return null;
			}
			$offset = $position + strlen( $old_html );
		}

		return substr( $html, 0, $position ) . $new_html . substr( $html, $position + strlen( $old_html ) );
	}
}
