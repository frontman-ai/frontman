<?php
/**
 * Polylang language and translation tools. Uses Polylang's public PHP API only.
 *
 * @package Frontman
 */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Polylang {
	private const POST = [ 'type' => 'integer', 'minimum' => 1 ];

	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_languages',
			'Reports whether Polylang is available and lists configured language slugs and the default language. Does not read private plugin options.',
			[ 'type' => 'object', 'additionalProperties' => false, 'properties' => new \stdClass() ],
			[ $this, 'list_languages' ]
		) );
		$tools->add( new Frontman_Tool_Definition(
			'wp_read_post_language',
			'Reads a post language and readable translation IDs through Polylang. Unreadable translations are omitted.',
			[ 'type' => 'object', 'additionalProperties' => false, 'properties' => [ 'id' => self::POST ], 'required' => [ 'id' ] ],
			[ $this, 'read_post_language' ]
		) );
		$tools->add( new Frontman_Tool_Definition(
			'wp_set_post_language',
			'Assigns a configured Polylang language to an existing editable post. Refuses to change the language of a post already linked to translations. Does not link posts as translations; concurrent changes elsewhere can race with this best-effort linked-post check.',
			[ 'type' => 'object', 'additionalProperties' => false, 'properties' => [
				'id' => self::POST,
				'lang' => [ 'type' => 'string', 'description' => 'Configured Polylang language slug.' ],
			], 'required' => [ 'id', 'lang' ] ],
			[ $this, 'set_post_language' ]
		) );
	}

	private function available(): bool {
		return function_exists( 'pll_languages_list' )
			&& function_exists( 'pll_default_language' )
			&& function_exists( 'pll_is_translated_post_type' )
			&& function_exists( 'pll_get_post_language' )
			&& function_exists( 'pll_get_post_translations' )
			&& function_exists( 'pll_set_post_language' );
	}

	private function require_available(): void {
		if ( ! $this->available() ) {
			throw new Frontman_Tool_Error( 'Polylang is not active or its language API is unavailable.' );
		}
	}

	public function list_languages( array $input ): array {
		if ( ! $this->available() ) {
			return [
				'plugin_active' => Frontman_Plugin_Dependencies::is_available( 'polylang/polylang.php' ),
				'api_available' => false,
				'languages' => [],
				'default_language' => null,
			];
		}
		return [
			'plugin_active' => true,
			'api_available' => true,
			'languages' => array_values( pll_languages_list( [ 'hide_empty' => false, 'fields' => 'slug' ] ) ),
			'default_language' => pll_default_language( 'slug' ) ?: null,
		];
	}

	private function post( int $id, bool $write ): \WP_Post {
		$post = get_post( $id );
		if ( ! $post ) {
			throw new Frontman_Tool_Error( "Post {$id} not found." );
		}
		if ( ! pll_is_translated_post_type( $post->post_type ) ) {
			throw new Frontman_Tool_Error( "Polylang does not manage post type {$post->post_type}." );
		}
		if ( ! current_user_can( $write ? 'edit_post' : 'read_post', $id ) ) {
			throw new Frontman_Tool_Error( "Insufficient permission to " . ( $write ? 'edit' : 'read' ) . " post {$id}." );
		}
		return $post;
	}

	private function readable_translations( array $translations ): array {
		$result = [];
		foreach ( $translations as $lang => $id ) {
			if ( current_user_can( 'read_post', (int) $id ) ) {
				$result[ $lang ] = (int) $id;
			}
		}
		ksort( $result );
		return $result;
	}

	public function read_post_language( array $input ): array {
		$this->require_available();
		$id = (int) $input['id'];
		$this->post( $id, false );
		return [
			'id' => $id,
			'lang' => pll_get_post_language( $id, 'slug' ) ?: null,
			'translations' => $this->readable_translations( (array) pll_get_post_translations( $id ) ),
		];
	}

	private function require_language( string $lang ): void {
		if ( ! in_array( $lang, $this->list_languages( [] )['languages'], true ) ) {
			throw new Frontman_Tool_Error( "Unknown Polylang language slug: {$lang}." );
		}
	}

	public function set_post_language( array $input ): array {
		$this->require_available();
		$id = (int) $input['id'];
		$lang = $input['lang'];
		$this->require_language( $lang );
		$this->post( $id, true );
		$before = pll_get_post_language( $id, 'slug' ) ?: null;
		$group = (array) pll_get_post_translations( $id );
		if ( $before !== $lang && count( $group ) > 1 ) {
			throw new Frontman_Tool_Error( 'Changing a linked post language requires a separate translation-group migration.' );
		}
		if ( $before !== $lang ) {
			pll_set_post_language( $id, $lang );
		}
		if ( pll_get_post_language( $id, 'slug' ) !== $lang ) {
			throw new Frontman_Tool_Error( "Language assignment on post {$id} may have partially succeeded; no rollback was performed. Use wp_read_post_language before retrying." );
		}
		return [ 'id' => $id, 'before' => $before, 'lang' => $lang ];
	}
}
