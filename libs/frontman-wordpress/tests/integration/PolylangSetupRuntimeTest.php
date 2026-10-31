<?php

frontman_runtime_assert( function_exists( 'PLL' ), 'Polylang must load in the setup admin context.' );
frontman_runtime_same( [], pll_languages_list( [ 'hide_empty' => false, 'fields' => 'slug' ] ), 'Polylang fixture must start without languages.' );
update_option( '_frontman_runtime_polylang_baseline', [
	'options' => get_option( 'polylang', null ),
	'categories' => get_terms( [ 'taxonomy' => 'category', 'hide_empty' => false, 'fields' => 'ids' ] ),
], false );
foreach ( [
	[ 'locale' => 'en_US', 'name' => 'English', 'slug' => 'en', 'rtl' => false ],
	[ 'locale' => 'fr_FR', 'name' => 'Français', 'slug' => 'fr', 'rtl' => false ],
	[ 'locale' => 'de_DE', 'name' => 'Deutsch', 'slug' => 'de', 'rtl' => false ],
] as $args ) {
	$language = PLL()->model->languages->add( $args );
	frontman_runtime_assert( ! is_wp_error( $language ) && $language, 'Could not create Polylang fixture language.' );
}
frontman_runtime_same( [ 'en', 'fr', 'de' ], pll_languages_list( [ 'hide_empty' => false, 'fields' => 'slug' ] ), 'Polylang fixture must expose configured empty languages.' );
