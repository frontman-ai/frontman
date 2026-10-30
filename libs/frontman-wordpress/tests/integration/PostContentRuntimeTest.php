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
