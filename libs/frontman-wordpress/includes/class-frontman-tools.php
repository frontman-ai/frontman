<?php

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Error extends \RuntimeException {}

class Frontman_Tool_Definition {
	public string $name;
	public string $description;
	public string $access;
	public array  $input_schema;
	public bool   $visible_to_agent;
	public bool   $preserve_input_strings;
	public $handler;

	public function __construct(
		string $name,
		string $description,
		array $input_schema,
		callable $handler,
		?string $access = null,
		bool $visible_to_agent = true,
		bool $preserve_input_strings = false
	) {
		$this->name                   = $name;
		$this->description            = $description;
		$this->access                 = $this->normalize_access( $access ?? self::infer_access( $name ) );
		$this->input_schema           = $input_schema;
		$this->handler                = $handler;
		$this->visible_to_agent       = $visible_to_agent;
		$this->preserve_input_strings = $preserve_input_strings;
	}

	public function to_array(): array {
		return [
			'name'           => $this->name,
			'description'    => $this->description,
			'access'         => $this->access,
			'inputSchema'    => $this->input_schema,
			'visibleToAgent' => $this->visible_to_agent,
		];
	}

	private function normalize_access( string $access ): string {
		if ( in_array( $access, [ 'read', 'write', 'read-write' ], true ) ) {
			return $access;
		}

		return 'read-write';
	}

	private static function infer_access( string $name ): string {
		foreach ( [ 'wp_list_', 'wp_read_', 'wp_get_', 'wc_get_', 'wc_list_' ] as $prefix ) {
			if ( 0 === strpos( $name, $prefix ) ) {
				return 'read';
			}
		}

		foreach ( [ 'wp_create_', 'wp_duplicate_', 'wp_insert_', 'wp_upload_', 'wc_create_' ] as $prefix ) {
			if ( 0 === strpos( $name, $prefix ) ) {
				return 'write';
			}
		}

		return 'read-write';
	}
}

class Frontman_Tools {
	private array $tools = [];

	private static ?self $instance = null;

