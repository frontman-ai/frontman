defmodule FrontmanServer.Credo.Checks.NoEctoQueryOutsideSchemas do
  @moduledoc false

  use Credo.Check,
    base_priority: :high,
    category: :design,
    param_defaults: [ignored_path_patterns: []],
    explanations: [
      check: """
      Ecto.Query should stay in Ecto schema modules.

      Schema modules are the persistence boundary for schema-scoped query helpers.
      Application contexts should call those helpers rather than importing Ecto.Query.
      """,
      params: [
        ignored_path_patterns: "Regex patterns for source files skipped by this check."
      ]
    ]

  @impl true
  @spec run(Credo.SourceFile.t(), Keyword.t()) :: [Credo.Issue.t()]
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    case ignored_source_file?(source_file, params) do
      true ->
        []

      false ->
        source_file
        |> SourceFile.ast()
        |> modules()
        |> Enum.flat_map(&issues_for_module(&1, issue_meta))
    end
  end

  defp ignored_source_file?(source_file, params) do
    params
    |> Params.get(:ignored_path_patterns, __MODULE__)
    |> Enum.any?(fn pattern -> Regex.match?(pattern, source_file.filename) end)
  end

  defp modules(ast) do
    ast
    |> Credo.Code.prewalk(&collect_module/2)
    |> Enum.reverse()
  end

  defp collect_module({:defmodule, _meta, _args} = ast, modules) do
    {ast, [ast | modules]}
  end

  defp collect_module(ast, modules), do: {ast, modules}

  defp issues_for_module(module_ast, issue_meta) do
    case ecto_schema_module?(module_ast) do
      true -> []
      false -> ecto_query_issues(module_ast, issue_meta)
    end
  end

  defp ecto_schema_module?(module_ast) do
    body = module_body(module_ast)

    uses_ecto_schema? =
      body
      |> prewalk_module_body(&find_ecto_schema_use/2, false)

    contains_schema? =
      body
      |> prewalk_module_body(&find_schema/2, false)

    uses_ecto_schema? and contains_schema?
  end

  defp module_body({:defmodule, _meta, [_module_name, [do: body]]}), do: body
  defp module_body(_module_ast), do: nil

  defp prewalk_module_body(ast, fun, acc) do
    Credo.Code.prewalk(ast, &skip_nested_modules(&1, &2, fun), acc)
  end

  defp skip_nested_modules({:defmodule, _meta, _args}, acc, _fun) do
    {nil, acc}
  end

  defp skip_nested_modules(ast, acc, fun), do: fun.(ast, acc)

  defp find_ecto_schema_use(ast, true), do: {ast, true}

  defp find_ecto_schema_use(
         {:use, _meta, [{:__aliases__, _alias_meta, [:Ecto, :Schema]} | _]} = ast,
         false
       ) do
    {ast, true}
  end

  defp find_ecto_schema_use(ast, found), do: {ast, found}

  defp find_schema(ast, true), do: {ast, true}

  defp find_schema({:schema, _meta, [_source, [do: _body]]} = ast, false) do
    {ast, true}
  end

  defp find_schema(ast, found), do: {ast, found}

  defp ecto_query_issues(module_ast, issue_meta) do
    module_ast
    |> module_body()
    |> prewalk_module_body(&find_ecto_query/2, [])
    |> Enum.reverse()
    |> Enum.map(&issue_for(&1, issue_meta))
  end

  defp find_ecto_query(
         {operation, _meta,
          [
            {{:., _dot_meta, [{:__aliases__, ecto_meta, [:Ecto]}, :{}]}, _aliases_meta, aliases}
            | _
          ]} = ast,
         issues
       )
       when operation in [:alias, :import, :require] do
    case Enum.any?(aliases, &query_alias?/1) do
      true -> {ast, [{ecto_meta, "Ecto"} | issues]}
      false -> {ast, issues}
    end
  end

  defp find_ecto_query({:__aliases__, meta, [:Ecto, :Query | _]} = ast, issues) do
    {ast, [{meta, "Ecto.Query"} | issues]}
  end

  defp find_ecto_query(ast, issues), do: {ast, issues}

  defp query_alias?({:__aliases__, _meta, [:Query]}), do: true
  defp query_alias?(_ast), do: false

  defp issue_for({meta, trigger}, issue_meta) do
    format_issue(
      issue_meta,
      message: "Ecto.Query is only allowed in Ecto schema modules.",
      trigger: trigger,
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
