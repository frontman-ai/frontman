defmodule FrontmanServer.Credo.Checks.NoEctoQueryOutsideSchemasTest do
  use Credo.Test.Case

  Code.require_file(
    Path.expand("../../../../credo_checks/no_ecto_query_outside_schemas.ex", __DIR__)
  )

  alias FrontmanServer.Credo.Checks.NoEctoQueryOutsideSchemas

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "allows Ecto.Query in modules that define Ecto schemas" do
    """
    defmodule Example.Schema do
      use Ecto.Schema
      import Ecto.Query

      schema "records" do
        field(:name, :string)
      end
    end
    """
    |> to_source_file("lib/example/schema.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> refute_issues()
  end

  test "reports Ecto.Query imports in modules without Ecto schemas" do
    """
    defmodule Example.Context do
      import Ecto.Query

      def list_records do
        from(r in Example.Record)
      end
    end
    """
    |> to_source_file("lib/example/context.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> assert_issue(fn issue ->
      assert issue.trigger == "Ecto.Query"
      assert issue.line_no == 2
    end)
  end

  test "reports aliases of Ecto.Query in modules without Ecto schemas" do
    """
    defmodule Example.Context do
      alias Ecto.Query
    end
    """
    |> to_source_file("lib/example/context.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> assert_issue(fn issue ->
      assert issue.trigger == "Ecto.Query"
      assert issue.line_no == 2
    end)
  end

  test "reports multi-alias usage of Ecto.Query in modules without Ecto schemas" do
    """
    defmodule Example.Context do
      import Ecto.{Changeset, Query}
    end
    """
    |> to_source_file("lib/example/context.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> assert_issue(fn issue ->
      assert issue.trigger == "Ecto"
      assert issue.line_no == 2
    end)
  end

  test "ignores test files" do
    """
    defmodule Example.ContextTest do
      import Ecto.Query
    end
    """
    |> to_source_file("test/example/context_test.exs")
    |> run_check(NoEctoQueryOutsideSchemas, ignored_path_patterns: [~r/^test\//])
    |> refute_issues()
  end

  test "ignores Mix tasks" do
    """
    defmodule Mix.Tasks.DebugTask do
      import Ecto.Query
    end
    """
    |> to_source_file("lib/mix/tasks/debug_task.ex")
    |> run_check(NoEctoQueryOutsideSchemas, ignored_path_patterns: [~r/^lib\/mix\//])
    |> refute_issues()
  end

  test "reports Ecto.Query in non-schema modules even when another module in the file is a schema" do
    """
    defmodule Example.Schema do
      use Ecto.Schema

      schema "records" do
        field(:name, :string)
      end
    end

    defmodule Example.Context do
      import Ecto.Query
    end
    """
    |> to_source_file("lib/example/mixed.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> assert_issue(fn issue ->
      assert issue.trigger == "Ecto.Query"
      assert issue.line_no == 10
    end)
  end

  test "does not report non-Ecto from calls" do
    """
    defmodule Example.Notifier do
      def deliver(email) do
        email
        |> from("support@example.com")
      end
    end
    """
    |> to_source_file("lib/example/notifier.ex")
    |> run_check(NoEctoQueryOutsideSchemas)
    |> refute_issues()
  end
end
