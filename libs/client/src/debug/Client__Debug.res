/**
 * Client__Debug - Window debug utilities for state capture
 * 
 * Exposes `window.__frontmanDebug` object with utilities for:
 * - Capturing the current chatbox state
 * - Copying state snapshots to clipboard for Storybook debugging
 * 
 * Usage in browser console:
 *   window.__frontmanDebug.captureState() // Copies JSON to clipboard
 *   window.__frontmanDebug.getSnapshot()  // Returns snapshot object
 */

// Type for the debug object we'll attach to window
type debugObject = {
  captureState: unit => promise<unit>,
  getSnapshot: unit => Client__StateSnapshot.t,
  getSnapshotJson: unit => string,
}

// Get the current state from the store
let getCurrentState = (): Client__State__Types.state => {
  StateStore.getState(Client__State__Store.store)
}

// Capture the current state as a snapshot
let getSnapshot = (): Client__StateSnapshot.t => {
  let state = getCurrentState()
  Client__StateSnapshot.captureFromState(state)
}

// Get snapshot as JSON string
let getSnapshotJson = (): string => {
  let snapshot = getSnapshot()
  Client__StateSnapshot.toJsonString(snapshot)
}

// Copy text to clipboard using raw JS
let copyToClipboard: string => promise<unit> = %raw(`
  async function(text) {
    if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
    } else {
      throw new Error('Clipboard API not available');
    }
  }
`)

// Capture state and copy to clipboard
let captureState = async () => {
  let jsonString = getSnapshotJson()
  
  // Try to copy to clipboard
  try {
    await copyToClipboard(jsonString)
    Console.log("[Frontman Debug] State snapshot copied to clipboard!")
    Console.log("[Frontman Debug] Paste this JSON into your Storybook story.")
  } catch {
  | _ =>
    Console.warn("[Frontman Debug] Could not copy to clipboard. Here's the JSON:")
    Console.log(jsonString)
  }
  
  // Also log the snapshot object for inspection
  let snapshot = getSnapshot()
  Console.log2("[Frontman Debug] Snapshot object:", snapshot)
  Console.log2("[Frontman Debug] Tasks:", snapshot.tasks)
  Console.log2("[Frontman Debug] Current task ID:", snapshot.currentTaskId)
}

// Create the debug object
let debugObject: debugObject = {
  captureState,
  getSnapshot,
  getSnapshotJson,
}

// Attach to window - uses raw JS to set window property
let attachToWindow: debugObject => unit = %raw(`
  function(debugObj) {
    if (typeof window !== 'undefined') {
      window.__frontmanDebug = debugObj;
      console.log('[Frontman Debug] Debug utilities attached to window.__frontmanDebug');
      console.log('[Frontman Debug] Available commands:');
      console.log('  - window.__frontmanDebug.captureState() - Capture state and copy to clipboard');
      console.log('  - window.__frontmanDebug.getSnapshot() - Get snapshot object');
      console.log('  - window.__frontmanDebug.getSnapshotJson() - Get snapshot as JSON string');
    }
  }
`)

// Initialize - call this to attach debug utilities to window
let init = () => {
  attachToWindow(debugObject)
}

// Auto-initialize in browser environment
let _ = {
  // Check if we're in a browser environment
  let isBrowser: bool = %raw(`typeof window !== 'undefined'`)
  if isBrowser {
    init()
  }
}

