<?php
/** Integration contract against the checksum-verified official SureRank 1.10.2. */
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

function surerank_check( bool $ok, string $message ): void {
	if ( ! $ok ) {
		throw new RuntimeException( $message );
	}
}

if ( in_array( '--setup', $argv, true ) ) {
	surerank_check( '1.10.2' === get_plugin_data( WP_PLUGIN_DIR . '/surerank/surerank.php', false, false )['Version'], 'Wrong installed SureRank version.' );
	surerank_check( ! is_wp_error( activate_plugin( 'surerank/surerank.php' ) ), 'SureRank activation failed.' );
	exit( 0 );
}

surerank_check( defined( 'SURERANK_VERSION' ) && '1.10.2' === SURERANK_VERSION, 'Real pinned SureRank must be loaded.' );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$tools = Frontman_Tools::instance();
$seo = new Frontman_Tool_Seo();
$info = ( new Frontman_Tool_Templates() )->get_site_info( [] );
if ( in_array( '--coexist', $argv, true ) ) {
	surerank_check( defined( 'WPSEO_VERSION' ) && is_plugin_active( 'wordpress-seo/wp-seo.php' ), 'Real Yoast must coexist.' );
	surerank_check( null === $tools->get( 'wp_read_seo' ) && null === $tools->get( 'wp_update_seo' ), 'Conflicting providers must not advertise SEO tools.' );
	surerank_check( null === $info['seo_capabilities']['provider'] && false === $info['seo_capabilities']['read'] && false === $info['seo_capabilities']['write'], 'Conflict capabilities are misleading.' );
	surerank_check( is_string( Frontman_Tool_Seo::read_unavailable_reason() ), 'Conflict read reason missing.' );
	foreach ( [ 'read_seo', 'update_seo' ] as $handler ) {
		try {
			$seo->$handler( [ 'id' => 1 ] + ( 'update_seo' === $handler ? [ 'title' => 'Must not save' ] : [] ) );
			throw new RuntimeException( 'Direct conflicting-provider operation accepted.' );
		} catch ( Frontman_Tool_Error $error ) {
			surerank_check( Frontman_Tool_Seo::read_unavailable_reason() === $error->getMessage(), 'Conflict direct guard differs.' );
		}
	}
	deactivate_plugins( 'wordpress-seo/wp-seo.php' );
	echo "OK (real SureRank and Yoast coexistence fails closed)\n";
	exit( 0 );
}

