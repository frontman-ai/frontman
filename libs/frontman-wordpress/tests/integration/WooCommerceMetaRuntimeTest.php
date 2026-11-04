<?php

frontman_runtime_assert( class_exists( 'WooCommerce' ), 'WooCommerce must be active for metadata cases.' );
$tools = Frontman_Tools::instance();
$names = array_column( $tools->all_definitions(), 'name' );
foreach ( [ 'product', 'order', 'customer' ] as $entity ) {
	frontman_runtime_assert( ! in_array( 'wc_create_' . $entity . '_meta', $names, true ), 'Metadata create alias remains registered for ' . $entity );
	frontman_runtime_assert( in_array( 'wc_update_' . $entity . '_meta', $names, true ), 'Metadata update tool missing for ' . $entity );
}

$admin = get_user_by( 'login', 'admin' );
frontman_runtime_assert( $admin instanceof WP_User, 'WordPress administrator is missing.' );
wp_set_current_user( $admin->ID );
$cookie = wp_generate_auth_cookie( $admin->ID, time() + HOUR_IN_SECONDS, 'logged_in' );
$_COOKIE[ LOGGED_IN_COOKIE ] = $cookie;
$nonce = Frontman_Auth::create_nonce();
unset( $_COOKIE[ LOGGED_IN_COOKIE ] );
$call = static function( string $name, array $arguments ) use ( $cookie, $nonce ): array {
	$response = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => $arguments ] );
	frontman_runtime_same( 200, $response['status'], $name . ' HTTP status' );
	frontman_runtime_same( false, $response['body']['isError'], $name . ' failed' );
	return json_decode( $response['body']['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};

$product = null;
$order = null;
$customer = null;
try {
	$product = new WC_Product_Simple();
	$product->set_name( 'Metadata product fixture' );
	$product->set_status( 'publish' );
	$product->set_regular_price( '12' );
	$product->save();
	$order = wc_create_order();
	frontman_runtime_assert( $order instanceof WC_Order, 'Could not create metadata order.' );
	$customer = new WC_Customer();
	$customer->set_username( 'frontman-meta-' . wp_generate_password( 12, false ) );
	$customer->set_email( $customer->get_username() . '@example.com' );
	$customer->set_password( wp_generate_password() );
	$customer->save();

	foreach ( [
		[ 'product', 'productId', $product ],
		[ 'order', 'orderId', $order ],
		[ 'customer', 'customerId', $customer ],
	] as [ $entity, $id_key, $object ] ) {
		$input = [ $id_key => $object->get_id(), 'metaKey' => 'frontman_upsert', 'confirm' => true ];
		$meta_id = null;
		foreach ( [ 'created', 'updated' ] as $value ) {
			$call( 'wc_update_' . $entity . '_meta', $input + [ 'metaValue' => $value ] );
			$all_meta = $call( 'wc_get_' . $entity . '_meta', [ $id_key => $object->get_id() ] );
			$matches = array_values( array_filter( $all_meta, static fn( $entry ) => 'frontman_upsert' === ( $entry['key'] ?? null ) ) );
			frontman_runtime_same( 1, count( $matches ), 'Metadata key count for ' . $entity );
			frontman_runtime_same( $value, $matches[0]['value'], 'Metadata value for ' . $entity );
			if ( null !== $meta_id ) {
				frontman_runtime_same( $meta_id, $matches[0]['id'], 'Metadata update created a duplicate key for ' . $entity );
			}
			$meta_id = $matches[0]['id'];
		}
	}
} finally {
	if ( $product instanceof WC_Product ) {
		$product->delete( true );
	}
	if ( $order instanceof WC_Order ) {
		$order->delete( true );
	}
	if ( $customer instanceof WC_Customer && $customer->get_id() ) {
		$customer->delete( true );
	}
}
