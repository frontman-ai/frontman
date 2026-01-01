ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(FrontmanServer.Repo, :manual)

# Start Swarm supervisor once for all tests
{:ok, _} = Swarm.Supervisor.start_link([])
