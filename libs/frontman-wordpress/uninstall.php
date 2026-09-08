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
delete_option( 'frontman_php_diagnostics' );
