<?php
/**
 * WordPress Menu tools — list and modify navigation menus.
 *
 * Tools: wp_list_menus, wp_list_menu_locations, wp_read_menu, wp_create_menu,
 * wp_delete_menu, wp_assign_menu_location, wp_create_menu_item,
 * wp_update_menu_item, wp_delete_menu_item
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Menus {
	/**
	 * Register all menu tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_menus',
			'Lists all registered navigation menus with their item counts and assigned theme locations.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_menus' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_list_menu_locations',
			'Lists all registered theme menu locations and which menu is assigned to each one.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_menu_locations' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_menu',
			'Reads a single navigation menu with all its items, including URLs, types, and hierarchy.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id' => [
						'type'        => 'integer',
						'description' => 'The menu term ID (from wp_list_menus).',
					],
				],
				'required' => [ 'id' ],
			],
			[ $this, 'read_menu' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_menu',
			'Creates a new navigation menu.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'name' => [
						'type'        => 'string',
						'description' => 'Human-readable menu name.',
					],
				],
				'required' => [ 'name' ],
			],
			[ $this, 'create_menu' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_delete_menu',
			'Deletes a navigation menu. Ask the user for confirmation first and only call this tool with confirm=true after they approve.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'id'      => [
						'type'        => 'integer',
						'description' => 'The menu term ID to delete.',
					],
					'confirm' => [
						'type'        => 'boolean',
						'description' => 'Must be true only after the user explicitly confirms deletion.',
					],
				],
				'required' => [ 'id', 'confirm' ],
			],
			[ $this, 'delete_menu' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_assign_menu_location',
			'Assigns a navigation menu to a theme menu location.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'menu_id'  => [
						'type'        => 'integer',
						'description' => 'The menu term ID to assign.',
					],
					'location' => [
						'type'        => 'string',
						'description' => 'The theme location slug to assign the menu to.',
					],
				],
				'required' => [ 'menu_id', 'location' ],
			],
			[ $this, 'assign_menu_location' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_menu_item',
			'Creates a new custom-link or post/page-backed menu item in a navigation menu. Use post_id for WordPress pages/posts so the menu item keeps proper object metadata.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'menu_id'   => [
						'type'        => 'integer',
						'description' => 'The menu term ID (from wp_list_menus).',
					],
					'title'     => [
						'type'        => 'string',
						'description' => 'Display title for the new menu item.',
					],
					'url'       => [
						'type'        => 'string',
						'description' => 'URL for a custom-link menu item. Do not use with post_id.',
					],
					'post_id'   => [
						'type'        => 'integer',
						'description' => 'Optional WordPress post/page ID for a post-backed menu item.',
					],
					'parent_id' => [
						'type'        => 'integer',
						'description' => 'Optional parent menu item ID.',
					],
					'position'  => [
						'type'        => 'integer',
						'description' => 'Optional 1-based menu position.',
					],
				],
				'required' => [ 'menu_id' ],
			],
			[ $this, 'create_menu_item' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_menu_item',
			'Updates a menu item\'s title, URL, or position while preserving its existing WordPress menu item metadata.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'menu_item_id' => [
						'type'        => 'integer',
						'description' => 'The menu item post ID (from wp_read_menu).',
					],
					'title'        => [
						'type'        => 'string',
						'description' => 'New display title for the menu item.',
					],
					'url'          => [
						'type'        => 'string',
						'description' => 'New URL for custom link menu items. Post-backed menu items keep their post permalink.',
					],
					'position'     => [
						'type'        => 'integer',
						'description' => 'New menu order position (1-based).',
					],
				],
				'required' => [ 'menu_item_id' ],
			],
			[ $this, 'update_menu_item' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_delete_menu_item',
			'Deletes a menu item. Ask the user for confirmation first and only call this tool with confirm=true after they approve.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'menu_item_id' => [
						'type'        => 'integer',
						'description' => 'The menu item post ID to delete.',
					],
					'confirm'      => [
						'type'        => 'boolean',
						'description' => 'Must be true only after the user explicitly confirms deletion.',
					],
				],
				'required' => [ 'menu_item_id', 'confirm' ],
			],
			[ $this, 'delete_menu_item' ]
		) );
	}

	private function get_menu_locations_snapshot(): array {
		$registered = get_registered_nav_menus();
		$assigned   = get_nav_menu_locations();
		$result     = [];

		foreach ( $registered as $location => $label ) {
			$menu_id = isset( $assigned[ $location ] ) ? (int) $assigned[ $location ] : 0;
			$menu    = $menu_id ? wp_get_nav_menu_object( $menu_id ) : null;
			$result[] = [
				'location' => $location,
				'label'    => $label,
				'menu_id'  => $menu_id,
				'menu_name'=> $menu ? $menu->name : null,
			];
		}

		return $result;
	}

	/**
	 * Serialize a menu item for output.
	 */
	private function serialize_menu_item( \WP_Post $item ): array {
		return [
			'id'        => $item->ID,
			'title'     => $item->title,
			'url'       => $item->url,
			'type'      => $item->type,
			'object'    => $item->object,
			'object_id' => (int) $item->object_id,
			'parent'    => (int) $item->menu_item_parent,
			'position'  => (int) $item->menu_order,
		];
	}

	/**
	 * wp_list_menus handler.
	 */
	public function list_menus( array $input ): array {
		$menus  = wp_get_nav_menus();
		$result = [];

		foreach ( $menus as $menu ) {
			$items      = wp_get_nav_menu_items( $menu->term_id ) ?: [];
			$locations  = get_nav_menu_locations();
			$assigned   = array_keys( array_filter( $locations, function( $id ) use ( $menu ) { return (int) $id === (int) $menu->term_id; } ) );

			$result[] = [
				'id'        => $menu->term_id,
				'name'      => $menu->name,
				'slug'      => $menu->slug,
				'count'     => count( $items ),
				'locations' => $assigned,
			];
		}

		return $result;
	}

	/**
	 * wp_list_menu_locations handler.
	 */
	public function list_menu_locations( array $input ): array {
		return $this->get_menu_locations_snapshot();
	}

	/**
	 * wp_read_menu handler.
	 */
	public function read_menu( array $input ): array {
		$id   = absint( $input['id'] ?? 0 );
		$menu = wp_get_nav_menu_object( $id );

		if ( ! $menu ) {
			throw new Frontman_Tool_Error( "Menu not found: {$id}" );
		}

		$items = wp_get_nav_menu_items( $menu->term_id ) ?: [];

		return [
			'id'    => $menu->term_id,
			'name'  => $menu->name,
			'slug'  => $menu->slug,
			'locations' => array_values( array_map(
				static function( array $entry ) {
					return $entry['location'];
				},
				array_filter(
					$this->get_menu_locations_snapshot(),
					static function( array $entry ) use ( $menu ) {
						return (int) $entry['menu_id'] === (int) $menu->term_id;
					}
				)
			) ),
			'items' => array_map( [ $this, 'serialize_menu_item' ], $items ),
		];
	}

	/**
	 * wp_create_menu handler.
	 */
	public function create_menu( array $input ): array {
		$name   = sanitize_text_field( $input['name'] ?? '' );
		$before = $this->list_menus( [] );

		if ( '' === $name ) {
			throw new Frontman_Tool_Error( 'Menu name is required' );
		}

		$menu_id = wp_create_nav_menu( $name );
		if ( is_wp_error( $menu_id ) ) {
			throw new Frontman_Tool_Error( $menu_id->get_error_message() );
		}

		return [
			'created' => true,
			'menu_id' => $menu_id,
			'before'  => $before,
			'after'   => $this->list_menus( [] ),
			'menu'    => $this->read_menu( [ 'id' => $menu_id ] ),
		];
	}

	/**
	 * wp_delete_menu handler.
	 */
	public function delete_menu( array $input ): array {
		$id = absint( $input['id'] ?? 0 );
		if ( empty( $input['confirm'] ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		$menu = wp_get_nav_menu_object( $id );
		if ( ! $menu ) {
			throw new Frontman_Tool_Error( "Menu not found: {$id}" );
		}

		$before = [
			'menu'      => $this->read_menu( [ 'id' => $id ] ),
			'locations' => $this->get_menu_locations_snapshot(),
		];

		$result = wp_delete_nav_menu( $id );
		if ( ! $result ) {
			throw new Frontman_Tool_Error( "Failed to delete menu: {$id}" );
		}

		return [
			'deleted' => true,
			'id'      => $id,
			'before'  => $before,
			'after'   => [
				'menus'     => $this->list_menus( [] ),
				'locations' => $this->get_menu_locations_snapshot(),
			],
		];
	}

	/**
	 * wp_assign_menu_location handler.
	 */
	public function assign_menu_location( array $input ): array {
		$menu_id  = absint( $input['menu_id'] ?? 0 );
		$location = sanitize_key( $input['location'] ?? '' );

		$menu = wp_get_nav_menu_object( $menu_id );
		if ( ! $menu ) {
			throw new Frontman_Tool_Error( "Menu not found: {$menu_id}" );
		}

		$registered = get_registered_nav_menus();
		if ( ! isset( $registered[ $location ] ) ) {
			throw new Frontman_Tool_Error( "Menu location not found: {$location}" );
		}

		$before = $this->get_menu_locations_snapshot();
		$locations = get_nav_menu_locations();
		$locations[ $location ] = $menu_id;
		set_theme_mod( 'nav_menu_locations', $locations );

		return [
			'updated'  => true,
			'location' => $location,
			'menu_id'  => $menu_id,
			'before'   => $before,
			'after'    => $this->get_menu_locations_snapshot(),
		];
	}

	/**
	 * wp_create_menu_item handler.
	 */
	public function create_menu_item( array $input ): array {
		$menu_id = absint( $input['menu_id'] ?? 0 );
		$menu    = wp_get_nav_menu_object( $menu_id );

		if ( ! $menu ) {
			throw new Frontman_Tool_Error( "Menu not found: {$menu_id}" );
		}

		$before = $this->read_menu( [ 'id' => $menu_id ] );

		if ( isset( $input['post_id'] ) && absint( $input['post_id'] ) > 0 ) {
			$post_id = absint( $input['post_id'] );
			$post    = get_post( $post_id );
			if ( ! $post ) {
				throw new Frontman_Tool_Error( "Post not found: {$post_id}" );
			}

			$menu_data = [
				'menu-item-title'     => isset( $input['title'] ) ? sanitize_text_field( $input['title'] ) : $post->post_title,
				'menu-item-url'       => get_permalink( $post_id ),
				'menu-item-type'      => 'post_type',
				'menu-item-object'    => sanitize_key( $post->post_type ),
				'menu-item-object-id' => $post_id,
				'menu-item-status'    => 'publish',
			];
		} else {
			$title = sanitize_text_field( $input['title'] ?? '' );
			$url   = esc_url_raw( $input['url'] ?? '' );

			if ( '' === $title ) {
				throw new Frontman_Tool_Error( 'title is required for custom-link menu items.' );
			}
			if ( '' === $url ) {
				throw new Frontman_Tool_Error( 'url is required for custom-link menu items. Use post_id for WordPress pages/posts.' );
			}

			$menu_data = [
				'menu-item-title'     => $title,
				'menu-item-url'       => $url,
				'menu-item-type'      => 'custom',
				'menu-item-object'    => 'custom',
				'menu-item-object-id' => 0,
				'menu-item-status'    => 'publish',
			];
		}

		if ( isset( $input['parent_id'] ) ) {
			$menu_data['menu-item-parent-id'] = absint( $input['parent_id'] );
		}
		if ( isset( $input['position'] ) ) {
			$menu_data['menu-item-position'] = absint( $input['position'] );
		}

		$result = wp_update_nav_menu_item( $menu_id, 0, wp_slash( $menu_data ) );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		$created = get_post( $result );
		if ( ! $created ) {
			throw new Frontman_Tool_Error( 'Menu item was created but could not be read back.' );
		}

		return [
			'created'      => true,
			'menu_item_id' => $result,
			'before'       => $before,
			'after'        => $this->read_menu( [ 'id' => $menu_id ] ),
			'item'         => $this->serialize_menu_item( wp_setup_nav_menu_item( $created ) ),
		];
	}

	/**
	 * wp_update_menu_item handler.
	 */
	public function update_menu_item( array $input ): array {
		$menu_item_id = absint( $input['menu_item_id'] ?? 0 );
		$item         = get_post( $menu_item_id );

		if ( ! $item || $item->post_type !== 'nav_menu_item' ) {
			throw new Frontman_Tool_Error( "Menu item not found: {$menu_item_id}" );
		}

		$setup_item = wp_setup_nav_menu_item( $item );
		$status     = (string) ( $setup_item->post_status ?? 'publish' );
		$menu_data  = [
			'menu-item-db-id'     => (int) $setup_item->ID,
			'menu-item-title'     => (string) $setup_item->title,
			'menu-item-url'       => (string) $setup_item->url,
			'menu-item-type'      => (string) $setup_item->type,
			'menu-item-object'    => (string) $setup_item->object,
			'menu-item-object-id' => (int) $setup_item->object_id,
			'menu-item-parent-id' => (int) $setup_item->menu_item_parent,
			'menu-item-position'  => (int) $setup_item->menu_order,
			'menu-item-status'    => '' === $status ? 'publish' : $status,
		];
		$changed    = false;

		if ( isset( $input['title'] ) ) {
			$menu_data['menu-item-title'] = sanitize_text_field( $input['title'] );
			$changed = true;
		}
		if ( isset( $input['url'] ) ) {
			if ( 'custom' !== (string) ( $setup_item->type ?? '' ) ) {
				throw new Frontman_Tool_Error( 'Cannot set url on a post-backed menu item. Create a custom-link menu item for arbitrary URLs.' );
			}
			$menu_data['menu-item-url'] = esc_url_raw( $input['url'] );
			$changed = true;
		}
		if ( isset( $input['position'] ) ) {
			$menu_data['menu-item-position'] = absint( $input['position'] );
			$changed = true;
		}

		if ( ! $changed ) {
			throw new Frontman_Tool_Error( 'Provide title, url, or position to update a menu item.' );
		}

		// Get the menu this item belongs to.
		$menus = wp_get_object_terms( $menu_item_id, 'nav_menu' );
		if ( empty( $menus ) ) {
			throw new Frontman_Tool_Error( "Menu item {$menu_item_id} is not assigned to any menu" );
		}

		$before = $this->serialize_menu_item( wp_setup_nav_menu_item( $item ) );

		$result = wp_update_nav_menu_item( $menus[0]->term_id, $menu_item_id, wp_slash( $menu_data ) );

		if ( is_wp_error( $result ) ) {
			throw new Frontman_Tool_Error( $result->get_error_message() );
		}

		return [
			'updated'      => true,
			'menu_item_id' => $result,
			'before'       => $before,
			'after'        => $this->serialize_menu_item( wp_setup_nav_menu_item( get_post( $menu_item_id ) ) ),
		];
	}

	/**
	 * wp_delete_menu_item handler.
	 */
	public function delete_menu_item( array $input ): array {
		$menu_item_id = absint( $input['menu_item_id'] ?? 0 );
		if ( empty( $input['confirm'] ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		$item = get_post( $menu_item_id );
		if ( ! $item || $item->post_type !== 'nav_menu_item' ) {
			throw new Frontman_Tool_Error( "Menu item not found: {$menu_item_id}" );
		}

		$menus = wp_get_object_terms( $menu_item_id, 'nav_menu' );
		if ( empty( $menus ) ) {
			throw new Frontman_Tool_Error( "Menu item {$menu_item_id} is not assigned to any menu" );
		}

		$menu_id = (int) $menus[0]->term_id;
		$before = [
			'menu' => $this->read_menu( [ 'id' => $menu_id ] ),
			'item' => $this->serialize_menu_item( wp_setup_nav_menu_item( $item ) ),
		];

		$result = wp_delete_post( $menu_item_id, true );
		if ( ! $result ) {
			throw new Frontman_Tool_Error( "Failed to delete menu item: {$menu_item_id}" );
		}

		return [
			'deleted'      => true,
			'menu_item_id' => $menu_item_id,
			'before'       => $before,
			'after'        => $this->read_menu( [ 'id' => $menu_id ] ),
		];
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
