<?php

switch ( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) {
	case 'elementor-content-guard':
		require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/includes/class-frontman-elementor-data.php';
		break;
	case 'transform-content':
		add_filter( 'wp_insert_post_data', static function( array $data ): array {
			$data['post_content'] .= '<p>Plugin transformation</p>';
			return $data;
		} );
		break;
	case 'preview-race-selection':
		add_action( 'pre_get_posts', static function( WP_Query $query ): void {
			static $inserted = false;
			$id = (int) $query->get( 'post_parent' );
			if ( ! $inserted && $id && 'revision' === $query->get( 'post_type' ) && 1 === $query->get( 'posts_per_page' ) ) {
				$inserted = true;
				$data = get_post( $id, ARRAY_A );
				$data['post_content'] = 'Concurrent editor content';
				_wp_put_post_revision( $data, true );
			}
		} );
		break;
	case 'preview-race-insert':
		add_filter( 'wp_insert_post_data', static function( array $data ): array {
			static $inserted = false;
			if ( ! $inserted && 'revision' === $data['post_type'] && $data['post_parent'] ) {
				$inserted = true;
				$editor = get_post( $data['post_parent'], ARRAY_A );
				$editor['post_content'] = 'Concurrent editor content';
				_wp_put_post_revision( $editor, true );
			}
			return $data;
		} );
		break;
	case 'reject-template-metadata':
		add_filter( 'update_post_metadata', static function( $check, $id, $key ) {
			return '_wp_page_template' === $key ? false : $check;
		}, 10, 3 );
		break;
	case 'no-block-templates':
		add_action( 'after_setup_theme', static function(): void {
			remove_theme_support( 'block-templates' );
		}, 99 );
		break;
	case 'unavailable-template':
		add_filter( 'theme_page_templates', static fn( array $templates ): array => [] );
		break;
	case 'custom-area':
		add_filter( 'default_wp_template_part_areas', static function( array $areas ): array {
			$areas[] = [ 'area' => 'frontman-sidebar', 'label' => 'Sidebar' ];
			return $areas;
		} );
		break;
	case 'hooked-block':
		add_action( 'init', static function(): void {
			register_block_type( 'frontman/runtime-hook', [ 'api_version' => 2, 'block_hooks' => [ 'core/paragraph' => 'after' ] ] );
		} );
		break;
}
