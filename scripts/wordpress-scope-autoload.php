<?php

$ids = array_keys( require 'vendor/composer/autoload_files.php' );
$scoped_ids = array_map( static function ( string $id ): string { return 'frontman-' . $id; }, $ids );
foreach ( [ 'autoload_files.php', 'autoload_static.php' ] as $file ) {
	$path = 'vendor/composer/' . $file;
	file_put_contents( $path, str_replace( $ids, $scoped_ids, file_get_contents( $path ) ) );
}
