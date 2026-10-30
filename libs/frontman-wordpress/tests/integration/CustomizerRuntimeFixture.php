<?php

// Simulate a front-end integration which initialized a manager before the
// Frontman router handles the request, without Astra's admin-only bootstrap.
add_action( 'wp_loaded', static function(): void {
	$mode = $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '';
	if ( 'customizer-own-manager' === $mode ) {
		$tool = new Frontman_Tool_Options();
		$tool->update_theme_mod( [
			'name' => 'frontman_runtime_first', 'value' => 'first-default',
			'stylesheet' => get_stylesheet(), 'confirm' => true,
		] );
		return;
	}
	if ( ! in_array( $mode, [ 'customizer-manager', 'customizer-preview' ], true ) ) {
		return;
	}
	global $wp_customize;
	require_once ABSPATH . WPINC . '/class-wp-customize-manager.php';
	$wp_customize = new WP_Customize_Manager( [ 'settings_previewed' => false ] );
	remove_action( 'customize_register', [ $wp_customize, 'register_controls' ] );
	$wp_customize->register_controls();
	if ( 'customizer-preview' === $mode ) {
		$wp_customize->start_previewing_theme();
	}
} );

// Register real Customizer settings on each HTTP request while this case runs.
add_action( 'customize_register', static function( $manager ): void {
	if ( ! get_option( 'frontman_customizer_runtime_fixture' ) ) {
		return;
	}
	$manager->add_setting( 'frontman_runtime_first', [
		'type' => 'theme_mod',
		'default' => 'first-default',
		'sanitize_callback' => 'sanitize_text_field',
		'validate_callback' => static function( $validity, $value ) {
			if ( 'invalid' === $value ) {
				$validity->add( 'fixture_invalid', 'Fixture validation rejected the value.' );
			}
			return $validity;
		},
	] );
	$manager->add_setting( 'frontman_runtime_restricted', [
		'type' => 'theme_mod',
		'capability' => 'manage_network',
		'default' => 'restricted',
	] );
	$manager->add_setting( 'frontman_runtime_option', [
		'type' => 'option',
		'default' => 'not allowed',
	] );
} );

add_filter( 'pre_update_option_astra-settings', static function( $new, $old ) {
	return 'block-astra-write' === ( $_SERVER['HTTP_X_FRONTMAN_SEO_TEST'] ?? '' ) ? $old : $new;
}, 10, 2 );
