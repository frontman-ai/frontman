<?php

frontman_runtime_assert( defined( 'SURERANK_VERSION' ) && '1.10.2' === SURERANK_VERSION, 'Real pinned SureRank must be loaded.' );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$tools = Frontman_Tools::instance();
$seo = new Frontman_Tool_Seo();
$info = ( new Frontman_Tool_Templates() )->get_site_info( [] );
frontman_runtime_assert( null === Frontman_Tool_Seo::read_unavailable_reason(), 'SureRank read unavailable.' );
$write_reason = Frontman_Tool_Seo::unavailable_reason();
frontman_runtime_assert( is_string( $write_reason ) && '' !== $write_reason, 'SureRank writes must remain unavailable.' );
frontman_runtime_assert( [
	'provider' => 'surerank', 'read' => true, 'write' => false,
	'supported_fields' => [ 'title', 'description', 'focus_keyphrase' ],
	'read_unavailable_reason' => null, 'write_unavailable_reason' => $write_reason,
] === $info['seo_capabilities'], 'Site info capability contract differs.' );
frontman_runtime_assert( $write_reason === $info['seo_unavailable_reason'], 'Legacy reason must describe write eligibility.' );
frontman_runtime_assert( null !== $tools->get( 'wp_read_seo' ) && null === $tools->get( 'wp_update_seo' ), 'SureRank must advertise only read.' );
frontman_runtime_assert( '' !== SureRank\Inc\Functions\Settings::get( 'page_title' ), 'Real SureRank must have a nonempty global title template for default coverage.' );
$ids = [];
register_post_type( 'frontman_sure_item', [ 'public' => true, 'show_ui' => true, 'supports' => [ 'title', 'editor' ] ] );
try {
	foreach ( [ [ 'post', 'publish' ], [ 'page', 'draft' ], [ 'post', 'private' ], [ 'frontman_sure_item', 'publish' ] ] as [ $type, $status ] ) {
		$id = wp_insert_post( [ 'post_type' => $type, 'post_status' => $status, 'post_title' => 'SureRank defaults', 'post_content' => 'Default description content.' ], true );
		frontman_runtime_assert( ! is_wp_error( $id ), 'Could not create fixture.' );
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
			frontman_runtime_assert( false === $read['isError'], 'Dispatcher read failed: ' . wp_json_encode( $read ) );
			$data = json_decode( $read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
			frontman_runtime_assert( $id === $data['id'] && 'surerank' === $data['provider'] && ( $stored['page_title'] ?? '' ) === $data['title'] && ( $stored['page_description'] ?? '' ) === $data['description'], 'Read must return stored strings, not rendered defaults or expanded variables.' );
			frontman_runtime_assert( ( $stored['focus_keyword'] ?? '' ) === $data['focus_keyphrase'] && ! array_key_exists( 'unsupported_fields', $data ), 'Stored focus keyphrase contract differs.' );
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
					frontman_runtime_assert( [
						'resultType' => 'complete',
						'content' => [ [ 'type' => 'text', 'text' => $expected_error ] ],
						'isError' => true,
					] === $denied, 'Dispatcher denial must return only the permission error, without stored fields.' );
					foreach ( $stored as $value ) {
						if ( '' !== $value ) {
							frontman_runtime_assert( false === strpos( $denied['content'][0]['text'], $value ), 'Dispatcher denial disclosed a stored value.' );
						}
					}
					try {
						$seo->read_seo( [ 'id' => $id ] );
						throw new RuntimeException( 'Direct denied read accepted.' );
					} catch ( Frontman_Tool_Error $error ) {
						frontman_runtime_assert( $expected_error === $error->getMessage(), 'Direct denial must return only the permission error.' );
					}
				} finally {
					remove_filter( 'map_meta_cap', $deny, PHP_INT_MAX );
				}
			}
			try {
				$tools->call( 'wp_update_seo', [ 'id' => $id, 'title' => 'Must not save' ] );
				throw new RuntimeException( 'Unregistered write route accepted.' );
			} catch ( RuntimeException $error ) {
				frontman_runtime_assert( 'Unknown tool: wp_update_seo' === $error->getMessage(), 'Unregistered write route did not reject as unknown.' );
			}
			try {
				$seo->update_seo( [ 'id' => $id, 'title' => 'Must not save' ] );
				throw new RuntimeException( 'Direct SureRank write accepted.' );
			} catch ( Frontman_Tool_Error $error ) {
				frontman_runtime_assert( $write_reason === $error->getMessage(), 'Direct write guard differs from site info.' );
			}
			frontman_runtime_assert( $before === $snapshot(), 'Read or rejected operations mutated posts, metadata, or SureRank settings.' );
		}
	}
} finally {
	foreach ( $ids as $id ) {
		wp_delete_post( $id, true );
	}
}
