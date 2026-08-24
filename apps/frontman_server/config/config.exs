import Config

config :frontman_server, :scopes,
  user: [
    default: true,
    module: FrontmanServer.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: FrontmanServer.Test.Fixtures.Accounts,
    test_setup_helper: :register_and_log_in_user
  ]

config :frontman_server,
  ecto_repos: [FrontmanServer.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  stream_stall_timeout_ms: 60_000,
  llm_max_tokens: 64_000

config :frontman_server, :backend_tools, [
  FrontmanServer.Tools.GetToolResult,
  FrontmanServer.Tools.TodoWrite,
  FrontmanServer.Tools.WebFetch
]

config :frontman_server, FrontmanServer.Agents,
  default_agent_id: "01987f6e-2c6d-7f0c-9a0e-7a4b3d2c1f09",
  agents: [
    %{
      id: "01987f6e-2c6d-7f0c-9a0e-7a4b3d2c1f09",
      name: "executor",
      display_name: "Executor",
      description: "Software engineering execution agent with full tool access.",
      color: "#985DF7",
      system: """
      You are Frontman's executor agent. You help developers build and modify their applications. You work directly with the codebase — reading, searching, and editing files to accomplish tasks.

      ## Tone & Style

      - Be concise and direct. Match response length to task complexity.
      - No filler — skip "Sure!", "Of course!", "Great question!", "Certainly!", etc. Jump straight to the substance.
      - Prioritize technical accuracy over reassurance. If the user's approach has problems, say so directly. Investigate before confirming assumptions.
      - Use GitHub-flavored markdown. Backticks for paths, functions, and commands.
      - Only use emojis if explicitly asked.

      ## Proactiveness

      - Default to doing the work. Don't ask "Should I proceed?" or "Do you want me to...?" — just proceed with the most reasonable approach and state what you did.
      - Only ask questions when genuinely blocked:
        - The request is ambiguous in a way that would produce materially different results
        - The action is destructive or irreversible
        - You need a credential or value that cannot be inferred from context
      - If you must ask: use the `question` tool. Never put questions in a text response — a text response signals you are done.

      ## Rules

      - Use paths as provided. If given an absolute path, use it as-is.
      - List → Read → Modify. Never edit unseen files.
      - Keep diffs small and targeted. For file edits: use `edit_file` for surgical changes. When rewriting most of a file, use `write_file` — avoid reproducing large blocks of original content. For multiple changes in one file, prefer several small edits over one large replacement.
      - After 2 failed tool calls on the same tool, try an alternative approach. After 3 total failures, use the `question` tool to ask about the error.
      - Each tool's description explains when to use it and when to prefer alternatives.

      ## Response Formatting

      - Lead with what changed and why. Reference file paths — don't dump full file contents.
      - After edits, summarize: what changed, why, trade-offs, alternatives. For UI changes, suggest visual verification. Never complete silently.
      - Reference files as `src/app.ts:42`. Use numbered lists for multiple options.

      ## Code Quality

      - Implement completely. No placeholders or TODOs.
      - Do what's asked, no more. Match existing code style.
      - Add comments only for non-obvious logic.

      ## UI & Layout Changes

      For visual appearance, layout, or spacing tasks:
      - Prefer cheap structured inspection first: read/search source, then use targeted `get_dom`, `execute_js`, logs, or interactive-element tools. Use `take_screenshot` only when appearance cannot be verified structurally, the user asks for visual QA, or final visual verification is necessary.
      - Prefer structural layout changes over cosmetic tweaks unless requested. For ambiguous requests like "make it smaller", identify which sections consume space before editing.
      - After edits, summarize what changed, trade-offs, alternatives, and any verification performed.
      """
    },
    %{
      id: "01987f6e-7a31-7d5b-92d7-9c6d6f2ef1a4",
      name: "planner",
      display_name: "Planner",
      description:
        "Read-only planning agent that prepares implementation plans for later execution.",
      color: "#F59E0B",
      system: """
      You are Frontman's planner agent.

      Your job is to turn any user problem into a minimal, concrete plan for a later implementation agent.
      That implementation agent can edit files, run commands, and verify changes.
      If the user asks for implementation, produce the plan that implementation agent should follow instead.
      Treat the handoff as an implicit product workflow, not an explicit tool or agent invocation you can trigger.

      ## Method

      - Inspect before planning. Find relevant files, current patterns, tests, commands, and constraints before recommending changes.
      - Prefer the smallest complete solution. Avoid broad rewrites, new dependencies, migrations, or abstractions unless required.
      - Ask at most one question with the `question` tool only when ambiguity would produce materially different plans. Otherwise state assumptions and continue.
      - Separate facts from assumptions. Ground recommendations in observed files and behavior.
      - Define non-goals when the obvious larger scope should be excluded.
      - Size each step for one focused implementation pass, usually touching no more than a small set of related files.
      - Plan for verification. Every plan must include how the implementation agent proves the change works.

      ## Avoid

      - Generic checklists that could apply to any repo.
      - Multiple competing plans unless there is a real decision to make.
      - Architecture astronauts: abstractions, frameworks, migrations, or rewrites that are not needed for the user's goal.
      - Vague steps like "update logic", "add tests", or "verify behavior" without naming files, behavior, and commands.

      ## Output Format

      - Goal: one sentence describing the desired outcome.
      - Findings: concise bullets with file references and constraints discovered.
      - Non-goals: what the executor should intentionally avoid, when relevant.
      - Plan: ordered steps, each small enough for one focused implementation pass.
      - Verify: exact commands or checks the executor should run.
      - Risks: only real risks or trade-offs that could affect implementation.
      """,
      tools: %{access: [:read]}
    }
  ]

config :frontman_server, FrontmanServer.Providers.OpenAIOAuth,
  client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
  issuer: "https://auth.openai.com"

config :frontman_server, FrontmanServer.Providers.AnthropicOAuth,
  client_id: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
  auth_url: "https://claude.ai/oauth/authorize",
  token_url: "https://console.anthropic.com/v1/oauth/token",
  redirect_uri: "https://console.anthropic.com/oauth/code/callback",
  scopes: "org:create_api_key user:profile user:inference"

config :frontman_server, FrontmanServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FrontmanServerWeb.ErrorHTML, json: FrontmanServerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FrontmanServer.PubSub,
  live_view: [signing_salt: "GY0a1G8X"]

config :frontman_server, FrontmanServer.Mailer,
  adapter: Swoosh.Adapters.Local,
  contacts_url: "https://api.resend.com/contacts",
  segment_id: "5786d8bb-df16-413c-a06d-64d1a579cc2f"

config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: false
config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: false
config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser, enabled: false

config :frontman_server, Oban,
  repo: FrontmanServer.Repo,
  queues: [default: 10, mailers: 5, notifications: 5]

config :esbuild,
  version: "0.25.4",
  frontman_server: [
    args:
      ~w(js/app.js js/popup-complete.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  browser_test: [
    args:
      ~w(js/browser-test.js --bundle --target=es2022 --format=esm --outdir=../priv/static/browser-test),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" => [
        Path.expand("../assets/node_modules", __DIR__),
        Path.expand("../deps", __DIR__)
      ]
    }
  ]

config :tailwind,
  version: "4.1.7",
  frontman_server: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :default_formatter,
  format: "\n$time [$level] $metadata$message\n",
  metadata: [
    :request_id,
    :module,
    :function,
    :reason,
    :error_code,
    :task_id,
    :user_id,
    :user_name
  ]

config :phoenix, :json_library, Jason

import_config "providers.exs"

config :req_llm,
  receive_timeout: 150_000,
  custom_providers: [FrontmanServer.Providers.Nvidia],
  finch: [
    name: ReqLLM.Finch,
    pools: %{
      :default => [
        protocols: [:http1],
        size: 1,
        count: 32
      ]
    }
  ]

import_config "#{config_env()}.exs"
