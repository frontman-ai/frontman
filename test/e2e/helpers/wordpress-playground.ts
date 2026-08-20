import { type ChildProcess, spawn } from "node:child_process";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dirname, "../../..");
const E2E = resolve(ROOT, "test/e2e");

export const PLAYGROUND_PORT = 9410;
export const PLAYGROUND_SCOPE = "/scope:frontman-playground";
export const PLAYGROUND_ORIGIN = `http://127.0.0.1:${PLAYGROUND_PORT}`;
export const PLAYGROUND_BASE_URL = `${PLAYGROUND_ORIGIN}${PLAYGROUND_SCOPE}`;

export interface PlaygroundServer {
	process: ChildProcess;
	output: string;
}

export interface PlaygroundSession {
	cookie: string;
	nonce: string;
}

function cookiesFrom(response: Response, cookies: Map<string, string>): void {
	for (const header of response.headers.getSetCookie()) {
		const pair = header.split(";", 1)[0];
		const separator = pair.indexOf("=");
		if (separator > 0)
			cookies.set(pair.slice(0, separator), pair.slice(separator + 1));
	}
}

function cookieHeader(cookies: Map<string, string>): string {
	return [...cookies.entries()]
		.map(([name, value]) => `${name}=${value}`)
		.join("; ");
}

async function authenticatedGet(
	path: string,
	cookies: Map<string, string>,
): Promise<{ response: Response; cookie: string }> {
	let url = `${PLAYGROUND_BASE_URL}${path}`;
	for (let redirects = 0; redirects <= 8; redirects += 1) {
		const response = await fetch(url, {
			headers: cookies.size > 0 ? { Cookie: cookieHeader(cookies) } : {},
			redirect: "manual",
		});
		cookiesFrom(response, cookies);
		if (response.status < 300 || response.status >= 400) {
			return { response, cookie: cookieHeader(cookies) };
		}
		const location = response.headers.get("location");
		if (!location)
			throw new Error("Playground login redirect omitted Location");
		url = new URL(location, url).toString();
	}
	throw new Error("Playground login exceeded eight redirects");
}

export async function startPlayground(): Promise<PlaygroundServer> {
	const args = [
		"wp-playground-cli",
		"server",
		`--port=${PLAYGROUND_PORT}`,
		`--site-url=${PLAYGROUND_BASE_URL}`,
		"--wp=7.0",
		"--php=8.4",
		"--workers=1",
		`--blueprint=${resolve(E2E, "fixtures/wordpress-playground/blueprint.json")}`,
		`--mount=${resolve(ROOT, "dist/frontman-wordpress-package/github/frontman-agentic-ai-editor")}:/wordpress/wp-content/plugins/frontman-agentic-ai-editor`,
		"--verbosity=normal",
	];
	const child = spawn("yarn", args, {
		cwd: E2E,
		env: process.env,
		stdio: ["ignore", "pipe", "pipe"],
	});
	const server: PlaygroundServer = { process: child, output: "" };

	await new Promise<void>((resolveReady, reject) => {
		const timer = setTimeout(() => {
			child.kill("SIGKILL");
			reject(
				new Error(
					`Playground did not start within 120 seconds\n${server.output}`,
				),
			);
		}, 120_000);
		const receive = (chunk: Buffer) => {
			server.output += chunk.toString();
			if (server.output.includes("Ready! WordPress is running")) {
				clearTimeout(timer);
				resolveReady();
			}
		};
		child.stdout?.on("data", receive);
		child.stderr?.on("data", receive);
		child.once("error", (error) => {
			clearTimeout(timer);
			reject(error);
		});
		child.once("exit", (code) => {
			clearTimeout(timer);
			reject(
				new Error(
					`Playground exited before readiness with ${code}\n${server.output}`,
				),
			);
		});
	});

	return server;
}

export async function stopPlayground(server: PlaygroundServer): Promise<void> {
	if (server.process.exitCode !== null) return;
	server.process.kill("SIGTERM");
	const exited = new Promise<boolean>((resolveExit) => {
		const timer = setTimeout(() => resolveExit(false), 5000);
		server.process.once("exit", () => {
			clearTimeout(timer);
			resolveExit(true);
		});
	});
	if (!(await exited)) {
		server.process.kill("SIGKILL");
		await new Promise<void>((resolveExit) =>
			server.process.once("exit", () => resolveExit()),
		);
	}
}

export async function createPlaygroundSession(): Promise<PlaygroundSession> {
	const cookies = new Map<string, string>();
	const loginPage = await fetch(`${PLAYGROUND_BASE_URL}/wp-login.php`, {
		redirect: "manual",
	});
	cookiesFrom(loginPage, cookies);
	const loginResponse = await fetch(`${PLAYGROUND_BASE_URL}/wp-login.php`, {
		method: "POST",
		headers: {
			Cookie: cookieHeader(cookies),
			"Content-Type": "application/x-www-form-urlencoded",
		},
		body: new URLSearchParams({
			log: "admin",
			pwd: "password",
			redirect_to: `${PLAYGROUND_BASE_URL}/wp-admin/`,
			testcookie: "1",
		}),
		redirect: "manual",
	});
	cookiesFrom(loginResponse, cookies);
	const login = await authenticatedGet("/wp-admin/", cookies);
	if (login.response.status !== 200) {
		throw new Error(`Playground login returned ${login.response.status}`);
	}
	const frontman = await fetch(`${PLAYGROUND_BASE_URL}/frontman`, {
		headers: { Cookie: login.cookie },
		redirect: "manual",
	});
	if (frontman.status !== 200) {
		throw new Error(`Playground Frontman page returned ${frontman.status}`);
	}
	const html = await frontman.text();
	const nonce = html.match(/data-wp-nonce="([^"]+)"/)?.[1];
	if (!nonce) {
		throw new Error(
			`Playground Frontman page omitted its MCP nonce: ${frontman.status} ${frontman.headers.get("location") ?? ""} ${html.slice(0, 300)}`,
		);
	}
	return { cookie: login.cookie, nonce };
}
