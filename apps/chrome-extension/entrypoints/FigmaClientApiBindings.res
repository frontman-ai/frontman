// Bindings for @ask-the-llm/figma-client-api

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
}

// Text span for styled text segments
type textSpan = {
  text: string,
  tailwind: string,
}

// Converted node output
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

// Main conversion function
@module("@ask-the-llm/figma-client-api")
external figmaToTailwindJSON: (figmaNode, conversionSettings) => promise<Js.Nullable.t<convertedNode>> =
  "figmaToTailwindJSON"

// Convert multiple nodes
@module("@ask-the-llm/figma-client-api")
external convertNodes: (array<figmaNode>, conversionSettings) => promise<array<convertedNode>> =
  "convertNodes"

// Default settings
let defaultSettings: conversionSettings = {
  embedVectors: true,
  embedImages: true,
  maxIconSize: 64,
}

// Figma Plugin API bindings

// Get current page
@get external currentPage: figmaApi => pageNode = "currentPage"

// Get selection from page
@get external selection: pageNode => array<figmaNode> = "selection"

// Selection change listener using click events
let onSelectionChange: (figmaApi, unit => unit) => unit = %raw(`
  function(figma, callback) {
    let previousFirstNodeId = null;
    
    const checkSelection = () => {
      try {
        const selection = window.figma?.currentPage?.selection;
        
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
