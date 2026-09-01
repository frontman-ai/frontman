defmodule FrontmanServer.Tasks.ToolCallClaimConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.MCPRecovery
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.ToolCallClaimToken
  alias ModelContextProtocol, as: MCP

  test "competing claim acquisitions have one winner" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "one-winner")
      parent = self()

      contenders =
        for owner <- ["connection-1", "connection-2"] do
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              send(parent, {:ready, self()})

              receive do
                :acquire ->
                  Tasks.acquire_tool_call_claim(
                    scope,
                    reference,
                    owner,
                    5_000,
                    :verified_idempotent
                  )
              after
                1_000 -> raise "timed out waiting to acquire claim"
              end
            end)
          end)
        end

      assert_receive {:ready, _pid}, 1_000
      assert_receive {:ready, _pid}, 1_000
      Enum.each(contenders, &send(&1.pid, :acquire))

      results = Enum.map(contenders, &Task.await(&1, 2_000))
      assert Enum.count(results, &match?({:ok, %ToolCallClaimToken{}}, &1)) == 1
      assert Enum.count(results, &match?({:error, :already_claimed}, &1)) == 1
    end)
  end

  test "independent connections serialize duplicate logical creation and acquisition" do
    unboxed_case(fn scope ->
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)
      tool_call = %SwarmAi.ToolCall{id: "logical-race", name: "question", arguments: "{}"}

      creation_results =
        race_on_independent_connections(["node-a", "node-b"], fn _node_identity ->
          Tasks.request_client_tool_with_reference(scope, task_id, turn_number, tool_call)
        end)

      assert Enum.count(creation_results, fn {_backend, result} ->
               match?({:ok, _, %Interaction.ToolCall{}}, result)
             end) == 1

      assert Enum.count(creation_results, fn {_backend, result} ->
               match?({:error, :duplicate_tool_call}, result)
             end) == 1

      assert creation_results |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 2

      [%InteractionSchema{id: interaction_id, data: persisted}] =
        InteractionSchema
        |> InteractionSchema.for_task(task_id)
        |> InteractionSchema.for_turn(turn_number)
        |> InteractionSchema.of_type(:tool_call)
        |> Repo.all()

      reference = %Tasks.ToolCallExecutionReference{
        interaction_id: interaction_id,
        task_id: task_id,
        turn_number: turn_number,
        tool_call_id: persisted.tool_call_id,
        tool_name: persisted.tool_name
      }

      claim_results =
        race_on_independent_connections(["node-a", "node-b"], fn node_identity ->
          Tasks.acquire_tool_call_claim(
            scope,
            reference,
            node_identity,
            60_000,
            :verified_idempotent
          )
        end)

      assert Enum.count(claim_results, fn {_backend, result} ->
               match?({:ok, %ToolCallClaimToken{}}, result)
             end) == 1

      assert Enum.count(claim_results, fn {_backend, result} ->
               match?({:error, :already_claimed}, result)
             end) == 1

      assert claim_results |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 2
    end)
  end

  test "database lease generation and expiration boundary are exact" do
    unboxed_case(fn _scope ->
      {database_now, lease_expires_at} = Tasks.generate_tool_call_lease(60_000)

      assert DateTime.diff(lease_expires_at, database_now, :millisecond) == 60_000
      assert DateTime.diff(lease_expires_at, database_now, :microsecond) == 60_000_000

      one_microsecond_before = DateTime.add(lease_expires_at, -1, :microsecond)
      one_microsecond_after = DateTime.add(lease_expires_at, 1, :microsecond)

      assert Tasks.classify_tool_call_lease(lease_expires_at, one_microsecond_before) == :active
      assert Tasks.classify_tool_call_lease(lease_expires_at, lease_expires_at) == :active
      assert Tasks.classify_tool_call_lease(lease_expires_at, one_microsecond_after) == :expired
    end)
  end

  test "durable deadline boundary is exact" do
    deadline_at = DateTime.utc_now()
    one_microsecond_before = DateTime.add(deadline_at, -1, :microsecond)
    one_microsecond_after = DateTime.add(deadline_at, 1, :microsecond)

    assert Tasks.classify_tool_call_deadline(deadline_at, one_microsecond_before) == :active
    assert Tasks.classify_tool_call_deadline(deadline_at, deadline_at) == :active
    assert Tasks.classify_tool_call_deadline(deadline_at, one_microsecond_after) == :expired
  end

  test "claim acquisition fails loudly for duplicate logical tool-call rows" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "duplicate-logical-call")

      InteractionSchema.create_changeset(
        reference.task_id,
        :tool_call,
        %{
          tool_call_id: reference.tool_call_id,
          tool_name: reference.tool_name,
          arguments: %{}
        },
        reference.turn_number
      )
      |> Repo.insert!()

      assert {:error, :duplicate_logical_tool_call} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :verified_idempotent
               )
    end)
  end

  test "an expired claim is taken over with a higher generation" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "takeover")

      assert {:ok, first} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 1,
                 :verified_idempotent
               )

      expire_claim_one_microsecond_ago(reference)

      assert {:ok, second} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-2",
                 5_000,
                 :verified_idempotent
               )

      assert first.generation == 1
      assert second.generation == 2
      assert second.started_at == first.started_at
      assert second.deadline_at == first.deadline_at
    end)
  end

  test "claim acquisition persists one immutable absolute deadline" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "durable-deadline")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :verified_idempotent,
                 60_000
               )

      assert DateTime.diff(token.deadline_at, token.started_at, :microsecond) == 60_000_000
      assert {:ok, delay_ms} = Tasks.tool_call_deadline_delay_ms(scope, token)
      assert delay_ms in 59_900..60_000

      persisted = Repo.get!(InteractionSchema, reference.interaction_id).data.execution_claim
      assert persisted.started_at == token.started_at
      assert persisted.deadline_at == token.deadline_at
    end)
  end

  test "a former owner is fenced after lease takeover" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "stale-owner")

      assert {:ok, stale_token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 1,
                 :verified_idempotent
               )

      expire_claim_one_microsecond_ago(reference)

      assert {:error, :claim_expired} =
               Tasks.renew_tool_call_claim(scope, stale_token, 5_000)

      assert {:error, :claim_expired} =
               Tasks.complete_claimed_tool_call(scope, stale_token, MCP.tool_result_text("late"))

      assert {:ok, _current_token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-2",
                 5_000,
                 :verified_idempotent
               )

      assert {:error, :stale_claim} = Tasks.mark_tool_call_dispatch_started(scope, stale_token)

      assert {:error, :stale_claim} =
               Tasks.complete_claimed_tool_call(scope, stale_token, MCP.tool_result_text("late"))

      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end)
  end

  test "renewal extends only the matching active generation" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "renewal")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :verified_idempotent
               )

      assert {:ok, renewed} = Tasks.renew_tool_call_claim(scope, token, 10_000)
      assert renewed.generation == token.generation
      assert DateTime.compare(renewed.lease_expires_at, token.lease_expires_at) == :gt

      stale = %{token | generation: token.generation + 1}
      assert {:error, :stale_claim} = Tasks.renew_tool_call_claim(scope, stale, 10_000)
    end)
  end

  test "non-idempotent dispatch does not automatically replay after expiry" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "ambiguous-dispatch")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 50,
                 :non_idempotent
               )

      assert {:ok, _token} = Tasks.mark_tool_call_dispatch_started(scope, token)
      Repo.query!("SELECT pg_sleep(0.06)")

      assert {:error, :dispatch_ambiguous} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-2",
                 5_000,
                 :non_idempotent
               )
    end)
  end

  test "invalid peer completion atomically stores one canonical error and completes the claim" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "transactional-completion")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :non_idempotent
               )

      assert {:ok, ^token} = Tasks.mark_tool_call_dispatch_started(scope, token)

      assert {:ok, %Interaction.ToolResult{is_error: true} = result, :no_executor} =
               Tasks.complete_claimed_tool_call(scope, token, %{"content" => []})

      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)
      [tool_call] = Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolCall{}, &1))
      assert tool_call.execution_claim.resolution_state == :completed
      assert MCP.extract_content_text(result.result) == "Invalid MCP tool result"

      assert {:ok, %Interaction.ToolResult{id: result_id}, :already_resolved} =
               Tasks.complete_claimed_tool_call(scope, token, MCP.tool_result_text("complete"))

      assert result_id == result.id
      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

      assert [%Interaction.ToolCall{execution_claim: claim}] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolCall{}, &1))

      assert claim.resolution_state == :completed

      assert [_result] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end)
  end

  test "completion rejects a claim whose dispatch has not started" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "undispatched-completion")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :verified_idempotent
               )

      assert {:error, :dispatch_not_started} =
               Tasks.complete_claimed_tool_call(scope, token, MCP.tool_result_text("impossible"))

      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end)
  end

  test "completion and timeout after the durable deadline converge on one timeout result" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "deadline-race")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 5_000,
                 :non_idempotent,
                 60_000
               )

      assert {:ok, token} = Tasks.mark_tool_call_dispatch_started(scope, token)
      expire_deadline_one_microsecond_ago(reference)

      results =
        race_on_independent_connections([:completion, :timeout], fn
          :completion ->
            Tasks.complete_claimed_tool_call(scope, token, MCP.tool_result_text("late success"))

          :timeout ->
            Tasks.timeout_claimed_tool_call(scope, token, "Tool execution timed out")
        end)

      assert Enum.all?(results, fn {_backend, result} -> match?({:ok, _, _}, result) end)
      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

      assert [%Interaction.ToolResult{result: result, is_error: true}] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

      assert MCP.extract_content_text(result) == "Tool execution timed out"
      assert Tasks.restart_recovery_pending?(scope, reference.task_id)
      assert :ok = Tasks.complete_restart_recovery(scope, reference.task_id)
      refute Tasks.restart_recovery_pending?(scope, reference.task_id)
    end)
  end

  test "live executor delivery clears the durable restart resume marker" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "delivered-result")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 60_000,
                 :non_idempotent
               )

      assert {:ok, token} = Tasks.mark_tool_call_dispatch_started(scope, token)

      key = {:tool_call, reference.task_id, reference.tool_call_id}

      {:ok, _owner} =
        Registry.register(FrontmanServer.ToolCallRegistry, key, %{caller_pid: self()})

      assert {:ok, %Interaction.ToolResult{}, :notified} =
               Tasks.complete_claimed_tool_call(
                 scope,
                 token,
                 MCP.tool_result_text("delivered")
               )

      assert_receive {:tool_result, "delivered-result", _content, false}
      refute Tasks.restart_recovery_pending?(scope, reference.task_id)

      persisted = Repo.get!(InteractionSchema, reference.interaction_id).data.execution_claim
      assert persisted.recovery_state == :resumed
      Registry.unregister(FrontmanServer.ToolCallRegistry, key)
    end)
  end

  test "caller death after terminal commit preserves recovery evidence before notification" do
    shared_case(fn scope ->
      reference = execution_reference(scope, "post-commit-death")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "connection-1",
                 60_000,
                 :non_idempotent
               )

      assert {:ok, token} = Tasks.mark_tool_call_dispatch_started(scope, token)

      key = {:tool_call, reference.task_id, reference.tool_call_id}

      {:ok, _owner} =
        Registry.register(FrontmanServer.ToolCallRegistry, key, %{caller_pid: self()})

      handler_id = "post-commit-death-#{System.unique_integer([:positive])}"
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          [:frontman_server, :mcp, :tool_call, :committed],
          fn _event, _measurements, metadata, parent ->
            send(parent, {:tool_call_committed, self(), metadata})

            receive do
              :continue_delivery -> :ok
            after
              2_000 -> exit(:commit_checkpoint_timeout)
            end
          end,
          parent
        )

      try do
        caller =
          spawn(fn ->
            Tasks.complete_claimed_tool_call(scope, token, MCP.tool_result_text("committed"))
          end)

        monitor = Process.monitor(caller)

        assert_receive {:tool_call_committed, ^caller,
                        %{
                          result_interaction_id: result_interaction_id,
                          task_id: task_id,
                          tool_call_id: tool_call_id
                        }},
                       1_000

        assert is_binary(result_interaction_id)
        assert task_id == reference.task_id
        assert tool_call_id == reference.tool_call_id
        Process.exit(caller, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^caller, :killed}, 1_000

        assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

        assert [%Interaction.ToolResult{}] =
                 Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

        assert Tasks.restart_recovery_pending?(scope, reference.task_id)
        refute_receive {:tool_result, "post-commit-death", _content, _is_error}, 50

        assert :ok = Tasks.complete_restart_recovery(scope, reference.task_id)
        refute Tasks.restart_recovery_pending?(scope, reference.task_id)
      after
        :telemetry.detach(handler_id)
        Registry.unregister(FrontmanServer.ToolCallRegistry, key)
      end
    end)
  end

  test "startup recovery resolves expired pre-send and ambiguous post-dispatch claims in a bound" do
    unboxed_case(fn scope ->
      pre_send = execution_reference(scope, "recover-pre-send")
      ambiguous = execution_reference(scope, "recover-ambiguous")

      assert {:ok, _pre_send_token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 pre_send,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      assert {:ok, ambiguous_token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 ambiguous,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      assert {:ok, _token} = Tasks.mark_tool_call_dispatch_started(scope, ambiguous_token)
      expire_deadline_one_microsecond_ago(pre_send)
      expire_claim_one_microsecond_ago(ambiguous)

      assert [{:resolved, first_id}] = Tasks.recover_tool_call_claims(1)
      assert first_id in [pre_send.interaction_id, ambiguous.interaction_id]
      assert [{:resolved, second_id}] = Tasks.recover_tool_call_claims(1)

      assert MapSet.new([first_id, second_id]) ==
               MapSet.new([pre_send.interaction_id, ambiguous.interaction_id])

      assert Tasks.recover_tool_call_claims(1) == []
      assert {:ok, pre_send_task} = Tasks.get_task(scope, pre_send.task_id)
      assert {:ok, ambiguous_task} = Tasks.get_task(scope, ambiguous.task_id)

      results =
        [pre_send_task, ambiguous_task]
        |> Enum.flat_map(&Tasks.interactions/1)
        |> Enum.filter(&match?(%Interaction.ToolResult{}, &1))

      assert length(results) == 2
      assert Enum.all?(results, & &1.is_error)
    end)
  end

  test "task cancellation resolves every durable claim without a live MCP owner" do
    unboxed_case(fn scope ->
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)

      tokens =
        for call_id <- ["cancel-one", "cancel-two"] do
          tool_call = %SwarmAi.ToolCall{id: call_id, name: "question", arguments: "{}"}

          assert {:ok, reference, %Interaction.ToolCall{}} =
                   Tasks.request_client_tool_with_reference(
                     scope,
                     task.id,
                     turn_number,
                     tool_call
                   )

          assert {:ok, token} =
                   Tasks.acquire_tool_call_claim(
                     scope,
                     reference,
                     "departed-owner",
                     60_000,
                     :non_idempotent
                   )

          assert {:ok, token} = Tasks.mark_tool_call_dispatch_started(scope, token)
          token
        end

      assert length(tokens) == 2

      assert {:ok, 2} =
               Tasks.cancel_claimed_tool_calls_for_task(scope, task.id, "Task cancelled")

      assert {:ok, 0} =
               Tasks.cancel_claimed_tool_calls_for_task(scope, task.id, "Task cancelled")

      assert {:ok, loaded} = Tasks.get_task(scope, task.id)
      results = Enum.filter(Tasks.interactions(loaded), &match?(%Interaction.ToolResult{}, &1))
      assert length(results) == 2
      assert Enum.all?(results, &(MCP.extract_content_text(&1.result) == "Task cancelled"))
    end)
  end

  test "task cancellation fences a persisted tool call before claim acquisition" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "cancel-before-claim")

      assert {:ok, 1} =
               Tasks.cancel_claimed_tool_calls_for_task(
                 scope,
                 reference.task_id,
                 "Task cancelled"
               )

      assert {:error, :already_resolved} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "late-owner",
                 60_000,
                 :non_idempotent
               )

      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

      assert [%Interaction.ToolResult{result: result}] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

      assert MCP.extract_content_text(result) == "Task cancelled"
    end)
  end

  test "concurrent recovery passes converge without duplicate terminal work" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "concurrent-recovery")

      assert {:ok, _token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      expire_deadline_one_microsecond_ago(reference)

      results =
        race_on_independent_connections([:recovery_one, :recovery_two], fn _identity ->
          Tasks.recover_tool_call_claims(1)
        end)

      assert results
             |> Enum.flat_map(fn {_backend, recovered} -> recovered end)
             |> Enum.count(&match?({:resolved, _interaction_id}, &1)) == 1

      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

      assert [_result] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end)
  end

  test "task cancellation racing recovery consumes the durable resume marker" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "cancel-recovery-race")

      assert {:ok, _token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      expire_deadline_one_microsecond_ago(reference)

      results =
        race_on_independent_connections([:recovery, :cancellation], fn
          :recovery ->
            Tasks.recover_tool_call_claims(1)

          :cancellation ->
            Tasks.cancel_claimed_tool_calls_for_task(
              scope,
              reference.task_id,
              "Task cancelled"
            )
        end)

      assert Enum.all?(results, fn
               {_backend, [_recovery]} -> true
               {_backend, []} -> true
               {_backend, {:ok, _count}} -> true
             end)

      refute Tasks.restart_recovery_pending?(scope, reference.task_id)
      assert {:ok, task} = Tasks.get_task(scope, reference.task_id)

      assert [_result] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end)
  end

  test "task cancellation consumes existing recovery markers in its terminal transaction" do
    unboxed_case(fn scope ->
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)

      recovered = persist_reference(scope, task.id, turn_number, "recovered-before-cancel")

      assert {:ok, _token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 recovered,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      expire_deadline_one_microsecond_ago(recovered)
      recovered_interaction_id = recovered.interaction_id
      assert [{:resolved, ^recovered_interaction_id}] = Tasks.recover_tool_call_claims(1)
      assert Tasks.restart_recovery_pending?(scope, task.id)

      unresolved = persist_reference(scope, task.id, turn_number, "unresolved-at-cancel")

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 unresolved,
                 "departed-owner",
                 60_000,
                 :non_idempotent
               )

      assert {:ok, _token} = Tasks.mark_tool_call_dispatch_started(scope, token)

      assert {:ok, 1} =
               Tasks.cancel_claimed_tool_calls_for_task(scope, task.id, "Task cancelled")

      refute Tasks.restart_recovery_pending?(scope, task.id)

      for reference <- [recovered, unresolved] do
        claim = Repo.get!(InteractionSchema, reference.interaction_id).data.execution_claim
        assert claim.recovery_state == :resumed
      end
    end)
  end

  test "supervised recovery finalizes the marker after live executor delivery" do
    shared_case(fn scope ->
      reference = execution_reference(scope, "supervised-recovery")

      assert {:ok, _token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-owner",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      expire_deadline_one_microsecond_ago(reference)

      key = {:tool_call, reference.task_id, reference.tool_call_id}

      {:ok, _owner} =
        Registry.register(FrontmanServer.ToolCallRegistry, key, %{caller_pid: self()})

      recovery = start_supervised!({MCPRecovery, interval_ms: 10, batch_size: 1})

      assert_receive {:tool_result, "supervised-recovery", _content, true}, 1_000

      wait_until(fn ->
        case Tasks.get_task(scope, reference.task_id) do
          {:ok, task} ->
            Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
        end
      end)

      assert Process.alive?(recovery)
      refute Tasks.restart_recovery_pending?(scope, reference.task_id)
      persisted = Repo.get!(InteractionSchema, reference.interaction_id).data.execution_claim
      assert persisted.recovery_state == :resumed
      Registry.unregister(FrontmanServer.ToolCallRegistry, key)
      stop_supervised(MCPRecovery)
    end)
  end

  test "fresh BEAM application recovers an overdue durable claim at startup" do
    unboxed_case(fn scope ->
      reference = execution_reference(scope, "application-restart-recovery")

      assert {:ok, _token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-application",
                 60_000,
                 :non_idempotent,
                 60_000
               )

      expire_deadline_one_microsecond_ago(reference)

      script = """
      Application.put_env(:frontman_server, :mcp_recovery_enabled, true)
      {:ok, _applications} = Application.ensure_all_started(:frontman_server)
      interaction_id = #{inspect(reference.interaction_id)}

      recovered =
        Enum.reduce_while(1..100, false, fn _attempt, false ->
          claim =
            FrontmanServer.Repo.get!(FrontmanServer.Tasks.InteractionSchema, interaction_id).data.execution_claim

          case claim.resolution_state do
            :cancelled -> {:halt, true}
            :unresolved ->
              Process.sleep(50)
              {:cont, false}
          end
        end)

      true = recovered
      """

      command =
        Task.async(fn ->
          System.cmd(
            System.find_executable("mix"),
            ["run", "--no-start", "--no-compile", "-e", script],
            env: [{"MIX_ENV", "test"}],
            stderr_to_stdout: true
          )
        end)

      assert {:ok, {_output, 0}} =
               Task.yield(command, 20_000) || Task.shutdown(command, :brutal_kill)

      persisted = Repo.get!(InteractionSchema, reference.interaction_id).data.execution_claim
      assert persisted.resolution_state == :cancelled
      assert persisted.recovery_state == :pending_resume
      assert Tasks.restart_recovery_pending?(scope, reference.task_id)
    end)
  end

  defp execution_reference(scope, tool_call_id) do
    task_id = task_fixture(scope).id
    turn_number = start_turn_fixture(scope, task_id)
    persist_reference(scope, task_id, turn_number, tool_call_id)
  end

  defp persist_reference(scope, task_id, turn_number, tool_call_id) do
    tool_call = %SwarmAi.ToolCall{id: tool_call_id, name: "question", arguments: "{}"}

    assert {:ok, reference, %Interaction.ToolCall{}} =
             Tasks.request_client_tool_with_reference(scope, task_id, turn_number, tool_call)

    reference
  end

  defp expire_claim_one_microsecond_ago(reference) do
    %{num_rows: 1, rows: [[lease_expires_at]]} =
      Repo.query!(
        """
        UPDATE interactions
        SET data = jsonb_set(
          data,
          '{execution_claim,lease_expires_at}',
          to_jsonb(to_char(
            (clock_timestamp() - interval '1 microsecond') AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
        )
        WHERE id::text = $1
        RETURNING data #>> '{execution_claim,lease_expires_at}'
        """,
        [reference.interaction_id]
      )

    assert is_binary(lease_expires_at)

    {:ok, expected, 0} = DateTime.from_iso8601(lease_expires_at)
    persisted = Repo.get!(InteractionSchema, reference.interaction_id)
    assert persisted.data.execution_claim.lease_expires_at == expected

    %{rows: [[database_now]]} = Repo.query!("SELECT clock_timestamp()")
    assert Tasks.classify_tool_call_lease(expected, database_now) == :expired
  end

  defp expire_deadline_one_microsecond_ago(reference) do
    %{num_rows: 1} =
      Repo.query!(
        """
        UPDATE interactions
        SET data = jsonb_set(
          data,
          '{execution_claim,deadline_at}',
          to_jsonb(to_char(
            (clock_timestamp() - interval '1 microsecond') AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
        )
        WHERE id::text = $1
        """,
        [reference.interaction_id]
      )

    :ok
  end

  defp unboxed_case(test) do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        test.(scope)
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp shared_case(test) do
    owner = Sandbox.start_owner!(Repo, shared: true)
    scope = user_scope_fixture()

    try do
      test.(scope)
    after
      Repo.delete!(Scope.user(scope))
      Sandbox.stop_owner(owner)
    end
  end

  defp wait_until(assertion, attempts \\ 100)

  defp wait_until(assertion, attempts) when attempts > 0 do
    case assertion.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        wait_until(assertion, attempts - 1)
    end
  end

  defp wait_until(_assertion, 0), do: flunk("condition was not met before timeout")

  defp race_on_independent_connections(node_identities, operation) do
    parent = self()

    contenders =
      Enum.map(node_identities, fn node_identity ->
        Task.async(fn -> run_contender(parent, node_identity, operation) end)
      end)

    contender_pids = Enum.map(contenders, & &1.pid)

    for _index <- node_identities do
      assert_receive {:ready, pid}, 2_000
      assert pid in contender_pids
    end

    Enum.each(contenders, &send(&1.pid, :run))
    Enum.map(contenders, &Task.await(&1, 5_000))
  end

  defp run_contender(parent, node_identity, operation) do
    Sandbox.unboxed_run(Repo, fn ->
      %{rows: [[backend_pid]]} = Repo.query!("SELECT pg_backend_pid()")
      send(parent, {:ready, self()})

      receive do
        :run -> {backend_pid, operation.(node_identity)}
      after
        2_000 -> raise "timed out waiting to run contention operation"
      end
    end)
  end
end
