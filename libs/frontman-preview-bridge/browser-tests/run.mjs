import {createServer} from "node:http"
import {mkdtemp, readFile, rm} from "node:fs/promises"
import {tmpdir} from "node:os"
import {join} from "node:path"
import {build} from "vite"
import {chromium} from "playwright"

const host = "127.0.0.1"
const parentPort = 4173
const childPort = 4174
const attackerPort = 4175
const outputDirectory = await mkdtemp(join(tmpdir(), "frontman-preview-bridge-"))

const assert = (condition, message) => {
	if (!condition) throw new Error(message)
}

const listen = (port, render) => new Promise(resolve => {
	const server = createServer((request, response) => {
		const body = render(request.url)
		response.writeHead(body === undefined ? 404 : 200, {
			"content-type": request.url.endsWith(".js") ? "text/javascript" : "text/html",
		})
		response.end(body ?? "Not found")
	})
	server.listen(port, host, () => resolve(server))
})

const closeServer = server => new Promise((resolve, reject) => {
	server.close(error => error === undefined ? resolve() : reject(error))
})

const bootstrap = (channel = "preview-task-id", marker = "@bluehotdog/reworker/window/v2") => `
const connection = new MessageChannel()
window.attackReady = false
connection.port1.onmessage = () => { window.attackReady = true }
window.attackAttempted = true
document.querySelector("iframe").contentWindow.postMessage({
	marker: ${JSON.stringify(marker)},
	kind: "connect",
	channel: ${JSON.stringify(channel)},
}, "http://${host}:${childPort}", [connection.port2])`

const childHtml = `<!doctype html>
<script>
window.bridgeListenerAdds = {message: 0, pagehide: 0}
window.bridgeListenerRemoves = {message: 0, pagehide: 0}
window.bridgeListeners = {message: new Set(), pagehide: new Set()}
window.bridgeDataPosts = 0
const addListener = window.addEventListener
const removeListener = window.removeEventListener
window.addEventListener = function(type, ...args) {
	if (type in window.bridgeListenerAdds) window.bridgeListenerAdds[type] += 1
	if (type in window.bridgeListeners) window.bridgeListeners[type].add(args[0])
	return addListener.call(this, type, ...args)
}
window.removeEventListener = function(type, ...args) {
	if (type in window.bridgeListenerRemoves) window.bridgeListenerRemoves[type] += 1
	if (type in window.bridgeListeners) window.bridgeListeners[type].delete(args[0])
	return removeListener.call(this, type, ...args)
}
const postMessage = MessagePort.prototype.postMessage
MessagePort.prototype.postMessage = function(message, ...args) {
	if (message?.kind === "data") window.bridgeDataPosts += 1
	return postMessage.call(this, message, ...args)
}
</script>
<script src="/bridge.js" data-frontman-parent-origin="http://${host}:${parentPort}" data-frontman-channel="preview-task-id"></script>
<script src="/bridge.js" data-frontman-parent-origin="http://${host}:${parentPort}" data-frontman-channel="preview-task-id"></script>`

const matchingParentHtml = `<!doctype html>
<iframe id="preview" src="http://${host}:${childPort}/child"></iframe>
<script>
document.querySelector("iframe").addEventListener("load", () => {
	const script = document.createElement("script")
	script.src = "/parent.js"
	document.body.append(script)
}, {once: true})
</script>`

const forgedParentHtml = (script) => `<!doctype html>
<iframe src="http://${host}:${childPort}/child"></iframe>
<script>document.querySelector("iframe").addEventListener("load", () => {${script}}, {once: true})</script>`

const wrongSourceHtml = `<!doctype html>
<iframe name="target" src="http://${host}:${childPort}/child"></iframe>
<iframe name="sender" src="/sender"></iframe>
<script>
window.attackReady = false
window.attackAttempted = false
let loaded = 0
for (const frame of document.querySelectorAll("iframe")) {
	frame.addEventListener("load", () => {
		loaded += 1
		if (loaded === 2) frames.sender.forge(frames.target)
	})
}
</script>`

const senderHtml = `<!doctype html><script>
window.forge = target => {
	const connection = new MessageChannel()
	connection.port1.onmessage = () => { parent.attackReady = true }
	parent.attackAttempted = true
	target.postMessage({
		marker: "@bluehotdog/reworker/window/v2",
		kind: "connect",
		channel: "preview-task-id",
	}, "http://${host}:${childPort}", [connection.port2])
}
</script>`

let browser
let servers = []

