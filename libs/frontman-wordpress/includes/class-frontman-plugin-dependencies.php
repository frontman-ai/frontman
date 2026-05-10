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

		if ( function_exists( 'is_plugin_active' ) && is_plugin_active( $plugin_file ) ) {
			return true;
		}

		if ( function_exists( 'is_plugin_active_for_network' ) && is_plugin_active_for_network( $plugin_file ) ) {
			return true;
		}

		$active_plugins = function_exists( 'get_option' ) ? get_option( 'active_plugins', [] ) : [];
		if ( is_array( $active_plugins ) && in_array( $plugin_file, $active_plugins, true ) ) {
			return true;
		}

		$network_plugins = function_exists( 'get_site_option' ) ? get_site_option( 'active_sitewide_plugins', [] ) : [];
		if ( is_array( $network_plugins ) && isset( $network_plugins[ $plugin_file ] ) ) {
			return true;
		}

		return false;
	}
}
