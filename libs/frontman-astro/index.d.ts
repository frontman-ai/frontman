import type { AstroIntegration } from "astro";

export interface FrontmanConfig {
  projectRoot?: string;

  sourceRoot?: string;

  basePath?: string;

  serverName?: string;

  serverVersion?: string;

  host?: string;

  clientUrl?: string;

  clientCssUrl?: string;

}

export default function frontman(config?: FrontmanConfig): AstroIntegration;

export { frontman as frontmanIntegration };
