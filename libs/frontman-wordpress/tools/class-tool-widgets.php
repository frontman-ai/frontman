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

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Widgets {
	private const SUPPORTED_MUTATION_WIDGET_BASES = [ 'text' ];

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
			'Creates a new widget instance and places it in a sidebar. Currently supports text widgets only.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'sidebar_id'   => [ 'type' => 'string', 'description' => 'The sidebar/widget area ID.' ],
					'widget_base'  => [ 'type' => 'string', 'description' => 'The widget base ID, such as text or categories.' ],
					'settings'     => [ 'type' => 'string', 'description' => 'JSON-encoded object of widget settings.' ],
					'position'     => [ 'type' => 'integer', 'description' => 'Optional 1-based insertion position.' ],
				],
				'required' => [ 'sidebar_id', 'widget_base', 'settings' ],
			],
			[ $this, 'create_widget' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_update_widget',
			'Updates a widget\'s settings in a sidebar. Currently supports text widgets only.',
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
						'description' => 'The widget instance ID (e.g. "text-2", "categories-3").',
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
			'Moves a widget to a different sidebar or position.',
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
			'Deletes a widget from its sidebar. Ask the user for confirmation first and only call this tool with confirm=true after they approve.',
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
		if ( ! preg_match( '/^(.+)-(\d+)$/', $widget_id, $matches ) ) {
			throw new Frontman_Tool_Error( "Invalid widget ID format: {$widget_id}" );
		}

		return [
			'base'   => $matches[1],
			'number' => (int) $matches[2],
		];
	}

	private function assert_mutation_supported( string $widget_base ): void {
		if ( ! in_array( $widget_base, self::SUPPORTED_MUTATION_WIDGET_BASES, true ) ) {
			throw new Frontman_Tool_Error( 'Widget mutations currently support these widget types only: ' . implode( ', ', self::SUPPORTED_MUTATION_WIDGET_BASES ) );
		}
	}

	private function widget_sidebar_map(): array {
		$sidebars_widgets = get_option( $this->core_sidebars_widgets_option_name(), [] );
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

	private function sanitized_settings( $raw ): array {
		$settings = is_string( $raw ) ? ( json_decode( $raw, true ) ?? [] ) : ( is_array( $raw ) ? $raw : [] );
		return $this->sanitize_value_recursive( $settings );
	}

	/**
	 * WordPress core stores widget instances in widget_{base} options.
	 */
	private function core_widget_option_name( string $widget_base ): string {
		return 'widget_' . sanitize_key( $widget_base );
	}

	/**
	 * WordPress core stores sidebar assignments in this built-in option.
	 */
	private function core_sidebars_widgets_option_name(): string {
		return 'sidebars_widgets';
	}

	private function sanitize_value_recursive( $value ) {
		if ( is_array( $value ) ) {
			$result = [];
			foreach ( $value as $key => $item ) {
				$result[ $key ] = $this->sanitize_value_recursive( $item );
			}
			return $result;
		}

		if ( is_bool( $value ) || is_int( $value ) || is_float( $value ) || null === $value ) {
			return $value;
		}

		return sanitize_text_field( (string) $value );
	}

	/**
	 * wp_list_widget_areas handler.
	 */
	public function list_widget_areas( array $input ): array {
		global $wp_registered_sidebars;

		$sidebars_widgets = get_option( $this->core_sidebars_widgets_option_name(), [] );
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
		$settings = get_option( $this->core_widget_option_name( $parts['base'] ), [] );
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
		$sidebar_id  = sanitize_key( $input['sidebar_id'] ?? '' );
		$widget_base = sanitize_key( $input['widget_base'] ?? '' );
		$settings    = $this->sanitized_settings( $input['settings'] ?? '{}' );
		$before      = $this->sidebar_snapshot( $sidebar_id );
		$this->assert_mutation_supported( $widget_base );

		$all_settings = get_option( $this->core_widget_option_name( $widget_base ), [] );
		$max_number   = 0;
		foreach ( array_keys( $all_settings ) as $key ) {
			if ( is_numeric( $key ) ) {
				$max_number = max( $max_number, (int) $key );
			}
		}

		$widget_number = $max_number + 1;
		$widget_id     = $widget_base . '-' . $widget_number;
		$all_settings[ $widget_number ] = $settings;
		update_option( $this->core_widget_option_name( $widget_base ), $all_settings );

		$sidebars_widgets = get_option( $this->core_sidebars_widgets_option_name(), [] );
		$widgets = $sidebars_widgets[ $sidebar_id ] ?? [];
		$position = isset( $input['position'] ) ? max( 0, absint( $input['position'] ) - 1 ) : count( $widgets );
		$position = min( $position, count( $widgets ) );
		array_splice( $widgets, $position, 0, [ $widget_id ] );
		$sidebars_widgets[ $sidebar_id ] = $widgets;
		update_option( $this->core_sidebars_widgets_option_name(), $sidebars_widgets );

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
		$sidebar_id = sanitize_key( $input['sidebar_id'] ?? '' );
		$widget_id  = sanitize_text_field( $input['widget_id'] ?? '' );
		$settings   = $this->sanitized_settings( $input['settings'] ?? '{}' );

		if ( empty( $sidebar_id ) || empty( $widget_id ) ) {
			throw new Frontman_Tool_Error( 'Missing sidebar_id or widget_id' );
		}

		$parts = $this->parse_widget_id( $widget_id );
		$widget_base   = $parts['base'];
		$widget_number = $parts['number'];
		$this->assert_mutation_supported( $widget_base );

		// Get current widget settings.
		$all_settings = get_option( $this->core_widget_option_name( $widget_base ), [] );

		if ( ! isset( $all_settings[ $widget_number ] ) ) {
			throw new Frontman_Tool_Error( "Widget instance not found: {$widget_id}" );
		}

		$before = $all_settings[ $widget_number ];

		// Merge new settings.
		$all_settings[ $widget_number ] = array_merge( $all_settings[ $widget_number ], $settings );

		update_option( $this->core_widget_option_name( $widget_base ), $all_settings );

		return [
			'before'    => $before,
			'updated'   => true,
			'widget_id' => $widget_id,
			'settings'  => $all_settings[ $widget_number ],
		];
	}

	/**
	 * wp_move_widget handler.
	 */
	public function move_widget( array $input ): array {
		$widget_id     = sanitize_text_field( $input['widget_id'] ?? '' );
		$to_sidebar_id = sanitize_key( $input['to_sidebar_id'] ?? '' );
		$map           = $this->widget_sidebar_map();

		if ( ! isset( $map[ $widget_id ] ) ) {
			throw new Frontman_Tool_Error( "Widget instance not found: {$widget_id}" );
		}

		$from_sidebar_id = $map[ $widget_id ]['sidebar_id'];
		$before = [
			'widget'       => $this->read_widget( [ 'widget_id' => $widget_id ] ),
			'from_sidebar' => $this->sidebar_snapshot( $from_sidebar_id ),
			'to_sidebar'   => $this->sidebar_snapshot( $to_sidebar_id ),
		];

		$sidebars_widgets = get_option( $this->core_sidebars_widgets_option_name(), [] );
		$from_widgets = array_values( array_filter( $sidebars_widgets[ $from_sidebar_id ] ?? [], static function( $id ) use ( $widget_id ) {
			return $id !== $widget_id;
		} ) );
		$to_widgets = ( $from_sidebar_id === $to_sidebar_id ) ? $from_widgets : ( $sidebars_widgets[ $to_sidebar_id ] ?? [] );

		$position = isset( $input['to_position'] ) ? max( 0, absint( $input['to_position'] ) - 1 ) : count( $to_widgets );
		$position = min( $position, count( $to_widgets ) );
		array_splice( $to_widgets, $position, 0, [ $widget_id ] );

		$sidebars_widgets[ $from_sidebar_id ] = $from_widgets;
		$sidebars_widgets[ $to_sidebar_id ]   = $to_widgets;
		update_option( $this->core_sidebars_widgets_option_name(), $sidebars_widgets );

		return [
			'moved'  => true,
			'before' => $before,
			'after'  => [
				'widget'       => $this->read_widget( [ 'widget_id' => $widget_id ] ),
				'from_sidebar' => $this->sidebar_snapshot( $from_sidebar_id ),
				'to_sidebar'   => $this->sidebar_snapshot( $to_sidebar_id ),
			],
		];
	}

	/**
	 * wp_delete_widget handler.
	 */
	public function delete_widget( array $input ): array {
		$widget_id = sanitize_text_field( $input['widget_id'] ?? '' );
		if ( empty( $input['confirm'] ) ) {
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

		$sidebars_widgets = get_option( $this->core_sidebars_widgets_option_name(), [] );
		$sidebars_widgets[ $sidebar_id ] = array_values( array_filter( $sidebars_widgets[ $sidebar_id ] ?? [], static function( $id ) use ( $widget_id ) {
			return $id !== $widget_id;
		} ) );
		update_option( $this->core_sidebars_widgets_option_name(), $sidebars_widgets );

		return [
			'deleted'   => true,
			'widget_id' => $widget_id,
			'before'    => $before,
			'after'     => $this->sidebar_snapshot( $sidebar_id ),
		];
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
