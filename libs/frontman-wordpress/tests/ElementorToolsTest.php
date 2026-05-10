<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-elementor-tools/' );

$GLOBALS['frontman_test_posts'] = [];
$GLOBALS['frontman_test_meta']  = [];

if ( ! class_exists( 'WP_Post' ) ) {
	class WP_Post {
		public int $ID;
		public string $post_title;
		public string $post_name;
		public string $post_status;
		public string $post_type;

		public function __construct( int $id, string $title, string $slug, string $status = 'publish', string $type = 'page' ) {
			$this->ID          = $id;
			$this->post_title  = $title;
			$this->post_name   = $slug;
			$this->post_status = $status;
			$this->post_type   = $type;
		}
	}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_slash' ) ) {
	function wp_slash( $value ) {
		if ( is_array( $value ) ) {
			return array_map( 'wp_slash', $value );
		}

		return is_string( $value ) ? addslashes( $value ) : $value;
	}
}

if ( ! function_exists( 'wp_unslash' ) ) {
	function wp_unslash( $value ) {
		if ( is_array( $value ) ) {
			return array_map( 'wp_unslash', $value );
		}

		return is_string( $value ) ? stripslashes( $value ) : $value;
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'esc_url_raw' ) ) {
	function esc_url_raw( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'absint' ) ) {
	function absint( $value ): int {
		return abs( (int) $value );
	}
}

if ( ! function_exists( 'wp_strip_all_tags' ) ) {
	function wp_strip_all_tags( $value ): string {
		return strip_tags( (string) $value );
	}
}

if ( ! function_exists( 'trailingslashit' ) ) {
	function trailingslashit( string $value ): string {
		return rtrim( $value, '/\\' ) . '/';
	}
}

if ( ! function_exists( 'wp_upload_dir' ) ) {
	function wp_upload_dir(): array {
		return [ 'basedir' => sys_get_temp_dir() ];
	}
}

if ( ! function_exists( 'wp_get_attachment_url' ) ) {
	function wp_get_attachment_url( int $id ): string {
		return 'https://example.test/uploads/' . $id . '.jpg';
	}
}

if ( ! function_exists( 'get_post_meta' ) ) {
	function get_post_meta( int $post_id, string $key, bool $single = true ) {
		return $GLOBALS['frontman_test_meta'][ $post_id ][ $key ] ?? '';
	}
}

if ( ! function_exists( 'update_post_meta' ) ) {
	function update_post_meta( int $post_id, string $key, $value ): bool {
		$GLOBALS['frontman_test_meta'][ $post_id ][ $key ] = wp_unslash( $value );
		return true;
	}
}

if ( ! function_exists( 'delete_post_meta' ) ) {
	function delete_post_meta( int $post_id, string $key ): bool {
		unset( $GLOBALS['frontman_test_meta'][ $post_id ][ $key ] );
		return true;
	}
}

if ( ! function_exists( 'get_post' ) ) {
	function get_post( int $post_id ) {
		return $GLOBALS['frontman_test_posts'][ $post_id ] ?? null;
	}
}

if ( ! function_exists( 'get_posts' ) ) {
	function get_posts( array $args ): array {
		$post_type = $args['post_type'] ?? 'page';
		return array_values( array_filter( $GLOBALS['frontman_test_posts'], function ( $post ) use ( $post_type ) { return $post->post_type === $post_type; } ) );
	}
}

if ( ! function_exists( 'get_permalink' ) ) {
	function get_permalink( int $post_id ): string {
		return 'https://example.test/page-' . $post_id;
	}
}

