# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.BrandTokens do
  @moduledoc """
  Frontman brand design tokens shared by browser UI and email templates.
  """

  @font_sans "Inter Variable, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

  @colors %{
    primary: "#A259FF",
    primary_content: "#FAF5FF",
    primary_50: "#FAF5FF",
    primary_100: "#F3E8FF",
    primary_200: "#E9D5FF",
    primary_300: "#D8B4FF",
    primary_400: "#C084FF",
    primary_500: "#A259FF",
    primary_600: "#8847D9",
    primary_700: "#6E38B3",
    primary_800: "#552C8C",
    primary_900: "#3C1F66",
    primary_950: "#23123D",
    neutral_50: "#f8fafc",
    neutral_100: "#f1f5f9",
    neutral_200: "#e2e8f0",
    neutral_300: "#cbd5e1",
    neutral_400: "#94a3b8",
    neutral_500: "#64748b",
    neutral_600: "#475569",
    neutral_700: "#334155",
    neutral_800: "#1e293b",
    neutral_900: "#0f172a",
    neutral_950: "#020617",
    accent_purple: "#7C3AED",
    accent_cyan: "#06B6D4",
    accent_amber: "#D97706",
    bg_cream: "#FFF4CC",
    bg_lightblue: "#C4E0FF",
    bg_lavender: "#E8D5FF",
    bg_peach: "#FFE4D6"
  }

  @css_vars [
    {:primary, "--fm-color-primary"},
    {:primary_content, "--fm-color-primary-content"},
    {:primary_50, "--fm-color-primary-50"},
    {:primary_100, "--fm-color-primary-100"},
    {:primary_200, "--fm-color-primary-200"},
    {:primary_300, "--fm-color-primary-300"},
    {:primary_400, "--fm-color-primary-400"},
    {:primary_500, "--fm-color-primary-500"},
    {:primary_600, "--fm-color-primary-600"},
    {:primary_700, "--fm-color-primary-700"},
    {:primary_800, "--fm-color-primary-800"},
    {:primary_900, "--fm-color-primary-900"},
    {:primary_950, "--fm-color-primary-950"},
    {:neutral_50, "--fm-color-neutral-50"},
    {:neutral_100, "--fm-color-neutral-100"},
    {:neutral_200, "--fm-color-neutral-200"},
    {:neutral_300, "--fm-color-neutral-300"},
    {:neutral_400, "--fm-color-neutral-400"},
    {:neutral_500, "--fm-color-neutral-500"},
    {:neutral_600, "--fm-color-neutral-600"},
    {:neutral_700, "--fm-color-neutral-700"},
    {:neutral_800, "--fm-color-neutral-800"},
    {:neutral_900, "--fm-color-neutral-900"},
    {:neutral_950, "--fm-color-neutral-950"},
    {:accent_purple, "--fm-color-accent-purple"},
    {:accent_cyan, "--fm-color-accent-cyan"},
    {:accent_amber, "--fm-color-accent-amber"},
    {:bg_cream, "--fm-color-bg-cream"},
    {:bg_lightblue, "--fm-color-bg-lightblue"},
    {:bg_lavender, "--fm-color-bg-lavender"},
    {:bg_peach, "--fm-color-bg-peach"}
  ]

  def font_sans, do: @font_sans

  def color(name), do: Map.fetch!(@colors, name)

  def root_style do
    color_vars =
      Enum.map_join(@css_vars, " ", fn {name, css_var} ->
        "#{css_var}: #{color(name)};"
      end)

    "#{color_vars} --fm-font-sans: #{@font_sans};"
  end
end
