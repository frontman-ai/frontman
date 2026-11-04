<?php

$script = '<script src="https://example.test/embed.js" defer data-region="eu1"></script>';
$content = '<!-- wp:html -->' . $script . '<div>Été 日本語 \\path\\file "quoted"</div><!-- /wp:html -->';
$page = [ 'title' => 'Embedded form', 'content' => $content, 'post_type' => 'page', 'status' => 'publish' ];
$created = $call( 'wp_create_post', $page );
$id = $created['id'];
frontman_runtime_same( $content, $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Create preserves embed bytes' );
$rendered = frontman_runtime_http( 'GET', wp_make_link_relative( $created['permalink'] ) );
frontman_runtime_same( 200, $rendered['status'], 'Published embed renders' );
frontman_runtime_assert( false !== strpos( $rendered['body'], $script ), 'Rendered page retains the script and its attributes' );

$updated = $call( 'wp_update_post', [ 'id' => $id, 'content' => $content . '<p>Updated</p>' ] );
frontman_runtime_same( $content, $updated['before']['content'], 'Update captures the original embed' );
$content .= '<p>Updated</p>';
frontman_runtime_same( $content, $updated['after']['content'], 'Update preserves embed bytes' );
$renamed = $call( 'wp_update_post', [ 'id' => $id, 'title' => 'Renamed form' ] );
frontman_runtime_same( $content, $renamed['after']['content'], 'Omitted content preserves the embed' );

$reject( 'wp_create_post', [ 'title' => 'Missing content' ], 'content is a required property' );
foreach ( [ null, false, 123, [] ] as $invalid ) {
	$reject( 'wp_create_post', [ 'title' => 'Invalid content', 'content' => $invalid ], 'content' );
	$reject( 'wp_update_post', [ 'id' => $id, 'title' => 'Must not save', 'content' => $invalid ], 'content' );
}
$actor->add_cap( 'unfiltered_html', false );
try {
	$reject( 'wp_create_post', $page, 'unfiltered_html' );
	$reject( 'wp_update_post', [ 'id' => $id, 'content' => $content ], 'unfiltered_html' );
	$reject( 'wp_update_post', [ 'id' => $id, 'title' => 'Must not save' ], 'unfiltered_html' );
	$safe = $call( 'wp_create_post', [ 'title' => 'Safe page', 'content' => '<p>Safe</p>' ] );
	$renamed = $call( 'wp_update_post', [ 'id' => $safe['id'], 'title' => 'Safe rename' ] );
	frontman_runtime_same( '<p>Safe</p>', $renamed['after']['content'], 'Restricted users can save and rename safe content' );
} finally {
	$actor->remove_cap( 'unfiltered_html' );
}

foreach ( [ 'wp_create_post' => $page, 'wp_update_post' => [ 'id' => $id, 'content' => $content ] ] as $name => $input ) {
	$message = $call( $name, $input, true, 'transform-content' );
	$stored = $call( 'wp_read_post', [ 'id' => frontman_runtime_saved_id( $message ) ] );
	frontman_runtime_same( $input['content'] . '<p>Plugin transformation</p>', $stored['content'], 'Transformed saves report failure without undoing native filters' );
}
$anchor = '<main id="content">';
$navigation = "<nav>\n\t<a href=\"/products/\">Produits 日本語</a>\n</nav>\n";
$body = "\n  " . $script . "\n" . $anchor . "Été 日本語 \\path\\file \"quoted\"\n</main>\n";
foreach ( [ $body, "<!-- wp:html -->\n" . $body . "<!-- /wp:html -->\n" ] as $original ) {
	$draft = $call( 'wp_create_post', [
		'title' => 'Draft navigation', 'content' => $original,
		'post_type' => 'page', 'status' => 'draft',
	] );
	$id = $draft['id'];
	$call( 'wp_update_post', [ 'id' => $id, 'excerpt' => 'Keep excerpt' ] );
	update_post_meta( $id, 'fragment-test-meta', 'Keep metadata' );
	$before = $call( 'wp_read_post', [ 'id' => $id ] );
	frontman_runtime_same( hash( 'sha256', $original ), $before['content_sha256'], 'Read hash covers exact stored bytes' );
	$edit = [
		'id' => $id, 'mode' => 'edit', 'oldText' => $anchor,
		'newText' => $navigation . $anchor, 'expected_current_sha256' => $before['content_sha256'],
	];
	$result = $call( 'wp_update_post', $edit );
	$expected = str_replace( $anchor, $navigation . $anchor, $original );
	frontman_runtime_same( $original, $result['before']['content'], 'Edit captures original bytes' );
	frontman_runtime_same( $expected, $result['after']['content'], 'Navigation insertion preserves the entire string' );
	frontman_runtime_same( hash( 'sha256', $expected ), $result['after']['content_sha256'], 'Edit readback hashes persisted bytes' );
	foreach ( [ 'title', 'status', 'author', 'excerpt', 'slug', 'template', 'categories', 'tags' ] as $field ) {
		frontman_runtime_same( $before[ $field ], $result['after'][ $field ], 'Edit preserves omitted ' . $field );
	}
	frontman_runtime_same( 'Keep metadata', get_post_meta( $id, 'fragment-test-meta', true ), 'Edit retains custom metadata' );
	$reject( 'wp_update_post', $edit + [ 'title' => 'Must not save', 'status' => 'publish' ], 'Stale content hash' );

	$fresh = $result['after']['content_sha256'];
	$call( 'wp_update_post', [ 'id' => $id, 'content' => $expected . "\nElsewhere" ] );
	$edit['expected_current_sha256'] = $fresh;
	$reject( 'wp_update_post', $edit, 'Stale content hash' );
	$current = $call( 'wp_read_post', [ 'id' => $id ] );
	$edit['expected_current_sha256'] = $current['content_sha256'];
	$edit['title'] = 'Must not save';
	$edit['status'] = 'publish';
	$invalid_inputs = [
		[ [ 'mode' => 'unknown' ], 'mode' ],
		[ [ 'mode' => null ], 'mode' ],
		[ [ 'mode' => ' edit ' ], 'mode' ],
		[ [ 'mode' => 'replace' ], 'only allowed in edit mode' ],
		[ [ 'content' => null ], 'content' ],
		[ [ 'content' => $expected ], 'content is not allowed' ],
		[ [ 'oldText' => '' ], 'nonempty' ],
		[ [ 'newText' => $anchor ], 'different' ],
		[ [ 'oldText' => 'absent anchor' ], 'exactly once' ],
		[ [ 'oldText' => "\n" ], 'exactly once' ],
		[ [ 'expected_current_sha256' => strtoupper( $current['content_sha256'] ) ], 'expected_current_sha256' ],
		[ [ 'expected_current_sha256' => str_repeat( 'a', 63 ) ], 'expected_current_sha256' ],
		[ [ 'expected_current_sha256' => str_repeat( 'g', 64 ) ], 'expected_current_sha256' ],
	];
	foreach ( [ 'mode', 'oldText', 'newText', 'expected_current_sha256' ] as $field ) {
		foreach ( [ null, false, 123, [], (object) [ 'value' => 'invalid' ] ] as $invalid ) {
			$invalid_inputs[] = [ [ $field => $invalid ], $field ];
		}
	}
	foreach ( $invalid_inputs as [ $overrides, $reason ] ) {
		$reject( 'wp_update_post', array_replace( $edit, $overrides ), $reason );
	}
	foreach ( [ 'mode', 'oldText', 'newText', 'expected_current_sha256' ] as $field ) {
		$missing = $edit;
		unset( $missing[ $field ] );
		$reject( 'wp_update_post', $missing, 'mode' === $field ? 'only allowed in edit mode' : 'is required' );
	}
	foreach ( [ 'oldText', 'newText', 'expected_current_sha256' ] as $field ) {
		$reject( 'wp_update_post', [ 'id' => $id, $field => 'expected_current_sha256' === $field ? str_repeat( 'a', 64 ) : 'invalid' ], 'only allowed in edit mode' );
	}
	$actor->add_cap( 'unfiltered_html', false );
	try {
		$reject( 'wp_update_post', $edit, 'unfiltered_html' );
	} finally {
		$actor->remove_cap( 'unfiltered_html' );
	}
	update_post_meta( $id, '_elementor_edit_mode', 'builder' );
	$reject( 'wp_update_post', $edit, 'Elementor-managed', 'elementor-content-guard' );
	delete_post_meta( $id, '_elementor_edit_mode' );
	$message = $call( 'wp_update_post', $edit, true, 'transform-content' );
	$stored = $call( 'wp_read_post', [ 'id' => frontman_runtime_saved_id( $message ) ] );
	frontman_runtime_same(
		str_replace( $anchor, $navigation . $anchor, $current['content'] ) . '<p>Plugin transformation</p>',
		$stored['content'],
		'Edit reports native save-filter partial writes without rollback'
	);
}
$plain = $call( 'wp_create_post', [ 'title' => 'Overlapping anchors', 'content' => 'aaa' ] );
$edit = [
	'id' => $plain['id'], 'mode' => 'edit', 'oldText' => 'aa', 'newText' => '',
	'expected_current_sha256' => $plain['after']['content_sha256'],
];
$reject( 'wp_update_post', $edit, 'exactly once' );
$edit['oldText'] = 'aaa';
$deleted = $call( 'wp_update_post', $edit );
frontman_runtime_same( '', $deleted['after']['content'], 'Empty newText deletes the unique fragment' );

$original = '<p>Été 日本語</p><p>Old \\path</p>';
$multi = $call( 'wp_create_post', [ 'title' => 'Multiple exact edits', 'content' => $original, 'post_type' => 'page', 'status' => 'publish' ] );
$id = $multi['id'];
$edits = [
	[ 'oldText' => 'Été 日本語', 'newText' => 'Hiver 日本語' ],
	[ 'newText' => 'New \\path', 'oldText' => 'Old \\path' ],
];
$expected = '<p>Hiver 日本語</p><p>New \\path</p>';
$request = [ 'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => $multi['after']['content_sha256'], 'edits' => $edits ];
global $wpdb;
try {
	$preview = $call( 'wp_update_post', $request + [ 'dryRun' => true ], false, 'count-post-saves' );
	frontman_runtime_same( true, $preview['dry_run'], 'Multiple-edit dry run is labeled as proposed' );
	frontman_runtime_same( 2, $preview['edit_count'], 'Dry run counts the requested edits' );
	frontman_runtime_same( [ 0 => 3, 1 => strpos( $original, 'Old \\path' ) ], $preview['match_offsets'], 'Dry run reports original byte offsets by edit index' );
	frontman_runtime_same( hash( 'sha256', $expected ), $preview['proposed_sha256'], 'Dry run hashes proposed bytes' );
	frontman_runtime_same( null, $wpdb->get_var( "SELECT option_value FROM {$wpdb->options} WHERE option_name = 'frontman_multi_edit_save_count'" ), 'Dry run does not invoke post save hooks' );
	frontman_runtime_same( $original, $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Dry run does not change post content' );
	frontman_runtime_assert( ! isset( $preview['before'] ) && ! isset( $preview['after'] ) && ! isset( $preview['content'] ), 'Dry run must not echo the page' );
	$reversed = $call( 'wp_update_post', array_replace( $request, [ 'edits' => array_reverse( $edits ), 'dryRun' => true ] ) );
	frontman_runtime_same( [ strpos( $original, 'Old \\path' ), 3 ], $reversed['match_offsets'], 'Out-of-order edits return an indexed JSON array in input order' );
	frontman_runtime_same( $preview['proposed_sha256'], $reversed['proposed_sha256'], 'Edit order does not change the proposed content' );

	$saved = $call( 'wp_update_post', $request, false, 'count-post-saves' );
	frontman_runtime_same( '1', $wpdb->get_var( "SELECT option_value FROM {$wpdb->options} WHERE option_name = 'frontman_multi_edit_save_count'" ), 'Multiple edits save the post once' );
	frontman_runtime_same( false, $saved['dry_run'], 'Multiple-edit receipt reports a saved change' );
	frontman_runtime_same( 2, $saved['edit_count'], 'Receipt counts saved edits' );
	frontman_runtime_same( $request['expected_current_sha256'], $saved['before_sha256'], 'Receipt identifies original content' );
	frontman_runtime_same( hash( 'sha256', $expected ), $saved['after_sha256'], 'Receipt hashes persisted content' );
	frontman_runtime_assert( ! isset( $saved['before'] ) && ! isset( $saved['after'] ) && ! isset( $saved['content'] ), 'Saved receipt must not echo the page' );
	frontman_runtime_same( $expected, $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Readback confirms both exact edits' );
	$reject( 'wp_update_post', $request, 'Stale content hash' );
	$reject( 'wp_update_post', $request + [ 'dryRun' => 'true' ], 'dryRun' );
	$reject( 'wp_update_post', $request + [ 'title' => 'Must not change' ], 'not allowed in edit_many' );
	$reject( 'wp_update_post', [ 'id' => $id, 'mode' => 'edit', 'edits' => $edits ], 'only allowed in edit_many' );
	$reject( 'wp_update_post', [ 'id' => $id, 'edits' => $edits ], 'only allowed in edit_many' );

	$overlap = $call( 'wp_create_post', [ 'title' => 'Overlapping edits', 'content' => 'abc' ] );
	$overlap_request = [
		'id' => $overlap['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $overlap['after']['content_sha256'],
		'edits' => [ [ 'oldText' => 'ab', 'newText' => 'x' ], [ 'oldText' => 'bc', 'newText' => 'y' ] ],
	];
	$reject( 'wp_update_post', $overlap_request, 'must not overlap' );
	frontman_runtime_same( 'abc', $call( 'wp_read_post', [ 'id' => $overlap['id'] ] )['content'], 'Overlapping edits do not write' );
	$missing_edits = $overlap_request;
	unset( $missing_edits['edits'] );
	$reject( 'wp_update_post', $missing_edits, 'edits' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [] ] ), 'at least 1' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => (object) [ '0' => $overlap_request['edits'][0] ] ] ), 'edits' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => 'a' ] ] ] ), 'newText' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => false, 'newText' => 'x' ] ] ] ), 'oldText' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => 'missing', 'newText' => 'x' ] ] ] ), 'match exactly once' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => 'ab', 'newText' => 'ab' ] ] ] ), 'different newText' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => 'ab', 'newText' => 'x', 'unexpected' => 'y' ] ] ] ), 'not a valid property' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [
		[ 'oldText' => 'ab', 'newText' => 'x' ], [ 'oldText' => 'ab', 'newText' => 'y' ],
	] ] ), 'must not overlap' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => array_fill( 0, 51, [ 'oldText' => 'abc', 'newText' => 'x' ] ) ] ), 'at most 50' );
	$reject( 'wp_update_post', array_replace( $overlap_request, [ 'edits' => [ [ 'oldText' => 'a', 'newText' => 'x' ], [ 'oldText' => 'missing', 'newText' => 'y' ] ] ] ), 'match exactly once' );
	frontman_runtime_same( 'abc', $call( 'wp_read_post', [ 'id' => $overlap['id'] ] )['content'], 'A later invalid edit does not save an earlier valid edit' );
	$repeated = $call( 'wp_create_post', [ 'title' => 'Ambiguous edits', 'content' => 'same same' ] );
	$reject( 'wp_update_post', [
		'id' => $repeated['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $repeated['after']['content_sha256'],
		'edits' => [ [ 'oldText' => 'same', 'newText' => 'new' ] ],
	], 'match exactly once' );
	$adjacent = $call( 'wp_create_post', [ 'title' => 'Adjacent edits', 'content' => 'abc' ] );
	$adjacent_receipt = $call( 'wp_update_post', [
		'id' => $adjacent['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $adjacent['after']['content_sha256'],
		'edits' => [
			[ 'oldText' => 'a', 'newText' => 'b' ],
			[ 'oldText' => 'b', 'newText' => '' ],
			[ 'oldText' => 'c', 'newText' => 'd' ],
		],
	] );
	frontman_runtime_same( 3, $adjacent_receipt['edit_count'], 'Adjacent edits accept a deletion' );
	frontman_runtime_same( 'bd', $call( 'wp_read_post', [ 'id' => $adjacent['id'] ] )['content'], 'Each adjacent match uses original bytes, not prior replacements' );
	$many_edits = [];
	$many_parts = [];
	for ( $index = 0; $index < 50; ++$index ) {
		$part = sprintf( 'marker-%02d', $index );
		$many_parts[] = $part;
		$many_edits[] = [ 'oldText' => $part, 'newText' => sprintf( 'value-%02d', $index ) ];
	}
	$many = $call( 'wp_create_post', [ 'title' => 'Maximum edits', 'content' => implode( '|', $many_parts ) ] );
	$many_preview = $call( 'wp_update_post', [
		'id' => $many['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $many['after']['content_sha256'],
		'edits' => $many_edits, 'dryRun' => true,
	] );
	frontman_runtime_same( 50, $many_preview['edit_count'], 'Dry run accepts the documented maximum of 50 edits' );
	frontman_runtime_same( implode( '|', $many_parts ), $call( 'wp_read_post', [ 'id' => $many['id'] ] )['content'], 'Large dry run does not save' );

	$filtered = $call( 'wp_create_post', [ 'title' => 'Filtered edit', 'content' => '<p>First</p><p>Second</p>' ] );
	$filtered_request = [
		'id' => $filtered['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $filtered['after']['content_sha256'],
		'edits' => [ [ 'oldText' => 'First', 'newText' => 'One' ], [ 'oldText' => 'Second', 'newText' => 'Two' ] ],
	];
	$proposed = $call( 'wp_update_post', $filtered_request + [ 'dryRun' => true ], false, 'transform-content' );
	frontman_runtime_same( hash( 'sha256', '<p>One</p><p>Two</p>' ), $proposed['proposed_sha256'], 'Dry run does not apply save filters' );
	frontman_runtime_same( '<p>First</p><p>Second</p>', $call( 'wp_read_post', [ 'id' => $filtered['id'] ] )['content'], 'Dry run does not persist filtered content' );
	$partial = $call( 'wp_update_post', $filtered_request, true, 'transform-content' );
	frontman_runtime_assert( false !== strpos( $partial, 'content readback did not match' ), 'Filtered edits report partial writes without a success receipt' );
	frontman_runtime_same( '<p>One</p><p>Two</p><p>Plugin transformation</p>', $call( 'wp_read_post', [ 'id' => $filtered['id'] ] )['content'], 'Readback exposes the save-filter change' );
	$competing = $call( 'wp_create_post', [ 'title' => 'Concurrent change', 'content' => '<p>Before</p>' ] );
	$competing_request = [
		'id' => $competing['id'], 'mode' => 'edit_many', 'expected_current_sha256' => $competing['after']['content_sha256'],
		'edits' => [ [ 'oldText' => 'Before', 'newText' => 'After' ] ],
	];
	$call( 'wp_update_post', $competing_request + [ 'dryRun' => true ] );
	$call( 'wp_update_post', [ 'id' => $competing['id'], 'content' => '<p>Other writer</p>' ] );
	$reject( 'wp_update_post', $competing_request, 'Stale content hash' );
	$reject( 'wp_update_post', $competing_request + [ 'dryRun' => true ], 'Stale content hash' );
	frontman_runtime_same( '<p>Other writer</p>', $call( 'wp_read_post', [ 'id' => $competing['id'] ] )['content'], 'Stale edits preserve the competing write' );

	$actor->add_cap( 'edit_published_pages', false );
	try {
		$reject( 'wp_update_post', [ 'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => $saved['after_sha256'], 'edits' => [ [ 'oldText' => 'Hiver', 'newText' => 'Summer' ] ], 'dryRun' => true ], 'permission' );
	} finally {
		$actor->remove_cap( 'edit_published_pages' );
	}
	update_post_meta( $id, '_elementor_edit_mode', 'builder' );
	$reject( 'wp_update_post', [ 'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => $saved['after_sha256'], 'edits' => [ [ 'oldText' => 'Hiver', 'newText' => 'Summer' ] ], 'dryRun' => true ], 'Elementor-managed', 'elementor-content-guard' );
	delete_post_meta( $id, '_elementor_edit_mode' );
	$actor->add_cap( 'unfiltered_html', false );
	try {
		$unsafe = [
			'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => $saved['after_sha256'],
			'edits' => [ [ 'oldText' => 'Hiver', 'newText' => '<script>alert(1)</script>' ] ],
		];
		$reject( 'wp_update_post', $unsafe + [ 'dryRun' => true ], 'unfiltered_html' );
		$reject( 'wp_update_post', $unsafe, 'unfiltered_html' );
		frontman_runtime_same( $expected, $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Denied HTML does not change the post' );
		$safe = array_replace( $unsafe, [ 'edits' => [ [ 'oldText' => 'Hiver', 'newText' => 'Winter' ] ] ] );
		$call( 'wp_update_post', $safe );
		frontman_runtime_same( '<p>Winter 日本語</p><p>New \\path</p>', $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Permitted edits work without unfiltered_html' );
	} finally {
		$actor->remove_cap( 'unfiltered_html' );
	}
} finally {
	delete_option( 'frontman_multi_edit_save_count' );
}

$specialist_content = '<!-- wp:paragraph --><p>Specialist state</p><!-- /wp:paragraph -->';
foreach ( [
	'custom_css' => 'wp_update_custom_css',
	'wp_navigation' => 'wp_update_navigation_menu',
	'wp_template' => 'wp_update_template',
	'wp_template_part' => 'wp_update_template',
] as $type => $specialist ) {
	$id = wp_insert_post( [
		'post_type' => $type,
		'post_status' => 'publish',
		'post_name' => 'frontman-specialist-' . $type,
		'post_title' => 'Specialist fixture',
		'post_content' => $specialist_content,
	], true );
	frontman_runtime_assert( is_int( $id ), $type . ' fixture must exist' );
	frontman_runtime_assert( current_user_can( get_post_type_object( $type )->cap->create_posts ), $type . ' fixture must be creatable by the administrator' );
	frontman_runtime_same( 'custom_css' !== $type, current_user_can( 'edit_post', $id ), $type . ' editing capability differs from the generic route' );
	try {
		$create_tool = in_array( $type, [ 'wp_template', 'wp_template_part' ], true )
			? 'wp_create_template'
			: ( 'wp_navigation' === $type ? 'wp_create_navigation_menu' : 'wp_update_custom_css' );
		if ( in_array( $type, [ 'wp_template', 'wp_template_part' ], true ) ) {
			wp_set_post_terms( $id, [ get_stylesheet() ], 'wp_theme' );
		}
		frontman_runtime_same( $specialist_content, $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Raw post recovery still reads ' . $type );
		$reject( 'wp_create_post', [ 'post_type' => $type, 'title' => 'Blocked', 'content' => $specialist_content ], $create_tool );
		$reject( 'wp_duplicate_post', [ 'source_id' => $id ], $create_tool );
		if ( in_array( $type, [ 'wp_template', 'wp_template_part' ], true ) ) {
			$call( 'wp_update_post', [ 'id' => $id, 'title' => 'Recovered template by ID' ] );
			$call( 'wp_update_post', [
				'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => hash( 'sha256', $specialist_content ),
				'edits' => [ [ 'oldText' => 'Specialist state', 'newText' => 'Raw recovery' ] ],
			] );
			frontman_runtime_assert( false !== strpos( $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Raw recovery' ), 'Template post remains editable by ID' );
			$call( 'wp_update_block', [
				'post_id' => $id, 'index' => 0,
				'block_markup' => '<!-- wp:paragraph --><p>Block recovery</p><!-- /wp:paragraph -->',
			] );
			frontman_runtime_assert( false !== strpos( $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Block recovery' ), 'Template block remains editable by ID' );
			$reject( 'wp_delete_post', [ 'id' => $id, 'confirm' => true ], 'permanent' );
			$deleted_template = $call( 'wp_delete_post', [ 'id' => $id, 'confirm' => true, 'force' => true ] );
			frontman_runtime_same( false, $deleted_template['trashed'], 'Permanent template deletion is not reported as trash' );
			clean_post_cache( $id );
			frontman_runtime_same( null, get_post( $id ), 'Approved template deletion removes its post' );
		} else {
			$reject( 'wp_update_post', [ 'id' => $id, 'title' => 'Blocked' ], $specialist );
			$reject( 'wp_update_post', [
				'id' => $id, 'mode' => 'edit_many', 'expected_current_sha256' => hash( 'sha256', $specialist_content ),
				'edits' => [ [ 'oldText' => 'Specialist state', 'newText' => 'Blocked' ] ], 'dryRun' => true,
			], $specialist );
			$reject( 'wp_update_block', [
				'post_id' => $id, 'index' => 0,
				'block_markup' => '<!-- wp:paragraph --><p>Blocked</p><!-- /wp:paragraph -->',
			], $specialist );
			$reject( 'wp_delete_post', [ 'id' => $id, 'confirm' => true, 'force' => true ], current_user_can( 'delete_post', $id ) ? ( 'custom_css' === $type ? 'wp_update_custom_css' : 'wp_delete_navigation_menu' ) : 'permission' );
		}
	} finally {
		wp_delete_post( $id, true );
	}
}

$block_page = $call( 'wp_create_post', [ 'title' => 'Block permissions', 'post_type' => 'page', 'status' => 'publish', 'content' => $specialist_content ] );
$actor->add_cap( 'edit_published_pages', false );
try {
	$reject( 'wp_update_block', [
		'post_id' => $block_page['id'], 'index' => 0,
		'block_markup' => '<!-- wp:paragraph --><p>Blocked</p><!-- /wp:paragraph -->',
	], 'permission' );
} finally {
	$actor->remove_cap( 'edit_published_pages' );
}
frontman_runtime_same( $specialist_content, $call( 'wp_read_post', [ 'id' => $block_page['id'] ] )['content'], 'Denied block update preserves its post' );
$ordinary = $call( 'wp_create_post', [ 'title' => 'Ordinary deletion', 'content' => '<p>Keep until trash</p>' ] );
$trash = $call( 'wp_delete_post', [ 'id' => $ordinary['id'], 'confirm' => true ] );
frontman_runtime_same( true, $trash['trashed'], 'Ordinary posts report their observed trash state' );
frontman_runtime_same( 'trash', $call( 'wp_read_post', [ 'id' => $ordinary['id'] ] )['status'], 'Ordinary deletion moves the post to trash' );
$navigation = $call( 'wp_create_navigation_menu', [ 'title' => 'Protected navigation', 'content' => $specialist_content ] );
$actor->add_cap( 'edit_theme_options', false );
try {
	$reject( 'wp_create_navigation_menu', [ 'title' => 'Denied navigation', 'content' => $specialist_content ], 'edit_theme_options' );
	$reject( 'wp_update_navigation_menu', [ 'id' => $navigation['id'], 'title' => 'Denied navigation' ], 'permission' );
	$reject( 'wp_delete_navigation_menu', [ 'id' => $navigation['id'], 'confirm' => true ], 'permission' );
} finally {
	$actor->remove_cap( 'edit_theme_options' );
}
$call( 'wp_delete_navigation_menu', [ 'id' => $navigation['id'], 'confirm' => true ] );
$actor->add_cap( 'unfiltered_html', false );
try {
	$reject( 'wp_update_custom_css', [ 'css' => '.denied { color: red; }', 'confirm' => true ], 'edit_css' );
} finally {
	$actor->remove_cap( 'unfiltered_html' );
}
$actor->add_cap( 'delete_published_pages', false );
try {
	$reject( 'wp_delete_post', [ 'id' => $block_page['id'], 'confirm' => true ], 'permission' );
} finally {
	$actor->remove_cap( 'delete_published_pages' );
}

$published = $call( 'wp_create_post', [ 'title' => 'Preview page', 'content' => '<p>Public original</p>', 'post_type' => 'page', 'status' => 'publish' ] );
$id = $published['id'];
$proposed = '<!-- wp:html --><p>Private proposed 日本語 \\path</p>' . $script . '<!-- /wp:html -->';
$definition = Frontman_Tools::instance()->get( 'wp_save_post_preview' );
frontman_runtime_same( 'read-write', $definition->access, 'Preview requires write access' );
$preview = $call( 'wp_save_post_preview', [ 'id' => $id, 'content' => $proposed ] );
frontman_runtime_same( $id, $preview['parent_id'], 'Preview identifies original page' );
frontman_runtime_same( $proposed, get_post( $preview['autosave_id'] )->post_content, 'Autosave retains proposed bytes' );
frontman_runtime_same( '<p>Public original</p>', $call( 'wp_read_post', [ 'id' => $id ] )['content'], 'Published parent remains unchanged' );
$path = wp_make_link_relative( $preview['preview_url'] );
$authenticated = frontman_runtime_http( 'GET', $path, $cookie );
frontman_runtime_same( 200, $authenticated['status'], 'Authenticated preview renders' );
frontman_runtime_assert( false !== strpos( $authenticated['body'], 'Private proposed' ), 'Authenticated preview contains proposed content' );
$anonymous = frontman_runtime_http( 'GET', $path );
frontman_runtime_assert( false === strpos( $anonymous['body'], 'Private proposed' ), 'Anonymous preview does not expose proposed content' );
$public = frontman_runtime_http( 'GET', wp_make_link_relative( $published['permalink'] ) );
frontman_runtime_assert( false !== strpos( $public['body'], 'Public original' ) && false === strpos( $public['body'], 'Private proposed' ), 'Public page remains unchanged' );
$again = $call( 'wp_save_post_preview', [ 'id' => $id, 'content' => $proposed ] );
frontman_runtime_same( $preview['autosave_id'], $again['autosave_id'], 'Identical autosave is reused' );
$reject( 'wp_save_post_preview', [ 'id' => $id, 'content' => '<p>Other proposal</p>' ], 'differing editor autosave' );
foreach ( [ null, false, 123, [] ] as $invalid ) {
	$reject( 'wp_save_post_preview', [ 'id' => $id, 'content' => $invalid ], 'content' );
}
foreach ( [ null, false, 0, -1, '123', [] ] as $invalid ) {
	$reject( 'wp_save_post_preview', [ 'id' => $invalid, 'content' => 'test' ], 'id' );
}
$reject( 'wp_save_post_preview', [ 'id' => $id ], 'content is a required property' );
$preview_draft = $call( 'wp_create_post', [ 'title' => 'Preview draft', 'content' => 'draft' ] );
$reject( 'wp_save_post_preview', [ 'id' => $preview_draft['id'], 'content' => 'test' ], 'published' );
update_post_meta( $id, '_elementor_edit_mode', 'builder' );
$reject( 'wp_save_post_preview', [ 'id' => $id, 'content' => $proposed ], 'Builder-managed', 'elementor-content-guard' );
delete_post_meta( $id, '_elementor_edit_mode' );
$actor->add_cap( 'unfiltered_html', false );
try {
	$reject( 'wp_save_post_preview', [ 'id' => $id, 'content' => $proposed ], 'unfiltered_html' );
} finally {
	$actor->remove_cap( 'unfiltered_html' );
}
$actor->add_cap( 'edit_published_pages', false );
try {
	$reject( 'wp_save_post_preview', [ 'id' => $id, 'content' => $proposed ], 'permission' );
} finally {
	$actor->remove_cap( 'edit_published_pages' );
}
foreach ( [ 'preview-race-selection', 'preview-race-insert' ] as $fixture ) {
	$race = $call( 'wp_create_post', [ 'title' => 'Preview race ' . $fixture, 'content' => 'Original', 'status' => 'publish' ] );
	$message = $call( 'wp_save_post_preview', [ 'id' => $race['id'], 'content' => 'Proposed' ], true, $fixture );
	frontman_runtime_assert( false !== strpos( $message, 'differing editor autosave' ), 'Concurrent autosave causes a conflict: ' . $message );
	$revisions = get_posts( [
		'post_type' => 'revision', 'post_status' => 'inherit', 'post_parent' => $race['id'],
		'name' => $race['id'] . '-autosave-v1', 'posts_per_page' => -1,
	] );
	$contents = array_column( $revisions, 'post_content' );
	frontman_runtime_assert( in_array( 'Concurrent editor content', $contents, true ), 'Concurrent editor autosave is preserved: ' . $fixture );
	if ( 'preview-race-insert' === $fixture ) {
		frontman_runtime_assert( in_array( 'Proposed', $contents, true ), 'Concurrent insert is reported without rollback' );
	}
	frontman_runtime_same( 'Original', get_post( $race['id'] )->post_content, 'Race does not change published parent' );
}
echo "OK (embed persistence, exact-fragment editing, permissions and partial saves)\n";
