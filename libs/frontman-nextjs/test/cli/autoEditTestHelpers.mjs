// Verification helpers for auto-edit LLM integration tests
// These live in a separate .mjs file because the regex patterns
// contain } characters that conflict with ReScript's %raw() parser.

/**
 * Verify that a proper import statement exists (not just a substring match).
 * Matches static imports: import { ... } from 'modulePath'
 * Also matches dynamic imports: await import('modulePath')
 */
export function hasProperImport(content, modulePath) {
  const escaped = modulePath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  // Check static import
  const staticRe = new RegExp(
    "import\\s*\\{[^}]+\\}\\s*from\\s*['\"]" + escaped + "['\"]"
  );
  // Check dynamic import: await import('modulePath') or import('modulePath')
  const dynamicRe = new RegExp(
    "import\\s*\\(\\s*['\"]" + escaped + "['\"]\\s*\\)"
  );
  return staticRe.test(content) || dynamicRe.test(content);
}

/**
 * Verify that host string appears inside a createMiddleware({ host: '...' }) call.
 * Matches: createMiddleware({ host: 'thehost' }) with optional other properties.
 */
export function hasHostInConfig(content, host) {
  const escaped = host.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(
    "createMiddleware\\s*\\(\\s*\\{[^}]*host\\s*:\\s*['\"]" +
      escaped +
      "['\"][^}]*\\}\\s*\\)"
  );
  return re.test(content);
}

/**
 * Verify that the matcher config contains frontman routes alongside existing ones.
 * Finds the matcher: [...] array and checks both /frontman and the existing route are present.
 */
export function hasMatcherWithFrontman(content, existingRoute) {
  const matcherMatch = content.match(/matcher\s*:\s*\[([^\]]+)\]/);
  if (!matcherMatch) return false;
  const matcherContent = matcherMatch[1];
  return (
    matcherContent.includes("/frontman") &&
    matcherContent.includes(existingRoute)
  );
}

/**
 * Verify export function exists with the given name.
 * Matches: export function name( or export async function name(
 */
export function hasExportFunction(content, funcName) {
  const re = new RegExp(
    "export\\s+(async\\s+)?function\\s+" + funcName + "\\s*\\("
  );
  return re.test(content);
}
