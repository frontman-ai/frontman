<?php

declare(strict_types=1);

$catalogs = [
	'registry' => json_decode( wp_json_encode( Frontman_Tools::instance()->all_definitions() ), true, 512, JSON_THROW_ON_ERROR ),
	'browser' => json_decode( $browser_catalog['body'], true, 512, JSON_THROW_ON_ERROR )['tools'],
	'REST' => $catalog['tools'],
];
$expected_hints = [
	'false' => [ 'readOnlyHint' => false, 'destructiveHint' => false, 'openWorldHint' => false, 'idempotentHint' => false ],
	'read' => [ 'readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false, 'idempotentHint' => false ],
	'destructive' => [ 'readOnlyHint' => false, 'destructiveHint' => true, 'openWorldHint' => false, 'idempotentHint' => false ],
	'open' => [ 'readOnlyHint' => false, 'destructiveHint' => false, 'openWorldHint' => true, 'idempotentHint' => false ],
	'idempotent' => [ 'readOnlyHint' => false, 'destructiveHint' => false, 'openWorldHint' => false, 'idempotentHint' => true ],
	'true' => [ 'readOnlyHint' => true, 'destructiveHint' => true, 'openWorldHint' => true, 'idempotentHint' => true ],
];
foreach ( $catalogs as $transport => $definitions ) {
	$by_name = array_column( $definitions, null, 'name' );
	foreach ( $expected_hints as $suffix => $expected ) {
		$name = 'wp_test_annotations_' . $suffix;
		frontman_runtime_assert( isset( $by_name[ $name ] ), $transport . ' includes annotated tool ' . $name );
		$definition = $by_name[ $name ];
		frontman_runtime_same( $expected, $definition['annotations'], $transport . ' preserves every boolean hint for ' . $name );
		foreach ( [ 'access', 'inputSchema', 'visibleToAgent' ] as $field ) {
			frontman_runtime_same( $by_name['wp_read_post'][ $field ], $definition[ $field ], $transport . ' preserves ' . $field . ' alongside annotations.' );
		}
	}
}

$name = 'wp_test_annotations_false';
$browser_read = frontman_runtime_tool( $cookie, $nonce, [ 'name' => $name, 'arguments' => [ 'id' => $mcp_post ] ] );
$rest_read = $mcp_request( $mcp_credentials, $name );
frontman_runtime_same( 200, $browser_read['status'], 'Annotated browser call succeeds.' );
frontman_runtime_same( 200, $rest_read['status'], 'Annotated REST call succeeds.' );
foreach ( [ $browser_read['body'], json_decode( $rest_read['body'], true, 512, JSON_THROW_ON_ERROR ) ] as $result ) {
	frontman_runtime_same( false, $result['isError'], 'Annotations do not change real post-reader dispatch.' );
	frontman_runtime_same( 'Private MCP bytes', json_decode( $result['content'][0]['text'], true, 512, JSON_THROW_ON_ERROR )['content'], 'Annotated reader returns persisted WordPress content.' );
}

$constructors = [
	'strict' => static function( array $hints ): Frontman_Tool_Annotations { return new Frontman_Tool_Annotations( ...$hints ); },
	'non-strict' => 'frontman_runtime_weak_annotations',
];
foreach ( $constructors as $caller => $construct ) {
	foreach ( [ 'readOnlyHint', 'destructiveHint', 'openWorldHint', 'idempotentHint' ] as $position => $hint ) {
		foreach ( [ 'false', 'true', '', 0, 1, 0.0, 1.0, null, [], new stdClass() ] as $invalid ) {
			$values = [ false, false, false, false ];
			$values[ $position ] = $invalid;
			$rejected = false;
			try {
				$construct( $values );
			} catch ( InvalidArgumentException $error ) {
				frontman_runtime_same( $hint . ' must be a boolean.', $error->getMessage(), 'Malformed annotations identify the invalid hint.' );
				$rejected = true;
			}
			frontman_runtime_assert( $rejected, $caller . ' caller: ' . $hint . ' rejects non-booleans without coercion.' );
		}
	}
}
foreach ( [ [], [ false ], [ false, false ], [ false, false, false ] ] as $incomplete ) {
	$rejected = false;
	try {
		new Frontman_Tool_Annotations( ...$incomplete );
	} catch ( ArgumentCountError $error ) {
		$rejected = true;
	}
	frontman_runtime_assert( $rejected, 'All four hints are required without classification defaults.' );
}
$reader = Frontman_Tools::instance()->get( 'wp_read_post' );
foreach ( [ [], [ null ], [ $expected_hints['false'] ], [ false ], [ 'read' ] ] as $arguments ) {
	$rejected = false;
	try {
		new Frontman_Tool_Definition( 'invalid_annotations', 'Invalid definition.', $reader->input_schema, $reader->handler, ...$arguments );
	} catch ( TypeError $error ) {
		frontman_runtime_same( [] === $arguments ? ArgumentCountError::class : TypeError::class, get_class( $error ), 'Missing or malformed annotations fail at construction.' );
		$rejected = true;
	}
	frontman_runtime_assert( $rejected, 'Definitions require an explicit annotation value, not null, scalars or unchecked arrays.' );
}
$definition = new Frontman_Tool_Definition(
	'annotation_flags', 'Explicit flags.', $reader->input_schema, $reader->handler,
	new Frontman_Tool_Annotations( false, false, false, false ), 'read', false, true
);
frontman_runtime_same( 'read', $definition->access, 'Required annotations retain explicit access.' );
frontman_runtime_same( false, $definition->visible_to_agent, 'Required annotations retain explicit visibility.' );
frontman_runtime_same( true, $definition->preserve_input_strings, 'Required annotations retain string preservation.' );
$rejected = false;
try {
	$definition->annotations = null;
} catch ( TypeError $error ) {
	$rejected = true;
}
frontman_runtime_assert( $rejected, 'A constructed definition cannot lose its required annotation value.' );

fwrite( STDOUT, "OK (tool annotation catalogs, dispatch and strict/non-strict validation)\n" );
