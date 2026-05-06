<?php
/**
 * No-op agent instruction loader for WordPress.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Agent_Instructions_Tool {
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'load_agent_instructions',
			'Returns no project-level agent instruction files in WordPress. This tool intentionally does not inspect the filesystem.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'startPath' => [ 'type' => 'string' ],
				],
			],
			[ $this, 'load_agent_instructions' ],
			false
		) );
	}

	public function load_agent_instructions( array $input ): array {
		return [];
	}
}
