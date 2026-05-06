<?php
/**
 * Elementor data helpers used by Frontman Elementor tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Frontman_Elementor_Data {
    private const ROLLBACK_META_KEY = '_frontman_elementor_rollbacks';
    private const MAX_ROLLBACKS = 20;

    public static function post_uses_elementor( int $post_id ): bool {
        if ( 'builder' === get_post_meta( $post_id, '_elementor_edit_mode', true ) ) {
            return true;
        }

        return ! empty( get_post_meta( $post_id, '_elementor_data', true ) );
    }

    public static function get_page_data( int $post_id ): ?array {
        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->documents ) ) {
            $document = $plugin->documents->get( $post_id );
            if ( $document && method_exists( $document, 'get_elements_data' ) ) {
                $data = $document->get_elements_data();
                if ( is_array( $data ) && ! empty( $data ) ) {
                    return $data;
                }
            }
        }

        $raw = get_post_meta( $post_id, '_elementor_data', true );
        if ( empty( $raw ) ) {
            return null;
        }
        if ( is_array( $raw ) ) {
            return $raw;
        }
        if ( ! is_string( $raw ) ) {
            return null;
        }

        $decoded = json_decode( $raw, true );
        if ( is_array( $decoded ) ) {
            return $decoded;
        }
        if ( function_exists( 'wp_unslash' ) ) {
            $decoded = json_decode( wp_unslash( $raw ), true );
            if ( is_array( $decoded ) ) {
                return $decoded;
            }
        }

        return null;
    }

    public static function save_page_data( int $post_id, array $data ): bool {
        $post = get_post( $post_id );
        if ( ! $post ) {
            throw new \RuntimeException( 'Post not found: ' . esc_html( (string) $post_id ) );
        }

        update_post_meta( $post_id, '_elementor_edit_mode', 'builder' );
        update_post_meta( $post_id, '_elementor_template_type', self::template_type_for_post( $post ) );
        if ( 'page' === $post->post_type ) {
            update_post_meta( $post_id, '_wp_page_template', 'elementor_header_footer' );
        }

        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->documents ) ) {
            $document = $plugin->documents->get( $post_id );
            if ( $document && method_exists( $document, 'save' ) ) {
                $document->save( [ 'elements' => $data ] );
                self::flush_css( $post_id );
                return true;
            }
        }

        $json = wp_json_encode( $data );
        if ( ! is_string( $json ) || '' === $json ) {
            throw new \RuntimeException( 'Failed to encode Elementor data.' );
        }

        update_post_meta( $post_id, '_elementor_data', function_exists( 'wp_slash' ) ? wp_slash( $json ) : addslashes( $json ) );
        update_post_meta( $post_id, '_elementor_version', defined( 'ELEMENTOR_VERSION' ) ? ELEMENTOR_VERSION : 'unknown' );
        self::flush_css( $post_id );

        return true;
    }

    public static function get_page_structure( int $post_id ): ?array {
        $data = self::get_page_data( $post_id );
        return null === $data ? null : array_map( [ self::class, 'summarize_element' ], $data );
    }

    public static function get_element( array $elements, string $element_id ): ?array {
        foreach ( $elements as $element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                return $element;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
                $found = self::get_element( $element['elements'], $element_id );
                if ( null !== $found ) {
                    return $found;
                }
            }
        }

        return null;
    }

    public static function update_element_settings( array &$elements, string $element_id, array $settings ): bool {
        foreach ( $elements as &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                $current             = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
                $element['settings'] = array_merge( $current, $settings );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::update_element_settings( $element['elements'], $element_id, $settings ) ) {
                return true;
            }
        }

        return false;
    }

    public static function insert_element( array &$elements, array $new_element, ?string $parent_id, int $position = -1 ): bool {
        $new_element = self::normalize_element( $new_element );
        if ( null === $parent_id || '' === $parent_id ) {
            self::insert_at_position( $elements, $new_element, $position );
            return true;
        }

        foreach ( $elements as &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $parent_id ) {
                if ( ! self::element_can_contain_children( $element ) ) {
                    return false;
                }
                if ( ! isset( $element['elements'] ) || ! is_array( $element['elements'] ) ) {
                    $element['elements'] = [];
                }
                self::insert_at_position( $element['elements'], $new_element, $position );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::insert_element( $element['elements'], $new_element, $parent_id, $position ) ) {
                return true;
            }
        }

        return false;
    }

    public static function remove_element( array &$elements, string $element_id ): bool {
        foreach ( $elements as $index => &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                array_splice( $elements, $index, 1 );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::remove_element( $element['elements'], $element_id ) ) {
                return true;
            }
        }

        return false;
    }

    public static function duplicate_element( array &$elements, string $element_id ): ?string {
        foreach ( $elements as $index => &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                $clone = $element;
                self::reassign_ids( $clone );
                array_splice( $elements, $index + 1, 0, [ $clone ] );
                return (string) $clone['id'];
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
                $new_id = self::duplicate_element( $element['elements'], $element_id );
                if ( null !== $new_id ) {
                    return $new_id;
                }
            }
        }

        return null;
    }

    public static function move_element( array &$elements, string $element_id, ?string $parent_id, int $position = -1 ): bool {
        if ( null !== $parent_id && '' !== $parent_id && $parent_id === $element_id ) {
            return false;
        }

        $element = self::get_element( $elements, $element_id );
        if ( null === $element || ! self::remove_element( $elements, $element_id ) ) {
            return false;
        }

        return self::insert_element( $elements, $element, $parent_id, $position );
    }

    public static function make_element_rollback( string $action, array $elements, string $element_id ): ?array {
        $contexts = self::element_contexts( $elements, $element_id );
        if ( empty( $contexts ) ) {
            return null;
        }
        if ( count( $contexts ) > 1 ) {
            throw new Frontman_Tool_Error( 'Element ID is duplicated; refusing to create an ambiguous rollback: ' . esc_html( $element_id ) );
        }

        $context = $contexts[0];

        return [
            'rollback_id'        => self::generate_id(),
            'action'             => $action,
            'created_at'         => gmdate( 'c' ),
            'element_id'         => $element_id,
            'parent_id'          => $context['parent_id'],
            'parent_el_type'     => $context['parent_el_type'],
            'parent_widget_type' => $context['parent_widget_type'],
            'position'           => $context['position'],
            'element'            => $context['element'],
        ];
    }

    public static function make_page_rollback( string $action, array $data ): array {
        return [
            'rollback_id' => self::generate_id(),
            'action'      => $action,
            'created_at'  => gmdate( 'c' ),
            'sections'    => count( $data ),
            'data'        => $data,
        ];
    }

    public static function save_rollback( int $post_id, array $rollback ): array {
        $rollbacks = self::get_rollbacks( $post_id );
        array_unshift( $rollbacks, $rollback );
        $rollbacks = array_slice( $rollbacks, 0, self::MAX_ROLLBACKS );
        update_post_meta( $post_id, self::ROLLBACK_META_KEY, function_exists( 'wp_slash' ) ? wp_slash( $rollbacks ) : $rollbacks );

        $rollback_id = (string) ( $rollback['rollback_id'] ?? '' );
        if ( '' === $rollback_id || ! self::rollback_exists( self::get_rollbacks( $post_id ), $rollback_id ) ) {
            throw new Frontman_Tool_Error( 'Failed to persist Elementor rollback snapshot.' );
        }

        return $rollback;
    }

    public static function list_rollbacks( int $post_id ): array {
        return array_map( [ self::class, 'summarize_rollback' ], self::get_rollbacks( $post_id ) );
    }

    public static function restore_rollback( int $post_id, string $rollback_id ): ?array {
        $rollback = self::get_rollback( $post_id, $rollback_id );
        if ( null === $rollback ) {
            return null;
        }

        $action = (string) ( $rollback['action'] ?? '' );
        if ( isset( $rollback['data'] ) ) {
            $data = isset( $rollback['data'] ) && is_array( $rollback['data'] ) ? $rollback['data'] : null;
            if ( null === $data || ! self::is_element_list( $data ) ) {
                return [ 'success' => false, 'error' => 'Rollback does not contain valid page data.' ];
            }

            $before = self::get_page_data( $post_id );
            $undo   = is_array( $before ) ? self::save_rollback( $post_id, self::make_page_rollback( 'pre_restore_page_data', $before ) ) : null;
            try {
                self::save_page_data( $post_id, $data );
            } catch ( \Throwable $e ) {
                return [ 'success' => false, 'error' => 'Failed to restore page rollback: ' . $e->getMessage() ];
            }

            return [ 'success' => true, 'restored' => 'page_data', 'rollback_id' => $rollback_id, 'undo_rollback_id' => $undo['rollback_id'] ?? null ];
        }

        $element = isset( $rollback['element'] ) && is_array( $rollback['element'] ) ? $rollback['element'] : null;
        if ( null === $element || ! self::is_element( $element ) ) {
            return [ 'success' => false, 'error' => 'Rollback does not contain valid element data.' ];
        }

        $data       = self::get_page_data( $post_id ) ?? [];
        $before     = $data;
        $element_id = (string) ( $rollback['element_id'] ?? ( $element['id'] ?? '' ) );
        $matches    = self::element_contexts( $data, $element_id );
        $restored   = false;

        if ( 'removed' === $action ) {
            if ( ! empty( $matches ) ) {
                return [ 'success' => false, 'error' => 'Cannot restore removed element because an element with the same ID already exists.' ];
            }
            $parent_id = self::rollback_parent_id( $rollback );
            $position  = isset( $rollback['position'] ) ? (int) $rollback['position'] : -1;
            if ( ! self::can_insert_into_rollback_parent( $data, $parent_id, $rollback ) ) {
                return [ 'success' => false, 'error' => 'Cannot restore removed element because the original parent is missing or no longer accepts children.' ];
            }
            $restored = self::insert_element( $data, $element, $parent_id, $position );
        } else {
            if ( 0 === count( $matches ) ) {
                return [ 'success' => false, 'error' => 'Cannot restore element rollback because the target element no longer exists.' ];
            }
            if ( count( $matches ) > 1 ) {
                return [ 'success' => false, 'error' => 'Cannot restore element rollback because the target element ID is duplicated.' ];
            }
            if ( ! self::context_matches_rollback( $matches[0], $rollback ) ) {
                return [ 'success' => false, 'error' => 'Cannot restore element rollback because the target element moved since the rollback was created.' ];
            }
            $restored = self::replace_element_at_context( $data, $element_id, $matches[0]['parent_id'], (int) $matches[0]['position'], $element );
        }

        if ( ! $restored ) {
            return [ 'success' => false, 'error' => 'Unable to restore rollback because the original parent element was not found.' ];
        }

        $undo = self::save_rollback( $post_id, self::make_page_rollback( 'pre_restore_page_data', $before ) );
        try {
            self::save_page_data( $post_id, $data );
        } catch ( \Throwable $e ) {
            return [ 'success' => false, 'error' => 'Failed to restore element rollback: ' . $e->getMessage() ];
        }

        return [ 'success' => true, 'restored' => 'element', 'rollback_id' => $rollback_id, 'undo_rollback_id' => $undo['rollback_id'], 'element_id' => $element_id ];
    }

    public static function generate_id(): string {
        try {
            return substr( bin2hex( random_bytes( 4 ) ), 0, 8 );
        } catch ( \Throwable $e ) {
            return substr( md5( uniqid( '', true ) ), 0, 8 );
        }
    }

    public static function generate_element( array $input ): array {
        $type     = sanitize_key( $input['type'] ?? 'widget' );
        $settings = isset( $input['settings'] ) && is_array( $input['settings'] ) ? $input['settings'] : [];
        $children = isset( $input['children'] ) && is_array( $input['children'] ) ? $input['children'] : [];

        switch ( $type ) {
            case 'container':
                return self::container( $settings, $children, ! empty( $input['is_inner'] ) );
            case 'row':
                return self::container( array_merge( [ 'content_width' => 'full', 'flex_direction' => 'row', 'flex_wrap' => 'wrap' ], $settings ), $children, true );
            case 'column':
                $width = isset( $input['width'] ) ? (float) $input['width'] : 50.0;
                return self::container(
                    array_merge(
                        [
                            'content_width'  => 'full',
                            'width'          => [ 'size' => $width, 'unit' => '%' ],
                            'width_tablet'   => [ 'size' => 100, 'unit' => '%' ],
                            'flex_direction' => 'column',
                        ],
                        $settings
                    ),
                    $children,
                    true
                );
            case 'heading':
                return self::widget( 'heading', array_merge( [ 'title' => sanitize_text_field( $input['title'] ?? '' ), 'header_size' => sanitize_key( $input['tag'] ?? 'h2' ) ], $settings ) );
            case 'text':
                return self::widget( 'text-editor', array_merge( [ 'editor' => wp_kses_post( $input['content'] ?? '' ) ], $settings ) );
            case 'image':
                $attachment_id = absint( $input['attachment_id'] ?? 0 );
                return self::widget( 'image', array_merge( [ 'image' => [ 'id' => $attachment_id, 'url' => $attachment_id ? wp_get_attachment_url( $attachment_id ) : '', 'source' => 'library' ], 'image_size' => 'large' ], $settings ) );
            case 'button':
                return self::widget( 'button', array_merge( [ 'text' => sanitize_text_field( $input['button_text'] ?? 'Click' ), 'link' => [ 'url' => esc_url_raw( $input['url'] ?? '#' ) ] ], $settings ) );
            case 'widget':
                return self::widget( sanitize_key( $input['widget_type'] ?? 'heading' ), $settings );
            default:
                throw new \RuntimeException( 'Unsupported Elementor element generator type: ' . esc_html( $type ) );
        }
    }

    public static function list_widgets(): array {
        $plugin = self::elementor_plugin();
        if ( ! $plugin || ! isset( $plugin->widgets_manager ) ) {
            return [];
        }

        $result = [];
        foreach ( $plugin->widgets_manager->get_widget_types() as $name => $widget ) {
            $result[] = [
                'name'       => (string) $name,
                'title'      => method_exists( $widget, 'get_title' ) ? $widget->get_title() : (string) $name,
                'icon'       => method_exists( $widget, 'get_icon' ) ? $widget->get_icon() : '',
                'categories' => method_exists( $widget, 'get_categories' ) ? $widget->get_categories() : [],
            ];
        }

        return $result;
    }

    public static function get_widget_schema( string $widget_name ): ?array {
        $plugin = self::elementor_plugin();
        if ( ! $plugin || ! isset( $plugin->widgets_manager ) ) {
            return null;
        }

        $widget = $plugin->widgets_manager->get_widget_types( $widget_name );
        if ( ! $widget || ! method_exists( $widget, 'get_controls' ) ) {
            return null;
        }

        $schema = [];
        foreach ( $widget->get_controls() as $id => $control ) {
            $type = $control['type'] ?? 'unknown';
            if ( 0 === strpos( (string) $id, '_' ) || in_array( $type, [ 'section', 'tab' ], true ) ) {
                continue;
            }

            $schema[ $id ] = [
                'type'    => $type,
                'label'   => $control['label'] ?? $id,
                'default' => $control['default'] ?? null,
            ];
            if ( ! empty( $control['options'] ) ) {
                $schema[ $id ]['options'] = $control['options'];
            }
        }

        return $schema;
    }

    public static function flush_css( int $post_id = 0 ): void {
        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->files_manager ) && method_exists( $plugin->files_manager, 'clear_cache' ) ) {
            $plugin->files_manager->clear_cache();
        }

		if ( $post_id > 0 ) {
			delete_post_meta( $post_id, '_elementor_css' );
		}
	}

    private static function summarize_element( array $element ): array {
        $summary = [
            'id'     => (string) ( $element['id'] ?? '' ),
            'elType' => (string) ( $element['elType'] ?? '' ),
        ];
        if ( ! empty( $element['widgetType'] ) ) {
            $summary['widgetType'] = (string) $element['widgetType'];
        }
        if ( ! empty( $element['isInner'] ) ) {
            $summary['isInner'] = true;
        }
        $settings = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
        $hint     = [];
        foreach ( [ 'title', 'editor', 'text', 'button_text', 'content_width', 'flex_direction' ] as $key ) {
            if ( empty( $settings[ $key ] ) || is_array( $settings[ $key ] ) ) {
                continue;
            }
            $value        = wp_strip_all_tags( (string) $settings[ $key ] );
            $hint[ $key ] = function_exists( 'mb_substr' ) ? mb_substr( $value, 0, 80 ) : substr( $value, 0, 80 );
        }
        if ( ! empty( $hint ) ) {
            $summary['hint'] = $hint;
        }
        if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
            $summary['children'] = array_map( [ self::class, 'summarize_element' ], $element['elements'] );
        }

        return $summary;
    }

    private static function summarize_rollback( array $rollback ): array {
        $summary = [
            'rollback_id' => (string) ( $rollback['rollback_id'] ?? '' ),
            'action'      => (string) ( $rollback['action'] ?? '' ),
            'created_at'  => (string) ( $rollback['created_at'] ?? '' ),
        ];

        if ( isset( $rollback['element_id'] ) ) {
            $summary['element_id'] = (string) $rollback['element_id'];
        }
        if ( array_key_exists( 'parent_id', $rollback ) ) {
            $summary['parent_id'] = $rollback['parent_id'];
        }
        if ( isset( $rollback['position'] ) ) {
            $summary['position'] = (int) $rollback['position'];
        }
        if ( isset( $rollback['sections'] ) ) {
            $summary['sections'] = (int) $rollback['sections'];
        }
        if ( isset( $rollback['element'] ) && is_array( $rollback['element'] ) ) {
            $summary['summary'] = self::summarize_element_metadata( $rollback['element'] );
        }
        if ( isset( $rollback['data'] ) && is_array( $rollback['data'] ) ) {
            $summary['summary'] = array_map( [ self::class, 'summarize_element_metadata' ], array_values( array_filter( $rollback['data'], 'is_array' ) ) );
        }

        return $summary;
    }

    private static function summarize_element_metadata( array $element ): array {
        $summary = [
            'id'          => (string) ( $element['id'] ?? '' ),
            'elType'      => (string) ( $element['elType'] ?? '' ),
            'child_count' => isset( $element['elements'] ) && is_array( $element['elements'] ) ? count( $element['elements'] ) : 0,
        ];
        if ( ! empty( $element['widgetType'] ) ) {
            $summary['widgetType'] = (string) $element['widgetType'];
        }

        return $summary;
    }

    private static function get_rollbacks( int $post_id ): array {
        $rollbacks = get_post_meta( $post_id, self::ROLLBACK_META_KEY, true );
        if ( is_string( $rollbacks ) ) {
            $decoded = json_decode( $rollbacks, true );
            $rollbacks = is_array( $decoded ) ? $decoded : [];
        }

        return is_array( $rollbacks ) ? array_values( array_filter( $rollbacks, 'is_array' ) ) : [];
    }

    private static function get_rollback( int $post_id, string $rollback_id ): ?array {
        foreach ( self::get_rollbacks( $post_id ) as $rollback ) {
            if ( $rollback_id === (string) ( $rollback['rollback_id'] ?? '' ) ) {
                return $rollback;
            }
        }

        return null;
    }

    private static function rollback_exists( array $rollbacks, string $rollback_id ): bool {
        foreach ( $rollbacks as $rollback ) {
            if ( $rollback_id === (string) ( $rollback['rollback_id'] ?? '' ) ) {
                return true;
            }
        }

        return false;
    }

    private static function is_element_list( array $elements ): bool {
        foreach ( $elements as $element ) {
            if ( ! is_array( $element ) || ! self::is_element( $element ) ) {
                return false;
            }
        }

        return true;
    }

    private static function is_element( array $element ): bool {
        if ( isset( $element['settings'] ) && ! is_array( $element['settings'] ) ) {
            return false;
        }
        if ( isset( $element['elements'] ) ) {
            if ( ! is_array( $element['elements'] ) ) {
                return false;
            }

            return self::is_element_list( $element['elements'] );
        }

        return true;
    }

    private static function element_contexts( array $elements, string $element_id, ?string $parent_id = null, ?array $parent = null ): array {
        $matches = [];
        foreach ( $elements as $index => $element ) {
            if ( ! is_array( $element ) ) {
                continue;
            }
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                $matches[] = [
                    'element'            => $element,
                    'parent_id'          => $parent_id,
                    'parent_el_type'     => is_array( $parent ) ? (string) ( $parent['elType'] ?? '' ) : null,
                    'parent_widget_type' => is_array( $parent ) ? (string) ( $parent['widgetType'] ?? '' ) : null,
                    'position'           => $index,
                ];
            }

            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
                $matches = array_merge( $matches, self::element_contexts( $element['elements'], $element_id, (string) ( $element['id'] ?? '' ), $element ) );
            }
        }

        return $matches;
    }

    private static function rollback_parent_id( array $rollback ): ?string {
        if ( ! array_key_exists( 'parent_id', $rollback ) || null === $rollback['parent_id'] || '' === $rollback['parent_id'] ) {
            return null;
        }

        return (string) $rollback['parent_id'];
    }

    private static function can_insert_into_rollback_parent( array $elements, ?string $parent_id, array $rollback ): bool {
        if ( null === $parent_id ) {
            return true;
        }

        $matches = self::element_contexts( $elements, $parent_id );
        if ( 1 !== count( $matches ) ) {
            return false;
        }

        $parent = $matches[0]['element'];
        if ( ! self::element_can_contain_children( $parent ) ) {
            return false;
        }

        $el_type = (string) ( $parent['elType'] ?? '' );
        $rollback_parent_type = (string) ( $rollback['parent_el_type'] ?? '' );
        return '' === $rollback_parent_type || $rollback_parent_type === $el_type;
    }

    private static function element_can_contain_children( array $element ): bool {
        return in_array( (string) ( $element['elType'] ?? '' ), [ 'container', 'section', 'column' ], true );
    }

    private static function context_matches_rollback( array $context, array $rollback ): bool {
        $parent_id = self::rollback_parent_id( $rollback );
        return $parent_id === $context['parent_id'] && (int) ( $rollback['position'] ?? -1 ) === (int) $context['position'];
    }

    private static function replace_element_at_context( array &$elements, string $element_id, ?string $parent_id, int $position, array $replacement ): bool {
        if ( null === $parent_id ) {
            if ( isset( $elements[ $position ] ) && (string) ( $elements[ $position ]['id'] ?? '' ) === $element_id ) {
                $elements[ $position ] = $replacement;
                return true;
            }

            return false;
        }

        foreach ( $elements as &$element ) {
            if ( ! is_array( $element ) ) {
                continue;
            }
            if ( (string) ( $element['id'] ?? '' ) === $parent_id ) {
                if ( isset( $element['elements'][ $position ] ) && (string) ( $element['elements'][ $position ]['id'] ?? '' ) === $element_id ) {
                    $element['elements'][ $position ] = $replacement;
                    return true;
                }

                return false;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::replace_element_at_context( $element['elements'], $element_id, $parent_id, $position, $replacement ) ) {
                return true;
            }
        }

        return false;
    }

    private static function container( array $settings = [], array $children = [], bool $is_inner = false ): array {
        return [
            'id'       => self::generate_id(),
            'elType'   => 'container',
            'isInner'  => $is_inner,
            'settings' => array_merge( [ 'content_width' => 'boxed', 'flex_direction' => 'column' ], $settings ),
            'elements' => array_values( $children ),
        ];
    }

    private static function widget( string $widget_type, array $settings = [] ): array {
        return [
            'id'         => self::generate_id(),
            'elType'     => 'widget',
            'widgetType' => $widget_type,
            'settings'   => $settings,
            'elements'   => [],
        ];
    }

    private static function normalize_element( array $element ): array {
        if ( empty( $element['id'] ) ) {
            $element['id'] = self::generate_id();
        }
        if ( ! isset( $element['elements'] ) || ! is_array( $element['elements'] ) ) {
            $element['elements'] = [];
        }
        if ( ! isset( $element['settings'] ) || ! is_array( $element['settings'] ) ) {
            $element['settings'] = [];
        }

        return $element;
    }

    private static function insert_at_position( array &$elements, array $element, int $position ): void {
        if ( $position < 0 || $position >= count( $elements ) ) {
            $elements[] = $element;
            return;
        }

        array_splice( $elements, $position, 0, [ $element ] );
    }

    private static function reassign_ids( array &$element ): void {
        $element['id'] = self::generate_id();
        if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
            foreach ( $element['elements'] as &$child ) {
                self::reassign_ids( $child );
            }
        }
    }

    private static function template_type_for_post( \WP_Post $post ): string {
        if ( 'page' === $post->post_type ) {
            return 'wp-page';
        }

        $existing = get_post_meta( $post->ID, '_elementor_template_type', true );
        return is_string( $existing ) && '' !== $existing ? $existing : $post->post_type;
    }

    private static function elementor_plugin() {
        if ( ! class_exists( '\Elementor\Plugin' ) ) {
            return null;
        }

        return \Elementor\Plugin::$instance;
    }
}
