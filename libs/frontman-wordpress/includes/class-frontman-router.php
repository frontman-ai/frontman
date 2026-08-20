<?php
/**
 * Router — intercepts /frontman/* requests at the WordPress level.
 *
 * Uses parse_request to catch requests before WordPress tries to resolve
 * them as posts/pages. This means the client can call the same paths as
 * all other Frontman adapters:
 *
 *   GET  /frontman                        → Serve the UI (preview: homepage)
 *   GET  /about/frontman                  → Serve the UI (preview: /about)
 *   POST /mcp                             → MCP request
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
	 * Handles exact /mcp and suffix /any/path/frontman UI routes.
	 */
	public function intercept( \WP $wp ): void {
		$request_uri = $this->get_request_path();
		$method      = isset( $_SERVER['REQUEST_METHOD'] ) ? wp_unslash( $_SERVER['REQUEST_METHOD'] ) : 'GET';
		$route       = $this->classify_route( $request_uri, $method );

		if ( 'mcp' === $route['type'] ) {
			$this->handle_mcp( $method );
			exit;
		}

		if ( 'source-location' === $route['type'] ) {
			$this->require_auth( true );
			$this->require_nonce();
			$this->handle_resolve_source_location();
			exit;
		}

		if ( 'suffix' !== $route['type'] ) {
			return;
		}

		$suffix_prefix = $route['prefix'];

		$this->require_auth( false );

		$canonical = $this->get_canonical_redirect( $suffix_prefix );
		if ( $canonical !== null ) {
			wp_safe_redirect( home_url( $canonical ), 302 );
			exit;
		}

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
		if ( '/mcp' === $request_uri ) {
			return [ 'type' => 'mcp' ];
		}
		if ( '/mcp/' !== $request_uri ) {
			$request_uri = rtrim( $request_uri, '/' );
		}

		if ( 'GET' === $method ) {
			$suffix_prefix = $this->get_suffix_prefix( $request_uri );
			if ( null !== $suffix_prefix ) {
				return [
					'type'   => 'suffix',
					'prefix' => $suffix_prefix,
				];
			}
		}

		if ( '/frontman/resolve-source-location' === $request_uri && 'POST' === $method ) {
			return [ 'type' => 'source-location' ];
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
	 * /frontman/tools     → null
	 *
	 * @return string|null The prefix path (may be empty), or null if not a suffix route.
	 */
	private function get_suffix_prefix( string $path ): ?string {
		$base = 'frontman';

		if ( $path === '/' . $base ) {
			return '';
		}

		$suffix = '/' . $base;
		if ( substr( $path, -strlen( $suffix ) ) === $suffix ) {
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

		if ( $prefix_path === $base ) {
			return '/' . $base;
		}

		if ( substr( $prefix_path, -strlen( $suffix ) ) === $suffix ) {
			$stripped = substr( $prefix_path, 0, strlen( $prefix_path ) - strlen( $suffix ) );
			return ( $stripped === '' ) ? '/' . $base : '/' . $stripped . '/' . $base;
		}

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
		$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';

		$path = strtok( $request_uri, '?' );
		if ( false === $path ) {
			$path = '/';
		}

		$home_url_parts = wp_parse_url( home_url() );
		$home_path      = is_array( $home_url_parts ) ? ( $home_url_parts['path'] ?? '' ) : '';
		if ( $home_path !== '' && $home_path !== '/' ) {
			$home_path = rtrim( $home_path, '/' );
			if ( strpos( $path, $home_path ) === 0 ) {
				$path = substr( $path, strlen( $home_path ) );
			}
		}

		if ( $path === '' ) {
			return '/';
		}

		if ( $path[0] !== '/' ) {
			$path = '/' . $path;
		}

		return $path;
	}

	private function handle_mcp( string $method ): void {
		$home = wp_parse_url( home_url() );
		if ( ! is_array( $home ) || ! isset( $home['scheme'], $home['host'] ) ) {
			throw new \RuntimeException( 'WordPress home URL has no HTTP Origin' );
		}
		$origin = strtolower( $home['scheme'] ) . '://' . strtolower( $home['host'] );
		if ( isset( $home['port'] ) ) {
			$origin .= ':' . (int) $home['port'];
		}

		$mcp = new Frontman_MCP( $this->tools, $origin );
		$response = $mcp->handle(
			$method,
			$this->request_headers(),
			function (): string { return $this->read_mcp_body(); },
			function () use ( $method ): array {
				$auth = Frontman_Auth::check();
				if ( is_wp_error( $auth ) ) {
					$data = $auth->get_error_data();
					return [ 'status' => is_array( $data ) && isset( $data['status'] ) ? (int) $data['status'] : 403 ];
				}
				if ( 'POST' === $method ) {
					$nonce = Frontman_Auth::verify_nonce();
					if ( is_wp_error( $nonce ) ) {
						return [ 'status' => 403 ];
					}
				}
				return [
					'status'    => 200,
					'principal' => 'wordpress:' . (int) get_current_blog_id() . ':user:' . (int) get_current_user_id(),
				];
			}
		);

		status_header( $response['status'] );
		foreach ( $response['headers'] as $name => $value ) {
			header( $name . ': ' . $value );
		}
		echo $response['body'];
	}

	private function read_mcp_body(): string {
		$stream = fopen( 'php://input', 'rb' );
		if ( false === $stream ) {
			throw new \RuntimeException( 'Failed to open MCP request body' );
		}
		$body = '';
		while ( ! feof( $stream ) && strlen( $body ) <= 2097152 ) {
			$chunk = fread( $stream, min( 8192, 2097153 - strlen( $body ) ) );
			if ( false === $chunk ) {
				fclose( $stream );
				throw new \RuntimeException( 'Failed to read MCP request body' );
			}
			$body .= $chunk;
		}
		fclose( $stream );
		return $body;
	}

	private function request_headers(): array {
		$headers = [];
		foreach ( $_SERVER as $name => $value ) {
			if ( ! is_string( $value ) ) {
				continue;
			}
			if ( 0 === strpos( $name, 'HTTP_' ) ) {
				$header = str_replace( ' ', '-', ucwords( strtolower( str_replace( '_', ' ', substr( $name, 5 ) ) ) ) );
				$headers[ $header ] = wp_unslash( $value );
			}
		}
		if ( isset( $_SERVER['CONTENT_TYPE'] ) ) {
			$headers['Content-Type'] = wp_unslash( $_SERVER['CONTENT_TYPE'] );
		}
		if ( isset( $_SERVER['CONTENT_LENGTH'] ) ) {
			$headers['Content-Length'] = wp_unslash( $_SERVER['CONTENT_LENGTH'] );
		}
		return $headers;
	}

	/**
	 * POST /frontman/resolve-source-location — not supported in WordPress PHP mode.
	 */
	private function handle_resolve_source_location(): void {
		wp_send_json(
			[
				'error' => 'Source location resolution is not supported by the WordPress PHP tool runtime yet.',
			],
			501
		);
	}
}
