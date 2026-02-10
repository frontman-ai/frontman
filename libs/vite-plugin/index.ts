import type { IncomingMessage, ServerResponse } from "node:http";
import type { Plugin } from "vite";
import { createMiddleware } from "@frontman/nextjs/src/Vite__Middleware.res.mjs";
import { make as makeConfig } from "@frontman/nextjs/src/Nextjs__Config.res.mjs";

/**
 * Helper to adapt middleware (Web API Request/Response) to Vite middleware (Node.js IncomingMessage/ServerResponse)
 * The middleware returns option<Response> - None means pass through, Some(response) means handle it
 */
const adaptMiddlewareToVite = (middleware: any) => {
	return async (req: IncomingMessage, res: ServerResponse, next: () => void) => {
		// Parse request body
		const bodyChunks: Buffer[] = [];
		for await (const chunk of req) {
			bodyChunks.push(chunk);
		}
		const bodyBuffer = Buffer.concat(bodyChunks);
		
		// Create Web API Request from Node.js IncomingMessage
		const url = `http://${req.headers.host || "localhost"}${req.url || ""}`;
		const webRequest = new Request(url, {
			method: req.method || "GET",
			headers: req.headers as Record<string, string>,
			body: bodyBuffer.length > 0 ? bodyBuffer : undefined,
		});

		// Call the middleware with Web API Request
		const webResponseOption = await middleware(webRequest);

		// If middleware returns None, pass through to next middleware
		if (webResponseOption === null || webResponseOption === undefined) {
			next();
			return;
		}

		// Convert Web API Response to Node.js ServerResponse
		const webResponse = webResponseOption;
		res.statusCode = webResponse.status;
		
		// Set headers
		webResponse.headers.forEach((value: string, key: string) => {
			res.setHeader(key, value);
		});

		// Handle streaming response (for SSE)
		if (webResponse.body) {
			const reader = webResponse.body.getReader();
			try {
				while (true) {
					const { done, value } = await reader.read();
					if (done) break;
					res.write(value);
				}
			} finally {
				reader.releaseLock();
			}
		}

		res.end();
	};
};

export interface FrontmanPluginOptions {
	/**
	 * Whether to run in development mode
	 * @default process.env.NODE_ENV !== "production"
	 */
	isDev?: boolean;
	/**
	 * Base path for the middleware routes
	 * @default "frontman"
	 */
	basePath?: string;
	/**
	 * URL to the client JavaScript bundle
	 * @default "http://localhost:5173/src/Main.res.mjs" (dev) or "https://frontman.dev/frontman.es.js" (prod)
	 */
	clientUrl?: string;
	/**
	 * URL to the client CSS stylesheet (optional)
	 */
	clientCssUrl?: string;
	/**
	 * Entrypoint URL for the API (optional)
	 * Will be injected as a template script tag with id "frontman-entrypoint-url"
	 */
	entrypointUrl?: string;
	/**
	 * Whether to use light theme instead of dark theme
	 * @default false (dark theme)
	 */
	isLightTheme?: boolean;
}

/**
 * Vite plugin for integrating Frontman middleware
 */
export const frontmanPlugin = (
	options: FrontmanPluginOptions = {},
): Plugin => {
	const {
		isDev = process.env.NODE_ENV !== "production",
		basePath = "frontman",
		clientUrl,
		clientCssUrl,
		entrypointUrl,
		isLightTheme,
	} = options;

	let middleware: any;

	return {
		name: "frontman-middleware",
		configureServer(server) {
			// Create the config and middleware
			const config = makeConfig(isDev, basePath, clientUrl, clientCssUrl, entrypointUrl, isLightTheme);
			middleware = createMiddleware(config);
			const adaptedMiddleware = adaptMiddlewareToVite(middleware);

			server.middlewares.use(
				async (
					req: IncomingMessage,
					res: ServerResponse,
					next: () => void,
				) => {
					try {
						// The adapted middleware handles pass-through internally
						await adaptedMiddleware(req, res, next);
					} catch (error) {
						console.error("Middleware error:", error);
						res.statusCode = 500;
						res.end("Internal Server Error");
					}
				},
			);
		},
	};
};

