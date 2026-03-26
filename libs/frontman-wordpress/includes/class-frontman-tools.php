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
					esc_html__( 'Unknown tool: %s', 'frontman' ),
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
}
