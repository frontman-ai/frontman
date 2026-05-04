import { defineConfig } from "astro/config"; // force rebuild // force rebuild
import tailwindcss from "@tailwindcss/vite";
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import frontman from "@frontman-ai/astro";
import brokenLinksChecker from "astro-broken-links-checker";
import astroConsent from "astro-consent";
import path from "node:path";
import fs from "node:fs";
import hcStarlight from 'hc-starlight';
import starlight from "@astrojs/starlight";

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
const releasesDateMap = buildDateMap(path.resolve(appRoot, "src/content/releases"));
const monorepoRoot = path.resolve(appRoot, "../..");

// Validate that all docs pages have a description in their frontmatter.
// Runs at build start so missing descriptions fail fast instead of silently
// producing pages with empty meta tags.
function stripMarketingConsentCategory() {
  return {
    name: "strip-marketing-consent-category",
    hooks: {
      "astro:config:setup": ({ injectScript }) => {
        injectScript("page", `
(() => {
  const consent = window.astroConsent;
  if (!consent) return;

  const originalSet = consent.set;
  consent.set = (categories) => {
    const { marketing, ...allowedCategories } = categories;
    originalSet(allowedCategories);
  };
})();
`);
      },
    },
  };
}

function validateDocsDescriptions() {
  const docsRoot = path.resolve(appRoot, "src/content/docs");

  function walkDir(dir) {
    const files = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        files.push(...walkDir(full));
      } else if (
        entry.isFile() &&
        (entry.name.endsWith(".md") || entry.name.endsWith(".mdx")) &&
        !entry.name.startsWith("_")
      ) {
        files.push(full);
      }
    }
    return files;
  }

  const missing = [];
  for (const file of walkDir(docsRoot)) {
    const raw = fs.readFileSync(file, "utf-8");
    const fmMatch = raw.match(/^---\n([\s\S]*?)\n---/);
    if (!fmMatch) {
      missing.push({ file, reason: "no frontmatter" });
      continue;
    }
    const descMatch = fmMatch[1].match(/^description:\s*(.+)$/m);
    if (!descMatch || !descMatch[1].trim()) {
      missing.push({ file, reason: "missing description" });
    }
  }

  if (missing.length > 0) {
    const details = missing
      .map((m) => `  - ${path.relative(appRoot, m.file)} (${m.reason})`)
      .join("\n");
    throw new Error(
      `[SEO] The following docs pages are missing a description in their frontmatter:\n${details}\n\n` +
        `Every docs page needs a description for SEO meta tags. Add one to the frontmatter:\n` +
        `---\ntitle: My Page\ndescription: A short summary of this page for search engines.\n---`
    );
  }

  return { name: "validate-docs-descriptions", hooks: { "astro:config:done": () => {} } };
}

