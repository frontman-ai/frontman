<?php

// Each tool call uses a fresh HTTP request, matching the agent's runtime.
$previous_theme = get_stylesheet();
$original_options = get_option( 'astra-settings', false );
$original_mods = get_option( 'theme_mods_astra', false );
$write_input = static function( array $read, $value ): array {
	return [
		'id' => $read['id'], 'value' => $value, 'stylesheet' => $read['stylesheet'],
		'expected_fingerprint' => $read['fingerprint'], 'confirm' => true,
	];
};
try {
	update_option( 'frontman_customizer_runtime_fixture', true );
	switch_theme( 'astra' );
	update_option( 'astra-settings', [ 'frontman-runtime-sibling' => 'keep' ] );
	set_theme_mod( 'custom_logo', 42 );
	set_theme_mod( 'nav_menu_locations', [ 'primary' => 123 ] );

	$id = 'astra-settings[header-desktop-items]';
	$list = $call( 'wp_list_customizer_settings', [ 'search' => 'header-desktop-items' ] );
	frontman_runtime_assert( in_array( $id, array_column( $list['settings'], 'id' ), true ), 'Cold HTTP discovery exposes Astra Header Builder' );
	$existing_error = $call( 'wp_list_customizer_settings', [], true, 'customizer-manager' );
	frontman_runtime_assert( false !== stripos( $existing_error, 'fresh request' ), 'Incompatible managers fail closed with recovery guidance' );
	$existing = $call( 'wp_list_customizer_settings', [ 'search' => 'header-desktop-items' ], false, 'customizer-own-manager' );
	frontman_runtime_assert( in_array( $id, array_column( $existing['settings'], 'id' ), true ), 'Existing theme-mod tool uses the shared Astra bootstrap' );
	$preview_error = $call( 'wp_get_customizer_setting', [ 'id' => $id ], true, 'customizer-preview' );
	frontman_runtime_assert( false !== stripos( $preview_error, 'preview' ), 'Preview managers are explicitly rejected' );

	// Desktop and mobile are independent writes, not a transaction.
	foreach ( [ $id, 'astra-settings[header-mobile-items]' ] as $layout_id ) {
		$read = $call( 'wp_get_customizer_setting', [ 'id' => $layout_id ] );
		frontman_runtime_assert( is_array( $read['value'] ) && isset( $read['value']['primary'] ), 'Native Astra defaults expose builder rows' );
		$layout = $read['value'];
		if ( $layout_id === $id ) {
			$layout['above']['above_center'] = [ 'logo' ];
			$layout['primary']['primary_left'] = [];
			$layout['primary']['primary_center'] = [ 'menu-1' ];
			$layout['primary']['primary_right'] = [];
		} else {
			$layout['primary']['primary_left'] = [ 'logo' ];
			$layout['primary']['primary_right'] = [ 'mobile-trigger' ];
		}
		$result = $call( 'wp_update_customizer_setting', $write_input( $read, $layout ) );
		frontman_runtime_same( $read['value'], $result['before'], 'Receipt reports the prior value' );
		frontman_runtime_same( $layout, $result['after'], 'Receipt reports the persisted layout' );
		frontman_runtime_same( $layout, $call( 'wp_get_customizer_setting', [ 'id' => $layout_id ] )['value'], 'Fresh request observes the saved layout' );
	}
	$read = $call( 'wp_get_customizer_setting', [ 'id' => $id ] );
	$blocked = $read['value'];
	$blocked['above']['above_center'] = [];
	$error = $call( 'wp_update_customizer_setting', $write_input( $read, $blocked ), true, 'block-astra-write' );
	frontman_runtime_assert( false !== stripos( $error, 'verif' ), 'Blocked indexed saves report unverified persistence, not success' );
	frontman_runtime_same( $read['value'], $call( 'wp_get_customizer_setting', [ 'id' => $id ] )['value'], 'Blocked save does not mistake the cached value for persistence' );
	wp_cache_delete( 'astra-settings', 'options' );
	frontman_runtime_same( 'keep', get_option( 'astra-settings' )['frontman-runtime-sibling'], 'Indexed saves preserve unrelated options' );
	wp_cache_delete( 'theme_mods_astra', 'options' );
	$mods = get_option( 'theme_mods_astra' );
	frontman_runtime_same( 42, $mods['custom_logo'], 'Builder writes preserve the logo' );
	frontman_runtime_same( [ 'primary' => 123 ], $mods['nav_menu_locations'], 'Builder writes preserve menu assignments' );

	$bounded = $call( 'wp_list_customizer_settings', [ 'search' => 'astra-settings[', 'limit' => 1 ] );
	frontman_runtime_same( 1, count( $bounded['settings'] ), 'Discovery obeys its bound' );
	frontman_runtime_assert( null !== $bounded['next_offset'], 'Discovery exposes the next page' );
	frontman_runtime_same( [], $call( 'wp_list_customizer_settings', [ 'search' => 'frontman_runtime_restricted' ] )['settings'], 'Discovery hides inaccessible settings' );
	foreach ( [ 'frontman_runtime_restricted', 'frontman_runtime_unregistered', 'frontman_runtime_option' ] as $unsupported ) {
		$call( 'wp_get_customizer_setting', [ 'id' => $unsupported ], true );
	}
	$label = $call( 'wp_get_customizer_setting', [ 'id' => 'frontman_runtime_first' ] );
	$input = $write_input( $label, '<b>sanitized</b>' );
	$call( 'wp_update_customizer_setting', array_replace( $input, [ 'confirm' => false ] ), true );
	$call( 'wp_update_customizer_setting', array_replace( $input, [ 'stylesheet' => 'wrong-theme' ] ), true );
	$call( 'wp_update_customizer_setting', array_replace( $input, [ 'value' => 'invalid' ] ), true );
	frontman_runtime_same( $label['value'], $call( 'wp_get_customizer_setting', [ 'id' => $label['id'] ] )['value'], 'Rejected writes leave state unchanged' );
	$result = $call( 'wp_update_customizer_setting', $input );
	frontman_runtime_same( 'sanitized', $result['after'], 'Native sanitization runs' );
	$call( 'wp_update_customizer_setting', $input, true );
	$current = $call( 'wp_get_customizer_setting', [ 'id' => $label['id'] ] );
	frontman_runtime_same( false, $call( 'wp_update_customizer_setting', $write_input( $current, 'sanitized' ) )['updated'], 'No-op save is reported accurately' );
	$actor->set_role( 'subscriber' );
	foreach ( [
		[ 'name' => 'wp_get_customizer_setting', 'arguments' => [ 'id' => $label['id'] ] ],
		[ 'name' => 'wp_update_customizer_setting', 'arguments' => $write_input( $current, 'unauthorized' ) ],
	] as $request ) {
		$denied = frontman_runtime_tool( $cookie, $nonce, $request );
		frontman_runtime_assert( in_array( $denied['status'], [ 401, 403 ], true ), 'Subscribers cannot use Customizer tools' );
	}
} finally {
	$actor->set_role( 'administrator' );
	delete_option( 'frontman_customizer_runtime_fixture' );
	switch_theme( $previous_theme );
	foreach ( [ 'astra-settings' => $original_options, 'theme_mods_astra' => $original_mods ] as $name => $original ) {
		if ( false === $original ) {
			delete_option( $name );
		} else {
			update_option( $name, $original );
		}
	}
}
