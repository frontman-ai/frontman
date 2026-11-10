<?php

declare(strict_types=1);

frontman_runtime_assert( class_exists( 'WooCommerce' ), 'Real WooCommerce must be active for annotation coverage.' );
$woo_tools = Frontman_Tools::instance();

$actor = get_current_user_id();
$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$products = [];
$order = null;
$reviews = [];
$call = static function( string $name, array $input ) use ( $woo_tools ): array {
	$result = frontman_runtime_call( $woo_tools, $name, $input );
	frontman_runtime_same( false, $result['isError'], $name . ' succeeds: ' . $result['content'][0]['text'] );
	return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
};
try {
	$definitions = json_decode( wp_json_encode( $woo_tools->all_definitions() ), false, 512, JSON_THROW_ON_ERROR );
	$check_schema = static function( $value, string $path ) use ( &$check_schema ): void {
		if ( is_object( $value ) ) {
			if ( isset( $value->type ) && 'object' === $value->type ) {
				frontman_runtime_assert( isset( $value->properties ) && $value->properties instanceof stdClass, $path . ' properties must serialize as an object.' );
				foreach ( $value->required ?? [] as $field ) {
					frontman_runtime_assert( property_exists( $value->properties, $field ), $path . ' missing required property ' . $field );
				}
			}
			if ( isset( $value->type ) && 'array' === $value->type ) {
				frontman_runtime_assert( isset( $value->items ), $path . ' array must have items.' );
			}
			foreach ( get_object_vars( $value ) as $key => $child ) { $check_schema( $child, $path . '.' . $key ); }
		} elseif ( is_array( $value ) ) {
			foreach ( $value as $key => $child ) { $check_schema( $child, $path . '[' . $key . ']' ); }
		}
	};
	$names = [];
	foreach ( $definitions as $definition ) {
		if ( 0 !== strpos( $definition->name, 'wc_' ) ) { continue; }
		$names[] = $definition->name;
		$check_schema( $definition->inputSchema, $definition->name );
		if ( 0 === strpos( $definition->name, 'wc_maint_' ) ) {
			$schema = $definition->inputSchema;
			frontman_runtime_same( [ 'confirm' ], array_keys( get_object_vars( $schema->properties ) ), 'Maintenance schema exposes only confirmation.' );
			frontman_runtime_same( 'boolean', $schema->properties->confirm->type, 'Maintenance confirmation is boolean.' );
			frontman_runtime_same( [ 'confirm' ], $schema->required, 'Maintenance confirmation is required.' );
			frontman_runtime_same( false, $schema->additionalProperties, 'Maintenance rejects extra arguments.' );
		}
	}
	$expected = array_keys( frontman_runtime_woocommerce_annotations() );
	sort( $names );
	sort( $expected );
	frontman_runtime_same( $expected, $names, 'Complete WooCommerce catalog matches the independent reviewed inventory.' );
	foreach ( [ 'wc_get_system_status_tools', 'wc_run_system_status_tool' ] as $old ) {
		frontman_runtime_assert( ! in_array( $old, $names, true ), 'Old generic maintenance tool must not be registered: ' . $old );
	}
	for ( $i = 0; $i < 2; $i++ ) {
		$product = $call( 'wc_create_product', [ 'productData' => [ 'name' => 'Safety product', 'status' => 'draft', 'regular_price' => '10' ] ] );
		$products[] = $product['id'];
	}
	frontman_runtime_assert( $products[0] !== $products[1], 'Identical creates produce additional products.' );
	$id = $products[0];
	$description = '<p>Path C:\\tmp\\shirt and regex /\\d+/</p>';
	$forwarded = null;
	$observe_raw = static function( $result, $server, $request ) use ( &$forwarded ) {
		if ( 'POST' === $request->get_method() && '/wc/v3/products' === $request->get_route() ) {
			$forwarded = $request->get_param( 'description' );
		}
		return $result;
	};
	add_filter( 'rest_pre_dispatch', $observe_raw, 10, 3 );
	try {
		$raw = $call( 'wc_create_product', [ 'productData' => [ 'name' => 'Runtime raw', 'description' => $description, 'status' => 'draft' ] ] );
	} finally { remove_filter( 'rest_pre_dispatch', $observe_raw, 10 ); }
	$products[] = $raw['id'];
	frontman_runtime_same( $description, $forwarded, 'Product creation forwards HTML and backslashes to the native endpoint.' );
	$native_request = new WP_REST_Request( 'POST', '/wc/v3/products' );
	$native_request->set_header( 'Content-Type', 'application/json' );
	$native_request->set_body( wp_json_encode( [ 'name' => 'Native raw', 'description' => $description, 'status' => 'draft' ] ) );
	$native_response = rest_do_request( $native_request );
	frontman_runtime_assert( ! is_wp_error( $native_response ) && $native_response->get_status() < 400, 'Direct native product creation succeeds.' );
	$native_product = $native_response->get_data();
	$products[] = $native_product['id'];
	frontman_runtime_same( wc_get_product( $native_product['id'] )->get_description(), wc_get_product( $raw['id'] )->get_description(), 'Tool and direct native endpoint persist the same description.' );
	$found = $call( 'wc_get_products', [ 'perPage' => 1, 'page' => 2, 'filters' => [ 'status' => 'draft', 'search' => 'Safety product', 'orderby' => 'id', 'order' => 'asc' ] ] );
	frontman_runtime_same( [ $products[1] ], array_column( $found, 'id' ), 'Product filters and pagination select the second matching product.' );
	$gateway = $call( 'wc_get_payment_gateway', [ 'gatewayId' => 'bacs' ] );
	frontman_runtime_same( 'bacs', $gateway['id'], 'String gateway IDs select the native built-in gateway.' );
	$events = [];
	$observe = static function( $result, $server, $request ) use ( &$events, $id ) {
		if ( '/wc/v3/products/' . $id === $request->get_route() ) { $events[] = $request->get_method(); }
		return $result;
	};
	add_filter( 'rest_pre_dispatch', $observe, 10, 3 );
	try {
		$call( 'wc_update_product', [ 'productId' => $id, 'productData' => [ 'name' => 'Updated safety product' ], 'confirm' => true ] );
	} finally { remove_filter( 'rest_pre_dispatch', $observe, 10 ); }
	frontman_runtime_same( [ 'GET', 'PUT' ], $events, 'Native authorization read precedes product update.' );
	foreach ( [ [], [ 'confirm' => false ], [ 'confirm' => 'true' ], [ 'confirm' => 1 ] ] as $confirmation ) {
		foreach ( [
			[ 'wc_update_product', [ 'productId' => $id, 'productData' => [ 'name' => 'Must not save' ] ] ],
			[ 'wc_delete_product', [ 'productId' => $id, 'force' => true ] ],
		] as [ $tool, $input ] ) {
			$result = frontman_runtime_call( $woo_tools, $tool, $input + $confirmation );
			frontman_runtime_same( true, $result['isError'], $tool . ' rejects missing or non-literal confirmation.' );
			frontman_runtime_same( 'Updated safety product', wc_get_product( $id )->get_name(), $tool . ' rejection leaves the product intact.' );
		}
	}
	$review = $call( 'wc_create_product_review', [ 'productId' => $id, 'reviewData' => [ 'review' => 'Excellent runtime product', 'reviewer' => 'Runtime reviewer', 'reviewer_email' => 'reviewer@example.com', 'rating' => 5, 'status' => 'approved' ] ] );
	$reviews[] = $review['id'];
	$listed = $call( 'wc_get_product_reviews', [ 'productId' => $id ] );
	frontman_runtime_assert( in_array( $review['id'], array_column( $listed, 'id' ), true ), 'Native product review creation and product filtering work.' );
	$other_reviews = $call( 'wc_get_product_reviews', [ 'productId' => $products[1] ] );
	frontman_runtime_assert( ! in_array( $review['id'], array_column( $other_reviews, 'id' ), true ), 'Product review filter excludes reviews for another product.' );
	$before = wp_json_encode( wc_get_product( $id )->get_data() );
	$call( 'wc_get_product', [ 'productId' => $id ] );
	frontman_runtime_same( $before, wp_json_encode( wc_get_product( $id )->get_data() ), 'Product inspection does not change stored product state.' );
	foreach ( [ 'first', 'replacement' ] as $value ) {
		$call( 'wc_update_product_meta', [ 'productId' => $id, 'metaKey' => 'safety_review', 'metaValue' => $value, 'confirm' => true ] );
		frontman_runtime_same( $value, wc_get_product( $id )->get_meta( 'safety_review' ), 'Metadata update is an upsert, not an additive-only action.' );
	}
	$call( 'wc_delete_product_meta', [ 'productId' => $id, 'metaKey' => 'safety_review', 'confirm' => true ] );
	frontman_runtime_same( '', wc_get_product( $id )->get_meta( 'safety_review' ), 'Metadata deletion persists through WooCommerce CRUD.' );
	frontman_runtime_same( [], $call( 'wc_get_product_meta', [ 'productId' => $id, 'metaKey' => 'safety_review' ] ), 'Metadata deletion is visible through the native REST readback.' );
	$call( 'wc_update_product', [ 'productId' => $id, 'productData' => [ 'status' => 'publish' ], 'confirm' => true ] );
	frontman_runtime_same( 'publish', wc_get_product( $id )->get_status(), 'Product mutation can publish immediately.' );
	$url = wp_parse_url( get_permalink( $id ) );
	$public = frontman_runtime_http( 'GET', ( $url['path'] ?? '/' ) . ( isset( $url['query'] ) ? '?' . $url['query'] : '' ) );
	frontman_runtime_same( 200, $public['status'], 'Published product is publicly accessible.' );
	frontman_runtime_assert( false !== strpos( $public['body'], 'Updated safety product' ), 'Public output contains the published product.' );

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
	foreach ( [ [], [ 'confirm' => false ], [ 'confirm' => 'true' ], [ 'confirm' => true, 'toolId' => 'clear_sessions' ] ] as $input ) {
		$result = frontman_runtime_call( $woo_tools, 'wc_maint_clear_transients', $input );
		frontman_runtime_same( true, $result['isError'], 'Invalid maintenance request is rejected.' );
		frontman_runtime_same( [ $id ], get_transient( 'wc_products_onsale' ), 'Invalid maintenance request has no cache effect.' );
	}
	$user = wp_get_current_user();
	$user->add_cap( 'manage_woocommerce', false );
	try {
		$result = frontman_runtime_call( $woo_tools, 'wc_maint_clear_transients', [ 'confirm' => true ] );
		frontman_runtime_same( true, $result['isError'], 'Native maintenance capability denial is enforced.' );
		frontman_runtime_same( [ $id ], get_transient( 'wc_products_onsale' ), 'Denied maintenance has no cache effect.' );
	} finally { $user->remove_cap( 'manage_woocommerce' ); }
	$disable = static function( $native ) {
		$native['clear_transients']['disabled'] = true;
		return $native;
	};
	add_filter( 'woocommerce_debug_tools', $disable );
	try {
		$result = frontman_runtime_call( $woo_tools, 'wc_maint_clear_transients', [ 'confirm' => true ] );
		frontman_runtime_same( true, $result['isError'], 'A native tool disabled after discovery cannot run.' );
		frontman_runtime_same( [ $id ], get_transient( 'wc_products_onsale' ), 'Disabled maintenance has no cache effect.' );
	} finally { remove_filter( 'woocommerce_debug_tools', $disable ); }
	$events = [];
	$observe_maintenance = static function( $result, $server, $request ) use ( &$events ) {
		if ( 0 === strpos( $request->get_route(), '/wc/v3/system_status/tools' ) ) {
			$events[] = [ $request->get_method(), $request->get_route() ];
		}
		return $result;
	};
	add_filter( 'rest_pre_dispatch', $observe_maintenance, 10, 3 );
	try {
		$call( 'wc_maint_clear_transients', [ 'confirm' => true ] );
	} finally { remove_filter( 'rest_pre_dispatch', $observe_maintenance, 10 ); }
	frontman_runtime_same( [
		[ 'GET', '/wc/v3/system_status/tools/clear_transients' ],
		[ 'PUT', '/wc/v3/system_status/tools/clear_transients' ],
	], $events, 'Native maintenance authorization read precedes execution.' );
	frontman_runtime_same( false, get_transient( 'wc_products_onsale' ), 'Maintenance selection changes persistent cache state.' );

	$metadata = null;
	$extension = static function( $native ) use ( &$metadata ) {
		$native['frontman-test-cache'] = $native['clear_transients'];
		$native['frontman-test-cache']['callback'] = 'wc_delete_product_transients';
		if ( null !== $metadata ) { $native['frontman-test-cache']['frontman'] = $metadata; }
		return $native;
	};
	add_filter( 'woocommerce_debug_tools', $extension );
	try {
		set_transient( 'wc_products_onsale', [ $id ], 300 );
		$unannotated = new Frontman_Tools();
		( new Frontman_Tool_WooCommerce() )->register( $unannotated );
		frontman_runtime_same( null, $unannotated->get( 'wc_maint_frontman-test-cache' ), 'Unknown native actions without metadata are omitted.' );
		frontman_runtime_same( [ $id ], get_transient( 'wc_products_onsale' ), 'Unannotated discovery does not execute native callbacks.' );
		$metadata = [
			'description' => 'Clear the product cache for the runtime extension.',
			'annotations' => new Frontman_Tool_Annotations( false, true, false, false ),
		];
		$extended = new Frontman_Tools();
		( new Frontman_Tool_WooCommerce() )->register( $extended );
		$definition = $extended->get( 'wc_maint_frontman-test-cache' );
		frontman_runtime_assert( null !== $definition, 'Explicit metadata exposes the native extension action.' );
		$schema = json_decode( wp_json_encode( $definition->input_schema ), true, 512, JSON_THROW_ON_ERROR );
		frontman_runtime_same( [ 'confirm' ], array_keys( $schema['properties'] ), 'Extension maintenance has a fixed confirmation-only schema.' );
		frontman_runtime_same( [ 'confirm' ], $schema['required'], 'Extension confirmation is required.' );
		frontman_runtime_same( false, $schema['additionalProperties'], 'Extension rejects extra arguments.' );
		frontman_runtime_same( [ $id ], get_transient( 'wc_products_onsale' ), 'Annotated discovery does not execute native callbacks.' );
		$result = frontman_runtime_call( $extended, 'wc_maint_frontman-test-cache', [ 'confirm' => true ] );
		frontman_runtime_same( false, $result['isError'], 'Confirmed native extension succeeds.' );
		frontman_runtime_same( false, get_transient( 'wc_products_onsale' ), 'Confirmed extension invokes the real native callback.' );
		$metadata = [ 'description' => '', 'annotations' => 'invalid' ];
		try {
			( new Frontman_Tool_WooCommerce() )->register( new Frontman_Tools() );
			throw new RuntimeException( 'Malformed explicit maintenance metadata was accepted.' );
		} catch ( LogicException $error ) {
			frontman_runtime_assert( false !== strpos( $error->getMessage(), 'frontman-test-cache' ), 'Invalid metadata identifies the native action.' );
		}
	} finally {
		remove_filter( 'woocommerce_debug_tools', $extension );
		delete_transient( 'wc_products_onsale' );
	}
} finally {
	foreach ( $reviews as $review_id ) { wp_delete_comment( $review_id, true ); }
	foreach ( $products as $id ) { $product = wc_get_product( $id ); if ( $product ) { $product->delete( true ); } }
	if ( $order instanceof WC_Order ) {
		foreach ( wc_get_order( $order->get_id() )->get_refunds() as $refund ) { $refund->delete( true ); }
		$order->delete( true );
	}
	wp_set_current_user( $actor );
}
fwrite( STDOUT, "OK (reviewed WooCommerce catalog, real CRUD, publication, refunds and maintenance)\n" );
