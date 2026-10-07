import { expect, test } from "vitest";
import { readFileSync } from "node:fs";
import { JSDOM } from "jsdom";
import { createRequire } from "node:module";
import CoverImage from "../sites/blog-starter/src/app/_components/cover-image";
import { HeroPost } from "../sites/blog-starter/src/app/_components/hero-post";
import { PostPreview } from "../sites/blog-starter/src/app/_components/post-preview";

const require = createRequire(new URL("../sites/blog-starter/package.json", import.meta.url));
const { createElement } = require("react") as typeof import("react");
const { renderToStaticMarkup } = require("react-dom/server") as typeof import("react-dom/server");

test("browser-test logs and tool metadata render as literal text", () => {
  const html = readFileSync(new URL("../../apps/frontman_server/priv/static/browser-test/index.html", import.meta.url), "utf8");
  const source = html.match(/<script type="module">([\s\S]*?)<\/script>/)![1]
    .replace(/import .* from '\.\/browser-test\.js';/, "");
  const dom = new JSDOM(html, { runScripts: "outside-only" });
  try {
    const payload = '<img src=x onerror="window.injected=true"> & "quoted"';
    dom.window.eval(`const MCPServer = { getToolsJson: server => server };
      ${source}
      log(${JSON.stringify(payload)}, 'error');
      displayRelayTools([{ name: ${JSON.stringify(payload)}, description: ${JSON.stringify(payload + "\nsecond line")} }]);
      mcpServer = [{ name: ${JSON.stringify(payload)} }];
      displayMcpTools();`);
    const document = dom.window.document;
    const entry = document.querySelector("#log .log-entry.error")!;
    expect(entry.querySelector(".time")).not.toBeNull();
    expect(entry.childNodes[1].textContent).toBe(payload);
    for (const list of ["relayToolsList", "mcpToolsList"]) {
      const item = document.querySelector(`#${list} .tool-item`)!;
      expect(item.querySelector(".tool-name")!.textContent).toBe(payload);
      expect(item.querySelector(".tool-desc")!.textContent).toBe(list === "relayToolsList" ? payload : "");
      expect(item.children).toHaveLength(2);
    }
    expect(document.querySelectorAll("#log img, #relayToolsList img, #mcpToolsList img")).toHaveLength(0);
  } finally {
    dom.window.close();
  }
});

test.each(["normal-post", '"><img src=x onerror=alert(1)>', "javascript:alert(1)", "quotes'&amp", "//example.com"])(
  "blog links keep hostile slug %s in an escaped internal path", (slug) => {
    const props = {
      slug, title: '<img src=x onerror=alert(1)> & "title"',
      coverImage: "/assets/blog/hello-world/cover.jpg", date: "2026-01-01",
      excerpt: "Excerpt", author: { name: "Author", picture: "/author.jpg" },
    };
    for (const component of [
      createElement(CoverImage, { ...props, src: props.coverImage }),
      createElement(HeroPost, props),
      createElement(PostPreview, props),
    ]) {
      const dom = new JSDOM(renderToStaticMarkup(component), { url: "https://test.invalid" });
      try {
        for (const anchor of dom.window.document.querySelectorAll("a")) {
          const url = new URL(anchor.href);
          expect(url.origin).toBe("https://test.invalid");
          expect(url.pathname.startsWith("/posts/")).toBe(true);
          expect(anchor.getAttribute("onerror")).toBeNull();
        }
        expect(dom.window.document.querySelectorAll("[onerror]")).toHaveLength(0);
        expect(dom.window.document.querySelectorAll("img")).toHaveLength(component.type === CoverImage ? 1 : 2);
        expect(dom.window.document.querySelector("a")!.getAttribute("aria-label")).toBe(props.title);
      } finally {
        dom.window.close();
      }
    }
  },
);
