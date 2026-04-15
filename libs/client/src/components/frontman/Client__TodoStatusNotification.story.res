/**
 * TodoStatusNotification Stories
 *
 * Demonstrates the inline notifications for todo status.
 */
open Bindings__Storybook
module Todo = Client__State__Types.Todo

type args = unit

// Default export for Storybook meta
let default: Meta.t<args> = {
  title: "Components/Todo/TodoStatusNotification",
  component: Obj.magic(Client__TodoStatusNotification.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

/** Pending notification */
let pending: Story.t<args> = {
  name: "Pending Todo",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification content="Waiting to start" status=Todo.Pending />
    </div>
  },
}

/** In Progress notification */
let inProgress: Story.t<args> = {
  name: "In Progress Todo",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification
        content="Analyzing codebase structure" status=Todo.InProgress
      />
    </div>
  },
}

/** Completed notification */
let completed: Story.t<args> = {
  name: "Completed Todo",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification content="Implement authentication" status=Todo.Completed />
    </div>
  },
}

/** Multiple notifications in sequence */
let sequence: Story.t<args> = {
  name: "Notification Sequence",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <div style={{display: "flex", flexDirection: "column", gap: "4px"}}>
        <Client__TodoStatusNotification content="Analyze project structure" status=Todo.Completed />
        <Client__TodoStatusNotification
          content="Implement component from specs" status=Todo.InProgress
        />
        <Client__TodoStatusNotification content="Write tests" status=Todo.Pending />
      </div>
    </div>
  },
}

/** Long content (truncation test) */
let longContent: Story.t<args> = {
  name: "Long Content",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification
        content="Refactoring the entire authentication system including OAuth2 integration, session management, and token refresh logic"
        status=Todo.InProgress
      />
    </div>
  },
}
