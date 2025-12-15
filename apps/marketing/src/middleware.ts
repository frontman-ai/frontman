import { sequence } from "astro:middleware";
import { createMiddleware, makeConfig } from "@ask-the-llm/frontman-astro";
import path from "node:path";

const FRONTMAN_ENABLED = import.meta.env.DEV;

// Astro provides paths relative to monorepo root (e.g., "apps/marketing/src/...")
// so projectRoot needs to be the monorepo root, not the app directory
const monorepoRoot = path.resolve(process.cwd(), "../..");

const frontman = FRONTMAN_ENABLED
  ? createMiddleware(
      makeConfig(
        monorepoRoot,
        "__frontman",
        "marketing",
        "1.0.0"
      )
    )
  : null;

export const onRequest = sequence(async (context, next) => {
  if (frontman) {
    return frontman(context, next);
  }
  return next();
});
