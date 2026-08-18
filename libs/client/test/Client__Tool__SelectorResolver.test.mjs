import { beforeEach, expect, it } from "vitest";
import { resolveBySelector } from "../src/tools/Client__Tool__SelectorResolver.res.mjs";

beforeEach(() => {
	document.body.innerHTML = "";
});

it("returns indexed CSS matches and their total count", () => {
	document.body.innerHTML =
		'<button class="action"></button><button class="action"></button>';
	const actions = document.querySelectorAll(".action");

	expect(resolveBySelector(document, ".action", 1)).toEqual([actions[1], 2]);
});

it("resolves indexed paths across nested open shadow roots", () => {
	const host = document.createElement("div");
	host.id = "outer-host";
	document.body.appendChild(host);
	host.attachShadow({ mode: "open" }).innerHTML =
		"<section><div></div></section>";
	const nestedHost = host.shadowRoot.querySelector("div");
	nestedHost.attachShadow({ mode: "open" }).innerHTML = "<button>Save</button>";

	const [button, count] = resolveBySelector(
		document,
		"#outer-host >>> 1/1 >>> 1",
		0,
	);

	expect(button).toBe(nestedHost.shadowRoot.querySelector("button"));
	expect(count).toBe(1);
});

it("returns no match when a shadow boundary is closed or missing", () => {
	document.body.innerHTML = '<div id="host"></div>';
	document.querySelector("#host").attachShadow({ mode: "closed" }).innerHTML =
		"<button></button>";

	expect(resolveBySelector(document, "#host >>> 1", 0)).toEqual([undefined, 0]);
});

it("excludes non-element XPath results", () => {
	document.body.innerHTML = "<div>Text node</div>";

	expect(resolveBySelector(document, "//text()", 0)).toEqual([undefined, 0]);
});
