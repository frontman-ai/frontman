<?php

declare(strict_types=1);

frontman_runtime_assert( class_exists( 'WooCommerce' ), 'Real WooCommerce must be active for annotation coverage.' );
$woo_tools = Frontman_Tools::instance();

$actor = get_current_user_id();
$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$products = [];
$order = null;
$call = static function( string $name, array $input ) use ( $woo_tools ): array {
	$result = frontman_runtime_call( $woo_tools, $name, $input );
	frontman_runtime_same( false, $result['isError'], $name . ' succeeds: ' . $result['content'][0]['text'] );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
try {
	for ( $i = 0; $i < 2; $i++ ) {
		$product = $call( 'wc_create_product', [ 'productData' => [ 'name' => 'Safety product', 'status' => 'draft', 'regular_price' => '10' ] ] );
		$products[] = $product['id'];
	}
	frontman_runtime_assert( $products[0] !== $products[1], 'Identical creates produce additional products.' );
	$id = $products[0];
	$before = wp_json_encode( wc_get_product( $id )->get_data() );
	$call( 'wc_get_product', [ 'productId' => $id ] );
	frontman_runtime_same( $before, wp_json_encode( wc_get_product( $id )->get_data() ), 'Product inspection does not change stored product state.' );
	foreach ( [ 'first', 'replacement' ] as $value ) {
		$call( 'wc_update_product_meta', [ 'productId' => $id, 'metaKey' => 'safety_review', 'metaValue' => $value, 'confirm' => true ] );
		frontman_runtime_same( $value, wc_get_product( $id )->get_meta( 'safety_review' ), 'Metadata update is an upsert, not an additive-only action.' );
	}
	$call( 'wc_update_product', [ 'productId' => $id, 'productData' => [ 'status' => 'publish' ], 'confirm' => true ] );
	frontman_runtime_same( 'publish', wc_get_product( $id )->get_status(), 'Product mutation can publish immediately.' );
	$url = wp_parse_url( get_permalink( $id ) );
	$public = frontman_runtime_http( 'GET', ( $url['path'] ?? '/' ) . ( isset( $url['query'] ) ? '?' . $url['query'] : '' ) );
	frontman_runtime_same( 200, $public['status'], 'Published product is publicly accessible.' );
	frontman_runtime_assert( false !== strpos( $public['body'], 'Safety product' ), 'Public output contains the published product.' );

	$order = wc_create_order();
	frontman_runtime_assert( $order instanceof WC_Order, 'Create a disposable native order.' );
	$order->set_total( '100' );
	$order->save();
	$refunds = [];
	for ( $i = 0; $i < 2; $i++ ) {
		$refund = $call( 'wc_create_order_refund', [
			'orderId' => $order->get_id(),
			'refundData' => [ 'amount' => '1.00', 'reason' => 'Annotation runtime', 'api_refund' => false, 'api_restock' => false ],
		] );
		$refunds[] = $refund['id'];
	}
	frontman_runtime_assert( $refunds[0] !== $refunds[1], 'Repeated identical refunds create distinct financial records.' );
	frontman_runtime_same( 2.0, (float) wc_get_order( $order->get_id() )->get_total_refunded(), 'Both refund records affect the order total refunded.' );
	$call( 'wc_delete_order_refund', [ 'orderId' => $order->get_id(), 'refundId' => $refunds[0], 'confirm' => true ] );
	frontman_runtime_same( false, wc_get_order( $refunds[0] ), 'Refund deletion removes the actual refund record.' );

	set_transient( 'wc_products_onsale', [ $id ], 300 );
	$call( 'wc_run_system_status_tool', [ 'toolId' => 'clear_transients', 'confirm' => true ] );
	frontman_runtime_same( false, get_transient( 'wc_products_onsale' ), 'Maintenance selection changes persistent cache state.' );
} finally {
	foreach ( $products as $id ) { $product = wc_get_product( $id ); if ( $product ) { $product->delete( true ); } }
	if ( $order instanceof WC_Order ) {
		foreach ( wc_get_order( $order->get_id() )->get_refunds() as $refund ) { $refund->delete( true ); }
		$order->delete( true );
	}
	wp_set_current_user( $actor );
}
fwrite( STDOUT, "OK (111 WooCommerce annotations, real discovery, publication, upserts, refunds and maintenance)\n" );
