<?php
/**
 * Explicit MCP safety hints for a tool.
 *
 * @package Frontman
 */

declare(strict_types=1);

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class Frontman_Tool_Annotations {
	private bool $read_only_hint;
	private bool $destructive_hint;
	private bool $open_world_hint;
	private bool $idempotent_hint;

	/**
	 * Validate before assignment: bool parameters would coerce scalar inputs
	 * when a WordPress integration calls from a non-strict PHP file.
	 *
	 * @param bool $read_only_hint   Whether the tool only reads or computes.
	 * @param bool $destructive_hint Whether the tool can modify or delete data (Claude directory convention).
	 * @param bool $open_world_hint  Whether the tool interacts with public or open-ended entities.
	 * @param bool $idempotent_hint  Whether identical calls have no additional effect.
	 */
	public function __construct( $read_only_hint, $destructive_hint, $open_world_hint, $idempotent_hint ) {
		foreach ( [
			'readOnlyHint' => $read_only_hint,
			'destructiveHint' => $destructive_hint,
			'openWorldHint' => $open_world_hint,
			'idempotentHint' => $idempotent_hint,
		] as $name => $value ) {
			if ( ! is_bool( $value ) ) {
				throw new \InvalidArgumentException( $name . ' must be a boolean.' );
			}
		}

		$this->read_only_hint   = $read_only_hint;
		$this->destructive_hint = $destructive_hint;
		$this->open_world_hint  = $open_world_hint;
		$this->idempotent_hint  = $idempotent_hint;
	}

	public function to_array(): array {
		return [
			'readOnlyHint' => $this->read_only_hint,
			'destructiveHint' => $this->destructive_hint,
			'openWorldHint' => $this->open_world_hint,
			'idempotentHint' => $this->idempotent_hint,
		];
	}
}
