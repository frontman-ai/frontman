<?php
/**
 * Tool registry — holds WP tool definitions and dispatches calls.
 *
 * Architecture mirrors the ReScript core server (FrontmanCore__Server):
 * - Tool handlers return plain data arrays on success, throw Frontman_Tool_Error on failure
 * - The registry wraps results into MCP-compliant format with _meta
 * - Individual handlers never construct MCP wire format directly
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Exception for tool execution errors.
 *
 * Throw this from handlers to signal a tool-level error.
 * The registry catches it and wraps it into an MCP error result.
 */
class Frontman_Tool_Error extends \RuntimeException {}

/**
 * Represents a single tool definition.
 */
class Frontman_Tool_Definition {
	public string $name;
	public string $description;
	public string $access;
	public array  $input_schema;
	public bool   $visible_to_agent;
	public bool   $preserve_input_strings;
	/** @var callable(array): array */
	public $handler;

	/**
	 * @param string   $name             Tool name (e.g. "wp_list_posts").
	 * @param string   $description      Human-readable description.
	 * @param array    $input_schema     JSON Schema for input (as PHP array).
	 * @param callable $handler          fn(array $input): array — returns plain data (JSON-serializable).
	 * @param string|null $access              Tool access level: read, write, or read-write. Inferred from name when omitted.
	 * @param bool     $visible_to_agent       Whether the agent can see this tool.
	 * @param bool     $preserve_input_strings Whether schema sanitization should preserve raw string values for downstream API validation.
	 */
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
		$definition = [
			'name'        => $this->name,
			'description' => $this->description,
			'inputSchema' => $this->input_schema,
			'annotations' => [ 'readOnlyHint' => 'read' === $this->access ],
		];

		if ( 'wp_upload_media' === $this->name ) {
			$definition['_meta'] = [
				'ai.frontman/attachment-resolution' => [
					'version'             => 1,
					'referenceArgument'   => 'image_ref',
					'contentArgument'     => 'content',
					'encodingArgument'    => 'encoding',
					'encodingValue'       => 'base64',
					'removeReference'     => false,
					'mediaTypeArgument'   => 'mime_type',
				],
			];
		}

		return $definition;
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

/**
 * Singleton tool registry.
 *
 * Mirrors FrontmanCore__Server.executeTool() — handlers return plain data,
 * the registry wraps into MCP callToolResult with _meta.
 */
class Frontman_Tools {
	public const MAX_TOOLS = 256;
	public const MAX_DEFINITION_BYTES = 65536;
	public const MAX_CATALOG_BYTES = 1048576;

	/** @var Frontman_Tool_Definition[] */
	private array $tools = [];
	private int $catalog_bytes = 0;

	private static ?self $instance = null;

