<?php

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_MCP_Rate_Limiter {
	public const LIMIT = 256;
	public const WINDOW_SECONDS = 60;
	private const MAX_WRITE_ATTEMPTS = 8;

	private $read;
	private $write;
	private $clock;

	public function __construct( ?callable $read = null, ?callable $write = null, ?callable $clock = null ) {
		$this->read = $read ?? function ( string $key ) { return get_option( $key, false ); };
		$this->write = $write ?? function ( string $key, $expected, array $state ): bool {
			if ( false === $expected ) {
				return add_option( $key, $state, '', false );
			}
			global $wpdb;
			$updated = $wpdb->update(
				$wpdb->options,
				[ 'option_value' => maybe_serialize( $state ) ],
				[ 'option_name' => $key, 'option_value' => maybe_serialize( $expected ) ],
				[ '%s' ],
				[ '%s', '%s' ]
			);
			if ( 1 === $updated ) {
				wp_cache_delete( $key, 'options' );
				return true;
			}
			return false;
		};
		$this->clock = $clock ?? function (): int { return time(); };
	}

	public function consume( string $principal ): array {
		$key = 'frontman_mcp_rate_' . hash( 'sha256', $principal );
		$now = (int) ( $this->clock )();
		for ( $attempt = 0; $attempt < self::MAX_WRITE_ATTEMPTS; $attempt++ ) {
			$stored = ( $this->read )( $key );
			$state = $stored;
			if ( false === $state || null === $state ) {
				$stored = false;
				$state = [ 'window' => $now, 'count' => 0 ];
			}
			if ( ! is_array( $state ) || ! isset( $state['window'], $state['count'] ) || ! is_int( $state['window'] ) || ! is_int( $state['count'] ) || $state['window'] > $now || $state['count'] < 0 || $state['count'] > self::LIMIT ) {
				throw new \RuntimeException( 'Invalid MCP rate-limit state' );
			}
			if ( $now >= $state['window'] + self::WINDOW_SECONDS ) {
				$state = [ 'window' => $now, 'count' => 0 ];
			}
			if ( $state['count'] >= self::LIMIT ) {
				return [ 'accepted' => false, 'retry_after' => max( 1, $state['window'] + self::WINDOW_SECONDS - $now ) ];
			}
			$state['count']++;
			if ( true === ( $this->write )( $key, $stored, $state ) ) {
				return [ 'accepted' => true, 'retry_after' => 0 ];
			}
		}
		throw new \RuntimeException( 'Failed to persist MCP rate-limit state' );
	}
}

class Frontman_MCP {
	private const VERSION = '2026-07-28';
	private const MAX_BODY_BYTES = 2097152;
	private const MAX_JSON_DEPTH = 64;
	private const MAX_META_KEYS = 64;
	private const MAX_META_BYTES = 16384;

	private Frontman_Tools $tools;
	private string $allowed_origin;
	private Frontman_MCP_Rate_Limiter $rate_limiter;

	public function __construct( Frontman_Tools $tools, string $allowed_origin, ?Frontman_MCP_Rate_Limiter $rate_limiter = null ) {
		$origin = $this->canonical_origin( $allowed_origin );
		if ( null === $origin ) {
			throw new \InvalidArgumentException( 'Invalid MCP allowed Origin' );
		}
		$this->tools          = $tools;
		$this->allowed_origin = $origin;
		$this->rate_limiter   = $rate_limiter ?? new Frontman_MCP_Rate_Limiter();
	}

