<?php

define( 'WP_ADMIN', false );
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
if ( ! class_exists( 'WooCommerce' ) ) {
	throw new RuntimeException( 'WooCommerce did not load.' );
}
catalog_assert( '10.4.3' === WC_VERSION, 'Unexpected WooCommerce dependency version' );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/includes/class-frontman-tools.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/tools/class-tool-options.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/tools/class-tool-woocommerce.php';
$tools = new Frontman_Tools();
(new Frontman_Tool_WooCommerce())->register( $tools );
(new Frontman_Tool_Options())->register( $tools );

function catalog_assert( bool $ok, string $message ): void {
	if ( ! $ok ) { throw new RuntimeException( $message ); }
}
function catalog_call( Frontman_Tools $tools, string $tool, array $input, bool $error = false ): array {
	try {
		$result = $tools->call( $tool, $tools->sanitize_input( $tool, $input ) );
	} catch ( Frontman_Tool_Error $exception ) {
		catalog_assert( $error, $exception->getMessage() );
		return [];
	}
	catalog_assert( $error === $result['isError'], $result['content'][0]['text'] );
	return $error ? [] : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
}

$admin = get_current_user_id();
$unrelated = [ get_option( 'blogname' ), get_option( 'woocommerce_currency' ) ];
foreach ( [ 'woocommerce_shop_page_display', 'woocommerce_category_archive_display' ] as $name ) {
	$original = get_option( $name, null );
	try {
		delete_option( $name );
		$read = catalog_call( $tools, 'wc_get_catalog_display', [ 'name' => $name ] );
		catalog_assert( '' === $read['value'], 'Missing option did not use native products default' );
		foreach ( [ 'subcategories', 'both', '', '' ] as $value ) {
			$before = get_option( $name, '' );
			$result = catalog_call( $tools, 'wc_update_catalog_display', compact( 'name', 'value' ) + [ 'confirm' => true ] );
			catalog_assert( $value === get_option( $name ) && $value === $result['after'], 'Native save did not persist' );
			catalog_assert( $before === $result['before'] && ( $before !== $value ) === $result['updated'], 'Incorrect no-op or change receipt' );
		}
		foreach ( [ 'products', null, false, [], new stdClass(), 1 ] as $invalid ) {
			catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => $invalid, 'confirm' => true ], true );
			catalog_assert( '' === get_option( $name ), 'Rejected value mutated option' );
		}
		foreach ( [ null, false, 'true' ] as $confirm ) {
			catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => $confirm ], true );
			catalog_assert( '' === get_option( $name ), 'Unconfirmed write mutated option' );
		}
		catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'confirm' => true ], true );
		$user = wp_get_current_user();
		foreach ( [ 'manage_woocommerce', 'edit_theme_options' ] as $capability ) {
			$user->add_cap( $capability, false );
			try {
				catalog_call( $tools, 'wc_get_catalog_display', [ 'name' => $name ], true );
				catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => true ], true );
				catalog_assert( '' === get_option( $name ), 'Independent capability denial changed option' );
			} finally { $user->remove_cap( $capability ); }
		}
		wp_set_current_user( 0 );
		catalog_call( $tools, 'wc_get_catalog_display', [ 'name' => $name ], true );
		catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => true ], true );
		wp_set_current_user( $admin );
		catalog_assert( '' === get_option( $name ), 'Unauthorized write mutated option' );
		$setting = $GLOBALS['wp_customize']->get_setting( $name );
		catalog_assert( 'option' === $setting->type && 'manage_woocommerce' === $setting->capability, 'Not using native WooCommerce setting' );
		catalog_assert( '' === $setting->sanitize( 'invalid' ), 'Native sanitizer semantics changed' );
		$reject_both = static function( $validity, $value ) {
			if ( 'both' === $value ) { $validity->add( 'catalog_policy', 'Catalog policy rejects both.' ); }
			return $validity;
		};
		add_filter( 'customize_validate_' . $name, $reject_both, 10, 2 );
		try {
			catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => true ], true );
			catalog_assert( '' === get_option( $name ), 'Native validation rejection changed option' );
		} finally { remove_filter( 'customize_validate_' . $name, $reject_both ); }
		$events = [];
		$before_save = static function( $manager ) use ( &$events, $name ) {
			catalog_assert( 'both' === $manager->get_setting( $name )->post_value(), 'Save hook cannot read validated input' );
			$events[] = 'before';
		};
		$setting_save = static function() use ( &$events ) { $events[] = 'setting'; };
		$after_save = static function() use ( &$events, $name ) { $events[] = 'after:' . get_option( $name ); };
		add_action( 'customize_save', $before_save );
		add_action( 'customize_save_' . $name, $setting_save );
		add_action( 'customize_save_after', $after_save );
		try {
			catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => true ] );
			catalog_assert( [ 'before', 'setting', 'after:both' ] === $events, 'Native save lifecycle did not run in order' );
		} finally {
			remove_action( 'customize_save', $before_save );
			remove_action( 'customize_save_' . $name, $setting_save );
			remove_action( 'customize_save_after', $after_save );
		}
		catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => '', 'confirm' => true ] );
		$block_write = static function( $new, $old ) { return $old; };
		add_filter( 'pre_update_option_' . $name, $block_write, 10, 2 );
		try {
			catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => $name, 'value' => 'both', 'confirm' => true ], true );
			catalog_assert( '' === get_option( $name ), 'Blocked native option write changed persisted state' );
		} finally { remove_filter( 'pre_update_option_' . $name, $block_write ); }
		catalog_call( $tools, 'wp_update_theme_mod', [ 'name' => $name, 'value' => 'both', 'stylesheet' => get_stylesheet(), 'confirm' => true ], true );
		catalog_call( $tools, 'wp_update_option', [ 'name' => $name, 'value' => 'both' ], true );
		catalog_assert( '' === get_option( $name ), 'Generic option or theme mod guard was bypassed' );
	} finally {
		wp_set_current_user( $admin );
		if ( null === $original ) { delete_option( $name ); } else { update_option( $name, $original ); }
	}
}
catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => 'blogname', 'value' => '', 'confirm' => true ], true );
catalog_call( $tools, 'wc_update_catalog_display', [ 'value' => '', 'confirm' => true ], true );
catalog_call( $tools, 'wc_get_catalog_display', [], true );
catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => 'woocommerce_shop_page_display', 'value' => '' ], true );
catalog_assert( $unrelated === [ get_option( 'blogname' ), get_option( 'woocommerce_currency' ) ], 'Unrelated options changed' );

