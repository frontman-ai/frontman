import { defineConfig } from "astro/config";
import partytown from "@astrojs/partytown";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import node from "@astrojs/node";
import { make as frontmanIntegration } from "@frontman/frontman-astro/integration";

const isProd = process.env.NODE_ENV === "production";

// https://astro.build/config
export default defineConfig({
  site: "https://frontman.sh",
  // SSR only needed in dev for /frontman/* routes
  ...(isProd ? {} : { output: "server", adapter: node({ mode: "standalone" }) }),
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
