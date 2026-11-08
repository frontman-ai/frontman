<?php

declare(strict_types=1);

$slug = 'assigned-layout';
$part = 'assigned-header';
$call( 'wp_create_template', [
	'slug' => $part, 'type' => 'wp_template_part', 'area' => 'header',
	'title' => 'Header', 'content' => '<!-- wp:paragraph --><p>ASSIGNED HEADER</p><!-- /wp:paragraph -->',
] );
$markup = '<!-- wp:template-part ' . wp_json_encode( [ 'slug' => $part, 'theme' => get_stylesheet() ] ) . ' /--><!-- wp:post-content /-->';
$call( 'wp_create_template', [ 'slug' => $slug, 'type' => 'wp_template', 'title' => 'Layout', 'content' => $markup ] );
$page = [ 'title' => 'Assigned page', 'post_type' => 'page', 'content' => '<!-- wp:paragraph --><p>ASSIGNED BODY</p><!-- /wp:paragraph -->' ];
$created = $call( 'wp_create_post', $page + [ 'template' => $slug, 'status' => 'publish' ] );
$id = $created['id'];
frontman_runtime_same( $slug, get_post_meta( $id, '_wp_page_template', true ), 'Create writes native page-template metadata' );
$rendered = frontman_runtime_http( 'GET', wp_make_link_relative( $created['permalink'] ) );
frontman_runtime_same( 200, $rendered['status'], 'Assigned page renders' );
foreach ( [ 'ASSIGNED HEADER', 'ASSIGNED BODY' ] as $marker ) {
	frontman_runtime_assert( false !== strpos( $rendered['body'], $marker ), 'Assigned template renders ' . $marker );
}
foreach ( [
	[ [ 'title' => 'Keep assignment' ], $slug ],
	[ [ 'template' => 'default' ], 'default' ],
	[ [ 'template' => $slug ], $slug ],
] as [ $edit, $expected ] ) {
	$saved = $call( 'wp_update_post', [ 'id' => $id ] + $edit );
	frontman_runtime_same( $expected, $saved['after']['template'], 'Update preserves, resets or assigns the template: ' . wp_json_encode( $edit ) );
}
$plain = $call( 'wp_create_post', $page );
frontman_runtime_same( 'default', $plain['after']['template'], 'Omitted creation template uses the default' );

try {
	foreach ( [ 123, true, 1.5, 0, false ] as $stored_template ) {
		update_post_meta( $plain['id'], '_wp_page_template', $stored_template );
		$metadata = get_post_meta( $plain['id'] );
		$metadata['_wp_page_template'] = [ $stored_template ];
		wp_cache_set( $plain['id'], $metadata, 'post_meta' );
		frontman_runtime_same( $stored_template, get_post_meta( $plain['id'], '_wp_page_template', true ), 'Native metadata cache retains the scalar fixture type' );
		$result = Frontman_Tools::instance()->call( 'wp_read_post', [ 'id' => $plain['id'] ] );
		frontman_runtime_same( false, $result['isError'], 'Cached scalar template metadata remains readable in strict mode' );
		$read = json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
		$expected = $stored_template ? (string) $stored_template : 'default';
		frontman_runtime_same( $expected, $read['template'], 'Cached scalar template metadata preserves string output' );
		wp_cache_delete( $plain['id'], 'post_meta' );
		frontman_runtime_same( $expected, $call( 'wp_read_post', [ 'id' => $plain['id'] ] )['template'], 'Fresh database reads preserve the same template output' );
	}
} finally {
	delete_post_meta( $plain['id'], '_wp_page_template' );
}

foreach ( [ [ null, 'template' ], [ 'missing-layout', 'not available' ], [ $part, 'not available' ] ] as [ $invalid, $reason ] ) {
	$reject( 'wp_create_post', $page + [ 'template' => $invalid ], $reason );
	$reject( 'wp_update_post', [ 'id' => $id, 'title' => 'Must not save', 'template' => $invalid ], $reason );
}
$post = $call( 'wp_create_post', [ 'title' => 'Nonpage', 'content' => '' ] );
$reject( 'wp_create_post', [ 'title' => 'Nonpage', 'content' => '', 'template' => 'default' ], 'only supported for pages' );
$reject( 'wp_update_post', [ 'id' => $post['id'], 'template' => 'default' ], 'only supported for pages' );
$reject( 'wp_create_post', $page + [ 'template' => $slug ], 'not available', 'unavailable-template' );
$reject( 'wp_update_post', [ 'id' => $id, 'template' => $slug ], 'not available', 'unavailable-template' );

foreach ( [
	[ 'wp_create_post', $page + [ 'template' => $slug ], 'default' ],
	[ 'wp_update_post', [ 'id' => $id, 'title' => 'Saved title', 'template' => 'default' ], $slug ],
] as [ $name, $input, $actual_template ] ) {
	$message = $call( $name, $input, true, 'reject-template-metadata' );
	$raw = $call( 'wp_read_post', [ 'id' => frontman_runtime_saved_id( $message ) ] );
	frontman_runtime_same( $input['title'], $raw['title'], 'Metadata failure retains the saved post fields' );
	frontman_runtime_same( $actual_template, $raw['template'], 'Partial save reports the template actually stored' );
}
echo "OK (page-template rendering, assignment and failed metadata writes)\n";
