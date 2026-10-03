defmodule FrontmanServer.CurrentPageContextTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction.CurrentPage
  alias FrontmanServer.Tasks.Interaction.UserMessage

  test "routing status survives ACP parsing, embedded storage, history, and prompt formatting" do
    for status <- ["enabled", "disabled", "unavailable"] do
      meta = %{
        "current_page" => true,
        "url" => "http://localhost:4321/",
        "astro_client_routing" => status
      }

      assert {:ok, page} =
               %CurrentPage{}
               |> CurrentPage.changeset(
                 UserMessage.attrs([%{"type" => "resource", "_meta" => meta}]).current_page
               )
               |> Ecto.Changeset.apply_action(:insert)

      stored = page |> Ecto.embedded_dump(:json) |> Jason.encode!() |> Jason.decode!()
      restored = Ecto.embedded_load(CurrentPage, stored, :json)
      assert restored.astro_client_routing == status
      assert [history_block] = CurrentPageContext.to_content_blocks(restored)
      assert UserMessage.attrs([history_block]).current_page == meta

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
    fields = UserMessage.attrs([%{"type" => "resource", "_meta" => meta}]).current_page
    assert [%{"_meta" => ^meta}] = CurrentPageContext.to_content_blocks(fields)
    refute CurrentPageContext.to_prompt_section(fields) =~ "Astro Client Routing"
  end

  test "preserves invalid routing metadata for changeset validation" do
    for invalid <- [true, false, "unknown", %{}, 1] do
      meta = %{
        "current_page" => true,
        "url" => "http://localhost:4321/",
        "astro_client_routing" => invalid
      }

      assert UserMessage.attrs([%{"type" => "resource", "_meta" => meta}]).current_page == meta
      refute CurrentPage.changeset(%CurrentPage{}, meta).valid?
    end
  end
end
