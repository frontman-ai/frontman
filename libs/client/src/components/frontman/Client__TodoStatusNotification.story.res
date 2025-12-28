/**
 * TodoStatusNotification Stories
 * 
 * Demonstrates the "Starting:" and "Finished:" inline notifications.
 */

open Bindings__Storybook
S.enableJson()

type args = unit

// Default export for Storybook meta
let default: Meta.t<args> = {
  title: "Components/Todo/TodoStatusNotification",
  component: Obj.magic(Client__TodoStatusNotification.make),
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
}

/** Starting notification */
let starting: Story.t<args> = {
  name: "Starting Todo",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification
        content="Analyzing codebase structure" eventType=#started messageId="story-1"
      />
    </div>
  },
}

/** Finished notification */
let finished: Story.t<args> = {
  name: "Finished Todo",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <Client__TodoStatusNotification
        content="Implement authentication" eventType=#completed messageId="story-2"
      />
    </div>
  },
}

/** Multiple notifications in sequence */
let sequence: Story.t<args> = {
  name: "Notification Sequence",
  render: _ => {
    <div style={{width: "400px", padding: "20px", backgroundColor: "#18181b"}}>
      <div style={{display: "flex", flexDirection: "column", gap: "4px"}}>
        <Client__TodoStatusNotification
          content="Analyze Figma design structure" eventType=#started messageId="story-3a"
        />
        <Client__TodoStatusNotification
          content="Analyze Figma design structure" eventType=#completed messageId="story-3b"
        />
        <Client__TodoStatusNotification
          content="Implement component from specs" eventType=#started messageId="story-3c"
        />
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
        eventType=#started
        messageId="story-4"
      />
    </div>
  },
}

