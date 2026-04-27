<?php
/**
 * Auth — centralized cookie-based authentication for Frontman routes.
 *
 * Every request to /frontman/* is verified here before any handler runs.
 * Uses WordPress cookie auth — the same mechanism that protects wp-admin.
 *
 * Security model:
 * - User must be logged in (WordPress auth cookie present + valid)
 * - User must have manage_options capability (administrator)
 * - Returns 401 for unauthenticated, 403 for insufficient permissions
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Auth {
	private const NONCE_ACTION = 'frontman_request';

	/**
	 * Check if the current request is authorized.
	 *
	 * Must be called after WordPress has loaded cookies and determined the
	 * current user (i.e. after 'init' or later).
	 *
	 * @return true|\WP_Error True if authorized, WP_Error with status code on failure.
	 */
	public static function check() {
		// Ensure current user is loaded from cookies (needed when called early in parse_request).
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

	/**
	 * Create a nonce for authenticated Frontman browser requests.
	 */
	public static function create_nonce(): string {
		return wp_create_nonce( self::NONCE_ACTION );
	}

	/**
	 * Verify the request nonce sent by the browser client.
	 *
	 * @return true|\WP_Error
	 */
	public static function verify_nonce() {
		$nonce = '';

		if ( isset( $_SERVER['HTTP_X_WP_NONCE'] ) ) {
			$nonce = sanitize_text_field( wp_unslash( $_SERVER['HTTP_X_WP_NONCE'] ) );
		}

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

	/**
	 * Send an error response and exit.
	 *
	 * Handles both JSON API errors and HTML redirects depending on context.
	 *
	 * @param \WP_Error $error   The auth error.
	 * @param bool      $is_api  Whether this is an API request (JSON) or page request (redirect).
	 */
	public static function send_error( \WP_Error $error, bool $is_api = true ): void {
		$status = $error->get_error_data()['status'] ?? 403;

		if ( $is_api ) {
			status_header( $status );
			header( 'Content-Type: application/json; charset=utf-8' );
			echo wp_json_encode( [ 'error' => $error->get_error_message() ] );
			exit;
		}

		// For page requests (the UI), redirect to login.
		$redirect_url = home_url( '/frontman' );
		wp_safe_redirect( wp_login_url( $redirect_url ) );
		exit;
	}
}
