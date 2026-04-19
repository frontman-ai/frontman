# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Mix.Tasks.DebugTask do
  @shortdoc "Debug task interactions from the database"
  @moduledoc """
  Query tasks and interactions for debugging agent behavior.

  ## Usage

      # List recent tasks with error counts
      mix debug_task list
      mix debug_task list --limit 10

      # Show all interactions for the most recent task
      mix debug_task show

      # Show a specific task by full UUID or prefix (min 8 chars)
      mix debug_task show 3f5167ad
      mix debug_task show 3f5167ad-56e7-45d3-ba95-6b8aba383d8f

      # Filter by errors only
      mix debug_task show --errors

      # Filter by tool name
      mix debug_task show --tool edit_file

      # Filter by interaction type
      mix debug_task show --type tool_call

      # Show full detail for a specific interaction by sequence number
      mix debug_task show --seq 280

      # Combine filters
      mix debug_task show --tool edit_file --errors

  ## Interaction types

  user_message, agent_response, tool_call, tool_result,
  agent_spawned, agent_completed, discovered_project_rule,
  discovered_project_structure
  """

  use Boundary, classify_to: FrontmanServer.Mix
  use Mix.Task

  import Ecto.Query

  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.TaskSchema

  # ANSI helpers
  defp cyan(text), do: IO.ANSI.cyan() <> text <> IO.ANSI.reset()
  defp red(text), do: IO.ANSI.red() <> text <> IO.ANSI.reset()
  defp bold(text), do: IO.ANSI.bright() <> text <> IO.ANSI.reset()
  defp dim(text), do: IO.ANSI.faint() <> text <> IO.ANSI.reset()
  defp yellow(text), do: IO.ANSI.yellow() <> text <> IO.ANSI.reset()
  defp magenta(text), do: IO.ANSI.magenta() <> text <> IO.ANSI.reset()
  defp green(text), do: IO.ANSI.green() <> text <> IO.ANSI.reset()

  @impl Mix.Task
  def run(args) do
    ensure_repo_started()

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [
          errors: :boolean,
          tool: :string,
          type: :string,
          seq: :integer,
          limit: :integer
        ]
      )

    case positional do
      ["list" | _] ->
        cmd_list(opts)

      ["show" | rest] ->
        cmd_show(rest, opts)

      [] ->
        cmd_show([], opts)

      other ->
        Mix.shell().error(
          "Unknown command: #{Enum.join(other, " ")}\nRun `mix help debug_task` for usage."
        )
    end
  end

  # ── list ──────────────────────────────────────────────────────

  defp cmd_list(opts) do
    limit = Keyword.get(opts, :limit, 10)

    tasks =
      TaskSchema
      |> TaskSchema.ordered_by_updated()
      |> TaskSchema.limited(limit)
      |> Repo.all()

    Mix.shell().info("\n#{bold("Recent Tasks (#{length(tasks)})")}")
    Mix.shell().info(String.duplicate("─", 60))

    for task <- tasks do
      count = interaction_count(task.id)
      error_count = error_count(task.id)
      prefix = task.id |> String.split("-") |> hd()
      date = Calendar.strftime(task.updated_at, "%Y-%m-%d %H:%M")
      desc = truncate(task.short_desc || "(no description)", 60)

      error_str =
        if error_count > 0,
          do: "  #{red("#{error_count} errors")}",
          else: ""

      Mix.shell().info(
        "  #{cyan(prefix)}  #{date}  #{count} interactions#{error_str}\n  #{desc}\n"
      )
    end
  end

  # ── show ──────────────────────────────────────────────────────

  defp cmd_show(positional, opts) do
    task = resolve_task_from_args(positional)

    error_count = error_count(task.id)

    Mix.shell().info(
      "\n#{bold("Task #{short_id(task.id)} | #{truncate(task.short_desc || "(no description)", 50)} | #{Calendar.strftime(task.updated_at, "%Y-%m-%d %H:%M")} | errors: #{error_count}")}"
    )

    Mix.shell().info(String.duplicate("─", 96))

    if opts[:seq] do
      show_detail(task.id, opts[:seq])
    else
      show_list(task.id, opts)
    end
  end

  # ── show_list ─────────────────────────────────────────────────

  defp show_list(task_id, opts) do
    limit = Keyword.get(opts, :limit, 100)

    query =
      InteractionSchema
      |> InteractionSchema.for_task(task_id)
      |> InteractionSchema.ordered()
      |> apply_filters(opts)
      |> limit(^limit)

    interactions = Repo.all(query)

    Mix.shell().info("  #{length(interactions)} interactions\n")

    for i <- interactions do
      print_interaction_line(i)
    end

    Mix.shell().info("\n#{dim("  Tip: --seq NUMBER for full detail on any interaction")}")
  end

  # ── show_detail ───────────────────────────────────────────────

  defp show_detail(task_id, seq) do
    interaction =
      InteractionSchema
      |> InteractionSchema.for_task(task_id)
      |> where([i], i.sequence == ^seq)
      |> Repo.one()

    case interaction do
      nil ->
        Mix.shell().error("No interaction found with sequence #{seq}")

      i ->
        is_error = get_in(i.data, ["is_error"]) == true
        error_label = if is_error, do: "\n  #{red("is_error: true")}", else: ""

        Mix.shell().info(
          "  #{bold(i.type)}  seq=#{i.sequence}  id=#{i.id}\n  timestamp: #{i.inserted_at}#{error_label}\n"
        )

        Mix.shell().info(format_json(i.data))

        # For error tool_results, show the originating tool_call
        if i.type == "tool_result" and is_error do
          show_originating_call(task_id, i.data["tool_call_id"])
        end

        # For tool_results, always show the originating call if not an error too
        if i.type == "tool_result" and not is_error and i.data["tool_call_id"] do
          show_originating_call(task_id, i.data["tool_call_id"])
        end
    end
  end

  defp show_originating_call(_task_id, nil) do
    Mix.shell().info(dim("\n  (no tool_call_id to look up originating call)"))
  end

  defp show_originating_call(task_id, tool_call_id) do
    call =
      InteractionSchema
      |> InteractionSchema.for_task(task_id)
      |> where([i], i.type == "tool_call")
      |> where([i], fragment("?->>'tool_call_id' = ?", i.data, ^tool_call_id))
      |> Repo.one()

    case call do
      nil ->
        Mix.shell().info(dim("\n  (originating tool_call not found for #{tool_call_id})"))

      c ->
        Mix.shell().info("\n#{bold("  Originating tool_call (seq #{c.sequence})")}\n")
        Mix.shell().info(format_json(c.data))
    end
  end

  # ── query filters ─────────────────────────────────────────────

  defp apply_filters(query, opts) do
    query
    |> maybe_filter_errors(opts[:errors])
    |> maybe_filter_type(opts[:type])
    |> maybe_filter_tool(opts[:tool])
  end

  defp maybe_filter_errors(query, true) do
    query
    |> where([i], i.type == "tool_result")
    |> where([i], fragment("(?->>'is_error')::boolean = true", i.data))
  end

  defp maybe_filter_errors(query, _), do: query

  defp maybe_filter_type(query, nil), do: query

  defp maybe_filter_type(query, type) do
    where(query, [i], i.type == ^type)
  end

  defp maybe_filter_tool(query, nil), do: query

  defp maybe_filter_tool(query, tool) do
    where(query, [i], fragment("?->>'tool_name' = ?", i.data, ^tool))
  end

  # ── task resolution ───────────────────────────────────────────

  defp resolve_task_from_args([]) do
    # No task specified — use the most recent
    task =
      TaskSchema
      |> TaskSchema.ordered_by_updated()
      |> TaskSchema.limited(1)
      |> Repo.one()

    task || Mix.raise("No tasks found in the database.")
  end

  defp resolve_task_from_args([id_or_prefix | _]) do
    resolve_task(id_or_prefix)
  end

  defp resolve_task(id) do
    cond do
      # Full UUID
      String.match?(id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) ->
        TaskSchema
        |> TaskSchema.by_id(id)
        |> Repo.one()
        |> case do
          nil -> Mix.raise("Task not found: #{id}")
          task -> task
        end

      # Prefix (at least 8 hex chars)
      String.match?(id, ~r/^[0-9a-f]{8,}$/i) ->
        like_pattern = "#{String.downcase(id)}%"

        tasks =
          from(t in TaskSchema,
            where: fragment("CAST(? AS text) LIKE ?", t.id, ^like_pattern),
            order_by: [desc: t.updated_at],
            limit: 2
          )
          |> Repo.all()

        case tasks do
          [] ->
            Mix.raise("No task found matching prefix: #{id}")

          [task] ->
            task

          [_ | _] ->
            Mix.raise(
              "Ambiguous prefix '#{id}' — matches multiple tasks. Use a longer prefix or full UUID."
            )
        end

      true ->
        Mix.raise(
          "Invalid task ID or prefix: #{id}. Expected a UUID or hex prefix (min 8 chars)."
        )
    end
  end

  # ── formatting helpers ────────────────────────────────────────

  defp print_interaction_line(i) do
    seq_str = String.pad_leading(to_string(i.sequence || 0), 6)
    is_error = get_in(i.data, ["is_error"]) == true
    tool_name = i.data["tool_name"]
    error_tag = if is_error, do: " #{red("ERROR")}", else: ""

    type_str = format_type(i.type)

    summary = interaction_summary(i)

    tool_str = if tool_name, do: "  #{bold(tool_name)}", else: ""

    Mix.shell().info("  #{dim(seq_str)} #{type_str}#{error_tag}#{tool_str} -> #{summary}")
  end

  defp format_type("tool_call"), do: yellow("tool_call      ")
  defp format_type("tool_result"), do: magenta("tool_result    ")
  defp format_type("agent_response"), do: green("agent_response ")
  defp format_type("user_message"), do: cyan("user_message   ")
  defp format_type("agent_spawned"), do: dim("agent_spawned  ")
  defp format_type("agent_completed"), do: dim("agent_completed")
  defp format_type("discovered_project_rule"), do: dim("project_rule   ")
  defp format_type("discovered_project_structure"), do: dim("project_struct ")
  defp format_type(other), do: dim(String.pad_trailing(other, 15))

  defp interaction_summary(%{type: "tool_call", data: data}) do
    args = data["arguments"] || %{}

    arg_keys =
      args
      |> Map.keys()
      |> Enum.join(", ")

    if arg_keys == "", do: "()", else: "(#{arg_keys})"
  end

  defp interaction_summary(%{type: "tool_result", data: data}) do
    is_error = data["is_error"] == true
    result = data["result"]

    cond do
      is_error && is_map(result) ->
        text =
          get_in(result, ["content", Access.at(0), "text"]) ||
            inspect(result)

        red(truncate(text, 80))

      is_map(result) ->
        summarize_tool_result_map(result)

      is_binary(result) ->
        truncate(result, 80)

      true ->
        inspect(result) |> truncate(80)
    end
  end

  defp interaction_summary(%{type: "agent_response", data: data}) do
    truncate(data["content"] || "", 80)
  end

  defp interaction_summary(%{type: "user_message", data: data}) do
    messages = data["messages"] || []

    case messages do
      [first | _] when is_binary(first) ->
        truncate(first, 80)

      [first | _] when is_map(first) ->
        truncate(first["content"] || first["text"] || "", 80)

      _ ->
        "(#{length(messages)} messages)"
    end
  end

  defp interaction_summary(%{type: "discovered_project_rule", data: data}) do
    data["path"] || ""
  end

  defp interaction_summary(%{type: "discovered_project_structure", data: data}) do
    truncate(data["summary"] || "", 80)
  end

  defp interaction_summary(%{type: "agent_spawned", data: data}) do
    truncate(inspect(data["config"] || %{}), 80)
  end

  defp interaction_summary(%{type: "agent_completed", data: data}) do
    truncate(data["result"] || "", 80)
  end

  defp interaction_summary(%{data: data}) do
    truncate(inspect(data), 60)
  end

  defp summarize_tool_result_map(result) do
    content = result["content"]

    cond do
      is_list(content) && content != [] ->
        summarize_content_item(hd(content), result)

      is_map(content) ->
        "{#{map_keys_summary(content)}}"

      true ->
        "{#{map_keys_summary(result)}}"
    end
  end

  defp summarize_content_item(%{"type" => "text"} = item, _result),
    do: truncate(item["text"] || "", 80)

  defp summarize_content_item(%{"type" => "image"}, _result),
    do: "{screenshot}"

  defp summarize_content_item(_item, result),
    do: "{#{map_keys_summary(result)}}"

  defp map_keys_summary(map) when is_map(map) do
    map |> Map.keys() |> Enum.sort() |> Enum.join(", ")
  end

  defp map_keys_summary(_), do: "..."

  defp format_json(data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} -> json
      _ -> inspect(data, pretty: true, limit: :infinity)
    end
  end

  defp truncate(nil, _max), do: ""

  defp truncate(str, max) when is_binary(str) do
    if String.length(str) > max do
      String.slice(str, 0, max) <> "..."
    else
      str
    end
  end

  defp truncate(other, max), do: truncate(inspect(other), max)

  defp short_id(id) do
    id |> String.split("-") |> hd()
  end

  # Start only the Repo (and its dependencies) instead of the full app.
  # This avoids needing Vault/CLOAK_KEY, WorkOS, Phoenix, etc.
  defp ensure_repo_started do
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:jason)
    _ = Repo.start_link()
    :ok
  end

  defp interaction_count(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> select([i], count(i.id))
    |> Repo.one()
  end

  defp error_count(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> where([i], i.type == "tool_result")
    |> where([i], fragment("(?->>'is_error')::boolean = true", i.data))
    |> select([i], count(i.id))
    |> Repo.one()
  end
end
