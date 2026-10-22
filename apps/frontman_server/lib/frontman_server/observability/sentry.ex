defmodule FrontmanServer.Observability.Sentry do
  @moduledoc false

  def before_send(
        %Sentry.Event{
          original_exception: %Ecto.InvalidChangesetError{changeset: changeset, action: action}
        } = event
      ) do
    errors =
      PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
        # Only interpolate validation counts, never rejected values or changeset params.
        case Keyword.fetch(opts, :count) do
          {:ok, count} -> String.replace(message, "%{count}", to_string(count))
          :error -> message
        end
      end)

    summary = "could not perform #{action} because changeset is invalid"

    exceptions =
      Enum.map(event.exception, fn exception ->
        if exception.type == "Ecto.InvalidChangesetError" do
          %{exception | value: summary}
        else
          exception
        end
      end)

    %{
      event
      | exception: exceptions,
        extra: Map.put(event.extra, :changeset_errors, errors)
    }
  end

  def before_send(event), do: event
end
