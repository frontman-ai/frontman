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

// Remove plugin options.
delete_option( 'frontman_settings' );
