<?php

define( 'ABSPATH', __DIR__ );
define( 'FRONTMAN_PLUGIN_URL', 'https://example.test/blog/wp-content/plugins/frontman/' );
define( 'FRONTMAN_VERSION', 'test' );

$hooks = [];
$scripts = [];
$authorized = false;
function add_action( $hook, $callback ) { $GLOBALS['hooks'][ $hook ] = $callback; }
function current_user_can( $capability ) { return $capability === 'manage_options' && $GLOBALS['authorized']; }
function wp_enqueue_script( ...$args ) { $GLOBALS['scripts'][] = $args; }
function check( bool $condition, string $message ): void {
	if ( ! $condition ) { throw new RuntimeException( $message ); }
}

require_once __DIR__ . '/../includes/class-frontman-ui.php';
$ui = new Frontman_UI();
$ui->register();
check( isset( $hooks['wp_enqueue_scripts'] ), 'Register the frontend loader hook' );
$hooks['wp_enqueue_scripts']();
check( $scripts === [], 'Do not enqueue the loader for visitors' );
$authorized = true;
$hooks['wp_enqueue_scripts']();
check( $scripts === [ [ 'frontman-preview-loader', FRONTMAN_PLUGIN_URL . 'assets/preview-loader.js', [], 'test', false ] ], 'Use the plugin asset URL, including a WordPress subdirectory, in the head' );
foreach ( [ 'bridge.js', 'preview-loader.js' ] as $asset ) {
	check( filesize( __DIR__ . '/../assets/' . $asset ) > 0, 'Build the packaged preview asset: ' . $asset );
}
echo "PASS: WordPress preview authorization, enqueue hook, subdirectory URL and built assets\n";