try {
	await build({
		configFile: false,
		logLevel: "silent",
		build: {
			lib: {
				entry: "test/ParentFixture.res.mjs",
				formats: ["iife"],
				name: "FrontmanParentFixture",
				fileName: () => "parent.js",
			},
			outDir: outputDirectory,
			emptyOutDir: true,
			minify: false,
		},
	})

	const parentBundle = await readFile(join(outputDirectory, "parent.js"))
	const bridgeBundle = await readFile("dist/bridge.js")
	servers = await Promise.all([
		listen(parentPort, path => {
			if (path === "/parent.js") return parentBundle
			if (path === "/sender") return senderHtml
			if (path === "/wrong-source") return wrongSourceHtml
			if (path === "/wrong-channel") return forgedParentHtml(bootstrap("wrong-channel"))
			if (path === "/wrong-marker") return forgedParentHtml(bootstrap("preview-task-id", "wrong-marker"))
			return matchingParentHtml
		}),
		listen(childPort, path => {
			if (path === "/bridge.js") return bridgeBundle
			if (path === "/missing-channel") return `<script src="/bridge.js" data-frontman-parent-origin="http://${host}:${parentPort}"></script>`
			if (path === "/empty-channel") return `<script src="/bridge.js" data-frontman-parent-origin="http://${host}:${parentPort}" data-frontman-channel=""></script>`
			if (path === "/empty-origin") return `<script src="/bridge.js" data-frontman-parent-origin="" data-frontman-channel="preview-task-id"></script>`
			if (path === "/wildcard-origin") return `<script src="/bridge.js" data-frontman-parent-origin="*" data-frontman-channel="preview-task-id"></script>`
			return childHtml
		}),
		listen(attackerPort, () => forgedParentHtml(bootstrap())),
	])

	browser = await chromium.launch({headless: true})
	const page = await browser.newPage()
	const pageErrors = []
	page.on("pageerror", error => pageErrors.push(error.message))
	await page.goto(`http://${host}:${parentPort}`)
	await page.waitForFunction(() => window.frontmanParentTest?.isOpen())

	const childFrame = page.frames().find(frame => frame.url().includes(`:${childPort}`))
	assert(childFrame !== undefined, "child frame was not found")
	assert(await childFrame.evaluate(() => JSON.stringify(window.bridgeListenerAdds)) === JSON.stringify({message: 1, pagehide: 2}), "duplicate bridge installation added listeners")
	assert(await childFrame.evaluate(() => window.bridgeDataPosts) === 0, "bridge sent an application readiness message")

	await childFrame.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pagehide", {persisted: true})))
	assert(await page.evaluate(() => window.frontmanParentTest.isOpen()), "BFCache transition closed runtime")

	const pendingResult = page.evaluate(async () => {
		const pending = window.frontmanParentTest.pending()
		try {
			await pending
			return "resolved"
		} catch (error) {
			return String(error)
		}
	})
	await childFrame.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pagehide", {persisted: false})))
	const disposalResult = await pendingResult
	assert(disposalResult !== "resolved", "page disposal did not reject pending work")
	assert(await page.evaluate(() => window.frontmanParentTest.isDisconnected()), "page disposal left parent runtime open")
	assert(await childFrame.evaluate(() => JSON.stringify(window.bridgeListenerRemoves)) === JSON.stringify({message: 1, pagehide: 2}), "page disposal did not remove bridge listeners")
	assert(await childFrame.evaluate(() => window.bridgeListeners.message.size === 0 && window.bridgeListeners.pagehide.size === 0), "page disposal left bridge listeners registered")
	assert(pageErrors.length === 0, `matching runtime emitted page errors: ${pageErrors.join(", ")}`)

	for (const [path, reason] of [
		[`http://${host}:${attackerPort}`, "wrong origin opened bridge"],
		[`http://${host}:${parentPort}/wrong-source`, "wrong source opened bridge"],
		[`http://${host}:${parentPort}/wrong-channel`, "wrong channel opened bridge"],
		[`http://${host}:${parentPort}/wrong-marker`, "wrong marker opened bridge"],
	]) {
		const invalidPage = await browser.newPage()
		await invalidPage.goto(path)
		await invalidPage.waitForFunction(() => window.attackAttempted)
		await invalidPage.waitForTimeout(700)
		assert(!await invalidPage.evaluate(() => window.attackReady), reason)
		await invalidPage.close()
	}

	for (const [path, expectedError] of [
		["missing-channel", "requires data-frontman-channel"],
		["empty-channel", "requires data-frontman-channel"],
		["empty-origin", "requires data-frontman-parent-origin"],
		["wildcard-origin", "must be an explicit origin"],
	]) {
		const invalidConfigPage = await browser.newPage()
		const errors = []
		invalidConfigPage.on("pageerror", error => errors.push(error.message))
		await invalidConfigPage.goto(`http://${host}:${childPort}/${path}`)
		await invalidConfigPage.waitForTimeout(50)
		assert(errors.some(error => error.includes(expectedError)), `invalid bootstrap configuration did not fail: ${path}`)
		await invalidConfigPage.close()
	}

	console.log("Frontman preview bridge browser tests passed")
} finally {
	if (browser !== undefined) await browser.close()
	await Promise.all(servers.map(closeServer))
	await rm(outputDirectory, {recursive: true, force: true})
}
