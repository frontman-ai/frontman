defmodule FrontmanNotifier.TaskSummariesTest do
  use ExUnit.Case, async: true

  alias FrontmanNotifier.TaskSummaries

  test "build_summary_embed includes stats, user intent, and issue details" do
    task = %{
      "id" => "3f5167ad-56e7-45d3-ba95-6b8aba383d8f",
      "short_desc" => "Fix the hero button",
      "framework" => "nextjs",
      "email" => "person@example.com",
      "user_name" => "Person",
      "subscription_status" => "active",
      "subscription_interval" => "monthly",
      "inserted_at" => ~N[2026-05-18 10:00:00],
      "last_interaction_at" => ~N[2026-05-18 10:45:00],
      "interaction_count" => 7,
      "user_message_count" => 1,
      "agent_response_count" => 2,
      "agent_completed_count" => 0,
      "agent_error_count" => 1,
      "agent_paused_count" => 0,
      "tool_call_count" => 2,
      "tool_result_count" => 2,
      "tool_error_count" => 1,
      "tools_used" => ["edit_file", "read_file"]
    }

    interactions = [
      %{
        "type" => "user_message",
        "data" => %{"messages" => ["Make the hero button more prominent"]}
      },
      %{
        "type" => "agent_error",
        "data" => %{
          "kind" => "failed",
          "category" => "tool_failure",
          "retryable" => true,
          "error" => "Could not apply patch"
        }
      },
      %{
        "type" => "tool_result",
        "data" => %{
          "tool_name" => "edit_file",
          "is_error" => true,
          "result" => %{"content" => [%{"type" => "text", "text" => "Patch failed"}]}
        }
      }
    ]

    embed = TaskSummaries.build_summary_embed(task, interactions)

    assert embed.title == "Task summary: Fix the hero button"
    assert embed.description =~ "Make the hero button more prominent"
    assert embed.color == 0xED4245
    assert field_value(embed, "User") =~ "person@example.com"
    assert field_value(embed, "Billing") == "active · monthly"
    assert field_value(embed, "Stats") =~ "7 interactions"
    assert field_value(embed, "Issues") =~ "1 agent errors"
    assert field_value(embed, "Issue details") =~ "Could not apply patch"
    assert field_value(embed, "Issue details") =~ "Patch failed"
    assert field_value(embed, "Tools") == "edit_file, read_file"
  end

  test "billing displays subscription statuses without treating them as paid access" do
    for status <- ["trialing", "past_due", "canceled", "unpaid", "incomplete"] do
      embed =
        TaskSummaries.build_summary_embed(
          %{"subscription_status" => status, "subscription_interval" => "yearly"},
          []
        )

      assert field_value(embed, "Billing") == "#{status} · yearly"
    end
  end

  test "billing shows the lifetime free allowance for users without a subscription" do
    for {used, remaining} <- [{nil, 5}, {0, 5}, {2, 3}, {5, 0}] do
      embed =
        TaskSummaries.build_summary_embed(
          %{
            "subscription_status" => nil,
            "subscription_interval" => nil,
            "free_messages_used" => used
          },
          []
        )

      assert field_value(embed, "Billing") == "Free · #{remaining} of 5 messages left"
    end
  end

  test "billing displays status when the interval is absent" do
    embed =
      TaskSummaries.build_summary_embed(
        %{"subscription_status" => "canceled", "subscription_interval" => nil},
        []
      )

    assert field_value(embed, "Billing") == "canceled"
  end

  defp field_value(embed, name) do
    embed.fields
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:value)
  end
end
