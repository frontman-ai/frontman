/**
 * Chatbox Stories
 * 
 * Demonstrates the Chatbox component with various states.
 * Use `window.__frontmanDebug.captureState()` in the running app
 * to capture real state snapshots for debugging.
 */

open Bindings__Storybook
S.enableJson()

type args = {
  showSnapshot: bool,
}

// Default export for Storybook meta
let default: Meta.t<args> = {
  title: "Components/Chatbox",
  component: Obj.magic(Client__Chatbox.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

/** Default empty state */
let emptyState: Story.t<args> = {
  name: "Empty State",
  render: _ => {
    // Reset to empty state for this story
    React.useEffect0(() => {
      Client__StateSnapshot__Storybook.resetState()
      None
    })
    
    <div style={{width: "400px", height: "600px"}}>
      <Client__Chatbox onSettingsClick={() => ()} />
    </div>
  },
}

module Snapshot = {
    // Import complex snapshot from fixture file
    @module("../../../test/fixtures/state_snapshot_complex_1.json")
    external complexSnapshotJson: JSON.t = "default"
    
    // Import subagent spawner snapshot for testing spawner hiding
    @module("../../../test/fixtures/state_snapshot_subagent_spawner.json")
    external subagentSpawnerJson: JSON.t = "default"
}

/** Complex snapshot with many tool calls */
let complexSnapshot: Story.t<args> = {
  name: "Complex Snapshot",
  render: _ => {
    let (loaded, setLoaded) = React.useState(() => false)
    let (error, setError) = React.useState(() => None)

    React.useEffect0(() => {
      let jsonString = JSON.stringify(Snapshot.complexSnapshotJson)
      switch Client__StateSnapshot__Storybook.loadSnapshot(jsonString) {
      | Ok() => setLoaded(_ => true)
      | Error(err) => setError(_ => Some(err))
      }
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    if error->Option.isSome {
      <div style={{padding: "20px", color: "#ef4444"}}>
        {React.string("Failed to load snapshot")}
        <pre style={{marginTop: "10px", fontSize: "12px"}}>
          {React.string(error->Option.getOr(""))}
        </pre>
      </div>
    } else if !loaded {
      <div style={{padding: "20px", color: "#a1a1aa"}}>
        {React.string("Loading snapshot...")}
      </div>
    } else {
      <div style={{width: "400px", height: "600px"}}>
        <Client__Chatbox onSettingsClick={() => ()} />
      </div>
    }
  },
}

/** Subagent spawner snapshot - tests that spawner tools are hidden when subagent group exists */
let subagentSpawner: Story.t<args> = {
  name: "Subagent Spawner (should hide Calling todo_add)",
  render: _ => {
    let (loaded, setLoaded) = React.useState(() => false)
    let (error, setError) = React.useState(() => None)

    React.useEffect0(() => {
      let jsonString = JSON.stringify(Snapshot.subagentSpawnerJson)
      switch Client__StateSnapshot__Storybook.loadSnapshot(jsonString) {
      | Ok() => setLoaded(_ => true)
      | Error(err) => setError(_ => Some(err))
      }
      Some(() => Client__StateSnapshot__Storybook.resetState())
    })

    if error->Option.isSome {
      <div style={{padding: "20px", color: "#ef4444"}}>
        {React.string("Failed to load snapshot")}
        <pre style={{marginTop: "10px", fontSize: "12px"}}>
          {React.string(error->Option.getOr(""))}
        </pre>
      </div>
    } else if !loaded {
      <div style={{padding: "20px", color: "#a1a1aa"}}>
        {React.string("Loading snapshot...")}
      </div>
    } else {
      <div style={{width: "400px", height: "600px"}}>
        <Client__Chatbox onSettingsClick={() => ()} />
      </div>
    }
  },
}

/** 
 * Instructions for capturing real snapshots
 */
let howToCapture: Story.t<args> = {
  name: "How to Capture Snapshots",
  render: _ => {
    <div style={{
      padding: "24px",
      backgroundColor: "#18181b",
      color: "#e4e4e7",
      fontFamily: "system-ui, sans-serif",
      maxWidth: "600px",
    }}>
      <h2 style={{marginTop: "0", color: "#f4f4f5"}}>
        {React.string("Capturing State Snapshots")}
      </h2>
      
      <p style={{lineHeight: "1.6", color: "#a1a1aa"}}>
        {React.string("To capture the current chatbox state for debugging:")}
      </p>
      
      <ol style={{lineHeight: "1.8", color: "#d4d4d8"}}>
        <li>
          {React.string("Open your app in the browser and reproduce the state you want to debug")}
        </li>
        <li>
          {React.string("Open the browser console (F12 or Cmd+Option+I)")}
        </li>
        <li>
          {React.string("Run: ")}
          <code style={{
            backgroundColor: "#27272a",
            padding: "2px 6px",
            borderRadius: "4px",
            color: "#22c55e",
          }}>
            {React.string("window.__frontmanDebug.captureState()")}
          </code>
        </li>
        <li>
          {React.string("The JSON is copied to your clipboard")}
        </li>
        <li>
          {React.string("Paste it into a story file as shown in Client__Chatbox.story.res")}
        </li>
      </ol>
      
      <h3 style={{color: "#f4f4f5", marginTop: "24px"}}>
        {React.string("Other Debug Commands")}
      </h3>
      
      <ul style={{lineHeight: "1.8", color: "#d4d4d8"}}>
        <li>
          <code style={{color: "#22c55e"}}>
            {React.string("window.__frontmanDebug.getSnapshot()")}
          </code>
          {React.string(" - Returns snapshot object for inspection")}
        </li>
        <li>
          <code style={{color: "#22c55e"}}>
            {React.string("window.__frontmanDebug.getSnapshotJson()")}
          </code>
          {React.string(" - Returns JSON string")}
        </li>
      </ul>
    </div>
  },
}

