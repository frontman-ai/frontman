open FrontmanBindings

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

// Wait for webpack to be available (10 seconds timeout)
let waitForWebpack: unit => promise<Js.Nullable.t<'a>> = %raw(`
  function() {
    return new Promise((resolve) => {
      if (typeof window !== 'undefined' && 
          typeof window.webpackChunk_figma_web_bundler !== 'undefined') {
        resolve(window.webpackChunk_figma_web_bundler);
        return;
      }
      
      const checkInterval = setInterval(() => {
        if (typeof window !== 'undefined' && 
            typeof window.webpackChunk_figma_web_bundler !== 'undefined') {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          resolve(window.webpackChunk_figma_web_bundler);
        }
      }, 100);
      
      const timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        console.warn('[Frontman] Webpack not found after 10 seconds');
        resolve(null);
      }, 10000);
    });
  }
`)

// Wait for window._fullscreen_ to be available (10 seconds timeout)
let waitForFullscreen: unit => promise<Js.Nullable.t<'a>> = %raw(`
  function() {
    return new Promise((resolve) => {
      if (typeof window !== 'undefined' && 
          typeof window._fullscreen_ !== 'undefined' &&
          window._fullscreen_?._store) {
        resolve(window._fullscreen_);
        return;
      }
      
      const checkInterval = setInterval(() => {
        if (typeof window !== 'undefined' && 
            typeof window._fullscreen_ !== 'undefined' &&
            window._fullscreen_?._store) {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          resolve(window._fullscreen_);
        }
      }, 100);
      
      const timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        console.warn('[Frontman] window._fullscreen_ not found after 10 seconds');
        resolve(null);
      }, 10000);
    });
  }
