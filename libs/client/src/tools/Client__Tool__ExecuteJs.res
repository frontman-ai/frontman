// Client tool that evaluates arbitrary JavaScript in the preview iframe.
// Returns serialized results with captured console output.

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.executeJs
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Execute a JavaScript expression or statement(s) inside the web preview iframe and return the result.

Use this to:
- Query DOM properties: \`document.querySelector('.header').getBoundingClientRect()\`
- Measure layout: \`document.querySelectorAll('*').forEach(el => { ... })\`
- Navigate: \`location.href = '/about'\` or \`history.back()\`
- Read computed styles: \`getComputedStyle(document.body).overflow\`
- Run any JS that the page context supports

The expression is evaluated via \`new Function\` on the iframe's window. If the result is a Promise it is awaited (with a timeout). DOM nodes, NodeLists, Maps, Sets, and circular references are automatically serialized to a readable JSON representation. Console output (log/warn/error) during execution is captured in the \`logs\` array.

Output is capped at 30 KB.`

let maxOutputBytes = 30000

@schema
type input = {
  @s.describe("JavaScript code to evaluate. Can be an expression (e.g. `1+2`) or statements (e.g. `let x = 1; x`).")
  expression: string,
  @s.describe("Maximum execution time in milliseconds. Defaults to 5000.")
  timeout: option<int>,
}

@schema
type output = {
  @s.describe("Whether the execution completed without error")
  success: bool,
  @s.describe("JSON-serialized return value (absent on error)")
  result: option<string>,
  @s.describe("Error message if execution failed")
  error: option<string>,
  @s.describe("Captured console.log/warn/error output during execution")
  logs: array<string>,
}

// ---------------------------------------------------------------------------
// Raw JS helpers — kept small and isolated per CLAUDE.md guidelines
// ---------------------------------------------------------------------------

// Smart serializer: handles DOM nodes, NodeList, Map, Set, circular refs, depth limit
let smartSerialize: ('a, int) => string = %raw(`
  function smartSerialize(value, maxBytes) {
    var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : { add: function(){}, has: function(){ return false } };
    var depth = 0;
    var maxDepth = 5;

    function replacer(key, val) {
      if (val === undefined || val === null) return val;
      if (typeof val === 'function') return '[Function: ' + (val.name || 'anonymous') + ']';

      if (typeof val === 'object') {
        if (depth > maxDepth) return '[Object]';

        // Circular reference detection
        if (seen.has(val)) return '[Circular]';
        seen.add(val);
        depth++;

        // DOM Element
        if (val instanceof Element || val instanceof HTMLElement) {
          var repr = {
            __type: 'Element',
            tag: val.tagName,
            id: val.id || undefined,
            className: val.className || undefined,
            textContent: (val.textContent || '').slice(0, 80) || undefined
          };
          depth--;
          return repr;
        }

        // NodeList / HTMLCollection
        if (val instanceof NodeList || val instanceof HTMLCollection) {
          var arr = Array.from(val);
          depth--;
          return arr;
        }

        // Map
        if (val instanceof Map) {
          var entries = [];
          val.forEach(function(v, k) { entries.push([k, v]); });
          depth--;
          return { __type: 'Map', entries: entries };
        }

        // Set
        if (val instanceof Set) {
          depth--;
          return { __type: 'Set', values: Array.from(val) };
        }

        depth--;
      }
      return val;
    }

    var json = JSON.stringify(value, replacer);
    if (json && json.length > maxBytes) {
      return json.slice(0, maxBytes) + '...[truncated]';
    }
    return json || 'undefined';
  }
`)

// Execute JS in the given window context, capturing console output.
// Returns {success, result, error, logs}.
let executeInWindow: (WebAPI.DOMAPI.window, string, int, int) => promise<output> = %raw(`
  function executeInWindow(win, expression, timeoutMs, maxBytes) {
    var logs = [];
    var origLog = win.console.log;
    var origWarn = win.console.warn;
    var origError = win.console.error;

    function capture(level, args) {
      try {
        var parts = [];
        for (var i = 0; i < args.length; i++) {
          parts.push(typeof args[i] === 'string' ? args[i] : JSON.stringify(args[i]));
        }
        logs.push('[' + level + '] ' + parts.join(' '));
      } catch (e) {
        logs.push('[' + level + '] [unserializable]');
      }
    }

    win.console.log = function() { capture('log', arguments); origLog.apply(win.console, arguments); };
    win.console.warn = function() { capture('warn', arguments); origWarn.apply(win.console, arguments); };
    win.console.error = function() { capture('error', arguments); origError.apply(win.console, arguments); };

    function restore() {
      win.console.log = origLog;
      win.console.warn = origWarn;
      win.console.error = origError;
    }

    function serialize(val) {
      return smartSerialize(val, maxBytes);
    }

    var result;
    try {
      // Try as expression first (most common case)
      try {
        var fn = new win.Function('return (' + expression + ')');
        result = fn.call(win);
      } catch (syntaxErr) {
        // Fall back to statement mode
        var fn2 = new win.Function(expression);
        result = fn2.call(win);
      }
    } catch (execErr) {
      restore();
      return Promise.resolve({
        success: false,
        result: undefined,
        error: execErr.message || String(execErr),
        logs: logs
      });
    }

    // If result is a thenable, race against timeout
    if (result && typeof result.then === 'function') {
      var timer;
      var timeoutPromise = new Promise(function(_, reject) {
        timer = setTimeout(function() { reject(new Error('Execution timed out after ' + timeoutMs + 'ms')); }, timeoutMs);
      });
      return Promise.race([result, timeoutPromise]).then(
        function(resolved) {
          clearTimeout(timer);
          restore();
          return { success: true, result: serialize(resolved), error: undefined, logs: logs };
        },
        function(err) {
          clearTimeout(timer);
          restore();
          return { success: false, result: undefined, error: err.message || String(err), logs: logs };
        }
      );
    }

    restore();
    return Promise.resolve({
      success: true,
      result: serialize(result),
      error: undefined,
      logs: logs
    });
  }
`)

let execute = async (input: input, ~taskId as _: string, ~toolCallId as _: string): toolResult<output> => {
  let state = StateStore.getState(Client__State__Store.store)
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)

  switch previewFrame.contentWindow {
  | None =>
    Ok({success: false, result: None, error: Some("Preview frame not available"), logs: []})
  | Some(win) =>
    let timeout = input.timeout->Option.getOr(5000)
    let output = await executeInWindow(win, input.expression, timeout, maxOutputBytes)
    Ok(output)
  }
}
