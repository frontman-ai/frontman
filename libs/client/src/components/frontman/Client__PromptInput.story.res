open Bindings__Storybook

type args = {
  isAgentRunning: bool,
  hasActiveACPSession: bool,
  isSelecting: bool,
  hasAnnotations: bool,
  isEnrichingAnnotations: bool,
  disabled: bool,
}

let default: Meta.t<args> = {
  title: "Frontman/PromptInput",
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
  render: args =>
    <Client__PromptInput
      onSubmit={(~text as _, ~inputItems as _) => ()}
      onCancel={() => ()}
      modelConfigOption=None
      isModelsConfigLoading=false
      selectedModelValue=None
      onModelChange={_ => ()}
      isAgentRunning={args.isAgentRunning}
      hasActiveACPSession={args.hasActiveACPSession}
      isSelecting={args.isSelecting}
      hasAnnotations={args.hasAnnotations}
      isEnrichingAnnotations={args.isEnrichingAnnotations}
      disabled={args.disabled}
      onSelectElement={() => ()}
    />,
}

let defaultState: Story.t<args> = {
  name: "Default (idle, session active)",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let selectionMode: Story.t<args> = {
  name: "Selection mode active",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: true,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let withAnnotations: Story.t<args> = {
  name: "Has annotations",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: true,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let agentRunning: Story.t<args> = {
  name: "Agent running",
  args: {
    isAgentRunning: true,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: false,
  },
}

let disabled: Story.t<args> = {
  name: "Disabled (usage exhausted)",
  args: {
    isAgentRunning: false,
    hasActiveACPSession: true,
    isSelecting: false,
    hasAnnotations: false,
    isEnrichingAnnotations: false,
    disabled: true,
  },
}