	public function handle( string $method, array $headers, $body, callable $authorize ): array {
		$origin = $this->validated_origin( $this->header( $headers, 'Origin' ) );
		if ( null === $origin ) {
			return $this->empty_response( 403, [ 'Vary' => 'Origin' ] );
		}

		if ( 'OPTIONS' === $method ) {
			return $this->preflight( $headers, $origin );
		}

		$authorization = $authorize();
		$authorization_status = is_array( $authorization ) && isset( $authorization['status'] ) ? (int) $authorization['status'] : 403;
		if ( 200 !== $authorization_status ) {
			return $this->empty_response( $authorization_status, $this->cors_headers( $origin ) );
		}
		$principal = isset( $authorization['principal'] ) && is_string( $authorization['principal'] ) ? $authorization['principal'] : '';
		if ( ! preg_match( '/^[A-Za-z0-9:._-]{1,256}$/D', $principal ) ) {
			return $this->empty_response( 403, $this->cors_headers( $origin ) );
		}

		if ( 'POST' !== $method ) {
			return $this->empty_response( 405, array_merge( $this->cors_headers( $origin ), [ 'Allow' => 'POST, OPTIONS' ] ) );
		}

		if ( ! $this->valid_content_type( $this->header( $headers, 'Content-Type' ) ) ) {
			return $this->empty_response( 415, $this->cors_headers( $origin ) );
		}

		if ( ! $this->valid_accept( $this->header( $headers, 'Accept' ) ) ) {
			return $this->empty_response( 406, $this->cors_headers( $origin ) );
		}

		$content_length = $this->header( $headers, 'Content-Length' );
		if ( null !== $content_length ) {
			if ( ! preg_match( '/^(?:0|[1-9][0-9]*)$/D', $content_length ) ) {
				return $this->rpc_error( 400, null, -32700, 'Parse error: Invalid JSON', $origin, false );
			}
			if ( (float) $content_length > self::MAX_BODY_BYTES ) {
				return $this->empty_response( 413, $this->cors_headers( $origin ) );
			}
		}
		if ( is_callable( $body ) ) {
			$body = $body();
		}
		if ( ! is_string( $body ) ) {
			throw new \RuntimeException( 'MCP body supplier did not return bytes' );
		}

		if ( strlen( $body ) > self::MAX_BODY_BYTES ) {
			return $this->empty_response( 413, $this->cors_headers( $origin ) );
		}

		if ( '' === $body || ! preg_match( '//u', $body ) ) {
			return $this->rpc_error( 400, null, -32700, 'Parse error: Invalid JSON', $origin, false );
		}

		$data = json_decode( $body, false, self::MAX_JSON_DEPTH + 1 );
		if ( JSON_ERROR_NONE !== json_last_error() ) {
			return $this->rpc_error( 400, null, -32700, 'Parse error: Invalid JSON', $origin, false );
		}

		$id = $this->readable_id( $data );
		if ( ! $this->valid_envelope( $data ) ) {
			return $this->rpc_error( 400, $id, -32600, 'Invalid Request', $origin, null !== $id );
		}

		$params = $data->params;
		$version = $this->metadata_version( $params );
		$name = $this->name_authority( $data->method, $params );
		$header_error = $this->standard_header_error( $headers, $data->method, $version, $name );
		if ( null !== $header_error ) {
			return $this->rpc_error( 400, $data->id, -32020, 'Header mismatch: ' . $header_error, $origin );
		}

		if ( self::VERSION !== $version ) {
			return $this->rpc_error(
				400,
				$data->id,
				-32022,
				'Unsupported protocol version',
				$origin,
				true,
				[ 'requested' => $version, 'supported' => [ self::VERSION ] ]
			);
		}

		if ( ! $this->valid_metadata( $params ) ) {
			return $this->rpc_error( 400, $data->id, -32602, 'Invalid request metadata', $origin );
		}

		if ( in_array( $data->method, [ 'server/discover', 'tools/list', 'tools/call' ], true ) ) {
			try {
				$rate = $this->rate_limiter->consume( $principal );
			} catch ( \Throwable $error ) {
				return $this->empty_response( 503, $this->cors_headers( $origin ) );
			}
			if ( ! $rate['accepted'] ) {
				return $this->empty_response( 429, array_merge( $this->cors_headers( $origin ), [ 'Retry-After' => (string) $rate['retry_after'] ] ) );
			}
		}

		switch ( $data->method ) {
			case 'server/discover':
				return $this->rpc_result( $data->id, $this->discovery_result(), $origin );

			case 'tools/list':
				if ( property_exists( $params, 'cursor' ) && ! is_string( $params->cursor ) ) {
					return $this->rpc_error( 200, $data->id, -32602, 'Invalid method parameters', $origin );
				}
				if ( property_exists( $params, 'cursor' ) ) {
					return $this->rpc_error( 200, $data->id, -32602, 'Invalid method parameters', $origin );
				}
				return $this->rpc_result( $data->id, $this->list_result(), $origin );

			case 'tools/call':
				return $this->call_tool( $data->id, $params, $origin );

			default:
				return $this->rpc_error( 404, $data->id, -32601, 'Method not found', $origin );
		}
	}

