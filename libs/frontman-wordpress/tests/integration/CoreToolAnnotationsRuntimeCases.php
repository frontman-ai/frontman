<?php

declare(strict_types=1);

$post_ids = [];
$attachment_ids = [];
try {
	$draft = $call( 'wp_create_post', [ 'title' => 'Safety draft', 'content' => '<p>Private draft</p>' ] );
	$post_ids[] = $draft['id'];
	frontman_runtime_same( 'draft', $call( 'wp_read_post', [ 'id' => $draft['id'] ] )['status'], 'Default creation remains private.' );
	$published = $call( 'wp_create_post', [ 'title' => 'Safety published', 'content' => '<p>Original public content</p>', 'status' => 'publish' ] );
	$post_ids[] = $published['id'];
	frontman_runtime_same( 'publish', $call( 'wp_read_post', [ 'id' => $published['id'] ] )['status'], 'The same create tool can publish immediately.' );
	$before = get_post( $published['id'], ARRAY_A );
	for ( $i = 0; $i < 2; $i++ ) {
		$call( 'wp_read_post', [ 'id' => $published['id'] ] );
	}
	clean_post_cache( $published['id'] );
	frontman_runtime_same( $before, get_post( $published['id'], ARRAY_A ), 'Repeated reads do not change stored post state.' );
	for ( $i = 0; $i < 2; $i++ ) {
		$copy = $call( 'wp_duplicate_post', [ 'source_id' => $published['id'] ] );
		$post_ids[] = $copy['id'];
		frontman_runtime_same( 'draft', $call( 'wp_read_post', [ 'id' => $copy['id'] ] )['status'], 'Duplicates remain drafts even for a published source.' );
	}
	frontman_runtime_assert( $post_ids[2] !== $post_ids[3], 'Repeated identical duplication creates additional records.' );
	$preview = $call( 'wp_save_post_preview', [ 'id' => $published['id'], 'content' => '<p>Unpublished proposal</p>' ] );
	clean_post_cache( $preview['autosave_id'] );
	frontman_runtime_same( '<p>Unpublished proposal</p>', get_post( $preview['autosave_id'] )->post_content, 'Preview persists an autosave.' );
	frontman_runtime_same( '<p>Original public content</p>', $call( 'wp_read_post', [ 'id' => $published['id'] ] )['content'], 'Preview does not overwrite published content.' );
	$call( 'wp_update_post', [ 'id' => $published['id'], 'mode' => 'replace', 'content' => '<p>Replacement content</p>' ] );
	$current = $call( 'wp_read_post', [ 'id' => $published['id'] ] );
	$call( 'wp_update_post', [
		'id' => $published['id'], 'mode' => 'edit', 'oldText' => 'Replacement',
		'newText' => 'Edited', 'expected_current_sha256' => $current['content_sha256'],
	] );
	frontman_runtime_same( '<p>Edited content</p>', $call( 'wp_read_post', [ 'id' => $published['id'] ] )['content'], 'Both update modes overwrite existing content.' );
	$current = $call( 'wp_read_post', [ 'id' => $published['id'] ] );
	$batch = [
		'id' => $published['id'], 'mode' => 'edit_many',
		'edits' => [ [ 'oldText' => 'Edited', 'newText' => 'Batch edited' ] ],
		'expected_current_sha256' => $current['content_sha256'],
	];
	$call( 'wp_update_post', $batch + [ 'dryRun' => true ] );
	frontman_runtime_same( $current['content'], $call( 'wp_read_post', [ 'id' => $published['id'] ] )['content'], 'Dry-run does not change stored content, but shares a descriptor with the write mode.' );
	$call( 'wp_update_post', $batch );
	frontman_runtime_same( '<p>Batch edited content</p>', $call( 'wp_read_post', [ 'id' => $published['id'] ] )['content'], 'The batch mode also overwrites published content.' );
	$page = frontman_runtime_http( 'GET', wp_parse_url( $published['permalink'], PHP_URL_PATH ) );
	frontman_runtime_same( 200, $page['status'], 'Published fixture is publicly readable.' );
	frontman_runtime_assert( false !== strpos( $page['body'], 'Batch edited content' ), 'Updates change actual public output.' );
	$call( 'wp_delete_post', [ 'id' => $published['id'], 'confirm' => true ] );
	clean_post_cache( $published['id'] );
	frontman_runtime_same( 'trash', get_post_status( $published['id'] ), 'Default deletion trashes the published post.' );
	$call( 'wp_delete_post', [ 'id' => $published['id'], 'confirm' => true, 'force' => true ] );
	clean_post_cache( $published['id'] );
	frontman_runtime_same( null, get_post( $published['id'] ), 'Force deletion permanently removes the post.' );

	$audio = file_get_contents( '/tmp/frontman-media-fixtures/audio.mp3' );
	for ( $i = 0; $i < 2; $i++ ) {
		$upload = $call( 'wp_upload_media', [ 'content' => base64_encode( $audio ), 'mime_type' => 'audio/mpeg', 'filename' => 'safety-audio.mp3' ] );
		$attachment_ids[] = $upload['attachment_id'];
		$asset = frontman_runtime_http( 'GET', wp_parse_url( $upload['url'], PHP_URL_PATH ) );
		frontman_runtime_same( 200, $asset['status'], 'Uploads are publicly addressable without authentication.' );
		frontman_runtime_same( $audio, $asset['body'], 'Public upload bytes match the supplied asset.' );
	}
	frontman_runtime_assert( $attachment_ids[0] !== $attachment_ids[1], 'Identical uploads create additional attachments.' );
} finally {
	foreach ( $attachment_ids as $id ) { wp_delete_attachment( $id, true ); }
	foreach ( $post_ids as $id ) { wp_delete_post( $id, true ); }
}

