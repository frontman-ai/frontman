// Utility functions for iframe element selection

type iframeMessage = {
  @as("type") type_: string,
  data?: {
    selector: string,
    reactComponent: {
      name: string,
      sourceLocation: {
        status: string,
        file: option<string>,
        line: option<int>,
      },
    },
  },
}

let injectSelectorScript: (WebAPI.DOMAPI.htmliFrameElement) => unit = %raw(`function(iframe) {
  if (!iframe) return;
  
  const script = document.createElement('script');
  script.textContent = \`
    (function() {
      let isSelecting = false;
      let highlightOverlay = null;
      
      const createHighlight = () => {
        const overlay = document.createElement('div');
        overlay.id = 'select-element-overlay';
        overlay.style.cssText = \`
          position: fixed;
          pointer-events: none;
          border: 2px solid #3b82f6;
          background: rgba(59, 130, 246, 0.1);
          z-index: 999999;
          box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
        \`;
        document.body.appendChild(overlay);
        return overlay;
      };
      
      const updateHighlight = (element) => {
        if (!highlightOverlay) {
          highlightOverlay = createHighlight();
        }
        const rect = element.getBoundingClientRect();
        highlightOverlay.style.left = rect.left + 'px';
        highlightOverlay.style.top = rect.top + 'px';
        highlightOverlay.style.width = rect.width + 'px';
        highlightOverlay.style.height = rect.height + 'px';
        highlightOverlay.style.display = 'block';
      };
      
      const removeHighlight = () => {
        if (highlightOverlay) {
          highlightOverlay.remove();
          highlightOverlay = null;
        }
      };
      
      const handleClick = (event) => {
        if (!isSelecting) return;
        
        event.preventDefault();
        event.stopPropagation();
        
        const element = event.target;
        if (!element) return;
        
        // Generate selector using @medv/finder
        const finder = window.finder || (() => '');
        const selector = finder(element, {
          root: document.body || document.documentElement,
          idName: () => true,
          className: () => true,
          tagName: () => true,
          attr: () => false,
          seedMinLength: 1,
          optimizedMinLength: 2,
          maxNumberOfPathChecks: 10000,
        });
        
        // Try to get React component info
        let reactComponent = {
          name: 'Unknown Component',
          sourceLocation: {
            status: 'unavailable',
            file: null,
            line: null,
          }
        };
        
        // Try to find React fiber
        const fiber = element._reactInternalFiber || element._reactInternalInstance;
        if (fiber) {
          const componentName = fiber.type?.displayName || fiber.type?.name || 'Unknown Component';
          reactComponent.name = componentName;
          reactComponent.sourceLocation.status = 'unavailable';
        }
        
        // Send message to parent
        window.parent.postMessage({
          type: 'ELEMENT_SELECTED',
          data: {
            selector,
            reactComponent,
          }
        }, '*');
        
        cleanup();
      };
      
      const handleMouseOver = (event) => {
        if (!isSelecting) return;
        updateHighlight(event.target);
      };
      
      const handleEscape = (event) => {
        if (event.key === 'Escape' && isSelecting) {
          cleanup();
        }
      };
      
      const cleanup = () => {
        isSelecting = false;
        document.body.style.cursor = 'default';
        removeHighlight();
        document.removeEventListener('click', handleClick, true);
        document.removeEventListener('mouseover', handleMouseOver, true);
        document.removeEventListener('keydown', handleEscape, true);
      };
      
      const startSelection = () => {
        isSelecting = true;
        document.body.style.cursor = 'crosshair';
        document.addEventListener('click', handleClick, true);
        document.addEventListener('mouseover', handleMouseOver, true);
        document.addEventListener('keydown', handleEscape, true);
      };
      
      // Listen for messages from parent
      window.addEventListener('message', (event) => {
        if (event.data.type === 'START_ELEMENT_SELECTION') {
          startSelection();
        } else if (event.data.type === 'STOP_ELEMENT_SELECTION') {
          cleanup();
        }
      });
    })();
  \`;
  
  try {
    iframe.contentDocument?.head?.appendChild(script);
  } catch (error) {
    console.warn('Cannot inject script into iframe:', error);
  }
}`)

let sendMessageToIframe: (WebAPI.DOMAPI.htmliFrameElement, iframeMessage) => unit = %raw(`function(iframe, message) {
  if (iframe && iframe.contentWindow) {
    iframe.contentWindow.postMessage(message, '*');
  }
}`)
