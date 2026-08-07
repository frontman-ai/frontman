
export function hasProperImport(content, modulePath) {
  const escaped = modulePath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const staticRe = new RegExp(
    "import\\s*\\{[^}]+\\}\\s*from\\s*['\"]" + escaped + "['\"]"
  );
  const dynamicRe = new RegExp(
    "import\\s*\\(\\s*['\"]" + escaped + "['\"]\\s*\\)"
  );
  return staticRe.test(content) || dynamicRe.test(content);
}

export function hasHostInConfig(content, host) {
  const escaped = host.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(
    "createMiddleware\\s*\\(\\s*\\{[^}]*host\\s*:\\s*['\"]" +
      escaped +
      "['\"][^}]*\\}\\s*\\)"
  );
  return re.test(content);
}

export function hasMatcherWithFrontman(content, existingRoute) {
  const matcherMatch = content.match(/matcher\s*:\s*\[([^\]]+)\]/);
  if (!matcherMatch) return false;
  const matcherContent = matcherMatch[1];
  return (
    matcherContent.includes("/frontman") &&
    matcherContent.includes(existingRoute)
  );
}

export function hasExportFunction(content, funcName) {
  const re = new RegExp(
    "export\\s+(async\\s+)?function\\s+" + funcName + "\\s*\\("
  );
  return re.test(content);
}
