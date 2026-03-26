<?php
/**
 * Persistent read-before-edit tracking for PHP core tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Core_File_Tracker {
	private const TTL = 21600;

	public static function clear(): void {
		delete_transient( self::storage_key() );
	}

	public static function clear_all(): void {
		global $wpdb;

		if ( ! isset( $wpdb ) || ! is_object( $wpdb ) || ! isset( $wpdb->options ) ) {
			self::clear();
			return;
		}

		$option_names = [
			$wpdb->esc_like( '_transient_frontman_file_tracker_' ) . '%',
			$wpdb->esc_like( '_transient_timeout_frontman_file_tracker_' ) . '%',
		];

		$query = $wpdb->prepare(
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared -- Table name comes from $wpdb->options.
			"DELETE FROM {$wpdb->options} WHERE option_name LIKE %s OR option_name LIKE %s",
			$option_names[0],
			$option_names[1]
		);

		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching -- The SQL string is already prepared above and uses only $wpdb->options for the table name. This direct delete is intentional because wildcard transient cleanup cannot be done through the Options API.
		$wpdb->query( $query );
	}

	public static function record_read( string $resolved_path, int $offset, int $limit, int $total_lines ): void {
		$records = self::records();
		$now     = microtime( true ) * 1000;
		$new     = [
			'start' => $offset,
			'end'   => min( $offset + $limit, $total_lines ),
		];

		if ( isset( $records[ $resolved_path ] ) ) {
			$records[ $resolved_path ]['readAt']     = $now;
			$records[ $resolved_path ]['totalLines'] = $total_lines;
			$records[ $resolved_path ]['ranges'][]   = $new;
			$records[ $resolved_path ]['ranges']     = self::merge_ranges( $records[ $resolved_path ]['ranges'] );
		} else {
			$records[ $resolved_path ] = [
				'readAt'     => $now,
				'totalLines' => $total_lines,
				'ranges'     => [ $new ],
			];
		}

		self::save_records( $records );
	}

	public static function assert_edit_safe( string $resolved_path ): void {
		$records = self::records();
		if ( ! isset( $records[ $resolved_path ] ) ) {
			throw new Frontman_Tool_Error( 'File must be read before editing. Use read_file first to see its current content.' );
		}

		$mtime_ms = file_exists( $resolved_path ) ? ( filemtime( $resolved_path ) * 1000 ) : null;
		if ( null !== $mtime_ms && $mtime_ms > ( $records[ $resolved_path ]['readAt'] + 100 ) ) {
			throw new Frontman_Tool_Error( 'File has been modified since it was last read. Please read the file again before editing.' );
		}
	}

	public static function check_coverage( string $resolved_path, string $content, string $old_text ): ?string {
		$records = self::records();
		if ( ! isset( $records[ $resolved_path ] ) ) {
			return null;
		}

		$record = $records[ $resolved_path ];
		if ( 1 === count( $record['ranges'] ) && 0 === $record['ranges'][0]['start'] && $record['ranges'][0]['end'] >= $record['totalLines'] ) {
			return null;
		}

		$lines          = preg_split( '/\r\n|\n|\r/', $content );
		$old_lines      = preg_split( '/\r\n|\n|\r/', trim( $old_text ) );
		$first_old_line = trim( $old_lines[0] ?? '' );
		$target_line    = null;

		foreach ( $lines as $index => $line ) {
			if ( trim( $line ) === $first_old_line ) {
				$target_line = $index;
				break;
			}
		}

		if ( null === $target_line ) {
			return null;
		}

		foreach ( $record['ranges'] as $range ) {
			if ( $target_line >= $range['start'] && $target_line < $range['end'] ) {
				return null;
			}
		}

		$range_str = implode(
			', ',
			array_map(
				static function( array $range ): string {
					return $range['start'] . '-' . $range['end'];
				},
				$record['ranges']
			)
		);

		return 'Warning: You are editing around line ' . $target_line . ' but only read lines [' . $range_str . '] of this ' . $record['totalLines'] . '-line file. Consider reading the target section first with read_file and an appropriate offset.';
	}

	public static function record_write( string $resolved_path ): void {
		$records = self::records();
		if ( isset( $records[ $resolved_path ] ) ) {
			$records[ $resolved_path ]['readAt'] = microtime( true ) * 1000;
			self::save_records( $records );
		}
	}

	private static function records(): array {
		$records = get_transient( self::storage_key() );
		return is_array( $records ) ? $records : [];
	}

	private static function save_records( array $records ): void {
		set_transient( self::storage_key(), $records, self::TTL );
	}

	private static function storage_key(): string {
		$user_id = function_exists( 'get_current_user_id' ) ? get_current_user_id() : 0;
		return 'frontman_file_tracker_' . (int) $user_id;
	}

	private static function merge_ranges( array $ranges ): array {
		usort(
			$ranges,
			static function( array $a, array $b ): int {
				return $a['start'] <=> $b['start'];
			}
		);

		$merged = [];
		foreach ( $ranges as $range ) {
			if ( empty( $merged ) ) {
				$merged[] = $range;
				continue;
			}

			$last_index = count( $merged ) - 1;
			if ( $range['start'] <= $merged[ $last_index ]['end'] ) {
				$merged[ $last_index ]['end'] = max( $merged[ $last_index ]['end'], $range['end'] );
			} else {
				$merged[] = $range;
			}
		}

		return $merged;
	}
}