$home = get_option( 'home' );
$site = get_option( 'siteurl' );
$path = ABSPATH . 'llms.txt';
$original = file_exists( $path ) ? file_get_contents( $path ) : null;
$previous = get_option( 'frontman_public_file_previous_llms.txt', null );
$public_call = static function( string $name, array $arguments ) use ( $mcp_credentials ): array {
	$response = frontman_runtime_http( 'POST', '/?rest_route=/frontman/v1/tools/call', '', null, wp_json_encode( [ 'name' => $name, 'arguments' => $arguments ] ), '', $mcp_credentials );
	frontman_runtime_same( 200, $response['status'], 'Public file REST dispatch succeeds.' );
	return json_decode( $response['body'], true, 512, JSON_THROW_ON_ERROR );
};
try {
	update_option( 'home', 'http://127.0.0.1' );
	update_option( 'siteurl', 'http://127.0.0.1' );
	if ( file_exists( $path ) ) { unlink( $path ); }
	$result = $public_call( 'wp_read_public_file', [ 'name' => 'llms.txt' ] );
	frontman_runtime_same( false, $result['isError'], 'Initial public file inspection succeeds.' );
	$initial = json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	$result = $public_call( 'wp_write_public_file', [ 'name' => 'llms.txt', 'content' => "# Safety original\n", 'confirm' => true, 'expected_revision' => $initial['revision'] ] );
	frontman_runtime_same( false, $result['isError'], 'Create the public fixture through WordPress filesystem ownership.' );
	$result = $public_call( 'wp_read_public_file', [ 'name' => 'llms.txt' ] );
	frontman_runtime_same( false, $result['isError'], 'Public file inspection succeeds through real WordPress HTTP: ' . wp_json_encode( $result['content'] ) );
	$inspection = json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_same( 200, $inspection['public']['status'], 'Read tool observes a real public HTTP response.' );
	frontman_runtime_same( "# Safety original\n", $inspection['public']['content'], 'Read tool observes public bytes without changing the file.' );
	$arguments = [ 'name' => 'llms.txt', 'content' => "# Safety replacement\n", 'confirm' => true, 'expected_revision' => $inspection['revision'] ];
	$result = $public_call( 'wp_write_public_file', $arguments );
	frontman_runtime_same( false, $result['isError'], 'Public file replacement succeeds.' );
	$saved = json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	frontman_runtime_assert( $saved['saved'] && $saved['verified'], 'Replacement changes local and public state.' );
	frontman_runtime_same( "# Safety replacement\n", frontman_runtime_http( 'GET', '/llms.txt' )['body'], 'Replacement is publicly visible.' );
	frontman_runtime_same( true, $public_call( 'wp_write_public_file', $arguments )['isError'], 'A repeated write with a stale revision is rejected, not automatically retried.' );
} finally {
	if ( null === $original ) {
		if ( file_exists( $path ) ) { unlink( $path ); }
	} else {
		file_put_contents( $path, $original );
	}
	wp_cache_delete( 'frontman_public_file_previous_llms.txt', 'options' );
	wp_cache_delete( 'alloptions', 'options' );
	wp_cache_delete( 'notoptions', 'options' );
	if ( null === $previous ) { delete_option( 'frontman_public_file_previous_llms.txt' ); } else { update_option( 'frontman_public_file_previous_llms.txt', $previous ); }
	update_option( 'home', $home );
	update_option( 'siteurl', $site );
}

fwrite( STDOUT, "OK (59 reviewed core annotations, catalog parity and real effects)\n" );
