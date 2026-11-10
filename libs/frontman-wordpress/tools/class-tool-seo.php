<?php
/**
 * Stored SEO inspection and runtime-validated Yoast updates.
 * @package Frontman
 */

declare(strict_types=1);

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Seo {
	private const YOAST = 'wordpress-seo/wp-seo.php';
	private const SURERANK = 'surerank/surerank.php';
	private const META = [ 'title' => 'title', 'description' => 'metadesc', 'focus_keyphrase' => 'focuskw' ];
	private const SURERANK_META = [
		'title' => 'surerank_settings_page_title',
		'description' => 'surerank_settings_page_description',
		'focus_keyphrase' => 'surerank_settings_focus_keyword',
	];
	public const ARCHIVE_TOOLS = [
		'wp_read_term_seo', 'wp_update_term_seo',
		'wp_read_post_type_archive_seo', 'wp_update_post_type_archive_seo',
	];
	public function register( Frontman_Tools $tools ): void {
		$this->register_archive_tools( $tools );
		if ( null !== self::read_unavailable_reason() ) {
			return;
		}
		$schema = [
			'type'                 => 'object',
			'additionalProperties' => false,
			'properties'           => [ 'id' => [ 'type' => 'integer', 'minimum' => 1, 'description' => 'Post, page, or custom post type ID.' ] ],
			'required'             => [ 'id' ],
		];
		$tools->add( new Frontman_Tool_Definition(
			'wp_read_seo',
			'Reads stored SEO title, description, and focus keyphrase for an editable post, not computed tags.',
			$schema,
			[ $this, 'read_seo' ],
			new Frontman_Tool_Annotations( true, false, false, true ), 'read'
		) );
		if ( null !== self::unavailable_reason() ) {
			return;
		}
		$schema['properties'] += [
			'title'       => [ 'type' => 'string', 'description' => 'SEO title override.' ],
			'description' => [ 'type' => 'string', 'description' => 'SEO description override.' ],
			'focus_keyphrase' => [ 'type' => 'string', 'description' => 'Single Yoast focus keyphrase, not secondary keywords.' ],
		];
		$tools->add( new Frontman_Tool_Definition(
			'wp_update_seo',
			'Updates SEO overrides or the focus keyphrase. Provide at least one of title, description, or focus_keyphrase. Omitted fields stay unchanged; empty strings restore provider defaults.',
			$schema,
			[ $this, 'update_seo' ],
			new Frontman_Tool_Annotations( false, true, true, false ), 'read-write'
		) );
	}
	public static function read_unavailable_reason(): ?string {
		return self::compatibility_reason( false );
	}
	public static function unavailable_reason(): ?string {
		return self::compatibility_reason( true );
	}
	public static function capabilities(): array {
		$read_reason = self::read_unavailable_reason();
		$write_reason = self::unavailable_reason();
		$targets = [];
		foreach ( [ 'term', 'post_type_archive' ] as $target ) {
			$read = self::archive_unavailable_reason( $target );
			$write = self::archive_unavailable_reason( $target, true );
			$targets[ $target ] = [ 'read' => null === $read, 'write' => null === $write, 'read_unavailable_reason' => $read, 'write_unavailable_reason' => $write ];
		}
		return [
			'provider' => null === $read_reason ? self::provider() : null,
			'read' => null === $read_reason,
			'write' => null === $write_reason,
			'supported_fields' => null === $read_reason ? array_keys( self::META ) : [],
			'read_unavailable_reason' => $read_reason,
			'write_unavailable_reason' => $write_reason,
			'targets' => $targets,
		];
	}
	private static function provider(): string {
		return Frontman_Plugin_Dependencies::is_available( self::SURERANK ) ? 'surerank' : 'yoast';
	}
	private static function compatibility_reason( bool $write, string $target = 'post' ): ?string {
		global $wp_version;
		$yoast = Frontman_Plugin_Dependencies::is_available( self::YOAST );
		$surerank = Frontman_Plugin_Dependencies::is_available( self::SURERANK );
		if ( ! $yoast && ! $surerank ) {
			return __( 'Yoast SEO Free and SureRank are absent or not loaded.', 'frontman-agentic-ai-editor' );
		}
		if ( ( $yoast && $surerank )
			|| Frontman_Plugin_Dependencies::is_available( 'wordpress-seo-premium/wp-seo-premium.php' )
			|| Frontman_Plugin_Dependencies::is_available( 'seo-by-rank-math/rank-math.php', 'RankMath' )
			|| Frontman_Plugin_Dependencies::is_available( 'all-in-one-seo-pack/all_in_one_seo_pack.php' ) || function_exists( 'aioseo' )
			|| Frontman_Plugin_Dependencies::is_available( 'all-in-one-seo-pack-pro/all_in_one_seo_pack.php' )
			|| Frontman_Plugin_Dependencies::is_available( 'autodescription/autodescription.php' ) || defined( 'THE_SEO_FRAMEWORK_VERSION' ) ) {
			return __( 'Yoast SEO Premium or another active SEO plugin conflicts with this route.', 'frontman-agentic-ai-editor' );
		}
		if ( ! isset( $wp_version ) || version_compare( (string) $wp_version, '6.9', '<' ) ) {
			return __( 'SEO tools require WordPress 6.9 or later.', 'frontman-agentic-ai-editor' );
		}
		if ( 'post' !== $target ) {
			if ( $surerank || ! defined( 'WPSEO_VERSION' ) || did_action( 'wpseo_loaded' ) < 1 ) {
				return __( 'Archive SEO requires initialized Yoast SEO Free.', 'frontman-agentic-ai-editor' );
			}
			return null;
		}
		if ( $surerank ) {
			return $write
				? __( 'SureRank SEO support is read-only; updates are not available.', 'frontman-agentic-ai-editor' )
				: self::surerank_unavailable_reason();
		}
		if ( ! defined( 'WPSEO_VERSION' ) ) {
			return __( 'Yoast SEO Free is absent or not loaded.', 'frontman-agentic-ai-editor' );
		}
		$runtime_reason = __( 'Yoast SEO runtime methods, initialization, or metadata sanitizers are unavailable.', 'frontman-agentic-ai-editor' );
		if ( did_action( 'wpseo_loaded' ) < 1 || ( $write && ! function_exists( 'sanitize_meta' ) ) ) {
			return $runtime_reason;
		}
		foreach ( $write ? [ 'get_value', 'set_value', 'delete', 'sanitize_post_meta' ] : [ 'get_value' ] as $method ) {
			if ( ! is_callable( [ 'WPSEO_Meta', $method ] ) ) {
				return $runtime_reason;
			}
		}
		if ( ! $write ) {
			return null;
		}
		$registered = get_registered_meta_keys( 'post' );
		foreach ( self::META as $key ) {
			$meta_key = '_yoast_wpseo_' . $key;
			if ( ! is_callable( $registered[ $meta_key ]['sanitize_callback'] ?? null )
				|| false === has_filter( 'sanitize_post_meta_' . $meta_key, [ 'WPSEO_Meta', 'sanitize_post_meta' ] ) ) {
				return $runtime_reason;
			}
		}
		return null;
	}
	private static function surerank_unavailable_reason(): ?string {
		if ( ! defined( 'SURERANK_VERSION' )
			|| ! is_callable( [ '\SureRank\Inc\Functions\Get', 'post_meta' ] ) ) {
			return __( 'SureRank SEO runtime metadata reader is unavailable.', 'frontman-agentic-ai-editor' );
		}
		return null;
	}
	private function surerank_snapshot( int $id ): array {
		$values = [];
		try {
			foreach ( self::SURERANK_META as $field => $key ) {
				$values[ $field ] = \SureRank\Inc\Functions\Get::post_meta( $id, $key, true );
			}
		} catch ( \Throwable $error ) {
			throw new Frontman_Tool_Error( __( 'SureRank could not read the stored SEO overrides.', 'frontman-agentic-ai-editor' ) );
		}
		foreach ( $values as $value ) {
			if ( ! is_string( $value ) || 1 !== preg_match( '//u', $value ) ) {
				throw new Frontman_Tool_Error( __( 'SureRank returned invalid SEO overrides.', 'frontman-agentic-ai-editor' ) );
			}
		}
		return $values;
	}
	public static function validate_input( string $tool, array $input ): array {
		if ( in_array( $tool, self::ARCHIVE_TOOLS, true ) ) {
			return self::validate_archive_input( $tool, $input );
		}
		$allowed = 'wp_read_seo' === $tool ? [ 'id' ] : array_merge( [ 'id' ], array_keys( self::META ) );
		if ( ! in_array( $tool, [ 'wp_read_seo', 'wp_update_seo' ], true ) || array_diff( array_keys( $input ), $allowed ) ) {
			throw new Frontman_Tool_Error( __( 'Invalid SEO tool input.', 'frontman-agentic-ai-editor' ) );
		}
		if ( ! isset( $input['id'] ) || ! is_int( $input['id'] ) || $input['id'] < 1 ) {
			throw new Frontman_Tool_Error( __( 'id must be a positive integer.', 'frontman-agentic-ai-editor' ) );
		}
		foreach ( self::META as $field => $key ) {
			if ( array_key_exists( $field, $input ) && ( ! is_string( $input[ $field ] ) || 1 !== preg_match( '//u', $input[ $field ] ) ) ) {
				throw new Frontman_Tool_Error( __( 'SEO values must be valid UTF-8 strings.', 'frontman-agentic-ai-editor' ) );
			}
		}
		if ( 'wp_update_seo' === $tool && ! array_intersect_key( $input, self::META ) ) {
			throw new Frontman_Tool_Error( __( 'Provide title, description, or focus_keyphrase.', 'frontman-agentic-ai-editor' ) );
		}
		return $input;
	}
	public function read_seo( array $input ): array {
		$input = self::validate_input( 'wp_read_seo', $input );
		$this->guard( $input['id'], false );
		return [ 'id' => $input['id'], 'provider' => self::provider() ] + $this->snapshot( $input['id'] );
	}
	public function update_seo( array $input ): array {
		$input     = self::validate_input( 'wp_update_seo', $input );
		$post_type = $this->guard( $input['id'] );
		$before    = $this->snapshot( $input['id'] );
		$expected  = [];
		try {
			foreach ( self::META as $field => $key ) {
				if ( array_key_exists( $field, $input ) ) {
					$expected[ $field ] = '' === $input[ $field ] ? '' : sanitize_meta( '_yoast_wpseo_' . $key, $input[ $field ], 'post', $post_type );
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
		foreach ( self::META as $field => $key ) {
			if ( ! array_key_exists( $field, $expected ) ) {
				continue;
			}
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
	private function guard( int $id, bool $write = true ): string {
		$reason = $write ? self::unavailable_reason() : self::read_unavailable_reason();
		if ( null !== $reason ) {
			throw new Frontman_Tool_Error( $reason );
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
		$keys = 'surerank' === self::provider() ? self::SURERANK_META : array_map( static fn( string $key ): string => '_yoast_wpseo_' . $key, self::META );
		foreach ( $keys as $key ) {
			if ( ! current_user_can( 'edit_post_meta', $id, $key ) ) {
				throw new Frontman_Tool_Error( __( 'You cannot edit this post SEO metadata.', 'frontman-agentic-ai-editor' ) );
			}
		}
		return $post->post_type;
	}
	private function snapshot( int $id ): array {
		if ( 'surerank' === self::provider() ) {
			return $this->surerank_snapshot( $id );
		}
		$values = [];
		try {
			foreach ( self::META as $field => $key ) {
				$values[ $field ] = \WPSEO_Meta::get_value( $key, $id );
			}
		} catch ( \Throwable $error ) {
			throw new Frontman_Tool_Error( __( 'Yoast could not read the stored SEO overrides.', 'frontman-agentic-ai-editor' ) );
		}
		foreach ( $values as $value ) {
			if ( ! is_string( $value ) || 1 !== preg_match( '//u', $value ) ) {
				throw new Frontman_Tool_Error( __( 'Yoast returned invalid SEO overrides.', 'frontman-agentic-ai-editor' ) );
			}
		}
		return $values;
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

	private function register_archive_tools( Frontman_Tools $tools ): void {
		foreach ( self::ARCHIVE_TOOLS as $name ) {
			$term = false !== strpos( $name, '_term_' );
			$write = 0 === strpos( $name, 'wp_update_' );
			if ( null !== self::archive_unavailable_reason( $term ? 'term' : 'post_type_archive', $write ) ) {
				continue;
			}
			$properties = $term
				? [ 'taxonomy' => [ 'type' => 'string' ], 'term_id' => [ 'type' => 'integer', 'minimum' => 1 ] ]
				: [ 'post_type' => [ 'type' => 'string', 'description' => 'Public custom post type with an archive, from wp_get_site_info.' ] ];
			$required = $term ? [ 'taxonomy', 'term_id' ] : [ 'post_type' ];
			if ( $term && ! $write ) {
				$properties['slug'] = [ 'type' => 'string', 'description' => 'Term slug. Supply exactly one of slug or term_id.' ];
				$required = [ 'taxonomy' ];
			}
			if ( $write ) {
				$properties += [ 'title' => [ 'type' => 'string' ], 'description' => [ 'type' => 'string' ] ];
			}
			$description = $term
				? 'Yoast Free term SEO overrides, not computed tags. Requires a public editable taxonomy. '
				: 'Yoast Free CPT archive title and description templates, including defaults, not computed tags. ';
			$description .= $write
				? 'Provide title or description. Omitted fields stay unchanged. Empty strings restore Yoast defaults. Reread after any failure; never retry automatically. Verify rendered tags separately.'
				: ( $term ? 'Supply taxonomy and exactly one of term_id or slug. Empty overrides inherit taxonomy templates.' : 'Use the returned archive URL to inspect rendered tags.' );
			$tools->add( new Frontman_Tool_Definition(
				$name, $description, [ 'type' => 'object', 'additionalProperties' => false, 'properties' => $properties, 'required' => $required ],
				[ $this, substr( $name, 3 ) ], new Frontman_Tool_Annotations( ! $write, $write, $write, ! $write ), $write ? 'read-write' : 'read'
			) );
		}
	}

	public static function archive_unavailable_reason( string $target, bool $write = false ): ?string {
		$reason = self::compatibility_reason( $write, $target );
		if ( null !== $reason ) {
			return $reason;
		}
		$methods = 'term' === $target ? [ 'get_term_meta' ] : [ 'get', 'get_default', 'get_option_instance' ];
		if ( $write ) {
			$methods = array_merge( $methods, 'term' === $target ? [ 'set_values', 'validate_term_meta_data' ] : [ 'set' ] );
		}
		foreach ( $methods as $method ) {
			if ( ! is_callable( [ 'term' === $target ? 'WPSEO_Taxonomy_Meta' : 'WPSEO_Options', $method ] ) ) {
				return 'Yoast archive SEO runtime APIs are unavailable.';
			}
		}
		if ( ! is_callable( [ 'WPSEO_Capability_Utils', 'current_user_can' ] ) ) {
			return 'Yoast archive SEO permissions are unavailable.';
		}
		if ( $write ) {
			$option = is_callable( [ 'WPSEO_Options', 'get_option_instance' ] ) ? WPSEO_Options::get_option_instance( 'term' === $target ? 'wpseo_taxonomy_meta' : 'wpseo_titles' ) : false;
			if ( ! is_object( $option ) || ! is_callable( [ $option, 'validate' ] ) || ! is_callable( [ $option, 'add_default_filters' ] )
				|| false === has_filter( 'sanitize_option_' . ( 'term' === $target ? 'wpseo_taxonomy_meta' : 'wpseo_titles' ), [ $option, 'validate' ] )
				|| ! function_exists( 'YoastSEO' )
				|| ! method_exists( 'term' === $target ? \Yoast\WP\SEO\Integrations\Watchers\Indexable_Term_Watcher::class : \Yoast\WP\SEO\Integrations\Watchers\Indexable_Post_Type_Archive_Watcher::class, 'build_indexable' ) ) {
				return 'Yoast archive SEO sanitizers or indexable refresh are unavailable.';
			}
		}
		return null;
	}

	private static function validate_archive_input( string $tool, array $input ): array {
		$term = false !== strpos( $tool, '_term_' );
		$write = 0 === strpos( $tool, 'wp_update_' );
		$allowed = $term ? [ 'taxonomy', 'term_id' ] : [ 'post_type' ];
		$allowed = array_merge( $allowed, $write ? [ 'title', 'description' ] : ( $term ? [ 'slug' ] : [] ) );
		if ( array_diff( array_keys( $input ), $allowed ) ) {
			throw new Frontman_Tool_Error( 'Invalid SEO tool input.' );
		}
		$key = $term ? 'taxonomy' : 'post_type';
		if ( ! isset( $input[ $key ] ) || ! is_string( $input[ $key ] ) || '' === $input[ $key ] || sanitize_key( $input[ $key ] ) !== $input[ $key ] ) {
			throw new Frontman_Tool_Error( "$key must be a canonical WordPress name." );
		}
		if ( $term ) {
			$id = array_key_exists( 'term_id', $input );
			$slug = array_key_exists( 'slug', $input );
			if ( $id === $slug || ( $write && ! $id ) || ( $id && ( ! is_int( $input['term_id'] ) || $input['term_id'] < 1 ) )
				|| ( $slug && ( ! is_string( $input['slug'] ) || '' === $input['slug'] || sanitize_title( $input['slug'] ) !== $input['slug'] ) ) ) {
				throw new Frontman_Tool_Error( 'Supply one positive integer term_id or canonical slug. Updates require term_id.' );
			}
		}
		foreach ( [ 'title', 'description' ] as $field ) {
			if ( array_key_exists( $field, $input ) && ( ! is_string( $input[ $field ] ) || 1 !== preg_match( '//u', $input[ $field ] ) ) ) {
				throw new Frontman_Tool_Error( 'SEO values must be valid UTF-8 strings.' );
			}
		}
		if ( $write && ! array_key_exists( 'title', $input ) && ! array_key_exists( 'description', $input ) ) {
			throw new Frontman_Tool_Error( 'Provide title or description.' );
		}
		return $input;
	}

	private function archive_target( string $tool, array $input ): array {
		$input = self::validate_archive_input( $tool, $input );
		$term = false !== strpos( $tool, '_term_' );
		$write = 0 === strpos( $tool, 'wp_update_' );
		$reason = self::archive_unavailable_reason( $term ? 'term' : 'post_type_archive', $write );
		if ( null !== $reason ) {
			throw new Frontman_Tool_Error( $reason );
		}
		if ( ! current_user_can( 'manage_options' ) || ( $write && is_multisite() && ms_is_switched() ) ) {
			throw new Frontman_Tool_Error( 'Archive SEO requires administrator access on the current site.' );
		}
		if ( $term ) {
			$taxonomy = get_taxonomy( $input['taxonomy'] );
			$object = isset( $input['term_id'] ) ? get_term( $input['term_id'], $input['taxonomy'] ) : get_term_by( 'slug', $input['slug'], $input['taxonomy'] );
			if ( ! $taxonomy || ! $taxonomy->public || ! $taxonomy->show_ui || ! is_taxonomy_viewable( $taxonomy ) || ! $object || is_wp_error( $object ) ) {
				throw new Frontman_Tool_Error( 'Term must exist in a public editable taxonomy.' );
			}
			if ( ! current_user_can( 'edit_term', $object->term_id ) ) {
				throw new Frontman_Tool_Error( 'You cannot edit this term SEO metadata.' );
			}
			$url = get_term_link( $object );
			$target = [ 'taxonomy' => $object->taxonomy, 'term_id' => (int) $object->term_id ];
		} else {
			$object = get_post_type_object( $input['post_type'] );
			if ( ! $object || $object->_builtin || ! $object->public || ! $object->publicly_queryable || ! $object->show_ui || ! $object->has_archive ) {
				throw new Frontman_Tool_Error( 'Post type must have a public custom post type archive.' );
			}
			if ( ! WPSEO_Capability_Utils::current_user_can( 'wpseo_manage_options' ) ) {
				throw new Frontman_Tool_Error( 'Yoast settings permission is required.' );
			}
			$url = get_post_type_archive_link( $object->name );
			$target = [ 'post_type' => $object->name ];
		}
		if ( ! is_string( $url ) || '' === $url ) {
			throw new Frontman_Tool_Error( 'Archive URL is unavailable.' );
		}
		return $target + [ 'url' => $url, 'provider' => 'yoast' ];
	}

	private function archive_keys( array $target ): array {
		return isset( $target['term_id'] ) ? [ 'title' => 'wpseo_title', 'description' => 'wpseo_desc' ]
			: [ 'title' => 'title-ptarchive-' . $target['post_type'], 'description' => 'metadesc-ptarchive-' . $target['post_type'] ];
	}

	/** Bypass provider read filters and caches when verifying persistence. Never expose the option root. */
	private function archive_record( array $target ): array {
		global $wpdb;
		$term = isset( $target['term_id'] );
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $term ? 'wpseo_taxonomy_meta' : 'wpseo_titles' ) );
		if ( '' !== $wpdb->last_error ) {
			throw new Frontman_Tool_Error( 'Could not read persisted archive SEO settings.' );
		}
		$root = $row ? maybe_unserialize( $row->option_value ) : [];
		if ( ! is_array( $root ) ) {
			throw new Frontman_Tool_Error( 'Invalid persisted archive SEO settings.' );
		}
		$record = $term ? ( $root[ $target['taxonomy'] ][ $target['term_id'] ] ?? [] ) : $root;
		if ( ! is_array( $record ) ) {
			throw new Frontman_Tool_Error( 'Invalid persisted term SEO settings.' );
		}
		return $term ? array_replace( WPSEO_Taxonomy_Meta::$defaults_per_term, $record ) : $record;
	}

	private function archive_values( array $target, array $record ): array {
		$values = [];
		foreach ( $this->archive_keys( $target ) as $field => $key ) {
			$value = $record[ $key ] ?? ( isset( $target['term_id'] ) ? '' : WPSEO_Options::get_default( 'wpseo_titles', $key ) );
			if ( ! is_string( $value ) || 1 !== preg_match( '//u', $value ) ) {
				throw new Frontman_Tool_Error( 'Yoast returned invalid archive SEO settings.' );
			}
			$values[ $field ] = $value;
		}
		return $values;
	}

	public function read_term_seo( array $input ): array {
		$target = $this->archive_target( 'wp_read_term_seo', $input );
		return $target + $this->archive_values( $target, $this->archive_record( $target ) );
	}
	public function read_post_type_archive_seo( array $input ): array {
		$target = $this->archive_target( 'wp_read_post_type_archive_seo', $input );
		return $target + $this->archive_values( $target, $this->archive_record( $target ) );
	}
	public function update_term_seo( array $input ): array {
		return $this->update_archive_seo( 'wp_update_term_seo', $input );
	}
	public function update_post_type_archive_seo( array $input ): array {
		return $this->update_archive_seo( 'wp_update_post_type_archive_seo', $input );
	}

	private function update_archive_seo( string $tool, array $input ): array {
		$target = $this->archive_target( $tool, $input );
		$record = $this->archive_record( $target );
		$before = $this->archive_values( $target, $record );
		$term = isset( $target['term_id'] );
		$keys = $this->archive_keys( $target );
		$dirty = $record;
		foreach ( $keys as $field => $key ) {
			if ( array_key_exists( $field, $input ) ) {
				$dirty[ $key ] = ! $term && '' === $input[ $field ] ? WPSEO_Options::get_default( 'wpseo_titles', $key ) : $input[ $field ];
			}
		}
		try {
			if ( $term ) {
				$expected = array_replace( WPSEO_Taxonomy_Meta::$defaults_per_term, WPSEO_Taxonomy_Meta::validate_term_meta_data( $dirty, $record ) );
			} else {
				$option = WPSEO_Options::get_option_instance( 'wpseo_titles' );
				try {
					$expected = $option->validate( $dirty );
				} finally {
					$option->add_default_filters();
				}
			}
			$wanted = $this->archive_values( $target, $expected );
			$changed_keys = array_intersect_key( $keys, $input );
			foreach ( $record as $key => $value ) {
				if ( ! in_array( $key, $changed_keys, true ) && ( ! array_key_exists( $key, $expected ) || $expected[ $key ] !== $value ) ) {
					throw new Frontman_Tool_Error( 'Yoast sanitization would change omitted SEO settings.' );
				}
			}
			$watcher = YoastSEO()->classes->get( $term
				? \Yoast\WP\SEO\Integrations\Watchers\Indexable_Term_Watcher::class
				: \Yoast\WP\SEO\Integrations\Watchers\Indexable_Post_Type_Archive_Watcher::class );
		} catch ( \Throwable $error ) {
			throw new Frontman_Tool_Error( 'Yoast could not prepare the archive SEO update. No writes were attempted.' );
		}
		try {
			if ( $term ) {
				WPSEO_Taxonomy_Meta::set_values( $target['term_id'], $target['taxonomy'], $dirty );
			} else {
				foreach ( $keys as $field => $key ) {
					if ( array_key_exists( $field, $input ) ) {
						WPSEO_Options::set( $key, $dirty[ $key ], 'wpseo_titles' );
						if ( $this->archive_values( $target, $this->archive_record( $target ) )[ $field ] !== $wanted[ $field ] ) {
							throw new \RuntimeException( 'Archive SEO field readback differs.' );
						}
					}
				}
			}
			$actual = $this->archive_record( $target );
			$after = $this->archive_values( $target, $actual );
			if ( $after !== $wanted ) {
				throw new \RuntimeException( 'Archive SEO readback differs.' );
			}
			foreach ( $record as $key => $value ) {
				if ( ! in_array( $key, $changed_keys, true ) && ( $actual[ $key ] ?? null ) !== $value ) {
					throw new \RuntimeException( 'Omitted archive SEO settings changed.' );
				}
			}
			$watcher->build_indexable( $term ? $target['term_id'] : $target['post_type'] );
			$refreshed = $this->verify_archive_indexable( $target, $after );
		} catch ( \Throwable $error ) {
			try {
				$after = $this->archive_values( $target, $this->archive_record( $target ) );
				$status = $after === $before ? 'failed' : 'partial';
			} catch ( \Throwable $read_error ) {
				$after = null;
				$status = 'uncertain';
			}
			throw new Frontman_Tool_Error( 'SEO update failed. Reread before retrying; saved settings or indexable refresh can be incomplete. Update state: ' . wp_json_encode(
				$target + [ 'status' => $status, 'before' => $before, 'expectedAfter' => $wanted, 'actualAfter' => $after ]
			) );
		}
		return $target + [ 'before' => $before, 'after' => $after, 'changed' => $before !== $after, 'indexable_refreshed' => $refreshed ];
	}

	/** Native watchers return void and can silently fail to save. Query without auto-create or upgrade. */
	private function verify_archive_indexable( array $target, array $values ): bool {
		if ( ! YoastSEO()->helpers->indexable->should_index_indexables() ) {
			return false;
		}
		$term = isset( $target['term_id'] );
		$query = YoastSEO()->classes->get( \Yoast\WP\SEO\Repositories\Indexable_Repository::class )->query()
			->where( 'object_type', $term ? 'term' : 'post-type-archive' )
			->where( 'object_sub_type', $term ? $target['taxonomy'] : $target['post_type'] );
		if ( $term ) {
			$query->where( 'object_id', $target['term_id'] );
		}
		$indexable = $query->find_one();
		foreach ( $values as $field => $value ) {
			$expected = $term && '' === $value ? null : $value;
			if ( ! $indexable || $indexable->$field !== $expected ) {
				throw new \RuntimeException( 'Saved settings did not reach the persisted archive indexable.' );
			}
		}
		return true;
	}
}
