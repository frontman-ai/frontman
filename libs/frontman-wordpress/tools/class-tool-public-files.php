<?php
/** Guarded physical public text files. @package Frontman */
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
class Frontman_Tool_Public_Files {
	private const NAMES = [ 'robots.txt', 'llms.txt', 'llms-full.txt' ];
	private const LIMIT = 131072;
	public function register( Frontman_Tools $tools ): void {
		$schema = [
			'type' => 'object', 'additionalProperties' => false,
			'properties' => [ 'name' => [ 'type' => 'string', 'enum' => self::NAMES ] ], 'required' => [ 'name' ],
		];
		$tools->add( new Frontman_Tool_Definition( 'wp_read_public_file', 'Inspect one allowlisted physical public text file and observed public output; read before writing.', $schema, [ $this, 'read_public_file' ], 'read' ) );
		$schema['properties'] += [
			'content' => [ 'type' => 'string', 'description' => 'Exact replacement UTF-8 text, at most 128 KiB.' ],
			'expected_revision' => [ 'type' => 'string', 'pattern' => '^[a-f0-9]{64}$' ],
			'confirm' => [ 'type' => 'boolean', 'enum' => [ true ], 'description' => 'True only after user approval of the diff and takeover warning.' ],
		];
		$schema['required'] = [ 'name', 'content', 'expected_revision', 'confirm' ];
		$tools->add( new Frontman_Tool_Definition( 'wp_write_public_file', 'Replace allowlisted public text after approval. Physical creation stops generated updates; manual removal restores generation. Saved and publicly verified are separate; never retry automatically.', $schema, [ $this, 'write_public_file' ], 'read-write' ) );
	}
	public static function validate_input( string $tool, array $input ): array {
		$fields = 'wp_read_public_file' === $tool ? [ 'name' ] : [ 'name', 'content', 'expected_revision', 'confirm' ];
		if ( ! in_array( $tool, [ 'wp_read_public_file', 'wp_write_public_file' ], true )
			|| array_diff( array_keys( $input ), $fields ) || array_diff( $fields, array_keys( $input ) )
			|| ! is_string( $input['name'] ) || ! in_array( $input['name'], self::NAMES, true ) ) {
			throw new Frontman_Tool_Error( 'Invalid public-file fields or filename.' );
		}
		if ( 'wp_write_public_file' === $tool ) {
			self::text( $input['content'] );
			if ( true !== $input['confirm'] || ! is_string( $input['expected_revision'] )
				|| 1 !== preg_match( '/\A[a-f0-9]{64}\z/', $input['expected_revision'] ) ) {
				throw new Frontman_Tool_Error( 'Approve the diff with confirm=true and supply the revision from a fresh read.' );
			}
		}
		return $input;
	}
	private static function text( $content ): void {
		if ( ! is_string( $content ) || strlen( $content ) > self::LIMIT || 1 !== preg_match( '//u', $content )
			|| preg_match( '/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', $content ) ) {
			throw new Frontman_Tool_Error( 'Unsupported text: require UTF-8 without control bytes except tab/CR/LF, at most 128 KiB.' );
		}
	}
	private function scope( string $name ): array {
		if ( ! current_user_can( 'manage_options' ) ) {
			throw new Frontman_Tool_Error( 'manage_options is required.' );
		}
		$home = untrailingslashit( home_url( '/' ) );
		$site = untrailingslashit( site_url( '/' ) );
		$url = wp_parse_url( $home );
		if ( is_multisite() || $home !== $site || ! is_array( $url ) || empty( $url['host'] )
			|| ! in_array( $url['scheme'] ?? '', [ 'http', 'https' ], true )
			|| array_intersect( array_keys( $url ), [ 'user', 'pass', 'query', 'fragment' ] ) || ! empty( $url['path'] ) || '\\' === DIRECTORY_SEPARATOR ) {
			throw new Frontman_Tool_Error( 'Only single-site, same-origin domain-root installations on a local Unix filesystem are supported.' );
		}
		if ( ! function_exists( 'get_home_path' ) || ! function_exists( 'get_filesystem_method' ) ) {
			require_once ABSPATH . 'wp-admin/includes/file.php';
		}
		$path = untrailingslashit( get_home_path() );
		$root = realpath( $path );
		if ( false === $root || $root !== $path || $root !== untrailingslashit( ABSPATH ) || ! is_dir( $root ) ) {
			throw new Frontman_Tool_Error( 'Ambiguous or symlinked public root; ABSPATH and canonical home path must agree.' );
		}
		global $wp_filesystem;
		if ( 'direct' !== get_filesystem_method( [], $root, false ) || ! WP_Filesystem( false, $root, false )
			|| ! $wp_filesystem instanceof WP_Filesystem_Direct ) {
			throw new Frontman_Tool_Error( 'Authorized WordPress direct filesystem access is required; no credentials or transport overrides are supported.' );
		}
		return [ $root, $root . '/' . $name, $home . '/' . $name, $wp_filesystem ];
	}
	private function local( string $path, $fs ): array {
		clearstatcache( true, $path );
		if ( is_link( $path ) ) {
			throw new Frontman_Tool_Error( 'Symlink targets, including dangling links, are unsupported.' );
		}
		if ( ! file_exists( $path ) ) {
			return [ 'exists' => false, 'content' => null ];
		}
		$stat = lstat( $path );
		if ( false === $stat || ! is_file( $path ) || 1 !== $stat['nlink'] || $stat['size'] > self::LIMIT ) {
			throw new Frontman_Tool_Error( 'Require a regular, single-link file of at most 128 KiB.' );
		}
		$content = $fs->get_contents( $path );
		self::text( $content );
		return [ 'exists' => true, 'content' => $content ];
	}
	private function public_state( string $url ): array {
		$response = wp_safe_remote_get( $url, [ 'timeout' => 5, 'redirection' => 0, 'limit_response_size' => self::LIMIT + 1, 'cookies' => [] ] );
		if ( is_wp_error( $response ) ) {
			return [ 'status' => null, 'content' => null, 'reason' => 'Public HTTP unavailable: ' . $response->get_error_message() ];
		}
		$status = wp_remote_retrieve_response_code( $response );
		$content = wp_remote_retrieve_body( $response );
		if ( strlen( $content ) > self::LIMIT ) {
			return [ 'status' => $status, 'content' => null, 'reason' => 'Public response exceeds unsupported-size limit of 128 KiB.' ];
		}
		try {
			self::text( $content );
		} catch ( Frontman_Tool_Error $error ) {
			return [ 'status' => $status, 'content' => null, 'reason' => $error->getMessage() ];
		}
		return [ 'status' => $status, 'content' => $content, 'reason' => null ];
	}
	public function read_public_file( array $input ): array {
		return $this->assert_current( self::validate_input( 'wp_read_public_file', $input ) )[2];
	}
	private function assert_current( array $input ): array {
		$scope = $this->scope( $input['name'] );
		$local = $this->local( $scope[1], $scope[3] );
		$public = $this->public_state( $scope[2] );
		if ( ! isset( $input['expected_revision'] ) && null !== $public['reason'] && false !== strpos( $public['reason'], 'unsupported-size' ) ) {
			throw new Frontman_Tool_Error( $public['reason'] );
		}
		$block = null;
		if ( ! current_user_can( 'edit_files' ) || ( defined( 'DISALLOW_FILE_EDIT' ) && DISALLOW_FILE_EDIT ) || ! wp_is_file_mod_allowed( 'frontman_public_files' ) ) {
			$block = 'File editing is prohibited by capability or WordPress modification policy.';
		} elseif ( ! $scope[3]->is_writable( $scope[0] ) || ( $local['exists'] && ! $scope[3]->is_writable( $scope[1] ) ) ) {
			$block = 'Public root or target is not writable.';
		} elseif ( ! $local['exists'] && ( null !== $public['reason'] || ! in_array( $public['status'], [ 200, 404 ], true ) ) ) {
			$block = 'Creation requires an available public 200 or 404 inspection.';
		} elseif ( $local['exists'] && $public['status'] >= 200 && $public['status'] < 300
			&& ( null !== $public['reason'] || $public['content'] !== $local['content'] ) ) {
			$block = 'Public output differs from local content; resolve possible host/CDN control before writing.';
		}
		$revision = hash( 'sha256', serialize( [ $input['name'], $scope[0], $scope[2], $local, $local['exists'] ? null : $public ] ) );
		if ( isset( $input['expected_revision'] ) && ( null !== $block || $input['expected_revision'] !== $revision ) ) {
			throw new Frontman_Tool_Error( $block ?? 'Stale revision; read current state again before editing.' );
		}
		$warning = ! $local['exists'] ? 'Physical creation takes over any generated output; generated rules/sitemaps will stop updating. Manual removal is required to restore generation. Remote output ownership is unknown.'
			: ( null !== $public['reason'] || 200 !== $public['status'] ? 'Public output is unavailable or unsuccessful; local saving cannot guarantee public delivery.' : null );
		return [ $scope, $local, [ 'name' => $input['name'], 'url' => $scope[2] ] + $local + [
			'revision' => $revision, 'public' => $public, 'writable' => null === $block, 'block_reason' => $block,
			'previous' => get_option( 'frontman_public_file_previous_' . $input['name'], null ), 'warning' => $warning,
		] ];
	}
	public function write_public_file( array $input ): array {
		$input = self::validate_input( 'wp_write_public_file', $input );
		[ $scope, $before, $inspection ] = $this->assert_current( $input );
		$key = 'frontman_public_file_previous_' . $input['name'];
		$previous = $inspection['previous'];
		$backed_up = false;
		$fs = $scope[3];
		$stage = wp_tempnam( 'frontman-public', $scope[0] . '/' );
		$saved = false;
		try {
			if ( ! is_string( $stage ) || dirname( $stage ) !== $scope[0] ) {
				throw new Frontman_Tool_Error( 'Cannot create same-directory staging file.' );
			}
			$this->local( $stage, $fs );
			if ( ! $fs->chmod( $stage, 0600 ) || ! $fs->put_contents( $stage, $input['content'], 0600 )
				|| $this->local( $stage, $fs )['content'] !== $input['content'] ) {
				throw new Frontman_Tool_Error( 'Staging write/readback failed; target was not replaced.' );
			}
			if ( get_option( $key, null ) !== $previous ) {
				throw new Frontman_Tool_Error( 'Previous snapshot independently changed; target was not replaced.' );
			}
			$backed_up = true;
			update_option( $key, $before, false );
			if ( get_option( $key, null ) !== $before ) {
				throw new Frontman_Tool_Error( 'Previous snapshot backup failed; target was not replaced.' );
			}
			$mode = $before['exists'] ? fileperms( $scope[1] ) : ( defined( 'FS_CHMOD_FILE' ) ? FS_CHMOD_FILE : 0644 );
			if ( false === $mode || ! $fs->chmod( $stage, $mode & 0777 ) ) {
				throw new Frontman_Tool_Error( 'Mode preservation failed.' );
			}
			$this->assert_current( $input );
			if ( ! @rename( $stage, $scope[1] ) ) {
				throw new Frontman_Tool_Error( 'Rename failed; target was not deleted. Inspect current state before retrying.' );
			}
			$saved = true;
		} catch ( \Throwable $error ) {
			if ( $backed_up && get_option( $key, null ) !== $previous ) {
				try {
					if ( get_option( $key, null ) === $before ) {
						if ( null === $previous ) { delete_option( $key ); } else { update_option( $key, $previous, false ); }
					}
					if ( get_option( $key, null ) !== $previous ) {
						throw new Frontman_Tool_Error( 'Option not restored or backup independently changed; inspect state.' );
					}
				} catch ( \Throwable $recovery_error ) {
					throw new Frontman_Tool_Error( 'Previous snapshot recovery failed: ' . $recovery_error->getMessage() . '. Original failure: ' . $error->getMessage() );
				}
			}
			throw $error;
		} finally {
			if ( is_string( $stage ) && file_exists( $stage ) && ! $fs->delete( $stage ) ) {
				throw new Frontman_Tool_Error( 'Staging cleanup failed; saved=' . ( $saved ? 'true' : 'false' ) . '. Inspect state; do not retry automatically.' );
			}
		}
		$after = null;
		$reason = null;
		try {
			$after = $this->local( $scope[1], $fs );
			if ( $after !== [ 'exists' => true, 'content' => $input['content'] ] ) {
				$reason = 'Local persistence differs from requested bytes; inspect state and do not retry automatically.';
			}
		} catch ( \Throwable $error ) {
			$reason = 'Local persistence unknown: ' . $error->getMessage() . ' Do not retry automatically.';
		}
		$observed = $this->public_state( $scope[2] );
		if ( null === $reason && ( 200 !== $observed['status'] || null !== $observed['reason'] || $observed['content'] !== $input['content'] ) ) {
			$reason = $observed['reason'] ?? 'Saved locally but public response is non-200 or differs. Do not retry automatically.';
		}
		return [ 'name' => $input['name'], 'url' => $scope[2], 'before' => $before, 'after' => $after,
			'saved' => true, 'verified' => null === $reason, 'reason' => $reason, 'warning' => $inspection['warning'] ];
	}
}
