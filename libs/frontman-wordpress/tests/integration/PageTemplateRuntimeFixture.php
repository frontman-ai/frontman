<?php
/** Simulate a plugin silently refusing native page-template metadata persistence. */
add_filter( 'update_post_metadata', static function( $check, $id, $key ) {
	if ( '_wp_page_template' === $key && 'Frontman blocked template fixture' === get_post_field( 'post_title', $id ) ) {
		return false;
	}
	return $check;
}, 10, 3 );
