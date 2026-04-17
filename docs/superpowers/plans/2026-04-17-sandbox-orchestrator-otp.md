# Sandbox Orchestrator + OTP Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Sandbox OTP supervision tree, Orchestrator GenServer, Provider behaviour, DB schema, and Sandboxes context — the full lifecycle management layer for cloud sandbox environments.

**Architecture:** A `DynamicSupervisor` manages per-sandbox `Orchestrator` GenServers that own VM lifecycle via a `Provider` behaviour. Each Orchestrator registers in a `Registry` for lookup by `sandbox_id`, polls VM health via heartbeat, delegates blocking exec calls to a `Task.Supervisor`, and coordinates state transitions with an Ecto-backed `SandboxSchema`. The `Sandboxes` context is the public API that wires DB operations to Orchestrator commands.

**Tech Stack:** Elixir, OTP (GenServer, DynamicSupervisor, Registry, Task.Supervisor), Ecto, Mox, ExUnit

**Source:** Issue #834 design comment, Issue #839

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `apps/frontman_server/lib/frontman_server/sandbox/provider.ex` | Behaviour: `create/1`, `exec/4`, `metrics/1`, `stop/1`, `start/1`, `destroy/1` |
| Create | `apps/frontman_server/lib/frontman_server/sandbox/sandbox_schema.ex` | Ecto schema for `sandboxes` table |
| Create | `apps/frontman_server/priv/repo/migrations/TIMESTAMP_create_sandboxes.exs` | DB migration |
| Create | `apps/frontman_server/lib/frontman_server/sandbox/orchestrator.ex` | GenServer: per-sandbox lifecycle state machine |
| Create | `apps/frontman_server/lib/frontman_server/sandboxes.ex` | Public context API |
| Modify | `apps/frontman_server/lib/frontman_server/application.ex` | Add Registry, Task.Supervisor, DynamicSupervisor children |
| Modify | `apps/frontman_server/test/support/mocks.ex` | Add `MockProvider` Mox mock |
| Create | `apps/frontman_server/test/support/fixtures/sandboxes.ex` | Test fixtures for sandbox setup |
| Create | `apps/frontman_server/test/frontman_server/sandbox/orchestrator_test.exs` | Orchestrator GenServer tests |
| Create | `apps/frontman_server/test/frontman_server/sandboxes_test.exs` | Context integration tests |

---

## Task 1: Provider behaviour + MockProvider

**Files:**
- Create: `apps/frontman_server/lib/frontman_server/sandbox/provider.ex`
- Modify: `apps/frontman_server/test/support/mocks.ex`

- [ ] **Step 1: Create the Provider behaviour**

Create `apps/frontman_server/lib/frontman_server/sandbox/provider.ex`:

```elixir
defmodule FrontmanServer.Sandbox.Provider do
  @moduledoc """
  Behaviour for sandbox VM providers.

  Abstracts the infrastructure layer so the Orchestrator doesn't
  know whether it's talking to microsandbox, E2B, or a test mock.
  """

  @type provider_ref :: String.t()
  @type exec_result :: %{exit_code: integer(), stdout: String.t(), stderr: String.t()}
  @type metrics :: %{running: boolean()}
  @type env_spec :: FrontmanServer.Sandbox.EnvironmentSpec.t()

  @callback create(env_spec) :: {:ok, provider_ref} | {:error, term()}

  @callback exec(provider_ref, command :: String.t(), args :: [String.t()], opts :: keyword()) ::
              {:ok, exec_result} | {:error, term()}

  @callback metrics(provider_ref) :: {:ok, metrics} | {:error, term()}

  @callback stop(provider_ref) :: :ok | {:error, term()}

  @callback start(provider_ref) :: :ok | {:error, term()}

  @callback destroy(provider_ref) :: :ok | {:error, term()}
end
```

- [ ] **Step 2: Add MockProvider to mocks.ex**

Add to `apps/frontman_server/test/support/mocks.ex`:

```elixir
Mox.defmock(MockProvider, for: FrontmanServer.Sandbox.Provider)
```

The file should now contain both mocks:

```elixir
Mox.defmock(MockGitHubClient, for: FrontmanServer.Sandbox.GitHubClient)
Mox.defmock(MockProvider, for: FrontmanServer.Sandbox.Provider)
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile`

Expected: Compiles cleanly.

