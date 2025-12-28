/**
 * TodoBatchBlock Stories
 * 
 * Demonstrates the "Added X todos" component with various states.
 */
open Bindings__Storybook
open AskTheLlmFrontmanClient.FrontmanClient__ACP__Types
S.enableJson()

type args = unit

// Default export for Storybook meta
let default: Meta.t<args> = {
  title: "Components/Todo/TodoBatchBlock",
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

module Samples = {
  // Sample todo entries for stories (wrapped in module to avoid being treated as stories)
  let sampleEntries: array<todoBatchEntry> = [
    {
      id: "todo-1",
      content: "Analyze Figma design structure",
      activeForm: Some("Analyzing Figma design structure"),
      status: "pending",
    },
    {
      id: "todo-2",
      content: "Implement component from Figma specs",
      activeForm: Some("Implementing the component from Figma specs"),
      status: "pending",
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

  // Mixed status entries (wrapped in module to avoid being treated as stories)
  let mixedStatusEntries: array<todoBatchEntry> = [
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
      status: "cancelled",
    },
  ]
}

/** Multiple todos - collapsed */
let multipleTodos: Story.t<args> = {
  name: "Multiple Todos (4)",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoBatchBlock
        entries=Samples.sampleEntries count=4 createdAt={Date.now()} messageId="story-1"
      />
    </div>
  },
}

/** Multiple todos with mixed statuses */
let mixedStatus: Story.t<args> = {
  name: "Mixed Status Todos",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoBatchBlock
        entries=Samples.mixedStatusEntries count=4 createdAt={Date.now()} messageId="story-2"
      />
    </div>
  },
}

/** Single todo */
let singleTodo: Story.t<args> = {
  name: "Single Todo",
  render: _ => {
    let singleEntry: array<todoBatchEntry> = [
      {
        id: "todo-1",
        content: "Fix authentication bug in login flow",
        activeForm: Some("Fixing authentication bug"),
        status: "pending",
      },
    ]
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoBatchBlock
        entries=singleEntry count=1 createdAt={Date.now()} messageId="story-3"
      />
    </div>
  },
}

/** Many todos (larger batch) */
let manyTodos: Story.t<args> = {
  name: "Large Batch (8 todos)",
  render: _ => {
    let manyEntries: array<todoBatchEntry> = [
      {id: "t1", content: "Review requirements", activeForm: None, status: "completed"},
      {id: "t2", content: "Set up project structure", activeForm: None, status: "completed"},
      {id: "t3", content: "Implement authentication", activeForm: None, status: "completed"},
      {id: "t4", content: "Create database schema", activeForm: None, status: "in_progress"},
      {id: "t5", content: "Build API endpoints", activeForm: None, status: "pending"},
      {id: "t6", content: "Design frontend components", activeForm: None, status: "pending"},
      {id: "t7", content: "Integrate frontend with API", activeForm: None, status: "pending"},
      {id: "t8", content: "Write end-to-end tests", activeForm: None, status: "pending"},
    ]
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoBatchBlock
        entries=manyEntries count=8 createdAt={Date.now()} messageId="story-4"
      />
    </div>
  },
}
