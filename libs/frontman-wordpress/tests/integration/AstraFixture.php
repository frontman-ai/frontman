<?php
define( 'WP_ADMIN', false );
require '/var/www/html/wp-load.php';
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );

$tools = Frontman_Tools::instance();
if ( 'fixture_banner' === $argv[1] ) {
	$enabled = 'on' === $argv[2];
	update_option( 'astra-settings', array_merge( get_option( 'astra-settings', [] ), [
		'ast-archive-product-title' => $enabled,
		'ast-dynamic-archive-product-layout' => 'layout-1',
	] ) );
	echo wp_json_encode( Frontman_Tools::success_result( [ 'fixture_banner' => $enabled ] ) );
	exit;
}
if ( 'setup' !== $argv[1] ) {
	$input = json_decode( $argv[2], true, 512, JSON_THROW_ON_ERROR );
	$result = $tools->call( $argv[1], $tools->sanitize_input( $argv[1], $input ) );
	if ( ! empty( $result['isError'] ) ) {
		throw new RuntimeException( $result['content'][0]['text'] );
	}
	echo wp_json_encode( $result ) . "\n";
	exit;
}
switch_theme( 'astra' );
update_option( 'astra-settings', array_merge( get_option( 'astra-settings', [] ), [
	'woocommerce-sidebar-layout' => 'right-sidebar',
	'woocommerce-ast-content-layout' => 'normal-width-container',
] ) );
if ( '4.12.3' !== wp_get_theme()->get( 'Version' ) || '10.4.3' !== WC_VERSION ) {
	throw new RuntimeException( 'Unexpected fixture dependency version.' );
}
update_option( 'home', getenv( 'FIXTURE_URL' ) );
update_option( 'siteurl', getenv( 'FIXTURE_URL' ) );
update_option( 'blog_public', 0 );
$password = bin2hex( random_bytes( 32 ) );
wp_set_password( $password, get_current_user_id() );
$password_file = '/tmp/frontman-fixture-admin-password';
if ( false === file_put_contents( $password_file, $password ) || ! chmod( $password_file, 0600 ) ) {
	throw new RuntimeException( 'Could not create the private fixture credential.' );
}
update_option( 'woocommerce_currency', 'USD' );
update_option( 'woocommerce_default_country', 'US:CA' );
foreach ( [
	'shop' => [ 'Synthetic shop', 'Synthetic shop introduction.' ],
	'cart' => [ 'Synthetic cart', '[woocommerce_cart]' ],
	'checkout' => [ 'Synthetic checkout', '[woocommerce_checkout]' ],
] as $slug => [ $title, $content ] ) {
	$id = wp_insert_post( [ 'post_type' => 'page', 'post_status' => 'publish', 'post_name' => "synthetic-$slug", 'post_title' => $title, 'post_content' => $content ], true );
	if ( is_wp_error( $id ) ) { throw new RuntimeException( $id->get_error_message() ); }
	update_option( "woocommerce_{$slug}_page_id", $id );
	update_post_meta( $id, 'site-sidebar-layout', 'left-sidebar' );
}
foreach ( wc_get_products( [ 'limit' => -1 ] ) as $product ) { $product->delete( true ); }
foreach ( [ 'Amber', 'Indigo' ] as $name ) {
	$term = wp_insert_term( "Synthetic $name category", 'product_cat' );
	if ( is_wp_error( $term ) ) { throw new RuntimeException( $term->get_error_message() ); }
	$product = new WC_Product_Simple();
	$product->set_name( "Synthetic $name product" );
	$product->set_slug( strtolower( $name ) );
	$product->set_status( 'publish' );
	$product->set_regular_price( '12' );
	$product->set_virtual( true );
	$product->set_category_ids( [ $term['term_id'] ] );
	$product->save();
}
update_option( 'widget_woocommerce_recently_viewed_products', [
	2 => [ 'title' => 'Synthetic recently viewed', 'number' => 4 ], '_multiwidget' => 1,
] );
wp_set_sidebars_widgets( [ 'astra-woo-shop-sidebar' => [ 'woocommerce_recently_viewed_products-2' ], 'sidebar-1' => [ 'woocommerce_recently_viewed_products-2' ] ] );
update_option( 'frontman_widget_visibility', [] );
update_option( 'woocommerce_shop_page_display', '' );
update_option( 'woocommerce_category_archive_display', '' );
update_option( 'permalink_structure', '' );
flush_rewrite_rules();
echo "Ready: synthetic Astra 4.12.3 / WooCommerce 10.4.3\n";
