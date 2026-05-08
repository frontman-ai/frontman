<?php
/**
 * Plugin Name:       Frontman - Agentic AI Editor
 * Plugin URI:        https://frontman.sh
 * Description:       Frontman - Agentic AI Editor: AI-powered frontend editing plugin for WordPress. Your AI agent observes your live site and makes changes to posts, blocks, menus, templates, and site options - all through a conversational interface, no dashboard required.
 * Version:           0.16.0
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            Frontman AI
 * Author URI:        https://frontman.sh/about
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       frontman-agentic-ai-editor
 */

// Abort if called directly.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'frontman_plugin_dir_path' ) ) {
	/**
	 * Resolve the plugin directory path.
	 */
	function frontman_plugin_dir_path( string $file ): string {
		if ( function_exists( 'plugin_dir_path' ) ) {
			return call_user_func( 'plugin_dir_path', $file );
		}

		return dirname( $file ) . '/';
	}
}

if ( ! function_exists( 'frontman_plugin_dir_url' ) ) {
	/**
	 * Resolve the plugin directory URL.
	 */
	function frontman_plugin_dir_url( string $file ): string {
		if ( function_exists( 'plugin_dir_url' ) ) {
			return call_user_func( 'plugin_dir_url', $file );
		}

		return '';
	}
}

define( 'FRONTMAN_VERSION', '0.16.0' );
define( 'FRONTMAN_PLUGIN_DIR', frontman_plugin_dir_path( __FILE__ ) );
define( 'FRONTMAN_PLUGIN_URL', frontman_plugin_dir_url( __FILE__ ) );
define( 'FRONTMAN_PLUGIN_FILE', __FILE__ );

// Autoload plugin classes.
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-auth.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-agent-instructions-tool.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-plugin-dependencies.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-tools.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-router.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-ui.php';

// Load tool implementations.
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-posts.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-blocks.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-media.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-menus.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-options.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-templates.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-widgets.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-cache.php';

/**
 * Main plugin bootstrap.
 */
function frontman_init(): void {
	// Register all WP tools.
	$tools = Frontman_Tools::instance();
	( new Frontman_Agent_Instructions_Tool() )->register( $tools );
	( new Frontman_Tool_Posts() )->register( $tools );
	( new Frontman_Tool_Blocks() )->register( $tools );
	( new Frontman_Tool_Media() )->register( $tools );
	( new Frontman_Tool_Menus() )->register( $tools );
	( new Frontman_Tool_Options() )->register( $tools );
	( new Frontman_Tool_Templates() )->register( $tools );
	( new Frontman_Tool_Widgets() )->register( $tools );
	( new Frontman_Tool_Cache() )->register( $tools );

	if ( Frontman_Plugin_Dependencies::is_available( 'elementor/elementor.php', '\Elementor\Plugin' ) ) {
		require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-elementor-data.php';
		require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-elementor.php';
		( new Frontman_Tool_Elementor() )->register( $tools );
	}

	// Build the UI renderer and router.
	$ui     = new Frontman_UI();
	$router = new Frontman_Router( $tools, $ui );

	// Register request interception (parse_request) and admin menu link.
	$router->register();
	$ui->register();
}
add_action( 'init', 'frontman_init' );

/**
 * Clear transient edit-tracking state on plugin deactivation.
 */
function frontman_deactivate(): void {
	delete_transient( 'frontman_file_tracker_' . (int) get_current_user_id() );
}

if ( function_exists( 'register_deactivation_hook' ) ) {
	call_user_func( 'register_deactivation_hook', FRONTMAN_PLUGIN_FILE, 'frontman_deactivate' );
}
