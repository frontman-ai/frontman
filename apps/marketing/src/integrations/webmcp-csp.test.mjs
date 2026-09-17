import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import vm from "node:vm";
import { build } from "vite";
import { expect, test, vi } from "vitest";
import webmcpValidators from "./webmcp-validators.mjs";

test("WebMCP works without dynamic code generation and CSP permits the support API", async () => {
  const headers = await readFile(new URL("../../public/_headers", import.meta.url), "utf8");
  expect(headers.match(/connect-src[^;]+/)[0]).toContain("https://api.frontman.sh");
  expect(headers.match(/script-src[^;]+/)[0]).not.toMatch(/(?:unsafe|trusted-types)-eval/);
  const [bundle] = await build({
    configFile: false,
    logLevel: "silent",
    plugins: [webmcpValidators],
    build: {
      write: false,
      lib: {
        entry: fileURLToPath(new URL("./webmcp.mjs", import.meta.url)),
        formats: ["iife"],
        name: "WebMCP",
      },
    },
  });
  const document = {
    modelContext: { registerTool: vi.fn() },
    defaultView: { location: { assign: vi.fn() } },
  };
  const context = vm.createContext({ AbortController }, { codeGeneration: { strings: false, wasm: false } });
  vm.runInContext(bundle.output.find(chunk => chunk.isEntry).code, context);
  await context.WebMCP.registerHomepageTools(document);
  const tools = document.modelContext.registerTool.mock.calls.map(([tool]) => tool);
  expect(tools).toHaveLength(6);
  const options = { signal: new AbortController().signal };
  for (const tool of tools) await expect(tool.execute({ unexpected: true }, options)).rejects.toThrow();
  await tools.find(tool => tool.name === "open_docs").execute({}, options);
  expect(document.defaultView.location.assign).toHaveBeenCalledWith("/docs/");
});
