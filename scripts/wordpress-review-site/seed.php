<?php

if ( ! defined( 'WP_CLI' ) || ! WP_CLI ) {
    exit( 1 );
}

if ( wp_parse_url( home_url(), PHP_URL_HOST ) !== 'quiet-bat-1b8ea4.instawp.site' ) {
    WP_CLI::error( 'This seed is restricted to the approved InstaWP review site.' );
}

if ( ! class_exists( 'WooCommerce' ) || ! did_action( 'elementor/loaded' ) ) {
    WP_CLI::error( 'Activate WooCommerce and Elementor before seeding.' );
}

if ( ! current_user_can( 'manage_options' ) || ! current_user_can( 'manage_woocommerce' ) ) {
    WP_CLI::error( 'Run this seed with --user set to an existing WordPress administrator.' );
}

if ( ! has_filter( 'pre_wp_mail', '__return_true' ) ||
    ! has_filter( 'woocommerce_payment_gateways', '__return_empty_array' ) ) {
    WP_CLI::error( 'Install the review safety MU plugin before seeding.' );
}

$marker = '_frontman_review_fixture';

function frontman_review_post( $key, $title, $content, $type = 'page', $status = 'draft' ) {
    $existing = get_posts( [
        'post_type' => $type,
        'post_status' => array_values( get_post_stati() ),
        'numberposts' => 2,
        'meta_key' => '_frontman_review_fixture',
        'meta_value' => $key,
    ] );
    if ( count( $existing ) > 1 ) {
        WP_CLI::error( 'Duplicate fixture marker: ' . $key );
    }
    if ( $existing ) {
        if ( 'trash' === $existing[0]->post_status ) {
            WP_CLI::error( 'Restore the trashed fixture before seeding: ' . $key );
        }
        return $existing[0]->ID;
    }
    $id = wp_insert_post( [
        'post_type' => $type,
        'post_status' => $status,
        'post_title' => $title,
        'post_name' => sanitize_title( $title ),
        'post_content' => $content,
        'meta_input' => [ '_frontman_review_fixture' => $key ],
    ], true );
    if ( is_wp_error( $id ) ) {
        WP_CLI::error( $id->get_error_message() );
    }
    return $id;
}

$pages = [
    'about' => frontman_review_post(
        'about',
        'Review About',
        '<!-- wp:paragraph --><p>Welcome to the Frontman review shop. This website contains synthetic products and orders for testing. No real purchases or deliveries take place.</p><!-- /wp:paragraph -->',
        'page',
        'publish'
    ),
    'gutenberg' => frontman_review_post(
        'gutenberg',
        'Review Gutenberg',
        '<!-- wp:heading --><h2 class="wp-block-heading">Everyday essentials for a sample shop</h2><!-- /wp:heading -->' .
        '<!-- wp:paragraph --><p>Explore our sample notebook, mug, and tote bag. This page is a draft for safe editing tests.</p><!-- /wp:paragraph -->' .
        '<!-- wp:buttons --><div class="wp-block-buttons"><!-- wp:button --><div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="/review-about/">About this demo</a></div><!-- /wp:button --></div><!-- /wp:buttons -->'
    ),
    'draft_a' => frontman_review_post( 'draft_a', 'Review Draft A', 'Sample draft A. Keep this post for the ambiguous-deletion review case.', 'post' ),
    'draft_b' => frontman_review_post( 'draft_b', 'Review Draft B', 'Sample draft B. Keep this post for the ambiguous-deletion review case.', 'post' ),
    'elementor' => frontman_review_post( 'elementor', 'Review Elementor', '' ),
];

if ( ! get_post_meta( $pages['elementor'], '_frontman_review_elementor_seeded', true ) ) {
    update_post_meta( $pages['elementor'], '_elementor_edit_mode', 'builder' );
    $document = \Elementor\Plugin::$instance->documents->get( $pages['elementor'] );
    if ( ! $document ) {
        WP_CLI::error( 'Could not load the Elementor review document.' );
    }
    $saved = $document->save( [
        'elements' => [
            [
                'id' => 'f0a0001',
                'elType' => 'container',
                'settings' => [],
                'elements' => [
                    [
                        'id' => 'f0a0002',
                        'elType' => 'widget',
                        'widgetType' => 'heading',
                        'settings' => [ 'title' => 'Welcome to the sample shop', 'header_size' => 'h2' ],
                        'elements' => [],
                    ],
                    [
                        'id' => 'f0a0003',
                        'elType' => 'widget',
                        'widgetType' => 'text-editor',
                        'settings' => [ 'editor' => '<p>This draft contains synthetic content for Elementor editing tests.</p>' ],
                        'elements' => [],
                    ],
                ],
            ],
        ],
        'settings' => [ 'post_status' => 'draft' ],
    ] );
    if ( ! $saved ) {
        WP_CLI::error( 'Elementor did not save the review document.' );
    }
    update_post_meta( $pages['elementor'], '_frontman_review_elementor_seeded', 1 );
}

