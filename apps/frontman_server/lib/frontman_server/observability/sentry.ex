defmodule FrontmanServer.Observability.Sentry do
  @moduledoc false

  def before_send(
        %Sentry.Event{
          original_exception: %Ecto.InvalidChangesetError{changeset: changeset}
        } = event
      ) do
    errors =
      PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
        %{message: message, metadata: Map.new(opts)}
      end)

    %{event | extra: Map.put(event.extra, :changeset_errors, errors)}
  end

  def before_send(event), do: event
end