`)

// Helper to wait for Figma to be fully ready
let waitForFigmaReady: int => promise<bool> = %raw(`
  async function(timeout = 10000) {
    const start = Date.now();
    
    while (Date.now() - start < timeout) {
      try {
        const state = window._fullscreen_?._store?.getState();
        const sg = state?.mirror?.sceneGraph;
        
        if (state?.mirror?.appModel?.isInitialized && 
            state?.userStateLoaded && 
            state?.openFile?.key &&
            typeof sg?.getDirectlySelectedNodes === 'function' &&
            typeof sg?.getRoot === 'function') {
          
          // Extra check - try calling getRoot
          try {
            sg.getRoot();
            console.log('[Frontman] Figma is fully initialized and ready');
            return true;
          } catch (e) {
            // Not ready yet
          }
        }
      } catch (e) {}
      
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.warn('[Frontman] Timeout waiting for Figma to be ready');
    return false;
  }
`)

// Get Figma internal handle via webpack internals
let getFigmaInternal: unit => promise<Js.Nullable.t<FigmaClientApiBindings.figmaApi>> = %raw(`
  async function() {
    try {
      const store = window._fullscreen_?._store;
      if (!store) throw new Error('Figma not loaded');
      
      const state = store.getState();
      
      // Basic checks
      if (!state.mirror?.appModel?.isInitialized) throw new Error('Not initialized');
      if (!state.userStateLoaded) throw new Error('User state not loaded');
      if (!state.openFile?.key) throw new Error('No file open');
      
      const sg = state.mirror.sceneGraph;
      
      // CRITICAL: Check if scene graph has the required methods
      if (typeof sg.getDirectlySelectedNodes !== 'function') {
        throw new Error('SceneGraph not fully loaded - getDirectlySelectedNodes missing');
      }
      
      if (typeof sg.getRoot !== 'function') {
        throw new Error('SceneGraph not fully loaded - getRoot missing');
      }
      
      // Try to call it to ensure it works
      try {
        sg.getRoot();
      } catch (e) {
        throw new Error('SceneGraph not ready - getRoot() failed: ' + e.message);
      }
      
      // Get webpack require
      const webpack = window.webpackChunk_figma_web_bundler;
      let webpackRequire = null;
      webpack.push([['__hook__'], {}, (r) => { webpackRequire = r; }]);
      
      if (!webpackRequire) throw new Error('No webpack require');
      
      // Find module
      const modules = {};
      for (let chunk of webpack) {
        if (chunk && chunk[1]) Object.assign(modules, chunk[1]);
      }
      
      let moduleID = null;
      for (let [id, modFn] of Object.entries(modules)) {
        const code = modFn.toString();
        if (code.includes('noOpVm') && 
            code.includes('GLOBAL_API') &&
            code.includes('addShutdownAction')) {
          moduleID = id;
          break;
        }
      }
      
      if (!moduleID) throw new Error('Module not found');
      
      const mod = webpackRequire(moduleID);
      
      let createAPIFunc = null;
      for (let exportValue of Object.values(mod)) {
        if (typeof exportValue === 'function') {
          const code = exportValue.toString();
          if (code.includes('apiMode') && 
              code.includes('noOpVm') &&
              (code.includes('return{vm:') || code.includes('return {vm:'))) {
            createAPIFunc = exportValue;
            break;
          }
        }
      }
      
      if (!createAPIFunc) throw new Error('API function not found');
      
      const result = createAPIFunc({
        apiMode: { type: 'GLOBAL_API' },
        pluginID: 'ext',
        enableNativeJsx: false,
        disableWebpageSync: false,
        sceneGraph: sg
      });
      
      const vm = result.vm;
      const figmaHandle = vm.getProp(vm.global, 'figma');
      const symbols = Object.getOwnPropertySymbols(figmaHandle);
      const internalSymbol = symbols.find(s => s.description === 'internal');
      
      if (!internalSymbol) throw new Error('Symbol(internal) not found');
      
      console.log('[Frontman] Successfully obtained Figma internal via webpack');
      return figmaHandle[internalSymbol];
    } catch (error) {
      console.warn('[Frontman] Error getting Figma internal via webpack:', error.message);
      return null;
    }
  }
`)

// Fallback: Wait for window.figma to be available (10 seconds timeout)
let waitForFigma: unit => promise<Js.Nullable.t<FigmaClientApiBindings.figmaApi>> = %raw(`
  function() {
    return new Promise((resolve) => {
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
      
      const timeoutId = setTimeout(() => {
        clearInterval(checkInterval);
        console.warn('[Frontman] window.figma not found after 10 seconds');
        resolve(null);
      }, 10000);
    });
  }
`)

// Helper to post any message through a port (bypasses type checking)
let postMessageRaw: ('port, 'message) => unit = %raw(`
  function(port, message) {
    port.postMessage(message);
  }
`)

let main = () => {
  let runAsync = async () => {
    // Try webpack method first - need both webpack and _fullscreen_
    let webpack = await waitForWebpack()
    let fullscreen = await waitForFullscreen()
    
    let figma = switch (webpack->Js.Nullable.toOption, fullscreen->Js.Nullable.toOption) {
    | (Some(_), Some(_)) =>
      Console.log("[Frontman] Webpack and _fullscreen_ found, waiting for Figma to be ready...")
      let isReady = await waitForFigmaReady(10000)
      if isReady {
        Console.log("[Frontman] Figma is ready, attempting to get Figma internal...")
        let internal = await getFigmaInternal()
        switch internal->Js.Nullable.toOption {
        | Some(api) =>
          Console.log("[Frontman] Successfully obtained Figma API via webpack internals")
          Some(api)
        | None =>
          Console.log("[Frontman] Webpack method failed, falling back to window.figma...")
          let fallback = await waitForFigma()
          fallback->Js.Nullable.toOption
        }
      } else {
        Console.log("[Frontman] Figma not ready in time, falling back to window.figma...")
        let fallback = await waitForFigma()
        fallback->Js.Nullable.toOption
      }
    | _ =>
      Console.log("[Frontman] Webpack or _fullscreen_ not available, using window.figma fallback...")
      let fallback = await waitForFigma()
      fallback->Js.Nullable.toOption
    }

    switch figma {
    | Some(figmaApi) =>
      Console.log("[Frontman] Figma API is ready!")
      let figma = figmaApi

      // Connect to the extension background via port for bidirectional communication
      let port = Chrome.Runtime.Connect.connectExternal(
        "kfdpjbmabcelpgoipaccjijhehdmeghp",
        Some({name: "FigmaContentScript"}),
      )
      Console.log("[Frontman] Connected to extension via port")

      // Listen for messages from the background (tool calls)
      Chrome.Port.addMessageListener(port, message => {
        let messageType = %raw(`message.type`)

        switch messageType {
        | "GetFigmaNodeRequest" =>
          Console.log2("[Frontman] Received GetFigmaNodeRequest:", message)
          let requestId: string = %raw(`message.requestId`)
          let nodeId: string = %raw(`message.nodeId`)
          let settings = %raw(`message.settings`)

          // Process the request asynchronously
          let handleRequest = async () => {
            try {
              let conversionSettings: FigmaClientApiBindings.conversionSettings = {
                embedVectors: settings["embedVectors"],
                embedImages: settings["embedImages"],
                maxIconSize: settings["maxIconSize"],
                withChildren: settings["withChildren"],
              }

              let includeImage = settings["includeImage"] == true

              let nodeResult = await FigmaClientApiBindings.getFigmaNodeJSON(
                figma,
                nodeId,
                conversionSettings,
              )

              switch nodeResult->Js.Nullable.toOption {
              | Some(node) =>
                // Export image if requested
                let imageDataUrl = if includeImage {
                  try {
                    let figmaNodeOpt = await FigmaClientApiBindings.getNodeByIdAsync(figma, nodeId)
                    switch figmaNodeOpt {
                    | Some(figmaNode) =>
                      try {
                        let bytes = await FigmaClientApiBindings.exportAsync(figmaNode, {
                          format: "PNG",
                        })
                        let base64 = FigmaClientApiBindings.base64Encode(figma, bytes)
                        Some(`data:image/png;base64,${base64}`)
                      } catch {
                      | exn =>
                        let errorMsg =
                          exn
                          ->JsExn.fromException
                          ->Option.flatMap(JsExn.message)
                          ->Option.getOr("Unknown error")
                        Console.warn2("[Frontman] Failed to export node image:", errorMsg)
                        None
                      }
                    | None => None
                    }
                  } catch {
                  | exn =>
                    let errorMsg =
                      exn
                      ->JsExn.fromException
                      ->Option.flatMap(JsExn.message)
                      ->Option.getOr("Unknown error")
                    Console.warn2("[Frontman] Failed to get node for image export:", errorMsg)
                    None
                  }
                } else {
                  None
                }

                postMessageRaw(port, {
                  "type": "GetFigmaNodeResponse",
                  "requestId": requestId,
                  "node": Js.Nullable.return(node->Obj.magic),
                  "error": Js.Nullable.null,
                  "image": imageDataUrl
                  ->Option.map(dataUrl => dataUrl->Obj.magic)
                  ->Option.getOr(Js.Nullable.null)
                  ->Obj.magic,
                })
              | None =>
                postMessageRaw(port, {
                  "type": "GetFigmaNodeResponse",
                  "requestId": requestId,
                  "node": Js.Nullable.null,
                  "error": Js.Nullable.return(
                    `Node with ID "${nodeId}" not found in the current document`,
                  ),
                  "image": Js.Nullable.null,
                })
              }
            } catch {
            | exn =>
              let errorMsg =
                exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
              Console.error2("[Frontman] Error fetching node:", errorMsg)
              postMessageRaw(port, {
                "type": "GetFigmaNodeResponse",
                "requestId": requestId,
                "node": Js.Nullable.null,
                "error": Js.Nullable.return(errorMsg),
                "image": Js.Nullable.null,
              })
            }
          }
          handleRequest()->ignore
        | _ => ()
        }
      })

      // Serialize first selected node when selection changes
      FigmaClientApiBindings.onSelectionChange(figma, () => {
        let runSerialize = async () => {
          let selection =
            figma->FigmaClientApiBindings.currentPage->FigmaClientApiBindings.selection
          switch selection[0] {
          | Some(firstNode) =>
            // Get node ID
            let nodeId = firstNode->FigmaClientApiBindings.id

            // Get node DSL representation
            let nodeDSL = await FigmaClientApiBindings.figmaToDSL(
              firstNode,
              FigmaClientApiBindings.defaultSettings,
              FigmaClientApiBindings.defaultDslOptions,
            )

            // Export node as PNG image
            let imageDataUrl = try {
              let bytes = await FigmaClientApiBindings.exportAsync(firstNode, {format: "PNG"})
              let base64 = FigmaClientApiBindings.base64Encode(figma, bytes)
              Some(`data:image/png;base64,${base64}`)
            } catch {
            | exn =>
              let errorMsg =
                exn
                ->JsExn.fromException
                ->Option.flatMap(JsExn.message)
                ->Option.getOr("Unknown error")
              Console.warn2("[Frontman] Failed to export node image:", errorMsg)
              None
            }

            // Send to extension with both node data (DSL) and image
            let nodeData = switch nodeDSL->Js.Nullable.toOption {
            | Some(dsl) => dsl->Obj.magic
            | None => %raw(`null`)->Obj.magic
            }

            let figmaNodeData = {
              "nodeId": nodeId,
              "nodeData": nodeData, // DSL representation (isDsl: true)
              "image": imageDataUrl
              ->Option.map(dataUrl => dataUrl->Obj.magic)
              ->Option.getOr(Js.Nullable.null)
              ->Obj.magic,
            }

            let data = {
              "selectedFigmaNode": Js.Nullable.return(figmaNodeData),
              "type": "FigmaNodeSelected",
            }
            Chrome.Runtime.sendMessageExternal("kfdpjbmabcelpgoipaccjijhehdmeghp", data, response => {
              Console.log2("[Frontman] Response from extension:", response)
            })
          | None => ()
          }
        }
        runSerialize()->ignore
      })
    | None => Console.error("[Frontman] Failed to obtain Figma API after all attempts")
    }
  }

  runAsync()->ignore
}

let config = {
  "matches": ["https://figma.com/design/*", "https://www.figma.com/design/*"],
}