	private function call_tool( $id, \stdClass $params, string $origin ): array {
		if ( ! property_exists( $params, 'name' ) || ! is_string( $params->name ) ) {
			return $this->rpc_error( 200, $id, -32602, 'Invalid method parameters', $origin );
		}

		if ( ( property_exists( $params, 'arguments' ) && ! $params->arguments instanceof \stdClass ) || property_exists( $params, 'inputResponses' ) || property_exists( $params, 'requestState' ) ) {
			return $this->rpc_error( 200, $id, -32602, 'Invalid method parameters', $origin );
		}

		$tool = $this->tools->get( $params->name );
		if ( null === $tool || ! $tool->visible_to_agent ) {
			return $this->rpc_error( 200, $id, -32602, 'Unknown tool: ' . $params->name, $origin );
		}

		$arguments = property_exists( $params, 'arguments' ) ? $params->arguments : new \stdClass();
		if ( ! $this->tools->valid_input( $params->name, $arguments ) ) {
			return $this->rpc_result( $id, $this->with_server_info( Frontman_Tools::error_result( 'Invalid tool arguments' ) ), $origin );
		}

		$input = $this->tools->sanitize_input( $params->name, $this->object_to_array( $arguments ) );
		try {
			$result = $this->tools->call( $params->name, $input );
		} catch ( \Throwable $error ) {
			$result = Frontman_Tools::error_result( 'Tool execution failed' );
		}
		return $this->rpc_result( $id, $this->with_server_info( $result ), $origin );
	}

	private function discovery_result(): array {
		return [
			'resultType'        => 'complete',
			'supportedVersions' => [ self::VERSION ],
			'capabilities'      => [ 'tools' => [ 'listChanged' => false ] ],
			'_meta'             => [ 'io.modelcontextprotocol/serverInfo' => $this->server_info() ],
			'ttlMs'             => 0,
			'cacheScope'        => 'private',
		];
	}

	private function list_result(): array {
		return [
			'resultType' => 'complete',
			'tools'      => $this->tools->all_definitions(),
			'_meta'      => [ 'io.modelcontextprotocol/serverInfo' => $this->server_info() ],
			'ttlMs'      => 0,
			'cacheScope' => 'private',
		];
	}

	private function server_info(): array {
		return [ 'name' => 'frontman-wordpress', 'version' => FRONTMAN_VERSION ];
	}

	private function with_server_info( array $result ): array {
		$meta = isset( $result['_meta'] ) && is_array( $result['_meta'] ) ? $result['_meta'] : [];
		$meta['io.modelcontextprotocol/serverInfo'] = $this->server_info();
		$result['_meta'] = $meta;
		return $result;
	}

	private function valid_envelope( $data ): bool {
		if ( ! $data instanceof \stdClass || ! property_exists( $data, 'jsonrpc' ) || '2.0' !== $data->jsonrpc || ! property_exists( $data, 'id' ) || null === $this->valid_id( $data->id ) || ! property_exists( $data, 'method' ) || ! is_string( $data->method ) || ! property_exists( $data, 'params' ) || ! $data->params instanceof \stdClass ) {
			return false;
		}
		return ! property_exists( $data, 'result' ) && ! property_exists( $data, 'error' );
	}

	private function readable_id( $data ) {
		if ( ! $data instanceof \stdClass || ! property_exists( $data, 'id' ) ) {
			return null;
		}
		return $this->valid_id( $data->id );
	}

	private function valid_id( $id ) {
		if ( is_string( $id ) ) {
			return $id;
		}
		if ( is_int( $id ) && $id >= -9007199254740991 && $id <= 9007199254740991 ) {
			return $id;
		}
		return null;
	}

	private function metadata_version( \stdClass $params ): ?string {
		if ( ! property_exists( $params, '_meta' ) || ! $params->_meta instanceof \stdClass || ! property_exists( $params->_meta, 'io.modelcontextprotocol/protocolVersion' ) || ! is_string( $params->_meta->{'io.modelcontextprotocol/protocolVersion'} ) ) {
			return null;
		}
		return $params->_meta->{'io.modelcontextprotocol/protocolVersion'};
	}

