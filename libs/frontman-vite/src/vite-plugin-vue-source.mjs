// Vite plugin that enhances Vue SFC compiled output with source location info
// for Frontman's element selection feature.
//
// Vue 3 + @vitejs/plugin-vue sets `__file` on component options in dev mode,
// but does NOT include template line/column info. This plugin adds:
//   - `__frontman_templateLine`: the line number where <template> starts in the .vue SFC
//
// The client-side Vue detection module reads __file (from Vue) plus
// __frontman_templateLine (from this plugin) to resolve clicked elements
// to source locations in .vue files.
//
// This plugin is dev-only and runs after @vitejs/plugin-vue.

import { readFileSync } from 'node:fs';

/**
 * @returns {import('vite').Plugin}
 */
export function frontmanVueSourcePlugin() {
  return {
    name: 'frontman:vue-source',
    enforce: 'post',  // Run after @vitejs/plugin-vue has compiled the SFC
    apply: 'serve',   // Dev only — no overhead in production builds

    transform(code, id) {
      // Only process .vue main modules — skip sub-requests like
      // App.vue?vue&type=template&... or App.vue?vue&type=style&...
      if (!id.endsWith('.vue')) return null;
      if (id.includes('?')) return null;

      // Only process files compiled by @vitejs/plugin-vue (they set __file)
      if (!code.includes('__file')) return null;

      try {
        // Read the original .vue source to find <template> start line.
        // We need the original because `code` is the compiled JS output.
        const originalSource = readFileSync(id, 'utf-8');

        // Strip <script> and <style> blocks before searching so that
        // `<template>` inside template literals / comments doesn't match.
        // Replacement preserves newline count to keep line numbers correct.
        const stripped = originalSource.replace(
          /<(script|style)\b[\s\S]*?<\/\1>/gi,
          (m) => '\n'.repeat(m.split('\n').length - 1),
        );
        const templateMatch = stripped.match(/^<template[\s>]/m);
        if (!templateMatch) return null;

        // Count lines before <template> to get the 1-indexed line number.
        // Use `stripped` (not originalSource) because templateMatch.index
        // is relative to the stripped string.  Line count is preserved
        // since stripping replaces blocks with equal newline counts.
        const templateLine =
          stripped.slice(0, templateMatch.index).split('\n').length;

        // Inject __frontman_templateLine right after the __file assignment.
        // The compiled output contains a pattern like:
        //   _sfc_main.__file = "/absolute/path/to/Component.vue"
        // We capture the variable name (e.g. _sfc_main, __default__) so
        // the injection targets the correct component options object.
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
        // File read failed (e.g., virtual module) — log and skip
        console.warn(`[Frontman] Vue source plugin: failed to read ${id}:`, err.message);
        return null;
      }
    },
  };
}
