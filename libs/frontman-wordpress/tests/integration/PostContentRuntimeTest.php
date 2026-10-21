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

$reject( 'wp_create_post', [ 'title' => 'Missing content' ], 'content is required' );
foreach ( [ null, false, 123, [] ] as $invalid ) {
	$reject( 'wp_create_post', [ 'title' => 'Invalid content', 'content' => $invalid ], 'must be a string' );
	$reject( 'wp_update_post', [ 'id' => $id, 'title' => 'Must not save', 'content' => $invalid ], 'content must be a string' );
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
echo "OK (embed persistence, permissions and partial saves)\n";
