defmodule FrontmanNotifier.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children =
      state_children() ++
        [
          {Task.Supervisor, name: FrontmanNotifier.TaskSupervisor}
        ] ++ scheduler_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: FrontmanNotifier.Supervisor)
  end

  defp state_children do
    case Application.get_env(:frontman_notifier, :start_state, true) do
      true -> [FrontmanNotifier.State]
      false -> []
    end
  end

  defp scheduler_children do
    case Application.get_env(:frontman_notifier, :start_scheduler, true) do
      true -> [FrontmanNotifier.Scheduler]
      false -> []
    end
  end
end
