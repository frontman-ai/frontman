<?php
add_filter( 'pre_wp_mail', '__return_false' );
add_filter( 'pre_http_request', static function () {
	return new WP_Error( 'fixture_offline', 'External HTTP disabled in local fixture.' );
} );
add_filter( 'woocommerce_available_payment_gateways', '__return_empty_array' );
