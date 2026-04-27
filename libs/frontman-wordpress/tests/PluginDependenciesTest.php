<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-plugin-dependencies/' );

$GLOBALS['frontman_test_active_plugins']         = [];
$GLOBALS['frontman_test_network_active_plugins'] = [];

if ( ! function_exists( 'is_plugin_active' ) ) {
	function is_plugin_active( string $plugin_file ): bool {
		return in_array( $plugin_file, $GLOBALS['frontman_test_active_plugins'], true );
	}
}

if ( ! function_exists( 'is_plugin_active_for_network' ) ) {
	function is_plugin_active_for_network( string $plugin_file ): bool {
		return in_array( $plugin_file, $GLOBALS['frontman_test_network_active_plugins'], true );
	}
}

require_once __DIR__ . '/../includes/class-frontman-plugin-dependencies.php';

class Frontman_Plugin_Dependencies_Test_Runner {
	private int $assertions = 0;

	public function run(): void {
		$this->test_inactive_plugin_is_unavailable();
		$this->test_active_plugin_is_available();
		$this->test_network_active_plugin_is_available();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function test_inactive_plugin_is_unavailable(): void {
		$GLOBALS['frontman_test_active_plugins']         = [];
		$GLOBALS['frontman_test_network_active_plugins'] = [];

		$this->assert_false(
			Frontman_Plugin_Dependencies::is_available( 'elementor/elementor.php', '\\Elementor\\Plugin' ),
			'Inactive Elementor plugin should not expose Elementor tools'
		);
	}

	private function test_active_plugin_is_available(): void {
		$GLOBALS['frontman_test_active_plugins']         = [ 'elementor/elementor.php' ];
		$GLOBALS['frontman_test_network_active_plugins'] = [];

		$this->assert_true(
			Frontman_Plugin_Dependencies::is_available( 'elementor/elementor.php', '\\Elementor\\Plugin' ),
			'Active Elementor plugin should expose Elementor tools'
		);
	}

	private function test_network_active_plugin_is_available(): void {
		$GLOBALS['frontman_test_active_plugins']         = [];
		$GLOBALS['frontman_test_network_active_plugins'] = [ 'elementor/elementor.php' ];

		$this->assert_true(
			Frontman_Plugin_Dependencies::is_available( 'elementor/elementor.php', '\\Elementor\\Plugin' ),
			'Network-active Elementor plugin should expose Elementor tools'
		);
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}

	private function assert_false( bool $condition, string $message ): void {
		$this->assert_true( ! $condition, $message );
	}
}

( new Frontman_Plugin_Dependencies_Test_Runner() )->run();
