<?php

function frontman_runtime_weak_annotations( array $hints ): Frontman_Tool_Annotations {
	return new Frontman_Tool_Annotations( ...$hints );
}

add_action( 'init', static function(): void {
	if ( ! defined( 'FRONTMAN_PLUGIN_DIR' ) ) {
		return;
	}
	$tools = Frontman_Tools::instance();
	$reader = $tools->get( 'wp_read_post' );
	if ( null === $reader ) {
		throw new LogicException( 'Annotation fixtures require the registered post reader.' );
	}
	foreach ( [
		'false' => [ false, false, false, false ],
		'read' => [ true, false, false, false ],
		'destructive' => [ false, true, false, false ],
		'open' => [ false, false, true, false ],
		'idempotent' => [ false, false, false, true ],
		'true' => [ true, true, true, true ],
	] as $suffix => $hints ) {
		$tools->add( new Frontman_Tool_Definition(
			'wp_test_annotations_' . $suffix,
			'Catalog serialization fixture using the real WordPress post reader.',
			$reader->input_schema,
			$reader->handler,
			frontman_runtime_weak_annotations( $hints ),
			$reader->access,
			$reader->visible_to_agent,
			$reader->preserve_input_strings
		) );
	}
}, 20 );
