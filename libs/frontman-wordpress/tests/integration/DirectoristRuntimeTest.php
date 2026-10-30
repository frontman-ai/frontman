<?php

frontman_runtime_assert( defined( 'ATBDP_VERSION' ) && '8.10.6' === ATBDP_VERSION, 'Real pinned Directorist must be loaded.' );
wp_set_current_user( get_user_by( 'login', 'admin' )->ID );
$tools = Frontman_Tools::instance();
frontman_runtime_assert( 'read' === $tools->get( 'wp_read_directorist_listing' )->access, 'Reader must be classified read-only.' );
frontman_runtime_assert( null === $tools->get( 'wp_update_directorist_listing' ), 'No Directorist writer should be exposed.' );
$created = wp_insert_term( 'Places', ATBDP_DIRECTORY_TYPE, [ 'slug' => 'reader-places' ] );
frontman_runtime_assert( ! is_wp_error( $created ), 'Cannot create directory type.' );
$directory_id = (int) $created['term_id'];
update_term_meta( $directory_id, 'submission_form_fields', [ 'fields' => [
	'title' => [ 'label' => 'Title', 'widget_name' => 'title' ],
	'description' => [ 'label' => 'Description', 'widget_name' => 'description' ],
	'image_upload' => [ 'label' => 'Gallery', 'widget_name' => 'image_upload', 'field_key' => 'listing_img' ],
	'video' => [ 'label' => 'Video', 'widget_name' => 'video', 'field_key' => 'videourl' ],
	'fm_plan' => [ 'label' => 'Plan', 'widget_name' => 'pricing_plans', 'field_key' => 'fm_plan' ],
	'tagline' => [ 'label' => 'Tagline', 'widget_name' => 'tagline' ],
	'social_info' => [ 'label' => 'Social links', 'widget_name' => 'social_info' ],
] ] );
update_term_meta( $directory_id, 'single_listing_header', [
	[ 'placeholderKey' => 'listing-title-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'title', 'widget_name' => 'title', 'enable_tagline' => true ] ] ],
	[ 'placeholderKey' => 'slider-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'slider', 'widget_name' => 'slider' ] ] ],
	[ 'placeholderKey' => 'quick-widgets-placeholder', 'placeholders' => [ [ 'placeholderKey' => 'quick-action-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'share', 'widget_name' => 'share' ] ] ] ] ],
	[ 'placeholderKey' => 'more-widgets-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'price', 'widget_name' => 'price' ] ] ],
] );
update_term_meta( $directory_id, 'single_listings_contents', [ 'groups' => [ [ 'label' => 'Details', 'type' => 'general_group', 'fields' => [ 'tagline', 'image_upload' ] ] ] ] );
update_term_meta( $directory_id, 'enable_single_listing_page', '1' );
$id = wp_insert_post( [ 'post_type' => ATBDP_POST_TYPE, 'post_title' => 'Reader listing', 'post_status' => 'publish', 'post_content' => 'Visible content' ], true );
frontman_runtime_assert( ! is_wp_error( $id ), 'Cannot create listing.' );
frontman_runtime_assert( true === directorist_set_listing_directory( $id, $directory_id ), 'Cannot assign directory.' );
update_post_meta( $id, '_listing_img', [ 11, 12 ] );
update_post_meta( $id, '_image_upload', 'wrong-key' );
update_post_meta( $id, '_videourl', 'https://example.com/video' );
update_post_meta( $id, '_tagline', 'Hello' );
update_post_meta( $id, '_social_info', [ [ 'id' => 'github', 'url' => 'https://github.com/example' ] ] );
update_post_meta( $id, '_fm_plan', 'hidden-plan' );
update_post_meta( $id, '_unrelated_private_meta', 'must-not-leak' );
$before = get_post_meta( $id );
$read = $tools->call( 'wp_read_directorist_listing', $tools->sanitize_input( 'wp_read_directorist_listing', [ 'id' => $id ] ) );
frontman_runtime_assert( false === $read['isError'], 'Dispatcher read failed: ' . wp_json_encode( $read ) );
$out = json_decode( $read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
frontman_runtime_same( $before, get_post_meta( $id ), 'Read must not write listing meta.' );
$by_key = [];
foreach ( $out['fields'] as $field ) { $by_key[ $field['key'] ] = $field; }
frontman_runtime_assert( ! isset( $by_key['fm_plan'] ), 'Plan fields must be omitted.' );
frontman_runtime_same( 'listing_img', $by_key['image_upload']['field_key'], 'Preserve the configured gallery storage key.' );
frontman_runtime_same( [ 11, 12 ], array_values( $by_key['image_upload']['value'] ), 'Read gallery from the configured storage key.' );
frontman_runtime_same( 'https://example.com/video', $by_key['video']['value'], 'Read video from videourl.' );
frontman_runtime_same( 'Hello', $by_key['tagline']['value'], 'Read tagline metadata.' );
frontman_runtime_same( [ [ 'id' => 'github', 'url' => 'https://github.com/example' ] ], $by_key['social_info']['value'], 'Preserve structured public social links.' );
frontman_runtime_same( 'Reader listing', $by_key['title']['value'], 'Read the listing title from the post.' );
frontman_runtime_same( 'Visible content', $by_key['description']['value'], 'Read the listing description from post content.' );
$encoded = wp_json_encode( $out );
frontman_runtime_assert( false === strpos( $encoded, 'hidden-plan' ) && false === strpos( $encoded, 'must-not-leak' ) && false === strpos( $encoded, 'wrong-key' ), 'Do not return excluded or wrong-key values.' );
frontman_runtime_same( $directory_id, $out['directory']['id'], 'Directory assignment.' );
frontman_runtime_assert( true === $out['single_page']['enabled'] && true === $out['header']['title'] && true === $out['header']['tagline'], 'Placeholder header flags.' );
frontman_runtime_same( [ 'slider' ], $out['header']['thumbnail'], 'Placeholder thumbnail.' );
frontman_runtime_same( [ 'price' ], $out['header']['quick_info'], 'Placeholder quick info.' );
frontman_runtime_same( [ 'share' ], $out['header']['quick_actions'], 'Nested quick actions.' );
frontman_runtime_same( [ 'tagline', 'image_upload' ], $out['sections'][0]['fields'], 'Section order.' );
update_term_meta( $directory_id, 'single_listing_header', [ 'listings_header' => [ 'thumbnail' => [ [ 'widget_name' => 'listing_slider' ] ], 'quick_info' => [ [ 'widget_name' => 'category' ] ], 'quick_actions' => [] ], 'options' => [ 'content_settings' => [ 'listing_title' => [ 'enable_title' => true, 'enable_tagline' => '0' ], 'listing_description' => [ 'enable' => 1 ] ] ] ] );
$legacy_read = $tools->call( 'wp_read_directorist_listing', $tools->sanitize_input( 'wp_read_directorist_listing', [ 'id' => $id ] ) );
frontman_runtime_assert( false === $legacy_read['isError'], 'Legacy header read failed.' );
$legacy = json_decode( $legacy_read['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
frontman_runtime_assert( true === $legacy['header']['title'] && false === $legacy['header']['tagline'] && true === $legacy['header']['description'], 'Decode the legacy header layout.' );
frontman_runtime_same( [ 'listing_slider' ], $legacy['header']['thumbnail'], 'Legacy thumbnail.' );
update_term_meta( $directory_id, 'single_listing_header', [ 'unrecognized' => true ] );
$rejected = $tools->call( 'wp_read_directorist_listing', $tools->sanitize_input( 'wp_read_directorist_listing', [ 'id' => $id ] ) );
frontman_runtime_assert( true === $rejected['isError'], 'Unrecognized headers must be rejected.' );
try {
	$tools->sanitize_input( 'wp_read_directorist_listing', [ 'id' => 0 ] );
	throw new RuntimeException( 'Missing listings must be rejected.' );
} catch ( Frontman_Tool_Error $e ) {
	frontman_runtime_assert( false !== strpos( $e->getMessage(), 'id' ), 'Invalid ID must identify the field.' );
}
