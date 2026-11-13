<?php

declare(strict_types=1);

function frontman_runtime_core_annotations(): array {
	$expected = [];
	foreach ( [
		[ [ true, false, false, true ], [
			'wp_list_posts', 'wp_read_post', 'wp_find_users', 'wp_list_blocks', 'wp_read_block',
			'wp_get_option', 'wp_list_options', 'wp_get_custom_css', 'wp_list_custom_css_revisions',
			'wp_get_custom_css_revision', 'wp_list_theme_mods', 'wp_get_theme_mod',
			'wp_list_customizer_settings', 'wp_get_customizer_setting', 'wp_list_cache_plugins',
			'wp_list_menus', 'wp_list_menu_locations', 'wp_read_menu',
			'wp_list_navigation_menus', 'wp_read_navigation_menu', 'wp_get_site_info',
			'wp_list_templates', 'wp_read_template', 'wp_list_widget_areas', 'wp_read_widget',
		] ],
		[ [ true, false, true, true ], [ 'wp_read_public_file' ] ],
		[ [ false, true, false, false ], [ 'wp_duplicate_post', 'wp_save_post_preview', 'wp_create_menu' ] ],
		[ [ false, true, true, false ], [
			'wp_create_post', 'wp_update_post', 'wp_delete_post',
			'wp_update_block', 'wp_insert_block', 'wp_move_block', 'wp_delete_block',
			'wp_upload_media', 'wp_update_option', 'wp_restore_custom_css_revision',
			'wp_update_custom_css', 'wp_update_theme_mod', 'wp_update_customizer_setting',
			'wp_clear_cache', 'wp_write_public_file', 'wp_delete_menu', 'wp_assign_menu_location',
			'wp_create_menu_item', 'wp_update_menu_item', 'wp_delete_menu_item',
			'wp_create_navigation_menu', 'wp_update_navigation_menu', 'wp_delete_navigation_menu',
			'wp_create_template', 'wp_update_template', 'wp_set_widget_visibility',
			'wp_create_widget', 'wp_update_widget', 'wp_move_widget', 'wp_delete_widget',
		] ],
	] as [ $hints, $names ] ) {
		foreach ( $names as $name ) {
			frontman_runtime_assert( ! isset( $expected[ $name ] ), 'Core review oracle contains a duplicate: ' . $name );
			$expected[ $name ] = $hints;
		}
	}
	return $expected;
}

function frontman_runtime_woocommerce_annotations(): array {
	$read = [ true, false, false, true ];
	$write = [ false, true, true, false ];
	$expected = [];
	foreach ( [
		'get_products', 'get_product', 'get_product_categories', 'get_product_category',
		'get_product_tags', 'get_product_tag', 'get_product_attributes', 'get_product_attribute',
		'get_attribute_terms', 'get_attribute_term', 'get_product_variations', 'get_product_variation',
		'get_product_reviews', 'get_product_review', 'get_orders', 'get_order', 'get_order_notes', 'get_order_note',
		'get_order_refunds', 'get_order_refund', 'get_customers', 'get_customer',
		'get_shipping_zones', 'get_shipping_zone', 'get_shipping_methods', 'get_shipping_zone_methods', 'get_shipping_zone_locations',
		'get_tax_classes', 'get_tax_rates', 'get_tax_rate', 'get_coupons', 'get_coupon',
		'get_payment_gateways', 'get_payment_gateway', 'get_sales_report', 'get_products_report', 'get_orders_report',
		'get_categories_report', 'get_customers_report', 'get_stock_report', 'get_coupons_report', 'get_taxes_report',
		'get_settings', 'get_setting_options',
		'get_data', 'get_continents', 'get_countries', 'get_currencies', 'get_current_currency', 'get_catalog_display',
	] as $method ) { $expected[ 'wc_' . $method ] = $read; }
	foreach ( [
		'create_product', 'update_product', 'delete_product',
		'create_product_category', 'update_product_category', 'delete_product_category',
		'update_product_tag', 'delete_product_tag', 'update_product_attribute', 'delete_product_attribute',
		'update_attribute_term', 'delete_attribute_term',
		'create_product_variation', 'update_product_variation', 'delete_product_variation',
		'create_product_review', 'update_product_review', 'delete_product_review',
		'create_order', 'update_order', 'delete_order', 'create_order_note', 'delete_order_note',
		'create_order_refund', 'delete_order_refund', 'create_customer', 'update_customer', 'delete_customer',
		'create_shipping_zone', 'update_shipping_zone', 'delete_shipping_zone',
		'create_shipping_zone_method', 'update_shipping_zone_method', 'delete_shipping_zone_method', 'update_shipping_zone_locations',
		'delete_tax_class', 'create_tax_rate', 'update_tax_rate', 'delete_tax_rate',
		'create_coupon', 'update_coupon', 'delete_coupon', 'update_payment_gateway', 'update_setting_option',
		'update_catalog_display',
	] as $method ) { $expected[ 'wc_' . $method ] = $write; }
	foreach ( [ 'create_product_tag', 'create_product_attribute', 'create_attribute_term' ] as $method ) {
		$expected[ 'wc_' . $method ] = [ false, true, true, false ];
	}
	$expected['wc_create_tax_class'] = [ false, true, false, false ];
	$expected['wc_get_system_status'] = [ false, true, true, false ];
	foreach ( [ 'product', 'order', 'customer' ] as $entity ) {
		$expected[ 'wc_get_' . $entity . '_meta' ] = $read;
		foreach ( [ 'update', 'delete' ] as $operation ) {
			$expected[ 'wc_' . $operation . '_' . $entity . '_meta' ] = $write;
		}
	}
	frontman_runtime_same( 109, count( $expected ), 'Review oracle covers all non-maintenance WooCommerce tools.' );
	$maintenance = [
		'clear_transients' => [ false, true, false, false ],
		'clear_expired_transients' => [ false, true, false, false ],
		'delete_orphaned_variations' => [ false, true, false, false ],
		'clear_expired_download_permissions' => [ false, true, false, false ],
		'regenerate_product_lookup_tables' => [ false, true, false, false ],
		'repair_coupons_lookup_table' => [ false, true, false, false ],
		'recount_terms' => [ false, true, false, false ],
		'reset_roles' => [ false, true, false, false ],
		'clear_sessions' => [ false, true, false, false ],
		'clear_template_cache' => [ false, true, false, false ],
		'clear_system_status_theme_info_cache' => [ false, true, false, false ],
		'install_pages' => [ false, true, true, false ],
		'delete_taxes' => [ false, true, false, false ],
		'regenerate_thumbnails' => [ false, true, false, false ],
		'db_update_routine' => [ false, true, false, false ],
		'recreate_order_address_fts_index' => [ false, true, false, false ],
		'verify_db_tables' => [ false, true, false, false ],
	];
	$native = ( new WC_REST_System_Status_Tools_Controller() )->get_tools();
	foreach ( $maintenance as $id => $hints ) {
		if ( isset( $native[ $id ] ) ) {
			$expected[ 'wc_maint_' . $id ] = $hints;
		}
	}
	return $expected;
}
