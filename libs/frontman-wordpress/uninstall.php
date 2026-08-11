<?php
/**
 * Uninstall hook — clean up all plugin data.
 *
 * @package Frontman
 */

if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

delete_option( 'frontman_settings' );
