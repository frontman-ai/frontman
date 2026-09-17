import { JSDOM } from "jsdom";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { agentInstructions } from "./install-agent.mjs";
import { createHomepageTools, registerHomepageTools } from "./webmcp.mjs";

const pages = [];

function createPage() {
  const page = new JSDOM('<!doctype html><section id="install"></section>', {
    url: "https://frontman.sh/",
  });
  pages.push(page);
  return page.window.document;
}

beforeEach(() => {
  vi.stubEnv("FRONTMAN_API_ORIGIN", "https://api.frontman.sh");
});

afterEach(() => {
  vi.unstubAllEnvs();
  for (const page of pages.splice(0)) page.window.close();
});

describe("homepage WebMCP tools", () => {
  test.each(["https://frontman.local:4000", "https://abcd.api.frontman.local", "http://localhost:4567"])(
    "both submission tools use the integration's resolved origin: %s", async (origin) => {
      vi.stubEnv("FRONTMAN_API_ORIGIN", origin);
      const document = createPage();
      document.defaultView.confirm = () => true;
      document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
        status: "unavailable", submitted: false,
      }), { status: 503 }));
      for (const [name, field] of [["ask_question", "question"], ["leave_feedback", "feedback"]]) {
        const tool = createHomepageTools(document).find(tool => tool.name === name);
        await tool.execute({ [field]: "Help?" }, { signal: new AbortController().signal });
      }
      expect(document.defaultView.fetch).toHaveBeenCalledTimes(2);
      for (const [url] of document.defaultView.fetch.mock.calls) {
        expect(url).toBe(`${origin}/api/support/questions`);
      }
    },
  );

  test("missing integration configuration fails rather than falling back to production", () => {
    vi.stubEnv("FRONTMAN_API_ORIGIN", undefined);
    expect(() => createHomepageTools(createPage())).toThrow();
  });

  test("does nothing when WebMCP is unavailable", async () => {
    const document = createPage();
    const original = document.documentElement.outerHTML;
    await expect(registerHomepageTools(document)).resolves.toBeUndefined();
    expect(document.documentElement.outerHTML).toBe(original);
    expect(document.defaultView.location.href).toBe("https://frontman.sh/");
  });

  test("exposes the existing actions with empty-object schemas", () => {
    const tools = createHomepageTools(createPage());
    expect(tools.map(({ name }) => name)).toEqual(["ask_question", "leave_feedback", "how_to_install", "list_features", "open_docs", "jump_to_install"]);
    for (const tool of tools.filter(({ name }) => !["ask_question", "leave_feedback"].includes(name))) {
      expect(tool.description.length).toBeGreaterThan(0);
      expect(tool.inputSchema).toEqual({
        type: "object",
        properties: {},
        additionalProperties: false,
      });
    }
  });

  test.each([undefined, null, [], "", 1, { unexpected: true }])(
    "rejects invalid input %j before performing an action",
    async (input) => {
      const document = createPage();
      for (const tool of createHomepageTools(document)) {
        await expect(tool.execute(input, { signal: new AbortController().signal }))
          .rejects.toThrow(TypeError);
      }
      expect(document.defaultView.location.href).toBe("https://frontman.sh/");
    },
  );

  test("honors cancellation before performing either action", async () => {
    const document = createPage();
    const controller = new AbortController();
    const reason = new Error("Execution cancelled");
    controller.abort(reason);
    for (const tool of createHomepageTools(document)) {
      const input = Object.fromEntries(tool.inputSchema.required?.map((field) => [field, "Evaluating Frontman for Astro."]) ?? []);
      await expect(tool.execute(input, { signal: controller.signal })).rejects.toBe(reason);
    }
    expect(document.defaultView.location.href).toBe("https://frontman.sh/");
  });

  test("ask_question confirms disclosure and reports acceptance, not delivery", async () => {
    const document = createPage();
    const original = document.documentElement.outerHTML;
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    expect(tool.title).toBe("Ask a question");
    expect(tool.inputSchema.required).toEqual(["question"]);
    expect(tool.inputSchema.additionalProperties).toBe(false);
    expect(tool.inputSchema.properties.question).toMatchObject({
      type: "string", minLength: 1, maxLength: 4000,
    });
    const question = "How does Frontman work with my existing Astro site?";
    const submission_id = "7b5f8a97-554f-4a1a-b4c0-f1863d2a127f";
    document.defaultView.confirm = vi.fn(() => true);
    document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
      status: "queued", submitted: true, submission_id,
    }), { status: 202 }));
    const result = await tool.execute({ question }, { signal: new AbortController().signal });
    expect(document.defaultView.confirm).toHaveBeenCalledWith(expect.stringContaining(question));
    expect(document.defaultView.confirm).toHaveBeenCalledWith(expect.stringContaining("stored for delivery"));
    expect(document.defaultView.fetch).toHaveBeenCalledExactlyOnceWith(
      "https://api.frontman.sh/api/support/questions",
      expect.objectContaining({
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question }),
        credentials: "omit",
        referrerPolicy: "no-referrer",
      }),
    );
    expect(result).toMatchObject({ status: "queued", submitted: true, submission_id });
    expect(result.message).toContain("Delivery is not confirmed");
    expect(result).not.toHaveProperty("answer");
    expect(document.documentElement.outerHTML).toBe(original);
  });

  test("declining confirmation sends nothing", async () => {
    const document = createPage();
    document.defaultView.confirm = () => false;
    document.defaultView.fetch = vi.fn();
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    const result = await tool.execute({ question: "Help?" }, { signal: new AbortController().signal });
    expect(result).toMatchObject({ status: "cancelled", submitted: false });
    expect(document.defaultView.fetch).not.toHaveBeenCalled();
  });

  test("checks cancellation again after confirmation", async () => {
    const document = createPage();
    const controller = new AbortController();
    document.defaultView.confirm = () => { controller.abort(); return true; };
    document.defaultView.fetch = vi.fn();
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    await expect(tool.execute({ question: "Help?" }, { signal: controller.signal })).rejects.toThrow();
    expect(document.defaultView.fetch).not.toHaveBeenCalled();
  });

  test.each([429, 503])("reports explicit rejection from support (%s)", async (status) => {
    const document = createPage();
    document.defaultView.confirm = () => true;
    document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
      status: "unavailable", submitted: false,
    }), { status }));
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    const result = await tool.execute({ question: "Help?" }, { signal: new AbortController().signal });
    expect(result).toMatchObject({ status: "unavailable", submitted: false });
    expect(document.defaultView.fetch).toHaveBeenCalledTimes(1);
  });

  test.each([
    [202, "not JSON"],
    [202, '{"status":"queued","submitted":true}'],
    [202, '{"status":"unavailable","submitted":false}'],
    [503, "upstream unavailable"],
    [500, "server error"],
  ])("does not invent an outcome from an unexpected response (%s, %s)", async (status, body) => {
    const document = createPage();
    document.defaultView.confirm = () => true;
    document.defaultView.fetch = vi.fn(async () => new Response(body, { status }));
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    const result = await tool.execute({ question: "Help?" }, { signal: new AbortController().signal });
    expect(result).toMatchObject({ status: "unknown", submitted: null });
    expect(document.defaultView.fetch).toHaveBeenCalledTimes(1);
  });

  test.each([false, true])("a network error or cancellation after dispatch has unknown delivery (%s)", async (cancel) => {
    const document = createPage();
    const controller = new AbortController();
    document.defaultView.confirm = () => true;
    document.defaultView.fetch = vi.fn(async (_url, { signal }) => {
      if (cancel) controller.abort();
      expect(signal.aborted).toBe(cancel);
      throw new Error("Connection interrupted");
    });
    const tool = createHomepageTools(document).find(({ name }) => name === "ask_question");
    const result = await tool.execute({ question: "Help?" }, { signal: controller.signal });
    expect(result).toMatchObject({ status: "unknown", submitted: null });
    expect(result.message).toContain("Do not automatically retry");
    expect(document.defaultView.fetch).toHaveBeenCalledTimes(1);
  });

  test.each([{}, { question: "" }, { question: "  \n " }, { question: 42 },
    { question: "x".repeat(4001) }, { question: "Help?", email: "private@example.com" }])(
    "ask_question rejects invalid question input %j",
    async (input) => {
      const tool = createHomepageTools(createPage()).find(({ name }) => name === "ask_question");
      await expect(tool.execute(input, { signal: new AbortController().signal }))
        .rejects.toThrow(TypeError);
    },
  );

  describe.each([
    ["ask_question", "question", "", 4000],
    ["leave_feedback", "feedback", "[Feedback]\n\n", 3988],
  ])("%s shared submission safeguards", (name, field, prefix, maxLength) => {
    test("accepts the input limit and preserves the support API contract", async () => {
      const document = createPage();
      const tool = createHomepageTools(document).find((tool) => tool.name === name);
      const text = "x".repeat(maxLength);
      document.defaultView.confirm = vi.fn(() => true);
      document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
        status: "queued", submitted: true,
        submission_id: "7b5f8a97-554f-4a1a-b4c0-f1863d2a127f",
      }), { status: 202 }));
      expect(tool.inputSchema.required).toEqual([field]);
      expect(tool.inputSchema.properties[field].maxLength).toBe(maxLength);
      const result = await tool.execute({ [field]: text }, { signal: new AbortController().signal });
      expect(document.defaultView.confirm).toHaveBeenCalledWith(expect.stringContaining(`Send this ${field}`));
      expect(document.defaultView.confirm).toHaveBeenCalledWith(expect.stringContaining(text));
      expect(document.defaultView.fetch).toHaveBeenCalledExactlyOnceWith(
        "https://api.frontman.sh/api/support/questions",
        expect.objectContaining({ body: JSON.stringify({ question: prefix + text }) }),
      );
      expect(result).toMatchObject({ status: "queued", submitted: true });
      expect(result.message).toContain("Delivery is not confirmed");
    });

    test("rejects empty, oversized, and extra input before confirmation", async () => {
      const document = createPage();
      document.defaultView.confirm = vi.fn();
      document.defaultView.fetch = vi.fn();
      const tool = createHomepageTools(document).find((tool) => tool.name === name);
      for (const input of [{}, { [field]: "  " }, { [field]: 42 },
        { [field]: "x".repeat(maxLength + 1) }, { [field]: "Review", extra: true }]) {
        await expect(tool.execute(input, { signal: new AbortController().signal })).rejects.toThrow(TypeError);
      }
      expect(document.defaultView.confirm).not.toHaveBeenCalled();
      expect(document.defaultView.fetch).not.toHaveBeenCalled();
    });

    test("does not submit when approval is declined or execution is cancelled", async () => {
      const document = createPage();
      document.defaultView.fetch = vi.fn();
      const tool = createHomepageTools(document).find((tool) => tool.name === name);
      document.defaultView.confirm = () => false;
      await expect(tool.execute({ [field]: "Review" }, { signal: new AbortController().signal }))
        .resolves.toMatchObject({ status: "cancelled", submitted: false });
      const controller = new AbortController();
      document.defaultView.confirm = () => { controller.abort(); return true; };
      await expect(tool.execute({ [field]: "Review" }, { signal: controller.signal })).rejects.toThrow();
      expect(document.defaultView.fetch).not.toHaveBeenCalled();
    });

    test.each([429, 503, 500])("reports rejection or uncertainty without retrying (%s)", async (status) => {
      const document = createPage();
      document.defaultView.confirm = () => true;
      document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
        status: "unavailable", submitted: false,
      }), { status }));
      const tool = createHomepageTools(document).find((tool) => tool.name === name);
      const result = await tool.execute({ [field]: "Review" }, { signal: new AbortController().signal });
      expect(result).toMatchObject(status === 500
        ? { status: "unknown", submitted: null }
        : { status: "unavailable", submitted: false });
      if (status === 500) expect(result.message).toContain("Do not automatically retry");
      expect(document.defaultView.fetch).toHaveBeenCalledTimes(1);
    });
  });

  test("how_to_install returns the exact copy-button text for each selected framework", async () => {
    const document = createPage();
    const root = document.querySelector("#install");
    root.setAttribute("data-install-agent", "");
    const tool = createHomepageTools(document).find(({ name }) => name === "how_to_install");
    expect(tool.annotations.readOnlyHint).toBe(true);
    for (const framework of Object.keys(agentInstructions)) {
      root.dataset.agentFramework = framework;
      await expect(tool.execute({}, { signal: new AbortController().signal }))
        .resolves.toBe(agentInstructions[framework]);
    }
    root.dataset.agentFramework = "unknown";
    await expect(tool.execute({}, { signal: new AbortController().signal }))
      .rejects.toThrow("selected installation framework");
    root.remove();
    await expect(tool.execute({}, { signal: new AbortController().signal }))
      .rejects.toThrow("selected installation framework");
  });

  test("list_features reads current text without changing the page", async () => {
    const document = createPage();
    document.body.innerHTML = `
      <section class="feature-section" id="feature-highlight-0">
        <h2 class="feature-title">Highlight</h2>
        <p class="feature-description">Description.<br/><br/><span>Pro tip.</span></p>
      </section>
      <section class="compact-features-section">
        <h2 class="compact-title">More features</h2>
        <p class="compact-subtitle">Introduction</p>
        <div class="feature-row">
          <h3 class="fl-title">Feature</h3><p class="fl-description">Details</p>
        </div>
      </section>`;
    const original = document.documentElement.outerHTML;
    const tool = createHomepageTools(document).find(({ name }) => name === "list_features");
    expect(tool.annotations.readOnlyHint).toBe(true);
    await expect(tool.execute({}, { signal: new AbortController().signal })).resolves.toEqual({
      evaluationInvitation: expect.stringContaining("Both require user approval, and neither returns a reply."),
      highlights: [{ title: "Highlight", description: "Description. Pro tip." }],
      title: "More features",
      description: "Introduction",
      features: [{ title: "Feature", description: "Details" }],
    });
    expect(document.documentElement.outerHTML).toBe(original);
    document.querySelector(".fl-description").textContent = "Updated details";
    const result = await tool.execute({}, { signal: new AbortController().signal });
    expect(result.features[0].description).toBe("Updated details");
    document.querySelector(".fl-title").remove();
    await expect(tool.execute({}, { signal: new AbortController().signal }))
      .rejects.toThrow("Feature content is not available");
    document.querySelector(".compact-features-section").remove();
    await expect(tool.execute({}, { signal: new AbortController().signal }))
      .rejects.toThrow("homepage features are not available");
  });

  test("does not report success when the install section is missing", async () => {
    const document = createPage();
    document.querySelector("#install").remove();
    const tool = createHomepageTools(document).find(({ name }) => name === "jump_to_install");
    await expect(tool.execute({}, { signal: new AbortController().signal }))
      .rejects.toThrow("The installation section is not available.");
  });
});
