<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-woocommerce-tools/' );

$GLOBALS['frontman_wc_rest_requests']  = [];
$GLOBALS['frontman_wc_rest_responses'] = [];
$GLOBALS['frontman_wc_meta_object']    = null;

if ( ! class_exists( 'WooCommerce' ) ) {
	class WooCommerce {}
}

if ( ! class_exists( 'Frontman_WC_Test_Meta_Object' ) ) {
	class Frontman_WC_Test_Meta_Object {
		public int $id;
		public array $deleted = [];
		public bool $saved = false;

		public function __construct( int $id ) {
			$this->id = $id;
		}

		public function delete_meta_data( string $key ): void {
			$this->deleted[] = $key;
		}

		public function save(): void {
			$this->saved = true;
		}
	}
}

if ( ! function_exists( 'wc_get_product' ) ) {
	function wc_get_product( int $id ) {
		$GLOBALS['frontman_wc_meta_object'] = new Frontman_WC_Test_Meta_Object( $id );
		return $GLOBALS['frontman_wc_meta_object'];
	}
}

if ( ! class_exists( 'WP_Error' ) ) {
	class WP_Error {
		private string $message;

		public function __construct( string $code = '', string $message = '' ) {
			$this->message = $message;
		}

		public function get_error_message(): string {
			return $this->message;
		}
	}
}

if ( ! class_exists( 'WP_REST_Request' ) ) {
	class WP_REST_Request {
		public string $method;
		public string $route;
		public array $params = [];
		public array $body_params = [];
		public array $headers = [];
		public string $body = '';

		public function __construct( string $method, string $route ) {
			$this->method = $method;
			$this->route  = $route;
		}

		public function set_param( string $key, $value ): void {
			$this->params[ $key ] = $value;
		}

		public function set_body_params( array $params ): void {
			$this->body_params = $params;
		}

		public function set_header( string $key, string $value ): void {
			$this->headers[ $key ] = $value;
		}

		public function set_body( string $body ): void {
			$this->body = $body;
		}
	}
}

if ( ! class_exists( 'WP_REST_Response' ) ) {
	class WP_REST_Response {
		private $data;
		private int $status;

		public function __construct( $data, int $status = 200 ) {
			$this->data   = $data;
			$this->status = $status;
		}

		public function get_data() {
			return $this->data;
		}

		public function get_status(): int {
			return $this->status;
		}
	}
}

if ( ! function_exists( 'rest_do_request' ) ) {
	function rest_do_request( WP_REST_Request $request ) {
		$GLOBALS['frontman_wc_rest_requests'][] = $request;

		if ( ! empty( $GLOBALS['frontman_wc_rest_responses'] ) ) {
			$response = array_shift( $GLOBALS['frontman_wc_rest_responses'] );
			if ( $response instanceof WP_REST_Response || $response instanceof WP_Error ) {
				return $response;
			}

			return new WP_REST_Response( $response );
		}

		return new WP_REST_Response( [
			'method'      => $request->method,
			'route'       => $request->route,
			'params'      => $request->params,
			'body_params' => $request->body_params,
			'body'        => '' === $request->body ? null : json_decode( $request->body, true ),
		] );
	}
}

if ( ! function_exists( 'is_wp_error' ) ) {
	function is_wp_error( $value ): bool {
		return $value instanceof WP_Error;
	}
}

