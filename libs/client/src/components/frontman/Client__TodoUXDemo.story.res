/**
 * TodoUXDemo Stories
 * 
 * Demonstrates the complete todo UX experience with:
 * - "Added X todos" batch blocks
 * - "Starting:" and "Finished:" notifications
 * - Mixed together as they would appear in a real session
 */

open Bindings__Storybook
open FrontmanFrontmanClient.FrontmanClient__ACP__Types
S.enableJson()

type args = unit

// Wrapper component for the demo
module DemoWrapper = {
  @react.component
  let make = (~children: React.element) => {
    <div> {children} </div>
  }
}

// Default export for Storybook meta
let default: Meta.t<args> = {
  title: "Components/Todo/Complete UX Demo",
  component: Obj.magic(DemoWrapper.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

/** Full todo workflow demonstration */
let fullWorkflow: Story.t<args> = {
  name: "Full Workflow",
  render: _ => {
    let batchEntries: array<todoBatchEntry> = [
      {
        id: "todo-1",
        content: "Analyze Figma design structure",
        activeForm: Some("Analyzing Figma design structure"),
        status: "completed",
      },
      {
        id: "todo-2",
        content: "Implement component from Figma specs",
        activeForm: Some("Implementing the component from Figma specs"),
        status: "in_progress",
      },
      {
        id: "todo-3",
        content: "Verify component implementation",
        activeForm: Some("Verifying component implementation"),
        status: "pending",
      },
      {
        id: "todo-4",
        content: "Write unit tests",
        activeForm: Some("Writing unit tests"),
        status: "pending",
      },
    ]

    <div
      style={{
        width: "440px",
        padding: "20px",
        backgroundColor: "#0a0a0a",
        borderRadius: "12px",
        fontFamily: "system-ui, -apple-system, sans-serif",
      }}>
      <div style={{marginBottom: "16px", color: "#71717a", fontSize: "12px"}}>
        {React.string("Todo UX Flow Demonstration")}
      </div>
      // Simulated chat flow
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "2px",
        }}>
        // User message (simulated)
        <div
          style={{
            padding: "12px 16px",
            backgroundColor: "#27272a",
            borderRadius: "12px",
            color: "#e4e4e7",
            fontSize: "14px",
            marginBottom: "8px",
          }}>
          {React.string("Convert the Figma design to a React component")}
        </div>
        // Agent creates todos
        <Client__TodoBatchBlock
          entries=batchEntries count=4 createdAt={Date.now()} messageId="demo-batch"
        />
        // Agent starts first todo
        <Client__TodoStatusNotification
          content="Analyzing Figma design structure" eventType=#started messageId="demo-start-1"
        />
        // Simulated tool calls would go here...
        <div
          style={{
            padding: "8px 12px",
            backgroundColor: "#18181b",
            border: "1px solid #27272a",
            borderRadius: "8px",
            color: "#a1a1aa",
            fontSize: "12px",
            margin: "4px 0",
          }}>
          {React.string("... exploration tool calls ...")}
        </div>
        // First todo completed
        <Client__TodoStatusNotification
          content="Analyzing Figma design structure" eventType=#completed messageId="demo-end-1"
        />
        // Start second todo
        <Client__TodoStatusNotification
          content="Implementing the component from Figma specs"
          eventType=#started
          messageId="demo-start-2"
        />
      </div>
    </div>
  },
}

/** Cursor-style todo experience */
let cursorStyle: Story.t<args> = {
  name: "Cursor IDE Style",
  render: _ => {
    let todoEntries: array<todoBatchEntry> = [
      {
        id: "t1",
        content: "Add dark mode toggle to settings",
        activeForm: Some("Adding dark mode toggle"),
        status: "completed",
      },
      {
        id: "t2",
        content: "Implement theme persistence",
        activeForm: Some("Implementing theme persistence"),
        status: "completed",
      },
      {
        id: "t3",
        content: "Update component styles",
        activeForm: Some("Updating component styles"),
        status: "in_progress",
      },
    ]

    <div
      style={{
        width: "440px",
        padding: "24px",
        backgroundColor: "#09090b",
        borderRadius: "12px",
        fontFamily: "system-ui, -apple-system, sans-serif",
      }}>
      <div
        style={{
          marginBottom: "20px",
          paddingBottom: "12px",
          borderBottom: "1px solid #27272a",
        }}>
        <div style={{color: "#f4f4f5", fontSize: "14px", fontWeight: "500"}}>
          {React.string("Task: Implement dark mode")}
        </div>
        <div style={{color: "#71717a", fontSize: "12px", marginTop: "4px"}}>
          {React.string("2 of 3 todos completed")}
        </div>
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "4px",
        }}>
        // Batch with progress
        <Client__TodoBatchBlock
          entries=todoEntries count=3 createdAt={Date.now()} messageId="cursor-batch"
        />
        // Completed items
        <Client__TodoStatusNotification
          content="Adding dark mode toggle" eventType=#completed messageId="cursor-done-1"
        />
        <Client__TodoStatusNotification
          content="Implementing theme persistence" eventType=#completed messageId="cursor-done-2"
        />
        // Currently in progress
        <Client__TodoStatusNotification
          content="Updating component styles" eventType=#started messageId="cursor-current"
        />
      </div>
    </div>
  },
}

/** Just notifications (no batch) */
let notificationsOnly: Story.t<args> = {
  name: "Status Notifications Flow",
  render: _ => {
    <div
      style={{
        width: "400px",
        padding: "20px",
        backgroundColor: "#18181b",
        borderRadius: "8px",
      }}>
      <div
        style={{
          marginBottom: "12px",
          color: "#a1a1aa",
          fontSize: "11px",
          textTransform: "uppercase",
          letterSpacing: "0.5px",
        }}>
        {React.string("Progress Updates")}
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "2px",
        }}>
        <Client__TodoStatusNotification
          content="Setting up project structure" eventType=#started messageId="flow-1"
        />
        <Client__TodoStatusNotification
          content="Setting up project structure" eventType=#completed messageId="flow-2"
        />
        <Client__TodoStatusNotification
          content="Creating database schema" eventType=#started messageId="flow-3"
        />
        <Client__TodoStatusNotification
          content="Creating database schema" eventType=#completed messageId="flow-4"
        />
        <Client__TodoStatusNotification
          content="Implementing API endpoints" eventType=#started messageId="flow-5"
        />
      </div>
    </div>
  },
}
