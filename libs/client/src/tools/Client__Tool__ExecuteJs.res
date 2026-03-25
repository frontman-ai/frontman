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
// Raw JS helper — console capture + eval must stay in raw JS because it
// monkey-patches the iframe's window.console and uses `new win.Function`.
// ---------------------------------------------------------------------------

// Execute JS in the given window context, capturing console output.
// Returns {success, result, error, logs}.
// Accepts a serializer function to avoid coupling to smartSerialize at the JS level.
let executeInWindow: (('a, int) => string, WebAPI.DOMAPI.window, string, int, int) => promise<output> = %raw(`
  function executeInWindow(serialize, win, expression, timeoutMs, maxBytes) {
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
          return { success: true, result: serialize(resolved, maxBytes), error: undefined, logs: logs };
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
      result: serialize(result, maxBytes),
      error: undefined,
      logs: logs
    });
  }
`)

// Tool result convention: Ok means the tool executed and produced a response for the
// AI agent. Error means the tool framework itself failed. The `success` field inside
// the output distinguishes execution success from JS-level errors.
let execute = async (input: input, ~taskId as _: string, ~toolCallId as _: string): toolResult<output> => {
  await Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=async () =>
      Ok({success: false, result: None, error: Some("Preview frame not available"), logs: []}),
    async ({win, doc: _}) => {
      let timeout = input.timeout->Option.getOr(5000)
      let output = await executeInWindow(
        Client__Tool__SmartSerialize.serialize,
        win,
        input.expression,
        timeout,
        maxOutputBytes,
      )
      Ok(output)
    },
  )
}
