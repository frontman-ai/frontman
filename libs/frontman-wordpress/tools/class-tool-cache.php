<?php
/**
 * WordPress cache tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Tool_Cache {
	/**
	 * Register cache tools.
	 */
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_list_cache_plugins',
			'Lists detected cache plugins and whether Frontman knows how to clear them.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'list_cache_plugins' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_clear_cache',
			'Clears known cache plugins and the WordPress object cache after reading the current cache-plugin state first.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => new \stdClass(),
			],
			[ $this, 'clear_cache' ]
		) );
	}

	/**
	 * wp_list_cache_plugins handler.
	 */
	public function list_cache_plugins( array $input ): array {
		$active_plugins = get_option( 'active_plugins', [] );
		$known = [
			[
				'slug'      => 'wp-rocket',
				'label'     => 'WP Rocket',
				'match'     => 'wp-rocket/wp-rocket.php',
				'available' => function_exists( 'rocket_clean_domain' ),
			],
			[
				'slug'      => 'w3-total-cache',
				'label'     => 'W3 Total Cache',
				'match'     => 'w3-total-cache/w3-total-cache.php',
				'available' => function_exists( 'w3tc_flush_all' ),
			],
			[
				'slug'      => 'litespeed-cache',
				'label'     => 'LiteSpeed Cache',
				'match'     => 'litespeed-cache/litespeed-cache.php',
				'available' => true,
			],
			[
				'slug'      => 'wp-super-cache',
				'label'     => 'WP Super Cache',
				'match'     => 'wp-super-cache/wp-cache.php',
				'available' => function_exists( 'wp_cache_clear_cache' ),
			],
			[
				'slug'      => 'autoptimize',
				'label'     => 'Autoptimize',
				'match'     => 'autoptimize/autoptimize.php',
				'available' => function_exists( 'autoptimize_delete_cache' ),
			],
		];

		$result = [];
		foreach ( $known as $plugin ) {
			if ( in_array( $plugin['match'], $active_plugins, true ) ) {
				$result[] = [
					'slug'         => $plugin['slug'],
					'label'        => $plugin['label'],
					'active'       => true,
					'clearSupport' => (bool) $plugin['available'],
				];
			}
		}

		return [
			'plugins'          => $result,
			'objectCacheFlush' => function_exists( 'wp_cache_flush' ),
		];
	}

	/**
	 * wp_clear_cache handler.
	 */
	public function clear_cache( array $input ): array {
		$before  = $this->list_cache_plugins( [] );
		$cleared = [];

		foreach ( $before['plugins'] as $plugin ) {
			switch ( $plugin['slug'] ) {
				case 'wp-rocket':
					if ( function_exists( 'rocket_clean_domain' ) ) {
						rocket_clean_domain();
						$cleared[] = $plugin['slug'];
					}
					break;
				case 'w3-total-cache':
					if ( function_exists( 'w3tc_flush_all' ) ) {
						w3tc_flush_all();
						$cleared[] = $plugin['slug'];
					}
					break;
				case 'litespeed-cache':
					// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedHooknameFound -- This intentionally calls LiteSpeed Cache's public hook name so Frontman can purge that plugin's cache when it is active.
					do_action( 'litespeed_purge_all' );
					$cleared[] = $plugin['slug'];
					break;
				case 'wp-super-cache':
					if ( function_exists( 'wp_cache_clear_cache' ) ) {
						global $file_prefix;
						wp_cache_clear_cache( $file_prefix ?? '', true );
						$cleared[] = $plugin['slug'];
					}
					break;
				case 'autoptimize':
					if ( function_exists( 'autoptimize_delete_cache' ) ) {
						autoptimize_delete_cache();
						$cleared[] = $plugin['slug'];
					}
					break;
			}
		}

		$object_cache_flushed = false;
		if ( function_exists( 'wp_cache_flush' ) ) {
			wp_cache_flush();
			$object_cache_flushed = true;
		}

		return [
			'before'             => $before,
			'clearedPlugins'     => array_values( array_unique( $cleared ) ),
			'objectCacheFlushed' => $object_cache_flushed,
			'after'              => $this->list_cache_plugins( [] ),
		];
	}
}
