<?php
/**
 * WordPress Media Library tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Media {
	private const MAX_UPLOAD_BYTES = 20971520; // 20 MB.

	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_upload_media',
			'Uploads a user-attached media asset into the WordPress Media Library. For chat image attachments, pass image_ref from the Available Image Attachments list; the browser resolves it before WordPress receives the request. Returns an attachment_id and URL for Elementor image widgets, post content, featured images, or custom HTML/CSS.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'image_ref'   => [
						'type'        => 'string',
						'description' => 'URI of a user-attached image, for example attachment://att_abc/photo.png. Prefer this when the user attached the asset in chat.',
					],
					'content'     => [
						'type'        => 'string',
						'description' => 'Base64-encoded file content. Usually filled automatically from image_ref by the browser client.',
					],
					'encoding'    => [
						'type'        => 'string',
						'enum'        => [ 'base64' ],
						'description' => 'Content encoding. Must be base64 when content is provided.',
					],
					'mime_type'   => [
						'type'        => 'string',
						'description' => 'Media MIME type. Usually filled automatically from image_ref.',
					],
					'filename'    => [
						'type'        => 'string',
						'description' => 'File name to use in the Media Library. If omitted, it is inferred from image_ref when possible.',
					],
					'title'       => [ 'type' => 'string', 'description' => 'Attachment title.' ],
					'alt_text'    => [ 'type' => 'string', 'description' => 'Image alt text saved as attachment metadata.' ],
					'caption'     => [ 'type' => 'string', 'description' => 'Attachment caption.' ],
					'description' => [ 'type' => 'string', 'description' => 'Attachment description.' ],
					'post_id'     => [ 'type' => 'integer', 'description' => 'Optional post/page ID to attach the media to.' ],
				],
			],
			[ $this, 'upload_media' ]
		) );
	}

	public function upload_media( array $input ): array {
		$mime_type = $this->sanitize_mime_type( $input['mime_type'] ?? '' );
		$content   = $this->require_content( $input, $mime_type );
		$filename  = $this->filename_for_upload( $input, $mime_type );
		$filetype  = $this->validate_filetype( $filename, $mime_type );
		$post_id   = absint( $input['post_id'] ?? 0 );

		if ( strlen( $content ) > self::MAX_UPLOAD_BYTES ) {
			throw new Frontman_Tool_Error( 'Media upload is too large. Maximum size is 20 MB.' );
		}

		$upload = wp_upload_bits( $filename, null, $content );
		if ( ! empty( $upload['error'] ) ) {
			throw new Frontman_Tool_Error( 'Failed to upload media: ' . $upload['error'] );
		}

		$file_path = (string) ( $upload['file'] ?? '' );
		$url       = (string) ( $upload['url'] ?? '' );
		if ( '' === $file_path || '' === $url ) {
			throw new Frontman_Tool_Error( 'WordPress did not return an uploaded media path.' );
		}

		try {
			$filetype = $this->validate_uploaded_file( $file_path, $filename, $filetype );
		} catch ( Frontman_Tool_Error $e ) {
			$this->delete_uploaded_file( $file_path );
			throw $e;
		}
		$title    = $this->attachment_title( $input, $filename );

		$attachment_id = wp_insert_attachment(
			[
				'post_mime_type' => $filetype['type'],
				'post_title'     => $title,
				'post_content'   => sanitize_textarea_field( $input['description'] ?? '' ),
				'post_excerpt'   => sanitize_text_field( $input['caption'] ?? '' ),
				'post_status'    => 'inherit',
			],
			$file_path,
			$post_id
		);

		if ( is_wp_error( $attachment_id ) ) {
			$this->delete_uploaded_file( $file_path );
			throw new Frontman_Tool_Error( 'Failed to create media attachment: ' . $attachment_id->get_error_message() );
		}

		$attachment_id = (int) $attachment_id;
		$this->update_attachment_metadata( $attachment_id, $file_path );

		$alt_text = sanitize_text_field( $input['alt_text'] ?? '' );
		if ( '' !== $alt_text ) {
			update_post_meta( $attachment_id, '_wp_attachment_image_alt', $alt_text );
		}

		return [
			'success'        => true,
			'attachment_id'  => $attachment_id,
			'url'            => $url,
			'filename'       => basename( $file_path ),
			'mime_type'      => $filetype['type'],
			'title'          => $title,
			'alt_text'       => $alt_text,
			'post_id'        => $post_id,
			'elementor_image' => [
				'id'     => $attachment_id,
				'url'    => $url,
				'source' => 'library',
			],
		];
	}

	private function require_content( array $input, string &$mime_type ): string {
		$encoding = sanitize_key( $input['encoding'] ?? 'base64' );
		if ( 'base64' !== $encoding ) {
			throw new Frontman_Tool_Error( 'Media content must use base64 encoding.' );
		}

		$raw = (string) ( $input['content'] ?? '' );
		if ( '' === $raw ) {
			throw new Frontman_Tool_Error( 'No media content supplied. Pass image_ref for an attached image so the browser can resolve it before upload.' );
		}

		if ( preg_match( '/^data:([^;]+);base64,(.*)$/s', $raw, $matches ) ) {
			if ( '' === $mime_type ) {
				$mime_type = $this->sanitize_mime_type( $matches[1] );
			}

			$raw = $matches[2];
		}

		$base64 = preg_replace( '/\s+/', '', $raw );
		if ( ! is_string( $base64 ) || '' === $base64 ) {
			throw new Frontman_Tool_Error( 'Media content is empty.' );
		}

		$content = base64_decode( $base64, true );
		if ( false === $content ) {
			throw new Frontman_Tool_Error( 'Media content is not valid base64.' );
		}

		return $content;
	}

	private function filename_for_upload( array $input, string $mime_type ): string {
		$filename = sanitize_file_name( $input['filename'] ?? '' );
		if ( '' === $filename && ! empty( $input['image_ref'] ) ) {
			$filename = sanitize_file_name( basename( (string) $input['image_ref'] ) );
		}

		if ( '' === $filename ) {
			$filename = 'frontman-upload';
		}

		if ( '' === pathinfo( $filename, PATHINFO_EXTENSION ) ) {
			$extension = $this->extension_for_mime_type( $mime_type );
			if ( '' !== $extension ) {
				$filename .= '.' . $extension;
			}
		}

		return $filename;
	}

	private function validate_filetype( string $filename, string $mime_type ): array {
		$filetype = wp_check_filetype( $filename, get_allowed_mime_types() );
		if ( empty( $filetype['type'] ) ) {
			throw new Frontman_Tool_Error( 'File type is not allowed for upload: ' . $filename );
		}

		if ( '' !== $mime_type && ! $this->mime_types_match( $mime_type, $filetype['type'] ) ) {
			throw new Frontman_Tool_Error( 'MIME type does not match the file extension for ' . $filename );
		}

		return $filetype;
	}

	private function validate_uploaded_file( string $file_path, string $filename, array $filetype ): array {
		if ( ! function_exists( 'wp_check_filetype_and_ext' ) ) {
			return $filetype;
		}

		$checked = wp_check_filetype_and_ext( $file_path, $filename, get_allowed_mime_types() );
		if ( empty( $checked['type'] ) || empty( $checked['ext'] ) ) {
			throw new Frontman_Tool_Error( 'Uploaded media file content does not match an allowed file type.' );
		}
		if ( ! $this->mime_types_match( $checked['type'], $filetype['type'] ) ) {
			throw new Frontman_Tool_Error( 'Uploaded media MIME type does not match the expected file type.' );
		}

		$filetype['type'] = $checked['type'];
		$filetype['ext']  = $checked['ext'];

		return $filetype;
	}

	private function delete_uploaded_file( string $file_path ): void {
		if ( '' === $file_path ) {
			return;
		}

		if ( function_exists( 'wp_delete_file' ) ) {
			wp_delete_file( $file_path );
		}
	}

	private function attachment_title( array $input, string $filename ): string {
		$title = sanitize_text_field( $input['title'] ?? '' );
		if ( '' !== $title ) {
			return $title;
		}

		return sanitize_text_field( preg_replace( '/\.[^.]+$/', '', $filename ) );
	}

	private function update_attachment_metadata( int $attachment_id, string $file_path ): void {
		if ( ! function_exists( 'wp_generate_attachment_metadata' ) ) {
			$image_api_path = ABSPATH . 'wp-admin/includes/image.php';
			if ( file_exists( $image_api_path ) ) {
				require_once $image_api_path;
			}
		}

		if ( ! function_exists( 'wp_generate_attachment_metadata' ) ) {
			return;
		}

		$metadata = wp_generate_attachment_metadata( $attachment_id, $file_path );
		if ( is_array( $metadata ) ) {
			wp_update_attachment_metadata( $attachment_id, $metadata );
		}
	}

	private function sanitize_mime_type( string $mime_type ): string {
		return strtolower( sanitize_text_field( $mime_type ) );
	}

	private function mime_types_match( string $provided, string $detected ): bool {
		return $this->normalize_mime_type( $provided ) === $this->normalize_mime_type( $detected );
	}

	private function normalize_mime_type( string $mime_type ): string {
		$mime_type = strtolower( trim( $mime_type ) );
		if ( in_array( $mime_type, [ 'image/jpg', 'image/pjpeg' ], true ) ) {
			return 'image/jpeg';
		}

		return $mime_type;
	}

	private function extension_for_mime_type( string $mime_type ): string {
		switch ( $this->normalize_mime_type( $mime_type ) ) {
			case 'image/jpeg':
				return 'jpg';
			case 'image/png':
				return 'png';
			case 'image/gif':
				return 'gif';
			case 'image/webp':
				return 'webp';
			case 'image/avif':
				return 'avif';
			case 'application/pdf':
				return 'pdf';
		}

		return '';
	}
}

// phpcs:enable WordPress.Security.EscapeOutput.ExceptionNotEscaped