	public static function instance(): self {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	public function add( Frontman_Tool_Definition $tool ): void {
		$this->tools[ $tool->name ] = $tool;
	}

	public function get( string $name ): ?Frontman_Tool_Definition {
		return $this->tools[ $name ] ?? null;
	}

	public function all_definitions(): array {
		return array_values(
			array_map(
				function( Frontman_Tool_Definition $t ) { return $t->to_array(); },
				$this->tools
			)
		);
	}

	public function sanitize_input( string $name, array $input ): array {
		$tool = $this->get( $name );
		if ( ! $tool ) {
			return $this->sanitize_untyped_array( $input, $name );
		}

		$sanitized = $this->sanitize_value_for_schema( $input, $tool->input_schema, $name, '', $tool->preserve_input_strings );
		return is_array( $sanitized ) ? $sanitized : [];
	}

	public function call( string $name, array $input ): array {
		$tool = $this->get( $name );
		if ( ! $tool ) {
			$tool_name = sanitize_text_field( $name );

			throw new \RuntimeException(
				sprintf(
					esc_html__( 'Unknown tool: %s', 'frontman-agentic-ai-editor' ),
					esc_html( $tool_name ),
				)
			);
		}

		try {
			$data = ( $tool->handler )( $input );
			return self::success_result( $data );
		} catch ( Frontman_Tool_Error $e ) {
			return self::error_result( $e->getMessage() );
		}
	}

	public function is_wp_tool( string $name ): bool {
		return isset( $this->tools[ $name ] );
	}

	public static function success_result( $data ): array {
		$text = is_string( $data ) ? $data : wp_json_encode( $data );
		return [
			'content' => [ [ 'type' => 'text', 'text' => $text ] ],
			'isError' => false,
		];
	}

	public static function error_result( string $message ): array {
		return [
			'content' => [ [ 'type' => 'text', 'text' => $message ] ],
			'isError' => true,
		];
	}

	private function sanitize_value_for_schema( $value, array $schema, string $tool_name, string $field_name, bool $preserve_input_strings = false ) {
		$type = $schema['type'] ?? null;

		switch ( $type ) {
			case 'object':
				return is_array( $value ) ? $this->sanitize_object_for_schema( $value, $schema, $tool_name, $preserve_input_strings ) : ( $preserve_input_strings ? null : [] );

			case 'array':
				if ( ! is_array( $value ) ) {
					return $preserve_input_strings ? null : [];
				}

				$item_schema = isset( $schema['items'] ) && is_array( $schema['items'] ) ? $schema['items'] : [];
				return array_values(
					array_map(
						function ( $item ) use ( $item_schema, $tool_name, $field_name, $preserve_input_strings ) {
							return $this->sanitize_value_for_schema( $item, $item_schema, $tool_name, $field_name, $preserve_input_strings );
						},
						$value
					)
				);

			case 'integer':
				return (int) $value;

			case 'number':
				return (float) $value;

			case 'boolean':
				return filter_var( $value, FILTER_VALIDATE_BOOLEAN );

			case 'string':
				if ( 'css' === $field_name && 'wp_update_custom_css' === $tool_name && ! is_string( $value ) ) {
					return $value;
				}

				return $this->sanitize_string_value( (string) $value, $tool_name, $field_name, $preserve_input_strings );
		}

		if ( is_array( $value ) ) {
			return $this->sanitize_untyped_array( $value, $tool_name, $preserve_input_strings );
		}

		if ( is_string( $value ) ) {
			return $this->sanitize_string_value( $value, $tool_name, $field_name, $preserve_input_strings );
		}

		if ( is_bool( $value ) || is_int( $value ) || is_float( $value ) || null === $value ) {
			return $value;
		}

		return sanitize_text_field( (string) $value );
	}

	private function sanitize_object_for_schema( array $value, array $schema, string $tool_name, bool $preserve_input_strings = false ): array {
		$properties            = isset( $schema['properties'] ) && is_array( $schema['properties'] ) ? $schema['properties'] : [];
		$allow_extra_properties = ! empty( $schema['additionalProperties'] );
		$sanitized             = [];

		foreach ( $properties as $property_name => $property_schema ) {
			if ( ! array_key_exists( $property_name, $value ) ) {
				continue;
			}

			$sanitized[ $property_name ] = is_array( $property_schema )
				? $this->sanitize_value_for_schema( $value[ $property_name ], $property_schema, $tool_name, (string) $property_name, $preserve_input_strings )
				: $this->sanitize_value_for_schema( $value[ $property_name ], [], $tool_name, (string) $property_name, $preserve_input_strings );
		}

		if ( $allow_extra_properties ) {
			foreach ( $value as $property_name => $property_value ) {
				if ( array_key_exists( $property_name, $sanitized ) ) {
					continue;
				}

				$sanitized[ $property_name ] = $this->sanitize_value_for_schema( $property_value, [], $tool_name, (string) $property_name, $preserve_input_strings );
			}
		}

		return $sanitized;
	}

	private function sanitize_untyped_array( array $value, string $tool_name, bool $preserve_input_strings = false ): array {
		$sanitized = [];
		foreach ( $value as $key => $item ) {
			$sanitized[ $key ] = $this->sanitize_value_for_schema( $item, [], $tool_name, (string) $key, $preserve_input_strings );
		}

		return $sanitized;
	}

	private function sanitize_string_value( string $value, string $tool_name, string $field_name, bool $preserve_input_strings = false ): string {
		$value = wp_check_invalid_utf8( $value );
		if ( $preserve_input_strings ) {
			return $value;
		}

		if ( in_array( $field_name, [ 'url', 'permalink' ], true ) ) {
			return esc_url_raw( $value );
		}

		if ( in_array( $field_name, [ 'post_type', 'status', 'orderby', 'order', 'type', 'widget_base', 'sidebar_id', 'to_sidebar_id', 'location', 'widget_name' ], true ) ) {
			return sanitize_key( $value );
		}

		if ( in_array( $field_name, [ 'block_markup', 'pattern', 'glob', 'settings', 'path', 'image_ref' ], true ) ) {
			return $value;
		}

		if ( 'content' === $field_name ) {
			return in_array( $tool_name, [ 'wp_update_template', 'wp_upload_media' ], true ) ? $value : wp_kses_post( $value );
		}

		if ( 'css' === $field_name && 'wp_update_custom_css' === $tool_name ) {
			return $value;
		}

		if ( 0 === strpos( $tool_name, 'wp_elementor_' ) ) {
			return $value;
		}

		if ( 'excerpt' === $field_name ) {
			return sanitize_textarea_field( $value );
		}

		return sanitize_text_field( $value );
	}
}
