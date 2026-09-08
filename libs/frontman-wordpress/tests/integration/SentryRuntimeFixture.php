<?php

add_action( 'init', static function (): void {
	if ( ! defined( 'FRONTMAN_PLUGIN_DIR' ) ) {
		return;
	}
	require_once FRONTMAN_PLUGIN_DIR . 'vendor/autoload.php';
	\FrontmanVendor\Sentry\State\Scope::addGlobalEventProcessor( static function ( \FrontmanVendor\Sentry\Event $event ) {
		update_option( 'frontman_test_sentry_count', (int) get_option( 'frontman_test_sentry_count', 0 ) + 1 );
		if ( get_option( 'frontman_test_sentry_fail', false ) ) {
			throw new RuntimeException( 'Injected reporting failure.' );
		}
		return null;
	} );
	Frontman_Tools::instance()->add( new Frontman_Tool_Definition(
		'wp_test_diagnostics',
		'Test exception reporting.',
		[ 'type' => 'object', 'properties' => [ 'expected' => [ 'type' => 'boolean' ] ] ],
		static function ( array $input ): array {
			if ( $input['expected'] ?? false ) {
				throw new Frontman_Tool_Error( 'Expected tool failure.' );
			}
			throw new RuntimeException( 'Unexpected tool failure.' );
		}
	) );
}, 20 );
