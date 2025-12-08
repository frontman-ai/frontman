open AskTheLlmBindings

// Monkey patch Error.prototype.stack to hide chrome-extension:// URLs
let patchErrorStack: unit => unit = %raw(`
  function() {
    const originalStackDescriptor = Object.getOwnPropertyDescriptor(Error.prototype, 'stack');
    const originalStackGetter = originalStackDescriptor?.get;
    const chromeExtRegex = new RegExp('chrome-extension://[^/]+/', 'g');
    
    function cleanStack(stack) {
      if (typeof stack === 'string') {
        return stack
          .split('\\n')
          .map(line => line.replace(chromeExtRegex, ''))
          .join('\\n');
      }
      // If stack is not a string (e.g., array of CallSites), return as-is
      return stack;
    }
    
    if (originalStackGetter) {
      // For browsers that use a getter
      Object.defineProperty(Error.prototype, 'stack', {
        get: function() {
          const stack = originalStackGetter.call(this);
          return cleanStack(stack);
        },
        configurable: true
      });
    } else {
      // Fallback: override stack on each Error instance
      const OriginalError = Error;
      Error = function(...args) {
        const err = new OriginalError(...args);
        const originalStack = err.stack;
        if (originalStack) {
          Object.defineProperty(err, 'stack', {
            get: function() {
              return cleanStack(originalStack);
            },
            configurable: true
          });
        }
        return err;
      };
      Error.prototype = OriginalError.prototype;
    }
  }
`)

// Check if window.figma and window.figma.on exist
let figmaExists: unit => bool = %raw(`
  function() {
    return typeof window !== 'undefined' && 
           typeof window.figma !== 'undefined';
  }
`)

// Wait for window.figma and window.figma.on to be available
let waitForFigma: unit => promise<FigmaClientApiBindings.figmaApi> = %raw(`
  function() {
    return new Promise((resolve) => {
      let timeoutId = null;
      if (typeof window !== 'undefined' && 
          typeof window.figma !== 'undefined') {
        resolve(window.figma);
        return;
      }
      
      const checkInterval = setInterval(() => {
        if (typeof window !== 'undefined' && 
            typeof window.figma !== 'undefined') {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          resolve(window.figma);
        }
      }, 100);
      
      timeoutId = setTimeout(() => {
        if (timeoutId) {
          clearInterval(checkInterval);
          console.warn('[Frontman] Figma API not found after 10 seconds');
          resolve();
        }
      }, 10000);
    });
  }
`)

let main = () => {
  patchErrorStack()

  let runAsync = async () => {
    let figma = await waitForFigma()

    Console.log("[Frontman] Figma API is ready!")

    // Serialize first selected node when selection changes
    FigmaClientApiBindings.onSelectionChange(figma, () => {
      let runSerialize = async () => {
        let selection =
          figma->FigmaClientApiBindings.currentPage->FigmaClientApiBindings.selection
        switch selection[0] {
        | Some(firstNode) =>
          let serialized =
            await FigmaClientApiBindings.figmaToTailwindJSON(
              firstNode,
              FigmaClientApiBindings.defaultSettings,
            )
          Console.log2("[Frontman] Serialized first node:", serialized)

          // Send to extension
          let data = {"selectedFigmaNode": serialized, "type": "FigmaNodeSelected"}
          Chrome.Runtime.sendMessageExternal("kfdpjbmabcelpgoipaccjijhehdmeghp", data, response => {
            Console.log2("[Frontman] Response from extension:", response)
          })
        | None => ()
        }
      }
      runSerialize()->ignore
    })
  }

  runAsync()->ignore
}

let config = {
  "matches": ["https://figma.com/design/*", "https://www.figma.com/design/*"],
}
