import {
  validateInput, validateQuestion,
  validateSearch, validateSearchIndex, searchInputSchema,
  validateQueuedQuestion, validateUnavailableQuestion,
  inputSchema, questionInputSchema,
} from "virtual:webmcp-validators";
import { agentInstructions } from "./install-agent.mjs";

function parseWith(validate, value) {
  if (!validate(value)) throw new TypeError("Invalid WebMCP data.");
  return value;
}

function readFeatureText(root, selector) {
  const element = root.querySelector(selector);
  if (!element) throw new Error(`Feature content is not available: ${selector}`);
  const copy = element.cloneNode(true);
  copy.querySelectorAll("br").forEach((br) => br.replaceWith("\n"));
  return copy.textContent.replace(/\s+/g, " ").trim();
}

export function createHomepageTools(document) {
  const window = document.defaultView;

  return [
    {
      name: "search_frontman",
      title: "Search Frontman",
      description: "Search Frontman's public documentation only, using concise keywords. Does not search pricing or marketing pages. Returns matching excerpts and source URLs, or no_results when nothing matches. Does not contact the team or submit a request. The query stays in the browser.",
      inputSchema: searchInputSchema,
      annotations: { readOnlyHint: true },
      execute: async (input, { signal }) => {
        const { query } = parseWith(validateSearch, input);
        signal.throwIfAborted();
        const response = await window.fetch("/search-index.json", { signal, credentials: "omit", referrerPolicy: "no-referrer" });
        if (!response.ok) throw new Error(`Frontman search index returned HTTP ${response.status}.`);
        const documents = parseWith(validateSearchIndex, await response.json());
        signal.throwIfAborted();
        const terms = query.toLowerCase().trim().split(/\s+/);
        const results = documents
          .filter(({ title, content }) => terms.every(term => `${title} ${content}`.toLowerCase().includes(term)))
          .sort((a, b) => terms.filter(term => b.title.toLowerCase().includes(term)).length - terms.filter(term => a.title.toLowerCase().includes(term)).length)
          .slice(0, 5)
          .map(({ title, url, content }) => {
            const text = content.replace(/\s+/g, " ");
            const start = Math.max(0, text.toLowerCase().indexOf(terms[0]) - 80);
            return { title, url, excerpt: text.slice(start, start + 400) };
          });
        return { status: results.length ? "found" : "no_results", results };
      },
    },
    {
      name: "ask_question",
      title: "Ask a question",
      description: "Send Frontman a product, compatibility, or setup question that the published documentation does not answer. Requires user approval; do not repeat a declined request. No replies. Exclude credentials and private information. Never automatically retry a failed submission.",
      inputSchema: questionInputSchema,
      execute: async (input, { signal = new AbortController().signal } = {}) => {
        const { question } = parseWith(validateQuestion, input);
        signal.throwIfAborted();
        const supportUrl = new URL("/api/support/questions", import.meta.env.FRONTMAN_API_ORIGIN);
        const confirmed = window.confirm(
          `Send this question to Frontman through Discord? It will be stored for delivery. ` +
          `No replies are available. Exclude credentials and private information.\n\n${question}`,
        );
        signal.throwIfAborted();
        if (!confirmed) return { status: "cancelled", submitted: false };

        const request = {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ question }),
          credentials: "omit",
          referrerPolicy: "no-referrer",
          signal: AbortSignal.any([signal, AbortSignal.timeout(15_000)]),
        };
        let response, body;
        try {
          response = await window.fetch(supportUrl.href, request);
          body = await response.text();
        } catch (cause) {
          throw new Error("Submission could not be confirmed; it may already be queued. Do not automatically retry.", { cause });
        }
        switch (response.status) {
          case 202: {
            const { status, submitted, submission_id } = parseWith(validateQueuedQuestion, JSON.parse(body));
            return { status, submitted, submission_id, message: "Queued. Delivery is not confirmed; no replies are available." };
          }
          case 429:
          case 503: {
            const { status, submitted } = parseWith(validateUnavailableQuestion, JSON.parse(body));
            return { status, submitted, message: "Support is unavailable. Submission was not accepted." };
          }
          default:
            throw new Error(`Support submission returned HTTP ${response.status}. Delivery is unconfirmed; do not automatically retry.`);
        }
      },
    },
    {
      name: "how_to_install",
      title: "How to install Frontman",
      description:
        "Return WordPress setup and safety on the homepage, or instructions for the selected stack on /frameworks/. Does not install anything.",
      inputSchema,
      annotations: { readOnlyHint: true },
      execute: async (input, { signal = new AbortController().signal } = {}) => {
        parseWith(validateInput, input);
        signal.throwIfAborted();
        const wordpress = document.querySelector("#install .wp-install");
        if (wordpress) {
          return [
            readFeatureText(wordpress, ".wp-install__steps"),
            readFeatureText(wordpress, ".wp-install__details"),
            readFeatureText(document, "#wordpress-safety .wp-copy"),
            `Setup guide: ${wordpress.querySelector(".wp-install__links a").href}`,
          ].join("\n\n");
        }
        const framework = document.querySelector("[data-install-agent]")?.dataset.agentFramework;
        if (!Object.hasOwn(agentInstructions, framework)) {
          throw new Error("The selected installation framework is not available.");
        }
        return agentInstructions[framework];
      },
    },
    {
      name: "list_features",
      title: "List Frontman features",
      description:
        "Read feature titles, descriptions, and capabilities from the current page without changing it.",
      inputSchema,
      annotations: { readOnlyHint: true },
      execute: async (input, { signal = new AbortController().signal } = {}) => {
        parseWith(validateInput, input);
        signal.throwIfAborted();
        const wordpress = document.querySelector("#wordpress-features");
        if (wordpress) {
          const highlights = [...wordpress.querySelectorAll(".wp-capability")];
          const features = [...wordpress.querySelectorAll(".wp-more-capabilities li")];
          if (!highlights.length || !features.length) throw new Error("The WordPress features are not available.");
          return {
            highlights: highlights.map(item => ({
              title: readFeatureText(item, "h3"),
              description: readFeatureText(item, "p"),
            })),
            title: readFeatureText(wordpress, "h2"),
            description: readFeatureText(wordpress, ".wp-more-capabilities summary"),
            features: features.map(item => item.textContent.trim()),
          };
        }
        const highlights = [...document.querySelectorAll('.feature-section[id^="feature-highlight-"]')];
        const section = document.querySelector(".compact-features-section");
        const items = section?.querySelectorAll(".feature-row");
        if (highlights.length === 0 || !section || !items?.length) {
          throw new Error("The homepage features are not available.");
        }
        return {
          highlights: highlights.map((item) => ({
            title: readFeatureText(item, ".feature-title"),
            description: readFeatureText(item, ".feature-description"),
          })),
          title: readFeatureText(section, ".compact-title"),
          description: readFeatureText(section, ".compact-subtitle"),
          features: [...items].map((item) => ({
            title: readFeatureText(item, ".fl-title"),
            description: readFeatureText(item, ".fl-description"),
          })),
        };
      },
    },
    {
      name: "open_docs",
      description: "Navigate to /docs/. Does not return documentation content.",
      inputSchema,
      execute: async (input, { signal = new AbortController().signal } = {}) => {
        parseWith(validateInput, input);
        signal.throwIfAborted();
        window.location.assign("/docs/");
        return "Navigation to Frontman documentation initiated.";
      },
    },
    {
      name: "jump_to_install",
      description: "Scroll to the current page's installation section. Does not install anything.",
      inputSchema,
      execute: async (input, { signal = new AbortController().signal } = {}) => {
        parseWith(validateInput, input);
        signal.throwIfAborted();
        const target = document.querySelector("#install");
        if (!target) throw new Error("The installation section is not available.");
        const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "auto"
          : "smooth";
        target.scrollIntoView({ behavior, block: "start" });
        return "Scrolling to the installation section initiated.";
      },
    },
  ];
}

export async function registerHomepageTools(document) {
  if (typeof document.modelContext?.registerTool !== "function") return;
  if (!["/", "/frameworks/", "/frameworks"].includes(document.defaultView.location.pathname)) return;

  const registration = new AbortController();
  try {
    for (const tool of createHomepageTools(document)) {
      await document.modelContext.registerTool(tool, { signal: registration.signal });
    }
  } catch (error) {
    registration.abort();
    throw error;
  }
}
