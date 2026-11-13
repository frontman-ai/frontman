<?php

add_action( 'plugin_loaded', static function ( string $plugin ): void {
	if ( 'frontman.php' !== basename( $plugin ) ) {
		return;
	}
	$GLOBALS['frontman_auth_load_state'] = [ did_action( 'init' ), did_action( 'set_current_user' ), has_action( 'init', 'frontman_init' ) ];
	foreach ( [ 'malformed', 'expired', 'bad_username', 'bad_hash', 'bad_session_token' ] as $reason ) {
		$callbacks = $GLOBALS['wp_filter'][ 'auth_cookie_' . $reason ]->callbacks[10] ?? [];
		$GLOBALS['frontman_auth_load_state'][] = array_filter( $callbacks, static function ( $entry ): bool {
			$scope = $entry['function'] instanceof Closure ? ( new ReflectionFunction( $entry['function'] ) )->getClosureScopeClass() : null;
			return $scope && 'Frontman_Auth' === $scope->getName();
		} );
	}
} );

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
		},
		new Frontman_Tool_Annotations( false, true, true, false )
	) );
}, 20 );