$old_query = $GLOBALS['wp_query'];
$old_shop = get_option( 'woocommerce_shop_page_id' );
$old_display = get_option( 'woocommerce_shop_page_display', null );
$shop = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'Catalog fixture', 'post_content' => 'Catalog description fixture' ], true );
catalog_assert( ! is_wp_error( $shop ), 'Could not create shop page' );
$category = wp_insert_term( 'Catalog category fixture', 'product_cat' );
catalog_assert( ! is_wp_error( $category ), 'Could not create product category' );
$product = new WC_Product_Simple();
$product->set_name( 'Catalog product fixture' );
$product->set_status( 'publish' );
$product->set_regular_price( '12' );
$product->set_category_ids( [ $category['term_id'] ] );
$product->save();
try {
	$meta_input = [ 'productId' => $product->get_id(), 'metaKey' => '_frontman_runtime', 'metaValue' => 'value', 'confirm' => true ];
	set_error_handler( static function( $severity, $message, $file, $line ) { throw new ErrorException( $message, 0, $severity, $file, $line ); } );
	try {
		foreach ( [ 'value', 2, 2.5, true, null, [ 'nested' => [ 'value' ] ], [ [ 'nested' => 'value' ] ] ] as $value ) {
			catalog_assert( $value === $tools->sanitize_input( 'wc_update_product_meta', array_merge( $meta_input, [ 'metaValue' => $value ] ) )['metaValue'], 'Metadata value changed during validation' );
		}
	} finally {
		restore_error_handler();
	}
	require_once '/tmp/RuntimeTestSupport.php';
	$cookie = wp_generate_auth_cookie( $admin, time() + HOUR_IN_SECONDS, 'logged_in' );
	$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
	$nonce = Frontman_Auth::create_nonce();
	unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
	foreach ( [ 'value', 2, 2.5, true, null, (object) [ 'nested' => [ 'value' ] ], [ (object) [ 'nested' => 'value' ] ], 'value' ] as $value ) {
		$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => 'wc_update_product_meta', 'arguments' => array_merge( $meta_input, [ 'metaValue' => $value ] ) ] );
		catalog_assert( 200 === $response['status'] && false === $response['body']['isError'], 'HTTP metadata update failed: ' . wp_json_encode( $response ) );
	}
	clean_post_cache( $product->get_id() );
	catalog_assert( 'value' === get_post_meta( $product->get_id(), '_frontman_runtime', true ), 'HTTP metadata update was not persisted' );
	$raw = [ 'name' => 'Premium <strong>Shirt</strong>', 'description' => '<p>Path C:\\tmp\\shirt and regex /\\d+/</p>', 'regular_price' => '29.99' ];
	$sanitized = $tools->sanitize_input( 'wc_create_product', [ 'productData' => $raw ] );
	catalog_assert( $raw === $sanitized['productData'], 'Product data changed during shared sanitization' );
	$before_count = $wpdb->get_var( "SELECT COUNT(*) FROM $wpdb->posts WHERE post_type = 'product'" );
	$before = wc_get_product( $product->get_id() )->get_data();
	foreach ( [
		[ 'wc_create_product', [ 'productData' => 'not an object' ], 'arguments[productData] must be of type object' ],
		[ 'wc_get_product', [ 'productId' => 'abc' ], 'arguments[productId] must be of type integer' ],
		[ 'wc_delete_product', [ 'productId' => $product->get_id(), 'force' => 'false', 'confirm' => true ], 'arguments[force] must be of type boolean' ],
	] as [ $tool, $input, $message ] ) {
		try {
			$tools->call( $tool, $tools->sanitize_input( $tool, $input ) );
			throw new RuntimeException( 'Expected strict type rejection for ' . $tool );
		} catch ( Frontman_Tool_Error $error ) {
			catalog_assert( false !== strpos( $error->getMessage(), $message ), 'Unexpected validation error: ' . $error->getMessage() );
		}
		catalog_assert( $before == wc_get_product( $product->get_id() )->get_data() && $before_count === $wpdb->get_var( "SELECT COUNT(*) FROM $wpdb->posts WHERE post_type = 'product'" ), 'Rejected input mutated products' );
	}
	update_option( 'woocommerce_shop_page_id', $shop );
	$GLOBALS['wp_query'] = new WP_Query( [ 'post_type' => 'product', 'post__in' => [ $product->get_id() ] ] );
	catalog_assert( is_shop(), 'Real product archive query was not recognized as shop' );
	foreach ( [ 'subcategories', 'both', '' ] as $value ) {
		catalog_call( $tools, 'wc_update_catalog_display', [ 'name' => 'woocommerce_shop_page_display', 'value' => $value, 'confirm' => true ] );
		$GLOBALS['wp_query']->rewind_posts();
		wc_setup_loop( [ 'total' => 1, 'current_page' => 1, 'is_search' => false, 'is_filtered' => false ] );
		catalog_assert( ( '' === $value ? 'products' : $value ) === woocommerce_get_loop_display_mode(), 'Persisted mode not used by native loop' );
		ob_start();
		wc_get_template( 'loop/header.php' );
		woocommerce_product_loop_start();
		if ( wc_get_loop_prop( 'total' ) ) {
			while ( have_posts() ) {
				the_post();
				wc_get_template_part( 'content', 'product' );
			}
		}
		woocommerce_product_loop_end();
		$html = ob_get_clean();
		catalog_assert( false !== strpos( $html, 'Catalog description fixture' ), 'Native archive lost assigned shop content' );
		catalog_assert( ( 'subcategories' !== $value ) === ( false !== strpos( $html, 'Catalog product fixture' ) ), 'Rendered products did not follow catalog mode' );
		catalog_assert( ( '' !== $value ) === ( false !== strpos( $html, 'Catalog category fixture' ) ), 'Rendered categories did not follow catalog mode' );
	}
} finally {
	$GLOBALS['wp_query'] = $old_query;
	wp_reset_postdata();
	wc_reset_loop();
	update_option( 'woocommerce_shop_page_id', $old_shop );
	if ( null === $old_display ) { delete_option( 'woocommerce_shop_page_display' ); } else { update_option( 'woocommerce_shop_page_display', $old_display ); }
	$product->delete( true );
	wp_delete_term( $category['term_id'], 'product_cat' );
	wp_delete_post( $shop, true );
}
echo "OK (WooCommerce 10.4.3 native catalog display settings)\n";
