import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

export async function proxy(request: NextRequest): Promise<NextResponse> {
	if (process.env.NODE_ENV !== "development") {
		return NextResponse.next();
	}

	const { createMiddleware } = await import("@frontman-ai/nextjs");
	const entrypoint = process.env.NEXTJS_URL
		? new URL(process.env.NEXTJS_URL)
		: undefined;
	if (entrypoint) {
		entrypoint.pathname = request.nextUrl.pathname.replace(/\/frontman\/?$/i, "/");
		entrypoint.search = "";
		entrypoint.hash = "";
	}
	const frontman = createMiddleware({
		isDev: true,
		projectRoot: process.cwd(),
		basePath: "frontman",
		serverName: "blog-starter",
		serverVersion: "1.0.0",
		entrypointUrl: entrypoint?.href,
	});

	const response = await frontman(request);
	if (response) {
		return response;
	}

	return NextResponse.next();
}

export const config = {
	matcher: ["/frontman", "/frontman/:path*", "/:path*/frontman", "/:path*/frontman/"],
};
