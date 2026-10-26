<?php

define( 'ABSPATH', __DIR__ );
require_once __DIR__ . '/../includes/class-frontman-tools.php';

$tools = new Frontman_Tools();
$original = new Frontman_Tool_Definition(
	'wp_list_redirects', 'Original provider', [],
	static function( array $input ): array { return [ 'provider' => 'original' ]; }
);
$other = new Frontman_Tool_Definition(
	'wp_301_redirects_list', 'Another provider', [],
	static function( array $input ): array { return [ 'provider' => 'other' ]; },
	'read'
);
$tools->add( $original );
$tools->add( $other );
foreach ( [ $original, new Frontman_Tool_Definition(
	$original->name, 'Replacement provider', [],
	static function( array $input ): array { return []; }
) ] as $duplicate ) {
	try {
		$tools->add( $duplicate );
		throw new RuntimeException( 'Duplicate tool registration was accepted.' );
	} catch ( LogicException $error ) {
		if ( $error->getMessage() !== 'Duplicate tool registration: wp_list_redirects' ) {
			throw new RuntimeException( 'Duplicate diagnostic must identify the tool.' );
		}
	}
}
if ( $tools->get( $original->name ) !== $original || $tools->get( $other->name ) !== $other ) {
	throw new RuntimeException( 'Registration changed an existing tool owner.' );
}
if ( count( $tools->all_definitions() ) !== 2 ) {
	throw new RuntimeException( 'Distinct provider tools must coexist.' );
}
echo "OK (tool names have unique owners)\n";
