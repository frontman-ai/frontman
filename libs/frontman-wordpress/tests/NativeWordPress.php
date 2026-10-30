<?php

$wp = getenv( 'FRONTMAN_WORDPRESS_SOURCE' );
if ( ! $wp || ! is_file( $wp . '/wp-includes/version.php' ) ) {
	throw new RuntimeException( 'FRONTMAN_WORDPRESS_SOURCE must name a WordPress source directory.' );
}
define( 'ABSPATH', $wp . '/' );
define( 'WPINC', 'wp-includes' );
require ABSPATH . WPINC . '/plugin.php';
require ABSPATH . WPINC . '/load.php';
require ABSPATH . WPINC . '/class-wp-error.php';
require ABSPATH . WPINC . '/pomo/translations.php';
require ABSPATH . WPINC . '/l10n.php';
$l10n['frontman-agentic-ai-editor'] = new NOOP_Translations();
require ABSPATH . WPINC . '/functions.php';
require ABSPATH . WPINC . '/cache.php';
wp_cache_init();
require ABSPATH . WPINC . '/rest-api.php';
