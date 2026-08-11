<?php

if ( ! defined( 'ABSPATH' ) ) {
	throw new RuntimeException( 'WordPress must be loaded before the Custom CSS runtime test.' );
}

function frontman_custom_css_update( string $stylesheet, string $css, string $preprocessed = '' ): WP_Post {
	$post = wp_update_custom_css_post(
		$css,
		[
			'stylesheet'   => $stylesheet,
			'preprocessed' => $preprocessed,
		]
	);
	frontman_runtime_assert( $post instanceof WP_Post, 'Could not update Custom CSS fixture.' );
	clean_post_cache( $post->ID );

	return get_post( $post->ID, OBJECT, 'raw' );
}

function frontman_custom_css_revision_with_content( int $parent_id, string $content ): WP_Post {
	foreach ( wp_get_post_revisions( $parent_id ) as $revision ) {
		if ( $content === $revision->post_content ) {
			return $revision;
		}
	}

	throw new RuntimeException( 'Expected Custom CSS revision content was not found.' );
}

function frontman_custom_css_persisted_post( int $post_id ): WP_Post {
	clean_post_cache( $post_id );
	$post = get_post( $post_id, OBJECT, 'raw' );
	frontman_runtime_assert( $post instanceof WP_Post, 'Custom CSS post disappeared.' );

	return $post;
}

function frontman_characterize_custom_css_revision_history(): void {
	$stylesheet = 'frontman-runtime-history';
	$first = frontman_custom_css_update( $stylesheet, '.history { color: red; }' );
	$first_revisions = wp_get_post_revisions( $first->ID );
	frontman_runtime_assert( 1 <= count( $first_revisions ), 'Initial Custom CSS save did not create a revision.' );

	frontman_custom_css_update( $stylesheet, '.history { color: blue; }' );
	$second_revisions = wp_get_post_revisions( $first->ID );
	frontman_runtime_assert( count( $first_revisions ) < count( $second_revisions ), 'Changed Custom CSS save did not create another revision.' );
	frontman_custom_css_revision_with_content( $first->ID, '.history { color: red; }' );
	frontman_custom_css_revision_with_content( $first->ID, '.history { color: blue; }' );
}

function frontman_characterize_custom_css_revision_availability(): void {
	$disable_revisions = static function( int $revisions, WP_Post $post ): int {
		return 'custom_css' === $post->post_type ? 0 : $revisions;
	};
	add_filter( 'wp_revisions_to_keep', $disable_revisions, 10, 2 );
	$disabled = frontman_custom_css_update( 'frontman-runtime-disabled', '.disabled { color: red; }' );
	frontman_runtime_assert( ! wp_revisions_enabled( $disabled ), 'Custom CSS revisions should be disabled by the test filter.' );
	frontman_runtime_assert( [] === wp_get_post_revisions( $disabled->ID ), 'Disabled Custom CSS revisions should have no history.' );
	remove_filter( 'wp_revisions_to_keep', $disable_revisions, 10 );

	$empty_id = wp_insert_post(
		wp_slash(
			[
				'post_title'   => 'frontman-runtime-empty',
				'post_name'    => 'frontman-runtime-empty',
				'post_type'    => 'custom_css',
				'post_status'  => 'publish',
				'post_content' => '.empty { color: red; }',
			]
		),
		true
	);
	frontman_runtime_assert( ! is_wp_error( $empty_id ), 'Could not create empty-history Custom CSS fixture.' );
	$empty = get_post( $empty_id );
	frontman_runtime_assert( wp_revisions_enabled( $empty ), 'Custom CSS revisions should be enabled for the empty-history fixture.' );
	frontman_runtime_assert( [] === wp_get_post_revisions( $empty_id ), 'Directly inserted Custom CSS unexpectedly has revision history.' );
}

