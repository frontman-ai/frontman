# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use FrontmanServerWeb, :html

  @support_email "support@frontman.sh"
  @discord_url "https://discord.gg/xk8uXJSvhC"

  def render(template, assigns) do
    assigns =
      assigns
      |> Map.put(:status_code, status_code(template))
      |> Map.put(:status_title, Phoenix.Controller.status_message_from_template(template))
      |> Map.put(:support_email, @support_email)
      |> Map.put(:discord_url, @discord_url)

    ~H"""
    <main class="min-h-screen bg-slate-950 px-6 py-16 text-white">
      <section class="mx-auto flex max-w-2xl flex-col gap-8 rounded-3xl border border-white/10 bg-white/[0.04] p-8 shadow-2xl shadow-black/30 sm:p-10">
        <div class="space-y-3">
          <p class="text-sm font-semibold uppercase tracking-[0.28em] text-primary">
            Error {@status_code}
          </p>
          <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">{@status_title}</h1>
          <p class="text-base leading-7 text-slate-300">
            Something went wrong while Frontman handled this request. If you were signing in or setting up Frontman, we can help you get unstuck.
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <a
            class="rounded-2xl bg-primary px-5 py-4 text-center text-sm font-semibold text-primary-content transition hover:brightness-110"
            href={"mailto:#{@support_email}?subject=Frontman%20error%20#{@status_code}"}
          >
            Email support
          </a>
          <a
            class="rounded-2xl border border-white/15 px-5 py-4 text-center text-sm font-semibold text-white transition hover:border-primary/70 hover:text-primary"
            href={@discord_url}
            target="_blank"
            rel="noopener noreferrer"
          >
            Join Discord
          </a>
        </div>

        <p class="text-sm leading-6 text-slate-400">
          Include what you were trying to do, the page URL, and the approximate time of the error. Support email:
          <a class="text-primary underline underline-offset-4" href={"mailto:#{@support_email}"}>{@support_email}</a>
        </p>
      </section>
    </main>
    """
  end

  defp status_code(template) do
    template
    |> to_string()
    |> String.split(".")
    |> List.first()
  end
end
