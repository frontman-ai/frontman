<?php
/** Exercise real native save filtering in the separate HTTP worker. */
add_filter( 'wp_insert_post_data', static function( array $data ): array {
	if ( 'Frontman transformed content fixture' === $data['post_title'] ) {
		$data['post_content'] .= '<p>Plugin transformation</p>';
	}
	return $data;
} );
