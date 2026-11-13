# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FrontmanServerWeb, :html

  embed_templates("layouts/*")

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  attr(:focused, :boolean, default: false)
  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <div class={[
      "relative flex min-h-screen flex-col overflow-hidden bg-base-100 text-base-content",
      @focused &&
        "min-h-dvh font-headings [&_:is(button,a,summary):focus-visible]:outline-2 [&_:is(button,a,summary):focus-visible]:outline-primary-300 [&_:is(button,a,summary):focus-visible]:outline-offset-4"
    ]}>
      <div
        aria-hidden="true"
        class="pointer-events-none absolute inset-x-0 top-0 h-[28rem] sm:h-[32rem]"
      >
        <div class="absolute inset-0 bg-gradient-to-b from-primary/16 via-primary/6 to-transparent" />
      </div>

      <header class={[
        "navbar relative z-10 px-4 sm:px-6 lg:px-8",
        if(@focused, do: "pt-6", else: "border-b border-base-content/5")
      ]}>
        <div class={if(@focused, do: "flex items-center", else: "navbar-start")}>
          <a
            href="/"
            class={[
              "flex items-center gap-2 text-base font-semibold tracking-tight",
              if(@focused, do: "rounded-full bg-white/4 px-5 py-3", else: "btn btn-ghost px-2")
            ]}
          >
            <img src={~p"/images/frontman-logo.svg"} width="28" height="28" alt="Frontman" />
            <span>Frontman</span>
          </a>
        </div>
      </header>

      <main class="relative z-10 flex-1">
        <div class={[
          "mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8",
          if(@focused, do: "py-8 md:py-24", else: "py-10 sm:py-14 lg:py-16")
        ]}>
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="footer footer-center relative z-10 px-4 py-6 text-base-content/40">
        <p class="text-xs">
          &copy; {DateTime.utc_now().year} Frontman. All rights reserved.
        </p>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc "Shared shell for sign-in, assistant authorization, and site connection."
  attr(:title, :string, required: true)
  attr(:step, :integer, default: 1, values: [1, 2, 3])
  attr(:assistant, :boolean, default: true)
  slot(:intro)
  slot(:inner_block, required: true)
  slot(:footer)

  def connection(assigns) do
    ~H"""
    <section
      aria-labelledby="connect-heading"
      class="grid items-start gap-8 md:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] md:gap-20"
    >
      <div class="min-w-0 motion-safe:animate-connection-enter md:pt-6">
        <p class="inline-flex items-center gap-6 rounded-full bg-white/4 px-3.5 py-2 text-[10px] font-medium uppercase tracking-[0.18em] text-primary-200">
          {if @assistant, do: "AI assistant setup", else: "Your Frontman account"}
          <span :if={@assistant} class="text-zinc-400">0{@step} / 03</span>
        </p>
        <h1
          id="connect-heading"
          class="mt-8 text-4xl font-medium leading-[1.08] tracking-tight md:text-6xl"
        >
          {@title}
        </h1>
        <div class="mt-6 max-w-sm space-y-3 text-base leading-7 text-base-content/60">
          {render_slot(@intro)}
        </div>
        <.connection_progress :if={@assistant} step={@step} />
        <.link
          href={~p"/"}
          id="connect-back"
          class="mt-8 inline-block text-sm text-primary-200 underline-offset-4 hover:underline md:mt-10"
        >
          Back to Frontman
        </.link>
      </div>
      <div class="min-w-0 motion-safe:animate-connection-enter motion-safe:[animation-delay:100ms]">
        <div
          data-connection-card
          class="space-y-6 rounded-[2rem] bg-zinc-900 bg-none p-6 shadow-none sm:p-8 md:p-10"
        >
          {render_slot(@inner_block)}
        </div>
        <div :if={@footer != []} class="mt-6 px-3 text-xs leading-5 text-zinc-400">
          {render_slot(@footer)}
        </div>
      </div>
    </section>
    """
  end

  attr(:step, :integer, required: true)

  defp connection_progress(assigns) do
    ~H"""
    <ol
      id="assistant-setup-steps"
      aria-label="Connection progress"
      class="mt-6 flex flex-wrap gap-4 text-xs text-zinc-400 md:mt-12 md:flex-col md:gap-5 md:text-sm"
    >
      <li
        :for={
          {label, index} <- [
            {"Sign in to Frontman", 1},
            {"Confirm your account", 2},
            {"Return to your assistant", 3}
          ]
        }
        aria-current={if @step == index, do: "step"}
        class={["flex items-center gap-2 md:gap-3.5", @step == index && "text-[#e4dbff]"]}
      >
        <span class={[
          "flex size-7 shrink-0 items-center justify-center rounded-full text-xs",
          if(@step == index, do: "bg-[#e4dbff] text-[#201532]", else: "bg-white/4")
        ]}>
          {if index < @step, do: "✓", else: index}
        </span>
        {label}
      </li>
    </ol>
    """
  end

  def connection_button_class do
    "flex min-h-14 w-full items-center justify-center gap-3 rounded-full bg-[#e4dbff] px-6 py-3 text-center font-medium text-[#201532] transition-transform duration-350 ease-[cubic-bezier(0.32,0.72,0,1)] hover:bg-[#f3eeff] motion-safe:active:scale-[0.98] motion-reduce:transition-none"
  end

  def connection_input_class do
    "min-h-14 w-full rounded-2xl border border-white/10 bg-zinc-950 px-4 py-3 text-base text-white outline-none placeholder:text-white/35 focus:border-primary-300 focus:ring-2 focus:ring-primary-300/20"
  end

  def connection_secondary_button_class do
    "flex min-h-12 w-full items-center justify-center gap-3 rounded-full bg-white/5 px-5 py-3 text-center font-medium text-white transition-transform duration-350 ease-[cubic-bezier(0.32,0.72,0,1)] hover:bg-white/10 motion-safe:active:scale-[0.98] motion-reduce:transition-none"
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
