<?php

frontman_runtime_same( [], pll_languages_list( [ 'hide_empty' => false, 'fields' => 'slug' ] ), 'Fixture languages must not persist after cleanup.' );
foreach ( [ 'language', 'term_language', 'term_translations' ] as $taxonomy ) {
	$terms = get_terms( [ 'taxonomy' => $taxonomy, 'hide_empty' => false, 'fields' => 'ids' ] );
	frontman_runtime_assert( ! is_wp_error( $terms ) && [] === $terms, "Fixture taxonomy {$taxonomy} must be empty after cleanup." );
}
