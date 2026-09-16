<?php
/**
 * Provider-neutral SEO tools for the tested Yoast route.
 * @package Frontman
 */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Seo {
	private const YOAST = 'wordpress-seo/wp-seo.php';
	private const META = [ 'title' => '_yoast_wpseo_title', 'description' => '_yoast_wpseo_metadesc' ];
	public function register( Frontman_Tools $tools ): void {
		$schema = [
			'type'                 => 'object',
			'additionalProperties' => false,
			'properties'           => [ 'id' => [ 'type' => 'integer', 'description' => 'Post, page, or custom post type ID.' ] ],
			'required'             => [ 'id' ],
		];
		$tools->add( new Frontman_Tool_Definition(
			'wp_read_seo',
			'Reads stored SEO title and description overrides for an editable post.',
			$schema,
			[ $this, 'read_seo' ],
			'read'
		) );
		$schema['properties'] += [
			'title'       => [ 'type' => 'string', 'description' => 'SEO title override.' ],
			'description' => [ 'type' => 'string', 'description' => 'SEO description override.' ],
		];
		$tools->add( new Frontman_Tool_Definition(
			'wp_update_seo',
			'Updates SEO overrides. Omitted fields stay unchanged; empty strings restore provider defaults.',
			$schema,
			[ $this, 'update_seo' ],
			'read-write'
		) );
	}
	public static function is_available(): bool {
		global $wp_version;
		if ( ! Frontman_Plugin_Dependencies::is_available( self::YOAST )
			|| Frontman_Plugin_Dependencies::is_available( 'wordpress-seo-premium/wp-seo-premium.php' )
			|| Frontman_Plugin_Dependencies::is_available( 'seo-by-rank-math/rank-math.php', 'RankMath' )
			|| Frontman_Plugin_Dependencies::is_available( 'all-in-one-seo-pack/all_in_one_seo_pack.php' ) || function_exists( 'aioseo' )
			|| Frontman_Plugin_Dependencies::is_available( 'all-in-one-seo-pack-pro/all_in_one_seo_pack.php' )
			|| Frontman_Plugin_Dependencies::is_available( 'autodescription/autodescription.php' ) || defined( 'THE_SEO_FRAMEWORK_VERSION' )
			|| ! defined( 'WPSEO_VERSION' ) || '28.4' !== WPSEO_VERSION
			|| ! isset( $wp_version ) || version_compare( (string) $wp_version, '6.9', '<' )
			|| did_action( 'wpseo_loaded' ) < 1 || ! function_exists( 'sanitize_meta' ) ) {
			return false;
		}
		foreach ( [ 'get_value', 'set_value', 'delete', 'sanitize_post_meta' ] as $method ) {
			if ( ! is_callable( [ 'WPSEO_Meta', $method ] ) ) {
				return false;
			}
		}
		$registered = get_registered_meta_keys( 'post' );
		foreach ( self::META as $meta_key ) {
			if ( ! is_callable( $registered[ $meta_key ]['sanitize_callback'] ?? null )
				|| false === has_filter( 'sanitize_post_meta_' . $meta_key, [ 'WPSEO_Meta', 'sanitize_post_meta' ] ) ) {
				return false;
			}
		}
		return true;
	}
	public static function validate_input( string $tool, array $input ): array {
		$allowed = 'wp_read_seo' === $tool ? [ 'id' ] : [ 'id', 'title', 'description' ];
		if ( ! in_array( $tool, [ 'wp_read_seo', 'wp_update_seo' ], true ) || array_diff( array_keys( $input ), $allowed ) ) {
			throw new Frontman_Tool_Error( __( 'Invalid SEO tool input.', 'frontman-agentic-ai-editor' ) );
		}
		if ( ! isset( $input['id'] ) || ! is_int( $input['id'] ) || $input['id'] < 1 ) {
			throw new Frontman_Tool_Error( __( 'id must be a positive integer.', 'frontman-agentic-ai-editor' ) );
		}
		foreach ( [ 'title', 'description' ] as $field ) {
			if ( array_key_exists( $field, $input ) && ( ! is_string( $input[ $field ] ) || 1 !== preg_match( '//u', $input[ $field ] ) ) ) {
				throw new Frontman_Tool_Error( __( 'SEO values must be valid UTF-8 strings.', 'frontman-agentic-ai-editor' ) );
			}
		}
		if ( 'wp_update_seo' === $tool && ! array_key_exists( 'title', $input ) && ! array_key_exists( 'description', $input ) ) {
			throw new Frontman_Tool_Error( __( 'Provide title or description.', 'frontman-agentic-ai-editor' ) );
		}
		return $input;
	}
	public function read_seo( array $input ): array {
		$input = self::validate_input( 'wp_read_seo', $input );
		$this->guard( $input['id'] );
		return [ 'id' => $input['id'], 'provider' => 'yoast' ] + $this->snapshot( $input['id'] );
	}
	public function update_seo( array $input ): array {
		$input     = self::validate_input( 'wp_update_seo', $input );
		$post_type = $this->guard( $input['id'] );
		$before    = $this->snapshot( $input['id'] );
		$expected  = [];
		try {
			foreach ( self::META as $field => $meta_key ) {
				if ( array_key_exists( $field, $input ) ) {
					$expected[ $field ] = '' === $input[ $field ] ? '' : sanitize_meta( $meta_key, $input[ $field ], 'post', $post_type );
					if ( ! is_string( $expected[ $field ] ) || 1 !== preg_match( '//u', $expected[ $field ] ) ) {
						throw new \UnexpectedValueException();
					}
				}
			}
		} catch ( \Throwable $error ) {
			throw new Frontman_Tool_Error( __( 'Yoast could not sanitize the SEO value.', 'frontman-agentic-ai-editor' ) );
		}
		$wanted = array_replace( $before, $expected );
		$after  = $before;
		foreach ( self::META as $field => $meta_key ) {
			if ( ! array_key_exists( $field, $expected ) ) {
				continue;
			}
			$key = 'description' === $field ? 'metadesc' : 'title';
			try {
				if ( '' === $input[ $field ] ) {
					\WPSEO_Meta::delete( $key, $input['id'] );
				} else {
					\WPSEO_Meta::set_value( $key, $input[ $field ], $input['id'] );
				}
				$after = $this->snapshot( $input['id'] );
			} catch ( \Throwable $error ) {
				$this->persistence_error( $input['id'], $before, $wanted );
			}
			if ( $after[ $field ] !== $expected[ $field ] ) {
				$this->persistence_error( $input['id'], $before, $wanted );
			}
		}
		try {
			$after = $this->snapshot( $input['id'] );
		} catch ( \Throwable $error ) {
			$this->persistence_error( $input['id'], $before, $wanted );
		}
		if ( $after !== $wanted ) {
			$this->persistence_error( $input['id'], $before, $wanted );
		}
		return [
			'id' => $input['id'], 'provider' => 'yoast',
			'before' => $before, 'after' => $after, 'changed' => $before !== $after,
		];
	}
	private function guard( int $id ): string {
		if ( defined( 'WPSEO_VERSION' ) && '28.4' !== WPSEO_VERSION ) {
			throw new Frontman_Tool_Error( sprintf(
				/** translators: %s: installed Yoast SEO version. */
				__( 'Unsupported Yoast SEO version %s; expected 28.4.', 'frontman-agentic-ai-editor' ),
				(string) WPSEO_VERSION
			) );
		}
		if ( ! self::is_available() ) {
			throw new Frontman_Tool_Error( __( 'Yoast SEO Free 28.4 is unavailable or conflicts with another SEO plugin.', 'frontman-agentic-ai-editor' ) );
		}
		$post = get_post( $id );
		$type = $post ? get_post_type_object( $post->post_type ) : null;
		if ( ! $post || wp_is_post_revision( $id ) || wp_is_post_autosave( $id )
			|| ( ! in_array( $post->post_type, [ 'post', 'page' ], true )
				&& ( 'attachment' === $post->post_type || ! $type || ! empty( $type->_builtin ) || empty( $type->show_ui ) ) ) ) {
			throw new Frontman_Tool_Error( __( 'SEO overrides are not available for this object.', 'frontman-agentic-ai-editor' ) );
		}
		if ( ! current_user_can( 'edit_post', $id ) ) {
			throw new Frontman_Tool_Error( __( 'You cannot edit this post.', 'frontman-agentic-ai-editor' ) );
		}
		foreach ( self::META as $meta_key ) {
			if ( ! current_user_can( 'edit_post_meta', $id, $meta_key ) ) {
				throw new Frontman_Tool_Error( __( 'You cannot edit this post SEO metadata.', 'frontman-agentic-ai-editor' ) );
			}
		}
		return $post->post_type;
	}
	private function snapshot( int $id ): array {
		try {
			$title       = \WPSEO_Meta::get_value( 'title', $id );
			$description = \WPSEO_Meta::get_value( 'metadesc', $id );
		} catch ( \Throwable $error ) {
			throw new Frontman_Tool_Error( __( 'Yoast could not read the stored SEO overrides.', 'frontman-agentic-ai-editor' ) );
		}
		if ( ! is_string( $title ) || ! is_string( $description )
			|| 1 !== preg_match( '//u', $title ) || 1 !== preg_match( '//u', $description ) ) {
			throw new Frontman_Tool_Error( __( 'Yoast returned invalid SEO overrides.', 'frontman-agentic-ai-editor' ) );
		}
		return [ 'title' => $title, 'description' => $description ];
	}
	private function persistence_error( int $id, array $before, array $wanted ): void {
		try {
			$actual = $this->snapshot( $id );
			$status = $actual === $before ? 'failed' : 'partial';
		} catch ( \Throwable $error ) {
			$actual = null;
			$status = 'uncertain';
		}
		$state = wp_json_encode( [
			'id' => $id, 'provider' => 'yoast', 'status' => $status,
			'before' => $before, 'expectedAfter' => $wanted, 'actualAfter' => $actual,
		] );
		throw new Frontman_Tool_Error( __( 'SEO update failed. Update state: ', 'frontman-agentic-ai-editor' ) . $state );
	}
}
