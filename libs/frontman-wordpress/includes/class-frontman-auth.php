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
	private static ?string $cookie_failure = null;
	private static bool $diagnostic_logged = false;

	public static function register(): void {
		foreach ( [
			'auth_cookie_malformed' => 'malformed',
			'auth_cookie_expired' => 'expired',
			'auth_cookie_bad_username' => 'bad_username',
			'auth_cookie_bad_hash' => 'bad_hash',
			'auth_cookie_bad_session_token' => 'bad_session',
		] as $hook => $category ) {
			add_action( $hook, static function () use ( $category ): void {
				if ( 'malformed' !== $category || null === self::$cookie_failure ) {
					self::$cookie_failure = $category;
				}
			}, 10, 0 );
		}
	}

	private static function log_auth_rejection(): void {
		if ( self::$diagnostic_logged || ! Frontman_Sentry::sanitize_enabled( get_option( 'frontman_php_diagnostics', false ) ) ) {
			return;
		}

		$has_cookie = defined( 'LOGGED_IN_COOKIE' ) && isset( $_COOKIE[ LOGGED_IN_COOKIE ] );
		$category = $has_cookie ? ( self::$cookie_failure ?? 'no_native_reason' ) : 'absent_cookie';
		self::$diagnostic_logged = true;
		error_log( 'Frontman auth diagnostics: ' . wp_json_encode( [
			'category' => $category,
			'wordpress_version' => get_bloginfo( 'version' ),
			'php_version' => PHP_VERSION,
			'plugin_version' => FRONTMAN_VERSION,
		] ) );
	}

	/**
	 * Check if the current request is authorized.
	 *
	 * Must be called after WordPress has loaded cookies and determined the
	 * current user (i.e. after 'init' or later).
	 *
	 * @return true|\WP_Error True if authorized, WP_Error with status code on failure.
	 */
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

	/**
	 * Create a nonce for authenticated Frontman browser requests.
	 */
	public static function create_nonce(): string {
		return wp_create_nonce( self::NONCE_ACTION );
	}

	/**
	 * Get the nonce action shared by UI generation and request validation.
	 */
	public static function nonce_action(): string {
		return self::NONCE_ACTION;
	}

	/**
	 * Read the browser nonce from the X-WP-Nonce request header.
	 */
	public static function request_nonce(): string {
		if ( ! isset( $_SERVER['HTTP_X_WP_NONCE'] ) ) {
			return '';
		}

		return sanitize_text_field( wp_unslash( $_SERVER['HTTP_X_WP_NONCE'] ) );
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
		$error_data = $error->get_error_data();
		$status     = is_array( $error_data ) && isset( $error_data['status'] ) ? (int) $error_data['status'] : 403;

		if ( $is_api ) {
			nocache_headers();
			$code = $error->get_error_code();
			if ( 'frontman_not_authenticated' === $code && 401 === $status ) {
				self::log_auth_rejection();
			}
			if ( in_array( $code, [ 'frontman_missing_nonce', 'frontman_invalid_nonce' ], true ) && true === self::check() ) {
				header( 'X-WP-Nonce: ' . self::create_nonce() );
			}
			wp_send_json( [ 'code' => $code, 'error' => $error->get_error_message() ], $status );
			return;
		}

		$redirect_url = Frontman_UI::url( '/frontman' );
		wp_safe_redirect( wp_login_url( $redirect_url ) );
		exit;
	}
}