surerank_check( null === Frontman_Tool_Seo::read_unavailable_reason(), 'SureRank read unavailable.' );
$write_reason = Frontman_Tool_Seo::unavailable_reason();
surerank_check( is_string( $write_reason ) && '' !== $write_reason, 'SureRank writes must remain unavailable.' );
surerank_check( [
	'provider' => 'surerank', 'read' => true, 'write' => false,
	'supported_fields' => [ 'title', 'description', 'focus_keyphrase' ],
	'read_unavailable_reason' => null, 'write_unavailable_reason' => $write_reason,
] === $info['seo_capabilities'], 'Site info capability contract differs.' );
surerank_check( $write_reason === $info['seo_unavailable_reason'], 'Legacy reason must describe write eligibility.' );
surerank_check( null !== $tools->get( 'wp_read_seo' ) && null === $tools->get( 'wp_update_seo' ), 'SureRank must advertise only read.' );
surerank_check( '' !== SureRank\Inc\Functions\Settings::get( 'page_title' ), 'Real SureRank must have a nonempty global title template for default coverage.' );
$ids = [];
register_post_type( 'frontman_sure_item', [ 'public' => true, 'show_ui' => true, 'supports' => [ 'title', 'editor' ] ] );
try {
	foreach ( [ [ 'post', 'publish' ], [ 'page', 'draft' ], [ 'post', 'private' ], [ 'frontman_sure_item', 'publish' ] ] as [ $type, $status ] ) {
		$id = wp_insert_post( [ 'post_type' => $type, 'post_status' => $status, 'post_title' => 'SureRank defaults', 'post_content' => 'Default description content.' ], true );
		surerank_check( ! is_wp_error( $id ), 'Could not create fixture.' );
		$ids[] = $id;
		foreach ( [ [], [ 'page_title' => 'Stored %title% — "Café" \\ path', 'page_description' => 'Stored %excerpt% 日本 \\ description', 'focus_keyword' => 'Café focus 日本 \\ phrase' ], [ 'page_title' => '', 'page_description' => '', 'focus_keyword' => '' ] ] as $stored ) {
			foreach ( $stored as $key => $value ) {
				SureRank\Inc\Functions\Update::post_meta( $id, 'surerank_settings_' . $key, wp_slash( $value ) );
			}
			global $wpdb;
			$snapshot = static fn() => [
				$wpdb->get_results( "SELECT * FROM {$wpdb->posts} ORDER BY ID", ARRAY_A ),
				$wpdb->get_results( "SELECT * FROM {$wpdb->postmeta} ORDER BY meta_id", ARRAY_A ),
				$wpdb->get_results( "SELECT * FROM {$wpdb->options} WHERE option_name LIKE 'surerank%' ORDER BY option_id", ARRAY_A ),
			];
			$before = $snapshot();
			$read = $tools->call( 'wp_read_seo', $tools->sanitize_input( 'wp_read_seo', [ 'id' => $id ] ) );
			surerank_check( false === $read['isError'], 'Dispatcher read failed: ' . wp_json_encode( $read ) );
			$data = json_decode( $read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
			surerank_check( $id === $data['id'] && 'surerank' === $data['provider'] && ( $stored['page_title'] ?? '' ) === $data['title'] && ( $stored['page_description'] ?? '' ) === $data['description'], 'Read must return stored strings, not rendered defaults or expanded variables.' );
			surerank_check( ( $stored['focus_keyword'] ?? '' ) === $data['focus_keyphrase'] && ! array_key_exists( 'unsupported_fields', $data ), 'Stored focus keyphrase contract differs.' );
			foreach ( [ null, 'surerank_settings_page_title', 'surerank_settings_page_description', 'surerank_settings_focus_keyword' ] as $denied_key ) {
				$deny = static function ( $caps, $cap, $user_id, $args ) use ( $id, $denied_key ) {
					$matches = $id === ( $args[0] ?? null )
						&& ( null === $denied_key ? 'edit_post' === $cap : ( 'edit_post_meta' === $cap && $denied_key === ( $args[1] ?? null ) ) );
					return $matches ? [ 'do_not_allow' ] : $caps;
				};
				add_filter( 'map_meta_cap', $deny, PHP_INT_MAX, 4 );
				try {
					$expected_error = null === $denied_key ? 'You cannot edit this post.' : 'You cannot edit this post SEO metadata.';
					$denied = $tools->call( 'wp_read_seo', [ 'id' => $id ] );
					surerank_check( [
						'resultType' => 'complete',
						'content' => [ [ 'type' => 'text', 'text' => $expected_error ] ],
						'isError' => true,
					] === $denied, 'Dispatcher denial must return only the permission error, without stored fields.' );
					foreach ( $stored as $value ) {
						if ( '' !== $value ) {
							surerank_check( false === strpos( $denied['content'][0]['text'], $value ), 'Dispatcher denial disclosed a stored value.' );
						}
					}
					try {
						$seo->read_seo( [ 'id' => $id ] );
						throw new RuntimeException( 'Direct denied read accepted.' );
					} catch ( Frontman_Tool_Error $error ) {
						surerank_check( $expected_error === $error->getMessage(), 'Direct denial must return only the permission error.' );
					}
				} finally {
					remove_filter( 'map_meta_cap', $deny, PHP_INT_MAX );
				}
			}
			try {
				$tools->call( 'wp_update_seo', [ 'id' => $id, 'title' => 'Must not save' ] );
				throw new RuntimeException( 'Unregistered write route accepted.' );
			} catch ( RuntimeException $error ) {
				surerank_check( 'Unknown tool: wp_update_seo' === $error->getMessage(), 'Unregistered write route did not reject as unknown.' );
			}
			try {
				$seo->update_seo( [ 'id' => $id, 'title' => 'Must not save' ] );
				throw new RuntimeException( 'Direct SureRank write accepted.' );
			} catch ( Frontman_Tool_Error $error ) {
				surerank_check( $write_reason === $error->getMessage(), 'Direct write guard differs from site info.' );
			}
			surerank_check( $before === $snapshot(), 'Read or rejected operations mutated posts, metadata, or SureRank settings.' );
		}
	}
} finally {
	foreach ( $ids as $id ) {
		wp_delete_post( $id, true );
	}
	deactivate_plugins( 'surerank/surerank.php' );
	if ( '' !== ( getenv( 'EXPECTED_YOAST_VERSION' ) ?: '' ) ) {
		surerank_check( ! is_wp_error( activate_plugin( 'wordpress-seo/wp-seo.php' ) ), 'Could not restore Yoast.' );
	} else {
		surerank_check( ! is_plugin_active( 'wordpress-seo/wp-seo.php' ), 'SureRank tests activated an absent Yoast dependency.' );
	}
}
echo "OK (SureRank 1.10.2 stored overrides, defaults, permissions and read-only contract)\n";
