import type { AstroIntegration } from "astro";

export interface FrontmanConfig {
  /**
   * Path to the project root directory.
   * @default process.env.PROJECT_ROOT || process.env.PWD || "."
   */
  projectRoot?: string;

  /**
   * Root for resolving source file paths from Astro's `data-astro-source-file` attributes.
   * In a monorepo, this is typically the monorepo root.
   * @default projectRoot
   */
  sourceRoot?: string;

  /**
   * URL prefix for Frontman routes (UI and API endpoints).
   * @default "frontman"
   */
  basePath?: string;

  /**
   * Server name included in tool responses.
   * @default "frontman-astro"
   */
  serverName?: string;

  /**
   * Server version included in tool responses.
   * @default "1.0.0"
   */
  serverVersion?: string;

  /**
   * Frontman server host for client connections.
   * Can also be set via the `FRONTMAN_HOST` environment variable.
   * @default "api.frontman.sh"
   */
  host?: string;

  /**
   * URL to the Frontman client bundle. Override for custom client builds.
   * Must include a `host` query parameter.
   * @default "https://app.frontman.sh/frontman.es.js" in production, dev server URL in development
   */
  clientUrl?: string;

  /**
   * URL to the Frontman client CSS stylesheet.
   * @default "https://app.frontman.sh/frontman.css" in production, omitted in development
   */
  clientCssUrl?: string;

  /**
   * Use a light theme for the Frontman UI.
   * @default false
   */
  isLightTheme?: boolean;
}

/**
 * Astro integration for Frontman — AI-powered development tools.
 *
 * @example
 * ```js
 * import { defineConfig } from 'astro/config';
 * import frontman from '@frontman-ai/astro';
 *
 * export default defineConfig({
 *   integrations: [frontman({ projectRoot: import.meta.dirname })],
 * });
 * ```
 */
export default function frontman(config?: FrontmanConfig): AstroIntegration;

/**
 * Named export of the integration factory.
 * Alias for the default export.
 */
export { frontman as frontmanIntegration };
