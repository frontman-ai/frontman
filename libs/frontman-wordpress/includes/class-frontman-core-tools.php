<?php
/**
 * Local PHP implementations of the core filesystem tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Core_Tools {
	private const NOISE_DIRS = [
		'node_modules',
		'.git',
		'dist',
		'build',
		'.next',
		'_build',
		'deps',
		'.turbo',
		'.cache',
		'coverage',
		'.svelte-kit',
		'.output',
		'.nuxt',
		'.vercel',
		'__pycache__',
		'target',
	];

	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'read_file',
			'Reads a file from the WordPress root filesystem with optional line offset and limit. Relative paths are resolved from the WordPress root directory.',
			[
				'type'       => 'object',
				'properties' => [
					'path'   => [ 'type' => 'string' ],
					'offset' => [ 'type' => 'integer', 'default' => 0 ],
					'limit'  => [ 'type' => 'integer', 'default' => 500 ],
				],
				'required'   => [ 'path' ],
			],
			[ $this, 'read_file' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'list_files',
			'Lists the immediate contents of a directory under the WordPress root directory. Relative paths are resolved from the WordPress root.',
			[
				'type'       => 'object',
				'properties' => [
					'path' => [ 'type' => 'string' ],
				],
			],
			[ $this, 'list_files' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'file_exists',
			'Checks if a file or directory exists under the WordPress root directory. Relative paths are resolved from the WordPress root.',
			[
				'type'       => 'object',
				'properties' => [
					'path' => [ 'type' => 'string' ],
				],
				'required'   => [ 'path' ],
			],
			[ $this, 'file_exists' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'load_agent_instructions',
			'Discovers and loads Agents.md or CLAUDE.md files by walking up directories starting from the WordPress root directory or a subdirectory under it.',
			[
				'type'       => 'object',
				'properties' => [
					'startPath' => [ 'type' => 'string' ],
				],
			],
			[ $this, 'load_agent_instructions' ],
			false
		) );

		$tools->add( new Frontman_Tool_Definition(
			'grep',
			'Searches file contents for text or regex patterns under the WordPress root directory. Relative paths are resolved from the WordPress root.',
			[
				'type'       => 'object',
				'properties' => [
					'pattern'          => [ 'type' => 'string' ],
					'path'             => [ 'type' => 'string' ],
					'type'             => [ 'type' => 'string' ],
					'glob'             => [ 'type' => 'string' ],
					'case_insensitive' => [ 'type' => 'boolean', 'default' => false ],
					'literal'          => [ 'type' => 'boolean', 'default' => false ],
					'max_results'      => [ 'type' => 'integer', 'default' => 20 ],
				],
				'required'   => [ 'pattern' ],
			],
			[ $this, 'grep' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'search_files',
			'Searches file names across the WordPress root directory. Relative paths are resolved from the WordPress root.',
			[
				'type'       => 'object',
				'properties' => [
					'pattern'     => [ 'type' => 'string' ],
					'path'        => [ 'type' => 'string' ],
					'max_results' => [ 'type' => 'integer', 'default' => 20 ],
				],
				'required'   => [ 'pattern' ],
			],
			[ $this, 'search_files' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'list_tree',
			'Returns a recursive directory tree rooted at the WordPress root directory, with lightweight workspace detection for paths under that root.',
			[
				'type'       => 'object',
				'properties' => [
					'path'  => [ 'type' => 'string' ],
					'depth' => [ 'type' => 'integer', 'default' => 3 ],
				],
			],
			[ $this, 'list_tree' ]
		) );
	}

	public function read_file( array $input ): array {
		$resolved = Frontman_Core_Path::resolve( $input['path'] ?? '' );
		$offset   = max( 0, (int) ( $input['offset'] ?? 0 ) );
		$limit    = max( 1, (int) ( $input['limit'] ?? 500 ) );

		if ( ! file_exists( $resolved['resolvedPath'] ) || ! is_file( $resolved['resolvedPath'] ) ) {
			throw new Frontman_Tool_Error( 'Failed to read file ' . ( $input['path'] ?? '' ) . ': file does not exist' );
		}

		$content     = file_get_contents( $resolved['resolvedPath'] );
		$lines       = preg_split( '/\r\n|\n|\r/', (string) $content );
		$total_lines = count( $lines );
		$selected    = array_slice( $lines, $offset, $limit );

		Frontman_Core_File_Tracker::record_read( $resolved['resolvedPath'], $offset, $limit, $total_lines );

		return [
			'content'    => implode( "\n", $selected ),
			'totalLines' => $total_lines,
			'hasMore'    => ( $offset + $limit ) < $total_lines,
			'_context'   => $this->path_context( $resolved ),
		];
	}

	public function list_files( array $input ): array {
		$requested = $input['path'] ?? '.';
		$resolved  = Frontman_Core_Path::resolve( $requested );
		$full_path = is_file( $resolved['resolvedPath'] ) ? dirname( $resolved['resolvedPath'] ) : $resolved['resolvedPath'];
		$base_rel  = Frontman_Core_Path::to_relative_path( Frontman_Core_Path::source_root(), Frontman_Core_Path::normalize( $full_path ) );

		$entries = @scandir( $full_path );
		if ( false === $entries ) {
			throw new Frontman_Tool_Error( 'Failed to list files in ' . $requested );
		}

		$entries = array_values( array_diff( $entries, [ '.', '..' ] ) );
		$entries = $this->filter_git_ignored_entries( $full_path, $entries );

		$result = [];
		foreach ( $entries as $name ) {
			$entry_path = $full_path . '/' . $name;
			$result[]   = [
				'name'        => $name,
				'path'        => '' === $base_rel ? $name : $base_rel . '/' . $name,
				'isFile'      => is_file( $entry_path ),
				'isDirectory' => is_dir( $entry_path ),
			];
		}

		return $result;
	}

	public function file_exists( array $input ): bool {
		$resolved = Frontman_Core_Path::resolve( $input['path'] ?? '' );
		return file_exists( $resolved['resolvedPath'] );
	}

	public function load_agent_instructions( array $input ): array {
		$resolved    = Frontman_Core_Path::resolve( $input['startPath'] ?? '.' );
		$source_root = $resolved['sourceRoot'];
		$dir         = is_dir( $resolved['resolvedPath'] ) ? $resolved['resolvedPath'] : dirname( $resolved['resolvedPath'] );
		$files       = [];

		while ( true ) {
			$level_files = $this->load_instruction_variants( $dir, [ 'Agents.md', '.claude/Agents.md', 'Agents.local.md' ] );
			if ( empty( $level_files ) ) {
				$level_files = $this->load_instruction_variants( $dir, [ 'CLAUDE.md', '.claude/CLAUDE.md', 'CLAUDE.local.md' ] );
			}

			$files = array_merge( $files, $level_files );
			if ( $dir === $source_root ) {
				break;
			}

			$parent = dirname( $dir );
			if ( $parent === $dir ) {
				break;
			}
			$dir = $parent;
		}

		return $files;
	}

	public function grep( array $input ): array {
		try {
			$search_path      = Frontman_Core_Path::resolve_search_path( $input['path'] ?? null );
			$case_insensitive = ! empty( $input['case_insensitive'] );
			$literal          = ! empty( $input['literal'] );
			$max_results      = max( 1, (int) ( $input['max_results'] ?? 20 ) );
			$pattern          = (string) ( $input['pattern'] ?? '' );
			$type_filter      = isset( $input['type'] ) ? (string) $input['type'] : null;
			$glob_filter      = isset( $input['glob'] ) ? (string) $input['glob'] : null;
			$files            = $this->collect_searchable_files( $search_path, true );
			$file_matches     = [];
			$total_matches    = 0;

			foreach ( $files as $file ) {
				$relative = Frontman_Core_Path::to_relative_path( Frontman_Core_Path::source_root(), $file );
				if ( ! $this->matches_file_filter( $relative, $type_filter, $glob_filter ) ) {
					continue;
				}

				$lines   = @file( $file, FILE_IGNORE_NEW_LINES );
				$matches = [];
				if ( false === $lines ) {
					continue;
				}

				foreach ( $lines as $index => $line ) {
					if ( $this->line_matches( $line, $pattern, $literal, $case_insensitive ) ) {
						$matches[] = [
							'lineNum'  => $index + 1,
							'lineText' => $line,
						];
					}
				}

				if ( empty( $matches ) ) {
					continue;
				}

				$total_matches += count( $matches );
				$file_matches[] = [
					'path'    => $relative,
					'matches' => $matches,
				];
			}

			return [
				'files'        => array_slice( $file_matches, 0, $max_results ),
				'totalMatches' => $total_matches,
				'truncated'    => count( $file_matches ) > $max_results,
			];
		} catch ( Frontman_Tool_Error $e ) {
			throw $e;
		} catch ( Throwable $e ) {
			throw new Frontman_Tool_Error( 'Grep failed: ' . $e->getMessage() );
		}
	}

	public function search_files( array $input ): array {
		try {
			$search_dir  = Frontman_Core_Path::resolve_search_dir( $input['path'] ?? null );
			$pattern     = (string) ( $input['pattern'] ?? '' );
			$max_results = max( 1, (int) ( $input['max_results'] ?? 20 ) );
			$matches     = [];

			foreach ( $this->collect_searchable_files( $search_dir, false ) as $file ) {
				$relative = Frontman_Core_Path::to_relative_path( Frontman_Core_Path::source_root(), $file );
				if ( $this->matches_filename_pattern( basename( $relative ), $pattern ) ) {
					$matches[] = $relative;
				}
			}

			return [
				'files'        => array_slice( $matches, 0, $max_results ),
				'totalResults' => count( $matches ),
				'truncated'    => count( $matches ) > $max_results,
			];
		} catch ( Frontman_Tool_Error $e ) {
			throw $e;
		} catch ( Throwable $e ) {
			throw new Frontman_Tool_Error( 'Search files failed: ' . $e->getMessage() );
		}
	}


	public function list_tree( array $input ): array {
		try {
			$resolved = Frontman_Core_Path::resolve( $input['path'] ?? '.' );
			$full     = is_file( $resolved['resolvedPath'] ) ? dirname( $resolved['resolvedPath'] ) : $resolved['resolvedPath'];
			$depth    = max( 1, (int) ( $input['depth'] ?? 3 ) );
			$mono     = $this->detect_monorepo( $full );
			$lookup   = [];

			foreach ( $mono['workspaces'] as $workspace ) {
				$lookup[ $workspace['path'] ] = $workspace['name'];
			}

			return [
				'tree'         => $this->render_tree( $full, $depth, $lookup ),
				'workspaces'   => $mono['workspaces'],
				'monorepoType' => $mono['monorepoType'],
			];
		} catch ( Frontman_Tool_Error $e ) {
			throw $e;
		} catch ( Throwable $e ) {
			throw new Frontman_Tool_Error( 'Failed to list tree: ' . $e->getMessage() );
		}
	}

	private function path_context( array $resolved ): array {
		return [
			'sourceRoot'   => $resolved['sourceRoot'],
			'resolvedPath' => $resolved['resolvedPath'],
			'relativePath' => $resolved['relativePath'],
		];
	}

	private function collect_searchable_files( string $path, bool $skip_hidden_files ): array {
		if ( is_file( $path ) ) {
			return [ Frontman_Core_Path::normalize( $path ) ];
		}

		if ( ! is_dir( $path ) ) {
			throw new Frontman_Tool_Error( 'Path does not exist: ' . $path );
		}

		$results   = [];
		$directory = new RecursiveDirectoryIterator( $path, FilesystemIterator::SKIP_DOTS );
		$filter    = new RecursiveCallbackFilterIterator(
			$directory,
			function( SplFileInfo $current ) use ( $skip_hidden_files ): bool {
				$name = $current->getFilename();
				if ( $current->isDir() ) {
					return ! in_array( $name, self::NOISE_DIRS, true ) && '.' !== substr( $name, 0, 1 );
				}

				if ( $skip_hidden_files && '.' === substr( $name, 0, 1 ) ) {
					return false;
				}

				return true;
			}
		);
		$iterator  = new RecursiveIteratorIterator( $filter );

		foreach ( $iterator as $file ) {
			if ( ! $file->isFile() || $this->is_binary_file( $file->getPathname() ) ) {
				continue;
			}

			$results[] = Frontman_Core_Path::normalize( $file->getPathname() );
		}

		return $results;
	}

	private function is_binary_file( string $path ): bool {
		$sample = @file_get_contents( $path, false, null, 0, 1024 );
		return false !== $sample && false !== strpos( $sample, "\0" );
	}

	private function line_matches( string $line, string $pattern, bool $literal, bool $case_insensitive ): bool {
		if ( $literal ) {
			return $case_insensitive
				? false !== stripos( $line, $pattern )
				: false !== strpos( $line, $pattern );
		}

		$flags = $case_insensitive ? 'i' : '';
		$result = @preg_match( '/' . str_replace( '/', '\/', $pattern ) . '/' . $flags, $line );
		if ( false === $result ) {
			throw new Frontman_Tool_Error( 'Invalid regex pattern for grep: ' . $pattern );
		}

		return 1 === $result;
	}

	private function matches_file_filter( string $path, ?string $type_filter, ?string $glob_filter ): bool {
		if ( null !== $type_filter && '.' . strtolower( $type_filter ) !== strtolower( strrchr( $path, '.' ) ?: '' ) ) {
			return false;
		}

		if ( null !== $glob_filter ) {
			foreach ( $this->expand_brace_glob( $glob_filter ) as $glob ) {
				if ( fnmatch( $glob, basename( $path ) ) || fnmatch( $glob, $path ) ) {
					return true;
				}
			}

			return false;
		}

		return true;
	}

	private function matches_filename_pattern( string $file_name, string $pattern ): bool {
		$pattern_lower   = strtolower( $pattern );
		$file_name_lower = strtolower( $file_name );

		if ( '' === $pattern_lower ) {
			return true;
		}

		if ( false !== strpos( $pattern_lower, '*' ) ) {
			$parts = explode( '*', $pattern_lower );
			$index = 0;
			foreach ( $parts as $part ) {
				if ( '' === $part ) {
					continue;
				}

				$found = strpos( $file_name_lower, $part, $index );
				if ( false === $found ) {
					return false;
				}

				if ( 0 === $index && '' !== $parts[0] && 0 !== $found ) {
					return false;
				}

				$index = $found + strlen( $part );
			}

			$last = end( $parts );
			return '' === $last || $this->ends_with( $file_name_lower, $last );
		}

		return false !== strpos( $file_name_lower, $pattern_lower );
	}

	private function filter_git_ignored_entries( string $cwd, array $entries ): array {
		if ( empty( $entries ) || ! function_exists( 'exec' ) ) {
			return $entries;
		}

		$ignored = [];
		$status  = 1;
		$command = 'cd ' . escapeshellarg( $cwd ) . ' && printf %s ' . escapeshellarg( implode( "\n", $entries ) ) . ' | git check-ignore --stdin 2>/dev/null';
		exec( $command, $ignored, $status );

		if ( 1 !== $status && 0 !== $status ) {
			return $entries;
		}

		return array_values( array_diff( $entries, array_filter( $ignored ) ) );
	}

	private function load_instruction_variants( string $dir, array $variants ): array {
		$files = [];
		foreach ( $variants as $variant ) {
			$path = $dir . '/' . $variant;
			$real = $this->find_file_case_insensitive( dirname( $path ), basename( $path ) );
			if ( null === $real || ! is_file( $real ) ) {
				continue;
			}

			$content = @file_get_contents( $real );
			if ( false === $content ) {
				continue;
			}

			$files[] = [
				'content'  => $content,
				'fullPath' => Frontman_Core_Path::normalize( $real ),
			];
		}

		return $files;
	}

	private function find_file_case_insensitive( string $dir, string $target ): ?string {
		if ( ! is_dir( $dir ) ) {
			return null;
		}

		foreach ( scandir( $dir ) ?: [] as $file ) {
			if ( strtolower( $file ) === strtolower( $target ) ) {
				return $dir . '/' . $file;
			}
		}

		return null;
	}

	private function detect_monorepo( string $root ): array {
		$workspaces = [];
		$pkg_path   = $root . '/package.json';
		$workspace_globs = [];
		$monorepo_type   = null;

		if ( is_file( $pkg_path ) ) {
			$data = json_decode( (string) file_get_contents( $pkg_path ), true );
			if ( is_array( $data ) ) {
				if ( isset( $data['workspaces'] ) && is_array( $data['workspaces'] ) ) {
					if ( isset( $data['workspaces']['packages'] ) && is_array( $data['workspaces']['packages'] ) ) {
						$workspace_globs = $data['workspaces']['packages'];
					} elseif ( array_values( $data['workspaces'] ) === $data['workspaces'] ) {
						$workspace_globs = $data['workspaces'];
					}
					$monorepo_type   = 'npm-workspaces';
				}
			}
		}

		if ( is_file( $root . '/turbo.json' ) ) {
			$monorepo_type = 'turborepo';
		} elseif ( is_file( $root . '/nx.json' ) ) {
			$monorepo_type = 'nx';
		} elseif ( is_file( $root . '/pnpm-workspace.yaml' ) ) {
			$monorepo_type = 'pnpm-workspaces';
		}

		foreach ( $workspace_globs as $glob ) {
			foreach ( $this->resolve_workspace_glob( $root, (string) $glob ) as $relative ) {
				$name      = $relative;
				$pkg       = $root . '/' . $relative . '/package.json';
				$pkg_json  = is_file( $pkg ) ? json_decode( (string) file_get_contents( $pkg ), true ) : null;
				if ( is_array( $pkg_json ) && ! empty( $pkg_json['name'] ) ) {
					$name = (string) $pkg_json['name'];
				}
				$workspaces[] = [
					'name' => $name,
					'path' => $relative,
				];
			}
		}

		return [
			'monorepoType' => $monorepo_type,
			'workspaces'   => $workspaces,
		];
	}

	private function resolve_workspace_glob( string $root, string $glob ): array {
		if ( $this->ends_with( $glob, '/*' ) ) {
			$parent = $root . '/' . substr( $glob, 0, -2 );
			$paths  = [];
			foreach ( scandir( $parent ) ?: [] as $entry ) {
				if ( '.' === $entry || '..' === $entry || ! is_dir( $parent . '/' . $entry ) ) {
					continue;
				}
				$paths[] = substr( $glob, 0, -2 ) . '/' . $entry;
			}
			return $paths;
		}

		return is_dir( $root . '/' . $glob ) ? [ $glob ] : [];
	}

	private function render_tree( string $root, int $max_depth, array $workspace_lookup ): string {
		$lines = [ '.' ];
		$this->append_tree_lines( $lines, $root, '', 1, $max_depth, $workspace_lookup );
		return implode( "\n", $lines );
	}

	private function append_tree_lines( array &$lines, string $dir, string $relative, int $depth, int $max_depth, array $workspace_lookup ): void {
		if ( $depth > $max_depth ) {
			return;
		}

		$entries = array_values(
			array_filter(
				scandir( $dir ) ?: [],
				function( string $entry ): bool {
					return '.' !== $entry && '..' !== $entry && ! in_array( $entry, self::NOISE_DIRS, true );
				}
			)
		);

		usort(
			$entries,
			function( string $a, string $b ) use ( $dir ): int {
				$a_dir = is_dir( $dir . '/' . $a );
				$b_dir = is_dir( $dir . '/' . $b );
				if ( $a_dir !== $b_dir ) {
					return $a_dir ? -1 : 1;
				}
				return strcasecmp( $a, $b );
			}
		);

		$truncated = count( $entries ) > 15;
		$visible   = $truncated ? array_slice( $entries, 0, 10 ) : $entries;

		foreach ( $visible as $index => $entry ) {
			$is_last  = ! $truncated && $index === count( $visible ) - 1;
			$path     = $dir . '/' . $entry;
			$is_dir   = is_dir( $path );
			$entry_rel = '' === $relative ? $entry : $relative . '/' . $entry;
			$label    = $entry . ( $is_dir ? '/' : '' );
			if ( $is_dir && isset( $workspace_lookup[ $entry_rel ] ) ) {
				$label .= ' [workspace: ' . $workspace_lookup[ $entry_rel ] . ']';
			}

			$lines[] = ( $is_last ? '└── ' : '├── ' ) . $label;
			if ( $is_dir ) {
				$child_lines = [];
				$this->append_tree_lines( $child_lines, $path, $entry_rel, $depth + 1, $max_depth, $workspace_lookup );
				$prefix = $is_last ? '    ' : '│   ';
				foreach ( $child_lines as $child_line ) {
					$lines[] = $prefix . $child_line;
				}
			}
		}

		if ( $truncated ) {
			$lines[] = '└── ... and ' . ( count( $entries ) - 10 ) . ' more entries';
		}
	}

	private function expand_brace_glob( string $glob ): array {
		if ( ! preg_match( '/\{([^}]+)\}/', $glob, $matches ) ) {
			return [ $glob ];
		}

		$patterns = [];
		foreach ( explode( ',', $matches[1] ) as $part ) {
			$patterns[] = str_replace( $matches[0], trim( $part ), $glob );
		}

		return $patterns;
	}

	private function ends_with( string $value, string $suffix ): bool {
		if ( '' === $suffix ) {
			return true;
		}

		return substr( $value, -strlen( $suffix ) ) === $suffix;
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
