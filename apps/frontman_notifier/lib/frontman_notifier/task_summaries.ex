defmodule FrontmanNotifier.TaskSummaries do
  @moduledoc """
  Posts summaries for recently idle production tasks.
  """

  require Logger

  alias FrontmanNotifier.Config
  alias FrontmanNotifier.Database
  alias FrontmanNotifier.Discord
  alias FrontmanNotifier.State

  @namespace :task_summary
  @discord_color_ok 0x57F287
  @discord_color_issue 0xED4245

  @candidate_query """
  SELECT
    t.id::text AS id,
    t.short_desc,
    t.framework,
    t.inserted_at,
    t.updated_at,
    u.email,
    u.name AS user_name,
    MAX(i.inserted_at) AS last_interaction_at,
    COUNT(i.id)::int AS interaction_count,
    (COUNT(*) FILTER (WHERE i.type = 'user_message'))::int AS user_message_count,
    (COUNT(*) FILTER (WHERE i.type = 'agent_response'))::int AS agent_response_count,
    (COUNT(*) FILTER (WHERE i.type = 'agent_completed'))::int AS agent_completed_count,
    (COUNT(*) FILTER (WHERE i.type = 'agent_error'))::int AS agent_error_count,
    (COUNT(*) FILTER (WHERE i.type = 'agent_paused'))::int AS agent_paused_count,
    (COUNT(*) FILTER (WHERE i.type = 'tool_call'))::int AS tool_call_count,
    (COUNT(*) FILTER (WHERE i.type = 'tool_result'))::int AS tool_result_count,
    (COUNT(*) FILTER (
      WHERE i.type = 'tool_result'
        AND COALESCE((i.data->>'is_error')::boolean, false) = true
    ))::int AS tool_error_count,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT i.data->>'tool_name'), NULL) AS tools_used
  FROM tasks t
  JOIN users u ON u.id = t.user_id
  JOIN interactions i ON i.task_id = t.id
  WHERE t.inserted_at >= timezone('UTC', now()) - ($2::int * interval '1 hour')
  GROUP BY t.id, t.short_desc, t.framework, t.inserted_at, t.updated_at, u.email, u.name
  HAVING MAX(i.inserted_at) <= timezone('UTC', now()) - ($3::int * interval '1 minute')
  ORDER BY last_interaction_at DESC
  LIMIT $1
  """

  @details_query """
  SELECT
    task_id::text AS task_id,
    type,
    data,
    inserted_at,
    sequence
  FROM interactions
  WHERE task_id::text = ANY($1::text[])
    AND (
      type IN ('user_message', 'agent_error', 'agent_paused', 'agent_completed')
      OR (
        type = 'tool_result'
        AND COALESCE((data->>'is_error')::boolean, false) = true
      )
    )
  ORDER BY task_id, COALESCE(sequence, 0), inserted_at
  """

  @spec check() :: {:ok, non_neg_integer()} | {:error, term()}
  def check do
    case Config.discord_task_summaries_webhook_url() do
      nil ->
        Logger.info("DISCORD_TASK_SUMMARIES_WEBHOOK_URL is not set; skipping task notifier")
        {:ok, 0}

      webhook_url ->
        post_task_summaries(webhook_url)
    end
  end

  @spec build_summary_embed(map(), list(map())) :: map()
  def build_summary_embed(task, interactions) when is_map(task) and is_list(interactions) do
    issue_count =
      int(task["agent_error_count"]) + int(task["tool_error_count"]) +
        int(task["agent_paused_count"])

    %{
      title: "Task summary: #{truncate(task["short_desc"] || "Untitled task", 240)}",
      color: embed_color(issue_count),
      description: truncate(user_attempt(task, interactions), 1_500),
      fields: [
        field("User", user_summary(task), true),
        field("Framework", task["framework"] || "unknown", true),
        field("Task ID", "`#{task["id"]}`", false),
        field("Stats", stats_summary(task), false),
        field("Issues", issues_summary(task), false),
        field("Issue details", issue_details(interactions), false),
        field("Tools", tools_summary(task), false),
        field("Timing", timing_summary(task), false)
      ],
      footer: %{text: "Frontman production task notifier"}
    }
  end

  defp post_task_summaries(webhook_url) do
    task_limit = Config.task_max_per_run()

    Database.with_connection(fn conn ->
      candidates = load_candidates(conn, task_limit * 5)

      tasks =
        candidates
        |> Enum.reject(&task_seen?/1)
        |> Enum.take(task_limit)

      details = load_details(conn, Enum.map(tasks, & &1["id"]))
      post_tasks(webhook_url, tasks, details)
    end)
  end

  defp load_candidates(conn, limit) do
    Database.query_maps!(conn, @candidate_query, [
      limit,
      Config.task_lookback_hours(),
      Config.task_idle_minutes()
    ])
  end

  defp load_details(_conn, []), do: %{}

  defp load_details(conn, task_ids) do
    conn
    |> Database.query_maps!(@details_query, [task_ids])
    |> Enum.group_by(& &1["task_id"])
  end

  defp post_tasks(webhook_url, tasks, details) do
    Enum.reduce_while(tasks, {:ok, 0}, fn task, {:ok, count} ->
      interactions = Map.get(details, task["id"], [])

      case Discord.post_embed(webhook_url, build_summary_embed(task, interactions)) do
        :ok ->
          State.mark_seen(@namespace, task["id"])
          {:cont, {:ok, count + 1}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp task_seen?(task) do
    State.seen?(@namespace, task["id"])
  end

  defp user_summary(task) do
    case task["user_name"] do
      nil -> task["email"] || "unknown"
      "" -> task["email"] || "unknown"
      name -> "#{name}\n#{task["email"]}"
    end
  end

  defp user_attempt(task, interactions) do
    messages =
      interactions
      |> Enum.filter(&(&1["type"] == "user_message"))
      |> Enum.flat_map(&messages_from_interaction/1)
      |> Enum.reject(&(&1 == ""))

    case messages do
      [] -> "What the user tried: #{task["short_desc"] || "No user message recorded."}"
      values -> "What the user tried:\n" <> (values |> Enum.take(3) |> Enum.join("\n\n"))
    end
  end

  defp messages_from_interaction(%{"data" => %{"messages" => messages}}) when is_list(messages) do
    Enum.map(messages, &message_text/1)
  end

  defp messages_from_interaction(_interaction), do: []

  defp message_text(value) when is_binary(value), do: value
  defp message_text(%{"content" => content}) when is_binary(content), do: content
  defp message_text(%{"text" => text}) when is_binary(text), do: text
  defp message_text(_value), do: ""

  defp stats_summary(task) do
    [
      "#{int(task["interaction_count"])} interactions",
      "#{int(task["user_message_count"])} user messages",
      "#{int(task["agent_response_count"])} agent responses",
      "#{int(task["tool_call_count"])} tool calls",
      "#{int(task["tool_result_count"])} tool results",
      "#{int(task["agent_completed_count"])} completions"
    ]
    |> Enum.join(" · ")
  end

  defp issues_summary(task) do
    [
      "#{int(task["agent_error_count"])} agent errors",
      "#{int(task["tool_error_count"])} tool errors",
      "#{int(task["agent_paused_count"])} pauses"
    ]
    |> Enum.join(" · ")
  end

  defp issue_details(interactions) do
    details =
      interactions
      |> Enum.flat_map(&issue_detail/1)
      |> Enum.take(8)

    case details do
      [] -> "No recorded errors or pauses."
      values -> Enum.join(values, "\n")
    end
  end

  defp issue_detail(%{"type" => "agent_error", "data" => data}) do
    category = data["category"] || "unknown"
    kind = data["kind"] || "failed"
    retryable = data["retryable"] || false

    [
      "Agent #{kind} (#{category}, retryable: #{retryable}): #{truncate(data["error"] || "", 260)}"
    ]
  end

  defp issue_detail(%{"type" => "agent_paused", "data" => data}) do
    ["Agent paused: #{truncate(data["reason"] || "", 260)}"]
  end

  defp issue_detail(%{"type" => "tool_result", "data" => %{"is_error" => true} = data}) do
    tool_name = data["tool_name"] || "unknown tool"
    ["Tool #{tool_name} error: #{truncate(tool_error_text(data["result"]), 260)}"]
  end

  defp issue_detail(_interaction), do: []

  defp tool_error_text(%{"content" => [%{"text" => text} | _]}) when is_binary(text), do: text
  defp tool_error_text(value) when is_binary(value), do: value
  defp tool_error_text(value), do: inspect(value, limit: 20)

  defp tools_summary(%{"tools_used" => tools}) when is_list(tools) do
    case Enum.reject(tools, &is_nil/1) do
      [] -> "No tools recorded."
      values -> values |> Enum.sort() |> Enum.join(", ") |> truncate(1_000)
    end
  end

  defp tools_summary(_task), do: "No tools recorded."

  defp timing_summary(task) do
    [
      "Started: #{format_time(task["inserted_at"])}",
      "Last interaction: #{format_time(task["last_interaction_at"])}"
    ]
    |> Enum.join("\n")
  end

  defp field(name, value, inline) do
    %{name: name, value: value |> to_string() |> truncate(1_000), inline: inline}
  end

  defp embed_color(0), do: @discord_color_ok
  defp embed_color(_issue_count), do: @discord_color_issue

  defp format_time(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
  end

  defp format_time(%DateTime{} = datetime) do
    datetime |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  end

  defp format_time(nil), do: "unknown"

  defp format_time(value), do: to_string(value)

  defp int(nil), do: 0
  defp int(value) when is_integer(value), do: value

  defp truncate(nil, _max), do: ""

  defp truncate(value, max) when is_binary(value) and max > 0 do
    case String.length(value) > max do
      true -> String.slice(value, 0, max - 3) <> "..."
      false -> value
    end
  end
end
