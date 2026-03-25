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

// Smart serializer: handles DOM nodes, NodeList, Map, Set, circular refs, depth/breadth limit.
// Uses a recursive approach instead of JSON.stringify replacer for correct depth tracking.
let smartSerialize: ('a, int) => string = %raw(`
  function smartSerialize(value, maxBytes) {
    var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : { add: function(){}, has: function(){ return false } };
    var maxDepth = 5;
    var maxBreadth = 50;

    function isElement(val) {
      return val.nodeType === 1 && typeof val.tagName === 'string';
    }

    function isNodeList(val) {
      return typeof val.item === 'function' && typeof val.length === 'number' && !Array.isArray(val);
    }

    function isMap(val) {
      return typeof val.get === 'function' && typeof val.set === 'function'
        && typeof val.entries === 'function' && typeof val.size === 'number';
    }

    function isSet(val) {
      return typeof val.add === 'function' && typeof val.has === 'function'
        && typeof val.size === 'number' && typeof val.get !== 'function';
    }

    function serialize(val, depth) {
      if (val === undefined) return undefined;
      if (val === null) return null;
      if (typeof val === 'function') return '[Function: ' + (val.name || 'anonymous') + ']';
      if (typeof val !== 'object') return val;

      if (depth > maxDepth) return '[Object]';
      if (seen.has(val)) return '[Circular]';
      seen.add(val);

      if (isElement(val)) {
        return {
          __type: 'Element',
          tag: val.tagName,
          id: val.id || undefined,
          className: val.className || undefined,
          textContent: (val.textContent || '').slice(0, 80) || undefined
        };
      }

      if (isNodeList(val)) {
        var items = [];
        var nlLen = Math.min(val.length, maxBreadth);
        for (var i = 0; i < nlLen; i++) items.push(serialize(val[i], depth + 1));
        if (val.length > maxBreadth) items.push('...' + (val.length - maxBreadth) + ' more');
        return items;
      }

      if (isMap(val)) {
        var entries = [];
        var mapCount = 0;
        val.forEach(function(v, k) {
          if (mapCount < maxBreadth) entries.push([serialize(k, depth + 1), serialize(v, depth + 1)]);
          mapCount++;
        });
        var mapResult = { __type: 'Map', entries: entries };
        if (mapCount > maxBreadth) mapResult.truncated = mapCount - maxBreadth;
        return mapResult;
      }

      if (isSet(val)) {
        var values = [];
        var setCount = 0;
        val.forEach(function(v) {
          if (setCount < maxBreadth) values.push(serialize(v, depth + 1));
          setCount++;
        });
        var setResult = { __type: 'Set', values: values };
        if (setCount > maxBreadth) setResult.truncated = setCount - maxBreadth;
        return setResult;
      }

      if (Array.isArray(val)) {
        var arr = [];
        var arrLen = Math.min(val.length, maxBreadth);
        for (var j = 0; j < arrLen; j++) arr.push(serialize(val[j], depth + 1));
        if (val.length > maxBreadth) arr.push('...' + (val.length - maxBreadth) + ' more');
        return arr;
      }

      var obj = {};
      var keys = Object.keys(val);
      var keyLen = Math.min(keys.length, maxBreadth);
      for (var k = 0; k < keyLen; k++) {
        obj[keys[k]] = serialize(val[keys[k]], depth + 1);
      }
      if (keys.length > maxBreadth) obj.__truncated = keys.length - maxBreadth + ' more keys';
      return obj;
    }

    var json = JSON.stringify(serialize(value, 0));
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

    var maxLogs = 200;
    function capture(level, args) {
      if (logs.length >= maxLogs) return;
      try {
        var parts = [];
        for (var i = 0; i < args.length; i++) {
          parts.push(typeof args[i] === 'string' ? args[i] : JSON.stringify(args[i]));
        }
        var entry = '[' + level + '] ' + parts.join(' ');
        logs.push(entry.length > 1000 ? entry.slice(0, 1000) + '...' : entry);
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

    var result;
    try {
      // Separate construction from execution so only SyntaxErrors trigger the fallback
      var fn;
      try {
        fn = new win.Function('return (' + expression + ')');
      } catch (syntaxErr) {
        fn = new win.Function(expression);
      }
      result = fn.call(win);
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
          return { success: true, result: smartSerialize(resolved, maxBytes), error: undefined, logs: logs };
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
      result: smartSerialize(result, maxBytes),
      error: undefined,
      logs: logs
    });
  }
`)

let execute = async (input: input, ~taskId as _: string, ~toolCallId as _: string): toolResult<output> => {
  await Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=async () =>
      Ok({success: false, result: None, error: Some("Preview frame not available"), logs: []}),
    async ({win, doc: _}) => {
      let timeout = input.timeout->Option.getOr(5000)
      let output = await executeInWindow(win, input.expression, timeout, maxOutputBytes)
      Ok(output)
    },
  )
}
