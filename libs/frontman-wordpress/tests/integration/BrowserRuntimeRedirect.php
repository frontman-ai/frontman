<?php
// Real redirect used to verify the browser's fixture-only network boundary.
$port = filter_input( INPUT_GET, 'port', FILTER_VALIDATE_INT );
if ( ! $port || $port < 1025 || $port > 65535 ) {
	http_response_code( 400 );
	exit;
}
header( 'Location: https://127.0.0.1:' . $port . '/', true, 307 );
