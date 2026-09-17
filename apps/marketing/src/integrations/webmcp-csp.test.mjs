import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import vm from "node:vm";
import { JSDOM } from "jsdom";
import { build } from "vite";
import { expect, test, vi } from "vitest";
import webmcpValidators from "./webmcp-validators.mjs";

const apiOrigin = "https://api.frontman.sh";

test("the production CSP permits support requests without permitting dynamic code", async () => {
  const headers = await readFile(new URL("../../public/_headers", import.meta.url), "utf8");
  const policy = headers.match(/Content-Security-Policy: (.+)/)[1];
  const directives = Object.fromEntries(policy.split(";").map(directive => {
    const [name, ...values] = directive.trim().split(/\s+/);
    return [name, values];
  }));
  expect(directives["connect-src"]).toContain(apiOrigin);
  expect(directives["script-src"]).not.toContain("'unsafe-eval'");
  expect(directives["script-src"]).not.toContain("'trusted-types-eval'");
});

test("the production bundle registers and executes tools with string code generation disabled", async () => {
  const result = await build({
    configFile: false,
    logLevel: "silent",
    plugins: [webmcpValidators()],
    define: { "import.meta.env.FRONTMAN_API_ORIGIN": JSON.stringify(apiOrigin) },
    build: {
      write: false,
      minify: true,
      lib: {
        entry: fileURLToPath(new URL("./webmcp.mjs", import.meta.url)),
        formats: ["iife"],
        name: "HomepageWebMCP",
      },
    },
  });
  const page = new JSDOM('<!doctype html><section id="install" data-install-agent data-agent-framework="astro"></section>', {
    url: "https://frontman.sh/",
  });
  try {
    const document = page.window.document;
    const tools = [];
    document.modelContext = { registerTool: vi.fn(tool => { tools.push(tool); }) };
    document.defaultView.confirm = vi.fn(() => false);
    document.defaultView.fetch = vi.fn(async () => new Response(JSON.stringify({
      status: "unavailable", submitted: false,
    }), { status: 503 }));
    const context = vm.createContext({ document, URL, AbortController, AbortSignal }, {
      codeGeneration: { strings: false, wasm: false },
    });
    expect(() => vm.runInContext("new Function('return 1')", context)).toThrow();
    for (const output of result) {
      for (const chunk of output.output) {
        if (chunk.type === "chunk") vm.runInContext(chunk.code, context);
      }
    }
    await context.HomepageWebMCP.registerHomepageTools(document);
    expect(tools.map(tool => tool.name)).toEqual([
      "ask_question", "leave_feedback", "how_to_install", "list_features", "open_docs", "jump_to_install",
    ]);
    const options = { signal: new AbortController().signal };
    const install = tools.find(tool => tool.name === "how_to_install");
    await expect(install.execute({}, options)).resolves.toContain("Astro");
    await expect(install.execute({ unexpected: true }, options)).rejects.toThrow();
    const question = tools.find(tool => tool.name === "ask_question");
    await expect(question.execute({ question: "Help?" }, options)).resolves.toMatchObject({
      status: "cancelled", submitted: false,
    });
    expect(document.defaultView.fetch).not.toHaveBeenCalled();
    const feedback = tools.find(tool => tool.name === "leave_feedback");
    await expect(feedback.execute({ feedback: "  " }, options)).rejects.toThrow();
    await expect(feedback.execute({ feedback: "Missing a capability." }, options)).resolves.toMatchObject({
      status: "unavailable", submitted: false,
    });
    expect(document.defaultView.fetch).toHaveBeenCalledExactlyOnceWith(
      `${apiOrigin}/api/support/questions`,
      expect.objectContaining({ body: JSON.stringify({ question: "[Feedback]\n\nMissing a capability." }) }),
    );
  } finally {
    page.window.close();
  }
});
