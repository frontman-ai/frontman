import { defineConfig } from "astro/config";
import partytown from "@astrojs/partytown";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import frontman from "@frontman-ai/astro";
import path from "node:path";
import fs from "node:fs";

const appRoot = path.resolve(import.meta.dirname);

// Build a slug -> pubDate map from blog markdown files so the sitemap can
// use real publication dates instead of a blanket "build date" for every URL.
const blogDir = path.resolve(appRoot, "src/content/blog");
const blogDateMap = new Map();
for (const file of fs.readdirSync(blogDir).filter((f) => f.endsWith(".md"))) {
  const raw = fs.readFileSync(path.join(blogDir, file), "utf-8");
  const match = raw.match(/^pubDate:\s*(.+)$/m);
  if (match) {
    const slug = file.replace(/\.md$/, "");
    blogDateMap.set(slug, new Date(match[1].trim()));
  }
}
const monorepoRoot = path.resolve(appRoot, "../..");

// https://astro.build/config
export default defineConfig({
  site: "https://frontman.sh",
  trailingSlash: "always",
  vite: {
    server: {
      allowedHosts: [".frontman.local"],
    },
  },
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
    sitemap({
      filter: (page) =>
        // Exclude empty placeholder pages, internal-only pages, and glossary
        // (glossary is also Disallow-ed in robots.txt)
        !page.includes("/features") &&
        !page.includes("/pricing") &&
        !page.includes("/design-system") &&
        !page.includes("/contact") &&
        !page.includes("/glossary"),
      serialize: (item) => {
        // Use the real pubDate for blog posts; fall back to build date for
        // everything else.
        const blogMatch = item.url.match(/\/blog\/([^/]+)\/?$/);
        if (blogMatch && blogDateMap.has(blogMatch[1])) {
          item.lastmod = blogDateMap.get(blogMatch[1]);
        } else {
          item.lastmod = new Date();
        }
        return item;
      },
    }),
    partytown({
      config: {
        forward: ["dataLayer.push"],
      },
    }),
  ],
});
