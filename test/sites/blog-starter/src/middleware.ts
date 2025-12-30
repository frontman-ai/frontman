import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export const config = {
	runtime: "nodejs",
};

const FRONTMAN_ENABLED = process.env.NODE_ENV === "development";

// Only load frontman in dev mode - completely safe in production
const frontmanMiddleware = FRONTMAN_ENABLED
	? await (async () => {
			const { createMiddleware } = await import(
				"@frontman/frontman-nextjs"
			);
			return createMiddleware({
				isDev: true,
				projectRoot: process.cwd(),
				basePath: "__frontman",
				serverName: "blog-starter",
				serverVersion: "1.0.0",
			});
		})()
	: null;

export default async function middleware(request: NextRequest) {
	if (frontmanMiddleware) {
		const response = await frontmanMiddleware(request);
		if (response) {
			return response;
		}
	}
	return NextResponse.next();
}
