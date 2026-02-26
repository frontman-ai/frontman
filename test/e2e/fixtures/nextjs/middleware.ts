import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

export const config = {
	runtime: "nodejs",
};

// Dynamically import @frontman-ai/nextjs to avoid bundling Node.js modules
// into Edge Runtime. This mirrors the pattern from test/sites/blog-starter.
const frontmanMiddleware = await (async () => {
	const { createMiddleware } = await import("@frontman-ai/nextjs");
	return createMiddleware({
		host: "localhost:4002",
	});
})();

export default async function middleware(req: NextRequest) {
	const response = await frontmanMiddleware(req);
	if (response) return response;
	return NextResponse.next();
}
