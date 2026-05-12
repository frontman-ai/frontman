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
    primary_content: "#faf5ff",
    primary_50: "#faf5ff",
    primary_100: "#f3e8ff",
    primary_200: "#e9d5ff",
    primary_300: "#d8b4ff",
    primary_400: "#c084ff",
    primary_500: "#a259ff",
    primary_600: "#8847d9",
    primary_700: "#6e38b3",
    primary_800: "#6e38b3",
    primary_900: "#6e38b3",
    primary_950: "#6e38b3",
    secondary: "#FFFFFF",
    secondary_content: "#020617",
    tertiary: "#020617",
    red_500: "oklch(63.7% .237 25.331)",
    amber_500: "oklch(76.9% .188 70.08)",
    green_400: "oklch(79.2% .209 151.711)",
    green_500: "oklch(72.3% .219 149.579)",
    violet_100: "oklch(94.3% .029 294.588)",
    violet_700: "oklch(49.1% .27 292.581)",
    violet_800: "oklch(43.2% .232 292.759)",
    purple_400: "oklch(71.4% .203 305.504)",
    pink_400: "oklch(71.8% .202 349.761)",
    slate_600: "oklch(44.6% .043 257.281)",
    slate_900: "oklch(20.8% .042 265.755)",
    zinc_50: "oklch(98.5% 0 0)",
    zinc_100: "oklch(96.7% .001 286.375)",
    zinc_200: "oklch(92% .004 286.32)",
    zinc_300: "oklch(87.1% .006 286.286)",
    zinc_400: "oklch(70.5% .015 286.067)",
    zinc_500: "oklch(55.2% .016 285.938)",
    zinc_600: "oklch(44.2% .017 285.786)",
    zinc_700: "oklch(37% .013 285.805)",
    zinc_800: "oklch(27.4% .006 286.033)",
    zinc_900: "oklch(21% .006 285.885)",
    zinc_950: "oklch(14.1% .005 285.823)",
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
    surface: "#0f172a",
    surface_2: "#1e293b",
    on_surface: "#FFFFFF",
    on_surface_muted: "#cbd5e1",
    border: "#334155",
    overlay: "#FFFFFF26",
    accent_purple: "oklch(71.4% .203 305.504)",
    accent_cyan: "oklch(71.8% .202 349.761)",
    accent_amber: "oklch(76.9% .188 70.08)",
    error: "oklch(63.7% .237 25.331)",
    success: "oklch(68% .145 165)",
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
    {:secondary, "--fm-color-secondary"},
    {:secondary_content, "--fm-color-secondary-content"},
    {:tertiary, "--fm-color-tertiary"},
    {:red_500, "--fm-color-red-500"},
    {:amber_500, "--fm-color-amber-500"},
    {:green_400, "--fm-color-green-400"},
    {:green_500, "--fm-color-green-500"},
    {:violet_100, "--fm-color-violet-100"},
    {:violet_700, "--fm-color-violet-700"},
    {:violet_800, "--fm-color-violet-800"},
    {:purple_400, "--fm-color-purple-400"},
    {:pink_400, "--fm-color-pink-400"},
    {:slate_600, "--fm-color-slate-600"},
    {:slate_900, "--fm-color-slate-900"},
    {:zinc_50, "--fm-color-zinc-50"},
    {:zinc_100, "--fm-color-zinc-100"},
    {:zinc_200, "--fm-color-zinc-200"},
    {:zinc_300, "--fm-color-zinc-300"},
    {:zinc_400, "--fm-color-zinc-400"},
    {:zinc_500, "--fm-color-zinc-500"},
    {:zinc_600, "--fm-color-zinc-600"},
    {:zinc_700, "--fm-color-zinc-700"},
    {:zinc_800, "--fm-color-zinc-800"},
    {:zinc_900, "--fm-color-zinc-900"},
    {:zinc_950, "--fm-color-zinc-950"},
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
    {:surface, "--fm-color-surface"},
    {:surface_2, "--fm-color-surface-2"},
    {:on_surface, "--fm-color-on-surface"},
    {:on_surface_muted, "--fm-color-on-surface-muted"},
    {:border, "--fm-color-border"},
    {:overlay, "--fm-color-overlay"},
    {:accent_purple, "--fm-color-accent-purple"},
    {:accent_cyan, "--fm-color-accent-cyan"},
    {:accent_amber, "--fm-color-accent-amber"},
    {:error, "--fm-color-error"},
    {:success, "--fm-color-success"},
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
