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

	public function __construct() {
		$reflection = new ReflectionClass( 'Frontman_Router' );
		$this->classifyRoute = $reflection->getMethod( 'classify_route' );
		$this->getRequestPath = $reflection->getMethod( 'get_request_path' );
		if ( PHP_VERSION_ID < 80100 ) {
			$this->classifyRoute->setAccessible( true );
			$this->getRequestPath->setAccessible( true );
		}
	}

	public function run(): void {
		$this->test_suffix_routes_win_over_prefix_regex();
		$this->test_exact_mcp_route_and_legacy_route_removal();
		$this->test_protected_resource_metadata_routes_are_absent();
		$this->test_non_frontman_routes_are_ignored();
		$this->test_request_path_preserves_percent_encoded_segments();
		$this->test_tool_results_use_canonical_shape();

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

	private function test_exact_mcp_route_and_legacy_route_removal(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();

		$this->assert_same( 'mcp', $this->classifyRoute->invoke( $router, '/mcp', 'POST' )['type'], 'root MCP route is exact' );
		$this->assert_same( 'mcp', $this->classifyRoute->invoke( $router, '/mcp', 'OPTIONS' )['type'], 'MCP preflight uses the same exact route' );
		$this->assert_same( 'none', $this->classifyRoute->invoke( $router, '/mcp/', 'POST' )['type'], 'trailing slash is not normalized' );
		$this->assert_same( 'none', $this->classifyRoute->invoke( $router, '/MCP', 'POST' )['type'], 'route matching is case-sensitive' );
		$this->assert_same( 'none', $this->classifyRoute->invoke( $router, '/frontman/mcp', 'POST' )['type'], 'private MCP alias is absent' );
		$this->assert_same( 'none', $this->classifyRoute->invoke( $router, '/frontman/tools', 'GET' )['type'], 'legacy tool listing route is removed' );
		$this->assert_same( 'none', $this->classifyRoute->invoke( $router, '/frontman/tools/call', 'POST' )['type'], 'legacy tool call route is removed' );
	}

	private function test_protected_resource_metadata_routes_are_absent(): void {
		$router = ( new ReflectionClass( 'Frontman_Router' ) )->newInstanceWithoutConstructor();
		$paths = [
			'/.well-known/oauth-protected-resource',
			'/.well-known/oauth-protected-resource/mcp',
			'/.well-known/oauth-protected-resource/scope:frontman-runtime/mcp',
			'/scope:frontman-runtime/.well-known/oauth-protected-resource/mcp',
		];

		foreach ( $paths as $path ) {
			$this->assert_same( 'none', $this->classifyRoute->invoke( $router, $path, 'GET' )['type'], 'protected-resource metadata route is absent at ' . $path );
		}
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

	private function test_tool_results_use_canonical_shape(): void {
		$this->assert_same(
			[
				'resultType' => 'complete',
				'content'    => [ [ 'type' => 'text', 'text' => '{"ok":true}' ] ],
			],
			Frontman_Tools::success_result( [ 'ok' => true ] ),
			'successful tool results should contain only canonical fields'
		);
		$this->assert_same(
			[
				'resultType' => 'complete',
				'content'    => [ [ 'type' => 'text', 'text' => 'Failed' ] ],
				'isError'    => true,
			],
			Frontman_Tools::error_result( 'Failed' ),
			'error tool results should contain only canonical fields'
		);
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
