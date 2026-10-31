<?php

$baseline = get_option( '_frontman_runtime_polylang_baseline' );
if ( is_array( $baseline ) ) {
	foreach ( [ 'de', 'fr', 'en' ] as $slug ) {
		$language = PLL()->model->languages->get( $slug );
		if ( $language ) {
			frontman_runtime_assert( PLL()->model->languages->delete( $language->term_id ), 'Could not remove Polylang fixture language.' );
		}
	}
	$categories = get_terms( [ 'taxonomy' => 'category', 'hide_empty' => false, 'fields' => 'ids' ] );
	foreach ( array_diff( $categories, $baseline['categories'] ) as $id ) {
		frontman_runtime_assert( ! is_wp_error( wp_delete_term( $id, 'category' ) ), 'Could not remove Polylang fixture category.' );
	}
	if ( null === $baseline['options'] ) {
		delete_option( 'polylang' );
	} else {
		update_option( 'polylang', $baseline['options'] );
	}
	delete_option( '_frontman_runtime_polylang_baseline' );
}