	private function valid_metadata( \stdClass $params ): bool {
		if ( ! property_exists( $params, '_meta' ) || ! $params->_meta instanceof \stdClass ) {
			return false;
		}
		$meta = $params->_meta;
		$properties = get_object_vars( $meta );
		if ( count( $properties ) > self::MAX_META_KEYS || strlen( (string) wp_json_encode( $meta ) ) > self::MAX_META_BYTES ) {
			return false;
		}
		foreach ( [ 'traceparent', 'tracestate', 'baggage' ] as $reserved ) {
			if ( property_exists( $meta, $reserved ) ) {
				return false;
			}
		}
		foreach ( array_keys( $properties ) as $key ) {
			if ( ! preg_match( '/^(?:[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\/)?(?:[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)?$/D', $key ) ) {
				return false;
			}
		}
		if ( ! property_exists( $meta, 'io.modelcontextprotocol/clientCapabilities' ) || ! $this->valid_client_capabilities( $meta->{'io.modelcontextprotocol/clientCapabilities'} ) ) {
			return false;
		}
		if ( property_exists( $meta, 'io.modelcontextprotocol/clientInfo' ) ) {
			$info = $meta->{'io.modelcontextprotocol/clientInfo'};
			if ( ! $this->valid_implementation( $info ) ) {
				return false;
			}
		}
		if ( property_exists( $meta, 'io.modelcontextprotocol/logLevel' ) && ! in_array( $meta->{'io.modelcontextprotocol/logLevel'}, [ 'alert', 'critical', 'debug', 'emergency', 'error', 'info', 'notice', 'warning' ], true ) ) {
			return false;
		}
		if ( property_exists( $meta, 'progressToken' ) && null === $this->valid_id( $meta->progressToken ) ) {
			return false;
		}
		return true;
	}

	private function valid_implementation( $info ): bool {
		if ( ! $info instanceof \stdClass || ! property_exists( $info, 'name' ) || ! is_string( $info->name ) || ! property_exists( $info, 'version' ) || ! is_string( $info->version ) ) {
			return false;
		}
		foreach ( [ 'title', 'description' ] as $name ) {
			if ( property_exists( $info, $name ) && ! is_string( $info->{$name} ) ) {
				return false;
			}
		}
		if ( property_exists( $info, 'websiteUrl' ) && ( ! is_string( $info->websiteUrl ) || ! $this->valid_uri( $info->websiteUrl ) ) ) {
			return false;
		}
		if ( property_exists( $info, 'icons' ) ) {
			if ( ! is_array( $info->icons ) ) {
				return false;
			}
			foreach ( $info->icons as $icon ) {
				if ( ! $icon instanceof \stdClass || ! property_exists( $icon, 'src' ) || ! is_string( $icon->src ) || ! $this->valid_uri( $icon->src ) ) {
					return false;
				}
				if ( property_exists( $icon, 'mimeType' ) && ! is_string( $icon->mimeType ) ) {
					return false;
				}
				if ( property_exists( $icon, 'theme' ) && ! in_array( $icon->theme, [ 'dark', 'light' ], true ) ) {
					return false;
				}
				if ( property_exists( $icon, 'sizes' ) && ( ! is_array( $icon->sizes ) || count( array_filter( $icon->sizes, 'is_string' ) ) !== count( $icon->sizes ) ) ) {
					return false;
				}
			}
		}
		return true;
	}

	private function valid_uri( string $value ): bool {
		if ( 1 !== preg_match( '/^[A-Za-z][A-Za-z0-9+.-]*:[^\x00-\x20\x7F]*$/D', $value ) ) {
			return false;
		}
		$parts = parse_url( $value );
		return is_array( $parts ) && isset( $parts['scheme'] );
	}

