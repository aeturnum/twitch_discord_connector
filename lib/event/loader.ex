defmodule TwitchDiscordConnector.Event.Loader do
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB

  alias TwitchDiscordConnector.Event
  # alias TwitchDiscordConnector.Util.H
  # alias TwitchDiscordConnector.Util.L

  # state: {user id, hook url, [keyword list]}
  def init(_), do: {}

  def channel(), do: :loader

  #############
  ## Events ###
  #############

  # startup event
  def handle_event({:send, :event}, {:added, _}, s) do
    {
      TwitchUserDB.user_ids()
      |> Enum.reduce(
        [],
        fn uid, actions ->
          actions
          |> add_twitch_handler(uid)
          |> add_discord_handler(uid)
        end
      ),
      s
    }
  end

  # default
  def handle_event(_), do: :ignore

  defp add_twitch_handler(actions, uid) do
    [
      {
        :job,
        :me,
        :load_twitch,
        {
          &Event.add_listener/2,
          [TwitchDiscordConnector.Event.TwitchUser, uid]
        }
      }
      | actions
    ]
  end

  defp add_discord_handler(actions, uid) do
    [
      {
        :job,
        :me,
        :load_disc,
        {
          &Event.add_listener/2,
          [TwitchDiscordConnector.Event.DiscEvents, uid]
        }
      }
      | actions
    ]
  end
end
