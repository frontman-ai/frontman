<?php
/**
 * Core path helpers for local filesystem tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Core_Path {
	public static function source_root(): string {
		$root = realpath( untrailingslashit( ABSPATH ) );
		return self::normalize( false !== $root ? $root : untrailingslashit( ABSPATH ) );
	}

	public static function resolve( string $input_path ): array {
		$source_root = self::source_root();
		$requested   = ( '' === $input_path ) ? '.' : $input_path;

		if ( self::is_absolute( $requested ) ) {
			$resolved = self::canonicalize( $requested );
			if ( ! self::is_under_root( $source_root, $resolved ) ) {
				throw new Frontman_Tool_Error( self::format_error( $source_root, $requested, "Absolute path must be under source root: {$requested}" ) );
			}
		} else {
			$resolved = self::canonicalize( $source_root . '/' . $requested );
			if ( ! self::is_under_root( $source_root, $resolved ) ) {
				throw new Frontman_Tool_Error( self::format_error( $source_root, $requested, "Path escapes source root: {$requested}" ) );
			}
		}

		return [
			'sourceRoot'   => $source_root,
			'resolvedPath' => $resolved,
			'relativePath' => self::to_relative_path( $source_root, $resolved ),
		];
	}

	public static function resolve_search_path( ?string $input_path ): string {
		if ( null === $input_path || '' === $input_path ) {
			return self::source_root();
		}

		return self::resolve( $input_path )['resolvedPath'];
	}

	public static function resolve_search_dir( ?string $input_path ): string {
		$resolved = self::resolve_search_path( $input_path );
		if ( is_file( $resolved ) ) {
			return self::normalize( dirname( $resolved ) );
		}

		return $resolved;
	}

	public static function to_relative_path( string $source_root, string $absolute_path ): string {
		$source_root   = self::normalize( $source_root );
		$absolute_path = self::normalize( $absolute_path );

		if ( $absolute_path === $source_root ) {
			return '';
		}

		$prefix = trailingslashit( $source_root );
		if ( 0 === strpos( $absolute_path, $prefix ) ) {
			return substr( $absolute_path, strlen( $prefix ) );
		}

		return $absolute_path;
	}

	public static function normalize( string $path ): string {
		$path      = str_replace( '\\', '/', $path );
		$drive     = '';
		$is_abs    = false;
		$segments  = [];

		if ( preg_match( '/^[A-Za-z]:\//', $path, $matches ) ) {
			$drive  = strtoupper( substr( $matches[0], 0, 2 ) );
			$path   = substr( $path, 2 );
			$is_abs = true;
		} elseif ( '/' === substr( $path, 0, 1 ) ) {
			$is_abs = true;
		}

		foreach ( explode( '/', $path ) as $segment ) {
			if ( '' === $segment || '.' === $segment ) {
				continue;
			}

			if ( '..' === $segment ) {
				if ( ! empty( $segments ) && '..' !== end( $segments ) ) {
					array_pop( $segments );
				} elseif ( ! $is_abs ) {
					$segments[] = $segment;
				}
				continue;
			}

			$segments[] = $segment;
		}

		$normalized = implode( '/', $segments );
		if ( $is_abs ) {
			$normalized = '/' . $normalized;
		}

		if ( '' !== $drive ) {
			$normalized = $drive . $normalized;
		}

		if ( '' === $normalized ) {
			return $is_abs ? '/' : '.';
		}

		return rtrim( $normalized, '/' );
	}

	private static function canonicalize( string $path ): string {
		$normalized = self::normalize( $path );

		if ( file_exists( $normalized ) ) {
			$real = realpath( $normalized );
			return false !== $real ? self::normalize( $real ) : $normalized;
		}

		$pending = [];
		$probe   = $normalized;

		while ( ! file_exists( $probe ) ) {
			$parent = dirname( $probe );
			if ( $parent === $probe ) {
				return $normalized;
			}

			array_unshift( $pending, basename( $probe ) );
			$probe = $parent;
		}

		$real_base = realpath( $probe );
		if ( false === $real_base ) {
			return $normalized;
		}

		$resolved = self::normalize( $real_base );
		foreach ( $pending as $segment ) {
			$resolved = self::normalize( $resolved . '/' . $segment );
		}

		return $resolved;
	}

	private static function is_absolute( string $path ): bool {
		$path = str_replace( '\\', '/', $path );
		return '/' === substr( $path, 0, 1 ) || 1 === preg_match( '/^[A-Za-z]:\//', $path );
	}

	private static function is_under_root( string $source_root, string $resolved_path ): bool {
		return $resolved_path === $source_root || 0 === strpos( $resolved_path, trailingslashit( $source_root ) );
	}

	private static function format_error( string $source_root, string $requested_path, string $message ): string {
		$hint = self::detect_path_confusion( $source_root, $requested_path );
		$base = $message . ' (sourceRoot: ' . $source_root . ')';

		if ( null !== $hint ) {
			return $base . "\n\nHint: " . $hint;
		}

		return $base;
	}

	private static function detect_path_confusion( string $source_root, string $requested_path ): ?string {
		$normalized = ltrim( str_replace( '\\', '/', $requested_path ), './' );
		$segments   = explode( '/', $normalized );
		$first      = $segments[0] ?? '';

		if ( '' === $first ) {
			return null;
		}

		$source_segments = explode( '/', str_replace( '\\', '/', $source_root ) );
		if ( in_array( $first, $source_segments, true ) ) {
			return "Path '{$requested_path}' not found. The sourceRoot is '{$source_root}' which already includes '{$first}/'. Try using '.' or a path relative to sourceRoot instead.";
		}

		return null;
	}
}
