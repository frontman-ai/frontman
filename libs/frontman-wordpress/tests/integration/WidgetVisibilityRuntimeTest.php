<?php
/**
 * Real WordPress/WooCommerce integration. Run after both plugins are active.
 * No replacement conditionals, widgets, database, or authorization services.
 */
require '/var/www/html/wp-load.php';

if ( ( $argv[1] ?? '' ) === '--render' ) {
	register_sidebar( [ 'id' => 'frontman-visibility', 'name' => 'Visibility test' ] );
	if ( ! empty( $argv[3] ) ) {
		$_COOKIE['woocommerce_recently_viewed'] = $argv[3];
	}
	wp( [ 'page_id' => (int) $argv[2] ] );
	dynamic_sidebar( 'frontman-visibility' );
	exit;
}

function widget_check( $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}
widget_check( class_exists( 'WC_Widget_Recently_Viewed' ), 'WooCommerce must be active.' );
$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$tool = new Frontman_Tool_Widgets();
register_sidebar( [ 'id' => 'frontman-visibility', 'name' => 'Visibility test' ] );
$widget_id = 'woocommerce_recently_viewed_products-2';
$original = [ 'title' => 'Original', 'number' => 4, 'extension_metadata' => 'retained' ];
update_option( 'widget_woocommerce_recently_viewed_products', [ 2 => $original, 3 => $original, '_multiwidget' => 1 ] );
wp_set_sidebars_widgets( [ 'frontman-visibility' => [ $widget_id ] ] );
$wp_widget_factory->widgets['WC_Widget_Recently_Viewed']->_register();
$identity = static function( $instance, $new, $old, $widget ) use ( $widget_id ) {
	widget_check( $widget_id === $widget->id && 2 === $widget->number, 'Native callback must receive the target instance, not the last registered instance' );
	return $instance;
};
add_filter( 'widget_update_callback', $identity, 10, 4 );
$input = [ 'widget_id' => $widget_id, 'sidebar_id' => 'frontman-visibility' ];
$result = $tool->update_widget( $input + [ 'settings' => '{"title":"<b>Viewed</b>","number":1}' ] );
remove_filter( 'widget_update_callback', $identity, 10 );
widget_check( 'Viewed' === $result['settings']['title'], 'Native title sanitation' );
widget_check( 'retained' === $result['settings']['extension_metadata'], 'Preserve extension metadata' );
widget_check( $original === get_option( 'widget_woocommerce_recently_viewed_products' )[3], 'Do not modify another instance' );
$reject_update = static function() { return false; };
add_filter( 'widget_update_callback', $reject_update );
$before = get_option( 'widget_woocommerce_recently_viewed_products' );
try {
	$tool->update_widget( $input + [ 'settings' => '{"title":"Rejected"}' ] );
	throw new RuntimeException( 'Native rejection ignored' );
} catch ( Frontman_Tool_Error $expected ) {
	widget_check( $before === get_option( 'widget_woocommerce_recently_viewed_products' ), 'Rejected native update wrote settings' );
}
remove_filter( 'widget_update_callback', $reject_update );
$sanitize = static function( $value, $new, $key ) {
	return 'title' === $key ? 'Native filtered title' : $value;
};
add_filter( 'woocommerce_widget_settings_sanitize_option', $sanitize, 10, 3 );
$filtered = $tool->update_widget( $input + [ 'settings' => '{"title":"Requested"}' ] );
widget_check( 'Native filtered title' === $filtered['settings']['title'], 'Native sanitation filter readback' );
remove_filter( 'woocommerce_widget_settings_sanitize_option', $sanitize, 10 );
foreach ( [ '{"number":0}', '{"number":16}', '{"number":"4"}', '{"title":false}', '{"arbitrary":"value"}' ] as $settings ) {
	$before = get_option( 'widget_woocommerce_recently_viewed_products' );
	try {
		$tool->update_widget( $input + [ 'settings' => $settings ] );
		throw new RuntimeException( 'Invalid settings accepted' );
	} catch ( Frontman_Tool_Error $expected ) {
		widget_check( $before === get_option( 'widget_woocommerce_recently_viewed_products' ), 'Invalid input changed settings' );
	}
}
$product = new WC_Product_Simple();
$product->set_name( 'History product' );
$product->set_status( 'publish' );
$product->set_regular_price( '10' );
$product_id = $product->save();
$cart = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'Cart' ] );
$checkout = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'Checkout' ] );
$other = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => 'Other' ] );
update_option( 'woocommerce_cart_page_id', $cart );
update_option( 'woocommerce_checkout_page_id', $checkout );
$render = static function( int $page ): string {
	$output = [];
	$status = 0;
	exec( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __FILE__ ) . ' --render ' . $page . ' ' . escapeshellarg( $_COOKIE['woocommerce_recently_viewed'] ?? '' ), $output, $status );
	widget_check( 0 === $status, 'Storefront render process failed' );
	return trim( implode( "\n", $output ) );
};
$_COOKIE['woocommerce_recently_viewed'] = (string) $product_id;
$tool->set_widget_visibility( [ 'widget_id' => $widget_id, 'visibility' => 'exclude_checkout' ] );
widget_check( false !== strpos( $render( $cart ), 'History product' ), 'History renders on semantic cart' );
$checkout_output = $render( $checkout );
widget_check( '' === $checkout_output, 'Checkout suppressed: ' . $checkout_output );
widget_check( false !== strpos( $render( $other ), 'History product' ), 'Exclusion preserves unrelated routes' );
$tool->set_widget_visibility( [ 'widget_id' => $widget_id, 'visibility' => 'cart_only' ] );
widget_check( false !== strpos( $render( $cart ), 'History product' ), 'Cart-only preserves populated history on cart' );
widget_check( '' === $render( $checkout ), 'Cart-only suppresses checkout' );
widget_check( '' === $render( $other ), 'Cart-only suppresses unrelated routes' );
widget_check( 'all' === $tool->read_widget( [ 'widget_id' => 'woocommerce_recently_viewed_products-3' ] )['visibility'], 'Sibling visibility remains unrestricted' );
unset( $_COOKIE['woocommerce_recently_viewed'] );
widget_check( '' === $render( $cart ), 'Empty history intentionally produces no output' );
$tool->set_widget_visibility( [ 'widget_id' => $widget_id, 'visibility' => 'all' ] );
widget_check( 'all' === $tool->read_widget( [ 'widget_id' => $widget_id ] )['visibility'], 'Rule is reversible' );
$_COOKIE['woocommerce_recently_viewed'] = (string) $product_id;
widget_check( false !== strpos( $render( $checkout ), 'History product' ), 'Clearing the rule restores checkout rendering' );
wp_set_current_user( 0 );
foreach ( [ 'set_widget_visibility' => [ 'widget_id' => $widget_id, 'visibility' => 'cart_only' ], 'update_widget' => $input + [ 'settings' => '{"number":2}' ] ] as $method => $args ) {
	try {
		$tool->$method( $args );
		throw new RuntimeException( 'Unauthorized mutation accepted' );
	} catch ( Frontman_Tool_Error $expected ) {
		widget_check( false !== strpos( $expected->getMessage(), 'edit_theme_options' ), 'Authorization rejected for correct reason' );
	}
}
echo "OK (native WooCommerce widget visibility)\n";