function frontman_characterize_custom_css_revision_scope(): void {
	$first = frontman_custom_css_update( 'frontman-runtime-parent-one', '.parent-one { color: red; }' );
	$second = frontman_custom_css_update( 'frontman-runtime-parent-two', '.parent-two { color: blue; }' );
	$revision = frontman_custom_css_revision_with_content( $first->ID, '.parent-one { color: red; }' );
	$missing_revision_id = PHP_INT_MAX;

	frontman_runtime_assert( null === wp_get_post_revision( $missing_revision_id ), 'Missing revision lookup should return null.' );
	frontman_runtime_assert( $first->ID === wp_is_post_revision( $revision ), 'Revision should resolve to its actual Custom CSS parent.' );
	frontman_runtime_assert( $second->ID !== $revision->post_parent, 'Cross-parent revision fixture unexpectedly matched.' );

	$active_stylesheet = get_stylesheet();
	$active = frontman_custom_css_update( $active_stylesheet, '.active { color: red; }' );
	$replacement = frontman_custom_css_update( 'frontman-runtime-replacement-theme', '.replacement { color: blue; }' );
	$replace_stylesheet = static function(): string {
		return 'frontman-runtime-replacement-theme';
	};
	add_filter( 'pre_option_stylesheet', $replace_stylesheet );
	frontman_runtime_assert( 'frontman-runtime-replacement-theme' === get_stylesheet(), 'Active stylesheet change simulation failed.' );
	frontman_runtime_assert( $replacement->ID === wp_get_custom_css_post()->ID, 'Default Custom CSS lookup did not follow changed active stylesheet.' );
	frontman_runtime_assert( $active->ID !== wp_get_custom_css_post()->ID, 'Stale expected Custom CSS parent still matched after stylesheet change.' );
	remove_filter( 'pre_option_stylesheet', $replace_stylesheet );
}

function frontman_characterize_plain_custom_css_restore(): void {
	$stylesheet = 'frontman-runtime-plain-restore';
	$target_css = '.plain { color: red; }';
	$current_css = '.plain { color: blue; }';
	$post = frontman_custom_css_update( $stylesheet, $target_css );
	frontman_custom_css_update( $stylesheet, $current_css );
	$revision = frontman_custom_css_revision_with_content( $post->ID, $target_css );

	$before_revision_count = count( wp_get_post_revisions( $post->ID ) );
	$restored_id = wp_restore_post_revision( $revision, [ 'post_content' ] );
	frontman_runtime_assert( $post->ID === $restored_id, 'Generic Custom CSS revision restore did not return parent ID.' );
	$generic = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( $target_css === $generic->post_content, 'Generic restore did not persist plain revision CSS.' );
	frontman_runtime_assert( '' === $generic->post_content_filtered, 'Generic plain CSS restore changed preprocessor source.' );
	$generic_created_revision = $before_revision_count < count( wp_get_post_revisions( $post->ID ) );

	frontman_custom_css_update( $stylesheet, $current_css );
	$before_revision_count = count( wp_get_post_revisions( $post->ID ) );
	frontman_custom_css_update( $stylesheet, $revision->post_content );
	$replayed = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( $target_css === $replayed->post_content, 'Custom CSS replay did not persist plain revision CSS.' );
	frontman_runtime_assert( '' === $replayed->post_content_filtered, 'Plain Custom CSS replay changed preprocessor source.' );
	$replay_created_revision = $before_revision_count < count( wp_get_post_revisions( $post->ID ) );
	frontman_runtime_assert( $generic_created_revision, 'Generic restore did not create the observed default-configuration revision.' );
	frontman_runtime_assert( $replay_created_revision, 'Custom CSS replay did not create the observed default-configuration revision.' );

	fwrite( STDOUT, 'Custom CSS plain restore revision observations: generic=' . ( $generic_created_revision ? 'created' : 'not-created' ) . ', replay=' . ( $replay_created_revision ? 'created' : 'not-created' ) . "\n" );
}

