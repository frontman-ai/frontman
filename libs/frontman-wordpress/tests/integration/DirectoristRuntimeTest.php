<?php
/** Read-only contract against the official Directorist package. */
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/user.php';

function directorist_check( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$admin = get_user_by( 'login', 'admin' );
wp_set_current_user( $admin->ID );
$tools = Frontman_Tools::instance();
if ( in_array( '--setup', $argv ?? [], true ) ) {
	directorist_check( null === $tools->get( 'wp_read_directorist_listing' ), 'Inactive Directorist must not register the reader.' );
	$result = activate_plugin( 'directorist/directorist-base.php' );
	directorist_check( ! is_wp_error( $result ), 'Directorist activation failed: ' . ( is_wp_error( $result ) ? $result->get_error_message() : '' ) );
	exit( 0 );
}

directorist_check( defined( 'ATBDP_VERSION' ) && ATBDP_VERSION === getenv( 'EXPECTED_DIRECTORIST_VERSION' ), 'Unexpected Directorist version.' );
directorist_check( 'read' === $tools->get( 'wp_read_directorist_listing' )->access, 'Reader must be classified read-only.' );
directorist_check( null === $tools->get( 'wp_update_directorist_listing' ), 'No Directorist writer should be exposed.' );

function directorist_call( array $input, bool $error = false ): array {
	global $tools;
	$result = $tools->call( 'wp_read_directorist_listing', $tools->sanitize_input( 'wp_read_directorist_listing', $input ) );
	directorist_check( $error === $result['isError'], $result['content'][0]['text'] );
	return $error ? $result : json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
}

$created = wp_insert_term( 'Places', ATBDP_DIRECTORY_TYPE, [ 'slug' => 'reader-places' ] );
directorist_check( ! is_wp_error( $created ), 'Cannot create directory type.' );
$directory_id = (int) $created['term_id'];
update_term_meta( $directory_id, 'submission_form_fields', [
	'fields' => [
		'image_upload' => [ 'label' => 'Gallery', 'widget_name' => 'image_upload', 'field_key' => 'listing_img' ],
		'video' => [ 'label' => 'Video', 'widget_name' => 'video', 'field_key' => 'videourl' ],
		'fm_plan' => [ 'label' => 'Plan', 'widget_name' => 'pricing_plans', 'field_key' => 'fm_plan' ],
		'tagline' => [ 'label' => 'Tagline', 'widget_name' => 'tagline' ],
	],
] );
update_term_meta( $directory_id, 'single_listing_header', [
	[ 'placeholderKey' => 'listing-title-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'title', 'widget_name' => 'title', 'enable_tagline' => true ] ] ],
	[ 'placeholderKey' => 'slider-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'slider', 'widget_name' => 'slider' ] ] ],
	[ 'placeholderKey' => 'quick-widgets-placeholder', 'placeholders' => [ [ 'placeholderKey' => 'quick-action-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'share', 'widget_name' => 'share' ] ] ] ] ],
	[ 'placeholderKey' => 'more-widgets-placeholder', 'selectedWidgets' => [ [ 'widget_key' => 'price', 'widget_name' => 'price' ] ] ],
] );
update_term_meta( $directory_id, 'single_listings_contents', [ 'groups' => [ [ 'label' => 'Details', 'type' => 'general_group', 'fields' => [ 'tagline', 'image_upload' ] ] ] ] );
update_term_meta( $directory_id, 'enable_single_listing_page', '1' );
$id = wp_insert_post( [ 'post_type' => ATBDP_POST_TYPE, 'post_title' => 'Reader listing', 'post_status' => 'publish', 'post_content' => 'Visible content' ], true );
directorist_check( ! is_wp_error( $id ), 'Cannot create listing.' );
directorist_check( true === directorist_set_listing_directory( $id, $directory_id ), 'Cannot assign directory.' );
update_post_meta( $id, '_listing_img', [ 11, 12 ] );
update_post_meta( $id, '_image_upload', 'wrong-key' );
update_post_meta( $id, '_videourl', 'https://example.com/video' );
update_post_meta( $id, '_tagline', 'Hello' );
update_post_meta( $id, '_fm_plan', 'hidden-plan' );
update_post_meta( $id, '_unrelated_private_meta', 'must-not-leak' );
$before = get_post_meta( $id );
$out = directorist_call( [ 'id' => $id ] );
directorist_check( get_post_meta( $id ) === $before, 'Read must not write listing meta.' );
$by_key = [];
foreach ( $out['fields'] as $field ) { $by_key[ $field['key'] ] = $field; }
$encoded = wp_json_encode( $out );
directorist_check( ! isset( $by_key['fm_plan'] ), 'Plan fields must be omitted.' );
directorist_check( 'listing_img' === $by_key['image_upload']['field_key'] && [ 11, 12 ] === array_values( $by_key['image_upload']['value'] ), 'Preserve the configured gallery storage key. ' . $encoded );
directorist_check( 'https://example.com/video' === $by_key['video']['value'] && 'Hello' === $by_key['tagline']['value'], 'Read configured video and tagline values.' );
directorist_check( false === strpos( $encoded, 'hidden-plan' ) && false === strpos( $encoded, 'must-not-leak' ) && false === strpos( $encoded, 'wrong-key' ), 'Do not return excluded or wrong-key values.' );
directorist_check( $directory_id === $out['directory']['id'] && true === $out['single_page']['enabled'], 'Directory assignment.' );
directorist_check( true === $out['header']['title'] && true === $out['header']['tagline'] && [ 'slider' ] === $out['header']['thumbnail'] && [ 'price' ] === $out['header']['quick_info'] && [ 'share' ] === $out['header']['quick_actions'], 'Decode placeholder header widgets. ' . $encoded );
directorist_check( 'Details' === $out['sections'][0]['label'] && [ 'tagline', 'image_upload' ] === $out['sections'][0]['fields'], 'Section order.' );
update_term_meta( $directory_id, 'single_listing_header', [ 'listings_header' => [ 'thumbnail' => [ [ 'widget_name' => 'listing_slider' ] ], 'quick_info' => [ [ 'widget_name' => 'category' ] ], 'quick_actions' => [] ], 'options' => [ 'content_settings' => [ 'listing_title' => [ 'enable_title' => true, 'enable_tagline' => '0' ], 'listing_description' => [ 'enable' => 1 ] ] ] ] );
$legacy = directorist_call( [ 'id' => $id ] );
directorist_check( true === $legacy['header']['title'] && false === $legacy['header']['tagline'] && true === $legacy['header']['description'] && [ 'listing_slider' ] === $legacy['header']['thumbnail'], 'Decode the legacy header layout.' );
update_term_meta( $directory_id, 'single_listing_header', [ 'unrecognized' => true ] );
directorist_call( [ 'id' => $id ], true );
directorist_call( [ 'id' => 0 ], true );
$page = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Not a listing' ] );
directorist_call( [ 'id' => $page ], true );
echo 'OK (Directorist ' . ATBDP_VERSION . ', WordPress ' . get_bloginfo( 'version' ) . ', PHP ' . PHP_VERSION . ")\n";
