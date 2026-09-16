<?php
/**
 * Narrow URL retirement tools backed by the Redirection plugin's REST API.
 *
 * @package Frontman
 */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Redirection {
	public static function is_available(): bool {
		return Frontman_Plugin_Dependencies::is_available( 'redirection/redirection.php' );
	}

	public function register( Frontman_Tools $tools ): void {
		$path = [ 'type' => 'string', 'description' => 'Literal site-root path, e.g. /team/. ASCII letters, digits, slash, dot, underscore, hyphen and tilde only. No query, fragment, encoding, wildcard or dot segments.' ];
		$confirm = [ 'type' => 'boolean', 'description' => 'Must be true after user approval.' ];
		$definitions = [
			'wp_list_redirects' => [
				'Lists Redirection rules and enabled WordPress groups. Page is zero-based; each page contains up to 100 rules and 100 groups. Optional source filters source URLs by substring. Inspect existing rules before creating one, including regex rules that may overlap.',
				[ 'page' => [ 'type' => 'integer', 'minimum' => 0 ], 'source' => $path ], [], 'list_redirects', 'read',
			],
			'wp_create_redirect' => [
				'Creates one literal-path Redirection rule: 301/302 to a same-site target path, or 404/410 without a target. Requires an enabled WordPress group ID from wp_list_redirects and confirm=true. Matches both trailing-slash variants, case-sensitively; ignores and drops query strings. Does not cover child paths (pagination, feeds, individual CPT entries), disable CPT archives, or edit PHP. Rejects duplicate literal sources and direct self-redirects, but does not detect redirect chains or regex overlap. Verify the public HTTP result and clear relevant caches afterward. Never retry a failed write blindly; list rules first.',
				[ 'source' => $path, 'target' => $path, 'code' => [ 'type' => 'integer', 'enum' => [ 301, 302, 404, 410 ] ], 'group_id' => [ 'type' => 'integer', 'minimum' => 1 ], 'confirm' => $confirm ],
				[ 'source', 'code', 'group_id', 'confirm' ], 'create_redirect', 'read-write',
			],
			'wp_delete_redirect' => [
				'Deletes one Redirection rule by ID after user approval (confirm=true). Supply its exact source URL from wp_list_redirects as expected_source to guard against deleting the wrong rule. Returns the deleted rule for reference.',
				[ 'id' => [ 'type' => 'integer', 'minimum' => 1 ], 'expected_source' => [ 'type' => 'string' ], 'confirm' => $confirm ],
				[ 'id', 'expected_source', 'confirm' ], 'delete_redirect', 'read-write',
			],
		];
		foreach ( $definitions as $name => [ $description, $properties, $required, $handler, $access ] ) {
			$tools->add( new Frontman_Tool_Definition(
				$name, $description,
				[ 'type' => 'object', 'additionalProperties' => false, 'properties' => $properties, 'required' => $required ],
				[ $this, $handler ], $access, true, true
			) );
		}
	}

	private function request( string $method, string $route, array $params = [] ): array {
		if ( ! self::is_available() || ! current_user_can( 'manage_options' ) ) {
			throw new Frontman_Tool_Error( 'Redirection must be active and the user must have manage_options permission.' );
		}
		$request = new WP_REST_Request( $method, '/redirection/v1/' . $route );
		if ( 'GET' === $method ) {
			$request->set_query_params( $params );
		} else {
			$request->set_body_params( $params );
		}
		$response = rest_do_request( $request );
		$data = $response->get_data();
		if ( $response->is_error() ) {
			throw new Frontman_Tool_Error( 'Redirection: ' . ( $data['message'] ?? 'API request failed.' ) );
		}
		if ( ! is_array( $data ) ) {
			throw new Frontman_Tool_Error( 'Unexpected Redirection API response. Inspect rules before retrying.' );
		}
		return $data;
	}

	private function path( $value ): string {
		if ( ! is_string( $value ) || strlen( $value ) > 2000 || ! preg_match( '~^/[a-zA-Z0-9/._\x7e-]*$~D', $value )
			|| strpos( $value, '//' ) !== false || preg_match( '~(?:^|/)\.{1,2}(?:/|$)~', $value ) ) {
			throw new Frontman_Tool_Error( 'Use a literal site-root ASCII path without query, fragment, encoding, wildcard or dot segments.' );
		}
		return $value;
	}

	private function positive_id( $value ): int {
		if ( ! is_int( $value ) || $value < 1 ) {
			throw new Frontman_Tool_Error( 'ID must be a positive integer.' );
		}
		return $value;
	}

	private function confirm( array $input ): void {
		if ( true !== ( $input['confirm'] ?? null ) ) {
			throw new Frontman_Tool_Error( 'User approval and confirm=true are required.' );
		}
	}

	private function groups( int $page ): array {
		return $this->request( 'GET', 'group', [ 'page' => $page, 'per_page' => 100, 'filterBy' => [ 'module' => '1', 'status' => 'enabled' ] ] );
	}

	public function list_redirects( array $input ): array {
		$page = $input['page'] ?? 0;
		if ( ! is_int( $page ) || $page < 0 ) {
			throw new Frontman_Tool_Error( 'page must be a non-negative integer.' );
		}
		$params = [ 'page' => $page, 'per_page' => 100 ];
		if ( array_key_exists( 'source', $input ) ) {
			$params['filterBy'] = [ 'url' => rtrim( $this->path( $input['source'] ), '/' ) ];
		}
		return [ 'page' => $page, 'redirects' => $this->request( 'GET', 'redirect', $params ), 'groups' => $this->groups( $page ) ];
	}

	/** Read candidate literal sources across all pages, including disabled rules. */
	private function source_rules( string $source ): array {
		$items = [];
		$page = 0;
		do {
			$data = $this->request( 'GET', 'redirect', [ 'page' => $page++, 'per_page' => 100, 'filterBy' => [ 'url' => rtrim( $source, '/' ) ] ] );
			foreach ( $data['items'] as $item ) {
				if ( ! $item['regex'] && strtolower( rtrim( $item['url'], '/' ) ) === strtolower( rtrim( $source, '/' ) ) ) {
					$items[] = $item;
				}
			}
		} while ( $page * 100 < $data['total'] );
		return $items;
	}

	public function create_redirect( array $input ): array {
		$this->confirm( $input );
		$source = $this->path( $input['source'] ?? null );
		$group_id = $this->positive_id( $input['group_id'] ?? null );
		$code = $input['code'] ?? null;
		if ( '/' === $source || ! in_array( $code, [ 301, 302, 404, 410 ], true ) ) {
			throw new Frontman_Tool_Error( 'Source cannot be the site root; code must be 301, 302, 404 or 410.' );
		}
		$target = '';
		if ( in_array( $code, [ 301, 302 ], true ) ) {
			$target = $this->path( $input['target'] ?? null );
			if ( strtolower( rtrim( $source, '/' ) ) === strtolower( rtrim( $target, '/' ) ) ) {
				throw new Frontman_Tool_Error( 'Source and target must differ, including trailing-slash variants.' );
			}
		} elseif ( array_key_exists( 'target', $input ) ) {
			throw new Frontman_Tool_Error( '404/410 rules must not include a target.' );
		}
		$found = false;
		$page = 0;
		do {
			$groups = $this->groups( $page++ );
			foreach ( $groups['items'] as $group ) {
				$found = $found || $group['id'] === $group_id;
			}
		} while ( ! $found && $page * 100 < $groups['total'] );
		if ( ! $found ) {
			throw new Frontman_Tool_Error( 'Choose an enabled WordPress group from wp_list_redirects.' );
		}
		if ( $this->source_rules( $source ) ) {
			throw new Frontman_Tool_Error( 'A rule already exists for this source. Inspect it instead of creating a duplicate.' );
		}
		/** ponytail: best-effort duplicate check, not atomic; add locking if concurrent rule creation becomes common. */
		$this->request( 'POST', 'redirect', [
			'url' => $source, 'group_id' => $group_id, 'match_type' => 'url',
			'action_type' => $target === '' ? 'error' : 'url', 'action_code' => $code,
			'action_data' => [ 'url' => $target ],
			'match_data' => [ 'source' => [ 'flag_regex' => false, 'flag_trailing' => true, 'flag_case' => false, 'flag_query' => 'ignore' ] ],
		] );
		$after = $this->source_rules( $source );
		if ( count( $after ) !== 1 || $after[0]['action_code'] !== $code || $after[0]['group_id'] !== $group_id
			|| ! $after[0]['enabled'] || $after[0]['action_type'] !== ( $target === '' ? 'error' : 'url' )
			|| ( $target !== '' && $after[0]['action_data']['url'] !== $target ) ) {
			throw new Frontman_Tool_Error( 'Could not verify the saved rule. Inspect wp_list_redirects before retrying.' );
		}
		return [ 'before' => null, 'after' => $after[0] ];
	}

	public function delete_redirect( array $input ): array {
		$this->confirm( $input );
		$id = $this->positive_id( $input['id'] ?? null );
		$params = [ 'filterBy' => [ 'id' => (string) $id ] ];
		$before = $this->request( 'GET', 'redirect', $params );
		if ( count( $before['items'] ) !== 1 || ( $input['expected_source'] ?? null ) !== $before['items'][0]['url'] ) {
			throw new Frontman_Tool_Error( 'Rule not found or source changed. Read wp_list_redirects before deleting.' );
		}
		$this->request( 'POST', 'bulk/redirect/delete', [ 'items' => [ $id ], 'global' => false ] );
		$after = $this->request( 'GET', 'redirect', $params );
		if ( $after['total'] !== 0 ) {
			throw new Frontman_Tool_Error( 'Rule deletion did not persist. Inspect wp_list_redirects before retrying.' );
		}
		return [ 'before' => $before['items'][0], 'after' => null ];
	}
}
