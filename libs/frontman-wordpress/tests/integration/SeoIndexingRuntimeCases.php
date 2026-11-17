<?php

declare(strict_types=1);

global $wpdb;
wp_set_current_user( $admin->ID );
$handler = new Frontman_Tool_Seo();
$tools = new Frontman_Tools();
$handler->register( $tools );
frontman_runtime_same( [ 'default', 'noindex', 'index' ], $tools->get( 'wp_update_seo' )->input_schema['properties']['indexing']['enum'] ?? null, 'Yoast advertises the stored indexing enum.' );
$call = static function( array $input, bool $error = false, string $fault = '', string $name = 'wp_update_seo' ) use ( $cookie, $nonce ) {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $input ], null, $fault );
	frontman_runtime_same( [ 200, $error ], [ $response['status'], $response['body']['isError'] ], 'Indexing dispatch (' . $fault . '): ' . wp_json_encode( $response ) );
	$text = $response['body']['content'][0]['text'];
	return $error ? $text : json_decode( $text, true, 512, JSON_THROW_ON_ERROR );
};
$ids = [];
$titles = get_option( 'wpseo_titles' );
try {
	foreach ( [ 'publish', 'publish', 'draft', 'private' ] as $status ) {
		$id = wp_insert_post( [ 'post_type' => 'page', 'post_status' => $status, 'post_title' => 'Indexing fixture ' . $status, 'post_content' => 'Indexing undisclosed body' ], true );
		frontman_runtime_assert( is_int( $id ), 'Create indexing fixture.' );
		$ids[] = $id;
		update_post_meta( $id, '_frontman_indexing_unrelated', 'keep' );
	}
	$id = $ids[0];
	WPSEO_Meta::set_value( 'canonical', get_permalink( $id ), $id );
	WPSEO_Meta::set_value( 'opengraph-title', 'Explicit indexing social', $id );
	$render = static fn( int $target, string $fault = 'render' ): array => frontman_runtime_http( 'GET', str_replace( home_url(), '', get_permalink( $target ) ), '', null, null, $fault );
	$persisted = static fn() => YoastSEO()->classes->get( \Yoast\WP\SEO\Repositories\Indexable_Repository::class )->query()->where( 'object_type', 'post' )->where( 'object_id', $id )->find_one();
	$protected = static function() use ( $wpdb, $ids, $id ): array {
		return [
			$wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->posts} WHERE ID IN (%d,%d,%d,%d) ORDER BY ID", ...$ids ), ARRAY_A ),
			$wpdb->get_results( $wpdb->prepare( "SELECT post_id,meta_key,meta_value FROM {$wpdb->postmeta} WHERE post_id IN (%d,%d,%d,%d) AND NOT (post_id = %d AND meta_key IN ('_yoast_wpseo_meta-robots-noindex','_yoast_wpseo_title','_yoast_wpseo_metadesc')) ORDER BY post_id,meta_key", ...array_merge( $ids, [ $id ] ) ), ARRAY_A ),
			$wpdb->get_results( "SELECT option_name,option_value FROM {$wpdb->options} WHERE option_name IN ('blogname','blogdescription','blog_public','wpseo_titles','wpseo_social') ORDER BY option_name", ARRAY_A ),
		];
	};
	$robots = static function( array $response ): array {
		$directives = [];
		foreach ( $response['meta_tags'] as $tag ) {
			if ( preg_match( '/robots|bot/i', $tag['name'] ) ) {
				$directives[] = [ $tag['name'], preg_split( '/\s*,\s*/', strtolower( $tag['content'] ) ) ];
			}
		}
		foreach ( $response['headers'] as $header ) {
			if ( 0 === stripos( $header, 'X-Robots-Tag:' ) ) { $directives[] = [ 'header', strtolower( $header ) ]; }
		}
		return $directives;
	};
	$render( $id );
	frontman_runtime_assert( false !== $persisted(), 'Warm the real persisted indexable before mutation.' );
	$safe = $protected();
	foreach ( [ 'default', 'noindex', 'noindex', 'index', 'index', 'default', 'default', 'index', 'noindex', 'default' ] as $preference ) {
		$before = $call( [ 'id' => $id ], false, '', 'wp_read_seo' )['indexing'];
		$saved = $call( [ 'id' => $id, 'indexing' => $preference ] );
		frontman_runtime_same( [ $before, $preference, $before !== $preference, true ], [ $saved['before']['indexing'], $saved['after']['indexing'], $saved['changed'], $saved['indexable_refreshed'] ], 'Enum transition and repeat snapshots.' );
		$indexable = $persisted();
		frontman_runtime_same( [ 'default' => null, 'noindex' => true, 'index' => false ][$preference], $indexable->is_robots_noindex, 'Independent persisted tri-state.' );
		wp_cache_delete( $id, 'post_meta' );
		frontman_runtime_same( [ 'default' => '0', 'noindex' => '1', 'index' => '2' ][$preference], WPSEO_Meta::get_value( 'meta-robots-noindex', $id ), 'Native stored enum.' );
		if ( 'default' === $preference ) { frontman_runtime_same( false, metadata_exists( 'post', $id, '_yoast_wpseo_meta-robots-noindex' ), 'Reset deletes the override.' ); }
		$html = $render( $id );
		frontman_runtime_same( 200, $html['status'], 'Independent anonymous GET.' );
		$observed = $robots( $html );
		frontman_runtime_assert( [] !== $observed, 'Inspect all global, duplicate, bot-specific and header directives.' );
		frontman_runtime_same( 'noindex' === $preference, false !== strpos( wp_json_encode( $observed ), 'noindex' ), 'Rendered robots independent of stored preference.' );
		frontman_runtime_same( 'Explicit indexing social', $html['og_title'], 'Explicit social output remains.' );
		frontman_runtime_assert( false !== strpos( $html['body'], esc_url( get_permalink( $id ) ) ), 'Explicit self-canonical remains.' );
		$sitemap = frontman_runtime_http( 'GET', '/index.php?sitemap=page', '', null, null, 'render' );
		frontman_runtime_same( 200, $sitemap['status'], 'Observe the real page sitemap separately.' );
		frontman_runtime_assert( false !== strpos( $sitemap['body'], '<urlset' ), 'The sitemap response must be XML, not a successful HTML fallback.' );
		preg_match_all( '~<loc>(.*?)</loc>~s', $sitemap['body'], $locations );
		$included = in_array( get_permalink( $id ), array_map( static fn( $url ) => html_entity_decode( $url, ENT_QUOTES | ENT_XML1, 'UTF-8' ), $locations[1] ), true );
		frontman_runtime_same( 'noindex' !== $preference, $included, 'Observe sitemap inclusion and noindex exclusion independently.' );
		fwrite( STDOUT, 'Indexing sitemap observation: ' . wp_json_encode( [ 'preference' => $preference, 'included' => $included ] ) . "\n" );
		frontman_runtime_same( $safe, $protected(), 'Indexing preserves source, sibling, unrelated metadata, canonical/social and policy options.' );
	}
	$call( [ 'id' => $id, 'indexing' => 'noindex', 'description' => 'Mixed indexing description' ] );
	$text = $call( [ 'id' => $id, 'title' => 'Omitted indexing' ] );
	frontman_runtime_same( 'noindex', $text['after']['indexing'], 'Text-only preserves indexing.' );
	frontman_runtime_same( false, array_key_exists( 'indexable_refreshed', $text ), 'Text-only refresh contract is unchanged.' );
	foreach ( [ null, false, true, 0, 1, 1.5, '', 'INDEX', 'unknown', [], (object) [] ] as $invalid ) {
		$input = [ 'id' => $id, 'title' => 'Must not save', 'indexing' => $invalid ];
		$call( $input, true );
		foreach ( [ static fn() => $handler->update_seo( $input ), static fn() => $tools->sanitize_input( 'wp_update_seo', $input ) ] as $invoke ) {
			try { $invoke(); throw new RuntimeException( 'Malformed enum accepted.' ); } catch ( Frontman_Tool_Error $error ) {}
		}
	}
	$call( [ 'id' => $id, 'indexing' => 'index', 'robots' => 'follow' ], true );
	try { $handler->update_seo( [ 'id' => $id, 'indexing' => 'index', 'robots' => 'follow' ] ); throw new RuntimeException( 'Unknown field accepted.' ); } catch ( Frontman_Tool_Error $error ) {}
	frontman_runtime_same( $text['after'], array_diff_key( $call( [ 'id' => $id ], false, '', 'wp_read_seo' ), [ 'id' => true, 'provider' => true ] ), 'Malformed mixed requests do not write.' );
	$request = [ 'name' => 'wp_update_seo', 'arguments' => [ 'id' => $id, 'indexing' => 'index' ] ];
	foreach ( [ [ '', null, 401 ], [ $subscriber_cookie, null, 403 ], [ $cookie, null, 403 ], [ $cookie, 'invalid', 403 ] ] as [ $auth, $token, $status ] ) {
		frontman_runtime_same( $status, frontman_runtime_tool( $auth, $token, $request )['status'], 'Indexing retains auth/admin/nonce guards.' );
	}
	foreach ( [ 'deny-object', 'deny-meta', 'deny-indexing', 'deny-advanced', 'missing-indexing-sanitizer', 'fail-indexing-sanitizer', 'fail-indexing-preflight' ] as $fault ) {
		$call( [ 'id' => $id, 'title' => 'Must not save', 'indexing' => 'index' ], true, $fault );
		frontman_runtime_same( $text['after'], array_diff_key( $call( [ 'id' => $id ], false, '', 'wp_read_seo' ), [ 'id' => true, 'provider' => true ] ), "$fault rejects before text mutation." );
	}
	$sql_before = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->postmeta} WHERE post_id = %d ORDER BY meta_id", $id ), ARRAY_A );
	$sql_error = $call( [ 'id' => $id, 'title' => 'Must not save', 'indexing' => 'index' ], true, 'fail-indexing-select' );
	frontman_runtime_same( 'Yoast could not prepare indexing sanitization or refresh. No writes were attempted.', $sql_error, 'Nonthrowing SQL failure must reject in preflight without database details.' );
	frontman_runtime_same( $sql_before, $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->postmeta} WHERE post_id = %d ORDER BY meta_id", $id ), ARRAY_A ), 'A failed derived SELECT cannot save mixed authored metadata.' );
	frontman_runtime_same( $text['after'], array_diff_key( $call( [ 'id' => $id ], false, '', 'wp_read_seo' ), [ 'id' => true, 'provider' => true ] ), 'SQL preflight rejection preserves stored preferences.' );
	$persisted()->delete();
	frontman_runtime_same( false, $persisted(), 'Begin empty-query recovery without a persisted indexable.' );
	$empty_recovery = $call( [ 'id' => $id, 'indexing' => 'noindex' ], false, 'stale-indexing-error' );
	frontman_runtime_same( [ false, true, true ], [ $empty_recovery['changed'], $empty_recovery['indexable_refreshed'], $persisted()->is_robots_noindex ], 'A successful empty SELECT clears prior native SQL errors and permits same-value recovery.' );
	frontman_runtime_same( $text['after'], $call( [ 'id' => $id, 'indexing' => 'noindex' ], false, 'open-advanced' )['after'], 'Obey native permission policy when advanced metadata is open to editors.' );
	$call( [ 'id' => $id ], true, 'deny-indexing', 'wp_read_seo' );
	$reset = $call( [ 'id' => $id, 'title' => '', 'description' => '' ] );
	frontman_runtime_same( [ 'title' => '', 'description' => '', 'focus_keyphrase' => '', 'indexing' => 'noindex' ], $reset['after'], 'Empty text resets preserve omitted indexing.' );
	$text = $call( [ 'id' => $id, 'title' => 'Omitted indexing' ] );
	foreach ( [ PHP_INT_MAX, wp_insert_post( [ 'post_type' => 'attachment' ] ), wp_insert_post( [ 'post_type' => 'revision', 'post_parent' => $id ] ) ] as $ineligible ) {
		$call( [ 'id' => $ineligible, 'indexing' => 'index' ], true );
		if ( PHP_INT_MAX !== $ineligible ) { wp_delete_post( $ineligible, true ); }
	}
	/** The native sanitizer and permission APIs exist on 19.9; should_index_indexable does not. */
	$hook = 'sanitize_post_meta__yoast_wpseo_meta-robots-noindex';
	$callback = [ 'WPSEO_Meta', 'sanitize_post_meta' ];
	$priority = has_filter( $hook, $callback );
	remove_filter( $hook, $callback, $priority );
	try {
		$registry = new Frontman_Tools(); $handler->register( $registry );
		frontman_runtime_same( false, isset( $registry->get( 'wp_update_seo' )->input_schema['properties']['indexing'] ), 'Missing indexing sanitizer preserves text tools, without advertising indexing writes.' );
		try { $handler->update_seo( [ 'id' => $id, 'title' => 'Must not save', 'indexing' => 'index' ] ); throw new RuntimeException( 'Missing sanitizer accepted.' ); } catch ( Frontman_Tool_Error $error ) {}
		clean_post_cache( $id );
		$text_result = frontman_runtime_call( $registry, 'wp_update_seo', [ 'id' => $id, 'description' => 'Text still supported' ] );
		frontman_runtime_assert( ! $text_result['isError'], 'Indexing dependency absence must not disable text writes: ' . wp_json_encode( $text_result ) );
		$text_saved = json_decode( $text_result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
		frontman_runtime_same( $text['after'], $text_saved['before'], 'Direct dispatch begins with fresh native state after the preceding HTTP writes.' );
		frontman_runtime_same( array_replace( $text['after'], [ 'description' => 'Text still supported' ] ), $text_saved['after'], 'Missing indexing sanitizer preserves text-only writes and omitted fields.' );
		$call( [ 'id' => $id, 'description' => 'HTTP text still supported' ], false, 'missing-indexing-sanitizer' );
	} finally { add_filter( $hook, $callback, $priority, 4 ); }
	foreach ( [ [ 'fail-indexing-write', 'index', 'failed' ], [ 'fail-indexing-delete', 'default', 'failed' ], [ 'fail-indexing-write', 'index', 'partial' ], [ 'read-indexing', 'index', 'uncertain' ], [ 'silent-indexing-refresh', 'index', 'partial' ], [ 'missing-indexing-refresh', 'index', 'partial' ] ] as [ $fault, $preference, $status ] ) {
		$call( [ 'id' => $id, 'indexing' => 'noindex' ] );
		$before = $call( [ 'id' => $id ], false, '', 'wp_read_seo' );
		$input = [ 'id' => $id, 'indexing' => $preference ] + ( 'partial' === $status && 'fail-indexing-write' === $fault ? [ 'title' => 'Partial indexing title' ] : [] );
		$message = $call( $input, true, $fault );
		$state = json_decode( substr( $message, strpos( $message, '{' ) ), true, 512, JSON_THROW_ON_ERROR );
		frontman_runtime_same( $status, $state['status'], "$fault reports observed save status." );
		frontman_runtime_same( array_diff_key( $before, [ 'id' => true, 'provider' => true ] ), $state['before'], 'Exact before snapshot.' );
		$read = $call( [ 'id' => $id ], false, '', 'wp_read_seo' );
		frontman_runtime_same( 'uncertain' === $status ? null : array_diff_key( $read, [ 'id' => true, 'provider' => true ] ), $state['actualAfter'], 'Fresh request independently observes saved state.' );
		frontman_runtime_same( $preference, $state['expectedAfter']['indexing'], 'Failure retains expected preference.' );
		if ( 'silent-indexing-refresh' === $fault ) {
			frontman_runtime_same( true, $persisted()->is_robots_noindex, 'Silent persistence failure leaves stale derived state.' );
			$recovered = $call( [ 'id' => $id, 'indexing' => $preference ] );
			frontman_runtime_same( [ false, true, false ], [ $recovered['changed'], $recovered['indexable_refreshed'], $persisted()->is_robots_noindex ], 'Approved same-value request repairs derived state.' );
		}
		if ( 'missing-indexing-refresh' === $fault ) {
			frontman_runtime_same( false, $persisted(), 'An absent persisted indexable cannot count as refreshed.' );
			$recovered = $call( [ 'id' => $id, 'indexing' => $preference ] );
			frontman_runtime_same( [ false, true, false ], [ $recovered['changed'], $recovered['indexable_refreshed'], $persisted()->is_robots_noindex ], 'Approved repeat repairs a missing indexable.' );
		}
	}
	frontman_runtime_same( false, $call( [ 'id' => $id, 'indexing' => 'noindex' ], false, 'no-indexing-persistence' )['indexable_refreshed'], 'Disabled native persistence is not verified.' );
	frontman_runtime_same( $safe, $protected(), 'Failure paths preserve source, sibling, unrelated metadata and options.' );
	foreach ( [ false, true ] as $type_noindex ) {
		WPSEO_Options::set( 'noindex-page', $type_noindex, 'wpseo_titles' );
		$call( [ 'id' => $id, 'indexing' => 'default' ] );
		frontman_runtime_same( $type_noindex, false !== strpos( wp_json_encode( $robots( $render( $id ) ) ), 'noindex' ), 'Default inherits native post-type policy in this owned fixture.' );
	}
	foreach ( array_slice( $ids, 2 ) as $restricted ) {
		$source_before = get_post( $restricted, ARRAY_A );
		$call( [ 'id' => $restricted, 'indexing' => 'index' ] );
		clean_post_cache( $restricted );
		frontman_runtime_same( $source_before, get_post( $restricted, ARRAY_A ), 'Restricted indexing cannot change authored content or publication status.' );
		$html = $render( $restricted );
		frontman_runtime_assert( 404 === $html['status'] && false === strpos( $html['body'], 'Indexing undisclosed body' ), 'Draft/private indexing does not disclose or publish content.' );
	}
	$call( [ 'id' => $id, 'indexing' => 'index' ] );
	$broader = $robots( $render( $id, 'broader-noindex' ) );
	frontman_runtime_assert( false !== strpos( wp_json_encode( $broader ), 'noindex' ), 'Stored index is not a guarantee against broader rendered directives.' );
	frontman_runtime_same( 3, count( array_filter( $broader, static fn( $tag ) => 'robots' === $tag[0] ) ), 'Preserve duplicate global robots tags.' );
	frontman_runtime_assert( in_array( [ 'googlebot', [ 'noindex' ] ], $broader, true ) && in_array( [ 'header', 'x-robots-tag: bingbot: noindex' ], $broader, true ), 'Inspect bot-specific tags and X-Robots-Tag independently.' );
	WPSEO_Meta::delete( 'meta-robots-noindex', $id );
	foreach ( [ 'corrupt', serialize( [ 'invalid' ] ) ] as $corrupt ) {
		$wpdb->insert( $wpdb->postmeta, [ 'post_id' => $id, 'meta_key' => '_yoast_wpseo_meta-robots-noindex', 'meta_value' => $corrupt ] );
		wp_cache_delete( $id, 'post_meta' );
		$call( [ 'id' => $id ], true, '', 'wp_read_seo' );
		$call( [ 'id' => $id, 'indexing' => 'default', 'title' => 'Must not save' ], true );
		WPSEO_Meta::delete( 'meta-robots-noindex', $id );
	}
	fwrite( STDOUT, 'Broader robots observation: ' . wp_json_encode( $broader ) . "\n" );
	fwrite( STDOUT, "Yoast indexing stored, persisted, rendered, fault and sitemap cases passed.\n" );
} finally {
	wp_cache_delete( 'wpseo_titles', 'options' ); wp_cache_delete( 'alloptions', 'options' );
	update_option( 'wpseo_titles', $titles );
	foreach ( $ids as $id ) { wp_delete_post( $id, true ); }
	wp_set_current_user( 0 );
}