if ( ! function_exists( 'current_user_can' ) ) {
	function current_user_can( string $capability ): bool {
		return in_array( $capability, [ 'manage_options', 'manage_woocommerce' ], true );
	}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_check_invalid_utf8' ) ) {
	function wp_check_invalid_utf8( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( strip_tags( (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'esc_url_raw' ) ) {
	function esc_url_raw( $value ): string {
		return (string) $value;
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-woocommerce.php';

class Frontman_WooCommerce_Tools_Test_Runner {
	private int $assertions = 0;
	private Frontman_Tools $tools;

	public function run(): void {
		$this->tools = new Frontman_Tools();
		( new Frontman_Tool_WooCommerce() )->register( $this->tools );

		$this->test_all_woocommerce_tools_are_registered();
		$this->test_tool_object_schemas_have_properties_objects();
		$this->test_tool_array_schemas_have_items();
		$this->test_list_products_maps_to_wc_rest_route();
		$this->test_create_product_preserves_raw_product_data();
		$this->test_update_product_reads_before_write();
		$this->test_invalid_product_data_is_rejected();
		$this->test_invalid_path_ids_are_rejected();
		$this->test_string_path_ids_are_allowed();
		$this->test_product_reviews_use_global_reviews_endpoint();
		$this->test_delete_product_requires_confirmation();
		$this->test_product_meta_upsert_uses_meta_data_array();
		$this->test_product_meta_delete_uses_woocommerce_crud();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function test_all_woocommerce_tools_are_registered(): void {
		$names = array_column( $this->tools->all_definitions(), 'name' );
		$expected = [
			'wc_get_products',
			'wc_get_product',
			'wc_create_product',
			'wc_update_product',
			'wc_delete_product',
			'wc_get_product_meta',
			'wc_create_product_meta',
			'wc_update_product_meta',
			'wc_delete_product_meta',
			'wc_get_product_categories',
			'wc_get_product_category',
			'wc_create_product_category',
			'wc_update_product_category',
			'wc_delete_product_category',
			'wc_get_product_tags',
			'wc_get_product_tag',
			'wc_create_product_tag',
			'wc_update_product_tag',
			'wc_delete_product_tag',
			'wc_get_product_attributes',
			'wc_get_product_attribute',
			'wc_create_product_attribute',
			'wc_update_product_attribute',
			'wc_delete_product_attribute',
			'wc_get_attribute_terms',
			'wc_get_attribute_term',
			'wc_create_attribute_term',
			'wc_update_attribute_term',
			'wc_delete_attribute_term',
			'wc_get_product_variations',
			'wc_get_product_variation',
			'wc_create_product_variation',
			'wc_update_product_variation',
			'wc_delete_product_variation',
			'wc_get_product_reviews',
			'wc_get_product_review',
			'wc_create_product_review',
			'wc_update_product_review',
			'wc_delete_product_review',
			'wc_get_orders',
			'wc_get_order',
			'wc_create_order',
			'wc_update_order',
			'wc_delete_order',
			'wc_get_order_meta',
			'wc_create_order_meta',
			'wc_update_order_meta',
			'wc_delete_order_meta',
			'wc_get_order_notes',
			'wc_get_order_note',
			'wc_create_order_note',
			'wc_delete_order_note',
			'wc_get_order_refunds',
			'wc_get_order_refund',
			'wc_create_order_refund',
			'wc_delete_order_refund',
			'wc_get_customers',
			'wc_get_customer',
			'wc_create_customer',
			'wc_update_customer',
			'wc_delete_customer',
			'wc_get_customer_meta',
			'wc_create_customer_meta',
			'wc_update_customer_meta',
			'wc_delete_customer_meta',
			'wc_get_shipping_zones',
			'wc_get_shipping_zone',
			'wc_create_shipping_zone',
			'wc_update_shipping_zone',
			'wc_delete_shipping_zone',
			'wc_get_shipping_methods',
			'wc_get_shipping_zone_methods',
			'wc_create_shipping_zone_method',
			'wc_update_shipping_zone_method',
			'wc_delete_shipping_zone_method',
			'wc_get_shipping_zone_locations',
			'wc_update_shipping_zone_locations',
			'wc_get_tax_classes',
			'wc_create_tax_class',
			'wc_delete_tax_class',
			'wc_get_tax_rates',
			'wc_get_tax_rate',
			'wc_create_tax_rate',
			'wc_update_tax_rate',
			'wc_delete_tax_rate',
			'wc_get_coupons',
			'wc_get_coupon',
			'wc_create_coupon',
			'wc_update_coupon',
			'wc_delete_coupon',
			'wc_get_payment_gateways',
			'wc_get_payment_gateway',
			'wc_update_payment_gateway',
			'wc_get_sales_report',
			'wc_get_products_report',
			'wc_get_orders_report',
			'wc_get_categories_report',
			'wc_get_customers_report',
			'wc_get_stock_report',
			'wc_get_coupons_report',
			'wc_get_taxes_report',
			'wc_get_settings',
			'wc_get_setting_options',
			'wc_update_setting_option',
			'wc_get_system_status',
			'wc_get_system_status_tools',
			'wc_run_system_status_tool',
			'wc_get_data',
			'wc_get_continents',
			'wc_get_countries',
			'wc_get_currencies',
			'wc_get_current_currency',
		];

		$this->assert_same( [], array_values( array_diff( $expected, $names ) ), 'All WooCommerce MCP-derived tools are registered' );
		$this->assert_same( count( $expected ), count( $names ), 'Only the expected WooCommerce tools are registered by the WooCommerce tool module' );
	}

	private function test_tool_object_schemas_have_properties_objects(): void {
		$definitions = json_decode( wp_json_encode( $this->tools->all_definitions() ) );

		foreach ( $definitions as $definition ) {
			$this->assert_object_schemas_have_properties_objects( $definition->inputSchema, $definition->name . '.inputSchema' );
		}
	}

	private function assert_object_schemas_have_properties_objects( $schema, string $path ): void {
		if ( is_object( $schema ) ) {
			if ( isset( $schema->type ) && 'object' === $schema->type ) {
				$this->assert_true( isset( $schema->properties ), $path . ' object schema has properties' );
				$this->assert_true( $schema->properties instanceof stdClass, $path . ' properties serialize as an object' );

				if ( isset( $schema->required ) && is_array( $schema->required ) ) {
					foreach ( $schema->required as $field ) {
						$this->assert_true( property_exists( $schema->properties, $field ), $path . ' required field exists in properties: ' . $field );
					}
				}
			}

			foreach ( get_object_vars( $schema ) as $key => $value ) {
				$this->assert_object_schemas_have_properties_objects( $value, $path . '.' . $key );
			}
		}

		if ( is_array( $schema ) ) {
			foreach ( $schema as $key => $value ) {
				$this->assert_object_schemas_have_properties_objects( $value, $path . '[' . $key . ']' );
			}
		}
	}

	private function test_tool_array_schemas_have_items(): void {
		$definitions = json_decode( wp_json_encode( $this->tools->all_definitions() ) );

		foreach ( $definitions as $definition ) {
			$this->assert_array_schemas_have_items( $definition->inputSchema, $definition->name . '.inputSchema' );
		}
	}

	private function assert_array_schemas_have_items( $schema, string $path ): void {
		if ( is_object( $schema ) ) {
			if ( isset( $schema->type ) && 'array' === $schema->type ) {
				$this->assert_true( isset( $schema->items ), $path . ' array schema has items' );
			}

			foreach ( get_object_vars( $schema ) as $key => $value ) {
				$this->assert_array_schemas_have_items( $value, $path . '.' . $key );
			}
		}

		if ( is_array( $schema ) ) {
			foreach ( $schema as $key => $value ) {
				$this->assert_array_schemas_have_items( $value, $path . '[' . $key . ']' );
			}
		}
	}

	private function test_list_products_maps_to_wc_rest_route(): void {
		$this->reset_rest();
		$this->call_success( 'wc_get_products', [
			'perPage' => 2,
			'page' => 3,
			'filters' => [ 'status' => 'publish', 'search' => 'shirt' ],
		] );

		$request = $GLOBALS['frontman_wc_rest_requests'][0];
		$this->assert_same( 'GET', $request->method, 'wc_get_products uses GET' );
		$this->assert_same( '/wc/v3/products', $request->route, 'wc_get_products uses the products route' );
		$this->assert_same( 2, $request->params['per_page'], 'wc_get_products maps perPage to per_page' );
		$this->assert_same( 3, $request->params['page'], 'wc_get_products maps page' );
		$this->assert_same( 'publish', $request->params['status'], 'wc_get_products passes filters through' );
	}

	private function test_create_product_preserves_raw_product_data(): void {
		$this->reset_rest();
		$input = [
			'productData' => [
				'name' => 'Premium <strong>Shirt</strong>',
				'description' => '<p>Path C:\\tmp\\shirt and regex /\\d+/</p>',
				'regular_price' => '29.99',
			],
		];
		$sanitized = $this->tools->sanitize_input( 'wc_create_product', $input );
		$this->call_success( 'wc_create_product', $sanitized );

		$request = $GLOBALS['frontman_wc_rest_requests'][0];
		$this->assert_same( 'POST', $request->method, 'wc_create_product uses POST' );
		$this->assert_same( '/wc/v3/products', $request->route, 'wc_create_product uses the products route' );
		$this->assert_same( 'Premium <strong>Shirt</strong>', $request->body_params['name'], 'WooCommerce product strings are preserved for WooCommerce REST validation' );
		$this->assert_same( '<p>Path C:\\tmp\\shirt and regex /\\d+/</p>', $request->body_params['description'], 'WooCommerce product HTML and backslashes are preserved' );
	}

	private function test_update_product_reads_before_write(): void {
		$this->reset_rest();
		$this->call_success( 'wc_update_product', [ 'productId' => 10, 'productData' => [ 'name' => 'After' ], 'confirm' => true ] );
		$this->assert_same( 'GET', $GLOBALS['frontman_wc_rest_requests'][0]->method, 'wc_update_product reads the product before mutation' );
		$this->assert_same( '/wc/v3/products/10', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'wc_update_product reads the target product route' );
		$this->assert_same( 'PUT', $GLOBALS['frontman_wc_rest_requests'][1]->method, 'wc_update_product writes after reading' );
	}

	private function test_invalid_product_data_is_rejected(): void {
		$sanitized = $this->tools->sanitize_input( 'wc_create_product', [ 'productData' => 'not an object' ] );
		$error = $this->call_error( 'wc_create_product', $sanitized );
		$this->assert_true( false !== strpos( $error, 'productData is required' ), 'wc_create_product rejects non-object productData' );
	}

	private function test_invalid_path_ids_are_rejected(): void {
		$sanitized = $this->tools->sanitize_input( 'wc_get_product', [ 'productId' => 'abc' ] );
		$error = $this->call_error( 'wc_get_product', $sanitized );
		$this->assert_true( false !== strpos( $error, 'productId is required' ), 'wc_get_product rejects invalid product IDs before REST dispatch' );
	}

	private function test_string_path_ids_are_allowed(): void {
		$this->reset_rest();
		$this->call_success( 'wc_get_payment_gateway', [ 'gatewayId' => 'stripe' ] );
		$this->assert_same( '/wc/v3/payment_gateways/stripe', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'gatewayId remains a string path parameter' );

		$this->reset_rest();
		$this->call_success( 'wc_run_system_status_tool', [ 'toolId' => 'clear_transients', 'confirm' => true ] );
		$this->assert_same( '/wc/v3/system_status/tools', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'wc_run_system_status_tool reads available tools before mutation' );
		$this->assert_same( '/wc/v3/system_status/tools/clear_transients', $GLOBALS['frontman_wc_rest_requests'][1]->route, 'toolId remains a string path parameter' );
	}

	private function test_product_reviews_use_global_reviews_endpoint(): void {
		$this->reset_rest();
		$this->call_success( 'wc_get_product_reviews', [ 'productId' => 10 ] );
		$this->assert_same( '/wc/v3/products/reviews', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'wc_get_product_reviews uses the global WooCommerce reviews route' );
		$this->assert_same( 10, $GLOBALS['frontman_wc_rest_requests'][0]->params['product'], 'wc_get_product_reviews maps productId to product filter' );

		$this->reset_rest();
		$this->call_success( 'wc_create_product_review', [ 'productId' => 10, 'reviewData' => [ 'review' => 'Great' ] ] );
		$this->assert_same( '/wc/v3/products/reviews', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'wc_create_product_review uses the global WooCommerce reviews route' );
		$this->assert_same( 10, $GLOBALS['frontman_wc_rest_requests'][0]->body_params['product_id'], 'wc_create_product_review writes product_id into the request body' );
	}

	private function test_delete_product_requires_confirmation(): void {
		$update_error = $this->call_error( 'wc_update_product', [ 'productId' => 10, 'productData' => [ 'name' => 'After' ] ] );
		$this->assert_true( false !== strpos( $update_error, 'explicit confirmation' ), 'wc_update_product requires confirm=true' );

		$error = $this->call_error( 'wc_delete_product', [ 'productId' => 10, 'force' => true, 'confirm' => false ] );
		$this->assert_true( false !== strpos( $error, 'explicit confirmation' ), 'wc_delete_product requires confirm=true' );
	}

	private function test_product_meta_upsert_uses_meta_data_array(): void {
		$this->reset_rest();
		$GLOBALS['frontman_wc_rest_responses'] = [
			[ 'id' => 10, 'meta_data' => [ [ 'id' => 1, 'key' => '_old', 'value' => 'before' ] ] ],
			[ 'id' => 10, 'meta_data' => [ [ 'id' => 1, 'key' => '_old', 'value' => 'after' ] ] ],
		];

		$meta = $this->call_success( 'wc_update_product_meta', [
			'productId' => 10,
			'metaKey' => '_old',
			'metaValue' => 'after',
			'confirm' => true,
		] );

		$this->assert_same( 'GET', $GLOBALS['frontman_wc_rest_requests'][0]->method, 'meta update reads the product first' );
		$this->assert_same( '/wc/v3/products/10', $GLOBALS['frontman_wc_rest_requests'][0]->route, 'meta update reads the product route' );
		$this->assert_same( 'PUT', $GLOBALS['frontman_wc_rest_requests'][1]->method, 'meta update writes the product' );
		$this->assert_same( 'after', $GLOBALS['frontman_wc_rest_requests'][1]->body_params['meta_data'][0]['value'], 'meta update sends modified meta_data array' );
		$this->assert_same( 'after', $meta[0]['value'], 'meta update returns updated metadata' );
	}

	private function test_product_meta_delete_uses_woocommerce_crud(): void {
		$this->reset_rest();
		$GLOBALS['frontman_wc_rest_responses'] = [ [ 'id' => 10, 'meta_data' => [] ] ];

		$this->call_success( 'wc_delete_product_meta', [
			'productId' => 10,
			'metaKey' => '_old',
			'confirm' => true,
		] );

		$this->assert_same( 10, $GLOBALS['frontman_wc_meta_object']->id, 'meta delete loads the WooCommerce CRUD object' );
		$this->assert_same( [ '_old' ], $GLOBALS['frontman_wc_meta_object']->deleted, 'meta delete uses delete_meta_data' );
		$this->assert_same( true, $GLOBALS['frontman_wc_meta_object']->saved, 'meta delete saves the WooCommerce CRUD object' );
		$this->assert_same( 'GET', $GLOBALS['frontman_wc_rest_requests'][0]->method, 'meta delete reads back updated metadata' );
	}

	private function reset_rest(): void {
		$GLOBALS['frontman_wc_rest_requests'] = [];
		$GLOBALS['frontman_wc_rest_responses'] = [];
	}

	private function call_success( string $name, array $input ): array {
		$result = $this->tools->call( $name, $input );
		if ( isset( $result['isError'] ) && true === $result['isError'] ) {
			throw new RuntimeException( 'Unexpected tool error for ' . $name . ': ' . $result['content'][0]['text'] );
		}

		$decoded = json_decode( $result['content'][0]['text'], true );
		return is_array( $decoded ) ? $decoded : [];
	}

	private function call_error( string $name, array $input ): string {
		$result = $this->tools->call( $name, $input );
		if ( ! isset( $result['isError'] ) || true !== $result['isError'] ) {
			throw new RuntimeException( 'Expected tool error for ' . $name );
		}

		return $result['content'][0]['text'];
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . "\nExpected: " . var_export( $expected, true ) . "\nActual: " . var_export( $actual, true ) );
		}
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}
}

( new Frontman_WooCommerce_Tools_Test_Runner() )->run();
