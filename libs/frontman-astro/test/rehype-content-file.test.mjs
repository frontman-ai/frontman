import { describe, test, expect } from 'vitest';
import { rehypeContentFile } from '../src/rehype-content-file.mjs';
import { unified } from 'unified';
import rehypeParse from 'rehype-parse';
import rehypeStringify from 'rehype-stringify';

function process(html, filePath, projectRoot) {
  const processor = unified()
    .use(rehypeParse, { fragment: true })
    .use(rehypeContentFile, { projectRoot })
    .use(rehypeStringify);

  const vfile = processor.processSync({ value: html, path: filePath });
  return String(vfile);
}

describe('rehypeContentFile', () => {
  test('prepends inert content file marker with relative path', () => {
    const result = process(
      '<p>Hello</p>',
      '/home/user/project/src/content/docs/guide.md',
      '/home/user/project'
    );
    expect(result).toContain('<template data-frontman-content-file="src/content/docs/guide.md"></template>');
    expect(result).toContain('<p>Hello</p>');
  });

  test('marker appears before content', () => {
    const result = process(
      '<h1>Title</h1><p>Body</p>',
      '/home/user/project/src/docs/page.md',
      '/home/user/project'
    );
    const markerIdx = result.indexOf('data-frontman-content-file');
    const h1Idx = result.indexOf('<h1>');
    expect(markerIdx).toBeLessThan(h1Idx);
  });

  test('no-op when file.path is undefined', () => {
    const processor = unified()
      .use(rehypeParse, { fragment: true })
      .use(rehypeContentFile, { projectRoot: '/home/user/project' })
      .use(rehypeStringify);

    const vfile = processor.processSync('<p>Hello</p>');
    const result = String(vfile);
    expect(result).not.toContain('data-frontman-content-file');
    expect(result).toContain('<p>Hello</p>');
  });

  test('handles trailing slash on projectRoot', () => {
    const result = process(
      '<p>Hi</p>',
      '/home/user/project/src/content/docs/page.md',
      '/home/user/project/'
    );
    expect(result).toContain('<template data-frontman-content-file="src/content/docs/page.md"></template>');
  });

  test('handles URL object as projectRoot (Astro config.root)', () => {
    const result = process(
      '<p>Hi</p>',
      '/home/user/project/src/content/docs/page.md',
      new URL('file:///home/user/project/')
    );
    expect(result).toContain('<template data-frontman-content-file="src/content/docs/page.md"></template>');
  });

  test('does not confuse project root prefixes', () => {
    const result = process(
      '<p>Hi</p>',
      '/home/user/project-copy/src/page.md',
      '/home/user/project'
    );

    expect(result).toContain('data-frontman-content-file="../project-copy/src/page.md"');
  });
});
