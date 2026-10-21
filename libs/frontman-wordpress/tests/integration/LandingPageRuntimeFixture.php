<?php

switch ( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) {
	case 'transform-content':
		add_filter( 'wp_insert_post_data', static function( array $data ): array {
			$data['post_content'] .= '<p>Plugin transformation</p>';
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
