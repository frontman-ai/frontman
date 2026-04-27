<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-media-tools/' );

$GLOBALS['frontman_test_uploads']             = [];
$GLOBALS['frontman_test_attachments']         = [];
$GLOBALS['frontman_test_attachment_meta']     = [];
$GLOBALS['frontman_test_attachment_metadata'] = [];
$GLOBALS['frontman_test_next_attachment_id']  = 1000;
$GLOBALS['frontman_test_deleted_files']        = [];
$GLOBALS['frontman_test_filetype_and_ext']     = null;

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_check_invalid_utf8' ) ) {
	function wp_check_invalid_utf8( string $value ): string {
		return $value;
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( strip_tags( (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_textarea_field' ) ) {
	function sanitize_textarea_field( $value ): string {
		return trim( strip_tags( (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_file_name' ) ) {
	function sanitize_file_name( $filename ): string {
		$filename = basename( (string) $filename );
		$filename = preg_replace( '/\s+/', '-', $filename );
		return preg_replace( '/[^A-Za-z0-9._\-]/', '', $filename );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return 'sanitized:' . (string) $value;
	}
}

if ( ! function_exists( 'absint' ) ) {
	function absint( $value ): int {
		return abs( (int) $value );
	}
}

if ( ! function_exists( 'get_allowed_mime_types' ) ) {
	function get_allowed_mime_types(): array {
		return [
			'jpg|jpeg|jpe' => 'image/jpeg',
			'png'          => 'image/png',
			'gif'          => 'image/gif',
			'webp'         => 'image/webp',
			'pdf'          => 'application/pdf',
		];
	}
}

if ( ! function_exists( 'wp_check_filetype' ) ) {
	function wp_check_filetype( string $filename, array $mimes = [] ): array {
		$extension = strtolower( pathinfo( $filename, PATHINFO_EXTENSION ) );
		foreach ( $mimes as $extensions => $mime_type ) {
			if ( in_array( $extension, explode( '|', $extensions ), true ) ) {
				return [ 'ext' => $extension, 'type' => $mime_type ];
			}
		}

		return [ 'ext' => false, 'type' => false ];
	}
}

if ( ! function_exists( 'wp_upload_bits' ) ) {
	function wp_upload_bits( string $filename, $deprecated, string $bits ): array {
		$filetype = wp_check_filetype( $filename, get_allowed_mime_types() );
		$GLOBALS['frontman_test_uploads'][] = [
			'filename' => $filename,
			'bits'     => $bits,
			'type'     => $filetype['type'],
		];

		return [
			'file'  => ABSPATH . 'uploads/' . $filename,
			'url'   => 'https://example.test/uploads/' . $filename,
			'type'  => $filetype['type'],
			'error' => false,
		];
	}
}

if ( ! function_exists( 'wp_check_filetype_and_ext' ) ) {
	function wp_check_filetype_and_ext( string $file, string $filename, $mimes = null ): array {
		if ( null !== $GLOBALS['frontman_test_filetype_and_ext'] ) {
			return $GLOBALS['frontman_test_filetype_and_ext'];
		}

		return wp_check_filetype( $filename, is_array( $mimes ) ? $mimes : get_allowed_mime_types() );
	}
}

if ( ! function_exists( 'wp_delete_file' ) ) {
	function wp_delete_file( string $file ): bool {
		$GLOBALS['frontman_test_deleted_files'][] = $file;
		return true;
	}
}

if ( ! function_exists( 'is_wp_error' ) ) {
	function is_wp_error( $value ): bool {
		return false;
	}
}

if ( ! function_exists( 'wp_insert_attachment' ) ) {
	function wp_insert_attachment( array $attachment, string $file, int $post_id = 0 ): int {
		$id = ++$GLOBALS['frontman_test_next_attachment_id'];
		$GLOBALS['frontman_test_attachments'][ $id ] = [
			'attachment' => $attachment,
			'file'       => $file,
			'post_id'    => $post_id,
		];

		return $id;
	}
}

if ( ! function_exists( 'wp_generate_attachment_metadata' ) ) {
	function wp_generate_attachment_metadata( int $attachment_id, string $file ): array {
		return [ 'file' => basename( $file ), 'generated_for' => $attachment_id ];
	}
}

if ( ! function_exists( 'wp_update_attachment_metadata' ) ) {
	function wp_update_attachment_metadata( int $attachment_id, array $metadata ): bool {
		$GLOBALS['frontman_test_attachment_metadata'][ $attachment_id ] = $metadata;
		return true;
	}
}

if ( ! function_exists( 'update_post_meta' ) ) {
	function update_post_meta( int $post_id, string $key, $value ): bool {
		$GLOBALS['frontman_test_attachment_meta'][ $post_id ][ $key ] = $value;
		return true;
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../tools/class-tool-media.php';

class Frontman_Media_Tools_Test_Runner {
	private Frontman_Tool_Media $tool;
	private Frontman_Tools $tools;
	private int $assertions = 0;

	public function __construct() {
		$this->tool  = new Frontman_Tool_Media();
		$this->tools = Frontman_Tools::instance();
		$this->tool->register( $this->tools );
	}

	public function run(): void {
		$this->test_uploads_base64_image_to_media_library();
		$this->test_upload_infers_filename_and_mime_type_from_attachment_reference();
		$this->test_upload_rejects_missing_resolved_content();
		$this->test_upload_rejects_uploaded_filetype_mismatch();
		$this->test_tool_schema_exposes_image_ref();
		$this->test_sanitizer_preserves_upload_content();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function test_uploads_base64_image_to_media_library(): void {
		$this->reset_upload_state();

		$result = $this->tool->upload_media( [
			'content'   => base64_encode( 'png-binary' ),
			'encoding'  => 'base64',
			'mime_type' => 'image/png',
			'filename'  => 'Hero Image.png',
			'title'     => 'Hero Image',
			'alt_text'  => 'AutonomyAI product hero',
			'caption'   => 'Hero caption',
			'post_id'   => 42,
		] );

		$this->assert_true( true === $result['success'], 'wp_upload_media reports success' );
		$this->assert_same( 1001, $result['attachment_id'], 'wp_upload_media returns attachment_id' );
		$this->assert_same( 'https://example.test/uploads/Hero-Image.png', $result['url'], 'wp_upload_media returns uploaded URL' );
		$this->assert_same( 'image/png', $result['mime_type'], 'wp_upload_media returns MIME type' );
		$this->assert_same( [ 'id' => 1001, 'url' => 'https://example.test/uploads/Hero-Image.png', 'source' => 'library' ], $result['elementor_image'], 'wp_upload_media returns Elementor image payload' );
		$this->assert_same( 'png-binary', $GLOBALS['frontman_test_uploads'][0]['bits'], 'wp_upload_media decodes base64 before upload' );
		$this->assert_same( 42, $GLOBALS['frontman_test_attachments'][1001]['post_id'], 'wp_upload_media attaches media to post_id' );
		$this->assert_same( 'AutonomyAI product hero', $GLOBALS['frontman_test_attachment_meta'][1001]['_wp_attachment_image_alt'], 'wp_upload_media saves alt text' );
		$this->assert_same( 'Hero caption', $GLOBALS['frontman_test_attachments'][1001]['attachment']['post_excerpt'], 'wp_upload_media saves caption' );
	}

	private function test_upload_infers_filename_and_mime_type_from_attachment_reference(): void {
		$this->reset_upload_state();

		$result = $this->tool->upload_media( [
			'image_ref' => 'attachment://att_abc/demo-photo.jpg',
			'content'   => 'data:image/jpeg;base64,' . base64_encode( 'jpeg-binary' ),
		] );

		$this->assert_same( 'demo-photo.jpg', $result['filename'], 'wp_upload_media infers filename from image_ref' );
		$this->assert_same( 'image/jpeg', $result['mime_type'], 'wp_upload_media infers MIME type from data URL' );
		$this->assert_same( 'demo-photo', $result['title'], 'wp_upload_media falls back to filename title' );
	}

	private function test_upload_rejects_missing_resolved_content(): void {
		$this->assert_throws(
			function() {
				$this->tool->upload_media( [ 'image_ref' => 'attachment://att_abc/missing.png' ] );
			},
			'No media content supplied',
			'wp_upload_media rejects unresolved image_ref content'
		);
	}

	private function test_upload_rejects_uploaded_filetype_mismatch(): void {
		$this->reset_upload_state();
		$GLOBALS['frontman_test_filetype_and_ext'] = [ 'ext' => false, 'type' => false ];

		$this->assert_throws(
			function() {
				$this->tool->upload_media( [
					'content'   => base64_encode( 'not-really-a-png' ),
					'encoding'  => 'base64',
					'mime_type' => 'image/png',
					'filename'  => 'fake.png',
				] );
			},
			'content does not match an allowed file type',
			'wp_upload_media rejects uploaded content when WordPress cannot validate the file type'
		);

		$this->assert_same( [], $GLOBALS['frontman_test_attachments'], 'wp_upload_media does not create attachment after failed content validation' );
		$this->assert_same( [ ABSPATH . 'uploads/fake.png' ], $GLOBALS['frontman_test_deleted_files'], 'wp_upload_media deletes failed uploads with WordPress API' );
	}

	private function test_tool_schema_exposes_image_ref(): void {
		$definition = $this->tools->get( 'wp_upload_media' );
		$this->assert_true( null !== $definition, 'wp_upload_media is registered' );
		$this->assert_true( isset( $definition->input_schema['properties']['image_ref'] ), 'wp_upload_media schema exposes image_ref' );
		$this->assert_true( isset( $definition->input_schema['properties']['content'] ), 'wp_upload_media schema accepts resolved content' );
	}

	private function test_sanitizer_preserves_upload_content(): void {
		$input = [
			'image_ref' => 'attachment://att_abc/caf%C3%A9.png',
			'content'   => 'abc<raw>base64',
			'filename'  => 'raw.png',
			'mime_type' => 'image/png',
		];

		$sanitized = $this->tools->sanitize_input( 'wp_upload_media', $input );
		$this->assert_same( 'attachment://att_abc/caf%C3%A9.png', $sanitized['image_ref'], 'wp_upload_media sanitizer preserves image_ref URI bytes' );
		$this->assert_same( 'abc<raw>base64', $sanitized['content'], 'wp_upload_media sanitizer preserves raw base64 content' );
	}

	private function reset_upload_state(): void {
		$GLOBALS['frontman_test_uploads']             = [];
		$GLOBALS['frontman_test_attachments']         = [];
		$GLOBALS['frontman_test_attachment_meta']     = [];
		$GLOBALS['frontman_test_attachment_metadata'] = [];
		$GLOBALS['frontman_test_next_attachment_id']  = 1000;
		$GLOBALS['frontman_test_deleted_files']        = [];
		$GLOBALS['frontman_test_filetype_and_ext']     = null;
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . ' expected ' . var_export( $expected, true ) . ' got ' . var_export( $actual, true ) );
		}
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}

	private function assert_throws( callable $callback, string $expected_message, string $message ): void {
		$this->assertions++;
		try {
			$callback();
		} catch ( Frontman_Tool_Error $e ) {
			if ( false !== strpos( $e->getMessage(), $expected_message ) ) {
				return;
			}

			throw new RuntimeException( $message . ' threw unexpected message: ' . $e->getMessage() );
		}

		throw new RuntimeException( $message . ' did not throw' );
	}
}

( new Frontman_Media_Tools_Test_Runner() )->run();
