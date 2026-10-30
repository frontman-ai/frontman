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

( static function () use ( $wpdb ): void {
	$post_id = wp_insert_post( [ 'post_type' => 'page', 'post_title' => 'Native Elementor mutations', 'post_status' => 'draft' ], true );
	frontman_runtime_assert( is_int( $post_id ) && $post_id > 0, 'Could not create mutation fixture.' );
	$tools = new Frontman_Tools();
	( new Frontman_Tool_Elementor() )->register( $tools );
	$key = '_frontman_elementor_rollbacks';
	$events = [];
	$observe = static function ( $meta_id, $id, $name ) use ( $post_id, $key, &$events ): void {
		if ( $post_id === $id && in_array( $name, [ $key, '_elementor_data' ], true ) ) {
			$events[] = $name;
		}
	};
	add_action( 'added_post_meta', $observe, 10, 3 );
	add_action( 'updated_post_meta', $observe, 10, 3 );
	$read = static function ( string $name ) use ( $post_id ) {
		wp_cache_delete( $post_id, 'post_meta' );
		return get_post_meta( $post_id, $name, true );
	};
	$page = static fn() => json_decode( $read( '_elementor_data' ), true, 512, JSON_THROW_ON_ERROR );
	$state = static function () use ( $wpdb, $post_id ): array {
		return $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$wpdb->postmeta} WHERE post_id = %d ORDER BY meta_id", $post_id ), ARRAY_A );
	};
	$seed = static function ( array $tree ) use ( $post_id, $key, $page, &$events ): array {
		delete_post_meta( $post_id, $key );
		update_post_meta( $post_id, '_elementor_data', wp_slash( wp_json_encode( $tree, JSON_PRESERVE_ZERO_FRACTION ) ) );
		$events = [];
		return $page();
	};
	$call = static function ( string $name, array $input ) use ( $tools, $post_id ): array {
		$name = 'wp_elementor_' . $name;
		$result = $tools->call( $name, $tools->sanitize_input( $name, $input + [ 'post_id' => $post_id ] ) );
		frontman_runtime_assert( false === $result['isError'], $name . ': ' . wp_json_encode( $result ) );
		return json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR );
	};
	$reject = static function ( string $name, array $input, bool $raw_rejection = false ) use ( $tools, $post_id, $state, &$events ): void {
		$name = 'wp_elementor_' . $name;
		$input += [ 'post_id' => $post_id ];
		$before = $state();
		$events = [];
		$result = $tools->call( $name, $input );
		frontman_runtime_assert( true === $result['isError'], $name . ' accepted invalid handler input.' );
		if ( $raw_rejection ) {
			$rejected = false;
			try {
				$tools->sanitize_input( $name, $input );
			} catch ( Frontman_Tool_Error $error ) {
				$rejected = true;
			}
			frontman_runtime_assert( $rejected, $name . ' accepted malformed raw input.' );
		}
		frontman_runtime_assert( [] === $events && $before === $state(), $name . ' rejection changed SQL metadata.' );
	};
	$persisted = static function ( array $before, array $result ) use ( $read, $key, &$events ): void {
		frontman_runtime_assert( [ $key, '_elementor_data' ] === $events, 'Mutation must persist one snapshot before one page write.' );
		$snapshots = json_decode( $read( $key ), true, 512, JSON_THROW_ON_ERROR );
		frontman_runtime_assert( 1 === count( $snapshots ) && $before === $snapshots[0]['data'] && $result['rollback_id'] === $snapshots[0]['rollback_id'], 'Snapshot must strictly preserve the original tree, including 1.0.' );
	};
	$restore = static function ( array $before, array $result ) use ( $call, $page ): void {
		$call( 'restore_rollback', [ 'rollback_id' => $result['rollback_id'], 'confirm' => true ] );
		frontman_runtime_assert( json_decode( wp_json_encode( $before ), true ) === $page(), 'One rollback did not restore the original SQL page.' );
	};
	$ids = static function ( array $tree ) use ( &$ids ): array {
		$result = [];
		foreach ( $tree as $node ) {
			$result[] = $node['id'];
			$result = array_merge( $result, $ids( $node['elements'] ?? [] ) );
		}
		return $result;
	};
	$fresh = static function ( array $nodes, array $before ) use ( $ids ): void {
		$new_ids = $ids( $nodes );
		frontman_runtime_assert( count( $new_ids ) === count( array_unique( $new_ids ) ) && ! in_array( '', $new_ids, true ) && [] === array_intersect( $new_ids, $ids( $before ) ), 'New subtree IDs must be unique and disjoint from the source.' );
	};
	$leaf = [ 'id' => 'leaf', 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [ 'text' => "Keep \"quoted\" \\path\nnext", 'size' => 1.0, 'width_mobile' => [ 'size' => 90 ], 'link' => [ 'url' => '/old', 'external' => true ] ], 'elements' => [] ];
	$target = [ 'id' => 'target', 'elType' => 'container', 'settings' => [ 'flex_direction_mobile' => 'column', 'link' => [ 'url' => '/old', 'external' => true ] ], 'elements' => [ $leaf ] ];
	$sibling = array_replace( $leaf, [ 'id' => 'first' ] );
	$tree = [ [ 'id' => 'row', 'elType' => 'container', 'settings' => [], 'elements' => [ $sibling, $target, array_replace( $leaf, [ 'id' => 'last' ] ) ] ], array_replace( $leaf, [ 'id' => 'rootwidget' ] ) ];
	$button = [ 'elType' => 'widget', 'widgetType' => 'button', 'settings' => [], 'elements' => [] ];
	$companion = [ 'elType' => 'container', 'elements' => [ $button ] ];
	$original_table = $wpdb->postmeta;
	$table = $wpdb->prefix . 'frontman_mutation_failure';
	try {
		foreach ( [ 'first', 'target', 'last', 'row', 'leaf', 'first' ] as $index => $anchor ) {
			$before = $seed( $tree );
			if ( 5 === $index ) {
				$call( 'move_element', [ 'element_id' => $anchor, 'parent_id' => 'target', 'position' => 0 ] );
				$before = $seed( $page() );
			}
			$context = Frontman_Elementor_Data::get_element_context( $before, $anchor );
			$result = $call( 'add_element', [ 'after_element_id' => $anchor, 'element' => $companion ] );
			$persisted( $before, $result );
			$data = $page();
			$inserted = Frontman_Elementor_Data::get_element_context( $data, $result['element_id'] );
			frontman_runtime_assert( [ $context['parent_id'], $context['position'] + 1 ] === [ $result['parent_id'], $result['position'] ] && $result['position'] === $inserted['position'] && $result['parent_id'] === $inserted['parent_id'], 'Relative insertion did not resolve the current anchor placement.' );
			$fresh( [ $inserted['element'] ], $before );
			$expected = $before;
			Frontman_Elementor_Data::insert_element( $expected, $inserted['element'], $context['parent_id'], $context['position'] + 1 );
			frontman_runtime_assert( json_decode( wp_json_encode( $expected ), true ) === $data, 'Relative insertion changed source or siblings.' );
			$restore( $before, $result );
		}
		foreach ( [ 'target', 'leaf' ] as $id ) {
			foreach ( [ false, true ] as $override ) {
				$before = $seed( $tree );
				$input = [ 'element_id' => $id ] + ( $override ? [ 'settings' => [ 'link' => [ 'url' => '/new' ] ] ] : [] );
				$result = $call( 'duplicate_element', $input );
				$persisted( $before, $result );
				$data = $page();
				$source = Frontman_Elementor_Data::get_element( $before, $id );
				$clone = Frontman_Elementor_Data::get_element_context( $data, $result['new_element_id'] );
				$context = Frontman_Elementor_Data::get_element_context( $before, $id );
				frontman_runtime_assert( json_decode( wp_json_encode( $source ), true ) === Frontman_Elementor_Data::get_element( $data, $id ), 'Duplicate changed source settings or descendants.' );
				$settings = $override ? array_merge( $source['settings'], $input['settings'] ) : $source['settings'];
				frontman_runtime_assert( json_decode( wp_json_encode( $settings ), true ) === $clone['element']['settings'] && [ $context['parent_id'], $context['position'] + 1 ] === [ $clone['parent_id'], $clone['position'] ], 'Duplicate overrides must shallow-merge only the cloned root at the next position.' );
				if ( 'target' === $id ) {
					frontman_runtime_assert( json_decode( wp_json_encode( $leaf['settings'] ), true ) === $clone['element']['elements'][0]['settings'], 'Duplicate override changed descendant settings.' );
				}
				$expected = $before;
				Frontman_Elementor_Data::insert_element( $expected, $clone['element'], $context['parent_id'], $context['position'] + 1 );
				frontman_runtime_assert( json_decode( wp_json_encode( $expected ), true ) === $data, 'Duplicate changed siblings or unrelated elements.' );
				$fresh( [ $clone['element'] ], $before );
				$restore( $before, $result );
			}
		}
		foreach ( [ 'row', 'target', 'leaf', 'rootwidget' ] as $id ) {
			foreach ( [ false, true ] as $with_companion ) {
				$before = $seed( $tree );
				$context = Frontman_Elementor_Data::get_element_context( $before, $id );
				$input = [ 'element_id' => $id ] + ( $with_companion ? [ 'settings' => [ 'flex_wrap' => 'nowrap', 'flex_direction_mobile' => 'column' ], 'element_after' => $companion ] : [] );
				$result = $call( 'wrap_element', $input );
				$persisted( $before, $result );
				$data = $page();
				$wrapped = Frontman_Elementor_Data::get_element_context( $data, $result['wrapper_id'] );
				$wrapper = $wrapped['element'];
				frontman_runtime_assert( [ $context['parent_id'], $context['position'] ] === [ $result['parent_id'], $result['position'] ] && [ $result['parent_id'], $result['position'] ] === [ $wrapped['parent_id'], $wrapped['position'] ], 'Wrapper must occupy the exact original position.' );
				frontman_runtime_assert( ( null !== $context['parent_id'] ) === $wrapper['isInner'] && 'container' === $wrapper['elType'], 'Wrapper type or root/nested inner flag is incorrect.' );
				$defaults = [ 'content_width' => 'full', 'flex_direction' => 'row', 'flex_wrap' => 'wrap' ];
				frontman_runtime_assert( array_merge( $defaults, $input['settings'] ?? [] ) === $wrapper['settings'], 'Wrapper must retain row defaults and caller overrides.' );
				frontman_runtime_assert( json_decode( wp_json_encode( $context['element'] ), true ) === $wrapper['elements'][0], 'Wrapping changed original IDs, settings or responsive descendants.' );
				frontman_runtime_assert( ( $with_companion ? 2 : 1 ) === count( $wrapper['elements'] ) && ( $with_companion ? $wrapper['elements'][1]['id'] : null ) === $result['added_element_id'], 'Companion placement or nullable response ID is incorrect.' );
				$new = $wrapper;
				$new['elements'] = array_slice( $wrapper['elements'], 1 );
				$fresh( [ $new ], $before );
				$expected = $before;
				frontman_runtime_assert( Frontman_Elementor_Data::wrap_at_context( $expected, $context, $wrapper ) && json_decode( wp_json_encode( $expected ), true ) === $data, 'Wrapping changed other elements or sibling order.' );
				$restore( $before, $result );
			}
		}
		$seed( $tree );
		foreach ( [
			[ 'add_element', [ 'after_element_id' => 'first', 'parent_id' => null, 'element' => $companion ] ],
			[ 'add_element', [ 'after_element_id' => 'first', 'position' => -1, 'element' => $companion ] ],
			[ 'add_element', [ 'after_element_id' => 'unknown', 'element' => $companion ] ],
			[ 'duplicate_element', [ 'element_id' => 'leaf', 'settings' => [] ] ],
			[ 'wrap_element', [ 'element_id' => 'unknown' ] ],
			[ 'wrap_element', [ 'element_id' => 'target', 'element_after' => $companion + [ 'id' => 'leaf' ] ] ],
		] as [ $name, $input ] ) {
			$reject( $name, $input );
		}
		foreach ( [ null, false, 'bad', [ 'bad' ] ] as $settings ) {
			$reject( 'wrap_element', [ 'element_id' => 'target', 'settings' => $settings ], true );
		}
		foreach ( [ null, false, [ 'elType' => 'section' ], [ 'elType' => 'widget' ], [ 'elType' => 'container', 'elements' => false ], [ 'elType' => 'container', 'elements' => [ false ] ] ] as $invalid ) {
			$reject( 'wrap_element', [ 'element_id' => 'target', 'element_after' => $invalid ], true );
		}
		$invalid_root = array_replace( $button, [ 'settings' => [ 'bad' ] ] );
		foreach ( [ $invalid_root, [ 'elType' => 'container', 'elements' => [ $invalid_root ] ] ] as $invalid ) {
			$reject( 'add_element', [ 'element' => $invalid ], true );
			$reject( 'generate_element', [ 'type' => 'row', 'children' => [ $invalid ] ], true );
			$reject( 'wrap_element', [ 'element_id' => 'target', 'element_after' => $invalid ], true );
		}
		$reject( 'generate_element', [ 'type' => 'row', 'settings' => [ 'bad' ] ], true );
		$result = $call( 'wrap_element', [ 'element_id' => 'target', 'settings' => [], 'element_after' => $button ] );
		frontman_runtime_assert( [] === Frontman_Elementor_Data::get_element( $page(), $result['added_element_id'] )['settings'], 'Empty companion settings must remain valid.' );
		$html = array_replace( $leaf, [ 'widgetType' => 'html', 'settings' => [ 'html' => '<p>Keep</p>' ] ] );
		$seed( [ $html ] );
		$reject( 'duplicate_element', [ 'element_id' => 'leaf', 'settings' => [ 'html' => 'forbidden' ] ] );
		foreach ( [ 'section', 'column', 'widget', 'duplicate', 'unrelated_duplicate' ] as $shape ) {
			$bad = $tree;
			if ( 'duplicate' === $shape || 'unrelated_duplicate' === $shape ) {
				$bad[] = 'duplicate' === $shape ? $target : $sibling;
			} else {
				$bad[0]['elType'] = $shape;
			}
			$seed( $bad );
			$reject( 'wrap_element', [ 'element_id' => 'target' ] );
			if ( false !== strpos( $shape, 'duplicate' ) ) {
				$reject( 'add_element', [ 'after_element_id' => 'first', 'element' => $companion ] );
				$reject( 'duplicate_element', [ 'element_id' => 'target' ] );
			}
		}
		foreach ( [ 'section', 'column' ] as $type ) {
			$bad = $tree;
			$bad[0]['elements'][1]['elType'] = $type;
			$seed( $bad );
			$reject( 'wrap_element', [ 'element_id' => 'target' ] );
		}
		frontman_runtime_assert( false !== $wpdb->query( "CREATE TEMPORARY TABLE $table LIKE $original_table" ), 'Could not create real snapshot-failure metadata table.' );
		try {
			frontman_runtime_assert( false !== $wpdb->query( "ALTER TABLE $table ADD CONSTRAINT frontman_reject_snapshot CHECK (meta_key <> '_frontman_elementor_rollbacks')" ), 'Could not constrain snapshot persistence.' );
			$wpdb->postmeta = $table;
			wp_cache_delete( $post_id, 'post_meta' );
			$seed( $tree );
			foreach ( [
				[ 'add_element', [ 'after_element_id' => 'first', 'element' => $companion ] ],
				[ 'duplicate_element', [ 'element_id' => 'target' ] ],
				[ 'wrap_element', [ 'element_id' => 'target', 'element_after' => $companion ] ],
			] as [ $name, $input ] ) {
				$before = $state();
				$events = [];
				$full_name = 'wp_elementor_' . $name;
				$result = $tools->call( $full_name, $tools->sanitize_input( $full_name, $input + [ 'post_id' => $post_id ] ) );
				frontman_runtime_assert( true === $result['isError'] && false !== strpos( $result['content'][0]['text'], 'WordPress did not persist' ), 'SQL snapshot failure must abort the mutation.' );
				frontman_runtime_assert( [] === $events && $before === $state() && $tree === $page() && '' === $read( $key ), 'Failed snapshot persistence changed the actual SQL page or snapshots.' );
			}
		} finally {
			$wpdb->postmeta = $original_table;
			wp_cache_delete( $post_id, 'post_meta' );
			$wpdb->query( "DROP TEMPORARY TABLE $table" );
		}
		fwrite( STDOUT, "OK (Elementor native SQL relative insertion, duplication, wrapping and rollback failures)\n" );
	} finally {
		remove_action( 'added_post_meta', $observe, 10 );
		remove_action( 'updated_post_meta', $observe, 10 );
		$wpdb->postmeta = $original_table;
		wp_cache_delete( $post_id, 'post_meta' );
		wp_delete_post( $post_id, true );
	}
} )();
