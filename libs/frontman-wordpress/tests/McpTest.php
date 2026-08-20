<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-mcp-tests/' );
define( 'FRONTMAN_VERSION', '2.0.0' );

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_check_invalid_utf8' ) ) {
	function wp_check_invalid_utf8( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'esc_url_raw' ) ) {
	function esc_url_raw( $value ): string {
		return (string) $value;
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-mcp.php';

class Frontman_Mcp_Test_Runner {
	private int $assertions = 0;
	private Frontman_MCP $mcp;
	private int $executions = 0;
	private array $rate_store = [];
	private int $rate_now = 1000;

	public function __construct() {
		$tools = new Frontman_Tools();
		$tools->add(
			new Frontman_Tool_Definition(
				'zeta_write',
				'Writes a value',
				[
					'type'                 => 'object',
					'additionalProperties' => false,
					'properties'           => [ 'value' => [ 'type' => 'string', 'enum' => [ 'ok' ] ] ],
					'required'             => [ 'value' ],
				],
				function ( array $input ): array {
					$this->executions++;
					return [ 'value' => $input['value'] ];
				},
				'write'
			)
		);
		$tools->add(
			new Frontman_Tool_Definition(
				'alpha_read',
				'Reads a value',
				[ 'type' => 'object', 'additionalProperties' => false, 'properties' => new stdClass() ],
				function (): array {
					$this->executions++;
					return [ 'ok' => true ];
				},
				'read'
			)
		);
		$tools->add(
			new Frontman_Tool_Definition(
				'hidden_tool',
				'Hidden',
				[ 'type' => 'object', 'properties' => new stdClass() ],
				function (): array { return []; },
				null,
				false
			)
		);
		$this->mcp = new Frontman_MCP( $tools, 'https://example.test', $this->rate_limiter() );
	}

	public function run(): void {
		$this->test_origin_precedes_authorization();
		$this->test_preflight_is_origin_only();
		$this->test_discovery();
		$this->test_listing_is_private_sorted_and_standard();
		$this->test_call_and_exact_id();
		$this->test_rejections_do_not_execute();
		$this->test_method_based_name_authority_and_malformed_precedence();
		$this->test_application_failures_have_no_authentication_challenge_or_side_effects();
		$this->test_open_fields_metadata_mrtr_and_encoded_name();
		$this->test_media_and_body_limits();
		$this->test_rate_limit_boundary_isolation_expiry_and_failure();
		$this->test_schema_profile_and_registry_limits();
		$this->test_stateless_identity_and_optional_feature_absence();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function test_origin_precedes_authorization(): void {
		$authorization_calls = 0;
		$response = $this->mcp->handle( 'POST', $this->headers( 'server/discover', null, null ), $this->body( 'server/discover', 'a' ), function () use ( &$authorization_calls ): array {
			$authorization_calls++;
			return [ 'status' => 401 ];
		} );
		$this->assert_same( 403, $response['status'], 'missing Origin is forbidden' );
		$this->assert_same( 0, $authorization_calls, 'Origin rejection precedes authorization' );
		$this->assert_same( '', $response['body'], 'Origin rejection is empty' );

		$response = $this->request( 'server/discover', 'a', [], [], 401 );
		$this->assert_same( 401, $response['status'], 'missing authentication is empty 401' );
		$this->assert_same( 'https://example.test', $response['headers']['Access-Control-Allow-Origin'], 'accepted Origin is echoed on auth rejection' );
	}

	private function test_preflight_is_origin_only(): void {
		$authorization_calls = 0;
		$response = $this->mcp->handle(
			'OPTIONS',
			[
				'Origin'                         => 'https://example.test',
				'Access-Control-Request-Method'  => 'POST',
				'Access-Control-Request-Headers' => 'Content-Type, MCP-Protocol-Version, Mcp-Method, X-WP-Nonce',
			],
			'',
			function () use ( &$authorization_calls ): array {
				$authorization_calls++;
				return [ 'status' => 401 ];
			}
		);
		$this->assert_same( 204, $response['status'], 'valid preflight succeeds' );
		$this->assert_same( 0, $authorization_calls, 'preflight does not authenticate' );
		$this->assert_same( 'POST, OPTIONS', $response['headers']['Access-Control-Allow-Methods'], 'preflight advertises narrow methods' );

		$response = $this->mcp->handle(
			'OPTIONS',
			[
				'Origin'                         => 'https://example.test',
				'Access-Control-Request-Method'  => 'POST',
				'Access-Control-Request-Headers' => 'X-Hostile',
			],
			'',
			function (): array { return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ]; }
		);
		$this->assert_same( 400, $response['status'], 'unsupported preflight header is rejected' );
	}

	private function test_discovery(): void {
		$response = $this->request( 'server/discover', 'discover' );
		$data = $this->json( $response );
		$this->assert_same( 200, $response['status'], 'discovery succeeds' );
		$this->assert_same( 'discover', $data['id'], 'discovery preserves string ID' );
		$this->assert_same( 'complete', $data['result']['resultType'], 'discovery is complete' );
		$this->assert_same( [ '2026-07-28' ], $data['result']['supportedVersions'], 'discovery advertises only the latest version' );
		$this->assert_same( [ 'tools' => [ 'listChanged' => false ] ], $data['result']['capabilities'], 'discovery advertises only implemented capabilities' );
		$this->assert_same( 'private', $data['result']['cacheScope'], 'discovery cache is private' );
	}

	private function test_listing_is_private_sorted_and_standard(): void {
		$response = $this->request( 'tools/list', 9007199254740991 );
		$data = $this->json( $response );
		$this->assert_same( 9007199254740991, $data['id'], 'listing preserves wide safe numeric ID' );
		$this->assert_same( [ 'alpha_read', 'zeta_write' ], array_column( $data['result']['tools'], 'name' ), 'listing filters and sorts tools' );
		$this->assert_same( [ 'readOnlyHint' => true ], $data['result']['tools'][0]['annotations'], 'read access maps to standard annotation' );
		$this->assert_same( [ 'readOnlyHint' => false ], $data['result']['tools'][1]['annotations'], 'write access maps to standard annotation' );
		$this->assert_false( isset( $data['result']['tools'][0]['access'] ), 'listing omits Relay access' );
		$this->assert_false( isset( $data['result']['tools'][0]['visibleToAgent'] ), 'listing omits Relay visibility' );

		$response = $this->request( 'tools/list', 2, [ 'cursor' => '' ] );
		$this->assert_error( $response, 200, -32602, 'Invalid method parameters' );
	}

	private function test_call_and_exact_id(): void {
		$response = $this->request( 'tools/call', 'call-1', [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ] ], [ 'Mcp-Name' => 'zeta_write' ] );
		$data = $this->json( $response );
		$this->assert_same( 200, $response['status'], 'tool call succeeds' );
		$this->assert_same( 'call-1', $data['id'], 'call preserves ID' );
		$this->assert_same( 'complete', $data['result']['resultType'], 'call result is complete' );
		$this->assert_same( '{"value":"ok"}', $data['result']['content'][0]['text'], 'call preserves tool output' );
		$this->assert_same( [ 'name' => 'frontman-wordpress', 'version' => '2.0.0' ], $data['result']['_meta']['io.modelcontextprotocol/serverInfo'], 'call result includes server identity' );
		$this->assert_same( 1, $this->executions, 'valid call executes once' );
	}

	private function test_rejections_do_not_execute(): void {
		$response = $this->request( 'tools/call', 3, [ 'name' => 'missing' ], [ 'Mcp-Name' => 'missing' ] );
		$this->assert_error( $response, 200, -32602, 'Unknown tool: missing' );

		$response = $this->request( 'tools/call', 4, [ 'name' => 'zeta_write' ], [ 'Mcp-Name' => 'zeta_write' ] );
		$data = $this->json( $response );
		$this->assert_same( true, $data['result']['isError'], 'invalid selected input is a tool error result' );
		$this->assert_same( 'Invalid tool arguments', $data['result']['content'][0]['text'], 'input diagnostics are redacted' );
		$this->assert_same( 'frontman-wordpress', $data['result']['_meta']['io.modelcontextprotocol/serverInfo']['name'], 'tool error result includes server identity' );

		$response = $this->request( 'tools/call', 5, [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ] ], [ 'Mcp-Name' => 'wrong' ] );
		$this->assert_error( $response, 400, -32020, 'Header mismatch: Mcp-Name' );

		$response = $this->request( 'unknown/method', 6 );
		$this->assert_error( $response, 404, -32601, 'Method not found' );
		$this->assert_same( 1, $this->executions, 'all rejected requests avoid execution' );
	}

	private function test_method_based_name_authority_and_malformed_precedence(): void {
		$executions = $this->executions;
		$rate_store = $this->rate_store;

		$response = $this->request( 'prompts/get', 'prompt', [ 'name' => 'welcome', 'uri' => 'ignored' ], [ 'Mcp-Name' => 'welcome' ] );
		$this->assert_error( $response, 404, -32601, 'Method not found' );
		$response = $this->request( 'resources/read', 'resource', [ 'name' => 'ignored', 'uri' => 'file:///project' ], [ 'Mcp-Name' => 'file:///project' ] );
		$this->assert_error( $response, 404, -32601, 'Method not found' );
		$response = $this->request( 'prompts/get', 'wrong-prompt-authority', [ 'name' => 'welcome', 'uri' => 'ignored' ], [ 'Mcp-Name' => 'ignored' ] );
		$this->assert_error( $response, 400, -32020, 'Header mismatch: Mcp-Name' );
		$response = $this->request( 'resources/read', 'wrong-resource-authority', [ 'name' => 'ignored', 'uri' => 'file:///project' ], [ 'Mcp-Name' => 'ignored' ] );
		$this->assert_error( $response, 400, -32020, 'Header mismatch: Mcp-Name' );
		$response = $this->request( 'unknown/method', 'unnamed', [ 'name' => 'not-an-authority' ] );
		$this->assert_error( $response, 404, -32601, 'Method not found' );

		foreach ( [
			[ 'tools/call', [ 'name' => false ], 'tool' ],
			[ 'prompts/get', [ 'name' => false ], 'prompt' ],
			[ 'resources/read', [ 'uri' => false ], 'file:///project' ],
		] as [ $method, $params, $header_name ] ) {
			$response = $this->request( $method, 'malformed-' . $method, $params, [ 'Mcp-Name' => $header_name ] );
			$this->assert_error( $response, 400, -32020, 'Header mismatch: Mcp-Name' );
		}

		$this->assert_same( $executions, $this->executions, 'unsupported and malformed named methods have no tool side effects' );
		$this->assert_same( $rate_store, $this->rate_store, 'unsupported and malformed named methods do not consume rate state' );
	}

	private function test_application_failures_have_no_authentication_challenge_or_side_effects(): void {
		foreach ( [
			[ 401, 'missing authentication' ],
			[ 403, 'forbidden application principal' ],
			[ 403, 'invalid application nonce' ],
		] as [ $status, $label ] ) {
			$body_reads = 0;
			$response = $this->mcp->handle(
				'POST',
				$this->headers( 'tools/call', 'zeta_write' ),
				function () use ( &$body_reads ): string {
					$body_reads++;
					return $this->body( 'tools/call', 'unauthorized', [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ] ] );
				},
				function () use ( $status ): array { return [ 'status' => $status ]; }
			);
			$this->assert_same( $status, $response['status'], $label . ' preserves application status' );
			$this->assert_false( isset( $response['headers']['WWW-Authenticate'] ), $label . ' emits no protocol authentication challenge' );
			$this->assert_same( 0, $body_reads, $label . ' does not read the request body' );
		}
		$this->assert_same( 1, $this->executions, 'application authentication failures cannot execute tools' );
	}

	private function test_media_and_body_limits(): void {
		$executions = $this->executions;
		$response = $this->request( 'server/discover', 7, [], [ 'Content-Type' => 'text/plain' ] );
		$this->assert_same( 415, $response['status'], 'unsupported media type is rejected' );
		$response = $this->request( 'server/discover', 8, [], [ 'Accept' => 'application/json' ] );
		$this->assert_same( 406, $response['status'], 'incomplete response offers are rejected' );

		$headers = $this->headers( 'server/discover' );
		$headers['Content-Length'] = '2097153';
		$response = $this->mcp->handle( 'POST', $headers, '', function (): array { return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ]; } );
		$this->assert_same( 413, $response['status'], 'declared oversized body is rejected' );
		$this->assert_same( $executions, $this->executions, 'transport rejection avoids execution' );
	}

	private function test_open_fields_metadata_mrtr_and_encoded_name(): void {
		$response = $this->request( 'server/discover', 9, [ 'vendorField' => true ] );
		$this->assert_same( 200, $response['status'], 'open method fields remain accepted' );

		$body = json_decode( $this->body( 'server/discover', 10 ) );
		$body->params->_meta->{'io.modelcontextprotocol/clientCapabilities'} = (object) [ 'roots' => true ];
		$response = $this->mcp->handle( 'POST', $this->headers( 'server/discover' ), json_encode( $body ), function (): array { return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ]; } );
		$this->assert_error( $response, 400, -32602, 'Invalid request metadata' );

		foreach ( [ 'traceparent', 'tracestate', 'baggage' ] as $reserved ) {
			$body = json_decode( $this->body( 'server/discover', 'reserved-' . $reserved ) );
			$body->params->_meta->{$reserved} = 'must-not-propagate';
			$response = $this->mcp->handle( 'POST', $this->headers( 'server/discover' ), json_encode( $body ), function (): array { return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ]; } );
			$this->assert_error( $response, 400, -32602, 'Invalid request metadata' );
		}

		$response = $this->request( 'tools/call', 11, [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ], 'requestState' => 'opaque' ], [ 'Mcp-Name' => 'zeta_write' ] );
		$this->assert_error( $response, 200, -32602, 'Invalid method parameters' );
		$response = $this->request( 'tools/call', 11, [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ], 'inputResponses' => [ 'prompt' => [ 'action' => 'bogus' ] ] ], [ 'Mcp-Name' => 'zeta_write' ] );
		$this->assert_error( $response, 200, -32602, 'Invalid method parameters' );

		$response = $this->request( 'tools/call', 12, [ 'name' => 'zeta_write', 'arguments' => [ 'value' => 'ok' ] ], [ 'Mcp-Name' => '=?base64?' . base64_encode( 'zeta_write' ) . '?=' ] );
		$this->assert_same( 200, $response['status'], 'encoded MCP name is decoded before comparison' );
		$this->assert_same( 2, $this->executions, 'encoded matching name executes once' );
	}

	private function test_rate_limit_boundary_isolation_expiry_and_failure(): void {
		$this->rate_store = [];
		$this->rate_now = 2000;
		for ( $index = 1; $index <= Frontman_MCP_Rate_Limiter::LIMIT; $index++ ) {
			$response = $this->request( 'server/discover', 'rate-' . $index );
			$this->assert_same( 200, $response['status'], 'request at or below rate boundary succeeds' );
		}
		$executions = $this->executions;
		$response = $this->request( 'tools/call', 'rate-rejected', [ 'name' => 'alpha_read' ], [ 'Mcp-Name' => 'alpha_read' ] );
		$this->assert_same( 429, $response['status'], 'first request over rate boundary is rejected' );
		$this->assert_same( '60', $response['headers']['Retry-After'], 'rate rejection reports deterministic window expiry' );
		$this->assert_same( '', $response['body'], 'rate rejection has no payload' );
		$this->assert_same( $executions, $this->executions, 'rate rejection cannot execute a tool' );
		$this->assert_same( Frontman_MCP_Rate_Limiter::LIMIT, max( array_column( $this->rate_store, 'count' ) ), 'rejected request does not increment stored count' );

		$response = $this->request( 'server/discover', 'isolated', [], [], 200, 'wordpress:1:user:2' );
		$this->assert_same( 200, $response['status'], 'different authorized principal has an isolated budget' );
		$this->assert_same( 2, count( $this->rate_store ), 'rate limiter stores one bounded record per active principal' );
		foreach ( array_keys( $this->rate_store ) as $key ) {
			$this->assert_false( false !== strpos( $key, 'wordpress:' ), 'rate storage key does not disclose principal text' );
		}

		$this->rate_now += Frontman_MCP_Rate_Limiter::WINDOW_SECONDS;
		$response = $this->request( 'server/discover', 'expired' );
		$this->assert_same( 200, $response['status'], 'budget expires at the exact window boundary' );

		$contention_store = false;
		$contention_writes = 0;
		$contention = new Frontman_MCP_Rate_Limiter(
			function () use ( &$contention_store ) { return $contention_store; },
			function ( string $key, $expected, array $state ) use ( &$contention_store, &$contention_writes ): bool {
				$contention_writes++;
				if ( 1 === $contention_writes ) {
					$contention_store = [ 'window' => 2500, 'count' => 1 ];
					return false;
				}
				if ( $contention_store !== $expected ) {
					return false;
				}
				$contention_store = $state;
				return true;
			},
			function (): int { return 2500; }
		);
		$this->assert_same( true, $contention->consume( 'wordpress:1:user:3' )['accepted'], 'compare-and-swap contention retries within the fixed bound' );
		$this->assert_same( 2, $contention_store['count'], 'contention cannot overwrite a concurrently consumed request' );

		$failing = new Frontman_MCP_Rate_Limiter(
			function () { return false; },
			function (): bool { return false; },
			function (): int { return 3000; }
		);
		$mcp = new Frontman_MCP( $this->tool_registry(), 'https://example.test', $failing );
		$response = $mcp->handle( 'POST', $this->headers( 'tools/call', 'alpha_read' ), $this->body( 'tools/call', 'closed', [ 'name' => 'alpha_read' ] ), function (): array {
			return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ];
		} );
		$this->assert_same( 503, $response['status'], 'rate-limit persistence failure fails closed' );
		$this->assert_same( '', $response['body'], 'fail-closed response is empty' );
	}

	private function test_schema_profile_and_registry_limits(): void {
		$registry = new Frontman_Tools();
		$registry->add( new Frontman_Tool_Definition(
			'profile',
			'Profile',
			[
				'$schema'              => 'https://json-schema.org/draft/2020-12/schema',
				'type'                 => 'object',
				'properties'           => [
					'settings' => [ 'type' => 'object', 'minProperties' => 1, 'properties' => new stdClass() ],
					'values'   => [ 'type' => 'array', 'items' => [ 'type' => 'string', 'enum' => [ 'a', 'b' ] ] ],
				],
				'required'             => [ 'settings', 'values' ],
				'additionalProperties' => false,
			],
			function (): array { return []; }
		) );
		$this->assert_same( true, $registry->valid_input( 'profile', json_decode( '{"settings":{"dynamic":true},"values":["a","b"]}' ) ), 'supported schema profile accepts all satisfied constraints' );
		$this->assert_same( false, $registry->valid_input( 'profile', json_decode( '{"settings":{},"values":["a"]}' ) ), 'minProperties is enforced' );
		$this->assert_same( false, $registry->valid_input( 'profile', json_decode( '{"settings":{"x":1},"values":["c"]}' ) ), 'nested enum is enforced' );
		$this->assert_same( false, $registry->valid_input( 'profile', json_decode( '{"settings":{"x":1},"values":["a"],"extra":true}' ) ), 'explicit additionalProperties false is enforced' );

		$open = new Frontman_Tools();
		$open->add( new Frontman_Tool_Definition( 'open', 'Open', [ 'type' => 'object', 'properties' => new stdClass() ], function (): array { return []; } ) );
		$this->assert_same( true, $open->valid_input( 'open', json_decode( '{"extra":"kept"}' ) ), 'omitted additionalProperties defaults to true' );
		$this->assert_same( [ 'extra' => 'kept' ], $open->sanitize_input( 'open', [ 'extra' => 'kept' ] ), 'sanitization preserves schema-permitted additional properties' );

		$this->assert_throws( function (): void {
			( new Frontman_Tools() )->add( new Frontman_Tool_Definition( 'unsupported', 'Unsupported', [ 'type' => 'object', 'anyOf' => [] ], function (): array { return []; } ) );
		}, InvalidArgumentException::class, 'unsupported schema vocabulary is rejected at registration' );
		$this->assert_throws( function (): void {
			( new Frontman_Tools() )->add( new Frontman_Tool_Definition( 'dialect', 'Dialect', [ '$schema' => 'http://json-schema.org/draft-07/schema#', 'type' => 'object' ], function (): array { return []; } ) );
		}, InvalidArgumentException::class, 'unsupported schema dialect is rejected at registration' );

		$names = new Frontman_Tools();
		$names->add( $this->definition( 'unique' ) );
		$this->assert_throws( function () use ( $names ): void { $names->add( $this->definition( 'unique' ) ); }, InvalidArgumentException::class, 'duplicate names are rejected' );
		$this->assert_throws( function (): void { ( new Frontman_Tools() )->add( $this->definition( 'bad name' ) ); }, InvalidArgumentException::class, 'invalid names are rejected' );
		$names->add( $this->definition( str_repeat( 'n', 128 ) ) );
		$this->assert_throws( function (): void { ( new Frontman_Tools() )->add( $this->definition( str_repeat( 'n', 129 ) ) ); }, InvalidArgumentException::class, 'name length one beyond the boundary is rejected' );

		$count_registry = new Frontman_Tools();
		for ( $index = 0; $index < Frontman_Tools::MAX_TOOLS; $index++ ) {
			$count_registry->add( $this->definition( 'count_' . $index ) );
		}
		$this->assert_same( Frontman_Tools::MAX_TOOLS, count( $count_registry->all_definitions() ), 'exact tool count boundary is accepted' );
		$this->assert_throws( function () use ( $count_registry ): void { $count_registry->add( $this->definition( 'count_over' ) ); }, LengthException::class, 'tool count one beyond the boundary is rejected' );

		$definition_registry = new Frontman_Tools();
		$definition_registry->add( $this->padded_definition( 'definition_exact', Frontman_Tools::MAX_DEFINITION_BYTES ) );
		$this->assert_throws( function (): void {
			( new Frontman_Tools() )->add( $this->padded_definition( 'definition_over', Frontman_Tools::MAX_DEFINITION_BYTES + 1 ) );
		}, LengthException::class, 'definition byte limit rejects one over' );

		$catalog_registry = new Frontman_Tools();
		for ( $index = 0; $index < 16; $index++ ) {
			$catalog_registry->add( $this->padded_definition( 'catalog_' . $index, Frontman_Tools::MAX_DEFINITION_BYTES ) );
		}
		$this->assert_throws( function () use ( $catalog_registry ): void { $catalog_registry->add( $this->definition( 'catalog_over' ) ); }, LengthException::class, 'aggregate byte limit rejects the first byte-bearing definition over' );
	}

	private function test_stateless_identity_and_optional_feature_absence(): void {
		$this->rate_store = [];
		$first = json_decode( $this->body( 'tools/list', 'identity-one' ) );
		$first->params->_meta->{'io.modelcontextprotocol/clientInfo'} = (object) [ 'name' => 'client-one', 'version' => '1' ];
		$second = json_decode( $this->body( 'tools/list', 'identity-two' ) );
		$second->params->_meta->{'io.modelcontextprotocol/clientInfo'} = (object) [ 'name' => 'spoofed-server-name', 'version' => '999' ];
		$headers = $this->headers( 'tools/list' );
		$headers['Mcp-Session-Id'] = 'attacker-controlled-session';
		$response_one = $this->mcp->handle( 'POST', $headers, json_encode( $first ), $this->authorization() );
		$response_two = $this->mcp->handle( 'POST', $headers, json_encode( $second ), $this->authorization() );
		$data_one = $this->json( $response_one );
		$data_two = $this->json( $response_two );
		$this->assert_same( $data_one['result']['tools'], $data_two['result']['tools'], 'clientInfo and prior requests do not change the stateless catalog' );
		$this->assert_false( isset( $response_one['headers']['Mcp-Session-Id'] ), 'server emits no session header' );
		$this->assert_same( [ 'tools' => [ 'listChanged' => false ] ], $this->json( $this->request( 'server/discover', 'capabilities' ) )['result']['capabilities'], 'optional server capabilities remain absent' );
		$executions = $this->executions;
		$this->assert_error( $this->request( 'resources/list', 'unsupported-resource' ), 404, -32601, 'Method not found' );
		$this->assert_same( $executions, $this->executions, 'unadvertised optional method has no side effect' );
		$response = $this->request( 'tools/call', 'no-discovery-required', [ 'name' => 'alpha_read' ], [ 'Mcp-Name' => 'alpha_read', 'Mcp-Session-Id' => 'different' ] );
		$this->assert_same( 200, $response['status'], 'tool call requires no discovery or session history' );
	}

	private function request( string $method, $id, array $params = [], array $header_overrides = [], int $authorization = 200, string $principal = 'wordpress:1:user:1' ): array {
		$name = 'resources/read' === $method ? ( $params['uri'] ?? null ) : ( in_array( $method, [ 'tools/call', 'prompts/get' ], true ) ? ( $params['name'] ?? null ) : null );
		$headers = array_merge( $this->headers( $method, is_string( $name ) ? $name : null ), $header_overrides );
		return $this->mcp->handle( 'POST', $headers, $this->body( $method, $id, $params ), function () use ( $authorization, $principal ): array { return [ 'status' => $authorization, 'principal' => $principal ]; } );
	}

	private function authorization(): callable {
		return function (): array { return [ 'status' => 200, 'principal' => 'wordpress:1:user:1' ]; };
	}

	private function rate_limiter(): Frontman_MCP_Rate_Limiter {
		return new Frontman_MCP_Rate_Limiter(
			function ( string $key ) { return $this->rate_store[ $key ] ?? false; },
			function ( string $key, $expected, array $state ): bool {
				$current = $this->rate_store[ $key ] ?? false;
				if ( $current !== $expected ) {
					return false;
				}
				$this->rate_store[ $key ] = $state;
				return true;
			},
			function (): int { return $this->rate_now; }
		);
	}

	private function tool_registry(): Frontman_Tools {
		$tools = new Frontman_Tools();
		$tools->add( new Frontman_Tool_Definition( 'alpha_read', 'Reads', [ 'type' => 'object', 'additionalProperties' => false, 'properties' => new stdClass() ], function (): array {
			$this->executions++;
			return [ 'ok' => true ];
		} ) );
		return $tools;
	}

	private function definition( string $name, string $description = '' ): Frontman_Tool_Definition {
		return new Frontman_Tool_Definition( $name, $description, [ 'type' => 'object', 'additionalProperties' => false, 'properties' => new stdClass() ], function (): array { return []; } );
	}

	private function padded_definition( string $name, int $bytes ): Frontman_Tool_Definition {
		$definition = $this->definition( $name );
		$encoded = wp_json_encode( $definition->to_array(), JSON_UNESCAPED_SLASHES );
		$padding = $bytes - strlen( $encoded );
		if ( $padding < 0 ) {
			throw new RuntimeException( 'Requested definition size is too small' );
		}
		return $this->definition( $name, str_repeat( 'x', $padding ) );
	}

	private function headers( string $method, ?string $name = null, ?string $origin = 'https://example.test' ): array {
		$headers = [
			'Content-Type'         => 'application/json',
			'Accept'               => 'application/json, text/event-stream',
			'MCP-Protocol-Version' => '2026-07-28',
			'Mcp-Method'           => $method,
		];
		if ( null !== $origin ) {
			$headers['Origin'] = $origin;
		}
		if ( null !== $name ) {
			$headers['Mcp-Name'] = $name;
		}
		return $headers;
	}

	private function body( string $method, $id, array $params = [] ): string {
		$params['_meta'] = [
			'io.modelcontextprotocol/protocolVersion'   => '2026-07-28',
			'io.modelcontextprotocol/clientCapabilities' => new stdClass(),
		];
		return json_encode( [ 'jsonrpc' => '2.0', 'id' => $id, 'method' => $method, 'params' => $params ] );
	}

	private function json( array $response ): array {
		$data = json_decode( $response['body'], true );
		if ( ! is_array( $data ) ) {
			throw new RuntimeException( 'Expected JSON response, got: ' . $response['body'] );
		}
		return $data;
	}

	private function assert_error( array $response, int $status, int $code, string $message ): void {
		$data = $this->json( $response );
		$this->assert_same( $status, $response['status'], 'error status' );
		$this->assert_same( $code, $data['error']['code'], 'error code' );
		$this->assert_same( $message, $data['error']['message'], 'error message' );
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . "\nExpected: " . var_export( $expected, true ) . "\nActual: " . var_export( $actual, true ) );
		}
	}

	private function assert_false( bool $condition, string $message ): void {
		$this->assert_same( false, $condition, $message );
	}

	private function assert_throws( callable $callback, string $class, string $message ): void {
		$this->assertions++;
		try {
			$callback();
		} catch ( Throwable $error ) {
			if ( $error instanceof $class ) {
				return;
			}
			throw new RuntimeException( $message . '\nExpected: ' . $class . '\nActual: ' . get_class( $error ) );
		}
		throw new RuntimeException( $message . '\nExpected exception: ' . $class );
	}
}

( new Frontman_Mcp_Test_Runner() )->run();
