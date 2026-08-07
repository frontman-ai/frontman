
import { readFileSync } from 'node:fs';

export function frontmanVueSourcePlugin() {
  return {
    name: 'frontman:vue-source',
    enforce: 'post',
    apply: 'serve',

    transform(code, id) {
      if (!id.endsWith('.vue')) return null;
      if (id.includes('?')) return null;

      if (!code.includes('__file')) return null;

      try {
        const originalSource = readFileSync(id, 'utf-8');

        const stripped = originalSource.replace(
          /<(script|style)\b[\s\S]*?<\/\1>/gi,
          (m) => '\n'.repeat(m.split('\n').length - 1),
        );
        const templateMatch = stripped.match(/^<template[\s>]/m);
        if (!templateMatch) return null;

        const templateLine =
          stripped.slice(0, templateMatch.index).split('\n').length;

        const fileAssignPattern = /(\w+)\.__file\s*=\s*"[^"]*"/;
        const varMatch = code.match(fileAssignPattern);
        if (!varMatch) {
          console.warn(`[Frontman] Vue source plugin: no __file assignment found in compiled output for ${id}`);
          return null;
        }

        const varName = varMatch[1];
        const transformed = code.replace(
          fileAssignPattern,
          `$&\n${varName}.__frontman_templateLine = ${templateLine}`
        );

        return { code: transformed, map: null };
      } catch (err) {
        console.warn(`[Frontman] Vue source plugin: failed to read ${id}:`, err.message);
        return null;
      }
    },
  };
}
