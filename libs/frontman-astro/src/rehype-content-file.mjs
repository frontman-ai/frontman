import { relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';


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
