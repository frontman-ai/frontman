// Annotation capture script — injected into the browser via injectScript("head-inline").
//
// Exported as a string because Astro's injectScript API takes raw JS code,
// not a module reference. This runs in the user's browser as an inline <script>.
//
// Reads Astro's data-astro-source-file/loc attributes and __frontman_props__
// HTML comments, then stores them on window.__frontman_annotations__ for
// the Frontman client to consume.
//
// Timing: Astro's dev toolbar strips data-astro-source-* attributes inside a
// DOMContentLoaded handler registered by a <script type="module">. This script
// is an inline <script> in <head>, so it parses and registers its
// DOMContentLoaded listener before the module script even starts loading.
// Since DOMContentLoaded listeners fire in registration order, we capture
// annotations before the toolbar strips them.
//
// Also re-captures on Astro View Transitions (SPA navigations) via astro:page-load.

export const annotationCaptureScript = `(function() {
  var PROPS_PREFIX = '__frontman_props__:';

  function parsePropsPayload(text) {
    text = text.trim();
    if (text.indexOf(PROPS_PREFIX) !== 0) return null;
    try {
      var encoded = text.slice(PROPS_PREFIX.length).trim();
      return JSON.parse(atob(encoded));
    } catch(e) {
      return null;
    }
  }

  function captureAnnotations() {
    var annotations = new Map();
    var propsMap = new Map();
    var pendingProps = [];

    var walker = document.createTreeWalker(
      document.documentElement,
      NodeFilter.SHOW_COMMENT | NodeFilter.SHOW_ELEMENT,
      null
    );

    var node;
    while (node = walker.nextNode()) {
      if (node.nodeType === 8) {
        var parsed = parsePropsPayload(node.textContent);
        if (parsed) {
          pendingProps.push(parsed);
        }
      } else if (node.nodeType === 1) {
        if (pendingProps.length > 0 && node.hasAttribute('data-astro-source-file')) {
          propsMap.set(node, pendingProps.slice());
          pendingProps = [];
        }
      }
    }

    document.querySelectorAll('[data-astro-source-file]').forEach(function(el) {
      var sourceFile = el.getAttribute('data-astro-source-file');
      var annotation = {
        file: sourceFile,
        loc: el.getAttribute('data-astro-source-loc')
      };

      var propsChain = propsMap.get(el);

      if (!propsChain) {
        var parent = el.parentElement;
        var maxSteps = 30;
        while (parent && maxSteps-- > 0) {
          propsChain = propsMap.get(parent);
          if (propsChain) break;
          parent = parent.parentElement;
        }
      }

      if (propsChain && propsChain.length > 0) {
        var match = null;
        for (var i = 0; i < propsChain.length; i++) {
          var entry = propsChain[i];
          if (entry.moduleId) {
            var entryFile = entry.moduleId.split('/').pop() || '';
            var srcFile = sourceFile.split('/').pop() || '';
            if (entryFile === srcFile && entryFile !== '') {
              match = entry;
              break;
            }
          }
        }
        if (!match) match = propsChain[0];

        if (match) {
          annotation.componentProps = match.props || null;
          if (match.displayName) {
            annotation.displayName = match.displayName;
          }
        }
      }

      annotations.set(el, annotation);
    });

    window.__frontman_annotations__ = {
      _map: annotations,
      get: function(el) { return annotations.get(el); },
      has: function(el) { return annotations.has(el); },
      size: function() { return annotations.size; }
    };
  }

  document.addEventListener('DOMContentLoaded', captureAnnotations);

  var initialLoad = true;
  document.addEventListener('astro:page-load', function() {
    if (initialLoad) { initialLoad = false; return; }
    captureAnnotations();
  });
})();`;
