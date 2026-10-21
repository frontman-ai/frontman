<?php
/** WebFactory 301 Redirects 1.05 storage adapter. */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_301_Redirects {
	public static function is_available(): bool {
		$file = WP_PLUGIN_DIR . '/301-redirects/301-redirects.php';
		if ( ! Frontman_Plugin_Dependencies::is_available( '301-redirects/301-redirects.php' )
			|| ! class_exists( 'ts_redirects', false ) || ! is_file( $file ) ) {
			return false;
		}
		$data = get_file_data( $file, [ 'version' => 'Version', 'author' => 'Author' ] );
		return '1.05' === $data['version'] && 'WebFactory Ltd' === $data['author'];
	}

	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_301_redirects_list',
			'Lists WebFactory 301 Redirects rules (exact URL matching, fixed 301). Page is zero-based with up to 100 rules per page. Inspect this store and Redirection separately; ask the user about ownership and conflicts before choosing a store. Never automatically select a provider.',
			[ 'type' => 'object', 'properties' => [ 'page' => [ 'type' => 'integer', 'minimum' => 0 ] ], 'additionalProperties' => false ],
			[ $this, 'list_redirects' ], 'read', true, true
		) );
	}

	private function path( $value ): string {
		if ( ! is_string( $value ) || strlen( $value ) > 2000
			|| ! preg_match( '~^/[a-zA-Z0-9/._\x7e-]*$~D', $value )
			|| strpos( $value, '//' ) !== false || preg_match( '~(?:^|/)\.{1,2}(?:/|$)~', $value ) ) {
			throw new Frontman_Tool_Error( 'Use a literal ASCII site-relative path without query, fragment, encoding or dot segments.' );
		}
		return $value;
	}

	private function target( $value ): string {
		if ( is_string( $value ) && substr( $value, 0, 1 ) === '/' ) {
			return get_bloginfo( 'url' ) . $this->path( $value );
		}
		if ( ! is_string( $value ) || strlen( $value ) > 2000
			|| preg_match( '/[\x00-\x20\x7f\\\\]/', $value )
			|| preg_match( '/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i', $value )
			|| ! filter_var( $value, FILTER_VALIDATE_URL ) ) {
			throw new Frontman_Tool_Error( 'Target must be a safe site-relative path or absolute HTTP(S) URL.' );
		}
		$parts = wp_parse_url( $value );
		if ( ! in_array( strtolower( $parts['scheme'] ?? '' ), [ 'http', 'https' ], true )
			|| isset( $parts['user'] ) || isset( $parts['pass'] ) ) {
			throw new Frontman_Tool_Error( 'Only HTTP(S) targets without credentials are supported.' );
		}
		return $value;
	}

	private function confirm( array $input ): void {
		$this->guard();
		if ( true !== ( $input['confirm'] ?? null ) ) {
			throw new Frontman_Tool_Error( 'User approval and exact confirm=true are required.' );
		}
	}

	private function guard(): void {
		if ( ! self::is_available() || ! current_user_can( 'manage_options' ) ) {
			throw new Frontman_Tool_Error( '301 Redirects 1.05 must be active; manage_options is required.' );
		}
	}

	public function list_redirects( array $input ): array {
		$this->guard();
		$page = $input['page'] ?? 0;
		if ( ! is_int( $page ) || $page < 0 || $page > intdiv( PHP_INT_MAX, 100 ) ) {
			throw new Frontman_Tool_Error( 'page must be a non-negative integer within the supported offset range.' );
		}
		global $wpdb;
		$rows = $wpdb->get_results( $wpdb->prepare(
			"SELECT id, title, section, old_link, new_link FROM {$wpdb->prefix}ts_redirects ORDER BY id ASC LIMIT %d OFFSET %d",
			100, $page * 100
		), ARRAY_A );
		if ( ! is_array( $rows ) || $wpdb->last_error ) {
			throw new Frontman_Tool_Error( 'Cannot read 301 Redirects storage. Initialize it in the plugin admin and inspect database errors.' );
		}
		$total = $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->prefix}ts_redirects" );
		if ( null === $total || $wpdb->last_error ) {
			throw new Frontman_Tool_Error( 'Cannot count 301 Redirects storage. Inspect database errors.' );
		}
		return [ 'redirects' => $rows, 'page' => $page, 'per_page' => 100, 'total' => (int) $total ];
	}
}