// https://astro.build/config
export default defineConfig({
  site: "https://frontman.sh",
  trailingSlash: "always",
  redirects: {
    "/blog/gpt-5.4-support": "/blog/gpt-54-support/",
    "/blog/mobile-app": "/blog/ai-coding-agents-blind-to-ui/",
    "/blog/user-stories": "/blog/frontman-vs-cursor-vs-claude-code/",
    "/blog/welcome": "/blog/introducing-frontman/",
    "/blog/what-are-framework-aware-ai-coding-tools": "/blog/what-are-browser-aware-ai-coding-tools/",
    "/blog/user-feedback": "/changelog/",
  },
  vite: {
    plugins: [tailwindcss()],
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
    validateDocsDescriptions(),
    starlight({
      title: "Frontman",
      plugins: [hcStarlight()],
      disable404Route: true,
      logo: {
        src: "./src/assets/logo.svg",
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/frontman-ai/frontman",
        },
        {
          icon: "discord",
          label: "Discord",
          href: "https://discord.gg/xk8uXJSvhC",
        },
        {
          icon: "x.com",
          label: "X",
          href: "https://twitter.com/frontman_agent",
        },
      ],
      sidebar: [
        {
          label: "Getting Started",
          items: [
            { label: "Introduction", slug: "docs" },
            { label: "Installation", slug: "docs/installation" },
            { label: "API Keys & Providers", slug: "docs/api-keys" },

          ],
        },
        {
          label: "Using Frontman",
          collapsed: true,
          items: [
            { label: "How the Agent Works", slug: "docs/using/how-the-agent-works" },
            { label: "Sending Prompts", slug: "docs/using/sending-prompts" },
            { label: "Annotations", slug: "docs/using/annotations" },
            { label: "The Web Preview", slug: "docs/using/web-preview" },
            { label: "Tool Capabilities", slug: "docs/using/tool-capabilities" },
            { label: "The Question Flow", slug: "docs/using/question-flow" },
            { label: "Plans & Todo Lists", slug: "docs/using/plans-and-todos" },
            { label: "Prompt Strategies", slug: "docs/using/prompt-strategies" },
            { label: "Limitations & Workarounds", slug: "docs/using/limitations" },
          ],
        },
        {
          label: "Integrations",
          collapsed: true,
          items: [
            { label: "Astro", slug: "docs/integrations/astro" },
            { label: "Next.js", slug: "docs/integrations/nextjs" },
            { label: "Vite", slug: "docs/integrations/vite" },
            { label: "WordPress (Beta)", slug: "docs/integrations/wordpress" },
          ],
        },
        {
          label: "Reference",
          collapsed: true,
          items: [
            { label: "Configuration Options", slug: "docs/reference/configuration" },
            { label: "Environment Variables", slug: "docs/reference/env-vars" },
            { label: "Models & Providers", slug: "docs/reference/models" },
            { label: "Supported Frameworks", slug: "docs/reference/compatibility" },
            { label: "Architecture Overview", slug: "docs/reference/architecture" },
            { label: "Troubleshooting", slug: "docs/reference/troubleshooting" },
            { label: "Self-Hosting", slug: "docs/reference/self-hosting" },
          ],
        },
      ],
      customCss: ["./src/styles/starlight.css", "./src/cookiebanner/styles.css"],
      editLink: {
        baseUrl:
          "https://github.com/frontman-ai/frontman/edit/main/apps/marketing/",
      },
      components: {
        Head: "./src/components/starlight/Head.astro",
      },
    }),
    astroConsent({
      siteName: "Frontman",
      headline: "Manage cookie preferences for Frontman",
      description:
        "We use cookies to understand site traffic and improve Frontman. Essential cookies are always on.",
      acceptLabel: "Accept all",
      rejectLabel: "Reject optional",
      manageLabel: "Manage preferences",
      cookiePolicyUrl: "/privacy/",
      privacyPolicyUrl: "/privacy/",
      displayUntilIdle: true,
      displayIdleDelayMs: 1000,
      presentation: "banner",
      consent: {
        days: 180,
        storageKey: "frontman-cookie-consent",
      },
    }),
    stripMarketingConsentCategory(),
    frontman({
    projectRoot: appRoot,
    sourceRoot: monorepoRoot,
    basePath: "frontman",
    serverName: "marketing",
  }), icon(), brokenLinksChecker({ throwError: true, checkExternalLinks: false }), sitemap({
    serialize: (item) => {
      // Exclude tag pages — thin filtered lists that add sitemap bloat
      // without meaningful indexable content.
      if (/\/blog\/tags\//.test(item.url)) return undefined;
      // Exclude integration redirect pages — they 301 to /docs/integrations/*,
      // which are already in the sitemap.
      if (/(?<!\/docs)\/integrations\/(astro|nextjs|vite)\/?$/.test(item.url)) return undefined;
      // Exclude noindexed stub pages that exist only for sidebar navigation.
      if (/\/docs\/guides\/?$/.test(item.url)) return undefined;

      // Use the real pubDate for blog and release posts; fall back to
      // build date for everything else.
      const blogMatch = item.url.match(/\/blog\/([^/]+)\/?$/);
      const releasesMatch = item.url.match(/\/open-source-ai-releases\/([^/]+)\/?$/);
      if (blogMatch && blogDateMap.has(blogMatch[1])) {
        item.lastmod = blogDateMap.get(blogMatch[1]);
      } else if (releasesMatch && releasesDateMap.has(releasesMatch[1])) {
        item.lastmod = releasesDateMap.get(releasesMatch[1]);
      } else {
        item.lastmod = new Date();
      }

      // Assign priority and changefreq by page type.
      if (item.url === 'https://frontman.sh/') {
        item.priority = 1.0;
        item.changefreq = 'weekly';
      } else if (/\/(pricing|features|how-it-works)\/?$/.test(item.url) || /\/use-cases\//.test(item.url)) {
        item.priority = 0.9;
        item.changefreq = 'monthly';
      } else if (/\/vs\//.test(item.url) || /(?<!\/docs)\/integrations\//.test(item.url)) {
        item.priority = 0.8;
        item.changefreq = 'monthly';
      } else if (/\/blog\/(?!tags\/)/.test(item.url) || /\/open-source-ai-releases\//.test(item.url)) {
        item.priority = 0.7;
        item.changefreq = 'never';
      } else if (/\/docs\//.test(item.url)) {
        item.priority = 0.7;
        item.changefreq = 'monthly';
      } else {
        item.priority = 0.5;
        item.changefreq = 'monthly';
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
      releases: (item) => {
        if (/\/open-source-ai-releases\//.test(item.url)) return item;
      },
      comparisons: (item) => {
        if (/\/vs\//.test(item.url)) return item;
      },
      integrations: (item) => {
        if (/\/integrations\//.test(item.url)) return item;
      },
      docs: (item) => {
        if (/\/docs\//.test(item.url)) return item;
      },
    },
  })],
});
