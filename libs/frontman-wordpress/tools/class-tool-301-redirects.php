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
			'Lists WebFactory 301 Redirects rules (exact URL matching, fixed 301). Inspect this store and Redirection separately; ask the user about ownership and conflicts before choosing a store. Never automatically select a provider.',
			[ 'type' => 'object', 'properties' => new stdClass(), 'additionalProperties' => false ],
			[ $this, 'list_redirects' ], 'read', true, true
		) );
	}

	private function guard(): void {
		if ( ! self::is_available() || ! current_user_can( 'manage_options' ) ) {
			throw new Frontman_Tool_Error( '301 Redirects 1.05 must be active; manage_options is required.' );
		}
	}

	public function list_redirects( array $input ): array {
		$this->guard();
		global $wpdb;
		// Do not call getAll(): it can create or rename tables during a read.
		$rows = $wpdb->get_results( "SELECT id, title, section, old_link, new_link FROM {$wpdb->prefix}ts_redirects ORDER BY id ASC", ARRAY_A );
		if ( ! is_array( $rows ) || $wpdb->last_error ) {
			throw new Frontman_Tool_Error( 'Cannot read 301 Redirects storage. Initialize it in the plugin admin and inspect database errors.' );
		}
		return [ 'redirects' => $rows ];
	}
}
