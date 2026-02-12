import type {MiddlewareHandler} from "astro";
import { createMiddleware, makeConfig } from "@frontman/frontman-astro";
import path from "node:path";

const FRONTMAN_ENABLED = import.meta.env.DEV;

// Use import.meta.dirname for reliable path resolution
const appRoot = path.resolve(import.meta.dirname, "..");
// In a monorepo, sourceRoot should be the monorepo root since Astro's
// data-astro-source-file paths are relative to it
const monorepoRoot = path.resolve(appRoot, "../..");

const frontman = FRONTMAN_ENABLED
  ? createMiddleware(
      makeConfig({
	projectRoot: appRoot,
	sourceRoot: monorepoRoot,
	basePath: "frontman",
	serverName: "marketing",
	serverVersion: "1.0.0",
      })
    )
  : null;

export const onRequest: MiddlewareHandler = async (context, next) => {
	if (frontman) {
	  return frontman(context, next);
	}
	return next();
};
