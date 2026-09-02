import {beforeEach, expect, it} from "vitest"
import {
	executeWithDocument,
	resolveBySelector,
} from "../src/FrontmanPreviewBridge__DomSnapshot.res.mjs"

beforeEach(() => {
	document.body.innerHTML = ""
})

function simplified(selector, options = {}) {
	return executeWithDocument(
		{
			selector,
			mode: "simplified",
			maxDepth: options.maxDepth,
			maxNodes: options.maxNodes,
			pierceShadowDom: options.pierceShadowDom,
		},
		document,
	)
}

it("describes bounded context with navigable parent and child selectors", () => {
	document.body.innerHTML = `
		<main><div id="inspection-root">Root "text"<span>First</span><span>Second</span></div></main>
	`

	const result = simplified("#inspection-root", {maxDepth: 1, maxNodes: 20})

	expect(result.success).toBe(true)
	expect(result.html).toContain('parent tag="main" selector="main"')
	expect(document.querySelector("main")).toBe(
		document.querySelector("#inspection-root").parentElement,
	)
	expect(result.html).toContain('selected tag="div" id="inspection-root"')
	expect(result.html).toContain('text="Root \\"text\\""')
	expect(result.html).toContain('selector="#inspection-root > :nth-child(1)"')
	expect(
		document.querySelector("#inspection-root > :nth-child(1)").textContent,
	).toBe("First")
})

it("caps simplified context at 30 KB of UTF-8", () => {
	const repeated = "é".repeat(100)
	document.body.innerHTML = `<div id="inspection-root">${`<div class="${repeated}">${repeated}</div>`.repeat(199)}</div>`

	const result = simplified("#inspection-root", {maxDepth: 1, maxNodes: 200})

	expect(new TextEncoder().encode(result.html).byteLength).toBeLessThanOrEqual(
		30_000,
	)
	expect(result.hint).toContain("Output stopped")
	expect(result.html).toContain("truncated nodes=")
})

it("omits control values and URL secrets", () => {
	document.body.innerHTML = `
		<form id="inspection-root">
			<input type="password" value="password-secret">
			<input type="hidden" value="hidden-token">
			<textarea>textarea-secret</textarea>
			<a href="/account?token=url-secret#private">Account</a>
			<img src="/avatar?signature=image-secret" alt="Avatar">
			<a href="https://user:user-password@example.com/private">Private</a>
			<a href="//user:relative-password@example.com/private">Relative</a>
			<a href=" //user:spaced-password@example.com/private">Spaced</a>
			<img src="DATA:image/png;base64,image-data-secret" alt="Embedded">
		</form>
	`

	const result = simplified("#inspection-root", {maxDepth: 1, maxNodes: 200})

	for (const secret of [
		"password-secret",
		"hidden-token",
		"textarea-secret",
		"url-secret",
		"image-secret",
		"user-password",
		"relative-password",
		"spaced-password",
		"image-data-secret",
	]) {
		expect(result.html).not.toContain(secret)
	}
	expect(result.html).toContain('href="/account"')
	expect(result.html).toContain('src="/avatar"')
})

it("returns navigable selectors through open shadow roots", () => {
	const host = document.createElement("div")
	host.id = "shadow-host"
	document.body.appendChild(host)
	host.attachShadow({mode: "open"}).innerHTML = `
		<section><span></span><span id="nested-decoy"></span></section>
		<button id="shadow-action">Save</button>
	`

	const hostSelector = "#shadow-host"
	const result = simplified(hostSelector, {
		maxDepth: 2,
		maxNodes: 20,
		pierceShadowDom: true,
	})
	const withoutPiercing = simplified(hostSelector, {maxDepth: 1, maxNodes: 20})
	const nestedSelector = `${hostSelector} >>> 1/2`
	const buttonSelector = `${hostSelector} >>> 2`

	expect(withoutPiercing.html).not.toContain("shadow-action")
	for (const selector of [nestedSelector, buttonSelector]) {
		expect(result.html).toContain(`selector=${JSON.stringify(selector)}`)
		expect(resolveBySelector(document, selector)[0]).toBeTruthy()
	}
})

it("resolves indexed paths across nested open shadow roots", () => {
	const host = document.createElement("div")
	host.id = "outer-host"
	document.body.appendChild(host)
	host.attachShadow({mode: "open"}).innerHTML =
		"<section><div></div></section>"
	const nestedHost = host.shadowRoot.querySelector("div")
	nestedHost.attachShadow({mode: "open"}).innerHTML = "<button>Save</button>"

	const [button, count] = resolveBySelector(document, "#outer-host >>> 1/1 >>> 1")

	expect(button).toBe(nestedHost.shadowRoot.querySelector("button"))
	expect(count).toBe(1)
})

it("returns no match when a shadow boundary is closed or missing", () => {
	document.body.innerHTML = '<div id="host"></div>'
	document.querySelector("#host").attachShadow({mode: "closed"}).innerHTML =
		"<button></button>"

	expect(resolveBySelector(document, "#host >>> 1")).toEqual([undefined, 0])
})

it("excludes non-element XPath results", () => {
	document.body.innerHTML = "<div>Text node</div>"

	expect(resolveBySelector(document, "//text()")).toEqual([undefined, 0])
})
