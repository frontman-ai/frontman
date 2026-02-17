import { defineConfig } from "astro/config";
import partytown from "@astrojs/partytown";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import frontman from "@frontman-ai/astro";
import path from "node:path";

const appRoot = path.resolve(import.meta.dirname);
const monorepoRoot = path.resolve(appRoot, "../..");

// https://astro.build/config
export default defineConfig({
  site: "https://frontman.sh",
  build: {
    // Inline all stylesheets directly into the HTML to eliminate
    // render-blocking <link> requests (~25 KiB total). Trades a small
    // increase in HTML size for removing 4 blocking CSS round-trips (~430 ms).
    inlineStylesheets: "always",
  },
  integrations: [
    frontman({
      projectRoot: appRoot,
      sourceRoot: monorepoRoot,
      basePath: "frontman",
      serverName: "marketing",
      serverVersion: "1.0.0",
    }),
    tailwind(),
    icon(),
    sitemap(),
    partytown({
      config: {
        forward: ["dataLayer.push"],
      },
    }),
  ],
});
