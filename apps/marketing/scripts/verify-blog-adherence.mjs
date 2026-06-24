#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const DEFAULT_SPEC = "/home/bluehotdog/dev/histogram/outputs/2026-06-24T11-19-32-329Z-best-wordpress-ai-agents.json";
const DEFAULT_POST = "src/content/blog/best-wordpress-ai-plugins-2026.md";
const POST_SLUG = "/blog/best-wordpress-ai-plugins-2026/";

const specPath = resolve(process.argv[2] ?? DEFAULT_SPEC);
const postPath = resolve(process.argv[3] ?? DEFAULT_POST);

const spec = JSON.parse(readFileSync(specPath, "utf8"));
const raw = readFileSync(postPath, "utf8");

const failures = [];
const pass = (condition, message) => {
  if (!condition) failures.push(message);
};

const frontmatterMatch = raw.match(/^---\n([\s\S]*?)\n---\n/);
pass(Boolean(frontmatterMatch), "post must have frontmatter");

const frontmatter = frontmatterMatch?.[1] ?? "";
const body = raw.slice(frontmatterMatch?.[0].length ?? 0);
const text = `${frontmatter}\n${body}`.toLowerCase();
const bodyText = body.toLowerCase();

const getScalar = (key) => {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*['\"]?(.+?)['\"]?\\s*$`, "m"));
  return match?.[1]?.replace(/['"]$/, "") ?? "";
};

const title = getScalar("title");
const seoTitle = getScalar("seoTitle");
const description = getScalar("description");
const image = getScalar("image");
const imageAlt = getScalar("imageAlt");
const author = getScalar("author");
const updatedDate = getScalar("updatedDate");

const wordCount = body
  .replace(/```[\s\S]*?```/g, " ")
  .replace(/<[^>]+>/g, " ")
  .replace(/[#*_`>\-|\[\]()]/g, " ")
  .split(/\s+/)
  .filter(Boolean).length;

const headings = [...body.matchAll(/^(#{2,4})\s+(.+)$/gm)].map((match) => ({
  level: match[1].length,
  text: match[2].trim(),
}));

const listItems = [...body.matchAll(/^[-*]\s+/gm)].length;
const tableRows = [...body.matchAll(/^\|.*\|$/gm)].length;
const linkUrls = [...body.matchAll(/\]\(([^)]+)\)/g)].map((match) => match[1]);
const internalLinks = linkUrls.filter((url) => url.startsWith("/"));
const internalBlogLinks = linkUrls.filter((url) => url.startsWith("/blog/"));

const keywordWords = spec.keyword.toLowerCase().split(/\s+/);
const requiredUrls = spec.results;
const nonEmptyPages = spec.pages.filter((page) => page.visible_text.words > 100);
const minCompetitorWords = Math.min(...nonEmptyPages.map((page) => page.visible_text.words));
const medianHeadingCount = [...nonEmptyPages]
  .map((page) => page.element_counts.headings.total)
  .sort((a, b) => a - b)[Math.floor(nonEmptyPages.length / 2)];

const relevantTerms = [
  ...new Set(
    spec.term_analysis.top_tfidf
      .map((entry) => entry.term.toLowerCase())
      .filter((term) =>
        [
          "wordpress",
          "plugins",
          "plugin",
          "content",
          "mcp",
          "builder",
          "automator",
          "aioseo",
          "seedprod",
          "hostinger",
          "elementor",
          "divi",
          "tidio",
          "wpforms",
          "jasper",
          "pricing",
          "features",
          "website builder",
          "ai engine",
          "wordpress ai",
          "ai wordpress plugins",
          "ai website builders",
        ].includes(term)
      )
  ),
];

const requiredEntities = spec.entities
  .slice(0, 24)
  .map((entry) => entry.entity)
  .filter((entity) =>
    [
      "AI Engine",
      "Divi AI",
      "MCP",
      "Elementor",
      "Elementor AI",
      "Uncanny Automator",
      "AIOSEO",
      "Liftoff AI",
      "Hostinger",
      "Tidio",
      "AI Website Builder",
      "AI Power",
      "Jasper AI",
      "Anthropic",
    ].includes(entity)
  );

const frontmatterListCount = (key) => {
  const start = frontmatter.indexOf(`${key}:`);
  if (start === -1) return 0;
  const rest = frontmatter.slice(start + key.length + 1);
  const nextTopLevel = rest.search(/^\S[^\n]*:/m);
  const block = nextTopLevel === -1 ? rest : rest.slice(0, nextTopLevel);
  return [...block.matchAll(/^\s*-\s+/gm)].length;
};

pass(title.toLowerCase().includes("wordpress"), "title must include WordPress");
pass(title.toLowerCase().includes("ai"), "title must include AI");
pass(title.includes("2026"), "title must include 2026");
pass(seoTitle.toLowerCase().includes("frontman"), "seoTitle must include Frontman as agent-positioning target");
pass(seoTitle.toLowerCase().includes("ai engine"), "seoTitle must include AI Engine from source entities");
pass(seoTitle.toLowerCase().includes("elementor ai"), "seoTitle must include Elementor AI from source entities");
pass(description.length >= 120 && description.length <= 155, "description must be 120-155 characters");
pass(author === "Itay Adler", "author must use full author name for E-E-A-T clarity");
pass(Boolean(updatedDate), "frontmatter must include updatedDate for freshness signals");
pass(image === "/blog/best-wordpress-ai-plugins-2026-cover.png", "image must use expected blog cover path");
pass(imageAlt.length >= 60, "imageAlt must be descriptive");

for (const word of keywordWords) {
  pass(text.includes(word), `post must include keyword word: ${word}`);
}

pass(text.includes("best wordpress ai plugin"), "post must include primary plugin phrase");
pass(text.includes("best wordpress ai agents"), "post must reference source keyword phrase");
pass(text.includes("quick answer"), "post must include quick answer block");
pass(text.includes("frontman is the best wordpress ai agent in 2026 when the job is editing an existing wordpress site"), "post must scope Frontman best claim to existing-site editing");
pass(text.includes("disclosure:"), "post must include conflict-of-interest disclosure");
pass(text.includes("not an affiliate roundup"), "post must disclose affiliate status");
pass(text.includes("how we evaluated"), "post must include methodology section");
pass(text.includes("histogram source-analysis"), "post must reference source-analysis methodology");
pass(bodyText.indexOf("frontman") < bodyText.indexOf("ai engine is the best broad"), "Frontman agent recommendation must appear before AI Engine framework recommendation");
pass(text.includes("ai engine is the best broad wordpress ai framework"), "post must frame AI Engine as broad framework, not agent winner");
pass(internalLinks.length >= 5, "post must link out to at least five internal pages/posts for topic clustering");
pass(internalBlogLinks.includes("/blog/ai-agent-wordpress-plugin-comparison/"), "post must link to the WordPress AI agent comparison post");
pass(internalBlogLinks.includes("/blog/frontman-wordpress-plugin-released/"), "post must link to the WordPress plugin release post");
pass(internalBlogLinks.includes("/blog/wordpress-integration/"), "post must link to the WordPress integration post");
pass(internalBlogLinks.includes("/blog/wordpress-7-breaking-changes/"), "post must link to the WordPress 7 breaking changes post");
pass(linkUrls.includes("/docs/integrations/wordpress/"), "post must link to WordPress setup docs");
pass(wordCount >= minCompetitorWords, `word count ${wordCount} must be at least shortest substantive source page ${minCompetitorWords}`);
pass(headings.length >= Math.floor(medianHeadingCount / 2), "post must have substantial heading coverage from source depth");
pass(headings.some((heading) => heading.text.toLowerCase().includes("best wordpress ai plugins")), "heading must include primary topic");
pass(headings.some((heading) => heading.text.toLowerCase().includes("frontman") && heading.text.toLowerCase().includes("existing-site visual editing")), "heading must scope Frontman positioning to existing-site visual editing");
pass(headings.some((heading) => heading.text.toLowerCase().includes("mcp")), "heading must cover MCP because source terms emphasize MCP");
pass(headings.some((heading) => heading.text.toLowerCase().includes("website builders")), "heading must cover website builders because source results include builders");
pass(headings.some((heading) => heading.text.toLowerCase().includes("common objections")), "post must include objection handling per blog voice");
pass(tableRows >= 10, "post must include comparison tables");
pass(listItems >= 20, "post must include enough list items to mirror source list-heavy pages");
pass(frontmatterListCount("faq") >= 5, "frontmatter must include at least 5 FAQ items for FAQPage schema");
pass(frontmatterListCount("comparisonItems") >= requiredUrls.length, "frontmatter must include comparisonItems covering source results");

for (const url of requiredUrls) {
  pass(linkUrls.includes(url) || raw.includes(url), `post must link source result URL: ${url}`);
}

const missingTerms = relevantTerms.filter((term) => !text.includes(term));
pass(missingTerms.length === 0, `post missing source-derived terms: ${missingTerms.join(", ")}`);

const missingEntities = requiredEntities.filter((entity) => !text.includes(entity.toLowerCase()));
pass(missingEntities.length === 0, `post missing source-derived entities: ${missingEntities.join(", ")}`);

const forbiddenUnqualifiedClaims = [
  "objectively best",
  "best for everyone",
  "only plugin you need",
  "guaranteed",
];
for (const phrase of forbiddenUnqualifiedClaims) {
  pass(!text.includes(phrase), `post must avoid unsupported claim: ${phrase}`);
}

const inboundLinkFiles = [
  "src/content/blog/ai-agent-wordpress-plugin-comparison.md",
  "src/content/blog/frontman-wordpress-plugin-released.md",
];
for (const file of inboundLinkFiles) {
  const inboundRaw = readFileSync(resolve(file), "utf8");
  pass(inboundRaw.includes(POST_SLUG), `${file} must link to ${POST_SLUG}`);
}

if (failures.length > 0) {
  console.error(`Blog adherence check failed for ${postPath}`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`Blog adherence check passed for ${postPath}`);
console.log(JSON.stringify({
  spec: specPath,
  keyword: spec.keyword,
  wordCount,
  headings: headings.length,
  listItems,
  tableRows,
  requiredUrls: requiredUrls.length,
  checkedTerms: relevantTerms.length,
  checkedEntities: requiredEntities.length,
  internalBlogLinks: internalBlogLinks.length,
  internalLinks: internalLinks.length,
  inboundLinkFiles: inboundLinkFiles.length,
}, null, 2));
