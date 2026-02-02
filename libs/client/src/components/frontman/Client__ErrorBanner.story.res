open Bindings__Storybook

type args = {message: string}

let default: Meta.t<args> = {
  title: "Components/Frontman/ErrorBanner",
  tags: ["autodocs"],
  decorators: [Decorators.darkBackground],
  render: args => <Client__ErrorBanner error={args.message} />,
}

let rateLimitError: Story.t<args> = {
  name: "Rate Limit Error",
  args: {
    message: "Free requests exhausted. Add your API key in Settings to continue.",
  },
}

let noApiKeyError: Story.t<args> = {
  name: "No API Key Error",
  args: {
    message: "No API key available for this request.",
  },
}

let genericError: Story.t<args> = {
  name: "Generic Error",
  args: {
    message: "An unexpected error occurred. Please try again.",
  },
}

let connectionError: Story.t<args> = {
  name: "Connection Error",
  args: {
    message: "Failed to connect to the server. Please check your internet connection.",
  },
}

let longErrorMessage: Story.t<args> = {
  name: "Long Error Message",
  args: {
    message: "This is a very long error message that might wrap to multiple lines. It tests how the component handles longer text content and ensures the layout remains readable and visually appealing even with extended error descriptions that go on and on explaining exactly what went wrong.",
  },
}
