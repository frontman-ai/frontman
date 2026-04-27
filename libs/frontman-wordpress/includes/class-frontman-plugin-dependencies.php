<?php
/**
 * Optional plugin dependency checks for tool registration.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Plugin_Dependencies {
	/**
	 * Check whether an optional plugin is available for runtime tool use.
	 *
	 * Availability means the plugin is already loaded or is active in WordPress.
	 */
	public static function is_available( string $plugin_file, string $class_name = '' ): bool {
		if ( '' !== $class_name && class_exists( ltrim( $class_name, '\\' ) ) ) {
			return true;
		}

		self::load_plugin_functions();

		if ( function_exists( 'is_plugin_active' ) && is_plugin_active( $plugin_file ) ) {
			return true;
		}

		if ( function_exists( 'is_plugin_active_for_network' ) && is_plugin_active_for_network( $plugin_file ) ) {
			return true;
		}

		return false;
	}

	/**
	 * Load WordPress plugin helper functions when running outside wp-admin.
	 */
	private static function load_plugin_functions(): void {
		if ( function_exists( 'is_plugin_active' ) && function_exists( 'is_plugin_active_for_network' ) ) {
			return;
		}

		$plugin_helpers = ABSPATH . 'wp-admin/includes/plugin.php';
		if ( file_exists( $plugin_helpers ) ) {
			require_once $plugin_helpers;
		}
	}
}
