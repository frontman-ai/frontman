<?php
/**
 * Settings — admin settings page for Frontman configuration.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Frontman_Settings {
	private const OPTION_KEY = 'frontman_settings';

	private const DEFAULTS = [
		'openrouter_api_key' => '',
		'anthropic_api_key'  => '',
	];

	/**
	 * Register settings fields (admin_init only).
	 *
	 * The admin menu entry is registered separately via register_menu()
	 * to ensure the parent "Frontman" menu page exists first.
	 */
	public function register(): void {
		add_action( 'admin_init', [ $this, 'register_settings' ] );
	}

	/**
	 * Register the submenu page under admin_menu.
	 *
	 * Must be called AFTER the parent "frontman" menu page is registered
	 * by Frontman_UI::register(), otherwise WordPress can't resolve the
	 * parent slug and the page returns "not allowed".
	 */
	public function register_menu(): void {
		add_action( 'admin_menu', [ $this, 'add_settings_page' ], 20 );
	}

	/**
	 * Register WordPress settings.
	 */
	public function register_settings(): void {
		register_setting( 'frontman_settings_group', self::OPTION_KEY, [
			'type'              => 'array',
			'sanitize_callback' => [ $this, 'sanitize' ],
			'default'           => self::DEFAULTS,
		] );

		// --- API Keys section ---
		add_settings_section(
			'frontman_api_keys_section',
			__( 'API Keys', 'frontman-agentic-ai-editor' ),
			function() {
				printf(
					'<p>%s</p>',
					esc_html__( 'Provide your own LLM API keys. These are passed to the Frontman server so the AI agent can use your key for requests.', 'frontman-agentic-ai-editor' )
				);
			},
			'frontman-settings'
		);

		add_settings_field(
			'openrouter_api_key',
			__( 'OpenRouter API Key', 'frontman-agentic-ai-editor' ),
			[ $this, 'render_password_field' ],
			'frontman-settings',
			'frontman_api_keys_section',
			[ 'key' => 'openrouter_api_key', 'placeholder' => 'sk-or-v1-...' ],
		);

		add_settings_field(
			'anthropic_api_key',
			__( 'Anthropic API Key', 'frontman-agentic-ai-editor' ),
			[ $this, 'render_password_field' ],
			'frontman-settings',
			'frontman_api_keys_section',
			[ 'key' => 'anthropic_api_key', 'placeholder' => 'sk-ant-...' ],
		);
	}

	/**
	 * Add sub-menu settings page under the Frontman menu.
	 */
	public function add_settings_page(): void {
		add_submenu_page(
			'frontman',
			__( 'Frontman Settings', 'frontman-agentic-ai-editor' ),
			__( 'Settings', 'frontman-agentic-ai-editor' ),
			'manage_options',
			'frontman-settings',
			[ $this, 'render_page' ],
		);
	}

	/**
	 * Render settings page.
	 */
	public function render_page(): void {
		?>
		<div class="wrap frontman-admin-page">
			<div class="frontman-admin-hero">
				<div class="frontman-admin-brand">
					<div class="frontman-admin-logo-wrap">
						<img class="frontman-admin-logo" src="<?php echo esc_url( FRONTMAN_PLUGIN_URL . 'assets/frontman-logo.svg' ); ?>" alt="<?php esc_attr_e( 'Frontman logo', 'frontman-agentic-ai-editor' ); ?>">
					</div>
					<div class="frontman-admin-copy">
						<p class="frontman-admin-eyebrow"><?php esc_html_e( 'Frontman for WordPress', 'frontman-agentic-ai-editor' ); ?></p>
						<h1><?php esc_html_e( 'Frontman Settings', 'frontman-agentic-ai-editor' ); ?></h1>
						<p><?php esc_html_e( 'Configure API keys, then launch Frontman from the WordPress sidebar.', 'frontman-agentic-ai-editor' ); ?></p>
					</div>
				</div>
				<div class="frontman-admin-actions">
					<a class="button button-primary" href="<?php echo esc_url( home_url( '/frontman' ) ); ?>"><?php esc_html_e( 'Open Frontman', 'frontman-agentic-ai-editor' ); ?></a>
				</div>
			</div>
			<div class="frontman-admin-card">
				<form method="post" action="options.php">
					<?php
					settings_fields( 'frontman_settings_group' );
					do_settings_sections( 'frontman-settings' );
					submit_button();
					?>
				</form>
			</div>
		</div>
		<?php
	}

	/**
	 * Render a text input field.
	 */
	public function render_text_field( array $args ): void {
		$key         = $args['key'];
		$value       = $this->get( $key );
		$placeholder = $args['placeholder'] ?? '';
		$type        = $args['type'] ?? 'text';
		$name        = self::OPTION_KEY . "[{$key}]";

		printf(
			'<input type="%s" name="%s" value="%s" placeholder="%s" class="regular-text">',
			esc_attr( $type ),
			esc_attr( $name ),
			esc_attr( $value ),
			esc_attr( $placeholder ),
		);
	}

	/**
	 * Render a password input field.
	 */
	public function render_password_field( array $args ): void {
		$key         = $args['key'];
		$value       = $this->get( $key );
		$placeholder = $args['placeholder'] ?? '';
		$name        = self::OPTION_KEY . "[{$key}]";

		printf(
			'<input type="password" name="%s" value="%s" placeholder="%s" class="regular-text" autocomplete="off">',
			esc_attr( $name ),
			esc_attr( $value ),
			esc_attr( $placeholder ),
		);
	}

	/**
	 * Render a checkbox input field.
	 */
	public function render_checkbox_field( array $args ): void {
		$key   = $args['key'];
		$value = (bool) $this->get( $key );
		$label = $args['label'] ?? '';
		$name  = self::OPTION_KEY . "[{$key}]";

		printf(
			'<label><input type="checkbox" name="%s" value="1" %s /> %s</label>',
			esc_attr( $name ),
			checked( $value, true, false ),
			esc_html( $label ),
		);
	}

	/**
	 * Sanitize settings on save.
	 */
	public function sanitize( array $input ): array {
		return [
			'openrouter_api_key' => sanitize_text_field( $input['openrouter_api_key'] ?? '' ),
			'anthropic_api_key'  => sanitize_text_field( $input['anthropic_api_key'] ?? '' ),
		];
	}

	/**
	 * Get a setting value.
	 */
	public function get( $key, $default = null ) {
		$settings = get_option( self::OPTION_KEY, self::DEFAULTS );
		return $settings[ $key ] ?? $default ?? self::DEFAULTS[ $key ] ?? null;
	}
}
