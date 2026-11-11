<?php
/**
 * Plugin Name: Frontman Review Site Safety
 * Description: Blocks WordPress email and WooCommerce payment gateways on a synthetic review site.
 * Version: 1.0.0
 */

defined( 'ABSPATH' ) || exit;

add_filter( 'pre_wp_mail', '__return_true', PHP_INT_MAX );
add_filter( 'woocommerce_payment_gateways', '__return_empty_array', PHP_INT_MAX );
