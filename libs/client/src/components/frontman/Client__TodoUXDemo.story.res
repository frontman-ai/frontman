/**
 * TodoUXDemo Stories
 *
 * Demonstrates the todo status notifications as they appear in a chat session.
 */

open Bindings__Storybook
module Todo = Client__State__Types.Todo

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
          {React.string("Convert the design to a React component")}
        </div>
        // Agent starts first todo
        <Client__TodoStatusNotification content="Analyzing project structure" status=Todo.InProgress />
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
        <Client__TodoStatusNotification content="Analyzing project structure" status=Todo.Completed />
        // Start second todo
        <Client__TodoStatusNotification
          content="Implementing the component from design specs" status=Todo.InProgress
        />
      </div>
    </div>
  },
}

/** Todo list view demonstration */
let todoListView: Story.t<args> = {
  name: "Todo List View",
  render: _ => {
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
        // Completed items
        <Client__TodoStatusNotification content="Adding dark mode toggle" status=Todo.Completed />
        <Client__TodoStatusNotification content="Implementing theme persistence" status=Todo.Completed />
        // Currently in progress
        <Client__TodoStatusNotification content="Updating component styles" status=Todo.InProgress />
      </div>
    </div>
  },
}

/** Status progression demonstration */
let statusProgression: Story.t<args> = {
  name: "Status Progression",
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
        <Client__TodoStatusNotification content="Setting up project structure" status=Todo.Completed />
        <Client__TodoStatusNotification content="Creating database schema" status=Todo.Completed />
        <Client__TodoStatusNotification content="Implementing API endpoints" status=Todo.InProgress />
        <Client__TodoStatusNotification content="Writing tests" status=Todo.Pending />
        <Client__TodoStatusNotification content="Documentation" status=Todo.Pending />
      </div>
    </div>
  },
}
