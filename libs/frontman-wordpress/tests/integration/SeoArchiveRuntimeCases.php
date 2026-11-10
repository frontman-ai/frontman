<?php

declare(strict_types=1);

global $wpdb;
$originals = [ 'wpseo_titles' => get_option( 'wpseo_titles' ), 'wpseo_taxonomy_meta' => get_option( 'wpseo_taxonomy_meta' ) ];
$terms = [];
$created_posts = [];
$storage = static function () use ( $wpdb ): array {
	$values = [];
	foreach ( [ 'wpseo_titles', 'wpseo_taxonomy_meta' ] as $name ) {
		$values[$name] = maybe_unserialize( $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $name ) ) );
		frontman_runtime_assert( is_array( $values[$name] ), "Read persisted $name." );
		ksort( $values[$name] );
	}
	return $values;
};
$tags = static function ( string $url ): array {
	$html = frontman_runtime_http( 'GET', str_replace( home_url(), '', $url ), '', null, null, 'render' );
	return array_intersect_key( $html, array_flip( [ 'status', 'title', 'description' ] ) );
};
try {
	foreach ( [ 'category', 'frontman_seo_topic' ] as $taxonomy ) {
		$term = wp_insert_term( 'Runtime ' . $taxonomy, $taxonomy, [ 'slug' => 'shared-seo' ] );
		frontman_runtime_assert( ! is_wp_error( $term ), "Create $taxonomy term." );
		$terms[$taxonomy] = $term['term_id'];
	}
	$term = [ 'taxonomy' => 'frontman_seo_topic', 'term_id' => $terms['frontman_seo_topic'] ];
	if ( ! get_post( $term['term_id'] ) ) {
		$id = wp_insert_post( [ 'import_id' => $term['term_id'], 'post_title' => 'Same-ID post' ], true );
		frontman_runtime_same( $term['term_id'], $id, 'Create the post/term ID collision.' );
		$created_posts[] = $id;
	}
	$item = wp_insert_post( [ 'post_type' => 'frontman_seo_item', 'post_status' => 'publish', 'post_title' => 'Archive item' ], true );
	frontman_runtime_assert( is_int( $item ), 'Create the public CPT item.' );
	$created_posts[] = $item;
	wp_set_object_terms( $item, [ $term['term_id'] ], $term['taxonomy'] );
	WPSEO_Taxonomy_Meta::set_values( $term['term_id'], $term['taxonomy'], [
		'wpseo_canonical' => 'https://example.test/canonical', 'wpseo_opengraph-title' => 'Keep social title', 'wpseo_focuskw' => 'Keep focus',
	] );
	WPSEO_Taxonomy_Meta::set_values( $terms['category'], 'category', [ 'wpseo_title' => 'Other taxonomy' ] );
	update_option( 'wpseo_titles', get_option( 'wpseo_titles' ) );
	$protected = static function () use ( $storage, $term, $item, $wpdb ): array {
		$values = $storage();
		unset( $values['wpseo_taxonomy_meta'][$term['taxonomy']][$term['term_id']]['wpseo_title'], $values['wpseo_taxonomy_meta'][$term['taxonomy']][$term['term_id']]['wpseo_desc'] );
		unset( $values['wpseo_titles']['title-ptarchive-frontman_seo_item'], $values['wpseo_titles']['metadesc-ptarchive-frontman_seo_item'] );
		$values['posts'] = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->posts} WHERE ID IN (%d, %d) ORDER BY ID", $term['term_id'], $item ), ARRAY_A );
		$values['postmeta'] = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->postmeta} WHERE post_id IN (%d, %d) ORDER BY meta_id", $term['term_id'], $item ), ARRAY_A );
		return $values;
	};
	$unchanged = $protected();
	$targets = [ 'term' => $term, 'post_type_archive' => [ 'post_type' => 'frontman_seo_item' ] ];

	foreach ( $targets as $kind => $target ) {
		$read = $call( "wp_read_{$kind}_seo", $target );
		$initial = array_intersect_key( $read, array_flip( [ 'title', 'description' ] ) );
		$default_tags = $tags( $read['url'] );
		frontman_runtime_same( 200, $default_tags['status'], "$kind archive is public." );
		$patch = [ 'title' => 'SEO %%sitename%%', 'description' => 'Café “quoted” \\ path' ];
		$saved = $call( "wp_update_{$kind}_seo", $target + $patch );
		frontman_runtime_same( $initial, $saved['before'], "$kind before snapshot." );
		frontman_runtime_same( $patch, $saved['after'], "$kind persisted template and UTF-8 text." );
		frontman_runtime_same( [ 'status' => 200, 'title' => 'SEO ' . get_bloginfo( 'name' ), 'description' => 'Café “quoted”  path' ], $tags( $read['url'] ), "$kind renders Yoast-normalized public metadata without changing stored bytes." );
		$patch['description'] = 'Description only';
		$saved = $call( "wp_update_{$kind}_seo", $target + [ 'description' => $patch['description'] ] );
		frontman_runtime_same( $patch, $saved['after'], "$kind preserves the omitted nonempty title." );
		frontman_runtime_same( false, $call( "wp_update_{$kind}_seo", $target + $patch )['changed'], "$kind repeat is unchanged." );
		$reset = $call( "wp_update_{$kind}_seo", $target + [ 'title' => '', 'description' => '' ] );
		frontman_runtime_same( $initial, $reset['after'], "$kind restores provider defaults, not necessarily empty templates." );
		frontman_runtime_same( $default_tags, $tags( $read['url'] ), "$kind reset restores public metadata." );
	}
	$category = $call( 'wp_read_term_seo', [ 'taxonomy' => 'category', 'slug' => 'shared-seo' ] );
	$topic = $call( 'wp_read_term_seo', [ 'taxonomy' => $term['taxonomy'], 'slug' => 'shared-seo' ] );
	frontman_runtime_same( [ $terms['category'], $term['term_id'] ], [ $category['term_id'], $topic['term_id'] ], 'Identical slugs resolve within their taxonomy.' );
	frontman_runtime_same( $unchanged, $protected(), 'Updates preserve other terms, all unrelated Yoast settings, and same-ID/CPT posts.' );

	foreach ( [
		[ 'term', 'deny-term-save', 'failed' ],
		[ 'post_type_archive', 'partial-archive-save', 'partial' ],
		[ 'term', 'silent-archive-refresh', 'partial' ],
		[ 'post_type_archive', 'silent-archive-refresh', 'partial' ],
	] as [ $kind, $fault, $status ] ) {
		$target = $targets[$kind];
		$read = $call( "wp_read_{$kind}_seo", $target );
		$before = array_intersect_key( $read, array_flip( [ 'title', 'description' ] ) );
		$patch = [ 'title' => 'Changed title', 'description' => 'Changed description' ];
		$actual = 'failed' === $status ? $before : ( 'partial-archive-save' === $fault ? array_replace( $before, [ 'title' => $patch['title'] ] ) : $patch );
		$warm = $tags( $read['url'] );
		$message = $call( "wp_update_{$kind}_seo", $target + $patch, true, $fault );
		$state = json_decode( substr( $message, strpos( $message, '{' ) ), true, 512, JSON_THROW_ON_ERROR );
		frontman_runtime_same( $target + [ 'url' => $read['url'], 'provider' => 'yoast', 'status' => $status, 'before' => $before, 'expectedAfter' => $patch, 'actualAfter' => $actual ], $state, "$fault reports exact save state." );
		$readback = $call( "wp_read_{$kind}_seo", $target );
		frontman_runtime_same( $actual, array_intersect_key( $readback, $patch ), "$fault agrees with a fresh request." );
		if ( 'silent-archive-refresh' === $fault ) {
			frontman_runtime_same( $warm, $tags( $read['url'] ), "$kind silent refresh leaves stale public output." );
			$recovered = $call( "wp_update_{$kind}_seo", $target + $patch );
			frontman_runtime_same( [ false, true ], [ $recovered['changed'], $recovered['indexable_refreshed'] ], "$kind same-value recovery refreshes the stale indexable." );
			frontman_runtime_same( [ 'status' => 200 ] + $patch, $tags( $read['url'] ), "$kind recovery reaches public metadata." );
		}
	}
	frontman_runtime_same( false, $call( 'wp_update_term_seo', $term + $patch, false, 'no-archive-persistence' )['indexable_refreshed'], 'Disabled Yoast persistence is not reported as refreshed.' );
	frontman_runtime_same( $unchanged, $protected(), 'Failure paths preserve unrelated persisted data.' );

	$before_rejection = $storage();
	foreach ( [
		[ 'wp_read_term_seo', $term + [ 'slug' => 'shared-seo' ], 'Supply one', '' ],
		[ 'wp_read_term_seo', [ 'taxonomy' => 'category', 'term_id' => $term['term_id'] ], 'Term must exist', '' ],
		[ 'wp_update_term_seo', array_replace( $term, [ 'term_id' => (string) $term['term_id'], 'title' => 'Bad' ] ), 'term_id', '' ],
		[ 'wp_update_term_seo', $term, 'Provide title or description', '' ],
		[ 'wp_update_post_type_archive_seo', $targets['post_type_archive'] + [ 'focus_keyphrase' => 'Bad' ], 'focus_keyphrase', '' ],
		[ 'wp_read_post_type_archive_seo', [ 'post_type' => 'post' ], 'Post type must have', '' ],
		[ 'wp_read_post_type_archive_seo', [ 'post_type' => 'fm_seo_no_archive' ], 'Post type must have', '' ],
		[ 'wp_read_term_seo', $term, 'You cannot edit this term SEO metadata.', 'deny-term' ],
		[ 'wp_update_post_type_archive_seo', $targets['post_type_archive'] + $patch, 'Yoast settings permission is required.', 'deny-yoast-options' ],
	] as [ $name, $arguments, $reason, $fault ] ) {
		$message = $call( $name, $arguments, true, $fault );
		frontman_runtime_assert( false !== strpos( $message, $reason ), "$name must reject for $reason, got: $message" );
	}
	$raw = '{"name":"wp_update_term_seo","arguments":{"taxonomy":"' . $term['taxonomy'] . '","term_id":' . $term['term_id'] . ',"description":"bad' . "\xC3\x28" . '"}}';
	frontman_runtime_same( true, frontman_runtime_tool( $cookie, $nonce, [], $raw )['body']['isError'], 'Malformed UTF-8 is rejected without repair.' );
	$actor = get_current_user_id();
	wp_set_current_user( 0 );
	try {
		foreach ( $targets as $kind => $target ) {
			$result = frontman_runtime_call( Frontman_Tools::instance(), "wp_update_{$kind}_seo", $target + $patch );
			frontman_runtime_same( Frontman_Tools::error_result( 'Archive SEO requires administrator access on the current site.' ), $result, "$kind direct calls enforce administrator access." );
		}
	} finally {
		wp_set_current_user( $actor );
	}
	frontman_runtime_same( $before_rejection, $storage(), 'Rejected inputs and permission denials do not save any Yoast settings.' );

	foreach ( [ 'term' => 'wpseo_taxonomy_meta', 'post_type_archive' => 'wpseo_titles' ] as $kind => $name ) {
		$option = WPSEO_Options::get_option_instance( $name );
		$hook = 'sanitize_option_' . $name;
		$priority = has_filter( $hook, [ $option, 'validate' ] );
		remove_filter( $hook, [ $option, 'validate' ], $priority );
		try {
			$registry = new Frontman_Tools();
			( new Frontman_Tool_Seo() )->register( $registry );
			$capability = Frontman_Tool_Seo::capabilities()['targets'][$kind];
			frontman_runtime_same( [ true, false, true, false ], [ $capability['read'], $capability['write'], null !== $registry->get( "wp_read_{$kind}_seo" ), null !== $registry->get( "wp_update_{$kind}_seo" ) ], "$kind sanitizer removal disables only its writer." );
			$other = 'term' === $kind ? 'post_type_archive' : 'term';
			frontman_runtime_same( true, Frontman_Tool_Seo::capabilities()['targets'][$other]['write'], "$kind sanitizer removal preserves the other writer." );
		} finally {
			add_filter( $hook, [ $option, 'validate' ], $priority );
		}
	}
} finally {
	foreach ( $terms as $taxonomy => $id ) { wp_delete_term( $id, $taxonomy ); }
	foreach ( $created_posts as $id ) { wp_delete_post( $id, true ); }
	foreach ( $originals as $name => $value ) {
		wp_cache_delete( $name, 'options' );
		wp_cache_delete( 'alloptions', 'options' );
		update_option( $name, $value );
	}
}
