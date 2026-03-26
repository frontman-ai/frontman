<?php
/**
 * Uninstall hook — clean up all plugin data.
 *
 * @package Frontman
 */

// Abort if not called by WordPress uninstall.
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

require_once __DIR__ . '/includes/class-frontman-settings.php';
require_once __DIR__ . '/includes/class-frontman-core-file-tracker.php';

Frontman_Core_File_Tracker::clear_all();

// Remove plugin options.
delete_option( 'frontman_settings' );
