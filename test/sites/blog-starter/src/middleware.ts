import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createMiddleware } from "@ask-the-llm/frontman-nextjs/src/FrontmanNextjs.res.mjs";

export const config = {
	runtime: "nodejs",
};

const frontmanMiddleware = createMiddleware({
	projectRoot: process.cwd(),
	basePath: "__frontman",
	serverName: "blog-starter",
	serverVersion: "1.0.0",
});

export default async function middleware(request: NextRequest) {
	const response = await frontmanMiddleware(request);
	if (response) {
		return response;
	}
	return NextResponse.next();
}
