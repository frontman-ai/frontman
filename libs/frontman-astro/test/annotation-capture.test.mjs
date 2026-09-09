import { runInNewContext } from 'node:vm';
import { describe, test, expect, vi } from 'vitest';
import { annotationCaptureScript } from '../src/annotation-capture.mjs';

function setup() {
  const document = new EventTarget();
  document.addEventListener = vi.fn(document.addEventListener.bind(document));
  document.createTreeWalker = vi.fn(() => ({ nextNode: () => null }));
  document.querySelectorAll = () => [];
  const window = {};
  const context = { window, document, NodeFilter: { SHOW_COMMENT: 128, SHOW_ELEMENT: 1 } };
  const install = () => runInNewContext(annotationCaptureScript, context);
  const dispatch = (phase, from, to) => {
    const event = new Event(`astro:${phase}`);
    if (from) event.from = new URL(from);
    if (to) event.to = new URL(to);
    document.dispatchEvent(event);
  };
  install();
  return { window, document, install, dispatch, state: window.__frontman_astro_navigation__ };
}

const from = 'https://example.com/start?tab=one#intro';
const to = 'https://example.com/next?tab=two#details';

describe('Astro navigation capture', () => {
  test('initial page load and unrelated completion events do not invent a navigation', () => {
    const { document, dispatch, state } = setup();
    document.dispatchEvent(new Event('DOMContentLoaded'));
    dispatch('page-load');
    dispatch('after-preparation');
    dispatch('after-swap');
    dispatch('page-load');
    expect(state.lastNavigation).toBeNull();
  });

  test('records every lifecycle phase, refreshed destination, and only the latest navigation', () => {
    const { dispatch, state } = setup();
    dispatch('page-load');
    dispatch('before-preparation', from, to);
    expect(state.lastNavigation).toEqual({ from, to, phase: 'astro:before-preparation' });
    dispatch('after-preparation');
    expect(state.lastNavigation).toEqual({ from, to, phase: 'astro:after-preparation' });

    const redirected = 'https://example.com/redirected';
    dispatch('before-swap', from, redirected);
    expect(state.lastNavigation).toEqual({ from, to: redirected, phase: 'astro:before-swap' });
    dispatch('after-swap');
    expect(state.lastNavigation).toEqual({ from, to: redirected, phase: 'astro:after-swap' });
    dispatch('page-load');
    expect(state.lastNavigation).toEqual({ from, to: redirected, phase: 'astro:page-load' });

    dispatch('before-preparation', redirected, from);
    expect(state.lastNavigation).toEqual({ from: redirected, to: from, phase: 'astro:before-preparation' });
  });

  test('page-load cannot complete a navigation that has not swapped', () => {
    const { dispatch, state } = setup();
    dispatch('before-preparation', from, to);
    dispatch('page-load');
    expect(state.lastNavigation.phase).toBe('astro:before-preparation');
    dispatch('before-swap', from, to);
    dispatch('after-swap');
    dispatch('page-load');
    expect(state.lastNavigation.phase).toBe('astro:page-load');
  });

  test('repeated injection preserves state and installs no duplicate listeners', () => {
    const { window, document, install, dispatch, state } = setup();
    document.dispatchEvent(new Event('DOMContentLoaded'));
    dispatch('page-load');
    const listeners = document.addEventListener.mock.calls.length;
    dispatch('before-preparation', from, to);
    const record = state.lastNavigation;
    install();
    expect(window.__frontman_astro_navigation__).toBe(state);
    expect(state.lastNavigation).toBe(record);
    expect(document.addEventListener).toHaveBeenCalledTimes(listeners);

    dispatch('before-swap', from, to);
    dispatch('after-swap');
    const annotations = window.__frontman_annotations__;
    dispatch('page-load');
    expect(state.lastNavigation.phase).toBe('astro:page-load');
    expect(window.__frontman_annotations__).toBe(annotations);
    expect(document.createTreeWalker).toHaveBeenCalledTimes(2);
    install();
    expect(state.lastNavigation.phase).toBe('astro:page-load');
    expect(document.addEventListener).toHaveBeenCalledTimes(listeners);
  });
});