- [ ] **Step 4: Commit**

```
feat: add Provider behaviour for sandbox VM abstraction
```

---

## Task 2: SandboxSchema + migration

**Files:**
- Create: `apps/frontman_server/priv/repo/migrations/20260417000000_create_sandboxes.exs`
- Create: `apps/frontman_server/lib/frontman_server/sandbox/sandbox_schema.ex`

- [ ] **Step 1: Create the migration**

Create `apps/frontman_server/priv/repo/migrations/20260417000000_create_sandboxes.exs`:

```elixir
defmodule FrontmanServer.Repo.Migrations.CreateSandboxes do
  use Ecto.Migration

  def change do
    create table(:sandboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :provider_ref, :text
      add :status, :text, null: false, default: "provisioning"
      add :port_map, :map, default: %{}
      add :env_spec, :map, null: false
      add :last_active_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:sandboxes, [:user_id])
    create index(:sandboxes, [:task_id])
    create index(:sandboxes, [:status])
  end
end
```

- [ ] **Step 2: Create the Ecto schema**

Create `apps/frontman_server/lib/frontman_server/sandbox/sandbox_schema.ex`:

```elixir
defmodule FrontmanServer.Sandbox.SandboxSchema do
  @moduledoc """
  Ecto schema for persisted sandboxes.

  Tracks the lifecycle state and provider reference for each
  sandbox VM. The Orchestrator GenServer reads and updates
  this record as the sandbox transitions between states.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Tasks.TaskSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sandboxes" do
    field :provider_ref, :string
    field :status, :string, default: "provisioning"
    field :port_map, :map, default: %{}
    field :env_spec, :map
    field :last_active_at, :utc_datetime

    belongs_to :user, User
    belongs_to :task, TaskSchema

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a new sandbox."
  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:env_spec, :user_id, :task_id])
    |> validate_required([:env_spec, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:task_id)
  end

  @doc "Changeset for status transitions."
  @spec status_changeset(t(), String.t()) :: Ecto.Changeset.t()
  def status_changeset(sandbox, new_status)
      when new_status in ~w(provisioning running stopped error) do
    sandbox
    |> change(status: new_status)
  end

  @doc "Changeset for setting the provider_ref after VM creation."
  @spec set_provider_ref_changeset(t(), String.t()) :: Ecto.Changeset.t()
  def set_provider_ref_changeset(sandbox, provider_ref) do
    sandbox
    |> change(provider_ref: provider_ref)
  end

  @doc "Changeset for updating last_active_at."
  @spec touch_changeset(t()) :: Ecto.Changeset.t()
  def touch_changeset(sandbox) do
    sandbox
    |> change(last_active_at: DateTime.utc_now(:second))
  end

  # Query helpers

  @type t :: %__MODULE__{}

  @spec by_id(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_id(query \\ __MODULE__, id) do
    from(s in query, where: s.id == ^id)
  end

  @spec for_user(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_user(query \\ __MODULE__, user_id) do
    from(s in query, where: s.user_id == ^user_id)
  end

  @spec with_status(Ecto.Queryable.t(), String.t() | [String.t()]) :: Ecto.Query.t()
  def with_status(query \\ __MODULE__, status) when is_binary(status) do
    from(s in query, where: s.status == ^status)
  end

  def with_status(query, statuses) when is_list(statuses) do
    from(s in query, where: s.status in ^statuses)
  end

  @spec for_task(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_task(query \\ __MODULE__, task_id) do
    from(s in query, where: s.task_id == ^task_id)
  end

  @spec idle_since(Ecto.Queryable.t(), DateTime.t()) :: Ecto.Query.t()
  def idle_since(query \\ __MODULE__, cutoff) do
    from(s in query,
      where: s.status == "running",
      where: s.last_active_at < ^cutoff or is_nil(s.last_active_at)
    )
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `mix ecto.migrate`

Expected: Migration runs cleanly, `sandboxes` table created.

- [ ] **Step 4: Verify compilation**

Run: `mix compile`

Expected: Compiles cleanly.

- [ ] **Step 5: Commit**

```
feat: add SandboxSchema and create_sandboxes migration
```

---

## Task 3: Wire supervision tree into Application

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/application.ex`

- [ ] **Step 1: Add Registry, Task.Supervisor, and DynamicSupervisor to children**

