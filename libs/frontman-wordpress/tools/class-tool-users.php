<?php
/**
 * Bounded, read-only current-site author account lookup.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Users {
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_find_users',
			'Find candidate accounts only for a user-requested author task, not bulk background discovery. Distinguish login from display name and consider remaining pages. If identity is ambiguous, ask which account; never choose the first result or guess IDs. Candidates are not proof of assignment eligibility. After assigning an author with wp_create_post or wp_update_post, read back with wp_read_post.',
			[
				'type' => 'object',
				'additionalProperties' => false,
				'properties' => [
					'search' => [
						'type' => 'string', 'minLength' => 1, 'maxLength' => 100,
						'description' => 'Trimmed nonempty literal substring, at most 100 Unicode characters. Must not start or end with * after whitespace trimming (including asterisk-only input). Interior *, %, _, and quotes are literal. Case sensitivity depends on database collation.',
					],
					'match_by' => [ 'type' => 'string', 'enum' => [ 'login', 'display_name' ], 'description' => 'Search only this column; never implicitly search email.' ],
					'page' => [ 'type' => 'integer', 'minimum' => 1, 'default' => 1 ],
					'per_page' => [ 'type' => 'integer', 'minimum' => 1, 'maximum' => 20, 'default' => 20 ],
				],
				'required' => [ 'search', 'match_by' ],
			],
			[ $this, 'find_users' ],
			'read'
		) );
	}

	/** Shared by the raw registry boundary and direct calls; no schema coercion. */
	public static function validate_input( array $input ): array {
		if ( array_diff( array_keys( $input ), [ 'search', 'match_by', 'page', 'per_page' ] ) ) {
			throw new Frontman_Tool_Error( 'Unexpected account lookup field.' );
		}
		if ( ! isset( $input['search'] ) || ! is_string( $input['search'] ) ) {
			throw new Frontman_Tool_Error( 'search must be a nonempty string of at most 100 Unicode characters.' );
		}
		$search = preg_replace( '/\A\s+|\s+\z/u', '', $input['search'] );
		if ( null === $search || 1 !== preg_match( '/\A.{1,100}\z/us', $search ) ) {
			throw new Frontman_Tool_Error( 'search must be a nonempty string of at most 100 Unicode characters.' );
		}
		if ( '*' === $search[0] || '*' === substr( $search, -1 ) ) {
			throw new Frontman_Tool_Error( 'search must not start or end with * after trimming whitespace; use a more specific name or login.' );
		}
		if ( ! isset( $input['match_by'] ) || ! in_array( $input['match_by'], [ 'login', 'display_name' ], true ) ) {
			throw new Frontman_Tool_Error( 'match_by must be login or display_name.' );
		}
		foreach ( [ 'page' => 1, 'per_page' => 20 ] as $field => $default ) {
			if ( ! array_key_exists( $field, $input ) ) {
				$input[ $field ] = $default;
			}
			if ( ! is_int( $input[ $field ] ) || $input[ $field ] < 1 || ( 'per_page' === $field && $input[ $field ] > 20 ) ) {
				throw new Frontman_Tool_Error( 'page must be a positive integer and per_page an integer from 1 to 20.' );
			}
		}
		if ( $input['page'] - 1 > intdiv( PHP_INT_MAX, $input['per_page'] ) ) {
			throw new Frontman_Tool_Error( 'page is too large for the requested per_page.' );
		}
		$input['search'] = $search;
		return $input;
	}

	public function find_users( array $input ): array {
		$input = self::validate_input( $input );
		if ( ! current_user_can( 'manage_options' ) || ! current_user_can( 'list_users' ) ) {
			throw new Frontman_Tool_Error( 'Account lookup requires manage_options and list_users.' );
		}
		$query = new \WP_User_Query( [
			'blog_id' => get_current_blog_id(),
			'search' => '*' . $input['search'] . '*',
			'search_columns' => [ 'login' === $input['match_by'] ? 'user_login' : 'display_name' ],
			'number' => $input['per_page'],
			'paged' => $input['page'],
			'orderby' => 'ID', 'order' => 'ASC', 'count_total' => true,
			'fields' => [ 'ID', 'user_login', 'display_name' ],
		] );
		$users = [];
		foreach ( $query->get_results() as $user ) {
			$users[] = [ 'id' => (int) $user->ID, 'login' => $user->user_login, 'display_name' => $user->display_name ];
		}
		$total = (int) $query->get_total();
		return [
			'users' => $users, 'page' => $input['page'], 'per_page' => $input['per_page'],
			'total' => $total, 'total_pages' => (int) ceil( $total / $input['per_page'] ),
		];
	}
}
