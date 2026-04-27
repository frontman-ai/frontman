<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-router-tests/' );

if ( ! class_exists( 'WP' ) ) {
	class WP {}
}

if ( ! function_exists( 'add_action' ) ) {
	function add_action( $hook, $callback, $priority = 10 ) {}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_unslash' ) ) {
	function wp_unslash( $value ) {
		return is_string( $value ) ? stripslashes( $value ) : $value;
	}
}

if ( ! function_exists( 'home_url' ) ) {
	function home_url( string $path = '' ): string {
		return 'https://example.test/blog' . $path;
	}
}

if ( ! function_exists( 'wp_parse_url' ) ) {
	function wp_parse_url( string $url ) {
		return parse_url( $url );
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-router.php';

class Frontman_Router_Test_Runner {
	private int $assertions = 0;
	private ReflectionMethod $classifyRoute;
	private ReflectionMethod $getRequestPath;
	private ReflectionMethod $sendSseToolResult;

	public function __construct() {
		$reflection = new ReflectionClass( 'Frontman_Router' );
		$this->classifyRoute = $reflection->getMethod( 'classify_route' );
		$this->getRequestPath = $reflection->getMethod( 'get_request_path' );
		$this->sendSseToolResult = $reflection->getMethod( 'send_sse_tool_result' );
	}

	public function run(): void {
		$this->test_suffix_routes_win_over_prefix_regex();
		$this->test_prefix_api_routes_still_match();
		$this->test_non_frontman_routes_are_ignored();
		$this->test_request_path_preserves_percent_encoded_segments();
		$this->test_sse_errors_use_result_event_format();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function test_suffix_routes_win_over_prefix_regex(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();

		$route = $this->classifyRoute->invoke( $router, '/frontman/frontman', 'GET' );
		$this->assert_same( 'suffix', $route['type'], '/frontman/frontman should be classified as a suffix route' );
		$this->assert_same( 'frontman', $route['prefix'], 'suffix route should preserve the nested frontman prefix for canonical redirect handling' );

		$route = $this->classifyRoute->invoke( $router, '/about/frontman', 'GET' );
		$this->assert_same( 'suffix', $route['type'], 'GET suffix routes should be handled before prefix API routes' );
		$this->assert_same( 'about', $route['prefix'], 'suffix route should preserve preview path' );
	}

	private function test_prefix_api_routes_still_match(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();

		$route = $this->classifyRoute->invoke( $router, '/frontman/tools', 'GET' );
		$this->assert_same( 'prefix', $route['type'], 'frontman API routes should still classify as prefix routes' );
		$this->assert_same( 'tools', $route['subPath'], 'prefix route should preserve API subpath' );

		$route = $this->classifyRoute->invoke( $router, '/frontman/tools/call', 'POST' );
		$this->assert_same( 'prefix', $route['type'], 'non-GET API routes should still classify as prefix routes' );
		$this->assert_same( 'tools/call', $route['subPath'], 'prefix route should preserve nested API subpath' );
	}

	private function test_non_frontman_routes_are_ignored(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();
		$route = $this->classifyRoute->invoke( $router, '/wp-admin/plugins.php', 'GET' );
		$this->assert_same( 'none', $route['type'], 'non-Frontman paths should not be intercepted' );
	}

	private function test_request_path_preserves_percent_encoded_segments(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();
		$_SERVER['REQUEST_URI'] = '/blog/caf%C3%A9/frontman?x=1';

		try {
			$path = $this->getRequestPath->invoke( $router );
			$this->assert_same( '/caf%C3%A9/frontman', $path, 'request path should preserve percent-encoded URL bytes' );
		} finally {
			unset( $_SERVER['REQUEST_URI'] );
		}
	}

	private function test_sse_errors_use_result_event_format(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();
		ob_start();
		$this->sendSseToolResult->invoke( $router, Frontman_Tools::error_result( 'Missing tool name' ) );
		$output = ob_get_clean();

		$this->assert_true( 0 === strpos( $output, "event: result\n" ), 'tool errors should be sent through SSE result events so the client parses MCP error payloads' );
		$this->assert_true( false !== strpos( $output, '"isError":true' ), 'SSE result payload should preserve MCP error metadata' );
		$this->assert_true( false !== strpos( $output, 'Missing tool name' ), 'SSE result payload should include the tool error message' );
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

( new Frontman_Router_Test_Runner() )->run();
