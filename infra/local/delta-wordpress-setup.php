<?php
$check = isset($argv[1]) && $argv[1] === 'check';
if (!$check) {
    $id = getenv('STACK_ID');
    $port = getenv('STACK_PORT');
    if (!$id || !ctype_digit($port)) {
        throw new RuntimeException('STACK_ID and STACK_PORT are required.');
    }
    $url = "https://$id.wordpress.frontman.local:$port";
    $config = "/var/www/html/wp-config.php";
    for ($attempt = 0; !is_file($config) && $attempt < 60; $attempt++) {
        sleep(1);
    }
    if (!is_file($config)) {
        throw new RuntimeException('WordPress entrypoint did not create wp-config.php.');
    }
    $overrides = [
        'WP_HOME' => $url,
        'WP_SITEURL' => $url,
        'FRONTMAN_HOST' => "$id.api.frontman.local:$port",
        'FRONTMAN_CLIENT_URL' => "https://$id.vite.frontman.local:$port/dist/frontman.es.js",
        'FRONTMAN_CLIENT_CSS' => "https://$id.vite.frontman.local:$port/dist/frontman.css",
    ];
    $php = "<?php\n\$_SERVER['HTTPS'] = 'on';\n";
    foreach ($overrides as $key => $value) {
        $php .= 'define(' . var_export($key, true) . ', ' . var_export($value, true) . ");\n";
    }
    file_put_contents('/var/www/html/frontman-local.php', $php);
    $content = file_get_contents($config);
    if (strpos($content, "require __DIR__ . '/frontman-local.php';") === false) {
        file_put_contents($config, str_replace('<?php', "<?php\nrequire __DIR__ . '/frontman-local.php';", $content));
    }
}
mysqli_report(MYSQLI_REPORT_OFF);
for ($attempt = 0; $attempt < 60; $attempt++) {
    $db = @new mysqli('127.0.0.1', 'wordpress', 'wordpress', 'wordpress');
    if (!$db->connect_errno) {
        $db->close();
        break;
    }
    sleep(1);
}
if ($attempt === 60) {
    throw new RuntimeException('MariaDB did not become ready.');
}
define('WP_INSTALLING', !$check);
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
if (!$check) {
    umask(0077);
    $state_dir = '/var/lib/frontman';
    if (!is_dir($state_dir)) {
        throw new RuntimeException('Mount the private state volume at /var/lib/frontman before preparation.');
    }
    if (!chmod($state_dir, 0700)) {
        throw new RuntimeException('Cannot protect private local state directory.');
    }
    $password_file = $state_dir . '/admin-password';
    $legacy_password_file = '/var/www/html/.frontman-admin-password';
    if (is_file($legacy_password_file)) {
        if (!is_file($password_file)) {
            $password = file_get_contents($legacy_password_file);
            if ($password === false || file_put_contents($password_file, $password) === false) {
                throw new RuntimeException('Cannot migrate local admin password.');
            }
        }
        if (!unlink($legacy_password_file)) {
            throw new RuntimeException('Cannot remove legacy local admin password.');
        }
    }
    if (!is_blog_installed()) {
        $password = bin2hex(random_bytes(24));
        if (file_put_contents($password_file, $password) === false) {
            throw new RuntimeException('Cannot save local admin password.');
        }
        wp_install('Frontman local checkout', 'admin', 'admin@example.test', true, '', $password);
    }
    $result = activate_plugin('frontman-agentic-ai-editor/frontman.php');
    if (is_wp_error($result)) {
        throw new RuntimeException($result->get_error_message());
    }
}
if (!is_plugin_active('frontman-agentic-ai-editor/frontman.php')) {
    throw new RuntimeException('Frontman plugin is not active.');
}
require_once WP_PLUGIN_DIR . '/frontman-agentic-ai-editor/frontman.php';
wp_set_current_user(get_user_by('login', 'admin')->ID);
ob_start();
(new Frontman_UI())->render_page();
$html = ob_get_clean();
foreach ([FRONTMAN_HOST, FRONTMAN_CLIENT_URL, FRONTMAN_CLIENT_CSS] as $expected) {
    if (strpos(html_entity_decode($html), $expected) === false) {
        throw new RuntimeException('Rendered Frontman page does not reference the checkout: ' . $expected);
    }
}
if (strpos($html, 'https://app.frontman.sh/') !== false) {
    throw new RuntimeException('Rendered page references the production client.');
}
echo "WordPress is installed, plugin active, and rendered client/backend URLs are local.\n";
