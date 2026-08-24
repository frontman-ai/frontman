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

let isTTY: unit => bool = %raw(`
  function() {
    return !!process.stdin.isTTY;
  }
`)