	public static function instance(): self {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	/**
	 * Register a tool definition.
	 */
	public function add( Frontman_Tool_Definition $tool ): void {
		if ( ! preg_match( '/^[A-Za-z0-9_.-]{1,128}$/D', $tool->name ) ) {
			throw new \InvalidArgumentException( 'Invalid tool name' );
		}
		if ( isset( $this->tools[ $tool->name ] ) ) {
			throw new \InvalidArgumentException( 'Duplicate tool name' );
		}
		if ( count( $this->tools ) >= self::MAX_TOOLS ) {
			throw new \LengthException( 'Tool count limit exceeded' );
		}
		$this->validate_schema_definition( $tool->input_schema, true );
		$encoded = wp_json_encode( $tool->to_array(), JSON_UNESCAPED_SLASHES );
		if ( ! is_string( $encoded ) ) {
			throw new \InvalidArgumentException( 'Tool definition is not JSON serializable' );
		}
		$definition_bytes = strlen( $encoded );
		if ( $definition_bytes > self::MAX_DEFINITION_BYTES ) {
			throw new \LengthException( 'Tool definition byte limit exceeded' );
		}
		if ( $this->catalog_bytes + $definition_bytes > self::MAX_CATALOG_BYTES ) {
			throw new \LengthException( 'Tool catalog byte limit exceeded' );
		}
		$this->catalog_bytes += $definition_bytes;
		$this->tools[ $tool->name ] = $tool;
	}

	/**
	 * Look up a tool by name.
	 */
	public function get( string $name ): ?Frontman_Tool_Definition {
		return $this->tools[ $name ] ?? null;
	}

	/**
	 * Return all tool definitions as serializable arrays.
	 *
	 * @return array[]
	 */
	public function all_definitions(): array {
		$tools = array_filter(
			$this->tools,
			function ( Frontman_Tool_Definition $tool ): bool { return $tool->visible_to_agent; }
		);
		ksort( $tools, SORT_STRING );
		return array_values( array_map( function ( Frontman_Tool_Definition $tool ): array { return $tool->to_array(); }, $tools ) );
	}

	/**
	 * Sanitize tool input against the registered JSON schema before dispatch.
	 */
	public function sanitize_input( string $name, array $input ): array {
		$tool = $this->get( $name );
		if ( ! $tool ) {
			return $this->sanitize_untyped_array( $input, $name );
		}

		$sanitized = $this->sanitize_value_for_schema( $input, $tool->input_schema, $name, '', $tool->preserve_input_strings );
		return is_array( $sanitized ) ? $sanitized : [];
	}

	public function valid_input( string $name, $input ): bool {
		$tool = $this->get( $name );
		return null !== $tool && $this->valid_schema_value( $input, $tool->input_schema );
	}

	/**
	 * Execute a tool by name and return an MCP-compliant callToolResult.
	 *
	 * Mirrors FrontmanCore__Server.executeTool():
	 * - Ok(output) → { content: [{type: "text", text: json}], _meta }
	 * - Error(msg) → { content: [{type: "text", text: msg}], isError: true, _meta }
	 *
	 * @param string $name  Tool name.
	 * @param array  $input Tool input arguments.
	 * @return array MCP callToolResult.
	 * @throws \RuntimeException If tool not found (not a tool-level error).
	 */
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

	/**
	 * Check if a tool name is a WP tool (handled locally).
	 */
	public function is_wp_tool( string $name ): bool {
		return isset( $this->tools[ $name ] );
	}

	/**
	 * Build a success callToolResult.
	 *
	 * @param array|string $data JSON-serializable data (array) or pre-encoded string.
	 */
	public static function success_result( $data ): array {
		$text = is_string( $data ) ? $data : wp_json_encode( $data );
		return [
			'resultType' => 'complete',
			'content'    => [ [ 'type' => 'text', 'text' => $text ] ],
		];
	}

	/**
	 * Build an error callToolResult.
	 */
	public static function error_result( string $message ): array {
		return [
			'resultType' => 'complete',
			'content'    => [ [ 'type' => 'text', 'text' => $message ] ],
			'isError'    => true,
		];
	}

	/**
	 * Sanitize a value using a JSON-schema fragment.
	 */
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

	/**
	 * Sanitize object properties and drop unexpected fixed-schema fields.
	 */
	private function sanitize_object_for_schema( array $value, array $schema, string $tool_name, bool $preserve_input_strings = false ): array {
		$properties            = isset( $schema['properties'] ) && is_array( $schema['properties'] ) ? $schema['properties'] : [];
		$allow_extra_properties = ! array_key_exists( 'additionalProperties', $schema ) || true === $schema['additionalProperties'];
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

	/**
	 * Sanitize arrays whose schema permits dynamic keys.
	 */
	private function sanitize_untyped_array( array $value, string $tool_name, bool $preserve_input_strings = false ): array {
		$sanitized = [];
		foreach ( $value as $key => $item ) {
			$sanitized[ $key ] = $this->sanitize_value_for_schema( $item, [], $tool_name, (string) $key, $preserve_input_strings );
		}

		return $sanitized;
	}

	/**
	 * Apply the narrowest safe string sanitizer available for each tool field.
	 */
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

	private function validate_schema_definition( array $schema, bool $root = false ): void {
		$allowed = [ 'type', 'properties', 'required', 'additionalProperties', 'items', 'enum', 'minProperties', 'description', 'default' ];
		if ( $root ) {
			$allowed[] = '$schema';
		}
		foreach ( array_keys( $schema ) as $keyword ) {
			if ( ! in_array( $keyword, $allowed, true ) ) {
				throw new \InvalidArgumentException( 'Unsupported JSON Schema keyword' );
			}
		}
		if ( isset( $schema['$schema'] ) && 'https://json-schema.org/draft/2020-12/schema' !== $schema['$schema'] ) {
			throw new \InvalidArgumentException( 'Unsupported JSON Schema dialect' );
		}
		$types = [ 'object', 'array', 'string', 'integer', 'number', 'boolean', 'null' ];
		$type = $schema['type'] ?? null;
		if ( null !== $type && ( ! is_string( $type ) || ! in_array( $type, $types, true ) ) ) {
			throw new \InvalidArgumentException( 'Schema requires one supported type' );
		}
		if ( $root && 'object' !== $type ) {
			throw new \InvalidArgumentException( 'Tool input schema root must be an object' );
		}
		if ( isset( $schema['description'] ) && ! is_string( $schema['description'] ) ) {
			throw new \InvalidArgumentException( 'Schema description must be a string' );
		}
		if ( array_key_exists( 'properties', $schema ) ) {
			if ( 'object' !== $type ) {
				throw new \InvalidArgumentException( 'Schema properties require object type' );
			}
			$properties = $this->schema_properties( $schema['properties'] );
			foreach ( $properties as $name => $property_schema ) {
				if ( ! is_string( $name ) || ! is_array( $property_schema ) ) {
					throw new \InvalidArgumentException( 'Invalid schema property' );
				}
				$this->validate_schema_definition( $property_schema );
			}
		}
		if ( array_key_exists( 'required', $schema ) ) {
			if ( 'object' !== $type || ! is_array( $schema['required'] ) ) {
				throw new \InvalidArgumentException( 'Invalid schema required keyword' );
			}
			$required_names = [];
			foreach ( $schema['required'] as $name ) {
				if ( ! is_string( $name ) || isset( $required_names[ $name ] ) ) {
					throw new \InvalidArgumentException( 'Invalid schema required property' );
				}
				$required_names[ $name ] = true;
			}
		}
		if ( array_key_exists( 'additionalProperties', $schema ) && ( 'object' !== $type || ! is_bool( $schema['additionalProperties'] ) ) ) {
			throw new \InvalidArgumentException( 'Unsupported additionalProperties schema' );
		}
		if ( array_key_exists( 'minProperties', $schema ) && ( 'object' !== $type || ! is_int( $schema['minProperties'] ) || $schema['minProperties'] < 0 ) ) {
			throw new \InvalidArgumentException( 'Invalid minProperties constraint' );
		}
		if ( array_key_exists( 'items', $schema ) ) {
			if ( 'array' !== $type || ! is_array( $schema['items'] ) ) {
				throw new \InvalidArgumentException( 'Invalid items schema' );
			}
			$this->validate_schema_definition( $schema['items'] );
		}
		if ( 'array' === $type && ! isset( $schema['items'] ) ) {
			throw new \InvalidArgumentException( 'Array schema requires items' );
		}
		if ( array_key_exists( 'enum', $schema ) ) {
			if ( ! is_array( $schema['enum'] ) || [] === $schema['enum'] ) {
				throw new \InvalidArgumentException( 'Invalid enum constraint' );
			}
			if ( null === $type || in_array( $type, [ 'object', 'array' ], true ) ) {
				throw new \InvalidArgumentException( 'Unsupported enum value profile' );
			}
			foreach ( $schema['enum'] as $index => $enum_value ) {
				if ( ! $this->valid_type( $enum_value, $type ) ) {
					throw new \InvalidArgumentException( 'Enum value does not match schema type' );
				}
				foreach ( array_slice( $schema['enum'], 0, $index ) as $prior_value ) {
					if ( $this->schema_values_equal( $enum_value, $prior_value ) ) {
						throw new \InvalidArgumentException( 'Enum values must be unique' );
					}
				}
			}
		}
	}

	private function schema_properties( $properties ): array {
		if ( $properties instanceof \stdClass ) {
			return get_object_vars( $properties );
		}
		if ( is_array( $properties ) ) {
			return $properties;
		}
		throw new \InvalidArgumentException( 'Schema properties must be an object' );
	}

	private function valid_schema_value( $value, array $schema ): bool {
		$type = $schema['type'] ?? null;
		if ( ! $this->valid_type( $value, $type ) ) {
			return false;
		}
		if ( isset( $schema['enum'] ) ) {
			$matched = false;
			foreach ( $schema['enum'] as $enum_value ) {
				if ( $this->schema_values_equal( $value, $enum_value ) ) {
					$matched = true;
					break;
				}
			}
			if ( ! $matched ) {
				return false;
			}
		}
		if ( 'object' === $type ) {
			$properties = isset( $schema['properties'] ) ? $this->schema_properties( $schema['properties'] ) : [];
			foreach ( $schema['required'] ?? [] as $required ) {
				if ( ! property_exists( $value, $required ) ) {
					return false;
				}
			}
			if ( isset( $schema['minProperties'] ) && count( get_object_vars( $value ) ) < $schema['minProperties'] ) {
				return false;
			}
			foreach ( get_object_vars( $value ) as $name => $property_value ) {
				if ( isset( $properties[ $name ] ) ) {
					if ( ! $this->valid_schema_value( $property_value, $properties[ $name ] ) ) {
						return false;
					}
				} elseif ( array_key_exists( 'additionalProperties', $schema ) && false === $schema['additionalProperties'] ) {
					return false;
				}
			}
		}
		if ( 'array' === $type ) {
			foreach ( $value as $item ) {
				if ( ! $this->valid_schema_value( $item, $schema['items'] ) ) {
					return false;
				}
			}
		}
		return true;
	}

	private function valid_type( $value, ?string $type ): bool {
		if ( null === $type ) {
			return true;
		}
		switch ( $type ) {
			case 'object':
				return $value instanceof \stdClass;
			case 'array':
				return is_array( $value );
			case 'string':
				return is_string( $value );
			case 'integer':
				return is_int( $value );
			case 'number':
				return is_int( $value ) || is_float( $value );
			case 'boolean':
				return is_bool( $value );
			case 'null':
				return null === $value;
		}
		return false;
	}

	private function schema_values_equal( $left, $right ): bool {
		if ( ( is_int( $left ) || is_float( $left ) ) && ( is_int( $right ) || is_float( $right ) ) ) {
			return (float) $left === (float) $right;
		}
		return $left === $right;
	}
}
