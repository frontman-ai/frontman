defmodule FrontmanServer.CurrentPageContextTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction.CurrentPage

  test "routing status survives ACP parsing, embedded storage, history, and prompt formatting" do
    for status <- ["enabled", "disabled", "unavailable"] do
      meta = %{
        "current_page" => true,
        "url" => "http://localhost:4321/",
        "astro_client_routing" => status
      }

      assert {:ok, page} =
               %CurrentPage{}
               |> CurrentPage.changeset(CurrentPage.attrs_from_acp_meta(meta))
               |> Ecto.Changeset.apply_action(:insert)

      stored = page |> Ecto.embedded_dump(:json) |> Jason.encode!() |> Jason.decode!()
      restored = Ecto.embedded_load(CurrentPage, stored, :json)
      assert restored.astro_client_routing == status
      assert [%{"_meta" => history_meta}] = CurrentPageContext.to_content_blocks(restored)
      assert history_meta == meta
      assert CurrentPage.attrs_from_acp_meta(history_meta).astro_client_routing == status

      prompt = CurrentPageContext.to_prompt_section(restored)
      assert prompt =~ "Astro Client Routing: #{status}"

      case status do
        "enabled" ->
          assert prompt =~ "astro:page-load"
          assert prompt =~ "astro:before-swap"
          assert prompt =~ "not proof of completed navigation"
          assert prompt =~ "persisted elements"

        "disabled" ->
          assert prompt =~ "normal document-load initialization"
          refute prompt =~ "astro:page-load"

        "unavailable" ->
          assert prompt =~ "Do not infer that client routing is disabled"
          refute prompt =~ "astro:page-load"
      end
    end
  end

  test "legacy and non-Astro metadata omit routing status and guidance" do
    meta = %{"current_page" => true, "url" => "http://localhost:3000/"}
    fields = CurrentPage.attrs_from_acp_meta(meta)
    assert fields.astro_client_routing == nil
    assert [%{"_meta" => ^meta}] = CurrentPageContext.to_content_blocks(fields)
    refute CurrentPageContext.to_prompt_section(fields) =~ "Astro Client Routing"
  end

  test "rejects invalid routing metadata at parsing and storage boundaries" do
    for invalid <- [true, false, "unknown", %{}, 1] do
      assert_raise FunctionClauseError, fn ->
        CurrentPageContext.fields_from_meta(%{
          "url" => "http://localhost:4321/",
          "astro_client_routing" => invalid
        })
      end

      changeset = CurrentPage.changeset(%CurrentPage{}, %{astro_client_routing: invalid})
      refute changeset.valid?
    end
  end
end
