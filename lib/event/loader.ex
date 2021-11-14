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
          |> add_job(twitch_handler_job(uid))
          # |> add_discord_handler(uid)
        end
      ),
      s
    }
  end

  # add discord handler when the twitch_handler broadcasts the data
  def handle_event({:brod, :twitch_user}, {:twitch_user_info, info}, s), do: {discord_handler_job(info), s}

  # default
  def handle_event(_), do: :ignore

  defp add_job(actions, handler), do: [ handler | actions ]

  defp twitch_handler_job(uid) do
    {
      :job,
      :me,
      :load_twitch,
      {
        &Event.add_listener/2,
        [TwitchDiscordConnector.Event.TwitchUser, uid]
      }
    }
  end

  defp discord_handler_job(user_info) do
    {
      :job,
      :me,
      :load_disc,
      {
        &Event.add_listener/2,
        [TwitchDiscordConnector.Event.DiscEvents, {user_info.uid, user_info}]
      }
    }
  end
end