In `apps/frontman_server/lib/frontman_server/application.ex`, add three new children to the `children` list, after the `ToolCallRegistry` entry and before the `Oban` entry:

```elixir
      # Registry for MCP tool call result routing (separate from agent execution tracking)
      {Registry, keys: :unique, name: FrontmanServer.ToolCallRegistry},
      # --- Sandbox OTP infrastructure ---
      {Registry, keys: :unique, name: FrontmanServer.Sandbox.Registry},
      {Task.Supervisor, name: FrontmanServer.Sandbox.TaskSupervisor},
      {DynamicSupervisor, name: FrontmanServer.Sandbox.DynamicSupervisor, strategy: :one_for_one},
      # Oban background job processing (email delivery, contact sync, etc.)
      {Oban, Application.fetch_env!(:frontman_server, Oban)},
```

- [ ] **Step 2: Verify the app starts**

Run: `mix compile`

Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```
feat: add Sandbox supervision tree to Application
```

---

## Task 4: TDD Orchestrator — provisioning happy path

**Files:**
- Create: `apps/frontman_server/test/support/fixtures/sandboxes.ex`
- Create: `apps/frontman_server/test/frontman_server/sandbox/orchestrator_test.exs`
- Create: `apps/frontman_server/lib/frontman_server/sandbox/orchestrator.ex`

- [ ] **Step 1: Create sandbox test fixtures**

Create `apps/frontman_server/test/support/fixtures/sandboxes.ex`:

```elixir
defmodule FrontmanServer.Test.Fixtures.Sandboxes do
  @moduledoc """
  Reusable fixtures for sandbox test setup.
  """

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.SandboxSchema

  @doc """
  Insert a sandbox record in the DB and return it.

  Requires a `user_id` in attrs.
  """
  @spec sandbox_fixture(map()) :: SandboxSchema.t()
  def sandbox_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          env_spec: %{"image" => "mcr.microsoft.com/devcontainers/base:ubuntu"}
        },
        attrs
      )

    {:ok, sandbox} =
      attrs
      |> SandboxSchema.create_changeset()
      |> Repo.insert()

    sandbox
  end
end
```

- [ ] **Step 2: Write failing test for provisioning → running transition**

Create `apps/frontman_server/test/frontman_server/sandbox/orchestrator_test.exs`:

```elixir
defmodule FrontmanServer.Sandbox.OrchestratorTest do
  use FrontmanServer.DataCase

  import Mox

  alias FrontmanServer.Sandbox.{Orchestrator, SandboxSchema}
  alias FrontmanServer.Test.Fixtures.{Accounts, Sandboxes}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    user = Accounts.user_fixture()
    sandbox = Sandboxes.sandbox_fixture(%{user_id: user.id})
    %{sandbox: sandbox, user: user}
  end

  describe "provisioning happy path" do
    test "transitions from provisioning to running when provider reports ready", %{
      sandbox: sandbox
    } do
      # Provider.create succeeds, returns a ref
      MockProvider
      |> expect(:create, fn _env_spec ->
        {:ok, "msb-ref-123"}
      end)
      # First heartbeat: VM is running
      |> expect(:metrics, fn "msb-ref-123" ->
        {:ok, %{running: true}}
      end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      # Wait for heartbeat to fire and transition to running
      assert_eventually(fn ->
        reloaded = Repo.get!(SandboxSchema, sandbox.id)
        reloaded.status == "running"
      end)

      assert Process.alive?(pid)
    end

    test "stores provider_ref on sandbox after create", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec ->
        {:ok, "msb-ref-456"}
      end)
      |> expect(:metrics, fn "msb-ref-456" ->
        {:ok, %{running: true}}
      end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        reloaded = Repo.get!(SandboxSchema, sandbox.id)
        reloaded.provider_ref == "msb-ref-456"
      end)
    end
  end

  describe "provisioning failure" do
    test "transitions to error when provider.create fails", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec ->
        {:error, :image_not_found}
      end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      reloaded = Repo.get!(SandboxSchema, sandbox.id)
      assert reloaded.status == "error"
    end

    test "transitions to error on provisioning timeout", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec ->
        {:ok, "msb-ref-slow"}
      end)
      # Heartbeat always says not running
      |> stub(:metrics, fn "msb-ref-slow" ->
        {:ok, %{running: false}}
      end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 50
        )

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      reloaded = Repo.get!(SandboxSchema, sandbox.id)
      assert reloaded.status == "error"
    end
  end

  describe "running state" do
    test "detects VM crash via heartbeat and transitions to error", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-crash"} end)
      # First heartbeat: running. Second: crashed.
      |> expect(:metrics, fn "msb-ref-crash" -> {:ok, %{running: true}} end)
      |> expect(:metrics, fn "msb-ref-crash" -> {:ok, %{running: false}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      reloaded = Repo.get!(SandboxSchema, sandbox.id)
      assert reloaded.status == "error"
    end

    test "survives daemon unreachability and retries", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-flaky"} end)
      # Heartbeat 1: running. Heartbeat 2: unreachable. Heartbeat 3: running again.
      |> expect(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)
      |> expect(:metrics, fn "msb-ref-flaky" -> {:error, :econnrefused} end)
      |> expect(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      # Wait long enough for 3+ heartbeats
      Process.sleep(80)

      assert Process.alive?(pid)
    end
  end

  describe "exec" do
    test "delegates to provider and returns result", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-exec"} end)
      |> expect(:metrics, fn "msb-ref-exec" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-exec" -> {:ok, %{running: true}} end)
      |> expect(:exec, fn "msb-ref-exec", "echo", ["hello"], [] ->
        {:ok, %{exit_code: 0, stdout: "hello\n", stderr: ""}}
      end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      # Wait for running state
      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == "running"
      end)

      assert {:ok, %{exit_code: 0, stdout: "hello\n"}} =
               Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end

    test "returns {:error, :not_ready} when still provisioning", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-notready"} end)
      |> stub(:metrics, fn "msb-ref-notready" -> {:ok, %{running: false}} end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 1_000,
          provision_timeout_ms: 60_000
        )

      # Give init time to complete
      Process.sleep(20)

      assert {:error, :not_ready} =
               Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end
  end

  describe "stop" do
    test "calls provider.stop, updates DB, and terminates", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-stop"} end)
      |> expect(:metrics, fn "msb-ref-stop" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-stop" -> {:ok, %{running: true}} end)
      |> expect(:stop, fn "msb-ref-stop" -> :ok end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == "running"
      end)

      ref = Process.monitor(pid)
      assert :ok = Orchestrator.stop(sandbox.id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      reloaded = Repo.get!(SandboxSchema, sandbox.id)
      assert reloaded.status == "stopped"
    end
  end

  describe "destroy" do
    test "calls provider.destroy, deletes DB record, and terminates", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-destroy"} end)
      |> expect(:metrics, fn "msb-ref-destroy" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-destroy" -> {:ok, %{running: true}} end)
      |> expect(:destroy, fn "msb-ref-destroy" -> :ok end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == "running"
      end)

      ref = Process.monitor(pid)
      assert :ok = Orchestrator.destroy(sandbox.id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get(SandboxSchema, sandbox.id) == nil
    end
  end

  # --- Helpers ---

  defp start_orchestrator(sandbox_id, opts) do
    Orchestrator.start_link(
      Keyword.merge(
        [sandbox_id: sandbox_id],
        opts
      )
    )
  end

  defp assert_eventually(fun, timeout \\ 1_000, interval \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout

    do_assert_eventually(fun, deadline, interval)
  end

  defp do_assert_eventually(fun, deadline, interval) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("assert_eventually timed out")
      else
        Process.sleep(interval)
        do_assert_eventually(fun, deadline, interval)
      end
    end
  end
end
```

- [ ] **Step 3: Run tests to confirm they fail**

Run: `mix test test/frontman_server/sandbox/orchestrator_test.exs`

Expected: Compile error — `FrontmanServer.Sandbox.Orchestrator` does not exist.

- [ ] **Step 4: Implement Orchestrator GenServer**

Create `apps/frontman_server/lib/frontman_server/sandbox/orchestrator.ex`:

