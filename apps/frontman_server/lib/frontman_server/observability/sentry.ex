defmodule FrontmanServer.Observability.Sentry do
  @moduledoc false

  def before_send(
        %Sentry.Event{
          original_exception: %Ecto.InvalidChangesetError{changeset: changeset}
        } = event
      ) do
    errors =
      PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
        metadata = Map.new(opts, fn {key, value} -> {key, json_safe(value)} end)
        %{message: message, metadata: metadata}
      end)

    %{event | extra: Map.put(event.extra, :changeset_errors, errors)}
  end

  def before_send(event), do: event

  defp json_safe(value) do
    case Jason.encode(value) do
      {:ok, encoded} -> Jason.decode!(encoded)
      {:error, _reason} -> inspect(value)
    end
  end
end
