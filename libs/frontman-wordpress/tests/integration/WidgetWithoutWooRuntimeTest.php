<?php
/** Real WordPress without WooCommerce; run in a separate request before activation. */
require '/var/www/html/wp-load.php';
if ( function_exists( 'is_cart' ) || function_exists( 'is_checkout' ) ) {
	throw new RuntimeException( 'This test requires WooCommerce to be inactive.' );
}
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
update_option( 'widget_text', [ 2 => [ 'title' => 'Preserved', 'text' => 'Content' ], '_multiwidget' => 1 ] );
$tool = new Frontman_Tool_Widgets();
$widget = new WP_Widget_Text();
$widget->_set( 2 );
foreach ( [ 'cart_only' => false, 'exclude_checkout' => [ 'title' => 'Preserved' ] ] as $rule => $expected ) {
	update_option( 'frontman_widget_visibility', [ 'text-2' => $rule ] );
	$actual = apply_filters( 'widget_display_callback', [ 'title' => 'Preserved' ], $widget, [ 'widget_id' => 'text-2' ] );
	if ( $actual !== $expected ) {
		throw new RuntimeException( 'Incorrect missing-WooCommerce behavior for ' . $rule );
	}
}
try {
	$tool->set_widget_visibility( [ 'widget_id' => 'text-2', 'visibility' => 'cart_only' ] );
	throw new RuntimeException( 'Accepted WooCommerce rule without WooCommerce' );
} catch ( Frontman_Tool_Error $expected ) {
	if ( false === strpos( $expected->getMessage(), 'WooCommerce' ) ) {
		throw $expected;
	}
}
$tool->set_widget_visibility( [ 'widget_id' => 'text-2', 'visibility' => 'all' ] );
if ( [] !== get_option( 'frontman_widget_visibility' ) ) {
	throw new RuntimeException( 'Cannot clear rules without WooCommerce' );
}
echo "OK (widget visibility without WooCommerce)\n";