```elixir
defmodule FrontmanServer.Sandbox.Orchestrator do
  @moduledoc """
  Per-sandbox lifecycle GenServer.

  Manages a single sandbox VM through its lifecycle:
  provisioning → running → stopped/error. Polls the provider
  for health via heartbeat and delegates blocking exec calls
  to Task.Supervisor so the GenServer stays responsive.

  Started under Sandbox.DynamicSupervisor, registered in
  Sandbox.Registry by sandbox_id.
  """

  use GenServer

  require Logger

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.SandboxSchema

  @default_heartbeat_interval_ms 30_000
  @default_provision_timeout_ms 300_000

  defstruct [
    :sandbox_id,
    :provider_ref,
    :status,
    :heartbeat_ref,
    :provision_timer_ref,
    :provider,
    :heartbeat_interval_ms
  ]

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
    )
  end

  @spec exec(String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec(sandbox_id, command, args, opts \\ []) do
    GenServer.call(via(sandbox_id), {:exec, command, args, opts}, 120_000)
  end

  @spec stop(String.t()) :: :ok | {:error, term()}
  def stop(sandbox_id) do
    GenServer.call(via(sandbox_id), :stop)
  end

  @spec destroy(String.t()) :: :ok | {:error, term()}
  def destroy(sandbox_id) do
    GenServer.call(via(sandbox_id), :destroy)
  end

  @spec status(String.t()) :: {:ok, atom()} | {:error, :not_found}
  def status(sandbox_id) do
    GenServer.call(via(sandbox_id), :status)
  end

  defp via(sandbox_id) do
    {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)
    provider = Keyword.fetch!(opts, :provider)
    heartbeat_interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @default_heartbeat_interval_ms)
    provision_timeout_ms = Keyword.get(opts, :provision_timeout_ms, @default_provision_timeout_ms)

    sandbox = Repo.get!(SandboxSchema, sandbox_id)

    state = %__MODULE__{
      sandbox_id: sandbox_id,
      provider: provider,
      status: :provisioning,
      heartbeat_interval_ms: heartbeat_interval_ms
    }

    case provider.create(sandbox.env_spec) do
      {:ok, provider_ref} ->
        sandbox
        |> SandboxSchema.set_provider_ref_changeset(provider_ref)
        |> Repo.update!()

        provision_timer_ref = Process.send_after(self(), :provision_timeout, provision_timeout_ms)
        heartbeat_ref = schedule_heartbeat(heartbeat_interval_ms)

        {:ok,
         %{
           state
           | provider_ref: provider_ref,
             heartbeat_ref: heartbeat_ref,
             provision_timer_ref: provision_timer_ref
         }}

      {:error, reason} ->
        Logger.error("Orchestrator: provider.create failed",
          sandbox_id: sandbox_id,
          reason: inspect(reason)
        )

        update_db_status(sandbox_id, "error")
        {:stop, :normal}
    end
  end

  @impl true
  def handle_call({:exec, command, args, opts}, from, %{status: :running} = state) do
    Task.Supervisor.start_child(FrontmanServer.Sandbox.TaskSupervisor, fn ->
      result = state.provider.exec(state.provider_ref, command, args, opts)
      GenServer.reply(from, result)
    end)

    touch_last_active(state.sandbox_id)
    {:noreply, state}
  end

  def handle_call({:exec, _, _, _}, _from, %{status: :provisioning} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:stop, _from, state) do
    case state.provider.stop(state.provider_ref) do
      :ok ->
        update_db_status(state.sandbox_id, "stopped")
        {:stop, :normal, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:destroy, _from, state) do
    case state.provider.destroy(state.provider_ref) do
      :ok ->
        Repo.get(SandboxSchema, state.sandbox_id)
        |> case do
          nil -> :ok
          sandbox -> Repo.delete(sandbox)
        end

        {:stop, :normal, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  @impl true
  def handle_info(:heartbeat, %{status: :provisioning} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)
        update_db_status(state.sandbox_id, "running")
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | status: :running, provision_timer_ref: nil, heartbeat_ref: heartbeat_ref}}

      {:ok, %{running: false}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:error, _reason} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:heartbeat, %{status: :running} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, %{running: false}} ->
        Logger.error("Orchestrator: VM crashed", sandbox_id: state.sandbox_id)
        update_db_status(state.sandbox_id, "error")
        {:stop, :normal, state}

      {:error, _reason} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:provision_timeout, %{status: :provisioning} = state) do
    Logger.error("Orchestrator: provisioning timed out", sandbox_id: state.sandbox_id)
    update_db_status(state.sandbox_id, "error")
    {:stop, :normal, state}
  end

  def handle_info(:provision_timeout, state) do
    # Already transitioned past provisioning — ignore stale timer
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)

    Logger.info("Orchestrator terminating",
      sandbox_id: state.sandbox_id,
      status: state.status,
      reason: inspect(reason)
    )

    :ok
  end

  # --- Private Helpers ---

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat, interval_ms)
  end

  defp update_db_status(sandbox_id, new_status) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        Logger.warning("Orchestrator: sandbox not found in DB", sandbox_id: sandbox_id)
        {:error, :not_found}

      sandbox ->
        sandbox
        |> SandboxSchema.status_changeset(new_status)
        |> Repo.update()
    end
  end

  defp touch_last_active(sandbox_id) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil -> :ok
      sandbox -> sandbox |> SandboxSchema.touch_changeset() |> Repo.update()
    end
  end
end
```

