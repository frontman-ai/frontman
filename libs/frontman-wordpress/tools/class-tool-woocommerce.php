<?php
/**
 * WooCommerce tools backed by WooCommerce's own REST API routes.
 *
 * The tool set mirrors the WooCommerce methods exposed by
 * https://github.com/techspawn/woocommerce-mcp-server, with Frontman-local
 * namespacing (`wc_*`) and cookie-authenticated in-process REST dispatch.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_WooCommerce {
	private const REST_NAMESPACE = '/wc/v3';

	/**
	 * Register all WooCommerce tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$this->register_products( $tools );
		$this->register_product_taxonomies( $tools );
		$this->register_product_attributes( $tools );
		$this->register_product_variations( $tools );
		$this->register_product_reviews( $tools );
		$this->register_orders( $tools );
		$this->register_order_notes( $tools );
		$this->register_order_refunds( $tools );
		$this->register_customers( $tools );
		$this->register_shipping( $tools );
		$this->register_taxes( $tools );
		$this->register_coupons( $tools );
		$this->register_payment_gateways( $tools );
		$this->register_reports( $tools );
		$this->register_settings( $tools );
		$this->register_system_status( $tools );
		$this->register_data( $tools );
	}

	private function register_products( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_products', 'Retrieves WooCommerce products with pagination and filters.', 'GET', '/products', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product', 'Gets one WooCommerce product by ID.', 'GET', '/products/{productId}', $this->id_schema( 'productId', 'The product ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_product', 'Creates a WooCommerce product.', 'POST', '/products', $this->data_schema( 'productData', 'WooCommerce product fields to create.', [ 'productData' ] ), [ 'body' => 'productData' ] );
		$this->add_endpoint_tool( $tools, 'update_product', 'Updates a WooCommerce product.', 'PUT', '/products/{productId}', $this->data_schema( 'productData', 'WooCommerce product fields to update.', [ 'productId', 'productData' ], [ 'productId' => $this->integer_prop( 'The product ID.' ) ] ), [ 'body' => 'productData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product', 'Deletes a WooCommerce product. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/{productId}', $this->delete_schema( 'productId', 'The product ID.' ), [ 'confirm' => true, 'force_default' => false ] );

		$this->add_meta_tools( $tools, 'product', 'productId', '/products/{productId}' );
	}

	private function register_product_taxonomies( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_product_categories', 'Retrieves WooCommerce product categories.', 'GET', '/products/categories', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product_category', 'Gets one WooCommerce product category.', 'GET', '/products/categories/{categoryId}', $this->id_schema( 'categoryId', 'The product category ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_product_category', 'Creates a WooCommerce product category.', 'POST', '/products/categories', $this->data_schema( 'categoryData', 'Product category fields to create.', [ 'categoryData' ] ), [ 'body' => 'categoryData' ] );
		$this->add_endpoint_tool( $tools, 'update_product_category', 'Updates a WooCommerce product category.', 'PUT', '/products/categories/{categoryId}', $this->data_schema( 'categoryData', 'Product category fields to update.', [ 'categoryId', 'categoryData' ], [ 'categoryId' => $this->integer_prop( 'The product category ID.' ) ] ), [ 'body' => 'categoryData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product_category', 'Deletes a WooCommerce product category. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/categories/{categoryId}', $this->delete_schema( 'categoryId', 'The product category ID.' ), [ 'confirm' => true, 'force_default' => true ] );

		$this->add_endpoint_tool( $tools, 'get_product_tags', 'Retrieves WooCommerce product tags.', 'GET', '/products/tags', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product_tag', 'Gets one WooCommerce product tag.', 'GET', '/products/tags/{tagId}', $this->id_schema( 'tagId', 'The product tag ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_product_tag', 'Creates a WooCommerce product tag.', 'POST', '/products/tags', $this->data_schema( 'tagData', 'Product tag fields to create.', [ 'tagData' ] ), [ 'body' => 'tagData' ] );
		$this->add_endpoint_tool( $tools, 'update_product_tag', 'Updates a WooCommerce product tag.', 'PUT', '/products/tags/{tagId}', $this->data_schema( 'tagData', 'Product tag fields to update.', [ 'tagId', 'tagData' ], [ 'tagId' => $this->integer_prop( 'The product tag ID.' ) ] ), [ 'body' => 'tagData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product_tag', 'Deletes a WooCommerce product tag. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/tags/{tagId}', $this->delete_schema( 'tagId', 'The product tag ID.' ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_product_attributes( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_product_attributes', 'Retrieves WooCommerce product attributes.', 'GET', '/products/attributes', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product_attribute', 'Gets one WooCommerce product attribute.', 'GET', '/products/attributes/{attributeId}', $this->id_schema( 'attributeId', 'The product attribute ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_product_attribute', 'Creates a WooCommerce product attribute.', 'POST', '/products/attributes', $this->data_schema( 'attributeData', 'Product attribute fields to create.', [ 'attributeData' ] ), [ 'body' => 'attributeData' ] );
		$this->add_endpoint_tool( $tools, 'update_product_attribute', 'Updates a WooCommerce product attribute.', 'PUT', '/products/attributes/{attributeId}', $this->data_schema( 'attributeData', 'Product attribute fields to update.', [ 'attributeId', 'attributeData' ], [ 'attributeId' => $this->integer_prop( 'The product attribute ID.' ) ] ), [ 'body' => 'attributeData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product_attribute', 'Deletes a WooCommerce product attribute. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/attributes/{attributeId}', $this->delete_schema( 'attributeId', 'The product attribute ID.' ), [ 'confirm' => true, 'force_default' => true ] );

		$term_ids = [
			'attributeId' => $this->integer_prop( 'The product attribute ID.' ),
			'termId'      => $this->integer_prop( 'The attribute term ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_attribute_terms', 'Retrieves terms for a WooCommerce product attribute.', 'GET', '/products/attributes/{attributeId}/terms', $this->object_schema( [ 'attributeId' => $this->integer_prop( 'The product attribute ID.' ), 'perPage' => $this->integer_prop( 'Number of results per page.' ), 'page' => $this->integer_prop( 'Page number.' ), 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ], [ 'attributeId' ] ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_attribute_term', 'Gets one term for a WooCommerce product attribute.', 'GET', '/products/attributes/{attributeId}/terms/{termId}', $this->object_schema( $term_ids, [ 'attributeId', 'termId' ] ) );
		$this->add_endpoint_tool( $tools, 'create_attribute_term', 'Creates a term for a WooCommerce product attribute.', 'POST', '/products/attributes/{attributeId}/terms', $this->data_schema( 'termData', 'Attribute term fields to create.', [ 'attributeId', 'termData' ], [ 'attributeId' => $this->integer_prop( 'The product attribute ID.' ) ] ), [ 'body' => 'termData' ] );
		$this->add_endpoint_tool( $tools, 'update_attribute_term', 'Updates a term for a WooCommerce product attribute.', 'PUT', '/products/attributes/{attributeId}/terms/{termId}', $this->data_schema( 'termData', 'Attribute term fields to update.', [ 'attributeId', 'termId', 'termData' ], $term_ids ), [ 'body' => 'termData' ] );
		$this->add_endpoint_tool( $tools, 'delete_attribute_term', 'Deletes a term from a WooCommerce product attribute. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/attributes/{attributeId}/terms/{termId}', $this->delete_schema_with_ids( $term_ids, [ 'attributeId', 'termId' ] ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_product_variations( Frontman_Tools $tools ): void {
		$ids = [
			'productId'   => $this->integer_prop( 'The parent product ID.' ),
			'variationId' => $this->integer_prop( 'The product variation ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_product_variations', 'Retrieves variations for a WooCommerce product.', 'GET', '/products/{productId}/variations', $this->object_schema( [ 'productId' => $this->integer_prop( 'The parent product ID.' ), 'perPage' => $this->integer_prop( 'Number of results per page.' ), 'page' => $this->integer_prop( 'Page number.' ), 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ], [ 'productId' ] ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product_variation', 'Gets one WooCommerce product variation.', 'GET', '/products/{productId}/variations/{variationId}', $this->object_schema( $ids, [ 'productId', 'variationId' ] ) );
		$this->add_endpoint_tool( $tools, 'create_product_variation', 'Creates a variation for a WooCommerce product.', 'POST', '/products/{productId}/variations', $this->data_schema( 'variationData', 'Variation fields to create.', [ 'productId', 'variationData' ], [ 'productId' => $this->integer_prop( 'The parent product ID.' ) ] ), [ 'body' => 'variationData' ] );
		$this->add_endpoint_tool( $tools, 'update_product_variation', 'Updates a WooCommerce product variation.', 'PUT', '/products/{productId}/variations/{variationId}', $this->data_schema( 'variationData', 'Variation fields to update.', [ 'productId', 'variationId', 'variationData' ], $ids ), [ 'body' => 'variationData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product_variation', 'Deletes a WooCommerce product variation. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/{productId}/variations/{variationId}', $this->delete_schema_with_ids( $ids, [ 'productId', 'variationId' ] ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_product_reviews( Frontman_Tools $tools ): void {
		$review_props = [
			'productId' => $this->integer_prop( 'Optional product ID. When omitted, uses the global product reviews endpoint.' ),
			'reviewId'  => $this->integer_prop( 'The product review ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_product_reviews', 'Retrieves WooCommerce product reviews, optionally scoped to one product.', 'GET', '/products/reviews', $this->object_schema( [ 'productId' => $review_props['productId'], 'perPage' => $this->integer_prop( 'Number of results per page.' ), 'page' => $this->integer_prop( 'Page number.' ), 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ] ), [ 'paged' => true, 'filters' => true, 'product_filter' => true ] );
		$this->add_endpoint_tool( $tools, 'get_product_review', 'Gets one WooCommerce product review.', 'GET', '/products/reviews/{reviewId}', $this->object_schema( $review_props, [ 'reviewId' ] ) );
		$this->add_endpoint_tool( $tools, 'create_product_review', 'Creates a WooCommerce product review.', 'POST', '/products/reviews', $this->data_schema( 'reviewData', 'Product review fields to create.', [ 'productId', 'reviewData' ], [ 'productId' => $review_props['productId'] ] ), [ 'body' => 'reviewData', 'body_product_id' => 'productId' ] );
		$this->add_endpoint_tool( $tools, 'update_product_review', 'Updates a WooCommerce product review.', 'PUT', '/products/reviews/{reviewId}', $this->data_schema( 'reviewData', 'Product review fields to update.', [ 'reviewId', 'reviewData' ], $review_props ), [ 'body' => 'reviewData' ] );
		$this->add_endpoint_tool( $tools, 'delete_product_review', 'Deletes a WooCommerce product review. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/products/reviews/{reviewId}', $this->delete_schema_with_ids( $review_props, [ 'reviewId' ] ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_orders( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_orders', 'Retrieves WooCommerce orders with pagination and filters.', 'GET', '/orders', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_order', 'Gets one WooCommerce order by ID.', 'GET', '/orders/{orderId}', $this->id_schema( 'orderId', 'The order ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_order', 'Creates a WooCommerce order.', 'POST', '/orders', $this->data_schema( 'orderData', 'WooCommerce order fields to create.', [ 'orderData' ] ), [ 'body' => 'orderData' ] );
		$this->add_endpoint_tool( $tools, 'update_order', 'Updates a WooCommerce order.', 'PUT', '/orders/{orderId}', $this->data_schema( 'orderData', 'WooCommerce order fields to update.', [ 'orderId', 'orderData' ], [ 'orderId' => $this->integer_prop( 'The order ID.' ) ] ), [ 'body' => 'orderData' ] );
		$this->add_endpoint_tool( $tools, 'delete_order', 'Deletes a WooCommerce order. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/orders/{orderId}', $this->delete_schema( 'orderId', 'The order ID.' ), [ 'confirm' => true, 'force_default' => false ] );

		$this->add_meta_tools( $tools, 'order', 'orderId', '/orders/{orderId}' );
	}

	private function register_order_notes( Frontman_Tools $tools ): void {
		$ids = [
			'orderId' => $this->integer_prop( 'The order ID.' ),
			'noteId'  => $this->integer_prop( 'The order note ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_order_notes', 'Retrieves notes for a WooCommerce order.', 'GET', '/orders/{orderId}/notes', $this->object_schema( [ 'orderId' => $ids['orderId'], 'perPage' => $this->integer_prop( 'Number of results per page.' ), 'page' => $this->integer_prop( 'Page number.' ), 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ], [ 'orderId' ] ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_order_note', 'Gets one note for a WooCommerce order.', 'GET', '/orders/{orderId}/notes/{noteId}', $this->object_schema( $ids, [ 'orderId', 'noteId' ] ) );
		$this->add_endpoint_tool( $tools, 'create_order_note', 'Creates a note for a WooCommerce order.', 'POST', '/orders/{orderId}/notes', $this->data_schema( 'noteData', 'Order note fields to create.', [ 'orderId', 'noteData' ], [ 'orderId' => $ids['orderId'] ] ), [ 'body' => 'noteData' ] );
		$this->add_endpoint_tool( $tools, 'delete_order_note', 'Deletes a note from a WooCommerce order. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/orders/{orderId}/notes/{noteId}', $this->delete_schema_with_ids( $ids, [ 'orderId', 'noteId' ] ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_order_refunds( Frontman_Tools $tools ): void {
		$ids = [
			'orderId'  => $this->integer_prop( 'The order ID.' ),
			'refundId' => $this->integer_prop( 'The refund ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_order_refunds', 'Retrieves refunds for a WooCommerce order.', 'GET', '/orders/{orderId}/refunds', $this->object_schema( [ 'orderId' => $ids['orderId'], 'perPage' => $this->integer_prop( 'Number of results per page.' ), 'page' => $this->integer_prop( 'Page number.' ), 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ], [ 'orderId' ] ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_order_refund', 'Gets one WooCommerce order refund.', 'GET', '/orders/{orderId}/refunds/{refundId}', $this->object_schema( $ids, [ 'orderId', 'refundId' ] ) );
		$this->add_endpoint_tool( $tools, 'create_order_refund', 'Creates a refund for a WooCommerce order.', 'POST', '/orders/{orderId}/refunds', $this->data_schema( 'refundData', 'Refund fields to create.', [ 'orderId', 'refundData' ], [ 'orderId' => $ids['orderId'] ] ), [ 'body' => 'refundData' ] );
		$this->add_endpoint_tool( $tools, 'delete_order_refund', 'Deletes a WooCommerce order refund. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/orders/{orderId}/refunds/{refundId}', $this->delete_schema_with_ids( $ids, [ 'orderId', 'refundId' ] ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_customers( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_customers', 'Retrieves WooCommerce customers with pagination and filters.', 'GET', '/customers', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_customer', 'Gets one WooCommerce customer by ID.', 'GET', '/customers/{customerId}', $this->id_schema( 'customerId', 'The customer ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_customer', 'Creates a WooCommerce customer.', 'POST', '/customers', $this->data_schema( 'customerData', 'WooCommerce customer fields to create.', [ 'customerData' ] ), [ 'body' => 'customerData' ] );
		$this->add_endpoint_tool( $tools, 'update_customer', 'Updates a WooCommerce customer.', 'PUT', '/customers/{customerId}', $this->data_schema( 'customerData', 'WooCommerce customer fields to update.', [ 'customerId', 'customerData' ], [ 'customerId' => $this->integer_prop( 'The customer ID.' ) ] ), [ 'body' => 'customerData' ] );
		$this->add_endpoint_tool( $tools, 'delete_customer', 'Deletes a WooCommerce customer. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/customers/{customerId}', $this->delete_schema( 'customerId', 'The customer ID.' ), [ 'confirm' => true, 'force_default' => false ] );

		$this->add_meta_tools( $tools, 'customer', 'customerId', '/customers/{customerId}' );
	}

	private function register_shipping( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_shipping_zones', 'Retrieves WooCommerce shipping zones.', 'GET', '/shipping/zones', $this->object_schema( [ 'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters.' ) ] ), [ 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_shipping_zone', 'Gets one WooCommerce shipping zone.', 'GET', '/shipping/zones/{zoneId}', $this->id_schema( 'zoneId', 'The shipping zone ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_shipping_zone', 'Creates a WooCommerce shipping zone.', 'POST', '/shipping/zones', $this->data_schema( 'zoneData', 'Shipping zone fields to create.', [ 'zoneData' ] ), [ 'body' => 'zoneData' ] );
		$this->add_endpoint_tool( $tools, 'update_shipping_zone', 'Updates a WooCommerce shipping zone.', 'PUT', '/shipping/zones/{zoneId}', $this->data_schema( 'zoneData', 'Shipping zone fields to update.', [ 'zoneId', 'zoneData' ], [ 'zoneId' => $this->integer_prop( 'The shipping zone ID.' ) ] ), [ 'body' => 'zoneData' ] );
		$this->add_endpoint_tool( $tools, 'delete_shipping_zone', 'Deletes a WooCommerce shipping zone. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/shipping/zones/{zoneId}', $this->delete_schema( 'zoneId', 'The shipping zone ID.' ), [ 'confirm' => true, 'force_default' => true ] );

		$method_ids = [
			'zoneId'     => $this->integer_prop( 'The shipping zone ID.' ),
			'instanceId' => $this->integer_prop( 'The shipping method instance ID.' ),
		];

		$this->add_endpoint_tool( $tools, 'get_shipping_methods', 'Retrieves available WooCommerce shipping methods.', 'GET', '/shipping_methods', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_shipping_zone_methods', 'Retrieves shipping methods for one WooCommerce shipping zone.', 'GET', '/shipping/zones/{zoneId}/methods', $this->id_schema( 'zoneId', 'The shipping zone ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_shipping_zone_method', 'Creates a shipping method in a WooCommerce shipping zone.', 'POST', '/shipping/zones/{zoneId}/methods', $this->data_schema( 'methodData', 'Shipping method fields to create.', [ 'zoneId', 'methodData' ], [ 'zoneId' => $method_ids['zoneId'] ] ), [ 'body' => 'methodData' ] );
		$this->add_endpoint_tool( $tools, 'update_shipping_zone_method', 'Updates a shipping method in a WooCommerce shipping zone.', 'PUT', '/shipping/zones/{zoneId}/methods/{instanceId}', $this->data_schema( 'methodData', 'Shipping method fields to update.', [ 'zoneId', 'instanceId', 'methodData' ], $method_ids ), [ 'body' => 'methodData' ] );
		$this->add_endpoint_tool( $tools, 'delete_shipping_zone_method', 'Deletes a shipping method from a WooCommerce shipping zone. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/shipping/zones/{zoneId}/methods/{instanceId}', $this->delete_schema_with_ids( $method_ids, [ 'zoneId', 'instanceId' ] ), [ 'confirm' => true, 'force_default' => true ] );
		$this->add_endpoint_tool( $tools, 'get_shipping_zone_locations', 'Retrieves locations assigned to a WooCommerce shipping zone.', 'GET', '/shipping/zones/{zoneId}/locations', $this->id_schema( 'zoneId', 'The shipping zone ID.' ) );
		$this->add_endpoint_tool( $tools, 'update_shipping_zone_locations', 'Updates locations assigned to a WooCommerce shipping zone.', 'PUT', '/shipping/zones/{zoneId}/locations', $this->object_schema( [ 'zoneId' => $method_ids['zoneId'], 'locations' => $this->array_of_objects_prop( 'Shipping zone location objects.' ) ], [ 'zoneId', 'locations' ] ), [ 'body' => 'locations' ] );
	}

	private function register_taxes( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_tax_classes', 'Retrieves WooCommerce tax classes.', 'GET', '/taxes/classes', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'create_tax_class', 'Creates a WooCommerce tax class.', 'POST', '/taxes/classes', $this->data_schema( 'taxClassData', 'Tax class fields to create.', [ 'taxClassData' ] ), [ 'body' => 'taxClassData' ] );
		$this->add_endpoint_tool( $tools, 'delete_tax_class', 'Deletes a WooCommerce tax class. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/taxes/classes/{slug}', $this->delete_schema_with_ids( [ 'slug' => $this->string_prop( 'The tax class slug.' ) ], [ 'slug' ] ), [ 'confirm' => true, 'force_default' => true, 'read_before_write' => '/taxes/classes' ] );

		$this->add_endpoint_tool( $tools, 'get_tax_rates', 'Retrieves WooCommerce tax rates.', 'GET', '/taxes', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_tax_rate', 'Gets one WooCommerce tax rate.', 'GET', '/taxes/{rateId}', $this->id_schema( 'rateId', 'The tax rate ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_tax_rate', 'Creates a WooCommerce tax rate.', 'POST', '/taxes', $this->data_schema( 'taxRateData', 'Tax rate fields to create.', [ 'taxRateData' ] ), [ 'body' => 'taxRateData' ] );
		$this->add_endpoint_tool( $tools, 'update_tax_rate', 'Updates a WooCommerce tax rate.', 'PUT', '/taxes/{rateId}', $this->data_schema( 'taxRateData', 'Tax rate fields to update.', [ 'rateId', 'taxRateData' ], [ 'rateId' => $this->integer_prop( 'The tax rate ID.' ) ] ), [ 'body' => 'taxRateData' ] );
		$this->add_endpoint_tool( $tools, 'delete_tax_rate', 'Deletes a WooCommerce tax rate. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/taxes/{rateId}', $this->delete_schema( 'rateId', 'The tax rate ID.' ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_coupons( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_coupons', 'Retrieves WooCommerce coupons with pagination and filters.', 'GET', '/coupons', $this->list_schema(), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_coupon', 'Gets one WooCommerce coupon by ID.', 'GET', '/coupons/{couponId}', $this->id_schema( 'couponId', 'The coupon ID.' ) );
		$this->add_endpoint_tool( $tools, 'create_coupon', 'Creates a WooCommerce coupon.', 'POST', '/coupons', $this->data_schema( 'couponData', 'Coupon fields to create.', [ 'couponData' ] ), [ 'body' => 'couponData' ] );
		$this->add_endpoint_tool( $tools, 'update_coupon', 'Updates a WooCommerce coupon.', 'PUT', '/coupons/{couponId}', $this->data_schema( 'couponData', 'Coupon fields to update.', [ 'couponId', 'couponData' ], [ 'couponId' => $this->integer_prop( 'The coupon ID.' ) ] ), [ 'body' => 'couponData' ] );
		$this->add_endpoint_tool( $tools, 'delete_coupon', 'Deletes a WooCommerce coupon. Ask the user for confirmation before calling with confirm=true.', 'DELETE', '/coupons/{couponId}', $this->delete_schema( 'couponId', 'The coupon ID.' ), [ 'confirm' => true, 'force_default' => true ] );
	}

	private function register_payment_gateways( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_payment_gateways', 'Retrieves WooCommerce payment gateways.', 'GET', '/payment_gateways', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_payment_gateway', 'Gets one WooCommerce payment gateway.', 'GET', '/payment_gateways/{gatewayId}', $this->object_schema( [ 'gatewayId' => $this->string_prop( 'The payment gateway ID.' ) ], [ 'gatewayId' ] ) );
		$this->add_endpoint_tool( $tools, 'update_payment_gateway', 'Updates a WooCommerce payment gateway.', 'PUT', '/payment_gateways/{gatewayId}', $this->data_schema( 'gatewayData', 'Payment gateway fields to update.', [ 'gatewayId', 'gatewayData' ], [ 'gatewayId' => $this->string_prop( 'The payment gateway ID.' ) ] ), [ 'body' => 'gatewayData' ] );
	}

	private function register_reports( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_sales_report', 'Retrieves WooCommerce sales reports.', 'GET', '/reports/sales', $this->report_schema( false, true ), [ 'period' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_products_report', 'Retrieves WooCommerce products reports.', 'GET', '/reports/products', $this->report_schema( true, true ), [ 'period' => true, 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_orders_report', 'Retrieves WooCommerce orders reports.', 'GET', '/reports/orders', $this->report_schema( true, true ), [ 'period' => true, 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_categories_report', 'Retrieves WooCommerce categories reports.', 'GET', '/reports/categories', $this->report_schema( true, false ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_customers_report', 'Retrieves WooCommerce customers reports.', 'GET', '/reports/customers', $this->report_schema( true, false ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_stock_report', 'Retrieves WooCommerce stock reports.', 'GET', '/reports/stock', $this->report_schema( true, false ), [ 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_coupons_report', 'Retrieves WooCommerce coupons reports.', 'GET', '/reports/coupons', $this->report_schema( true, true ), [ 'period' => true, 'paged' => true, 'filters' => true ] );
		$this->add_endpoint_tool( $tools, 'get_taxes_report', 'Retrieves WooCommerce taxes reports.', 'GET', '/reports/taxes', $this->report_schema( true, true ), [ 'period' => true, 'paged' => true, 'filters' => true ] );
	}

	private function register_settings( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_settings', 'Retrieves WooCommerce setting groups.', 'GET', '/settings', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_setting_options', 'Retrieves options in one WooCommerce setting group.', 'GET', '/settings/{group}', $this->object_schema( [ 'group' => $this->string_prop( 'The WooCommerce setting group ID.' ) ], [ 'group' ] ) );
		$this->add_endpoint_tool( $tools, 'update_setting_option', 'Updates one WooCommerce setting option.', 'PUT', '/settings/{group}/{id}', $this->data_schema( 'settingData', 'Setting fields to update.', [ 'group', 'id', 'settingData' ], [ 'group' => $this->string_prop( 'The WooCommerce setting group ID.' ), 'id' => $this->string_prop( 'The WooCommerce setting ID.' ) ] ), [ 'body' => 'settingData' ] );
	}

	private function register_system_status( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_system_status', 'Retrieves WooCommerce system status.', 'GET', '/system_status', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_system_status_tools', 'Retrieves WooCommerce system status tools.', 'GET', '/system_status/tools', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'run_system_status_tool', 'Runs one WooCommerce system status tool.', 'PUT', '/system_status/tools/{toolId}', $this->object_schema( [ 'toolId' => $this->string_prop( 'The system status tool ID.' ) ], [ 'toolId' ] ), [ 'read_before_write' => '/system_status/tools' ] );
	}

	private function register_data( Frontman_Tools $tools ): void {
		$this->add_endpoint_tool( $tools, 'get_data', 'Retrieves WooCommerce store data indexes.', 'GET', '/data', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_continents', 'Retrieves WooCommerce continents data.', 'GET', '/data/continents', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_countries', 'Retrieves WooCommerce countries data.', 'GET', '/data/countries', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_currencies', 'Retrieves WooCommerce currencies data.', 'GET', '/data/currencies', $this->empty_schema() );
		$this->add_endpoint_tool( $tools, 'get_current_currency', 'Retrieves the current WooCommerce currency.', 'GET', '/data/currencies/current', $this->empty_schema() );
	}

	private function add_endpoint_tool( Frontman_Tools $tools, string $source_method, string $description, string $http_method, string $path_template, array $schema, array $options = [] ): void {
		if ( in_array( strtoupper( $http_method ), [ 'PUT', 'DELETE' ], true ) ) {
			$schema             = $this->with_confirm( $schema );
			$options['confirm'] = true;
			if ( false === strpos( $description, 'confirm=true' ) ) {
				$description .= ' Ask the user for confirmation before calling with confirm=true.';
			}
		}

		$this->add_custom_tool(
			$tools,
			$source_method,
			$description,
			$schema,
			function( array $input ) use ( $http_method, $path_template, $options ) {
				return $this->handle_endpoint_tool( $http_method, $path_template, $options, $input );
			}
		);
	}

	private function add_custom_tool( Frontman_Tools $tools, string $source_method, string $description, array $schema, callable $handler ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wc_' . $source_method,
			$description . ' Mirrors woocommerce-mcp-server method `' . $source_method . '` using local WordPress authentication; no WooCommerce REST API keys are required.',
			$schema,
			$handler,
			null,
			true,
			true
		) );
	}

	private function add_meta_tools( Frontman_Tools $tools, string $entity, string $id_key, string $path_template ): void {
		$entity_label = ucfirst( $entity );
		$id_prop      = [ $id_key => $this->integer_prop( 'The WooCommerce ' . $entity . ' ID.' ) ];

		$this->add_custom_tool(
			$tools,
			'get_' . $entity . '_meta',
			'Retrieves WooCommerce ' . $entity . ' metadata, optionally filtered by meta key.',
			$this->object_schema( array_merge( $id_prop, [ 'metaKey' => $this->string_prop( 'Optional metadata key to filter by.' ) ] ), [ $id_key ] ),
			function( array $input ) use ( $path_template ) { return $this->get_meta( $path_template, $input ); }
		);

		foreach ( [ 'create', 'update' ] as $operation ) {
			$this->add_custom_tool(
				$tools,
				$operation . '_' . $entity . '_meta',
				$entity_label . ' metadata upsert. Creates the key when missing and updates the first matching key when present. Ask the user for confirmation before calling with confirm=true.',
				$this->with_confirm( $this->object_schema( array_merge( $id_prop, [ 'metaKey' => $this->string_prop( 'The metadata key.' ), 'metaValue' => [ 'description' => 'The metadata value. Can be a scalar, object, array, or null.' ] ] ), [ $id_key, 'metaKey', 'metaValue' ] ) ),
				function( array $input ) use ( $path_template ) { return $this->upsert_meta( $path_template, $input ); }
			);
		}

		$this->add_custom_tool(
			$tools,
			'delete_' . $entity . '_meta',
			'Deletes WooCommerce ' . $entity . ' metadata by key. Ask the user for confirmation before calling with confirm=true.',
			$this->object_schema( array_merge( $id_prop, [ 'metaKey' => $this->string_prop( 'The metadata key to delete.' ), 'confirm' => $this->boolean_prop( 'Must be true only after the user explicitly confirms deletion.' ) ] ), [ $id_key, 'metaKey', 'confirm' ] ),
			function( array $input ) use ( $entity, $id_key, $path_template ) { return $this->delete_meta( $entity, $id_key, $path_template, $input ); }
		);
	}

	private function handle_endpoint_tool( string $http_method, string $path_template, array $options, array $input ): array {
		if ( ! empty( $options['confirm'] ) && true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'This WooCommerce mutation requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		if ( isset( $options['body'] ) ) {
			$body_key = (string) $options['body'];
			$this->require_array_field( $input, $body_key );
			$body = $input[ $body_key ];
			if ( isset( $options['body_product_id'] ) ) {
				$body['product_id'] = $this->require_positive_int( $input, (string) $options['body_product_id'] );
			}
		} else {
			$body = null;
		}

		$path  = $this->resolve_path( $path_template, $input );
		$query = $this->query_params( $input, $options, 'DELETE' === strtoupper( $http_method ) );
		if ( in_array( strtoupper( $http_method ), [ 'PUT', 'DELETE' ], true ) ) {
			$read_path = $this->resolve_path( (string) ( $options['read_before_write'] ?? $path_template ), $input );
			$this->request( 'GET', $read_path );
		}

		return $this->request( $http_method, $path, $query, $body );
	}

	private function get_meta( string $path_template, array $input ): array {
		$resource = $this->request( 'GET', $this->resolve_path( $path_template, $input ) );
		$meta     = isset( $resource['meta_data'] ) && is_array( $resource['meta_data'] ) ? $resource['meta_data'] : [];

		if ( isset( $input['metaKey'] ) && '' !== (string) $input['metaKey'] ) {
			$key  = (string) $input['metaKey'];
			$meta = array_values( array_filter( $meta, static function( $entry ) use ( $key ) {
				return is_array( $entry ) && isset( $entry['key'] ) && (string) $entry['key'] === $key;
			} ) );
		}

		return $meta;
	}

	private function upsert_meta( string $path_template, array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'This WooCommerce metadata update requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		$this->require_string_field( $input, 'metaKey' );
		if ( ! array_key_exists( 'metaValue', $input ) ) {
			throw new Frontman_Tool_Error( 'metaValue is required' );
		}

		$path     = $this->resolve_path( $path_template, $input );
		$resource = $this->request( 'GET', $path );
		$meta     = isset( $resource['meta_data'] ) && is_array( $resource['meta_data'] ) ? array_values( $resource['meta_data'] ) : [];
		$key      = (string) $input['metaKey'];
		$updated  = false;

		foreach ( $meta as $index => $entry ) {
			if ( is_array( $entry ) && isset( $entry['key'] ) && (string) $entry['key'] === $key ) {
				$meta[ $index ]['value'] = $input['metaValue'];
				$updated = true;
				break;
			}
		}

		if ( ! $updated ) {
			$meta[] = [ 'key' => $key, 'value' => $input['metaValue'] ];
		}

		$response = $this->request( 'PUT', $path, [], [ 'meta_data' => $meta ] );
		return isset( $response['meta_data'] ) && is_array( $response['meta_data'] ) ? $response['meta_data'] : [];
	}

	private function delete_meta( string $entity, string $id_key, string $path_template, array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'This WooCommerce metadata deletion requires explicit confirmation. Ask the user first, then call again with confirm=true.' );
		}

		$this->require_string_field( $input, 'metaKey' );
		$object = $this->meta_object( $entity, $this->require_positive_int( $input, $id_key ) );
		try {
			$object->delete_meta_data( (string) $input['metaKey'] );
			$object->save();
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( $e->getMessage() );
		}

		return $this->get_meta( $path_template, $input );
	}

	private function meta_object( string $entity, int $id ) {
		try {
			switch ( $entity ) {
				case 'product':
					$object = function_exists( 'wc_get_product' ) ? wc_get_product( $id ) : null;
					break;
				case 'order':
					$object = function_exists( 'wc_get_order' ) ? wc_get_order( $id ) : null;
					break;
				case 'customer':
					$object = class_exists( 'WC_Customer' ) ? new \WC_Customer( $id ) : null;
					break;
				default:
					$object = null;
			}
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( $e->getMessage() );
		}

		if ( ! is_object( $object ) || ! method_exists( $object, 'delete_meta_data' ) || ! method_exists( $object, 'save' ) ) {
			throw new Frontman_Tool_Error( 'WooCommerce ' . $entity . ' not found or does not support metadata deletion.' );
		}

		return $object;
	}

	private function request( string $method, string $path, array $query = [], $body = null ): array {
		$this->assert_runtime_available();

		$request = new \WP_REST_Request( strtoupper( $method ), self::REST_NAMESPACE . $path );
		foreach ( $query as $key => $value ) {
			$request->set_param( (string) $key, $value );
		}

		if ( null !== $body ) {
			$json = wp_json_encode( $body );
			if ( is_string( $json ) && method_exists( $request, 'set_body' ) ) {
				$request->set_header( 'Content-Type', 'application/json' );
				$request->set_body( $json );
			}

			if ( is_array( $body ) && $this->is_assoc( $body ) ) {
				$request->set_body_params( $body );
				foreach ( $body as $key => $value ) {
					$request->set_param( (string) $key, $value );
				}
			}
		}

		$response = rest_do_request( $request );
		if ( is_wp_error( $response ) ) {
			throw new Frontman_Tool_Error( $response->get_error_message() );
		}

		$status = method_exists( $response, 'get_status' ) ? (int) $response->get_status() : 200;
		$data   = method_exists( $response, 'get_data' ) ? $response->get_data() : [];

		if ( $status >= 400 ) {
			$message = is_array( $data ) && isset( $data['message'] ) ? (string) $data['message'] : 'WooCommerce REST API returned HTTP ' . $status;
			throw new Frontman_Tool_Error( $message );
		}

		return is_array( $data ) ? $data : [ 'value' => $data ];
	}

	private function assert_runtime_available(): void {
		if ( ! function_exists( 'rest_do_request' ) || ! class_exists( 'WP_REST_Request' ) ) {
			throw new Frontman_Tool_Error( 'WordPress REST API is not available.' );
		}

		if ( ! function_exists( 'WC' ) && ! class_exists( 'WooCommerce' ) && ! defined( 'WC_VERSION' ) ) {
			throw new Frontman_Tool_Error( 'WooCommerce is not active. Activate WooCommerce to use wc_* tools.' );
		}

		if ( function_exists( 'current_user_can' ) && ! current_user_can( 'manage_woocommerce' ) && ! current_user_can( 'manage_options' ) ) {
			throw new Frontman_Tool_Error( 'Insufficient permissions. WooCommerce management access is required.' );
		}
	}

	private function resolve_path( string $template, array $input ): string {
		return preg_replace_callback(
			'/\{([A-Za-z0-9_]+)\}/',
			function( array $matches ) use ( $input ) {
				$field = $matches[1];
				if ( ! array_key_exists( $field, $input ) || '' === (string) $input[ $field ] ) {
					throw new Frontman_Tool_Error( $field . ' is required' );
				}
				if ( $this->is_integer_path_field( $field ) ) {
					return (string) $this->require_positive_int( $input, $field );
				}

				return rawurlencode( (string) $input[ $field ] );
			},
			$template
		);
	}

	private function query_params( array $input, array $options, bool $is_delete ): array {
		$query = [];

		if ( ! empty( $options['period'] ) ) {
			$query['period'] = isset( $input['period'] ) && '' !== (string) $input['period'] ? (string) $input['period'] : 'month';
			if ( isset( $input['dateMin'] ) ) {
				$query['date_min'] = (string) $input['dateMin'];
			}
			if ( isset( $input['dateMax'] ) ) {
				$query['date_max'] = (string) $input['dateMax'];
			}
		}

		if ( ! empty( $options['paged'] ) ) {
			$query['per_page'] = $this->bounded_int( $input['perPage'] ?? 10, 1, 100 );
			$query['page']     = $this->bounded_int( $input['page'] ?? 1, 1, 999999 );
		}

		if ( ! empty( $options['filters'] ) && isset( $input['filters'] ) && is_array( $input['filters'] ) ) {
			foreach ( $input['filters'] as $key => $value ) {
				$query[ $key ] = $value;
			}
		}
		if ( ! empty( $options['product_filter'] ) && isset( $input['productId'] ) && $this->positive_int( $input['productId'] ) > 0 ) {
			$query['product'] = $this->positive_int( $input['productId'] );
		}

		if ( $is_delete ) {
			$query['force'] = array_key_exists( 'force', $input ) ? (bool) $input['force'] : (bool) ( $options['force_default'] ?? false );
		}

		return $query;
	}

	private function require_positive_int( array $input, string $field ): int {
		$value = $this->positive_int( $input[ $field ] ?? 0 );
		if ( $value <= 0 ) {
			throw new Frontman_Tool_Error( $field . ' is required' );
		}

		return $value;
	}

	private function require_array_field( array $input, string $field ): void {
		if ( ! array_key_exists( $field, $input ) || ! is_array( $input[ $field ] ) ) {
			throw new Frontman_Tool_Error( $field . ' is required' );
		}
	}

	private function is_integer_path_field( string $field ): bool {
		return ! in_array( $field, [ 'gatewayId', 'id', 'toolId' ], true ) && substr( $field, -2 ) === 'Id';
	}

	private function require_string_field( array $input, string $field ): void {
		if ( ! isset( $input[ $field ] ) || '' === (string) $input[ $field ] ) {
			throw new Frontman_Tool_Error( $field . ' is required' );
		}
	}

	private function positive_int( $value ): int {
		return max( 0, (int) $value );
	}

	private function bounded_int( $value, int $min, int $max ): int {
		return min( max( (int) $value, $min ), $max );
	}

	private function is_assoc( array $value ): bool {
		return [] !== $value && array_keys( $value ) !== range( 0, count( $value ) - 1 );
	}

	private function empty_schema(): array {
		return $this->object_schema();
	}

	private function list_schema(): array {
		return $this->object_schema( [
			'perPage' => $this->integer_prop( 'Number of results per page. Default 10, max 100.' ),
			'page'    => $this->integer_prop( 'Page number. Default 1.' ),
			'filters' => $this->dynamic_object_prop( 'WooCommerce REST API filters to pass through.' ),
		] );
	}

	private function report_schema( bool $paged, bool $dated ): array {
		$properties = [
			'filters' => $this->dynamic_object_prop( 'WooCommerce REST API report filters to pass through.' ),
		];

		if ( $paged ) {
			$properties['perPage'] = $this->integer_prop( 'Number of results per page. Default 10, max 100.' );
			$properties['page']    = $this->integer_prop( 'Page number. Default 1.' );
		}

		if ( $dated ) {
			$properties['period']  = $this->string_prop( 'Report period. Default month.' );
			$properties['dateMin'] = $this->string_prop( 'Optional minimum date.' );
			$properties['dateMax'] = $this->string_prop( 'Optional maximum date.' );
		}

		return $this->object_schema( $properties );
	}

	private function id_schema( string $field, string $description ): array {
		return $this->object_schema( [ $field => $this->integer_prop( $description ) ], [ $field ] );
	}

	private function data_schema( string $field, string $description, array $required, array $extra_properties = [] ): array {
		$properties = array_merge( $extra_properties, [ $field => $this->dynamic_object_prop( $description ) ] );
		return $this->object_schema( $properties, $required );
	}

	private function delete_schema( string $id_field, string $description ): array {
		return $this->delete_schema_with_ids( [ $id_field => $this->integer_prop( $description ) ], [ $id_field ] );
	}

	private function delete_schema_with_ids( array $id_properties, array $required_ids ): array {
		return $this->object_schema(
			array_merge(
				$id_properties,
				[
					'force'   => $this->boolean_prop( 'If true, permanently delete where WooCommerce supports forced deletion.' ),
					'confirm' => $this->boolean_prop( 'Must be true only after the user explicitly confirms deletion.' ),
				]
			),
			array_merge( $required_ids, [ 'confirm' ] )
		);
	}

	private function object_schema( array $properties = [], array $required = [] ): array {
		$schema = [
			'type'                 => 'object',
			'additionalProperties' => false,
			'properties'           => empty( $properties ) ? new \stdClass() : $properties,
		];

		if ( ! empty( $required ) ) {
			$schema['required'] = $required;
		}

		return $schema;
	}

	private function with_confirm( array $schema ): array {
		$schema['properties']['confirm'] = $this->boolean_prop( 'Must be true only after the user explicitly confirms this WooCommerce mutation.' );
		$schema['required'] = array_values( array_unique( array_merge( $schema['required'] ?? [], [ 'confirm' ] ) ) );
		return $schema;
	}

	private function dynamic_object_prop( string $description ): array {
		return [
			'type'                 => 'object',
			'description'          => $description,
			'additionalProperties' => true,
			'properties'           => new \stdClass(),
		];
	}

	private function array_of_objects_prop( string $description ): array {
		return [
			'type'        => 'array',
			'description' => $description,
			'items'       => [
				'type'                 => 'object',
				'additionalProperties' => true,
				'properties'           => new \stdClass(),
			],
		];
	}

	private function integer_prop( string $description ): array {
		return [ 'type' => 'integer', 'description' => $description ];
	}

	private function string_prop( string $description ): array {
		return [ 'type' => 'string', 'description' => $description ];
	}

	private function boolean_prop( string $description ): array {
		return [ 'type' => 'boolean', 'description' => $description ];
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
