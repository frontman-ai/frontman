# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.CurrentPageContext do
  @moduledoc """
  Shared current-page context formatting and parsing.

  This is the single server-side source of truth for the ACP metadata shape,
  LLM prompt section, and preflight extraction logic.
  """

  @marker_key "current_page"
  @header "[Current Page Context]"
  @unchanged_placeholder "[Page context unchanged]"
  @prompt_section_pattern_source "(?:\\A|\\n)" <>
                                   Regex.escape(@header) <>
                                   "\\n.*?(?=\\n\\[[^\\]\\n]+\\]\\n|\\z)"
  @prompt_section_pattern Regex.compile!(@prompt_section_pattern_source, "s")

  @doc "Returns the prompt section header."
  def header, do: @header

  @doc "Returns the interaction/ACP data key for current-page context."
  def data_key, do: @marker_key

  @doc "Returns the placeholder used when page context repeats."
  def unchanged_placeholder, do: @unchanged_placeholder

  @doc "Returns true when ACP metadata contains current-page context."
  def current_page_in_meta?(%{@marker_key => true}), do: true
  def current_page_in_meta?(_), do: false

  @doc "Extracts normalized fields from ACP/DB metadata."
  def fields_from_meta(nil), do: nil

  def fields_from_meta(meta) when is_map(meta) do
    case meta["url"] do
      url when is_binary(url) ->
        %{
          url: url,
          viewport_width: meta["viewport_width"],
          viewport_height: meta["viewport_height"],
          device_pixel_ratio: meta["device_pixel_ratio"],
          title: meta["title"],
          color_scheme: meta["color_scheme"],
          scroll_y: meta["scroll_y"]
        }

      _ ->
        nil
    end
  end

  def fields_from_meta(_), do: nil

  @doc "Appends current-page prompt context to user text when present."
  def append_prompt_section(text, nil), do: text

  def append_prompt_section(text, page) when is_binary(text) do
    case to_prompt_section(page) do
      "" -> text
      section -> text <> section
    end
  end

  @doc "Formats page context as the LLM-visible prompt section."
  def to_prompt_section(nil), do: ""

  def to_prompt_section(page) when is_map(page) do
    case page_value(page, :url) do
      url when is_binary(url) ->
        lines = ["URL: #{url}" | optional_prompt_lines(page)]
        "\n#{@header}\n#{Enum.join(lines, "\n")}\n"

      _ ->
        ""
    end
  end

  def to_prompt_section(_), do: ""

  @doc "Extracts and removes only the current-page prompt section from text."
  def extract_prompt_section(text) when is_binary(text) do
    case Regex.run(@prompt_section_pattern, text, return: :index) do
      [{start, length}] ->
        after_start = start + length

        stripped =
          binary_part(text, 0, start) <>
            binary_part(text, after_start, byte_size(text) - after_start)

        {stripped, binary_part(text, start, length)}

      nil ->
        nil
    end
  end

  def extract_prompt_section(_), do: nil

  @doc "Returns system-prompt guidance for current-page context."
  def guidance do
    """
    ## Current Page Context

    User messages may include `#{@header}` with URL, viewport, title,
    color scheme, and scroll position. Use it to identify the relevant route and
    responsive/theme constraints. Do not inspect the browser just because page
    context exists; prefer code/source inspection unless the task needs rendered
    state or visual verification.
    """
  end

  @doc "Builds ACP history content blocks for current-page context."
  def to_content_blocks(nil), do: []

  def to_content_blocks(page) when is_map(page) do
    case page_value(page, :url) do
      url when is_binary(url) ->
        [
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => to_meta(page),
              "resource" => %{
                "uri" => "page://#{url}",
                "mimeType" => "text/plain",
                "text" => "Current page: #{url}"
              }
            }
          }
        ]

      _ ->
        []
    end
  end

  def to_content_blocks(_), do: []

  defp optional_prompt_lines(page) do
    [
      viewport_line(page),
      device_pixel_ratio_line(page),
      title_line(page),
      color_scheme_line(page),
      scroll_line(page)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp viewport_line(page) do
    case {page_value(page, :viewport_width), page_value(page, :viewport_height)} do
      {width, height} when is_integer(width) and is_integer(height) ->
        "Viewport: #{width}x#{height}"

      _ ->
        nil
    end
  end

  defp device_pixel_ratio_line(page) do
    case page_value(page, :device_pixel_ratio) do
      device_pixel_ratio when is_number(device_pixel_ratio) ->
        "Device Pixel Ratio: #{device_pixel_ratio}"

      _ ->
        nil
    end
  end

  defp title_line(page) do
    case page_value(page, :title) do
      title when is_binary(title) -> "Page Title: #{title}"
      _ -> nil
    end
  end

  defp color_scheme_line(page) do
    case page_value(page, :color_scheme) do
      color_scheme when is_binary(color_scheme) -> "Color Scheme: #{color_scheme}"
      _ -> nil
    end
  end

  defp scroll_line(page) do
    case page_value(page, :scroll_y) do
      scroll_y when is_integer(scroll_y) -> "Scroll Position: #{scroll_y}px"
      _ -> nil
    end
  end

  defp to_meta(page) do
    %{
      @marker_key => true,
      "url" => page_value(page, :url),
      "viewport_width" => page_value(page, :viewport_width),
      "viewport_height" => page_value(page, :viewport_height),
      "device_pixel_ratio" => page_value(page, :device_pixel_ratio),
      "title" => page_value(page, :title),
      "color_scheme" => page_value(page, :color_scheme),
      "scroll_y" => page_value(page, :scroll_y)
    }
    |> reject_nils()
  end

  defp reject_nils(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp page_value(page, key) when is_atom(key) do
    Map.get(page, key) || Map.get(page, Atom.to_string(key))
  end
end
