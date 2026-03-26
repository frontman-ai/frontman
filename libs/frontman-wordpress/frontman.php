<?php
/**
 * Plugin Name:       Frontman
 * Plugin URI:        https://frontman.sh
 * Description:       AI-powered frontend editing for WordPress. Lets an AI agent see your site and edit posts, blocks, menus, templates, and options through a conversational UI.
 * Version:           0.3.3
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            Frontman AI
 * Author URI:        https://frontman.sh
 * License:           Apache-2.0
 * License URI:       https://www.apache.org/licenses/LICENSE-2.0
 * Text Domain:       frontman
 */

// Abort if called directly.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'FRONTMAN_VERSION', '0.3.3' );
define( 'FRONTMAN_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'FRONTMAN_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'FRONTMAN_PLUGIN_FILE', __FILE__ );

// Autoload plugin classes.
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-auth.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-core-path.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-core-file-tracker.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-core-tools.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-tools.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-router.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-ui.php';
require_once FRONTMAN_PLUGIN_DIR . 'includes/class-frontman-settings.php';

// Load tool implementations.
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-posts.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-blocks.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-menus.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-options.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-templates.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-widgets.php';
require_once FRONTMAN_PLUGIN_DIR . 'tools/class-tool-cache.php';

/**
 * Main plugin bootstrap.
 */
function frontman_init(): void {
	// Register settings (admin_init fields only — menu added later).
	$settings = new Frontman_Settings();
	$settings->register();

	// Register all WP tools.
	$tools = Frontman_Tools::instance();
	( new Frontman_Core_Tools() )->register( $tools );
	( new Frontman_Tool_Posts() )->register( $tools );
	( new Frontman_Tool_Blocks() )->register( $tools );
	( new Frontman_Tool_Menus() )->register( $tools );
	( new Frontman_Tool_Options() )->register( $tools );
	( new Frontman_Tool_Templates() )->register( $tools );
	( new Frontman_Tool_Widgets() )->register( $tools );
	( new Frontman_Tool_Cache() )->register( $tools );

	// Build the UI renderer and router.
	$ui     = new Frontman_UI( $settings );
	$router = new Frontman_Router( $tools, $ui );

	// Register request interception (parse_request) and admin menu.
	// UI must register before Settings so the parent menu page exists
	// when the Settings submenu is added.
	$router->register();
	$ui->register();
	$settings->register_menu();
}
add_action( 'init', 'frontman_init' );

/**
 * Clear transient edit-tracking state on plugin deactivation.
 */
function frontman_deactivate(): void {
	Frontman_Core_File_Tracker::clear();
}
register_deactivation_hook( FRONTMAN_PLUGIN_FILE, 'frontman_deactivate' );
