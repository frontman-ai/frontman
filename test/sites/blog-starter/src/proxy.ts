import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

export async function proxy(request: NextRequest): Promise<NextResponse> {
	if (process.env.NODE_ENV !== "development") {
		return NextResponse.next();
	}

	const { createMiddleware } = await import("@frontman-ai/nextjs");
	const frontman = createMiddleware({
		isDev: true,
		projectRoot: process.cwd(),
		basePath: "frontman",
		serverName: "blog-starter",
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
