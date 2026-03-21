import { defineConfig } from "astro/config";
import partytown from "@astrojs/partytown";
import tailwind from "@astrojs/tailwind";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import frontman from "@frontman-ai/astro";
import path from "node:path";
import fs from "node:fs";

const appRoot = path.resolve(import.meta.dirname);

// Build slug -> pubDate maps from content markdown files so the sitemap can
// use real publication dates instead of a blanket "build date" for every URL.
function buildDateMap(dir) {
  const map = new Map();
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".md"))) {
    const raw = fs.readFileSync(path.join(dir, file), "utf-8");
    const match = raw.match(/^pubDate:\s*(.+)$/m);
    if (match) {
      const slug = file.replace(/\.md$/, "");
      map.set(slug, new Date(match[1].trim()));
    }
  }
  return map;
}

const blogDateMap = buildDateMap(path.resolve(appRoot, "src/content/blog"));
const glossaryDateMap = buildDateMap(path.resolve(appRoot, "src/content/glossary"));
const lighthouseDateMap = buildDateMap(path.resolve(appRoot, "src/content/lighthouse"));
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
    }),
    tailwind(),
    icon(),
    sitemap({
      filter: (page) =>
        // Exclude empty placeholder pages and internal-only pages
        !page.includes("/pricing") &&
        !page.includes("/design-system") &&
        !page.includes("/contact"),
      serialize: (item) => {
        // Use the real pubDate for blog and lighthouse posts; fall back to
        // build date for everything else.
        const blogMatch = item.url.match(/\/blog\/([^/]+)\/?$/);
        const glossaryMatch = item.url.match(/\/glossary\/([^/]+)\/?$/);
        const lighthouseMatch = item.url.match(/\/lighthouse\/([^/]+)\/?$/);
        if (blogMatch && blogDateMap.has(blogMatch[1])) {
          item.lastmod = blogDateMap.get(blogMatch[1]);
        } else if (glossaryMatch && glossaryDateMap.has(glossaryMatch[1])) {
          item.lastmod = glossaryDateMap.get(glossaryMatch[1]);
        } else if (lighthouseMatch && lighthouseDateMap.has(lighthouseMatch[1])) {
          item.lastmod = lighthouseDateMap.get(lighthouseMatch[1]);
        } else {
          item.lastmod = new Date();
        }
        return item;
      },
      // Split sitemap into content-grouped child sitemaps instead of a
      // single flat sitemap-0.xml. URLs that don't match any chunk land
      // in the default sitemap-pages-0.xml.
      chunks: {
        posts: (item) => {
          if (/\/blog\/(?!tags\/)/.test(item.url)) return item;
        },
        tags: (item) => {
          if (/\/blog\/tags\//.test(item.url)) return item;
        },
        glossary: (item) => {
          if (/\/glossary\//.test(item.url)) return item;
        },
        lighthouse: (item) => {
          if (/\/lighthouse\//.test(item.url)) return item;
        },
        comparisons: (item) => {
          if (/\/vs\//.test(item.url)) return item;
        },
        integrations: (item) => {
          if (/\/integrations\//.test(item.url)) return item;
        },
      },
    }),
    partytown({
      config: {
        forward: ["dataLayer.push"],
      },
    }),
  ],
});
