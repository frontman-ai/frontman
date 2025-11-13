import type { IncomingMessage, ServerResponse } from "node:http";
import type { Plugin } from "vite";
import {
	createUIHandler,
	createChatHandler,
	createStreamHandler,
	createToolResultsHandler,
} from "@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs";

/**
 * Helper to adapt Next.js API handlers to Vite middleware
 */
const adaptNextJsHandler = (handler: any) => {
	return async (req: IncomingMessage, res: ServerResponse) => {
		// Add status method to response for Next.js compatibility
		// @ts-ignore
		res.status = (status: number) => {
			res.statusCode = status;
			return res;
		};

		// Parse request body
		const body = await new Promise((resolve) => {
			let bodyStr = "";
			req.on("data", (chunk: Buffer) => {
				bodyStr += chunk.toString();
			});
			req.on("end", () => {
				try {
					resolve(bodyStr ? JSON.parse(bodyStr) : {});
				} catch {
					resolve({});
				}
			});
		});

		// Adapt the request to match Next.js API format by adding properties
		// We don't spread to preserve the IncomingMessage prototype methods
		// @ts-ignore
		req.query = Object.fromEntries(
			new URL(req.url || "", `http://${req.headers.host}`).searchParams,
		);
		// @ts-ignore
		req.body = body;

		await handler(req, res);
	};
};

export interface AskTheLlmPluginOptions {
	/**
	 * Whether to run in development mode
	 * @default process.env.NODE_ENV !== "production"
	 */
	isDev?: boolean;
	/**
	 * Whether to use light theme
	 * @default true
	 */
	isLightTheme?: boolean;
	/**
	 * Entrypoint URL for the API
	 * @default "http://localhost:3000/api/ask-the-llm"
	 */
	entrypointUrl?: string;
	/**
	 * Client URL for the API
	 * @default "http://localhost:5173/src/Main.js"
	 */
	clientUrl?: string;
}

/**
 * Vite plugin for integrating Ask-the-LLM API routes
 */
export const askTheLlmPlugin = (
	options: AskTheLlmPluginOptions = {},
): Plugin => {
	const {
		isDev = process.env.NODE_ENV !== "production",
		isLightTheme = true,
		entrypointUrl = "http://localhost:3000/api/ask-the-llm",
		clientUrl = "http://localhost:5173/src/Main.js",
	} = options;

	let uiHandler: any;
	let chatHandler: any;
	let streamHandler: any;
	let toolResultsHandler: any;

	return {
		name: "ask-the-llm-api-routes",
		configureServer(server) {
			uiHandler = createUIHandler({ isDev, isLightTheme, entrypointUrl, clientUrl });
			chatHandler = createChatHandler();
			streamHandler = createStreamHandler();
			toolResultsHandler = createToolResultsHandler();

			server.middlewares.use(
				async (
					req: IncomingMessage,
					res: ServerResponse,
					next: () => void,
				) => {
					const url = req.url || "";

					try {
						// Handle /api/ask-the-llm (exact match) - UI handler
						if (
							url === "/api/ask-the-llm" ||
							url.startsWith("/api/ask-the-llm?")
						) {
							await adaptNextJsHandler(uiHandler)(req, res);
							return;
						}

						// Handle /api/ask-the-llm/chat - Chat handler
						if (
							url === "/api/ask-the-llm/chat" ||
							url.startsWith("/api/ask-the-llm/chat?")
						) {
							await adaptNextJsHandler(chatHandler)(req, res);
							return;
						}

						// Handle /api/ask-the-llm/chat-sse - SSE stream handler
						if (
							url === "/api/ask-the-llm/chat-sse" ||
							url.startsWith("/api/ask-the-llm/chat-sse?")
						) {
							await adaptNextJsHandler(streamHandler)(req, res);
							return;
						}

						// Handle /api/ask-the-llm/tool-results - Tool results handler
						if (url === "/api/ask-the-llm/tool-results") {
							await adaptNextJsHandler(toolResultsHandler)(req, res);
							return;
						}

						// Not an API route, continue to next middleware
						next();
					} catch (error) {
						console.error("API route error:", error);
						res.statusCode = 500;
						res.end("Internal Server Error");
					}
				},
			);
		},
	};
};