if ( ! function_exists( 'get_the_title' ) ) {
	function get_the_title( int $post_id ): string {
		$post = get_post( $post_id );
		return $post ? $post->post_title : '';
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-elementor-data.php';
require_once __DIR__ . '/../tools/class-tool-elementor.php';

class Frontman_Elementor_Tools_Test_Runner {
	private Frontman_Tools $tools;
	private int $assertions = 0;

	public function __construct() {
		$this->tools = new Frontman_Tools();
		( new Frontman_Tool_Elementor() )->register( $this->tools );
	}

	public function run(): void {
		$this->seed_page();
		$this->test_tools_registered();
		$this->test_tool_object_schemas_have_properties_objects();
		$this->test_tool_array_schemas_have_items();
		$this->test_generate_element_schema_declares_handler_inputs();
		$this->test_rollback_tool_schemas();
		$this->test_structure_and_get_element();
		$this->test_update_rejects_empty_and_noop_settings();
		$this->test_update_duplicate_and_flush();
		$this->test_update_shortcut_fields();
		$this->test_remove_preserves_private_rollback();
		$this->test_removed_rollback_refuses_same_id_conflict();
		$this->test_save_page_data_rejects_invalid_tree();
		$this->test_save_page_data_preserves_page_rollback();
		$this->test_update_html_fragment_preserves_widget();
		$this->test_add_duplicate_and_move_restore_rollbacks();
		$this->test_rollback_preserves_backslash_newline_styles();
		$this->test_generate_element();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function seed_page(): void {
		$GLOBALS['frontman_test_posts'][42] = new WP_Post( 42, 'Home', 'home' );
		$GLOBALS['frontman_test_meta'][42]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root1111',
						'elType'   => 'container',
						'settings' => [ 'flex_direction' => 'column' ],
						'elements' => [
							[
								'id'         => 'head2222',
								'elType'     => 'widget',
								'widgetType' => 'heading',
								'settings'   => [ 'title' => 'Hello' ],
								'elements'   => [],
							],
							[
								'id'         => 'text3333',
								'elType'     => 'widget',
								'widgetType' => 'text-editor',
								'settings'   => [ 'editor' => 'Remove me' ],
								'elements'   => [],
							],
							[
								'id'         => 'button4444',
								'elType'     => 'widget',
								'widgetType' => 'button',
								'settings'   => [ 'text' => 'After' ],
								'elements'   => [],
							],
						],
					],
				]
			),
		];

		$GLOBALS['frontman_test_posts'][43] = new WP_Post( 43, 'Landing', 'landing' );
		$GLOBALS['frontman_test_meta'][43]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root4300',
						'elType'   => 'container',
						'settings' => [ 'flex_direction' => 'column' ],
						'elements' => [],
					],
				]
			),
		];

		$GLOBALS['frontman_test_posts'][44] = new WP_Post( 44, 'Conflict', 'conflict' );
		$GLOBALS['frontman_test_meta'][44]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root4400',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [
							[
								'id'         => 'text4401',
								'elType'     => 'widget',
								'widgetType' => 'text-editor',
								'settings'   => [ 'editor' => 'Original' ],
								'elements'   => [],
							],
						],
					],
					[
						'id'       => 'root4410',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [],
					],
				]
			),
		];

		$html_with_line_continuations = ".checkbox::after {\n  background: url(\"data:image/svg+xml;utf8," . "\\" . "\n" . "<svg></svg>" . "\\" . "\n" . "\");\n}";
		$GLOBALS['frontman_test_posts'][45] = new WP_Post( 45, 'Backslash Styles', 'backslash-styles' );
		$GLOBALS['frontman_test_meta'][45]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root4500',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [
							[
								'id'         => 'html4501',
								'elType'     => 'widget',
								'widgetType' => 'html',
								'settings'   => [ 'html' => $html_with_line_continuations ],
								'elements'   => [],
							],
						],
					],
				]
			),
		];

		$GLOBALS['frontman_test_posts'][46] = new WP_Post( 46, 'HTML Form', 'html-form' );
		$GLOBALS['frontman_test_meta'][46]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root4600',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [
							[
								'id'         => 'html4601',
								'elType'     => 'widget',
								'widgetType' => 'html',
								'settings'   => [
									'html' => '<form><div class="field"><label><input type="checkbox" name="sms"> SMS opt in</label></div><div class="field"><label><input type="checkbox" name="email"> Email opt in</label></div></form>',
								],
								'elements'   => [],
							],
						],
					],
				]
			),
		];

		$GLOBALS['frontman_test_posts'][47] = new WP_Post( 47, 'Rollback Operations', 'rollback-operations' );
		$GLOBALS['frontman_test_meta'][47]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root4700',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [
							[
								'id'         => 'text4701',
								'elType'     => 'widget',
								'widgetType' => 'text-editor',
								'settings'   => [ 'editor' => 'Move me' ],
								'elements'   => [],
							],
							[
								'id'         => 'button4702',
								'elType'     => 'widget',
								'widgetType' => 'button',
								'settings'   => [ 'text' => 'Stay' ],
								'elements'   => [],
							],
						],
					],
					[
						'id'       => 'root4710',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [],
					],
				]
			),
		];
	}

	private function test_tools_registered(): void {
		$names = array_column( $this->tools->all_definitions(), 'name' );
		$this->assert_true( in_array( 'wp_elementor_get_page_structure', $names, true ), 'Elementor structure tool is registered' );
		$this->assert_true( in_array( 'wp_elementor_update_element', $names, true ), 'Elementor update tool is registered' );
		$this->assert_true( ! in_array( 'wp_elementor_replace_html_fragment', $names, true ), 'Elementor HTML fragment tool is folded into update tool' );
		$this->assert_true( in_array( 'wp_elementor_list_rollbacks', $names, true ), 'Elementor rollback list tool is registered' );
		$this->assert_true( in_array( 'wp_elementor_restore_rollback', $names, true ), 'Elementor rollback restore tool is registered' );
	}

	private function test_tool_object_schemas_have_properties_objects(): void {
		$definitions = json_decode( wp_json_encode( $this->tools->all_definitions() ) );

		foreach ( $definitions as $definition ) {
			$this->assert_object_schemas_have_properties_objects(
				$definition->inputSchema,
				$definition->name . '.inputSchema'
			);
		}
	}

	private function assert_object_schemas_have_properties_objects( $schema, string $path ): void {
		if ( is_object( $schema ) ) {
			if ( isset( $schema->type ) && 'object' === $schema->type ) {
				$this->assert_true( isset( $schema->properties ), $path . ' object schema has properties' );
				$this->assert_true(
					$schema->properties instanceof stdClass,
					$path . ' properties serialize as an object'
				);

				if ( isset( $schema->required ) && is_array( $schema->required ) ) {
					foreach ( $schema->required as $field ) {
						$this->assert_true(
							property_exists( $schema->properties, $field ),
							$path . ' required field exists in properties: ' . $field
						);
					}
				}
			}

			foreach ( get_object_vars( $schema ) as $key => $value ) {
				$this->assert_object_schemas_have_properties_objects( $value, $path . '.' . $key );
			}
		}

		if ( is_array( $schema ) ) {
			foreach ( $schema as $key => $value ) {
				$this->assert_object_schemas_have_properties_objects( $value, $path . '[' . $key . ']' );
			}
		}
	}

	private function test_tool_array_schemas_have_items(): void {
		$definitions = json_decode( wp_json_encode( $this->tools->all_definitions() ) );

		foreach ( $definitions as $definition ) {
			$this->assert_array_schemas_have_items(
				$definition->inputSchema,
				$definition->name . '.inputSchema'
			);
		}
	}

	private function assert_array_schemas_have_items( $schema, string $path ): void {
		if ( is_object( $schema ) ) {
			if ( isset( $schema->type ) && 'array' === $schema->type ) {
				$this->assert_true( isset( $schema->items ), $path . ' array schema has items' );
			}

			foreach ( get_object_vars( $schema ) as $key => $value ) {
				$this->assert_array_schemas_have_items( $value, $path . '.' . $key );
			}
		}

		if ( is_array( $schema ) ) {
			foreach ( $schema as $key => $value ) {
				$this->assert_array_schemas_have_items( $value, $path . '[' . $key . ']' );
			}
		}
	}

	private function test_generate_element_schema_declares_handler_inputs(): void {
		$definition = $this->decoded_tool_definition( 'wp_elementor_generate_element' );
		$properties = $definition->inputSchema->properties;

		$expected_fields = [
			'type',
			'settings',
			'children',
			'widget_type',
			'is_inner',
			'width',
			'title',
			'tag',
			'content',
			'attachment_id',
			'button_text',
			'url',
		];

		foreach ( $expected_fields as $field ) {
			$this->assert_true(
				property_exists( $properties, $field ),
				'wp_elementor_generate_element schema declares ' . $field
			);
		}
	}

	private function test_rollback_tool_schemas(): void {
		$save = $this->decoded_tool_definition( 'wp_elementor_save_page_data' );
		$this->assert_true( property_exists( $save->inputSchema->properties, 'confirm' ), 'wp_elementor_save_page_data schema declares confirm' );
		$this->assert_true( in_array( 'confirm', $save->inputSchema->required, true ), 'wp_elementor_save_page_data requires confirm' );

		$restore = $this->decoded_tool_definition( 'wp_elementor_restore_rollback' );
		$this->assert_true( property_exists( $restore->inputSchema->properties, 'rollback_id' ), 'wp_elementor_restore_rollback schema declares rollback_id' );
		$this->assert_true( property_exists( $restore->inputSchema->properties, 'confirm' ), 'wp_elementor_restore_rollback schema declares confirm' );
		$this->assert_same( [ 'post_id', 'rollback_id', 'confirm' ], $restore->inputSchema->required, 'wp_elementor_restore_rollback required fields are exact' );
		$this->assert_same( false, $restore->inputSchema->additionalProperties, 'wp_elementor_restore_rollback disallows extra fields' );
	}

	private function decoded_tool_definition( string $name ) {
		$definitions = json_decode( wp_json_encode( $this->tools->all_definitions() ) );

		foreach ( $definitions as $definition ) {
			if ( $name === $definition->name ) {
				return $definition;
			}
		}

		throw new RuntimeException( 'Tool definition not found: ' . $name );
	}

	private function test_structure_and_get_element(): void {
		$structure = $this->call_success( 'wp_elementor_get_page_structure', [ 'post_id' => 42 ] );
		$this->assert_same( 'root1111', $structure['structure'][0]['id'], 'Structure includes root element' );
		$this->assert_same( 'Hello', $structure['structure'][0]['children'][0]['hint']['title'], 'Structure includes text hints' );

		$element = $this->call_success( 'wp_elementor_get_element', [ 'post_id' => 42, 'element_id' => 'head2222' ] );
		$this->assert_same( 'heading', $element['widgetType'], 'Get element returns widget data' );
	}

	private function test_update_rejects_empty_and_noop_settings(): void {
		$empty_error = $this->call_error( 'wp_elementor_update_element', [ 'post_id' => 42, 'element_id' => 'head2222', 'settings' => [] ] );
		$this->assert_true( false !== strpos( $empty_error, 'settings is empty' ), 'Update rejects empty settings' );

		$noop_error = $this->call_error( 'wp_elementor_update_element', [ 'post_id' => 42, 'element_id' => 'head2222', 'settings' => [ 'title' => 'Hello' ] ] );
		$this->assert_true( false !== strpos( $noop_error, 'do not change' ), 'Update rejects no-op settings' );

		$html_error = $this->call_error( 'wp_elementor_update_element', [ 'post_id' => 46, 'element_id' => 'html4601', 'settings' => [ 'html' => '<p>overwrite</p>' ] ] );
		$this->assert_true( false !== strpos( $html_error, 'old_html and new_html' ), 'Update rejects direct HTML widget settings.html overwrites' );
	}

	private function test_update_duplicate_and_flush(): void {
		$updated = $this->call_success( 'wp_elementor_update_element', [ 'post_id' => 42, 'element_id' => 'head2222', 'settings' => [ 'title' => 'Updated' ] ] );
		$this->assert_true( true === $updated['success'], 'Update returns success' );
		$this->assert_true( ! empty( $updated['rollback_id'] ), 'Update returns rollback ID' );

		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( 3, count( $data[0]['elements'] ), 'Update does not insert live rollback elements' );
		$this->assert_same( 'Updated', $data[0]['elements'][0]['settings']['title'], 'Update merges settings into Elementor data' );

		$rollbacks = $this->call_success( 'wp_elementor_list_rollbacks', [ 'post_id' => 42 ] );
		$this->assert_same( 1, count( $rollbacks['rollbacks'] ), 'Update stores one private rollback' );
		$this->assert_same( 'updated', $rollbacks['rollbacks'][0]['action'], 'Update rollback records update action' );
		$this->assert_same( 'head2222', $rollbacks['rollbacks'][0]['element_id'], 'Update rollback records original element ID' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 42, 'rollback_id' => $updated['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Update rollback restore returns success' );
		$this->assert_true( ! empty( $restored['undo_rollback_id'] ), 'Update rollback restore returns an undo rollback ID' );
		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( 'Hello', $data[0]['elements'][0]['settings']['title'], 'Update rollback restores previous settings' );
		$this->assert_same( 3, count( $data[0]['elements'] ), 'Update rollback restore does not insert live rollback elements' );

		$duplicated = $this->call_success( 'wp_elementor_duplicate_element', [ 'post_id' => 42, 'element_id' => 'head2222' ] );
		$this->assert_true( ! empty( $duplicated['new_element_id'] ), 'Duplicate returns new element ID' );
		$this->assert_true( ! empty( $duplicated['rollback_id'] ), 'Duplicate returns rollback ID' );

		$flushed = $this->call_success( 'wp_elementor_flush_css', [ 'post_id' => 42 ] );
		$this->assert_same( 'post-42', $flushed['scope'], 'Flush reports post scope' );
	}

	private function test_update_shortcut_fields(): void {
		$this->call_success(
			'wp_elementor_update_element',
			[
				'post_id'               => 42,
				'element_id'            => 'root1111',
				'background_image_id'   => 30275,
				'background_image_url'  => 'https://example.test/rocket.png',
				'background_size'       => 'cover',
				'background_position'   => 'center center',
				'background_repeat'     => 'no-repeat',
			]
		);

		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( 30275, $data[0]['settings']['background_image']['id'], 'Shortcut updates background image ID' );
		$this->assert_same( 'https://example.test/rocket.png', $data[0]['settings']['background_image']['url'], 'Shortcut updates background image URL' );
		$this->assert_same( 'library', $data[0]['settings']['background_image']['source'], 'Shortcut defaults background image source' );
		$this->assert_same( 'cover', $data[0]['settings']['background_size'], 'Shortcut updates background size' );
		$this->assert_same( 'center center', $data[0]['settings']['background_position'], 'Shortcut updates background position' );
		$this->assert_same( 'no-repeat', $data[0]['settings']['background_repeat'], 'Shortcut updates background repeat' );

		$this->call_success(
			'wp_elementor_update_element',
			[
				'post_id'                      => 42,
				'element_id'                   => 'head2222',
				'heading_html'                 => '<p>Ready to Launch? Let\'s Talk.</p>',
				'title_color'                  => '#FFFFFF',
				'title_typography_font_family' => 'Poppins',
			]
		);

		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( '<p>Ready to Launch? Let\'s Talk.</p>', $data[0]['elements'][0]['settings']['heading'], 'Shortcut updates heading HTML' );
		$this->assert_same( '#FFFFFF', $data[0]['elements'][0]['settings']['title_color'], 'Shortcut updates heading title color' );
		$this->assert_same( 'Poppins', $data[0]['elements'][0]['settings']['title_typography_font_family'], 'Shortcut updates heading font family' );
		$this->assert_same( 'custom', $data[0]['elements'][0]['settings']['title_typography_typography'], 'Shortcut enables custom heading typography' );
	}

	private function test_remove_preserves_private_rollback(): void {
		$scope_error = $this->call_error( 'wp_elementor_remove_element', [ 'post_id' => 42, 'element_id' => 'text3333', 'confirm' => true ] );
		$this->assert_true( false !== strpos( $scope_error, 'scope=whole_element' ), 'Remove requires explicit whole-element scope' );

		$removed = $this->call_success( 'wp_elementor_remove_element', [ 'post_id' => 42, 'element_id' => 'text3333', 'scope' => 'whole_element', 'confirm' => true ] );
		$this->assert_true( true === $removed['success'], 'Remove returns success' );
		$this->assert_true( ! empty( $removed['rollback_id'] ), 'Remove returns rollback ID' );

		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( null, Frontman_Elementor_Data::get_element( $data, 'text3333' ), 'Removed element is no longer active' );
		$this->assert_same( 3, count( $data[0]['elements'] ), 'Remove does not insert live rollback elements' );

		$rollbacks = $this->call_success( 'wp_elementor_list_rollbacks', [ 'post_id' => 42 ] );
		$this->assert_same( 'removed', $rollbacks['rollbacks'][0]['action'], 'Remove rollback records remove action' );
		$this->assert_same( 'text3333', $rollbacks['rollbacks'][0]['element_id'], 'Remove rollback records original element ID' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 42, 'rollback_id' => $removed['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Remove rollback restore returns success' );
		$this->assert_true( ! empty( $restored['undo_rollback_id'] ), 'Remove rollback restore returns an undo rollback ID' );
		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$element = Frontman_Elementor_Data::get_element( $data, 'text3333' );
		$this->assert_same( 'Remove me', $element['settings']['editor'], 'Remove rollback restores previous element settings' );
		$this->assert_same( 4, count( $data[0]['elements'] ), 'Remove rollback restores the active element without marker nodes' );
		$this->assert_same( 'text3333', $data[0]['elements'][2]['id'], 'Remove rollback restores element at its original position' );
		$this->assert_same( 'button4444', $data[0]['elements'][3]['id'], 'Remove rollback preserves following sibling position' );
	}

	private function test_removed_rollback_refuses_same_id_conflict(): void {
		$removed = $this->call_success( 'wp_elementor_remove_element', [ 'post_id' => 44, 'element_id' => 'text4401', 'scope' => 'whole_element', 'confirm' => true ] );
		$this->assert_true( ! empty( $removed['rollback_id'] ), 'Conflict fixture removal returns rollback ID' );

		$this->call_success(
			'wp_elementor_add_element',
			[
				'post_id'   => 44,
				'parent_id' => 'root4410',
				'element'   => [
					'id'         => 'text4401',
					'elType'     => 'widget',
					'widgetType' => 'text-editor',
					'settings'   => [ 'editor' => 'Conflicting' ],
					'elements'   => [],
				],
			]
		);

		$error = $this->call_error( 'wp_elementor_restore_rollback', [ 'post_id' => 44, 'rollback_id' => $removed['rollback_id'], 'confirm' => true ] );
		$this->assert_true( false !== strpos( $error, 'same ID already exists' ), 'Removed rollback refuses same-ID conflicts' );
	}

	private function test_save_page_data_rejects_invalid_tree(): void {
		$empty_error = $this->call_error( 'wp_elementor_save_page_data', [ 'post_id' => 43, 'data' => [], 'confirm' => true ] );
		$this->assert_true( false !== strpos( $empty_error, 'at least one Elementor element' ), 'Save page data rejects empty page trees' );

		$error = $this->call_error( 'wp_elementor_save_page_data', [ 'post_id' => 43, 'data' => [ [] ], 'confirm' => true ] );
		$this->assert_true( false !== strpos( $error, 'data[0].id is required' ), 'Save page data rejects missing element ID before Elementor save' );

		$duplicate_error = $this->call_error(
			'wp_elementor_save_page_data',
			[
				'post_id' => 43,
				'data'    => [
					[
						'id'       => 'dup4300',
						'elType'   => 'container',
						'settings' => [],
						'elements' => [
							[
								'id'         => 'dup4300',
								'elType'     => 'widget',
								'widgetType' => 'heading',
								'settings'   => [ 'title' => 'Duplicate' ],
								'elements'   => [],
							],
						],
					],
				],
				'confirm' => true,
			]
		);
		$this->assert_true( false !== strpos( $duplicate_error, 'Duplicate Elementor element ID' ), 'Save page data rejects duplicate element IDs' );

		$data = Frontman_Elementor_Data::get_page_data( 43 );
		$this->assert_same( 'root4300', $data[0]['id'], 'Invalid page data save leaves existing Elementor data unchanged' );
	}

	private function test_save_page_data_preserves_page_rollback(): void {
		$new_data = [
			[
				'id'       => 'newroot43',
				'elType'   => 'container',
				'settings' => [ 'flex_direction' => 'row' ],
				'elements' => [],
			],
		];

		$saved = $this->call_success( 'wp_elementor_save_page_data', [ 'post_id' => 43, 'data' => $new_data, 'confirm' => true ] );
		$this->assert_true( true === $saved['success'], 'Save page data returns success' );
		$this->assert_true( ! empty( $saved['rollback_id'] ), 'Save page data returns rollback ID' );

		$data = Frontman_Elementor_Data::get_page_data( 43 );
		$this->assert_same( 'newroot43', $data[0]['id'], 'Save page data replaces active Elementor data' );

		$rollbacks = $this->call_success( 'wp_elementor_list_rollbacks', [ 'post_id' => 43 ] );
		$this->assert_same( 'saved_page_data', $rollbacks['rollbacks'][0]['action'], 'Save page data rollback records page save action' );
		$this->assert_same( 1, $rollbacks['rollbacks'][0]['sections'], 'Save page data rollback records previous section count' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 43, 'rollback_id' => $saved['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Save page data rollback restore returns success' );
		$this->assert_true( ! empty( $restored['undo_rollback_id'] ), 'Save page data rollback restore returns an undo rollback ID' );
		$data = Frontman_Elementor_Data::get_page_data( 43 );
		$this->assert_same( 'root4300', $data[0]['id'], 'Save page data rollback restores previous page tree' );
	}

	private function test_update_html_fragment_preserves_widget(): void {
		$element             = Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 46 ), 'html4601' );
		$full_deletion_error = $this->call_error(
			'wp_elementor_update_element',
			[
				'post_id'    => 46,
				'element_id' => 'html4601',
				'old_html'   => $element['settings']['html'],
				'new_html'   => '',
			]
		);
		$this->assert_true( false !== strpos( $full_deletion_error, 'entire settings.html' ), 'HTML fragment replacement refuses whole-content deletion' );

		$old_fragment = '<div class="field"><label><input type="checkbox" name="sms"> SMS opt in</label></div>';
		$updated      = $this->call_success(
			'wp_elementor_update_element',
			[
				'post_id'    => 46,
				'element_id' => 'html4601',
				'old_html'   => $old_fragment,
				'new_html'   => '',
			]
		);
		$this->assert_true( true === $updated['success'], 'HTML fragment replacement returns success' );
		$this->assert_true( ! empty( $updated['rollback_id'] ), 'HTML fragment replacement returns rollback ID' );
		$this->assert_same( 1, $updated['matches_before'], 'HTML fragment replacement reports one exact match' );

		$data    = Frontman_Elementor_Data::get_page_data( 46 );
		$element = Frontman_Elementor_Data::get_element( $data, 'html4601' );
		$this->assert_same( 'html', $element['widgetType'], 'HTML fragment replacement keeps the Elementor HTML widget' );
		$this->assert_true( false === strpos( $element['settings']['html'], 'SMS opt in' ), 'HTML fragment replacement removes selected nested markup' );
		$this->assert_true( false !== strpos( $element['settings']['html'], 'Email opt in' ), 'HTML fragment replacement preserves sibling markup' );

		$rollbacks = $this->call_success( 'wp_elementor_list_rollbacks', [ 'post_id' => 46 ] );
		$this->assert_same( 'updated_html_fragment', $rollbacks['rollbacks'][0]['action'], 'HTML fragment replacement records specific rollback action' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 46, 'rollback_id' => $updated['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'HTML fragment rollback restore succeeds' );
		$this->assert_true( ! empty( $restored['undo_rollback_id'] ), 'HTML fragment rollback restore returns an undo rollback ID' );
		$element = Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 46 ), 'html4601' );
		$this->assert_same( 'html', $element['widgetType'], 'HTML fragment rollback keeps the Elementor HTML widget' );
		$this->assert_true( false !== strpos( $element['settings']['html'], 'SMS opt in' ), 'HTML fragment rollback restores removed markup' );
		$this->assert_true( false !== strpos( $element['settings']['html'], 'Email opt in' ), 'HTML fragment rollback preserves sibling markup' );
	}

	private function test_add_duplicate_and_move_restore_rollbacks(): void {
		$duplicate_add_error = $this->call_error(
			'wp_elementor_add_element',
			[
				'post_id'   => 47,
				'parent_id' => 'root4710',
				'element'   => [
					'id'         => 'text4701',
					'elType'     => 'widget',
					'widgetType' => 'html',
					'settings'   => [ 'html' => '<p>Duplicate ID</p>' ],
					'elements'   => [],
				],
			]
		);
		$this->assert_true( false !== strpos( $duplicate_add_error, 'Duplicate Elementor element ID' ), 'Add element rejects duplicate IDs before saving' );
		$data = Frontman_Elementor_Data::get_page_data( 47 );
		$this->assert_same( 0, count( $data[1]['elements'] ), 'Rejected duplicate add leaves Elementor data unchanged' );

		$added = $this->call_success(
			'wp_elementor_add_element',
			[
				'post_id'   => 47,
				'parent_id' => 'root4710',
				'element'   => [
					'id'         => 'html4703',
					'elType'     => 'widget',
					'widgetType' => 'html',
					'settings'   => [ 'html' => '<p>Added</p>' ],
					'elements'   => [],
				],
			]
		);
		$this->assert_true( ! empty( $added['rollback_id'] ), 'Add element returns rollback ID' );
		$this->assert_true( null !== Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 47 ), 'html4703' ), 'Add element mutates active Elementor data' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 47, 'rollback_id' => $added['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Add rollback restore succeeds' );
		$this->assert_same( null, Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 47 ), 'html4703' ), 'Add rollback removes added element' );

		$duplicated = $this->call_success( 'wp_elementor_duplicate_element', [ 'post_id' => 47, 'element_id' => 'text4701' ] );
		$this->assert_true( ! empty( $duplicated['rollback_id'] ), 'Duplicate element returns rollback ID' );
		$this->assert_true( ! empty( $duplicated['new_element_id'] ), 'Duplicate element returns cloned element ID' );
		$this->assert_true( null !== Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 47 ), $duplicated['new_element_id'] ), 'Duplicate element mutates active Elementor data' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 47, 'rollback_id' => $duplicated['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Duplicate rollback restore succeeds' );
		$this->assert_same( null, Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 47 ), $duplicated['new_element_id'] ), 'Duplicate rollback removes cloned element' );

		$moved = $this->call_success( 'wp_elementor_move_element', [ 'post_id' => 47, 'element_id' => 'text4701', 'parent_id' => 'root4710', 'position' => 0 ] );
		$this->assert_true( ! empty( $moved['rollback_id'] ), 'Move element returns rollback ID' );
		$data = Frontman_Elementor_Data::get_page_data( 47 );
		$this->assert_same( 'text4701', $data[1]['elements'][0]['id'], 'Move element mutates active Elementor data' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 47, 'rollback_id' => $moved['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Move rollback restore succeeds' );
		$data = Frontman_Elementor_Data::get_page_data( 47 );
		$this->assert_same( 'text4701', $data[0]['elements'][0]['id'], 'Move rollback returns element to original parent' );
		$this->assert_same( 0, count( $data[1]['elements'] ), 'Move rollback removes element from destination parent' );
	}

	private function test_rollback_preserves_backslash_newline_styles(): void {
		$original = Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 45 ), 'html4501' )['settings']['html'];
		$updated  = $this->call_success( 'wp_elementor_update_element', [ 'post_id' => 45, 'element_id' => 'html4501', 'old_html' => $original, 'new_html' => '<div>changed</div>' ] );
		$this->assert_true( ! empty( $updated['rollback_id'] ), 'Backslash style fragment replacement returns rollback ID' );

		$restored = $this->call_success( 'wp_elementor_restore_rollback', [ 'post_id' => 45, 'rollback_id' => $updated['rollback_id'], 'confirm' => true ] );
		$this->assert_true( true === $restored['success'], 'Backslash style rollback restore succeeds' );

		$element = Frontman_Elementor_Data::get_element( Frontman_Elementor_Data::get_page_data( 45 ), 'html4501' );
		$this->assert_same( $original, $element['settings']['html'], 'Rollback preserves backslash-newline CSS data URI content' );
	}

	private function test_generate_element(): void {
		$element = $this->call_success( 'wp_elementor_generate_element', [ 'type' => 'heading', 'title' => 'Generated', 'tag' => 'h1' ] );
		$this->assert_same( 'widget', $element['elType'], 'Generated heading is a widget' );
		$this->assert_same( 'heading', $element['widgetType'], 'Generated heading has widget type' );
		$this->assert_same( 'Generated', $element['settings']['title'], 'Generated heading uses title' );
	}

	private function call_success( string $name, array $input ): array {
		$result = $this->tools->call( $name, $input );
		if ( ! empty( $result['isError'] ) ) {
			throw new RuntimeException( 'Tool returned error: ' . $result['content'][0]['text'] );
		}

		return json_decode( $result['content'][0]['text'], true );
	}

	private function call_error( string $name, array $input ): string {
		$result = $this->tools->call( $name, $input );
		if ( empty( $result['isError'] ) ) {
			throw new RuntimeException( 'Tool returned success when error was expected: ' . $result['content'][0]['text'] );
		}

		return $result['content'][0]['text'];
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
}

( new Frontman_Elementor_Tools_Test_Runner() )->run();
