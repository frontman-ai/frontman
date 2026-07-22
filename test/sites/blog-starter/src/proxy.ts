import { createMiddleware } from "@frontman-ai/nextjs";
import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const frontman = createMiddleware({
	isDev: true,
	projectRoot: process.cwd(),
	basePath: "frontman",
	serverName: "blog-starter",
	serverVersion: "1.0.0",
});

export async function proxy(request: NextRequest): Promise<NextResponse> {
	const response = await frontman(request);
	if (response) {
		return response;
	}

	return NextResponse.next();
}

export const config = {
	matcher: ["/frontman", "/frontman/:path*", "/:path*/frontman", "/:path*/frontman/"],
};
