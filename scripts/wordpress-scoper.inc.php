<?php

$polyfills = [];
foreach ( glob( 'vendor/symfony/polyfill-*' ) as $directory ) {
	foreach ( new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $directory, FilesystemIterator::SKIP_DOTS ) ) as $file ) {
		$polyfills[] = $file->getRealPath();
	}
}

return [
	'prefix' => 'FrontmanVendor',
	'exclude-files' => $polyfills,
	'exclude-namespaces' => [ 'Symfony\\Polyfill' ],
	'expose-global-constants' => false,
	'expose-global-classes' => false,
	'expose-global-functions' => false,
];
