// Rehype plugin that prepends an HTML comment with the content file path.
//
// Astro's compiler adds data-astro-source-file to .astro template elements,
// but markdown content goes through unified (remark→rehype→stringify) and gets
// no source attribution. This plugin bridges the gap by injecting a comment
// that the Frontman annotation capture script can read as a fallback.
//
// The comment follows the same pattern as __frontman_props__ comments:
//   <!-- __frontman_content_file__:src/content/docs/page.md -->

export function rehypeContentFile(options) {
  var raw = (options && options.projectRoot) || '';
  // Astro's resolved config.root is a URL object — coerce to a filesystem path.
  var projectRoot = typeof raw === 'string' ? raw : raw.pathname || '';
  // Normalize: strip trailing slash for consistent path.relative behavior
  if (projectRoot.endsWith('/')) {
    projectRoot = projectRoot.slice(0, -1);
  }

  return function transformer(tree, file) {
    if (!file || !file.path) {
      return;
    }

    var absolute = file.path;
    var relative = absolute;
    if (projectRoot && absolute.startsWith(projectRoot + '/')) {
      relative = absolute.slice(projectRoot.length + 1);
    }

    var comment = {
      type: 'comment',
      value: ' __frontman_content_file__:' + relative + ' '
    };

    tree.children.unshift(comment);
  };
}
