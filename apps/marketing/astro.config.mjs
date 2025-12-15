import { defineConfig } from "astro/config";
import partytown from "@astrojs/partytown";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import node from "@astrojs/node";
import { frontmanIntegration } from "@ask-the-llm/frontman-astro";

// https://astro.build/config
export default defineConfig({
  site: "https://foxi.netlify.app/",
  // Server mode with prerendering: pages are static by default (prerendered)
  // Only /__frontman/* routes are SSR (handled by middleware)
  output: "server",
  adapter: node({ mode: "standalone" }),
  integrations: [
    frontmanIntegration(),
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
