// Minimal Node.js readline utilities for CLI prompts

// Raw JS implementation using node:readline.
// Returns null on EOF (Ctrl+D) so callers can distinguish it from empty input (Enter).
// IMPORTANT: resolve(answer) must be called BEFORE rl.close() because
// rl.close() synchronously emits 'close', which would resolve with null
// and silently discard the real answer (a Promise resolves only once).
let question: string => promise<Nullable.t<string>> = %raw(`
  async function(prompt) {
    const readline = await import('node:readline');

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    });
    return new Promise((resolve) => {
      rl.on('close', () => resolve(null));
      rl.question(prompt, (answer) => {
        resolve(answer);
        rl.close();
      });
    });
  }
`)

// Check if we can prompt interactively.
let isTTY: unit => bool = %raw(`
  function() {
    return !!process.stdin.isTTY;
  }
`)
