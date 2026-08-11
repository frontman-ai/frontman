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

function frontman_custom_css_assert_tool_error( callable $call, string $expected_message ): void {
	try {
		$call();
		throw new RuntimeException( 'Expected Custom CSS tool error was not thrown.' );
	} catch ( Frontman_Tool_Error $error ) {
		frontman_runtime_assert( false !== strpos( $error->getMessage(), $expected_message ), 'Unexpected Custom CSS tool error: ' . $error->getMessage() );
	}
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

function frontman_test_custom_css_read_tools(): void {
	$stylesheet = get_stylesheet();
	$target_css = '.tool-read { color: red; }';
	$current_css = '.tool-read { color: blue; }';
	$post = frontman_custom_css_update( $stylesheet, $target_css );
	frontman_custom_css_update( $stylesheet, $current_css );
	$revision = frontman_custom_css_revision_with_content( $post->ID, $target_css );
	$tool = new Frontman_Tool_Options();

	$current = $tool->get_custom_css( [ 'stylesheet' => $stylesheet ] );
	frontman_runtime_assert( $post->ID === $current['parent_post_id'], 'Current CSS metadata returned wrong parent.' );
	frontman_runtime_assert( strlen( $current_css ) === $current['persisted_css_bytes'], 'Current CSS metadata returned wrong byte count.' );
	frontman_runtime_assert( hash( 'sha256', $current_css ) === $current['persisted_css_sha256'], 'Current CSS metadata returned wrong fingerprint.' );
	frontman_runtime_assert( false === $current['preprocessor_source_present'], 'Plain current CSS unexpectedly reported preprocessor source.' );

	$listed = $tool->list_custom_css_revisions( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID ] );
	frontman_runtime_assert( 'available' === $listed['status'], 'Revision listing did not report available history.' );
	$listed_by_id = array_column( $listed['revisions'], null, 'revision_id' );
	frontman_runtime_assert( isset( $listed_by_id[ $revision->ID ] ), 'Revision listing omitted selected revision.' );
	frontman_runtime_assert( ! array_key_exists( 'css', $listed_by_id[ $revision->ID ] ), 'Revision listing exposed full CSS.' );
	frontman_runtime_assert( hash( 'sha256', $target_css ) === $listed_by_id[ $revision->ID ]['css_sha256'], 'Revision listing returned wrong fingerprint.' );

	$inspected = $tool->get_custom_css_revision( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID, 'revision_id' => $revision->ID ] );
	frontman_runtime_assert( $target_css === $inspected['css'], 'Revision inspection returned wrong CSS.' );

	$disable_revisions = static function( int $revisions, WP_Post $candidate ) use ( $post ): int {
		return $post->ID === $candidate->ID ? 0 : $revisions;
	};
	add_filter( 'wp_revisions_to_keep', $disable_revisions, 10, 2 );
	$disabled = $tool->list_custom_css_revisions( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID ] );
	frontman_runtime_assert( 'revisions_disabled' === $disabled['status'], 'Revision listing did not report disabled revisions.' );
	remove_filter( 'wp_revisions_to_keep', $disable_revisions, 10 );

	foreach ( wp_get_post_revisions( $post->ID ) as $existing_revision ) {
		wp_delete_post_revision( $existing_revision->ID );
	}
	$empty_list = $tool->list_custom_css_revisions( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID ] );
	frontman_runtime_assert( 'no_revisions' === $empty_list['status'], 'Revision listing did not report enabled empty history.' );

	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $stylesheet, $post ): void {
			$tool->list_custom_css_revisions( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID + 1 ] );
		},
		'parent post'
	);
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $stylesheet, $post ): void {
			$tool->get_custom_css_revision( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID, 'revision_id' => PHP_INT_MAX ] );
		},
		'not found'
	);
	$cross_parent = frontman_custom_css_update( 'frontman-runtime-cross-parent-tool', '.cross-parent { color: red; }' );
	$cross_revision = frontman_custom_css_revision_with_content( $cross_parent->ID, '.cross-parent { color: red; }' );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $stylesheet, $post, $cross_revision ): void {
			$tool->get_custom_css_revision( [ 'stylesheet' => $stylesheet, 'parent_post_id' => $post->ID, 'revision_id' => $cross_revision->ID ] );
		},
		'does not belong'
	);
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $post ): void {
			$tool->list_custom_css_revisions( [ 'stylesheet' => 'frontman-runtime-inactive', 'parent_post_id' => $post->ID ] );
		},
		'active stylesheet'
	);
}