	private function valid_client_capabilities( $capabilities ): bool {
		if ( ! $capabilities instanceof \stdClass ) {
			return false;
		}
		foreach ( [ 'roots' ] as $name ) {
			if ( property_exists( $capabilities, $name ) && ! $capabilities->{$name} instanceof \stdClass ) {
				return false;
			}
		}
		foreach ( [ 'elicitation' => [ 'form', 'url' ], 'sampling' => [ 'context', 'tools' ] ] as $name => $fields ) {
			if ( ! property_exists( $capabilities, $name ) ) {
				continue;
			}
			$value = $capabilities->{$name};
			if ( ! $value instanceof \stdClass ) {
				return false;
			}
			foreach ( $fields as $field ) {
				if ( property_exists( $value, $field ) && ! $value->{$field} instanceof \stdClass ) {
					return false;
				}
			}
		}
		foreach ( [ 'experimental', 'extensions' ] as $name ) {
			if ( ! property_exists( $capabilities, $name ) ) {
				continue;
			}
			$value = $capabilities->{$name};
			if ( ! $value instanceof \stdClass ) {
				return false;
			}
			foreach ( get_object_vars( $value ) as $key => $settings ) {
				if ( ! $settings instanceof \stdClass || ( 'extensions' === $name && ( false === strpos( $key, '/' ) || ! preg_match( '/^(?:[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\/)(?:[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)$/D', $key ) ) ) ) {
					return false;
				}
			}
		}
		return true;
	}

	private function name_authority( string $method, \stdClass $params ) {
		switch ( $method ) {
			case 'tools/call':
			case 'prompts/get':
				return property_exists( $params, 'name' ) ? $params->name : null;

			case 'resources/read':
				return property_exists( $params, 'uri' ) ? $params->uri : null;

			default:
				return null;
		}
	}

	private function standard_header_error( array $headers, string $method, ?string $version, $name ): ?string {
		$required = [ 'MCP-Protocol-Version', 'Mcp-Method' ];
		$named_method = in_array( $method, [ 'tools/call', 'prompts/get', 'resources/read' ], true );
		if ( $named_method ) {
			$required[] = 'Mcp-Name';
		}
		foreach ( $required as $header ) {
			if ( null === $this->header( $headers, $header ) ) {
				return $header;
			}
		}
		if ( $this->header( $headers, 'MCP-Protocol-Version' ) !== $version ) {
			return 'MCP-Protocol-Version';
		}
		if ( $this->header( $headers, 'Mcp-Method' ) !== $method ) {
			return 'Mcp-Method';
		}
		$header_name = $this->header( $headers, 'Mcp-Name' );
		if ( null !== $header_name ) {
			$decoded = $this->decode_header_value( $header_name );
			if ( null === $decoded ) {
				return 'Mcp-Name';
			}
			$header_name = $decoded;
		}
		if ( $named_method ) {
			if ( ! is_string( $name ) || $header_name !== $name ) {
				return 'Mcp-Name';
			}
		} elseif ( null !== $header_name ) {
			return 'Mcp-Name';
		}
		return null;
	}

	private function preflight( array $headers, string $origin ): array {
		$vary = 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers';
		$response_headers = [ 'Access-Control-Allow-Origin' => $origin, 'Vary' => $vary ];
		if ( 'POST' !== $this->header( $headers, 'Access-Control-Request-Method' ) ) {
			return $this->empty_response( 400, $response_headers );
		}

		$requested = $this->header( $headers, 'Access-Control-Request-Headers' );
		$accepted = [];
		if ( null !== $requested && '' !== trim( $requested ) ) {
			foreach ( explode( ',', $requested ) as $header ) {
				$header = trim( $header );
				$lower = strtolower( $header );
				if ( '' === $header || ( ! in_array( $lower, [ 'content-type', 'authorization', 'mcp-protocol-version', 'mcp-method', 'mcp-name', 'x-wp-nonce' ], true ) && 0 !== strpos( $lower, 'mcp-param-' ) ) ) {
					return $this->empty_response( 400, $response_headers );
				}
				$accepted[] = $header;
			}
		}

		$response_headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS';
		if ( [] !== $accepted ) {
			$response_headers['Access-Control-Allow-Headers'] = implode( ', ', $accepted );
		}
		return $this->empty_response( 204, $response_headers );
	}

	private function valid_content_type( ?string $value ): bool {
		if ( null === $value ) {
			return false;
		}
		$parts = explode( ';', strtolower( trim( $value ) ) );
		return 'application/json' === trim( $parts[0] ) && ( 1 === count( $parts ) || ( 2 === count( $parts ) && 'charset=utf-8' === trim( $parts[1] ) ) );
	}

