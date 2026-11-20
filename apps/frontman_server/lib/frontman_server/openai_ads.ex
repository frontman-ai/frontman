defmodule FrontmanServer.OpenAIAds do
  @moduledoc "Consent and durable, per-user advertising delivery bookkeeping."
  import Ecto.Changeset
  alias FrontmanServer.OpenAIAds.{Consent, DeliverConversion, Delivery}
  alias FrontmanServer.Repo

  @woocommerce_resources ~w(product product_category product_tag product_attribute attribute_term
    product_variation product_review order customer shipping_zone shipping_zone_method tax_rate coupon)
  @woocommerce_edits for resource <- @woocommerce_resources,
                         action <- ~w(create update delete),
                         do: "wc_#{action}_#{resource}"
  # Read/diagnostic tools, preview generation and cache maintenance are not edits.
  @editing_tools @woocommerce_edits ++
                   ~w(write_file edit_file wp_create_post wp_duplicate_post wp_update_post wp_delete_post
    wp_update_block wp_insert_block wp_move_block wp_delete_block wp_upload_media
    wp_update_option wp_restore_custom_css_revision wp_update_custom_css wp_update_theme_mod
    wp_update_customizer_setting wp_update_seo wp_set_post_language wp_write_public_file
    wp_create_redirect wp_delete_redirect wp_301_redirects_create wp_301_redirects_delete
    wp_set_widget_visibility wp_create_widget wp_update_widget wp_move_widget wp_delete_widget
    wp_create_menu wp_delete_menu wp_assign_menu_location wp_create_menu_item wp_update_menu_item
    wp_delete_menu_item wp_create_navigation_menu wp_update_navigation_menu wp_delete_navigation_menu
    wp_create_template wp_update_template wp_elementor_save_page_data wp_elementor_update_element
    wp_elementor_add_element wp_elementor_wrap_element wp_elementor_remove_element
    wp_elementor_restore_rollback wp_elementor_duplicate_element wp_elementor_move_element
    wc_create_order_note wc_delete_order_note wc_create_order_refund wc_delete_order_refund
    wc_update_shipping_zone_locations wc_create_tax_class wc_delete_tax_class
    wc_update_payment_gateway wc_update_setting_option)

  def editing_tools, do: @editing_tools
  def enabled?, do: Application.get_env(:frontman_server, __MODULE__, [])[:enabled] == true

  def grant(
        id,
        %{"advertising_consent" => true, "oppref" => oppref, "consent_updated_at_ms" => choice},
        user_id
      )
      when (is_nil(oppref) or (is_binary(oppref) and byte_size(oppref) in 1..2048)) and
             is_integer(choice) do
    Repo.transaction(fn ->
      lock_user(user_id)
      consent = get_consent(id)

      now_ms = System.system_time(:millisecond)

      unless choice in (now_ms - 180 * 86_400_000)..(now_ms + 600_000),
        do: Repo.rollback(:invalid_consent)

      unless owned?(consent, user_id), do: Repo.rollback(:association_conflict)
      active? = active?(consent)
      row = if active?, do: consent, else: %Consent{}

      attrs =
        case {active?, oppref} do
          {true, nil} ->
            %{}

          _new_attribution ->
            %{
              oppref: oppref,
              granted_at: DateTime.utc_now(),
              expires_at:
                min(now_ms + 30 * 86_400_000, choice + 180 * 86_400_000)
                |> div(1000)
                |> DateTime.from_unix!()
            }
        end

      row
      |> change(Map.put(attrs, :user_id, user_id))
      |> Repo.insert_or_update!(log: false)
    end)
  end

  def grant(_id, _params, _user_id), do: {:error, :invalid_consent}

  def associate(_user_id, nil), do: :ok

  def associate(user_id, id) do
    transact(user_id, fn ->
      consent = get_consent(id)

      if owned?(consent, user_id) && active?(consent) do
        Repo.update!(change(consent, user_id: user_id))
      end
    end)
  end

  def withdraw(id, user_id) do
    transact(user_id, fn ->
      consent = get_consent(id)
      if is_nil(user_id) || owned?(consent, user_id), do: revoke(consent)

      if user_id do
        Consent.for_user(user_id) |> Repo.all() |> Enum.each(&revoke/1)
      end
    end)
  end

  def record_registration(user_id, consent_id) do
    associate(user_id, consent_id)
    record(user_id, "registration_completed", user_id)
  end

  def record(user_id, kind, source_ref, eligible \\ true) do
    transact(user_id, fn ->
      consent = Repo.one(Consent.latest_for_user(user_id))

      reportable = enabled?() && eligible && active?(consent)

      row = %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        kind: kind,
        source_ref: source_ref,
        timestamp_ms: System.system_time(:millisecond),
        status: if(reportable, do: "pending", else: "suppressed"),
        consent_id: if(reportable, do: consent.id),
        oppref: if(reportable, do: consent.oppref)
      }

      case Repo.insert_all(Delivery, [row],
             on_conflict: :nothing,
             log: false,
             conflict_target: [:user_id, :kind],
             returning: [:id]
           ) do
        {1, [%{id: id}]} when reportable ->
          {:ok, _} = DeliverConversion.new(%{delivery_id: id}) |> Oban.insert()

        _already_consumed_or_denied ->
          :ok
      end
    end)
  end

  def editing_success?(name, %{"isError" => true}) when is_binary(name), do: false

  def editing_success?(name, %{"content" => content}) do
    name in @editing_tools &&
      Enum.all?(content, fn
        %{"type" => "text", "text" => text} ->
          case Jason.decode(text) do
            {:ok, %{"success" => false}} -> false
            {:ok, %{"updated" => false}} -> false
            {:ok, %{"dryRun" => true}} -> false
            {:ok, %{"dry_run" => true}} -> false
            {:ok, %{"before" => before, "after" => after_value}} -> before != after_value
            _text_or_operation_result -> true
          end

        _other_content ->
          true
      end)
  end

  def editing_success?(_name, _result), do: false

  def active?(%Consent{revoked_at: nil, expires_at: expires_at}),
    do: DateTime.compare(expires_at, DateTime.utc_now()) == :gt

  def active?(_consent), do: false

  def lock_user(nil), do: :ok

  def lock_user(id), do: Repo.one!(Consent.user_lock(id))

  defp transact(user_id, action) do
    {:ok, _} =
      Repo.transaction(fn ->
        lock_user(user_id)
        action.()
      end)

    :ok
  end

  defp get_consent(nil), do: nil

  defp get_consent(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.one(Consent.lock_query(id))
      :error -> nil
    end
  end

  defp owned?(nil, _user_id), do: true
  defp owned?(%Consent{user_id: nil}, _user_id), do: true
  defp owned?(%Consent{user_id: owner}, user_id), do: owner == user_id
  defp revoke(nil), do: :ok

  defp revoke(consent) do
    Repo.update!(change(consent, revoked_at: DateTime.utc_now(:second), oppref: nil))

    Delivery.pending_for_consent(consent.id)
    |> Repo.update_all(set: [status: "suppressed", oppref: nil])
  end
end
