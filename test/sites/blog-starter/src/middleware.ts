import * as Config from "@ask-the-llm/nextjs/src/Nextjs__Config.res.mjs";
import { createMiddleware } from "@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs";
export const config = {
	runtime: "nodejs",
};
export default createMiddleware(Config.make());
