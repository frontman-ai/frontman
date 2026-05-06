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
	public array  $input_schema;
	public bool   $visible_to_agent;
	/** @var callable(array): array */
	public $handler;

	/**
	 * @param string   $name             Tool name (e.g. "wp_list_posts").
	 * @param string   $description      Human-readable description.
	 * @param array    $input_schema     JSON Schema for input (as PHP array).
	 * @param callable $handler          fn(array $input): array — returns plain data (JSON-serializable).
	 * @param bool     $visible_to_agent Whether the agent can see this tool.
	 */
	public function __construct(
		string $name,
		string $description,
		array $input_schema,
		callable $handler,
		bool $visible_to_agent = true
	) {
		$this->name             = $name;
		$this->description      = $description;
		$this->input_schema     = $input_schema;
		$this->handler          = $handler;
		$this->visible_to_agent = $visible_to_agent;
	}

	/**
	 * Serialize to relay protocol format.
	 */
	public function to_array(): array {
		return [
			'name'           => $this->name,
			'description'    => $this->description,
			'inputSchema'    => $this->input_schema,
			'visibleToAgent' => $this->visible_to_agent,
		];
	}
}

/**
 * Singleton tool registry.
 *
 * Mirrors FrontmanCore__Server.executeTool() — handlers return plain data,
 * the registry wraps into MCP callToolResult with _meta.
 */
class Frontman_Tools {
	/** @var Frontman_Tool_Definition[] */
	private array $tools = [];

	private static ?self $instance = null;

	/**
	 * MCP _meta object — matches MCP.emptyMeta on the ReScript side.
	 * { model: undefined, envApiKey: {} }
	 */
	private const EMPTY_META = [ 'envApiKey' => [] ];

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
		return array_values(
			array_map(
				function( Frontman_Tool_Definition $t ) { return $t->to_array(); },
				$this->tools
			)
		);
	}

	/**
	 * Sanitize tool input against the registered JSON schema before dispatch.
	 */
	public function sanitize_input( string $name, array $input ): array {
		$tool = $this->get( $name );
		if ( ! $tool ) {
			return $this->sanitize_untyped_array( $input, $name );
		}

		$sanitized = $this->sanitize_value_for_schema( $input, $tool->input_schema, $name, '' );
		return is_array( $sanitized ) ? $sanitized : [];
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
					/* translators: %s: tool name */
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
			'content' => [ [ 'type' => 'text', 'text' => $text ] ],
			'_meta'   => self::meta(),
		];
	}

	/**
	 * Build an error callToolResult.
	 */
	public static function error_result( string $message ): array {
		return [
			'content' => [ [ 'type' => 'text', 'text' => $message ] ],
			'isError' => true,
			'_meta'   => self::meta(),
		];
	}

	/**
	 * Build the _meta object for callToolResult.
	 *
	 * Uses stdClass for envApiKey so json_encode produces {} not [].
	 */
	private static function meta(): array {
		return [ 'envApiKey' => new \stdClass() ];
	}

	/**
	 * Sanitize a value using a JSON-schema fragment.
	 */
	private function sanitize_value_for_schema( $value, array $schema, string $tool_name, string $field_name ) {
		$type = $schema['type'] ?? null;

		switch ( $type ) {
			case 'object':
				return is_array( $value ) ? $this->sanitize_object_for_schema( $value, $schema, $tool_name ) : [];

			case 'array':
				if ( ! is_array( $value ) ) {
					return [];
				}

				$item_schema = isset( $schema['items'] ) && is_array( $schema['items'] ) ? $schema['items'] : [];
				return array_values(
					array_map(
						function ( $item ) use ( $item_schema, $tool_name, $field_name ) {
							return $this->sanitize_value_for_schema( $item, $item_schema, $tool_name, $field_name );
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
				return $this->sanitize_string_value( (string) $value, $tool_name, $field_name );
		}

		if ( is_array( $value ) ) {
			return $this->sanitize_untyped_array( $value, $tool_name );
		}

		if ( is_string( $value ) ) {
			return $this->sanitize_string_value( $value, $tool_name, $field_name );
		}

		if ( is_bool( $value ) || is_int( $value ) || is_float( $value ) || null === $value ) {
			return $value;
		}

		return sanitize_text_field( (string) $value );
	}

	/**
	 * Sanitize object properties and drop unexpected fixed-schema fields.
	 */
	private function sanitize_object_for_schema( array $value, array $schema, string $tool_name ): array {
		$properties            = isset( $schema['properties'] ) && is_array( $schema['properties'] ) ? $schema['properties'] : [];
		$allow_extra_properties = ! empty( $schema['additionalProperties'] );
		$sanitized             = [];

		foreach ( $properties as $property_name => $property_schema ) {
			if ( ! array_key_exists( $property_name, $value ) ) {
				continue;
			}

			$sanitized[ $property_name ] = is_array( $property_schema )
				? $this->sanitize_value_for_schema( $value[ $property_name ], $property_schema, $tool_name, (string) $property_name )
				: $this->sanitize_value_for_schema( $value[ $property_name ], [], $tool_name, (string) $property_name );
		}

		if ( $allow_extra_properties ) {
			foreach ( $value as $property_name => $property_value ) {
				if ( array_key_exists( $property_name, $sanitized ) ) {
					continue;
				}

				$sanitized[ $property_name ] = $this->sanitize_value_for_schema( $property_value, [], $tool_name, (string) $property_name );
			}
		}

		return $sanitized;
	}

	/**
	 * Sanitize arrays whose schema permits dynamic keys.
	 */
	private function sanitize_untyped_array( array $value, string $tool_name ): array {
		$sanitized = [];
		foreach ( $value as $key => $item ) {
			$sanitized[ $key ] = $this->sanitize_value_for_schema( $item, [], $tool_name, (string) $key );
		}

		return $sanitized;
	}

	/**
	 * Apply the narrowest safe string sanitizer available for each tool field.
	 */
	private function sanitize_string_value( string $value, string $tool_name, string $field_name ): string {
		$value = wp_check_invalid_utf8( $value );

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

		if ( 0 === strpos( $tool_name, 'wp_elementor_' ) ) {
			return $value;
		}

		if ( 'excerpt' === $field_name ) {
			return sanitize_textarea_field( $value );
		}

		return sanitize_text_field( $value );
	}
}
