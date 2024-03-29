defmodule TwitchDiscordConnector do
  use Application

  alias TwitchDiscordConnector.Util.L

  def init(:ok) do
  end

  def start(_type, _args) do
    import Supervisor.Spec,
      warn: false

    with env <- Application.get_env(:twitch_discord_connector, :environment),
         {:ok, pid} <- start_internal_processes() do
      # start outward facing layer
      L.i("[TDC] Start")

      Enum.each(external_processes(env), fn child ->
        Supervisor.start_child(pid, child)
        |> L.ins(label: "Starting External Process: #{elem(child, 0)}")
      end)

      # Call all startup tasks now that internal and external services are up
      TwitchDiscordConnector.Startup.startup_tasks()
      L.i("[TDC] Done with Start")
      {:ok, pid}
    else
      other ->
        L.e("Supervisor failed to start: #{inspect(other)}")
    end
  end

  defp start_internal_processes() do
    [
      {TwitchDiscordConnector.JsonDB, settings(:init_jsondb)},
      {TwitchDiscordConnector.Event, settings(:init_event)},
      {TwitchDiscordConnector.Util.Live, []},
      {TwitchDiscordConnector.Template.SrcServer, settings(:init_srcserver)}
    ]
    |> Supervisor.start_link(strategy: :one_for_one, name: TwitchDiscordConnector.Supervisor)
  end

  defp external_processes(:test), do: []

  defp external_processes(_) do
    [
      {Plug.Cowboy,
       scheme: :http, plug: TwitchDiscordConnector.Views.Router, options: [port: 4000]}
      # {TwitchDiscordConnector.Twitch.Bot, settings(:init_bot)}
    ]
  end

  defp settings(atom), do: Application.get_env(:twitch_discord_connector, atom, [])
end