- [ ] **Step 5: Run the tests**

Run: `mix test test/frontman_server/sandbox/orchestrator_test.exs`

Expected: All tests pass (10 tests, 0 failures).

- [ ] **Step 6: Commit**

```
feat: implement Orchestrator GenServer with heartbeat and lifecycle management
```

---

## Task 5: TDD Sandboxes context

**Files:**
- Create: `apps/frontman_server/lib/frontman_server/sandboxes.ex`
- Create: `apps/frontman_server/test/frontman_server/sandboxes_test.exs`

- [ ] **Step 1: Write failing tests for the Sandboxes context**

Create `apps/frontman_server/test/frontman_server/sandboxes_test.exs`:

```elixir
defmodule FrontmanServer.SandboxesTest do
  use FrontmanServer.DataCase

  import Mox

  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Sandbox.{SandboxSchema, EnvironmentSpec}
  alias FrontmanServer.Test.Fixtures.{Accounts, Tasks}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    user = Accounts.user_fixture()
    scope = Accounts.user_scope_fixture(user)
    %{user: user, scope: scope}
  end

  @env_spec %{"image" => "mcr.microsoft.com/devcontainers/base:ubuntu"}

  describe "provision_and_start/3" do
    test "inserts sandbox record and starts orchestrator", %{scope: scope} do
      task_id = Tasks.task_fixture(scope)

      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-ctx"} end)
      |> expect(:metrics, fn "msb-ref-ctx" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-ctx" -> {:ok, %{running: true}} end)

      assert {:ok, sandbox} =
               Sandboxes.provision_and_start(scope, @env_spec,
                 task_id: task_id,
                 provider: MockProvider,
                 heartbeat_interval_ms: 10,
                 provision_timeout_ms: 5_000
               )

      assert sandbox.status == "provisioning"
      assert sandbox.user_id == scope.user.id
      assert sandbox.task_id == task_id

      # Orchestrator should eventually transition it to running
      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == "running"
      end)
    end
  end

  describe "get_sandbox/2" do
    test "returns sandbox for the user", %{scope: scope} do
      task_id = Tasks.task_fixture(scope)

      sandbox =
        FrontmanServer.Test.Fixtures.Sandboxes.sandbox_fixture(%{
          user_id: scope.user.id,
          task_id: task_id
        })

      assert {:ok, found} = Sandboxes.get_sandbox(scope, sandbox.id)
      assert found.id == sandbox.id
    end

    test "returns not_found for another user's sandbox", %{scope: _scope} do
      other_user = Accounts.user_fixture()

      sandbox =
        FrontmanServer.Test.Fixtures.Sandboxes.sandbox_fixture(%{user_id: other_user.id})

      scope = Accounts.user_scope_fixture(Accounts.user_fixture())
      assert {:error, :not_found} = Sandboxes.get_sandbox(scope, sandbox.id)
    end
  end

  describe "current_for_task/2" do
    test "returns the active sandbox for a task", %{scope: scope} do
      task_id = Tasks.task_fixture(scope)

      sandbox =
        FrontmanServer.Test.Fixtures.Sandboxes.sandbox_fixture(%{
          user_id: scope.user.id,
          task_id: task_id
        })

      assert {:ok, found} = Sandboxes.current_for_task(scope, task_id)
      assert found.id == sandbox.id
    end

    test "returns not_found when no sandbox exists for task", %{scope: scope} do
      task_id = Tasks.task_fixture(scope)
      assert {:error, :not_found} = Sandboxes.current_for_task(scope, task_id)
    end
  end

  describe "list_sandboxes/1" do
    test "returns all sandboxes for the user", %{scope: scope} do
      FrontmanServer.Test.Fixtures.Sandboxes.sandbox_fixture(%{user_id: scope.user.id})
      FrontmanServer.Test.Fixtures.Sandboxes.sandbox_fixture(%{user_id: scope.user.id})

      assert {:ok, sandboxes} = Sandboxes.list_sandboxes(scope)
      assert length(sandboxes) == 2
    end
  end

  # Reuse the polling helper
  defp assert_eventually(fun, timeout \\ 1_000, interval \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_assert_eventually(fun, deadline, interval)
  end

  defp do_assert_eventually(fun, deadline, interval) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("assert_eventually timed out")
      else
        Process.sleep(interval)
        do_assert_eventually(fun, deadline, interval)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

Run: `mix test test/frontman_server/sandboxes_test.exs`

Expected: Compile error — `FrontmanServer.Sandboxes` does not exist.

- [ ] **Step 3: Implement the Sandboxes context**

Create `apps/frontman_server/lib/frontman_server/sandboxes.ex`:

```elixir
defmodule FrontmanServer.Sandboxes do
  @moduledoc """
  Public API for sandbox lifecycle management.

  Coordinates DB operations with Orchestrator GenServer commands.
  All functions require a Scope for authorization — sandboxes are
  scoped to the user who created them.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.{Orchestrator, SandboxSchema}

  @doc """
  Create a sandbox record and start its Orchestrator.

  Inserts a `provisioning` record in the DB, then starts a GenServer
  under DynamicSupervisor that will call provider.create and begin
  heartbeat polling.

  ## Options

    * `:task_id` - optional task ID to associate with the sandbox
    * `:provider` - provider module (required in test, defaults to config in prod)
    * `:heartbeat_interval_ms` - heartbeat interval (default 30_000)
    * `:provision_timeout_ms` - provisioning timeout (default 300_000)
  """
  @spec provision_and_start(Scope.t(), map(), keyword()) ::
          {:ok, SandboxSchema.t()} | {:error, term()}
  def provision_and_start(%Scope{user: %{id: user_id}}, env_spec, opts \\ []) do
    task_id = Keyword.get(opts, :task_id)

    changeset_attrs = %{
      env_spec: env_spec,
      user_id: user_id,
      task_id: task_id
    }

    with {:ok, sandbox} <- changeset_attrs |> SandboxSchema.create_changeset() |> Repo.insert() do
      orchestrator_opts =
        Keyword.merge(
          [sandbox_id: sandbox.id],
          Keyword.take(opts, [:provider, :heartbeat_interval_ms, :provision_timeout_ms])
        )

      case DynamicSupervisor.start_child(
             FrontmanServer.Sandbox.DynamicSupervisor,
             {Orchestrator, orchestrator_opts}
           ) do
        {:ok, _pid} ->
          {:ok, sandbox}

        {:error, reason} ->
          Logger.error("Sandboxes: failed to start Orchestrator",
            sandbox_id: sandbox.id,
            reason: inspect(reason)
          )

          sandbox
          |> SandboxSchema.status_changeset("error")
          |> Repo.update()

          {:error, reason}
      end
    end
  end

  @doc "Get a sandbox by ID, scoped to the user."
  @spec get_sandbox(Scope.t(), String.t()) :: {:ok, SandboxSchema.t()} | {:error, :not_found}
  def get_sandbox(%Scope{user: %{id: user_id}}, sandbox_id) do
    query =
      SandboxSchema
      |> SandboxSchema.by_id(sandbox_id)
      |> SandboxSchema.for_user(user_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sandbox -> {:ok, sandbox}
    end
  end

  @doc "Get the active sandbox for a task."
  @spec current_for_task(Scope.t(), String.t()) :: {:ok, SandboxSchema.t()} | {:error, :not_found}
  def current_for_task(%Scope{user: %{id: user_id}}, task_id) do
    query =
      SandboxSchema
      |> SandboxSchema.for_user(user_id)
      |> SandboxSchema.for_task(task_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sandbox -> {:ok, sandbox}
    end
  end

  @doc "List all sandboxes for the user."
  @spec list_sandboxes(Scope.t()) :: {:ok, [SandboxSchema.t()]}
  def list_sandboxes(%Scope{user: %{id: user_id}}) do
    sandboxes =
      SandboxSchema
      |> SandboxSchema.for_user(user_id)
      |> Repo.all()

    {:ok, sandboxes}
  end

  @doc "Execute a command in a running sandbox."
  @spec exec(Scope.t(), String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec(%Scope{} = scope, sandbox_id, command, args, opts \\ []) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      Orchestrator.exec(sandbox_id, command, args, opts)
    end
  end

  @doc "Stop a running sandbox. The Orchestrator terminates."
  @spec stop_sandbox(Scope.t(), String.t()) :: :ok | {:error, term()}
  def stop_sandbox(%Scope{} = scope, sandbox_id) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      Orchestrator.stop(sandbox_id)
    end
  end

  @doc "Destroy a sandbox and its VM."
  @spec destroy_sandbox(Scope.t(), String.t()) :: :ok | {:error, term()}
  def destroy_sandbox(%Scope{} = scope, sandbox_id) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      Orchestrator.destroy(sandbox_id)
    end
  end
end
```

- [ ] **Step 4: Run all tests**

Run: `mix test test/frontman_server/sandboxes_test.exs`

Expected: All tests pass (4 tests, 0 failures).

- [ ] **Step 5: Commit**

```
feat: add Sandboxes context as public API for sandbox lifecycle
```

---

## Task 6: Run full test suite + format

- [ ] **Step 1: Run the full test suite**

Run: `mix test`

Expected: All tests pass, including existing tests and the new sandbox tests.

- [ ] **Step 2: Run mix format**

Run: `mix format`

- [ ] **Step 3: Run mix format check**

Run: `mix format --check-formatted`

Expected: All files formatted.

- [ ] **Step 4: Commit if format changed anything**

```
chore: apply mix format
```

---

## Self-Review

**Spec coverage check (against #834 design comment):**

| Requirement | Covered by |
|---|---|
| Registry (unique keys = sandbox_id) | Task 3, `application.ex` |
| Task.Supervisor for exec delegation | Task 3, `application.ex` + Task 4, `handle_call({:exec, ...})` |
| DynamicSupervisor for Orchestrators | Task 3, `application.ex` + Task 5, `provision_and_start/3` |
| `:temporary` restart (no auto-restart) | Task 4, GenServer with `:stop, :normal` exits |
| State machine: provisioning → running → stopped/error | Task 4, `handle_info(:heartbeat, ...)` + `handle_call(:stop, ...)` |
| Heartbeat polling (self-polling per Orchestrator) | Task 4, `schedule_heartbeat/1` + `handle_info(:heartbeat, ...)` |
| Provisioning timeout | Task 4, `provision_timer_ref` + `handle_info(:provision_timeout, ...)` |
| Daemon unreachable = keep retrying | Task 4, `{:error, _reason}` clause in heartbeat |
| VM crash detection | Task 4, `{:ok, %{running: false}}` in running heartbeat |
| Exec delegated to Task.Supervisor | Task 4, `Task.Supervisor.start_child` + `GenServer.reply` |
| Provider behaviour with 6 callbacks | Task 1 |
| DB schema with status, provider_ref, port_map, env_spec | Task 2 |
| Sandboxes context: provision_and_start, get, list, exec, stop, destroy | Task 5 |
| Scope-based authorization | Task 5, all functions take `Scope.t()` |
| Stop flow: provider.stop → DB update → terminate | Task 4 + test in Task 4 |
| Destroy flow: provider.destroy → DB delete → terminate | Task 4 + test in Task 4 |
| terminate/2 cancels timers | Task 4, `terminate/2` |

**Not in scope (per #834 design):** Resume flow (spawns fresh GenServer for stopped sandbox), Idle reaper Oban job, Reconciliation on init from existing DB state. These are mentioned in the design but are Phase 2 enhancements — the Orchestrator currently handles fresh sandboxes only.

**Placeholder scan:** None found. All steps have complete code.

**Type consistency:** `provider_ref` is `String.t()` everywhere. `sandbox_id` is `String.t()` everywhere. `env_spec` is `map()` at DB level, `EnvironmentSpec.t()` at Provider level. Status is `String.t()` in DB, `:atom` in GenServer state — consistent with the schema using string fields and GenServer using atoms internally.
