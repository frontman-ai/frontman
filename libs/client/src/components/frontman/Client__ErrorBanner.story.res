open Bindings__Storybook

type args = {message: string, category: string}

let default: Meta.t<args> = {
  title: "Components/Frontman/ErrorBanner",
  tags: ["autodocs"],
  decorators: [
    Decorators.darkBackground,
    story => <div className="max-w-[250px]"> {story()} </div>,
  ],
  render: args =>
    <Client__ErrorBanner error={args.message} category={args.category} onRetry={() => ()} />,
}

let rateLimitError: Story.t<args> = {
  name: "Rate Limit Error",
  args: {
    message: "Free requests exhausted. Add your API key in Settings to continue.",
    category: "rate_limit",
  },
}

let authError: Story.t<args> = {
  name: "Auth Error",
  args: {
    message: "Invalid API key provided.",
    category: "auth",
  },
}

let billingError: Story.t<args> = {
  name: "Billing Error",
  args: {
    message: "Your account has exceeded its billing limit.",
    category: "billing",
  },
}

let payloadTooLarge: Story.t<args> = {
  name: "Payload Too Large",
  args: {
    message: "The request payload was too large.",
    category: "payload_too_large",
  },
}

let outputTruncated: Story.t<args> = {
  name: "Output Truncated",
  args: {
    message: "The response was truncated due to length.",
    category: "output_truncated",
  },
}

let genericError: Story.t<args> = {
  name: "Generic Error",
  args: {
    message: "An unexpected error occurred. Please try again.",
    category: "unknown",
  },
}

let connectionError: Story.t<args> = {
  name: "Connection Error",
  args: {
    message: "Failed to connect to the server. Please check your internet connection.",
    category: "unknown",
  },
}

let longErrorMessage: Story.t<args> = {
  name: "Long Error Message",
  args: {
    message: "This is a very long error message that might wrap to multiple lines. It tests how the component handles longer text content and ensures the layout remains readable and visually appealing even with extended error descriptions that go on and on explaining exactly what went wrong.",
    category: "unknown",
  },
}