$products = [];
foreach ( [
    [ 'notebook', 'Review Notebook', '12.00', 25 ],
    [ 'mug', 'Review Ceramic Mug', '18.00', 15 ],
    [ 'tote', 'Review Canvas Tote', '22.00', 20 ],
] as [ $key, $name, $price, $stock ] ) {
    $sku = 'FRONTMAN-REVIEW-' . strtoupper( $key );
    $id = wc_get_product_id_by_sku( $sku );
    if ( $id ) {
        $product = wc_get_product( $id );
        if ( $product->get_meta( $marker ) !== $key ) {
            WP_CLI::error( 'An existing non-fixture product uses SKU ' . $sku );
        }
    } else {
        $product = new WC_Product_Simple();
        $product->set_name( $name );
        $product->set_sku( $sku );
        $product->set_status( 'publish' );
        $product->set_description( 'Synthetic physical product for Frontman review. No real purchases or deliveries take place.' );
        $product->set_regular_price( $price );
        $product->set_manage_stock( true );
        $product->set_stock_quantity( $stock );
        $product->set_virtual( false );
        $product->set_downloadable( false );
        $product->add_meta_data( $marker, $key, true );
        $id = $product->save();
        if ( ! $id ) {
            WP_CLI::error( 'Could not save product ' . $key );
        }
    }
    $products[$key] = $id;
}

$orders = [];
foreach ( [ 'pending', 'on-hold', 'completed' ] as $index => $status ) {
    $key = 'order_' . $index;
    if ( \Automattic\WooCommerce\Utilities\OrderUtil::custom_orders_table_usage_is_enabled() ) {
        $existing = wc_get_orders( [
            'limit' => 2,
            'meta_query' => [ [ 'key' => $marker, 'value' => $key ] ],
        ] );
    } else {
        $ids = get_posts( [
            'post_type' => 'shop_order',
            'post_status' => array_merge( array_keys( wc_get_order_statuses() ), [ 'trash' ] ),
            'numberposts' => 2,
            'fields' => 'ids',
            'meta_key' => $marker,
            'meta_value' => $key,
        ] );
        $existing = array_map( 'wc_get_order', $ids );
    }
    if ( count( $existing ) > 1 ) {
        WP_CLI::error( 'Duplicate order fixture: ' . $key );
    }
    if ( $existing ) {
        if ( ! $existing[0] || '1' !== (string) $existing[0]->get_meta( '_frontman_review_fixture_ready' ) ||
            'trash' === $existing[0]->get_status() ) {
            WP_CLI::error( 'An existing order fixture is incomplete or trashed: ' . $key );
        }
        $orders[$key] = $existing[0]->get_id();
        continue;
    }
    $order = new WC_Order();
    $order->set_created_via( 'frontman-review-fixture' );
    $order->set_customer_id( 0 );
    $order->set_billing_first_name( 'Synthetic' );
    $order->set_billing_last_name( 'Customer ' . ( $index + 1 ) );
    $order->set_billing_email( 'review-' . ( $index + 1 ) . '@example.invalid' );
    $order->set_customer_note( 'Synthetic review order. No payment, shipment, or customer notification is required.' );
    $order->add_meta_data( $marker, $key, true );
    $order->save();
    if ( ! $order->add_product( wc_get_product( array_values( $products )[$index] ), 1 ) ) {
        WP_CLI::error( 'Could not add the fixture product to order ' . $order->get_id() );
    }
    $order->calculate_totals();
    $order->set_status( $status );
    $order->add_meta_data( '_frontman_review_fixture_ready', 1, true );
    $order->save();
    $orders[$key] = $order->get_id();
}

update_option( 'blog_public', 0 );
update_option( 'frontman_review_fixture_version', 1, false );
WP_CLI::success( 'Synthetic review fixtures are ready. Existing fixtures were preserved, not reset.' );
echo wp_json_encode( [ 'pages' => $pages, 'products' => $products, 'orders' => $orders ], JSON_PRETTY_PRINT ) . "\n";
