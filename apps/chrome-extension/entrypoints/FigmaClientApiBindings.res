// Bindings for @frontman/figma-client-api

// Figma node type from Figma Plugin API
type figmaNode

// Figma API types
type figmaApi
type pageNode

// Conversion settings
type conversionSettings = {
  embedVectors: bool,
  embedImages: bool,
  maxIconSize: int,
  withChildren: bool,
}

// DSL conversion options
type dslConversionOptions = {
  sourceFile?: string,
  baseIndent?: int,
  indentSize?: int,
}

// Converted node output (for getFigmaNodeJSON)
type rec convertedNode = {
  id: string,
  name: string,
  @as("type") type_: string,
  tailwind: string,
  children: option<array<convertedNode>>,
  textContent: option<Js.Json.t>, // Can be string or array<textSpan>
  svg: option<string>,
  imageBase64: option<string>,
  warning: option<string>,
}

// Convert Figma node to DSL string
@module("@frontman/figma-client-api")
external figmaToDSL: (
  figmaNode,
  conversionSettings,
  dslConversionOptions,
) => promise<Js.Nullable.t<string>> = "figmaToDSL"

// Get full JSON for a node by ID
@module("@frontman/figma-client-api")
external getFigmaNodeJSON: (figmaApi, string, conversionSettings) => promise<Js.Nullable.t<convertedNode>> =
  "getFigmaNodeJSON"

// Default settings
let defaultSettings: conversionSettings = {
  embedVectors: true,
  embedImages: true,
  maxIconSize: 64,
  withChildren: true,
}

// Default DSL options
let defaultDslOptions: dslConversionOptions = {}

// Export options for exportAsync
type exportOptions = {format: string}

// Figma Plugin API bindings

// Get current page
@get external currentPage: figmaApi => pageNode = "currentPage"

// Get selection from page
@get external selection: pageNode => array<figmaNode> = "selection"

// Get node ID
@get external id: figmaNode => string = "id"

// Get node by ID (async)
// Note: Returns undefined (not null) when node is not found, to match ReScript's option<T> representation
let getNodeByIdAsync: (figmaApi, string) => promise<option<figmaNode>> = %raw(`
  function(figma, nodeId) {
    if (figma.getNodeByIdAsync) {
      return figma.getNodeByIdAsync(nodeId).then(node => node || undefined);
    }
    return Promise.resolve(undefined);
  }
`)

// Export node as image (returns Uint8Array)
let exportAsync: (figmaNode, exportOptions) => promise<Uint8Array.t> = %raw(`
  function(node, options) {
    return node.exportAsync(options);
  }
`)

// Base64 encode bytes (from figma API)
let base64Encode: (figmaApi, Uint8Array.t) => string = %raw(`
  function(figma, bytes) {
    return figma.base64Encode(bytes);
  }
`)

// Selection change listener using click events
let onSelectionChange: (figmaApi, unit => unit) => unit = %raw(`
  function(figma, callback) {
    let previousFirstNodeId = null;
    
    const checkSelection = () => {
      try {
        const selection = figma.currentPage?.selection;
        
        // Check if selection exists and is not empty
        if (selection && selection.length > 0) {
          const firstNode = selection[0];
          const currentFirstNodeId = firstNode?.id;
          
          // Fire callback only if the first element has changed
          if (currentFirstNodeId && currentFirstNodeId !== previousFirstNodeId) {
            previousFirstNodeId = currentFirstNodeId;
            callback();
          }
        }
      } catch (e) {
        // Silently ignore errors
      }
    };
    
    // Listen to click events on document with capture phase
    document.addEventListener('click', checkSelection, true);
    
    // Return cleanup function (optional)
    return () => {
      document.removeEventListener('click', checkSelection, true);
    };
  }
`)