function frontman_test_custom_css_restore_tool(): void {
	$stylesheet = get_stylesheet();
	$target_css = '.tool-restore { color: red; }';
	$current_css = '.tool-restore { color: blue; }';
	$post = frontman_custom_css_update( $stylesheet, $target_css );
	frontman_custom_css_update( $stylesheet, $current_css );
	$revision = frontman_custom_css_revision_with_content( $post->ID, $target_css );
	$tool = new Frontman_Tool_Options();
	$restore_input = [
		'stylesheet'              => $stylesheet,
		'parent_post_id'          => $post->ID,
		'revision_id'             => $revision->ID,
		'expected_current_sha256' => hash( 'sha256', $current_css ),
		'confirm'                 => true,
	];
	$unrelated_post_id = wp_insert_post(
		wp_slash(
			[
				'post_title'   => 'Unrelated scope fixture',
				'post_content' => 'private unrelated content',
				'post_status'  => 'publish',
				'post_type'    => 'page',
			]
		),
		true
	);
	frontman_runtime_assert( ! is_wp_error( $unrelated_post_id ), 'Could not create poisoned scope fixture.' );
	set_theme_mod( 'custom_css_post_id', $unrelated_post_id );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $stylesheet ): void {
			$tool->get_custom_css( [ 'stylesheet' => $stylesheet ] );
		},
		'invalid post'
	);
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( $restore_input );
		},
		'invalid post'
	);
	frontman_runtime_assert( 'private unrelated content' === get_post( $unrelated_post_id )->post_content, 'Poisoned scope restore changed unrelated post content.' );
	set_theme_mod( 'custom_css_post_id', $post->ID );

	$registry = new Frontman_Tools();
	$tool->register( $registry );
	$string_confirmation = $registry->call(
		'wp_restore_custom_css_revision',
		$registry->sanitize_input( 'wp_restore_custom_css_revision', array_merge( $restore_input, [ 'confirm' => 'true' ] ) )
	);
	frontman_runtime_assert( true === $string_confirmation['isError'], 'String restore confirmation was accepted.' );
	frontman_runtime_assert( false !== strpos( $string_confirmation['content'][0]['text'], 'confirm=true' ), 'String confirmation returned unexpected restore error.' );
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'String confirmation changed current CSS.' );
	$malformed_revision = $registry->call(
		'wp_restore_custom_css_revision',
		$registry->sanitize_input( 'wp_restore_custom_css_revision', array_merge( $restore_input, [ 'revision_id' => $revision->ID . 'junk' ] ) )
	);
	frontman_runtime_assert( true === $malformed_revision['isError'], 'Malformed restore revision ID was accepted.' );
	frontman_runtime_assert( false !== strpos( $malformed_revision['content'][0]['text'], 'positive integer' ), 'Malformed revision ID returned unexpected restore error.' );
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Malformed revision ID changed current CSS.' );

	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( array_merge( $restore_input, [ 'confirm' => false ] ) );
		},
		'confirm=true'
	);
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Confirmation failure changed current CSS.' );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( array_merge( $restore_input, [ 'expected_current_sha256' => hash( 'sha256', 'stale' ) ] ) );
		},
		'changed'
	);
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Stale-state failure changed current CSS.' );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( array_merge( $restore_input, [ 'parent_post_id' => $restore_input['parent_post_id'] + 1 ] ) );
		},
		'parent post'
	);
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Parent mismatch changed current CSS.' );

	$cross_parent = frontman_custom_css_update( 'frontman-runtime-cross-parent-restore', '.cross-restore { color: red; }' );
	$cross_revision = frontman_custom_css_revision_with_content( $cross_parent->ID, '.cross-restore { color: red; }' );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input, $cross_revision ): void {
			$tool->restore_custom_css_revision( array_merge( $restore_input, [ 'revision_id' => $cross_revision->ID ] ) );
		},
		'does not belong'
	);
	frontman_runtime_assert( $current_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Cross-parent revision failure changed current CSS.' );

	frontman_custom_css_update( $stylesheet, $current_css, 'source-v2' );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( $restore_input );
		},
		'preprocessor'
	);
	$preprocessor_post = frontman_custom_css_persisted_post( $post->ID );
	frontman_runtime_assert( $current_css === $preprocessor_post->post_content, 'Preprocessor rejection changed compiled CSS.' );
	frontman_runtime_assert( 'source-v2' === $preprocessor_post->post_content_filtered, 'Preprocessor rejection changed source CSS.' );

	frontman_custom_css_update( $stylesheet, $current_css );
	$restored = $tool->restore_custom_css_revision( $restore_input );
	frontman_runtime_assert( [ 'selected_revision_id', 'before', 'after' ] === array_keys( $restored ), 'Restore receipt exposed unsupported fields.' );
	frontman_runtime_assert( $revision->ID === $restored['selected_revision_id'], 'Restore receipt returned wrong selected revision.' );
	frontman_runtime_assert( hash( 'sha256', $current_css ) === $restored['before']['persisted_css_sha256'], 'Restore receipt returned wrong before fingerprint.' );
	frontman_runtime_assert( hash( 'sha256', $target_css ) === $restored['after']['persisted_css_sha256'], 'Restore receipt returned wrong after fingerprint.' );
	frontman_runtime_assert( $target_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Restore tool did not persist selected plain CSS revision.' );

	frontman_custom_css_update( $stylesheet, $current_css );
	$transform = static function( array $data ) use ( $target_css ): array {
		if ( 'custom_css' === $data['post_type'] && $target_css === $data['post_content'] ) {
			$data['post_content'] .= ' /* transformed */';
		}

		return $data;
	};
	add_filter( 'wp_insert_post_data', $transform );
	$transformed = $tool->restore_custom_css_revision( $restore_input );
	remove_filter( 'wp_insert_post_data', $transform );
	$transformed_css = $target_css . ' /* transformed */';
	frontman_runtime_assert( hash( 'sha256', $transformed_css ) === $transformed['after']['persisted_css_sha256'], 'Restore receipt did not report transformed persisted CSS.' );
	frontman_runtime_assert( $transformed_css === frontman_custom_css_persisted_post( $post->ID )->post_content, 'Restore tool persisted unexpected transformed output.' );

	frontman_custom_css_update( $stylesheet, $current_css );
	$change_scope = static function( array $data ) use ( $target_css ): array {
		if ( 'custom_css' === $data['post_type'] && $target_css === $data['post_content'] ) {
			$data['post_name'] = 'changed-custom-css-scope';
		}

		return $data;
	};
	add_filter( 'wp_insert_post_data', $change_scope );
	frontman_custom_css_assert_tool_error(
		static function() use ( $tool, $restore_input ): void {
			$tool->restore_custom_css_revision( $restore_input );
		},
		'ambiguous'
	);
	remove_filter( 'wp_insert_post_data', $change_scope );
}

frontman_characterize_custom_css_revision_history();
frontman_characterize_custom_css_revision_availability();
frontman_characterize_custom_css_revision_scope();
frontman_characterize_plain_custom_css_restore();
frontman_characterize_preprocessor_custom_css_restore();
frontman_characterize_custom_css_save_transformation();
frontman_characterize_custom_css_conflicts();
frontman_test_custom_css_read_tools();
frontman_test_custom_css_restore_tool();
