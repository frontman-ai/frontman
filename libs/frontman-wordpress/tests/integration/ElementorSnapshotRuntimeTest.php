<?php

require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/includes/class-frontman-elementor-data.php';
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/tools/class-tool-elementor.php';

foreach ( [ 'utf8mb3', 'utf8mb4' ] as $charset ) {
	$post_id = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Snapshot charset test', 'post_status' => 'draft' ], true );
	frontman_runtime_assert( ! is_wp_error( $post_id ), 'Could not create snapshot fixture.' );
	$original_table = $wpdb->postmeta;
	$table = $wpdb->prefix . 'frontman_snapshot_' . $charset;
	frontman_runtime_assert( false !== $wpdb->query( "CREATE TEMPORARY TABLE $table LIKE $original_table" ), 'Could not create isolated metadata table.' );
	try {
		frontman_runtime_assert( false !== $wpdb->query( "ALTER TABLE $table MODIFY meta_value LONGTEXT CHARACTER SET $charset COLLATE {$charset}_general_ci" ), 'Could not configure test metadata charset.' );
		$wpdb->postmeta = $table;
		wp_cache_delete( $post_id, 'post_meta' );
		$key = '_frontman_elementor_rollbacks';
		$text = "🎃🎄💜 \"quoted\" \\path\nnext";
		$data = [ [ 'id' => 'heading1', 'elType' => 'widget', 'widgetType' => 'heading', 'settings' => [ 'title' => $text ], 'elements' => [] ] ];
		update_post_meta( $post_id, '_elementor_data', wp_slash( wp_json_encode( $data ) ) );
		$rollback = Frontman_Elementor_Data::make_page_rollback( 'saved_page_data', $data );
		$old_result = update_post_meta( $post_id, $key, wp_slash( [ $rollback ] ) );
		frontman_runtime_assert( 'utf8mb3' === $charset ? false === $old_result : false !== $old_result, 'Legacy array writer did not exhibit expected charset behavior.' );
		delete_post_meta( $post_id, $key );

		$legacy = Frontman_Elementor_Data::make_page_rollback( 'saved_page_data', [] );
		frontman_runtime_assert( false !== update_post_meta( $post_id, $key, wp_slash( [ $legacy ] ) ), 'Could not seed legacy array snapshot.' );
		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		wp_cache_delete( $post_id, 'post_meta' );
		$stored = get_post_meta( $post_id, $key, true );
		frontman_runtime_assert( is_string( $stored ) && [ $rollback, $legacy ] === json_decode( $stored, true ), 'Snapshot JSON did not survive real database readback.' );
		frontman_runtime_assert( 0 === preg_match( '/[^\x00-\x7f]/', $stored ), 'Snapshot storage contains unescaped Unicode.' );

		$tool = new Frontman_Tool_Elementor();
		$updated = $tool->update_element( [ 'post_id' => $post_id, 'element_id' => 'heading1', 'settings' => [ 'title' => 'Changed' ] ] );
		frontman_runtime_assert( true === $updated['success'], 'Granular edit failed with emoji in its snapshot.' );
		$restored = $tool->restore_rollback( [ 'post_id' => $post_id, 'rollback_id' => $updated['rollback_id'], 'confirm' => true ] );
		wp_cache_delete( $post_id, 'post_meta' );
		frontman_runtime_assert( true === $restored['success'] && $data === Frontman_Elementor_Data::get_page_data( $post_id ), 'Granular rollback did not restore exact original content.' );
		$restored = $tool->restore_rollback( [ 'post_id' => $post_id, 'rollback_id' => $legacy['rollback_id'], 'confirm' => true ] );
		frontman_runtime_assert( true === $restored['success'] && [] === Frontman_Elementor_Data::get_page_data( $post_id ), 'Legacy snapshot was not restorable after JSON conversion.' );
		fwrite( STDOUT, "OK (Elementor snapshots, $charset)\n" );
	} finally {
		$wpdb->postmeta = $original_table;
		wp_cache_delete( $post_id, 'post_meta' );
		$wpdb->query( "DROP TEMPORARY TABLE $table" );
		wp_delete_post( $post_id, true );
	}
}
