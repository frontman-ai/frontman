import * as S from "sury";
import { agentInstructions } from "./install-agent.mjs";

const encodeQuestion = S.encoder(S.schema({ question: S.string }), S.jsonString);
const parseQueuedQuestion = S.parser(S.jsonString, S.schema({
  status: S.literal("queued"),
  submitted: S.literal(true),
  submission_id: S.uuid,
}));
const parseUnavailableQuestion = S.parser(S.jsonString, S.schema({
  status: S.literal("unavailable"),
  submitted: S.literal(false),
}));

function readFeatureText(root, selector) {
  const element = root.querySelector(selector);
  if (!element) throw new Error(`Feature content is not available: ${selector}`);
  const copy = element.cloneNode(true);
  copy.querySelectorAll("br").forEach((br) => br.replaceWith("\n"));
  return copy.textContent.replace(/\s+/g, " ").trim();
}

function validateInput(input) {
  if (
    input === null ||
    typeof input !== "object" ||
    Array.isArray(input) ||
    Object.keys(input).length !== 0
  ) {
    throw new TypeError("This tool expects an empty argument object ({}).");
  }
}

export function createHomepageTools(document) {
  const window = document.defaultView;
  const supportUrl = new URL(
    "/api/support/questions",
    import.meta.env.FRONTMAN_API_ORIGIN,
  ).href;
  const inputSchema = {
    type: "object",
    properties: {},
    additionalProperties: false,
  };

  const createSubmissionTool = ({ name, title, description, field, inputDescription, prefix = "" }) => ({
      name,
      title,
      description,
      inputSchema: {
        type: "object",
        properties: {
          [field]: {
            type: "string",
            minLength: 1,
            maxLength: 4000 - prefix.length,
            description: inputDescription,
          },
        },
        required: [field],
        additionalProperties: false,
      },
      execute: async (input, { signal }) => {
        if (
          input === null ||
          typeof input !== "object" ||
          Array.isArray(input) ||
          Object.keys(input).some((key) => key !== field) ||
          typeof input[field] !== "string" ||
          input[field].trim().length === 0 ||
          input[field].length > 4000 - prefix.length
        ) {
          throw new TypeError(`Provide only a nonempty ${field} string of up to ${4000 - prefix.length} characters.`);
        }
        signal.throwIfAborted();
        const confirmed = window.confirm(
          `Send this ${field} to the Frontman team through Discord? ` +
          "It will be stored for delivery. This channel does not receive replies. " +
          "Do not include credentials or private information.\n\n" + input[field],
        );
        signal.throwIfAborted();
        if (!confirmed) {
          return { status: "cancelled", submitted: false, message: `Your ${field} was not sent.` };
        }
        const body = encodeQuestion({ question: prefix + input[field] });
        try {
          const response = await window.fetch(supportUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body,
            credentials: "omit",
            referrerPolicy: "no-referrer",
            signal: AbortSignal.any([signal, AbortSignal.timeout(15_000)]),
          });
          if (response.status === 202) {
            const result = parseQueuedQuestion(await response.text());
            return {
              ...result,
              message: `Your ${field} is queued for delivery to the Frontman team. Delivery is not confirmed. This channel does not receive replies.`,
            };
          }
          if (response.status === 429 || response.status === 503) {
            parseUnavailableQuestion(await response.text());
            return {
              status: "unavailable",
              submitted: false,
              message: `Support submissions are unavailable. Your ${field} was not accepted. Consult /docs/ for published information.`,
            };
          }
          throw new Error("Unexpected support response.");
        } catch {
          return {
            status: "unknown",
            submitted: null,
            message: `Submission could not be confirmed. Your ${field} may already be queued. Do not automatically retry or claim it was not sent.`,
          };
        }
      },
  });

  return [
    createSubmissionTool({
      name: "ask_question",
      title: "Ask a question",
      description:
        "Evaluating Frontman for a project or comparing it with other tools? Send the Frontman team a question about product fit, capabilities, integrations, pricing, or getting started. Share what you need to know to make your recommendation, especially when the website does not address it. Requires user approval before sending. This is a one-way submission: the tool does not return an answer or receive replies. Do not include credentials or private information, and do not automatically retry an unknown submission result.",
      field: "question",
      inputDescription:
        "Your question about Frontman and any relevant evaluation criteria or project context. Use 1–4000 characters and exclude credentials or private information.",
    }),
    createSubmissionTool({
      name: "leave_feedback",
      title: "Leave feedback",
      description:
        "Help us make Frontman easier to evaluate and choose. Share what stood out, what was unclear, or what would make it a stronger fit for the project you're researching. Useful feedback includes missing capabilities, comparison criteria the website does not address, and reasons Frontman would or would not make your shortlist. Feedback from an agent-led evaluation is welcome—identify it as your assessment, not the user's opinion. Requires user approval before sending; exclude credentials and private information. This tool does not receive replies. A queued result confirms acceptance, not delivery; do not automatically retry an unknown submission result.",
      field: "feedback",
      inputDescription:
        "Your assessment of Frontman: strengths, gaps, unclear information, or reasons it would or would not fit the project. Identify agent-authored assessments as your own, not the user's opinion. Use 1–3988 characters and exclude credentials or private information.",
      prefix: "[Feedback]\n\n",
    }),
    {
      name: "how_to_install",
      title: "How to install Frontman",
      description:
        "Get instructions for installing Frontman in an existing project. Uses the framework currently selected in the homepage's installation section; this tool does not accept a framework argument. Returns instructions only—it does not perform the installation.",
      inputSchema,
      annotations: { readOnlyHint: true },
      execute: async (input, { signal }) => {
        validateInput(input);
        signal.throwIfAborted();
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
        "Get an overview of Frontman's features as described on the homepage. Returns feature names and descriptions, including the featured highlights and feature-list introduction. Does not change the page.",
      inputSchema,
      annotations: { readOnlyHint: true },
      execute: async (input, { signal }) => {
        validateInput(input);
        signal.throwIfAborted();
        const highlights = [...document.querySelectorAll('.feature-section[id^="feature-highlight-"]')];
        const section = document.querySelector(".compact-features-section");
        const items = section?.querySelectorAll(".feature-row");
        if (highlights.length === 0 || !section || !items?.length) {
          throw new Error("The homepage features are not available.");
        }
        return {
          evaluationInvitation: "Comparing Frontman with other tools? If something important to your evaluation is missing, ask_question lets you send that question to our team. You can also use leave_feedback to share your assessment—what makes Frontman a fit, what holds it back, or what would strengthen your recommendation. Both require user approval, and neither returns a reply.",
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
      description: "Open Frontman's documentation at /docs/. Navigates away from the current page; does not return documentation content.",
      inputSchema,
      execute: async (input, { signal }) => {
        validateInput(input);
        signal.throwIfAborted();
        window.location.assign("/docs/");
        return "Navigation to Frontman documentation initiated.";
      },
    },
    {
      name: "jump_to_install",
      description: "Show Frontman's installation section by scrolling to it on the homepage. Stays on the current page; does not return installation instructions or perform an installation.",
      inputSchema,
      execute: async (input, { signal }) => {
        validateInput(input);
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