function frontman_characterize_preprocessor_custom_css_restore(): void {
	$stylesheet = 'frontman-runtime-preprocessor';
	$compile = static function( array $data, array $args ) use ( $stylesheet ): array {
		if ( $stylesheet === $args['stylesheet'] ) {
			$data['css'] = 'compiled{' . $args['css'] . '}';
			$data['preprocessed'] = $args['css'];
		}

		return $data;
	};
	add_filter( 'update_custom_css_data', $compile, 10, 2 );

	$post = frontman_custom_css_update( $stylesheet, 'source-v1' );
	frontman_custom_css_update( $stylesheet, 'source-v2' );
	$revision = frontman_custom_css_revision_with_content( $post->ID, 'compiled{source-v1}' );
	frontman_runtime_assert( '' === $revision->post_content_filtered, 'Default revision unexpectedly captured preprocessor source.' );

	wp_restore_post_revision( $revision, [ 'post_content' ] );
	$generic = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( 'compiled{source-v1}' === $generic->post_content, 'Generic preprocessor restore changed compiled target CSS.' );
	frontman_runtime_assert( 'source-v2' === $generic->post_content_filtered, 'Generic restore should leave current preprocessor source unchanged.' );

	frontman_custom_css_update( $stylesheet, 'source-v2' );
	frontman_custom_css_update( $stylesheet, $revision->post_content );
	$replayed = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( 'compiled{compiled{source-v1}}' === $replayed->post_content, 'Replay did not pass revision CSS through preprocessor filter.' );
	frontman_runtime_assert( 'compiled{source-v1}' === $replayed->post_content_filtered, 'Replay did not replace preprocessor source with revision CSS.' );
	remove_filter( 'update_custom_css_data', $compile, 10 );
}

function frontman_characterize_custom_css_save_transformation(): void {
	$stylesheet = 'frontman-runtime-save-filter';
	$target_css = '.filtered { color: red; }';
	$current_css = '.filtered { color: blue; }';
	$post = frontman_custom_css_update( $stylesheet, $target_css );
	frontman_custom_css_update( $stylesheet, $current_css );
	$revision = frontman_custom_css_revision_with_content( $post->ID, $target_css );
	$transform = static function( array $data ): array {
		if ( 'custom_css' === $data['post_type'] && '.filtered { color: red; }' === $data['post_content'] ) {
			$data['post_content'] .= ' /* transformed */';
		}

		return $data;
	};
	add_filter( 'wp_insert_post_data', $transform );

	wp_restore_post_revision( $revision, [ 'post_content' ] );
	$observed = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( $target_css !== $observed->post_content, 'Save filter did not transform generic restore target.' );
	frontman_runtime_assert( $target_css . ' /* transformed */' === $observed->post_content, 'Generic restore persisted unexpected transformed CSS.' );

	frontman_custom_css_update( $stylesheet, $current_css );
	frontman_custom_css_update( $stylesheet, $revision->post_content );
	$observed = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( $target_css . ' /* transformed */' === $observed->post_content, 'Replay persisted unexpected transformed CSS.' );
	remove_filter( 'wp_insert_post_data', $transform );
}

function frontman_characterize_custom_css_conflicts(): void {
	$stylesheet = 'frontman-runtime-conflict';
	$post = frontman_custom_css_update( $stylesheet, '.conflict { color: red; }' );
	frontman_custom_css_update( $stylesheet, '.conflict { color: blue; }' );
	$revision = frontman_custom_css_revision_with_content( $post->ID, '.conflict { color: red; }' );
	$expected_hash = hash( 'sha256', frontman_custom_css_persisted_post( $post->ID )->post_content );

	frontman_custom_css_update( $stylesheet, '.conflict { color: green; }' );
	$current_hash = hash( 'sha256', frontman_custom_css_persisted_post( $post->ID )->post_content );
	frontman_runtime_assert( $expected_hash !== $current_hash, 'Stale expected Custom CSS state was not detectable.' );

	$checked_hash = $current_hash;
	frontman_custom_css_update( $stylesheet, '.conflict { color: purple; }' );
	frontman_runtime_assert( $checked_hash !== hash( 'sha256', frontman_custom_css_persisted_post( $post->ID )->post_content ), 'Concurrent Custom CSS write simulation failed.' );
	wp_restore_post_revision( $revision, [ 'post_content' ] );
	frontman_runtime_assert( '.conflict { color: red; }' === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Generic restore did not overwrite simulated concurrent write.' );
}

frontman_characterize_custom_css_revision_history();
frontman_characterize_custom_css_revision_availability();
frontman_characterize_custom_css_revision_scope();
frontman_characterize_plain_custom_css_restore();
frontman_characterize_preprocessor_custom_css_restore();
frontman_characterize_custom_css_save_transformation();
frontman_characterize_custom_css_conflicts();
