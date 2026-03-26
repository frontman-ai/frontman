<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-mutation-tests/' );

$GLOBALS['frontman_test_posts'] = [];
$GLOBALS['frontman_test_options'] = [];
$GLOBALS['frontman_test_menu_terms'] = [];
$GLOBALS['frontman_test_menu_item_to_term'] = [];
$GLOBALS['frontman_test_menu_locations'] = [];
$GLOBALS['frontman_test_registered_menu_locations'] = [];
$GLOBALS['frontman_test_block_templates'] = [];
$GLOBALS['frontman_test_cache_cleared'] = [];

class WP_Post extends stdClass {}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'sanitize_textarea_field' ) ) {
	function sanitize_textarea_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_title' ) ) {
	function sanitize_title( $value ): string {
		return strtolower( trim( preg_replace( '/[^a-zA-Z0-9_\-]+/', '-', (string) $value ), '-' ) );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'wp_strip_all_tags' ) ) {
	function wp_strip_all_tags( $value ): string {
		return strip_tags( (string) $value );
	}
}

if ( ! function_exists( 'absint' ) ) {
	function absint( $value ): int {
		return abs( (int) $value );
	}
}

if ( ! function_exists( 'esc_url_raw' ) ) {
	function esc_url_raw( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( '__' ) ) {
	function __( string $value ): string {
		return $value;
	}
}

if ( ! function_exists( 'is_wp_error' ) ) {
	function is_wp_error( $value ): bool {
		return false;
	}
}

if ( ! function_exists( 'get_permalink' ) ) {
	function get_permalink( $post ): string {
		$id = is_object( $post ) ? $post->ID : $post;
		return 'https://example.com/?p=' . $id;
	}
}

if ( ! function_exists( 'get_post' ) ) {
	function get_post( int $id ) {
		return $GLOBALS['frontman_test_posts'][ $id ] ?? null;
	}
}

if ( ! function_exists( 'wp_insert_post' ) ) {
	function wp_insert_post( array $post_data ) {
		$id = $post_data['ID'] ?? ( count( $GLOBALS['frontman_test_posts'] ) + 1 );
		$post = $GLOBALS['frontman_test_posts'][ $id ] ?? new WP_Post();
		$post->ID = $id;
		$post->post_title = $post_data['post_title'];
		$post->post_content = $post_data['post_content'];
		$post->post_excerpt = $post_data['post_excerpt'] ?? '';
		$post->post_status = $post_data['post_status'];
		$post->post_type = $post_data['post_type'];
		$post->post_date = $post->post_date ?? '2026-03-24 10:00:00';
		$post->post_modified = '2026-03-24 10:00:00';
		$post->post_author = 1;
		$post->post_name = $post_data['post_name'] ?? sanitize_key( $post_data['post_title'] );
		$GLOBALS['frontman_test_posts'][ $id ] = $post;

		if ( in_array( $post->post_type, [ 'wp_template', 'wp_template_part' ], true ) ) {
			$updated = false;
			foreach ( $GLOBALS['frontman_test_block_templates'] as $template ) {
				if ( $template->slug === $post->post_name && $template->type === $post->post_type ) {
					$template->title = $post->post_title;
					$template->content = $post->post_content;
					$template->wp_id = $id;
					$template->source = 'custom';
					$updated = true;
					break;
				}
			}
			if ( ! $updated ) {
				$template = (object) [
					'id' => 'frontman-theme//' . $post->post_name,
					'slug' => $post->post_name,
					'title' => $post->post_title,
					'description' => '',
					'type' => $post->post_type,
					'source' => 'custom',
					'content' => $post->post_content,
					'wp_id' => $id,
				];
				$GLOBALS['frontman_test_block_templates'][] = $template;
			}
		}

		return $id;
	}
}

if ( ! function_exists( 'wp_update_post' ) ) {
	function wp_update_post( array $post_data ) {
		$id = $post_data['ID'];
		$post = $GLOBALS['frontman_test_posts'][ $id ];
		foreach ( $post_data as $key => $value ) {
			if ( 'ID' === $key ) {
				continue;
			}
			$post->{ $key } = $value;
		}
		$post->post_modified = '2026-03-24 11:00:00';
		$GLOBALS['frontman_test_posts'][ $id ] = $post;
		return $id;
	}
}

if ( ! function_exists( 'wp_delete_post' ) ) {
	function wp_delete_post( int $id, bool $force ) {
		$post = $GLOBALS['frontman_test_posts'][ $id ] ?? null;
		if ( $force ) {
			unset( $GLOBALS['frontman_test_posts'][ $id ] );
			unset( $GLOBALS['frontman_test_menu_item_to_term'][ $id ] );
		}
		return $post;
	}
}

if ( ! function_exists( 'parse_blocks' ) ) {
	function parse_blocks( string $content ): array {
		$parts = array_values( array_filter( explode( "\n\n", $content ) ) );
		$blocks = [];
		foreach ( $parts as $part ) {
			if ( 0 === strpos( $part, 'RAW:' ) || 0 === strpos( $part, '<div>' ) ) {
				$markup = 0 === strpos( $part, 'RAW:' ) ? substr( $part, 4 ) : $part;
				$blocks[] = [
					'blockName'    => null,
					'attrs'        => [],
					'innerHTML'    => $markup,
					'innerContent' => [ $markup ],
					'markup'       => $markup,
				];
				continue;
			}

			$blocks[] = [
				'blockName'    => 'core/paragraph',
				'attrs'        => [],
				'innerHTML'    => $part,
				'innerContent' => [ $part ],
				'markup'       => $part,
			];
		}
		return $blocks;
	}
}

if ( ! function_exists( 'serialize_block' ) ) {
	function serialize_block( array $block ): string {
		return $block['markup'];
	}
}

if ( ! function_exists( 'get_option' ) ) {
	function get_option( string $name, $default = false ) {
		return $GLOBALS['frontman_test_options'][ $name ] ?? $default;
	}
}

if ( ! function_exists( 'update_option' ) ) {
	function update_option( string $name, $value ): bool {
		$GLOBALS['frontman_test_options'][ $name ] = $value;
		return true;
	}
}

if ( ! function_exists( 'wp_get_object_terms' ) ) {
	function wp_get_object_terms( int $object_id ): array {
		$term_id = $GLOBALS['frontman_test_menu_item_to_term'][ $object_id ] ?? null;
		return null === $term_id ? [] : [ (object) [ 'term_id' => $term_id ] ];
	}
}

if ( ! function_exists( 'wp_get_nav_menu_object' ) ) {
	function wp_get_nav_menu_object( int $menu_id ) {
		return $GLOBALS['frontman_test_menu_terms'][ $menu_id ] ?? null;
	}
}

if ( ! function_exists( 'wp_get_nav_menus' ) ) {
	function wp_get_nav_menus(): array {
		return array_values( $GLOBALS['frontman_test_menu_terms'] );
	}
}

if ( ! function_exists( 'get_nav_menu_locations' ) ) {
	function get_nav_menu_locations(): array {
		return $GLOBALS['frontman_test_menu_locations'];
	}
}

if ( ! function_exists( 'get_registered_nav_menus' ) ) {
	function get_registered_nav_menus(): array {
		return $GLOBALS['frontman_test_registered_menu_locations'];
	}
}

if ( ! function_exists( 'set_theme_mod' ) ) {
	function set_theme_mod( string $name, array $value ): void {
		if ( 'nav_menu_locations' === $name ) {
			$GLOBALS['frontman_test_menu_locations'] = $value;
		}
	}
}

if ( ! function_exists( 'wp_create_nav_menu' ) ) {
	function wp_create_nav_menu( string $name ) {
		$menu_id = count( $GLOBALS['frontman_test_menu_terms'] ) + 7;
		$GLOBALS['frontman_test_menu_terms'][ $menu_id ] = (object) [
			'term_id' => $menu_id,
			'name'    => $name,
			'slug'    => sanitize_key( $name ),
		];
		return $menu_id;
	}
}

if ( ! function_exists( 'wp_delete_nav_menu' ) ) {
	function wp_delete_nav_menu( int $menu_id ): bool {
		unset( $GLOBALS['frontman_test_menu_terms'][ $menu_id ] );
		foreach ( $GLOBALS['frontman_test_menu_item_to_term'] as $item_id => $term_id ) {
			if ( $term_id === $menu_id ) {
				unset( $GLOBALS['frontman_test_menu_item_to_term'][ $item_id ] );
			}
		}
		foreach ( $GLOBALS['frontman_test_menu_locations'] as $location => $assigned_menu_id ) {
			if ( $assigned_menu_id === $menu_id ) {
				unset( $GLOBALS['frontman_test_menu_locations'][ $location ] );
			}
		}
		return true;
	}
}

if ( ! function_exists( 'wp_get_nav_menu_items' ) ) {
	function wp_get_nav_menu_items( int $menu_id ): array {
		$items = [];
		foreach ( $GLOBALS['frontman_test_menu_item_to_term'] as $item_id => $term_id ) {
			if ( $term_id === $menu_id && isset( $GLOBALS['frontman_test_posts'][ $item_id ] ) ) {
				$items[] = $GLOBALS['frontman_test_posts'][ $item_id ];
			}
		}
		usort(
			$items,
			static function( $a, $b ) {
				return ( $a->menu_order ?? 0 ) <=> ( $b->menu_order ?? 0 );
			}
		);
		return $items;
	}
}

if ( ! function_exists( 'wp_update_nav_menu_item' ) ) {
	function wp_update_nav_menu_item( int $term_id, int $menu_item_id, array $menu_data ) {
		if ( 0 === $menu_item_id ) {
			$menu_item_id = count( $GLOBALS['frontman_test_posts'] ) + 1;
			$item = new WP_Post();
			$item->ID = $menu_item_id;
			$item->post_type = 'nav_menu_item';
			$item->title = $menu_data['menu-item-title'] ?? '';
			$item->url = $menu_data['menu-item-url'] ?? '';
			$item->type = 'custom';
			$item->object = 'custom';
			$item->object_id = 0;
			$item->menu_item_parent = $menu_data['menu-item-parent-id'] ?? 0;
			$item->menu_order = $menu_data['menu-item-position'] ?? ( count( wp_get_nav_menu_items( $term_id ) ) + 1 );
		} else {
			$item = $GLOBALS['frontman_test_posts'][ $menu_item_id ];
		}

		if ( isset( $menu_data['menu-item-title'] ) ) {
			$item->title = $menu_data['menu-item-title'];
		}
		if ( isset( $menu_data['menu-item-url'] ) ) {
			$item->url = $menu_data['menu-item-url'];
		}
		if ( isset( $menu_data['menu-item-position'] ) ) {
			$item->menu_order = $menu_data['menu-item-position'];
		}
		$GLOBALS['frontman_test_posts'][ $menu_item_id ] = $item;
		$GLOBALS['frontman_test_menu_item_to_term'][ $menu_item_id ] = $term_id;
		return $menu_item_id;
	}
}

if ( ! function_exists( 'wp_setup_nav_menu_item' ) ) {
	function wp_setup_nav_menu_item( WP_Post $item ): WP_Post {
		return $item;
	}
}

if ( ! function_exists( 'wp_get_sidebars_widgets' ) ) {
	function wp_get_sidebars_widgets(): array {
		return $GLOBALS['frontman_test_options']['sidebars_widgets'] ?? [];
	}
}

if ( ! function_exists( 'wp_get_theme' ) ) {
	function wp_get_theme() {
		return new class() {
			public function get( string $field ) {
				return 'Frontman Theme';
			}
			public function is_block_theme(): bool {
				return true;
			}
			public function get_template(): string {
				return 'frontman-theme';
			}
			public function get_stylesheet(): string {
				return 'frontman-theme';
			}
		};
	}
}

if ( ! function_exists( 'get_stylesheet' ) ) {
	function get_stylesheet(): string {
		return 'frontman-theme';
	}
}

if ( ! function_exists( 'get_block_templates' ) ) {
	function get_block_templates( array $query, string $type ): array {
		return array_values( array_filter( $GLOBALS['frontman_test_block_templates'], static function( $template ) use ( $type ) {
			return $template->type === $type;
		} ) );
	}
}

if ( ! function_exists( 'wp_set_post_terms' ) ) {
	function wp_set_post_terms( int $post_id, array $terms, string $taxonomy ): void {
		foreach ( $GLOBALS['frontman_test_block_templates'] as $template ) {
			if ( isset( $template->wp_id ) && (int) $template->wp_id === $post_id ) {
				$template->theme = $terms[0] ?? null;
			}
		}
	}
}

if ( ! function_exists( 'rocket_clean_domain' ) ) {
	function rocket_clean_domain(): void {
		$GLOBALS['frontman_test_cache_cleared'][] = 'wp-rocket';
	}
}

if ( ! function_exists( 'wp_cache_flush' ) ) {
	function wp_cache_flush(): void {
		$GLOBALS['frontman_test_cache_cleared'][] = 'object-cache';
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-posts.php';
require_once __DIR__ . '/../tools/class-tool-blocks.php';
require_once __DIR__ . '/../tools/class-tool-menus.php';
require_once __DIR__ . '/../tools/class-tool-options.php';
require_once __DIR__ . '/../tools/class-tool-templates.php';
require_once __DIR__ . '/../tools/class-tool-widgets.php';
require_once __DIR__ . '/../tools/class-tool-cache.php';

class Frontman_Mutation_Snapshots_Test_Runner {
	private int $assertions = 0;

	public function run(): void {
		$this->seed();
		$this->test_posts_include_before_snapshots();
		$this->test_blocks_include_before_snapshots();
		$this->test_block_move_and_delete_snapshots();
		$this->test_menu_management_snapshots();
		$this->test_menu_item_creation_includes_before_snapshot();
		$this->test_menu_option_and_widget_updates_include_before_snapshots();
		$this->test_widget_management_snapshots();
		$this->test_template_update_snapshot();
		$this->test_cache_tools();
		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function seed(): void {
		$post = new WP_Post();
		$post->ID = 10;
		$post->post_title = 'Before';
		$post->post_content = '<p>First</p>' . "\n\n" . 'RAW:<div>Loose HTML</div>' . "\n\n" . '<p>Second</p>';
		$post->post_excerpt = 'Excerpt';
		$post->post_status = 'draft';
		$post->post_type = 'page';
		$post->post_date = '2026-03-24 09:00:00';
		$post->post_modified = '2026-03-24 09:00:00';
		$post->post_author = 1;
		$post->post_name = 'before';
		$GLOBALS['frontman_test_posts'][10] = $post;

		$GLOBALS['frontman_test_menu_terms'][7] = (object) [
			'term_id' => 7,
			'name' => 'Primary Menu',
			'slug' => 'primary-menu',
		];
		$GLOBALS['frontman_test_registered_menu_locations'] = [
			'primary' => 'Primary Menu',
			'footer'  => 'Footer Menu',
		];
		$GLOBALS['frontman_test_menu_locations'] = [
			'primary' => 7,
			'footer'  => 0,
		];

		$menu_item = new WP_Post();
		$menu_item->ID = 25;
		$menu_item->post_type = 'nav_menu_item';
		$menu_item->title = 'Old Label';
		$menu_item->url = 'https://example.com/old';
		$menu_item->type = 'custom';
		$menu_item->object = 'custom';
		$menu_item->object_id = 0;
		$menu_item->menu_item_parent = 0;
		$menu_item->menu_order = 1;
		$GLOBALS['frontman_test_posts'][25] = $menu_item;
		$GLOBALS['frontman_test_menu_item_to_term'][25] = 7;

		$GLOBALS['frontman_test_options']['blogname'] = 'Old Blog Name';
		$GLOBALS['frontman_test_options']['active_plugins'] = [ 'wp-rocket/wp-rocket.php' ];
		$GLOBALS['frontman_test_options']['widget_text'] = [
			2 => [ 'title' => 'Old Widget', 'text' => 'Old text' ],
		];
		$GLOBALS['frontman_test_options']['widget_categories'] = [
			3 => [ 'title' => 'Categories Widget' ],
		];
		$GLOBALS['frontman_test_options']['sidebars_widgets'] = [
			'sidebar-1' => [ 'text-2', 'categories-3' ],
			'sidebar-2' => [],
		];
		$GLOBALS['wp_registered_sidebars'] = [
			'sidebar-1' => [ 'name' => 'Primary Sidebar', 'description' => '' ],
			'sidebar-2' => [ 'name' => 'Footer Sidebar', 'description' => '' ],
		];
		$GLOBALS['frontman_test_block_templates'][] = (object) [
			'id' => 'frontman-theme//home',
			'slug' => 'home',
			'title' => 'Home',
			'description' => 'Homepage template',
			'type' => 'wp_template',
			'source' => 'theme',
			'content' => '<!-- wp:paragraph --><p>Old Template</p><!-- /wp:paragraph -->',
			'wp_id' => null,
		];
	}

	private function test_posts_include_before_snapshots(): void {
		$tool = new Frontman_Tool_Posts();

		$updated = $tool->update_post( [ 'id' => 10, 'title' => 'After' ] );
		$this->assert_same( 'Before', $updated['before']['title'], 'wp_update_post returns previous post snapshot' );
		$this->assert_same( 'After', $updated['after']['title'], 'wp_update_post returns updated post snapshot' );

		$deleted = $tool->delete_post( [ 'id' => 10, 'force' => false, 'confirm' => true ] );
		$this->assert_same( 'After', $deleted['before']['title'], 'wp_delete_post returns previous post snapshot' );

		$created = $tool->create_post( [
			'title'   => 'Created',
			'content' => '<p>Created</p>',
			'status'  => 'publish',
			'post_type' => 'post',
		] );
		$this->assert_same( 'Created', $created['after']['title'], 'wp_create_post returns created post snapshot as after' );

		$this->assert_error_contains(
			static function() use ( $tool ) {
				$tool->delete_post( [ 'id' => 10, 'force' => true, 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_delete_post requires confirm=true'
		);
	}

	private function test_blocks_include_before_snapshots(): void {
		$tool = new Frontman_Tool_Blocks();
		$listed = $tool->list_blocks( [ 'post_id' => 10 ] );
		$this->assert_same( 2, $listed['block_count'], 'wp_list_blocks only counts named blocks' );

		$updated = $tool->update_block( [
			'post_id' => 10,
			'index' => 1,
			'block_markup' => '<p>Updated Block</p>',
		] );
		$this->assert_same( '<p>Second</p>', $updated['before']['block']['markup'], 'wp_update_block returns previous block snapshot' );
		$this->assert_same( '<p>Updated Block</p>', $updated['after']['block']['markup'], 'wp_update_block returns updated block snapshot' );
		$this->assert_true( false !== strpos( $updated['after']['post_content'], '<div>Loose HTML</div>' ), 'wp_update_block preserves freeform HTML blocks' );

		$inserted = $tool->insert_block( [
			'post_id' => 10,
			'index' => 1,
			'block_markup' => '<p>Inserted Block</p>',
		] );
		$this->assert_same( 2, $inserted['before']['blocks']['block_count'], 'wp_insert_block returns prior block list summary' );
		$this->assert_same( 3, $inserted['after']['blocks']['block_count'], 'wp_insert_block returns updated block list summary' );
		$this->assert_true( false !== strpos( $inserted['after']['post_content'], '<div>Loose HTML</div>' ), 'wp_insert_block preserves freeform HTML blocks' );
	}

	private function test_block_move_and_delete_snapshots(): void {
		$tool = new Frontman_Tool_Blocks();

		$moved = $tool->move_block( [ 'post_id' => 10, 'from_index' => 0, 'to_index' => 2 ] );
		$this->assert_same( 3, $moved['before']['blocks']['block_count'], 'wp_move_block captures prior block list' );
		$this->assert_same( 3, $moved['after']['blocks']['block_count'], 'wp_move_block captures updated block list' );

		$this->assert_error_contains(
			static function() use ( $tool ) {
				$tool->delete_block( [ 'post_id' => 10, 'index' => 0, 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_delete_block requires confirm=true'
		);

		$deleted = $tool->delete_block( [ 'post_id' => 10, 'index' => 0, 'confirm' => true ] );
		$this->assert_same( 3, $deleted['before']['blocks']['block_count'], 'wp_delete_block captures prior block list' );
		$this->assert_same( 2, $deleted['after']['blocks']['block_count'], 'wp_delete_block captures updated block list' );
		$this->assert_true( false !== strpos( $deleted['after']['post_content'], '<div>Loose HTML</div>' ), 'wp_delete_block preserves freeform HTML blocks' );
	}

	private function test_menu_management_snapshots(): void {
		$tool = new Frontman_Tool_Menus();
		$locations = $tool->list_menu_locations( [] );
		$this->assert_same( 'primary', $locations[0]['location'], 'wp_list_menu_locations returns registered locations' );

		$created = $tool->create_menu( [ 'name' => 'Footer Links' ] );
		$this->assert_same( 'Footer Links', $created['menu']['name'], 'wp_create_menu returns created menu snapshot' );
		$this->assert_same( 'Footer Links', $tool->read_menu( [ 'id' => $created['menu_id'] ] )['name'], 'wp_read_menu reads created menu' );

		$assigned = $tool->assign_menu_location( [ 'menu_id' => $created['menu_id'], 'location' => 'footer' ] );
		$this->assert_same( 0, $assigned['before'][1]['menu_id'], 'wp_assign_menu_location captures previous location assignment' );
		$this->assert_same( $created['menu_id'], $assigned['after'][1]['menu_id'], 'wp_assign_menu_location captures updated location assignment' );

		$this->assert_error_contains(
			static function() use ( $tool, $created ) {
				$tool->delete_menu( [ 'id' => $created['menu_id'], 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_delete_menu requires confirm=true'
		);

		$deleted = $tool->delete_menu( [ 'id' => $created['menu_id'], 'confirm' => true ] );
		$this->assert_same( $created['menu_id'], $deleted['id'], 'wp_delete_menu reports deleted menu id' );
	}

	private function test_menu_option_and_widget_updates_include_before_snapshots(): void {
		$menu_tool = new Frontman_Tool_Menus();
		$menu = $menu_tool->update_menu_item( [ 'menu_item_id' => 25, 'title' => 'New Label' ] );
		$this->assert_same( 'Old Label', $menu['before']['title'], 'wp_update_menu_item returns previous menu item snapshot' );
		$this->assert_same( 'New Label', $menu['after']['title'], 'wp_update_menu_item returns updated menu item snapshot' );

		$option_tool = new Frontman_Tool_Options();
		$option = $option_tool->update_option( [ 'name' => 'blogname', 'value' => 'New Blog Name' ] );
		$this->assert_same( 'Old Blog Name', $option['before'], 'wp_update_option returns previous option value' );
		$this->assert_same( 'New Blog Name', $option['value'], 'wp_update_option returns updated option value' );
		$this->assert_error_contains(
			static function() use ( $option_tool ) {
				$option_tool->update_option( [ 'name' => 'sidebars_widgets', 'value' => 'oops' ] );
			},
			'Option not allowed',
			'wp_update_option rejects complex widget/sidebar state writes'
		);

		$widget_tool = new Frontman_Tool_Widgets();
		$widget = $widget_tool->update_widget( [
			'sidebar_id' => 'sidebar-1',
			'widget_id' => 'text-2',
			'settings' => [ 'title' => 'New Widget' ],
		] );
		$this->assert_same( 'Old Widget', $widget['before']['title'], 'wp_update_widget returns previous widget settings' );
		$this->assert_same( 'New Widget', $widget['settings']['title'], 'wp_update_widget returns updated widget settings' );

		$this->assert_error_contains(
			static function() use ( $menu_tool ) {
				$menu_tool->delete_menu_item( [ 'menu_item_id' => 25, 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_delete_menu_item requires confirm=true'
		);

		$deleted_item = $menu_tool->delete_menu_item( [ 'menu_item_id' => 25, 'confirm' => true ] );
		$this->assert_same( 'New Label', $deleted_item['before']['item']['title'], 'wp_delete_menu_item returns previous item snapshot' );
		$this->assert_same( 1, count( $deleted_item['after']['items'] ), 'wp_delete_menu_item returns updated menu snapshot' );
	}

	private function test_menu_item_creation_includes_before_snapshot(): void {
		$menu_tool = new Frontman_Tool_Menus();
		$created = $menu_tool->create_menu_item( [
			'menu_id' => 7,
			'title' => 'Awesome',
			'url' => 'https://www.category-creation.com/',
		] );

		$this->assert_same( 1, count( $created['before']['items'] ), 'wp_create_menu_item returns menu state before insertion' );
		$this->assert_same( 2, count( $created['after']['items'] ), 'wp_create_menu_item returns menu state after insertion' );
		$this->assert_same( 'Awesome', $created['item']['title'], 'wp_create_menu_item returns the created menu item' );
	}

	private function test_widget_management_snapshots(): void {
		$tool = new Frontman_Tool_Widgets();

		$this->assert_error_contains(
			static function() use ( $tool ) {
				$tool->create_widget( [
					'sidebar_id' => 'sidebar-2',
					'widget_base' => 'categories',
					'settings' => [ 'title' => 'Categories' ],
				] );
			},
			'text',
			'wp_create_widget rejects unsupported widget bases'
		);

		$this->assert_error_contains(
			static function() use ( $tool ) {
				$tool->update_widget( [
					'sidebar_id' => 'sidebar-1',
					'widget_id' => 'categories-3',
					'settings' => [ 'title' => 'Nope' ],
				] );
			},
			'text',
			'wp_update_widget rejects unsupported widget bases'
		);

		$this->assert_error_contains(
			static function() use ( $tool ) {
				$tool->delete_widget( [
					'widget_id' => 'categories-3',
					'confirm' => true,
				] );
			},
			'text',
			'wp_delete_widget rejects unsupported widget bases'
		);

		$created = $tool->create_widget( [
			'sidebar_id' => 'sidebar-2',
			'widget_base' => 'text',
			'settings' => [ 'title' => 'Footer Widget', 'text' => 'Hello' ],
		] );
		$this->assert_same( 0, $created['before']['widget_count'], 'wp_create_widget captures sidebar state before creation' );
		$this->assert_same( 1, $created['after']['widget_count'], 'wp_create_widget captures sidebar state after creation' );
		$this->assert_same( 'Footer Widget', $tool->read_widget( [ 'widget_id' => $created['widget_id'] ] )['settings']['title'], 'wp_read_widget reads created widget settings' );

		$moved = $tool->move_widget( [
			'widget_id' => $created['widget_id'],
			'to_sidebar_id' => 'sidebar-1',
			'to_position' => 1,
		] );
		$this->assert_same( 'sidebar-2', $moved['before']['widget']['sidebar_id'], 'wp_move_widget captures original sidebar' );
		$this->assert_same( 'sidebar-1', $moved['after']['widget']['sidebar_id'], 'wp_move_widget captures destination sidebar' );

		$reordered = $tool->move_widget( [
			'widget_id' => $created['widget_id'],
			'to_sidebar_id' => 'sidebar-1',
			'to_position' => 2,
		] );
		$this->assert_same( 2, $reordered['after']['widget']['position'], 'wp_move_widget can reorder within the same sidebar without duplicating the widget' );
		$this->assert_same( $reordered['before']['from_sidebar']['widget_count'], $reordered['after']['from_sidebar']['widget_count'], 'same-sidebar widget move keeps the sidebar widget count stable' );

		$this->assert_error_contains(
			static function() use ( $tool, $created ) {
				$tool->delete_widget( [ 'widget_id' => $created['widget_id'], 'confirm' => false ] );
			},
			'explicit confirmation',
			'wp_delete_widget requires confirm=true'
		);

		$deleted = $tool->delete_widget( [ 'widget_id' => $created['widget_id'], 'confirm' => true ] );
		$this->assert_same( $created['widget_id'], $deleted['widget_id'], 'wp_delete_widget reports deleted widget id' );
		$this->assert_same( 'Footer Widget', $deleted['before']['widget']['settings']['title'], 'wp_delete_widget returns previous widget snapshot' );
	}

	private function test_template_update_snapshot(): void {
		$tool = new Frontman_Tool_Templates();
		$this->assert_same( 'Home', $tool->read_template( [ 'slug' => 'home', 'type' => 'wp_template' ] )['title'], 'wp_read_template reads template before update' );
		$updated = $tool->update_template( [
			'slug' => 'home',
			'type' => 'wp_template',
			'content' => '<!-- wp:paragraph --><p>Updated Template</p><!-- /wp:paragraph -->',
		] );
		$this->assert_same( 'theme', $updated['before']['source'], 'wp_update_template captures previous template source' );
		$this->assert_same( 'custom', $updated['after']['source'], 'wp_update_template captures updated template source' );
	}

	private function test_cache_tools(): void {
		$tool = new Frontman_Tool_Cache();
		$list = $tool->list_cache_plugins( [] );
		$this->assert_same( 'wp-rocket', $list['plugins'][0]['slug'], 'wp_list_cache_plugins detects active cache plugin' );

		$cleared = $tool->clear_cache( [] );
		$this->assert_true( in_array( 'wp-rocket', $cleared['clearedPlugins'], true ), 'wp_clear_cache clears supported cache plugins' );
		$this->assert_true( true === $cleared['objectCacheFlushed'], 'wp_clear_cache flushes object cache when available' );
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . "\nExpected: " . var_export( $expected, true ) . "\nActual: " . var_export( $actual, true ) );
		}
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}

	private function assert_error_contains( callable $fn, string $needle, string $message ): void {
		$this->assertions++;
		try {
			$fn();
			throw new RuntimeException( $message . ' (expected error)' );
		} catch ( Frontman_Tool_Error $e ) {
			if ( false === strpos( $e->getMessage(), $needle ) ) {
				throw new RuntimeException( $message . ' (wrong error: ' . $e->getMessage() . ')' );
			}
		}
	}
}

( new Frontman_Mutation_Snapshots_Test_Runner() )->run();
