<?php
/** Fresh table prefix and separate document root: never convert the single-site fixture. */
define( 'WP_INSTALLING', true );
define( 'WP_ALLOW_MULTISITE', true );
define( 'WP_SITEURL', 'http://frontman-multisite.example.test' );
define( 'WP_HOME', 'http://frontman-multisite.example.test' );
$_SERVER['HTTP_HOST'] = 'frontman-multisite.example.test';
$_SERVER['REQUEST_URI'] = '/';
require '/tmp/frontman-multisite/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
require_once ABSPATH . 'wp-admin/includes/network.php';
wp_install( 'Authors Multisite', 'multi-admin', 'multi-admin@example.test', true, '', wp_generate_password() );
foreach ( $wpdb->tables( 'ms_global' ) as $table => $prefixed_table ) {
	$wpdb->$table = $prefixed_table;
}
install_network();
$result = populate_network( 1, 'frontman-multisite.example.test', 'multi-admin@example.test', 'Authors Network', '/', false );
if ( is_wp_error( $result ) ) { throw new RuntimeException( $result->get_error_message() ); }
$config = file_get_contents( ABSPATH . 'wp-config.php' );
$config = str_replace( '<?php', "<?php\ndefine('MULTISITE', true);\ndefine('SUBDOMAIN_INSTALL', false);\ndefine('DOMAIN_CURRENT_SITE', 'frontman-multisite.example.test');\ndefine('PATH_CURRENT_SITE', '/');\ndefine('SITE_ID_CURRENT_SITE', 1);\ndefine('BLOG_ID_CURRENT_SITE', 1);", $config );
file_put_contents( ABSPATH . 'wp-config.php', $config );
echo "Isolated authors multisite installed.\n";
