defmodule FrontmanServer.Tasks.EditEligibilityTest do
  use FrontmanServer.DataCase, async: true
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.{Repo, Tasks}

  test "history requires a successful editing result and completion in the same turn" do
    scope = user_scope_fixture()
    task = task_fixture(scope)

    for {name, result, outcome} <- [
          {"wp_update_post", native_result(%{"dry_run" => true}), :completed},
          {"read_file", native_result(%{"content" => "read"}), :completed},
          {"edit_file", %{"isError" => true, "content" => []}, :completed},
          {"write_file", native_result(%{"success" => true}), :cancelled},
          {"write_file", native_result(%{"success" => true}), {:failed, "failed"}}
        ] do
      persist_result(scope, task, name, result, outcome)
      refute Tasks.earlier_edit?(scope)
    end

    turn = start_turn_fixture(scope, task.id)
    assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, :completed)
    refute Tasks.earlier_edit?(scope)

    for _ <- 1..15 do
      persist_result(scope, task, "write_file", native_result(%{"dry_run" => true}))
    end

    completion = persist_result(scope, task, "write_file", native_result(%{"success" => true}))
    assert Tasks.earlier_edit?(scope)
    refute Tasks.earlier_edit?(scope, completion.id)
    refute Tasks.earlier_edit?(user_scope_fixture())
  end

  test "native result qualification is identical for persisted SEO and WooCommerce edits" do
    for name <- ~w(wp_update_term_seo wp_update_post_type_archive_seo
                    wc_update_product_meta wc_delete_product_meta wc_update_order_meta
                    wc_delete_order_meta wc_update_customer_meta wc_delete_customer_meta) do
      scope = user_scope_fixture()
      task = task_fixture(scope)

      for result <- [
            %{"isError" => true, "content" => []},
            native_result(%{"success" => false}),
            native_result(%{"updated" => false}),
            native_result(%{"dryRun" => true}),
            native_result(%{"dry_run" => true}),
            native_result(%{"before" => "same", "after" => "same"})
          ] do
        refute Tasks.editing_success?(name, result)
        persist_result(scope, task, name, result)
        refute Tasks.earlier_edit?(scope)
      end

      result = native_result(%{"success" => true})
      assert Tasks.editing_success?(name, result)
      persist_result(scope, task, name, result)
      assert Tasks.earlier_edit?(scope)
    end
  end

  defp persist_result(scope, task, name, result, outcome \\ :completed) do
    turn = start_turn_fixture(scope, task.id)
    call = %SwarmAi.ToolCall{id: Ecto.UUID.generate(), name: name, arguments: "{}"}
    assert {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :synchronous)
    assert {:ok, _, :no_executor} = Tasks.resolve_tool_request(scope, task.id, call, result)
    assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, outcome)

    Repo.get_by(Tasks.InteractionSchema,
      task_id: task.id,
      turn_number: turn,
      type: :agent_completed
    )
  end

  defp native_result(payload),
    do: %{"content" => [%{"type" => "text", "text" => Jason.encode!(payload)}]}
end
