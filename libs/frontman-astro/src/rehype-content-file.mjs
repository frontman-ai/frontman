import { relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

// Rehype plugin that prepends an inert template with the content file path.
//
// Astro's compiler adds data-astro-source-file to .astro template elements,
// but markdown content goes through unified (remark→rehype→stringify) and gets
// no source attribution. This plugin bridges the gap by injecting a marker
// that the Frontman annotation capture script can read as a fallback.
//
// The marker survives both Markdown and MDX rendering:
//   <template data-frontman-content-file="src/content/docs/page.md"></template>

export function rehypeContentFile(options) {
  var raw = (options && options.projectRoot) || '';
  var projectRoot = raw instanceof URL ? fileURLToPath(raw) : raw;

  return function transformer(tree, file) {
    if (!file || !file.path) {
      return;
    }

    var contentFile = projectRoot ? relative(projectRoot, file.path) : file.path;
    if (sep !== '/') contentFile = contentFile.split(sep).join('/');

    var marker = {
      type: 'element',
      tagName: 'template',
      properties: {'data-frontman-content-file': contentFile},
      children: []
    };

    tree.children.unshift(marker);
  };
}
