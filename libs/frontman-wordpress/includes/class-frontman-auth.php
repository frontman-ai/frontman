<?php

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Auth {
	private const NONCE_ACTION = 'frontman_request';

	public static function check() {
		if ( ! did_action( 'set_current_user' ) ) {
			wp_get_current_user();
		}

		if ( ! is_user_logged_in() ) {
			return new \WP_Error(
				'frontman_not_authenticated',
				__( 'Authentication required. Please log in to WordPress.', 'frontman-agentic-ai-editor' ),
				[ 'status' => 401 ],
			);
		}

		if ( ! current_user_can( 'manage_options' ) ) {
			return new \WP_Error(
				'frontman_forbidden',
				__( 'Insufficient permissions. Administrator access required.', 'frontman-agentic-ai-editor' ),
				[ 'status' => 403 ],
			);
		}

		return true;
	}

	public static function create_nonce(): string {
		return wp_create_nonce( self::NONCE_ACTION );
	}

	public static function nonce_action(): string {
		return self::NONCE_ACTION;
	}

	public static function request_nonce(): string {
		if ( ! isset( $_SERVER['HTTP_X_WP_NONCE'] ) ) {
			return '';
		}

		return sanitize_text_field( wp_unslash( $_SERVER['HTTP_X_WP_NONCE'] ) );
	}

	public static function verify_nonce() {
		$nonce = self::request_nonce();

		if ( empty( $nonce ) ) {
			return new \WP_Error(
				'frontman_missing_nonce',
				__( 'Missing request nonce.', 'frontman-agentic-ai-editor' ),
				[ 'status' => 403 ],
			);
		}

		if ( ! wp_verify_nonce( $nonce, self::NONCE_ACTION ) ) {
			return new \WP_Error(
				'frontman_invalid_nonce',
				__( 'Invalid request nonce.', 'frontman-agentic-ai-editor' ),
				[ 'status' => 403 ],
			);
		}

		return true;
	}

	public static function send_error( \WP_Error $error, bool $is_api = true ): void {
		$error_data = $error->get_error_data();
		$status     = is_array( $error_data ) && isset( $error_data['status'] ) ? (int) $error_data['status'] : 403;

		if ( $is_api ) {
			wp_send_json( [ 'error' => $error->get_error_message() ], $status );
			return;
		}

		$redirect_url = home_url( '/frontman' );
		wp_safe_redirect( wp_login_url( $redirect_url ) );
		exit;
	}
}
