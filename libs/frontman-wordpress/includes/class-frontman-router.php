<?php
/**
 * Router — intercepts /frontman/* requests at the WordPress level.
 *
 * Uses parse_request to catch requests before WordPress tries to resolve
 * them as posts/pages. This means the client can call the same paths as
 * all other Frontman adapters (Vite, Astro, Next.js):
 *
 *   GET  /frontman                        → Serve the UI (preview: homepage)
 *   GET  /about/frontman                  → Serve the UI (preview: /about)
 *   GET  /frontman/tools                  → Tool list
 *   POST /frontman/tools/call             → Dispatch tool call (SSE)
 *   POST /frontman/resolve-source-location → Not supported in WordPress PHP mode
 *
 * Suffix-based routing: appending /frontman to any WordPress URL opens
 * the Frontman UI with that page loaded in the web preview. The browser
 * URL stays in sync as the user navigates within the preview iframe.
 *
 * Every route is guarded by Frontman_Auth::check() — only logged-in
 * administrators can access any Frontman endpoint.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Router {
	private Frontman_Tools    $tools;
	private Frontman_UI       $ui;

	public function __construct(
		Frontman_Tools $tools,
		Frontman_UI $ui
	) {
		$this->tools    = $tools;
		$this->ui       = $ui;
	}

	/**
	 * Register hooks.
	 */
	public function register(): void {
		add_action( 'parse_request', [ $this, 'intercept' ], 1 );
	}

	/**
	 * Intercept Frontman requests before WordPress resolves them.
	 *
	 * Handles two route styles:
	 *   Prefix: /frontman/tools, /frontman/tools/call (API endpoints)
	 *   Suffix: /any/path/frontman (UI with that path in the web preview)
	 */
	public function intercept( \WP $wp ): void {
		$request_uri = $this->get_request_path();
		// phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotSanitized -- REQUEST_METHOD is read once, then immediately unslashed and sanitized with sanitize_text_field() before routing.
		$method_raw  = isset( $_SERVER['REQUEST_METHOD'] ) ? wp_unslash( $_SERVER['REQUEST_METHOD'] ) : 'GET';
		$method      = strtoupper( sanitize_text_field( $method_raw ) );
		$route       = $this->classify_route( $request_uri, $method );

		if ( 'prefix' === $route['type'] ) {
			$sub_path = $route['subPath'];

			$this->require_auth( true );
			if ( $method === 'POST' ) {
				$this->require_nonce();
			}

			switch ( true ) {
				case $method === 'GET' && $sub_path === 'tools':
					$this->handle_get_tools();
					exit;

				case $method === 'POST' && $sub_path === 'tools/call':
					$this->handle_tool_call();
					exit;

				case $method === 'POST' && $sub_path === 'resolve-source-location':
					$this->handle_resolve_source_location();
					exit;

				case $method === 'OPTIONS':
					status_header( 204 );
					exit;

				default:
					status_header( 404 );
					header( 'Content-Type: application/json; charset=utf-8' );
					echo wp_json_encode( [ 'error' => 'Not found' ] );
					exit;
			}
		}

		if ( 'suffix' !== $route['type'] ) {
			return;
		}

		$suffix_prefix = $route['prefix'];

		$this->require_auth( false );

		// Canonical redirect: strip nested /frontman/frontman segments.
		$canonical = $this->get_canonical_redirect( $suffix_prefix );
		if ( $canonical !== null ) {
			wp_safe_redirect( home_url( $canonical ), 302 );
			exit;
		}

		// Build the preview path from the suffix prefix.
		$preview_path = ( $suffix_prefix === '' ) ? '/' : '/' . $suffix_prefix;
		$this->ui->render_page( $preview_path );
		exit;
	}

	/**
	 * Classify a request path as a prefix API route, suffix UI route, or neither.
	 *
	 * @return array{type:string, subPath?:string, prefix?:string}
	 */
	private function classify_route( string $request_uri, string $method ): array {
		if ( 'GET' === $method ) {
			$suffix_prefix = $this->get_suffix_prefix( $request_uri );
			if ( null !== $suffix_prefix ) {
				return [
					'type'   => 'suffix',
					'prefix' => $suffix_prefix,
				];
			}
		}

		if ( preg_match( '#^/frontman/(.+)$#', $request_uri, $matches ) ) {
			return [
				'type'    => 'prefix',
				'subPath' => $matches[1],
			];
		}

		return [ 'type' => 'none' ];
	}

	/**
	 * Check auth and send error response if unauthorized.
	 */
	private function require_auth( bool $is_api ): void {
		$auth = Frontman_Auth::check();
		if ( is_wp_error( $auth ) ) {
			Frontman_Auth::send_error( $auth, $is_api );
		}
	}

	/**
	 * Check nonce and send API error response if invalid.
	 */
	private function require_nonce(): void {
		$nonce = Frontman_Auth::verify_nonce();
		if ( is_wp_error( $nonce ) ) {
			Frontman_Auth::send_error( $nonce, true );
		}
	}

	/**
	 * Extract the prefix path from a suffix-based UI route.
	 *
	 * Mirrors FrontmanCore__Middleware.getSuffixRoutePrefix().
	 *
	 * /frontman           → '' (bare route, preview homepage)
	 * /about/frontman     → 'about'
	 * /blog/post/frontman → 'blog/post'
	 * /frontman/tools     → null (not a suffix route — has sub-path)
	 *
	 * @return string|null The prefix path (may be empty), or null if not a suffix route.
	 */
	private function get_suffix_prefix( string $path ): ?string {
		$base = 'frontman';

		// Bare /frontman route.
		if ( $path === '/' . $base ) {
			return '';
		}

		// Suffix route: /anything/frontman.
		$suffix = '/' . $base;
		if ( substr( $path, -strlen( $suffix ) ) === $suffix ) {
			// Strip leading slash and trailing /frontman.
			$prefix = substr( $path, 1, strlen( $path ) - 1 - strlen( $suffix ) );
			return $prefix;
		}

		return null;
	}

	/**
	 * Detect nested /frontman/frontman segments and return canonical path.
	 *
	 * Mirrors FrontmanCore__Middleware.getCanonicalRedirect().
	 * Prevents frontman-in-frontman loops when the iframe navigates
	 * to a URL that already contains /frontman.
	 *
	 * @return string|null Canonical path to redirect to, or null if already canonical.
	 */
	private function get_canonical_redirect( string $prefix_path ): ?string {
		$base   = 'frontman';
		$suffix = '/' . $base;

		// Exact: prefix IS "frontman" (from /frontman/frontman).
		if ( $prefix_path === $base ) {
			return '/' . $base;
		}

		// Trailing nested: prefix ends with /frontman.
		if ( substr( $prefix_path, -strlen( $suffix ) ) === $suffix ) {
			$stripped = substr( $prefix_path, 0, strlen( $prefix_path ) - strlen( $suffix ) );
			return ( $stripped === '' ) ? '/' . $base : '/' . $stripped . '/' . $base;
		}

		// Leading nested: prefix starts with frontman/.
		if ( strpos( $prefix_path, $base . '/' ) === 0 ) {
			$rest = substr( $prefix_path, strlen( $base ) + 1 );
			return ( $rest === '' ) ? '/' . $base : '/' . $rest . '/' . $base;
		}

		return null;
	}

	/**
	 * Get the request path relative to the site root.
	 *
	 * Handles WordPress installed in a subdirectory (e.g. /blog/frontman).
	 */
	private function get_request_path(): string {
		// phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotSanitized -- REQUEST_URI is read once, then immediately unslashed before query-string stripping and path normalization.
		$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';

		// Strip query string.
		$path = strtok( $request_uri, '?' );

		// Strip the site's home path prefix if WP is in a subdirectory.
		$home_url_parts = wp_parse_url( home_url() );
		$home_path      = is_array( $home_url_parts ) ? ( $home_url_parts['path'] ?? '' ) : '';
		if ( $home_path !== '' && $home_path !== '/' ) {
			$home_path = rtrim( $home_path, '/' );
			if ( strpos( $path, $home_path ) === 0 ) {
				$path = substr( $path, strlen( $home_path ) );
			}
		}

		// Strip trailing slash (WordPress adds one, but our routes don't expect it).
		$path = rtrim( $path, '/' );

		// Ensure leading slash.
		if ( $path === '' || $path[0] !== '/' ) {
			$path = '/' . $path;
		}

		return $path;
	}

	/**
	 * Read JSON body from the request.
	 */
	private function read_json_body(): array {
		$raw  = file_get_contents( 'php://input' );
		$data = json_decode( $raw, true );
		return is_array( $data ) ? $data : [];
	}

	/**
	 * GET /frontman/tools — return plugin tool definitions.
	 */
	private function handle_get_tools(): void {
		$all_tools = $this->tools->all_definitions();

		status_header( 200 );
		header( 'Content-Type: application/json; charset=utf-8' );
		echo wp_json_encode( [
			'tools'           => $all_tools,
			'serverInfo'      => [
				'name'    => 'frontman-wordpress',
				'version' => FRONTMAN_VERSION,
			],
			'protocolVersion' => '1.0',
		] );
	}

	/**
	 * POST /frontman/tools/call — route by tool name.
	 *
	 * Tools are handled locally in the WordPress plugin.
	 */
	private function handle_tool_call(): void {
		$body  = $this->read_json_body();
		$name  = $body['name'] ?? '';
		$input = $body['arguments'] ?? $body['input'] ?? [];

		if ( empty( $name ) ) {
			$this->send_sse_tool_result( Frontman_Tools::error_result( 'Missing tool name' ) );
			return;
		}

		// WP tools — handle locally.
		if ( $this->tools->is_wp_tool( $name ) ) {
			try {
				// call() returns MCP-compliant callToolResult with _meta.
				$result = $this->tools->call( $name, $input );
				$this->send_sse_tool_result( $result );
			} catch ( \Throwable $e ) {
				$this->send_sse_tool_result( Frontman_Tools::error_result( $e->getMessage() ) );
			}
			return;
		}

		$this->send_sse_tool_result( Frontman_Tools::error_result( 'Unknown tool: ' . $name ) );
	}

	/**
	 * Send an MCP callToolResult payload over SSE.
	 */
	private function send_sse_tool_result( array $result ): void {
		header( 'Content-Type: text/event-stream' );
		header( 'Cache-Control: no-cache' );
		header( 'X-Accel-Buffering: no' );
		echo "event: result\ndata: " . wp_json_encode( $result ) . "\n\n";
	}

	/**
	 * POST /frontman/resolve-source-location — not supported in WordPress PHP mode.
	 */
	private function handle_resolve_source_location(): void {
		status_header( 501 );
		header( 'Content-Type: application/json; charset=utf-8' );
		echo wp_json_encode(
			[
				'error' => 'Source location resolution is not supported by the WordPress PHP tool runtime yet.',
			]
		);
	}
}
