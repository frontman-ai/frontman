<?php
/**
 * WordPress Widget tools — list widget areas and update widgets.
 *
 * Tools: wp_list_widget_areas, wp_read_widget, wp_create_widget,
 * wp_update_widget, wp_move_widget, wp_delete_widget
 *
 * Handlers return plain data arrays on success, throw Frontman_Tool_Error on failure.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}


class Frontman_Tool_Widgets {
	private const SUPPORTED_MUTATION_WIDGET_BASES = [ 'text', 'custom_html', 'block' ];

	/**
	 * Register all widget tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_widget_areas',
			'Lists all registered widget areas (sidebars) and their active widget IDs.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_widget_areas' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_read_widget',
			'Reads a widget\'s current settings and sidebar placement.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'widget_id' => [
						'type'        => 'string',
						'description' => 'The widget instance ID (e.g. "text-2").',
					],
				],
				'required' => [ 'widget_id' ],
			],
			[ $this, 'read_widget' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_create_widget',
			'Creates a text, custom_html, or block widget in a sidebar. Text widgets accept title/text strings and filter/visual booleans; custom_html accepts title/content strings; block requires a content string containing complete block markup. HTML follows WordPress permissions. Read back and verify the rendered page.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'sidebar_id'   => [ 'type' => 'string', 'description' => 'The sidebar/widget area ID.' ],
					'widget_base'  => [ 'type' => 'string', 'enum' => self::SUPPORTED_MUTATION_WIDGET_BASES, 'description' => 'The widget base ID: text, custom_html, or block.' ],
					'settings'     => [ 'type' => 'string', 'description' => 'JSON-encoded object of widget settings.' ],
					'position'     => [ 'type' => 'integer', 'description' => 'Optional 1-based insertion position.' ],
				],
				'required' => [ 'sidebar_id', 'widget_base', 'settings' ],
			],
			[ $this, 'create_widget' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_widget',
			'Updates a text, custom_html, or block widget without moving it. Text accepts title/text strings and filter/visual booleans; custom_html accepts title/content strings; block requires content containing the complete replacement markup, including all blocks. Omitted settings and plugin metadata are preserved. Read back and verify the rendered page.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'sidebar_id' => [
						'type'        => 'string',
						'description' => 'The sidebar/widget area ID (from wp_list_widget_areas).',
					],
					'widget_id'  => [
						'type'        => 'string',
						'description' => 'The persisted widget instance ID (e.g. "text-2", "custom_html-4", "block-19"), not an editor preview ID.',
					],
					'settings'   => [
						'type'        => 'string',
						'description' => 'JSON-encoded object of widget settings to update (e.g. "{\"title\":\"My Widget\",\"text\":\"Hello\"}").',
					],
				],
				'required' => [ 'sidebar_id', 'widget_id', 'settings' ],
			],
			[ $this, 'update_widget' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_move_widget',
			'Moves a widget to a different sidebar or position, or restores a removed widget using its retained instance ID.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'widget_id'       => [ 'type' => 'string', 'description' => 'The widget instance ID to move.' ],
					'to_sidebar_id'   => [ 'type' => 'string', 'description' => 'Destination sidebar ID.' ],
					'to_position'     => [ 'type' => 'integer', 'description' => 'Optional 1-based position in the destination sidebar.' ],
				],
				'required' => [ 'widget_id', 'to_sidebar_id' ],
			],
			[ $this, 'move_widget' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_delete_widget',
			'Removes a text, custom_html, or block widget from its sidebar, retaining its settings for recovery with wp_move_widget. Ask the user for confirmation first and only call with confirm=true after approval.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'widget_id' => [ 'type' => 'string', 'description' => 'The widget instance ID to delete.' ],
					'confirm'   => [ 'type' => 'boolean', 'description' => 'Must be true only after the user explicitly confirms deletion.' ],
				],
				'required' => [ 'widget_id', 'confirm' ],
			],
			[ $this, 'delete_widget' ]
		) );
	}

	private function parse_widget_id( string $widget_id ): array {
		if ( ! preg_match( '/^(.+)-(\d+)$/', $widget_id, $matches ) || $widget_id !== sanitize_key( $matches[1] ) . '-' . (int) $matches[2] ) {
			throw new Frontman_Tool_Error( "Invalid widget ID format: {$widget_id}" );
		}

		return [
			'base'   => $matches[1],
			'number' => (int) $matches[2],
		];
	}

	private function assert_can_edit_widgets(): void {
		if ( ! current_user_can( 'edit_theme_options' ) ) {
			throw new Frontman_Tool_Error( 'Editing widgets requires edit_theme_options.' );
		}
	}

	private function assert_mutation_supported( string $widget_base ): void {
		if ( ! in_array( $widget_base, self::SUPPORTED_MUTATION_WIDGET_BASES, true ) ) {
			throw new Frontman_Tool_Error( 'Widget mutations currently support these widget types only: ' . implode( ', ', self::SUPPORTED_MUTATION_WIDGET_BASES ) );
		}
	}

	private function widget_sidebar_map(): array {
		$sidebars_widgets = get_option( 'sidebars_widgets', [] );
		$map = [];
		foreach ( $sidebars_widgets as $sidebar_id => $widgets ) {
			if ( ! is_array( $widgets ) ) {
				continue;
			}
			foreach ( $widgets as $position => $widget_id ) {
				$map[ $widget_id ] = [
					'sidebar_id' => $sidebar_id,
					'position'   => $position + 1,
				];
			}
		}
		return $map;
	}

	private function sidebar_snapshot( string $sidebar_id ): array {
		$areas = $this->list_widget_areas( [] );
		foreach ( $areas as $area ) {
			if ( $area['id'] === $sidebar_id ) {
				return $area;
			}
		}
		throw new Frontman_Tool_Error( "Sidebar not found: {$sidebar_id}" );
	}

	private function sanitized_settings( string $widget_base, $raw ): array {
		$this->assert_mutation_supported( $widget_base );
		$settings = is_string( $raw ) ? json_decode( $raw ) : null;
		if ( ! $settings instanceof \stdClass ) {
			throw new Frontman_Tool_Error( 'settings must be a JSON object of widget settings.' );
		}
		$settings = get_object_vars( $settings );
		switch ( $widget_base ) {
			case 'text':
				$fields = [ 'title', 'text', 'filter', 'visual' ];
				break;
			case 'custom_html':
				$fields = [ 'title', 'content' ];
				break;
			case 'block':
				$fields = [ 'content' ];
				if ( ! array_key_exists( 'content', $settings ) ) {
					throw new Frontman_Tool_Error( 'Block widgets require a content string containing the complete markup.' );
				}
				break;
		}
		foreach ( $settings as $key => $value ) {
			$boolean = in_array( $key, [ 'filter', 'visual' ], true );
			if ( ! in_array( $key, $fields, true ) || ( $boolean ? ! is_bool( $value ) : ! is_string( $value ) ) ) {
				throw new Frontman_Tool_Error( "Invalid setting {$key} for {$widget_base}. Allowed fields: " . implode( ', ', $fields ) . '; filter/visual must be booleans, other fields must be strings.' );
			}
			if ( ! $boolean ) {
				$settings[ $key ] = 'title' === $key ? sanitize_text_field( $value ) : ( current_user_can( 'unfiltered_html' ) ? $value : wp_kses_post( $value ) );
			}
		}
		return $settings;
	}

	private function save_settings( string $option, array $settings ): void {
		if ( ! update_option( $option, $settings ) && get_option( $option ) !== $settings ) {
			throw new Frontman_Tool_Error( "Could not save {$option}. Read current widget settings and placement before retrying." );
		}
	}

	private function save_sidebars( array $sidebars_widgets ): void {
		$this->save_settings( 'sidebars_widgets', $sidebars_widgets );
		if ( get_option( 'sidebars_widgets' ) !== $sidebars_widgets ) {
			throw new Frontman_Tool_Error( 'Sidebar placement differs from the requested change. Read current placement before retrying.' );
		}
	}

	/**
	 * wp_list_widget_areas handler.
	 */
	public function list_widget_areas( array $input ): array {
		global $wp_registered_sidebars;

		$sidebars_widgets = get_option( 'sidebars_widgets', [] );
		$result           = [];

		foreach ( $wp_registered_sidebars as $id => $sidebar ) {
			$widgets = $sidebars_widgets[ $id ] ?? [];

			$result[] = [
				'id'           => $id,
				'name'         => $sidebar['name'],
				'description'  => $sidebar['description'] ?? '',
				'widget_count' => count( $widgets ),
				'widgets'      => $widgets,
			];
		}

		return $result;
	}

	/**
	 * wp_read_widget handler.
	 */
	public function read_widget( array $input ): array {
		$widget_id = sanitize_text_field( $input['widget_id'] ?? '' );
		$parts = $this->parse_widget_id( $widget_id );
		$settings = get_option( 'widget_' . sanitize_key( $parts['base'] ), [] );
		if ( ! isset( $settings[ $parts['number'] ] ) ) {
			throw new Frontman_Tool_Error( "Widget instance not found: {$widget_id}" );
		}

		$map = $this->widget_sidebar_map();
		return [
			'widget_id'  => $widget_id,
			'widget_base'=> $parts['base'],
			'settings'   => $settings[ $parts['number'] ],
			'sidebar_id' => $map[ $widget_id ]['sidebar_id'] ?? null,
			'position'   => $map[ $widget_id ]['position'] ?? null,
		];
	}

	/**
	 * wp_create_widget handler.
	 */
	public function create_widget( array $input ): array {
		$this->assert_can_edit_widgets();
		$sidebar_id  = sanitize_key( $input['sidebar_id'] ?? '' );
		$widget_base = sanitize_key( $input['widget_base'] ?? '' );
		$settings    = $this->sanitized_settings( $widget_base, $input['settings'] ?? null );
		$before      = $this->sidebar_snapshot( $sidebar_id );
		$defaults    = 'block' === $widget_base ? [ 'content' => '' ] : ( 'text' === $widget_base ? [ 'title' => '', 'text' => '' ] : [ 'title' => '', 'content' => '' ] );

		$all_settings = get_option( 'widget_' . $widget_base, [] );
		$max_number   = 1;
		foreach ( array_keys( $all_settings ) as $key ) {
			if ( is_numeric( $key ) ) {
				$max_number = max( $max_number, (int) $key );
			}
		}

		$widget_number = $max_number + 1;
		$widget_id     = $widget_base . '-' . $widget_number;
		$all_settings[ $widget_number ] = array_merge( $defaults, $settings );
		$all_settings['_multiwidget'] = $all_settings['_multiwidget'] ?? 1;
		$this->save_settings( 'widget_' . $widget_base, $all_settings );
		$this->read_widget( [ 'widget_id' => $widget_id ] );

		$sidebars_widgets = get_option( 'sidebars_widgets', [] );
		$widgets = $sidebars_widgets[ $sidebar_id ] ?? [];
		$position = isset( $input['position'] ) ? max( 0, absint( $input['position'] ) - 1 ) : count( $widgets );
		$position = min( $position, count( $widgets ) );
		array_splice( $widgets, $position, 0, [ $widget_id ] );
		$sidebars_widgets[ $sidebar_id ] = $widgets;
		try {
			$this->save_sidebars( $sidebars_widgets );
		} catch ( Frontman_Tool_Error $error ) {
			throw new Frontman_Tool_Error( "Widget {$widget_id} settings were retained, but creation did not finish: " . $error->getMessage() . ' Use wp_read_widget before retrying; recover placement with wp_move_widget.' );
		}

		return [
			'created'   => true,
			'widget_id' => $widget_id,
			'before'    => $before,
			'after'     => $this->sidebar_snapshot( $sidebar_id ),
			'widget'    => $this->read_widget( [ 'widget_id' => $widget_id ] ),
		];
	}

	/**
	 * wp_update_widget handler.
	 */
	public function update_widget( array $input ): array {
		$this->assert_can_edit_widgets();
		$sidebar_id = sanitize_key( $input['sidebar_id'] ?? '' );
		$widget_id  = sanitize_text_field( $input['widget_id'] ?? '' );
		$widget = $this->read_widget( [ 'widget_id' => $widget_id ] );
		if ( '' === $sidebar_id || $sidebar_id !== $widget['sidebar_id'] ) {
			throw new Frontman_Tool_Error( 'sidebar_id must match the widget\'s current placement. Read the widget before updating it.' );
		}

		$parts = $this->parse_widget_id( $widget_id );
		$settings = $this->sanitized_settings( $parts['base'], $input['settings'] ?? null );

		$option = 'widget_' . sanitize_key( $parts['base'] );
		$all_settings = get_option( $option, [] );
		$all_settings[ $parts['number'] ] = array_merge( $widget['settings'], $settings );
		$this->save_settings( $option, $all_settings );

		return [
			'before'    => $widget['settings'],
			'updated'   => true,
			'widget_id' => $widget_id,
			'settings'  => $this->read_widget( [ 'widget_id' => $widget_id ] )['settings'],
		];
	}

	/**
	 * wp_move_widget handler.
	 */
	public function move_widget( array $input ): array {
		$this->assert_can_edit_widgets();
		$widget_id     = sanitize_text_field( $input['widget_id'] ?? '' );
		$to_sidebar_id = sanitize_key( $input['to_sidebar_id'] ?? '' );
		$widget        = $this->read_widget( [ 'widget_id' => $widget_id ] );
		$from_sidebar_id = $widget['sidebar_id'];
		$snapshot_source = null !== $from_sidebar_id && 'wp_inactive_widgets' !== $from_sidebar_id;
		$before = [
			'widget'       => $widget,
			'from_sidebar' => $snapshot_source ? $this->sidebar_snapshot( $from_sidebar_id ) : null,
			'to_sidebar'   => $this->sidebar_snapshot( $to_sidebar_id ),
		];

		$sidebars_widgets = get_option( 'sidebars_widgets', [] );
		$from_widgets = array_values( array_filter( $sidebars_widgets[ $from_sidebar_id ] ?? [], static function( $id ) use ( $widget_id ) {
			return $id !== $widget_id;
		} ) );
		$to_widgets = ( $from_sidebar_id === $to_sidebar_id ) ? $from_widgets : ( $sidebars_widgets[ $to_sidebar_id ] ?? [] );

		$position = isset( $input['to_position'] ) ? max( 0, absint( $input['to_position'] ) - 1 ) : count( $to_widgets );
		$position = min( $position, count( $to_widgets ) );
		array_splice( $to_widgets, $position, 0, [ $widget_id ] );

		if ( null !== $from_sidebar_id ) {
			$sidebars_widgets[ $from_sidebar_id ] = $from_widgets;
		}
		$sidebars_widgets[ $to_sidebar_id ] = $to_widgets;
		$this->save_sidebars( $sidebars_widgets );

		return [
			'moved'  => true,
			'before' => $before,
			'after'  => [
				'widget'       => $this->read_widget( [ 'widget_id' => $widget_id ] ),
				'from_sidebar' => $snapshot_source ? $this->sidebar_snapshot( $from_sidebar_id ) : null,
				'to_sidebar'   => $this->sidebar_snapshot( $to_sidebar_id ),
			],
		];
	}

	/**
	 * wp_delete_widget handler.
	 */
	public function delete_widget( array $input ): array {
		$this->assert_can_edit_widgets();
		$widget_id = sanitize_text_field( $input['widget_id'] ?? '' );
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		$parts = $this->parse_widget_id( $widget_id );
		$this->assert_mutation_supported( $parts['base'] );
		$map   = $this->widget_sidebar_map();
		if ( ! isset( $map[ $widget_id ] ) ) {
			throw new Frontman_Tool_Error( "Widget instance not found: {$widget_id}" );
		}

		$sidebar_id = $map[ $widget_id ]['sidebar_id'];
		$before = [
			'widget'  => $this->read_widget( [ 'widget_id' => $widget_id ] ),
			'sidebar' => $this->sidebar_snapshot( $sidebar_id ),
		];

		$sidebars_widgets = get_option( 'sidebars_widgets', [] );
		$sidebars_widgets[ $sidebar_id ] = array_values( array_filter( $sidebars_widgets[ $sidebar_id ] ?? [], static function( $id ) use ( $widget_id ) {
			return $id !== $widget_id;
		} ) );
		$this->save_sidebars( $sidebars_widgets );

		return [
			'deleted'   => true,
			'widget_id' => $widget_id,
			'before'    => $before,
			'after'     => $this->sidebar_snapshot( $sidebar_id ),
		];
	}
}
