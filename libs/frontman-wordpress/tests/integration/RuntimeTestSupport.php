<?php

function frontman_runtime_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

function frontman_runtime_same( $expected, $actual, string $message ): void {
	frontman_runtime_assert( $expected === $actual, $message . "\nExpected: " . wp_json_encode( $expected ) . "\nActual: " . wp_json_encode( $actual ) );
}

function frontman_runtime_saved_id( string $message ): int {
	frontman_runtime_assert( 1 === preg_match( '/[Pp]ost (\d+) was saved/', $message, $match ), 'Partial save must identify its post: ' . $message );
	frontman_runtime_assert( false !== strpos( $message, 'wp_read_post' ), 'Partial save must explain raw recovery: ' . $message );
	return (int) $match[1];
}

function frontman_runtime_http( string $method, string $path, string $cookie = '', ?string $nonce = null, ?string $body = null, string $test = '' ): array {
	$headers = [ 'Host: frontman-runtime.example.test' ];
	$headers[] = '' === $test ? '' : 'X-Frontman-Seo-Test: ' . $test;
	if ( '' !== $cookie ) {
		$headers[] = 'Cookie: ' . LOGGED_IN_COOKIE . '=' . $cookie;
	}
	if ( null !== $nonce ) {
		$headers[] = 'X-WP-Nonce: ' . $nonce;
	}
	$response = file_get_contents(
		'http://127.0.0.1' . $path,
		false,
		stream_context_create( [ 'http' => [
			'content' => $body ?? '',
			'header' => implode( "\r\n", array_filter( $headers ) ) . "\r\nContent-Type: application/json\r\n",
			'ignore_errors' => true, 'follow_location' => 0,
			'method' => $method,
		] ] )
	);
	preg_match_all( '/^HTTP\/\S+\s+(\d{3})/m', implode( "\n", $http_response_header ?? [] ), $status );
	preg_match( '/<title[^>]*>(.*?)<\/title>/is', (string) $response, $title );
	preg_match_all( "~<meta\\s+[^>]*(?:name|property)=[\"']([^\"']+)[\"'][^>]*content=([\"'])(.*?)\\2[^>]*>~is", (string) $response, $matches, PREG_SET_ORDER );
	$meta = [];
	foreach ( $matches as $match ) {
		$meta[ $match[1] ] = html_entity_decode( $match[3], ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	}
	$webpage = [];
	if ( preg_match( '~<script[^>]*class=["\']yoast-schema-graph["\'][^>]*>(.*?)</script>~is', (string) $response, $schema ) ) {
		foreach ( json_decode( $schema[1], true, 512, JSON_THROW_ON_ERROR )['@graph'] as $piece ) {
			if ( in_array( 'WebPage', (array) $piece['@type'], true ) ) {
				$webpage = $piece;
			}
		}
	}
	return [
		'body' => (string) $response, 'status' => (int) ( end( $status[1] ) ?: 0 ),
		'title' => isset( $title[1] ) ? html_entity_decode( trim( wp_strip_all_tags( $title[1] ) ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) : null,
		'description' => $meta['description'] ?? null,
		'og_title' => $meta['og:title'] ?? null, 'og_description' => $meta['og:description'] ?? null,
		'schema_name' => $webpage['name'] ?? null, 'schema_description' => $webpage['description'] ?? null,
	];
}

function frontman_runtime_tool( string $cookie, ?string $nonce, array $request, ?string $raw = null, string $test = '' ): array {
	$response = frontman_runtime_http( 'POST', '/index.php/frontman/tools/call', $cookie, $nonce, $raw ?? wp_json_encode( $request ), $test );
	if ( 200 !== $response['status'] ) {
		return $response;
	}
	frontman_runtime_assert( 1 === preg_match( '/^data: (.+)$/m', $response['body'], $match ), 'Tool response contained no SSE data event.' );
	return [ 'body' => json_decode( $match[1], true, 512, JSON_THROW_ON_ERROR ), 'status' => 200 ];
}

function frontman_runtime_isolated_cases(): array {
	return [
		'installation-paths' => [ 'file' => 'InstallationPathsRuntimeTest.php', 'root_alias' => true ],
		'seo-coexistence' => [ 'file' => 'SeoCoexistenceRuntimeTest.php', 'root_alias' => false ],
		'surerank' => [ 'file' => 'SureRankRuntimeTest.php', 'root_alias' => false ],
		'directorist' => [ 'file' => 'DirectoristRuntimeTest.php', 'root_alias' => false ],
	];
}

function frontman_runtime_process_case( string $case ): void {
	$cases = frontman_runtime_isolated_cases();
	frontman_runtime_assert( isset( $cases[ $case ] ), 'Unknown isolated runtime case: ' . $case );
	$alias = $cases[ $case ]['root_alias'] ? sys_get_temp_dir() . '/frontman-runtime-root-' . getmypid() : '';
	if ( '' !== $alias ) {
		frontman_runtime_assert( ! file_exists( $alias ) && ! is_link( $alias ), 'Runtime root alias must not already exist.' );
		frontman_runtime_assert( symlink( '/var/www/html', $alias ), 'Could not create the runtime root alias.' );
	}
	try {
		$command = escapeshellarg( PHP_BINARY ) . ' -d display_errors=1 -d error_reporting=E_ALL '
			. escapeshellarg( __DIR__ . '/RunWordPressRuntimeTest.php' ) . ' ' . escapeshellarg( $case ) . ' ' . escapeshellarg( $alias );
		passthru( $command, $status );
		frontman_runtime_same( 0, $status, 'Isolated runtime case failed, including PHP shutdown: ' . $case );
	} finally {
		if ( '' !== $alias && is_link( $alias ) ) {
			frontman_runtime_assert( unlink( $alias ), 'Could not clean the runtime root alias.' );
		}
	}
}
