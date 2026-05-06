<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-no-filesystem-tools/' );

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'wp_check_invalid_utf8' ) ) {
	function wp_check_invalid_utf8( $value ): string {
		return (string) $value;
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

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-agent-instructions-tool.php';
require_once __DIR__ . '/../tools/class-tool-posts.php';
require_once __DIR__ . '/../tools/class-tool-blocks.php';
require_once __DIR__ . '/../tools/class-tool-media.php';
require_once __DIR__ . '/../tools/class-tool-menus.php';
require_once __DIR__ . '/../tools/class-tool-options.php';
require_once __DIR__ . '/../tools/class-tool-templates.php';
require_once __DIR__ . '/../tools/class-tool-widgets.php';
require_once __DIR__ . '/../tools/class-tool-cache.php';

class Frontman_No_Filesystem_Tools_Test_Runner {
	private int $assertions = 0;

	public function run(): void {
		$tools = new Frontman_Tools();
		( new Frontman_Agent_Instructions_Tool() )->register( $tools );
		( new Frontman_Tool_Posts() )->register( $tools );
		( new Frontman_Tool_Blocks() )->register( $tools );
		( new Frontman_Tool_Media() )->register( $tools );
		( new Frontman_Tool_Menus() )->register( $tools );
		( new Frontman_Tool_Options() )->register( $tools );
		( new Frontman_Tool_Templates() )->register( $tools );
		( new Frontman_Tool_Widgets() )->register( $tools );
		( new Frontman_Tool_Cache() )->register( $tools );

		$tool_names = array_column( $tools->all_definitions(), 'name' );
		$blocked = [
			'read_file',
			'list_files',
			'file_exists',
			'grep',
			'search_files',
			'list_tree',
			'wp_get_managed_theme_status',
			'wp_create_managed_theme',
			'wp_activate_managed_theme',
			'wp_list_managed_theme_files',
			'wp_read_managed_theme_file',
			'wp_write_managed_theme_file',
			'wp_fork_parent_theme_file',
		];

		foreach ( $blocked as $tool_name ) {
			$this->assert_false( in_array( $tool_name, $tool_names, true ), $tool_name . ' must not be exposed by the WordPress plugin' );
		}

		$load_agent_instructions = $tools->get( 'load_agent_instructions' );
		$this->assert_same( false, $load_agent_instructions->visible_to_agent, 'load_agent_instructions remains hidden from the agent' );
		$this->assert_same( [], call_user_func( $load_agent_instructions->handler, [] ), 'load_agent_instructions must not read from disk in WordPress' );

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . ' expected ' . var_export( $expected, true ) . ' got ' . var_export( $actual, true ) );
		}
	}

	private function assert_false( bool $condition, string $message ): void {
		$this->assertions++;
		if ( $condition ) {
			throw new RuntimeException( $message );
		}
	}
}

( new Frontman_No_Filesystem_Tools_Test_Runner() )->run();