	private function valid_accept( ?string $value ): bool {
		if ( null === $value || false !== strpos( $value, '"' ) ) {
			return false;
		}
		$available = [];
		foreach ( explode( ',', $value ) as $range ) {
			$parts = explode( ';', strtolower( trim( $range ) ) );
			$media = trim( $parts[0] );
			if ( ! in_array( $media, [ 'application/json', 'text/event-stream' ], true ) || count( $parts ) > 2 ) {
				continue;
			}
			if ( 2 === count( $parts ) ) {
				$parameter = trim( $parts[1] );
				if ( ! preg_match( '/^q=(?:0(?:\.[0-9]{0,3})?|1(?:\.0{0,3})?)$/D', $parameter ) || (float) substr( $parameter, 2 ) <= 0 ) {
					continue;
				}
			}
			$available[ $media ] = true;
		}
		return isset( $available['application/json'], $available['text/event-stream'] );
	}

	private function decode_header_value( string $value ): ?string {
		if ( 0 === strpos( $value, '=?base64?' ) && substr( $value, -2 ) === '?=' ) {
			$encoded = substr( $value, 9, -2 );
			$decoded = base64_decode( $encoded, true );
			if ( ! is_string( $decoded ) || base64_encode( $decoded ) !== $encoded || ! preg_match( '//u', $decoded ) ) {
				return null;
			}
			return $decoded;
		}
		return preg_match( '/^[\x21-\x7E](?:[\x20-\x7E]*[\x21-\x7E])?$/D', $value ) ? $value : null;
	}

	private function object_to_array( $value ) {
		if ( $value instanceof \stdClass ) {
			$result = [];
			foreach ( get_object_vars( $value ) as $key => $item ) {
				$result[ $key ] = $this->object_to_array( $item );
			}
			return $result;
		}
		if ( is_array( $value ) ) {
			return array_map( [ $this, 'object_to_array' ], $value );
		}
		return $value;
	}

	private function canonical_origin( string $value ): ?string {
		if ( ! preg_match( '~^(https?)://([^/?#@]+)$~Di', $value, $matches ) ) {
			return null;
		}
		$parts = parse_url( $value );
		if ( ! is_array( $parts ) || ! isset( $parts['scheme'], $parts['host'] ) || substr( $parts['host'], -1 ) === '.' ) {
			return null;
		}
		$scheme = strtolower( $parts['scheme'] );
		$host = strtolower( $parts['host'] );
		$port = $parts['port'] ?? null;
		if ( ( 'http' === $scheme && 80 === $port ) || ( 'https' === $scheme && 443 === $port ) ) {
			$port = null;
		}
		return $scheme . '://' . $host . ( null === $port ? '' : ':' . $port );
	}

	private function validated_origin( ?string $value ): ?string {
		if ( null === $value ) {
			return null;
		}
		$origin = $this->canonical_origin( $value );
		return $origin === $this->allowed_origin ? $origin : null;
	}

	private function header( array $headers, string $name ): ?string {
		foreach ( $headers as $header_name => $value ) {
			if ( 0 === strcasecmp( (string) $header_name, $name ) ) {
				return is_string( $value ) ? $value : null;
			}
		}
		return null;
	}

	private function cors_headers( string $origin ): array {
		return [ 'Access-Control-Allow-Origin' => $origin, 'Vary' => 'Origin' ];
	}

	private function empty_response( int $status, array $headers ): array {
		return [ 'status' => $status, 'headers' => $headers, 'body' => '' ];
	}

	private function rpc_result( $id, array $result, string $origin ): array {
		return $this->json_response( 200, [ 'jsonrpc' => '2.0', 'id' => $id, 'result' => $result ], $origin );
	}

	private function rpc_error( int $status, $id, int $code, string $message, string $origin, bool $include_id = true, ?array $data = null ): array {
		$payload = [ 'jsonrpc' => '2.0' ];
		if ( $include_id ) {
			$payload['id'] = $id;
		}
		$payload['error'] = [ 'code' => $code, 'message' => $message ];
		if ( null !== $data ) {
			$payload['error']['data'] = $data;
		}
		return $this->json_response( $status, $payload, $origin );
	}

	private function json_response( int $status, array $payload, string $origin ): array {
		$body = wp_json_encode( $payload, JSON_UNESCAPED_SLASHES );
		if ( ! is_string( $body ) ) {
			throw new \RuntimeException( 'Failed to serialize MCP response' );
		}
		return [
			'status'  => $status,
			'headers' => array_merge( $this->cors_headers( $origin ), [ 'Content-Type' => 'application/json' ] ),
			'body'    => $body,
		];
	}
}
