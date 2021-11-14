defmodule TwitchDiscordConnector.Event.DiscEvents do
  @moduledoc """
  Event handler for discord interactions.

  Listens for events that might trigger messages to discord.
  """

  alias TwitchDiscordConnector.JsonDB.TwitchUserDB
  alias TwitchDiscordConnector.Discord

  # state: {user id, hook url, [keyword list]}
  def init({user_id, user_info}) do
    {
      user_id,
      %{
        user: user_info,
        hook: user_info.hook,
        last_stream: nil,
      }
    }

  end

  def channel(), do: :discord_manager

  #############
  ## Events ###
  #############

  # def handle_event({:send, :event}, {:added, _}, s) do
  #   {delay_asking_for_info()}, s}
  # end

  #   {:ok,
  #  %{
  #    "game_id" => "490655",
  #    "id" => "40139934782",
  #    "language" => "en",
  #    "started_at" => "2020-10-18T22:54:53Z",
  #    "tag_ids" => ["6ea6bca4-4712-4ab9-a906-e3336a9d8039"],
  #    "thumbnail_url" => "https://static-cdn.jtvnw.net/previews-ttv/live_user_themystic7hwd-{width}x{height}.jpg",
  #    "title" => "SHUNDO GIRATINA HUNTING!",
  #    "type" => "live",
  #    "user_id" => "171122649",
  #    "user_name" => "theMYSTIC7hwd",
  #    "viewer_count" => 864
  #  }}
  @doc """
  Send discord hook in response to stream, unless we've already sent a notification for this stream.
  """
  def handle_event({_, :twitch}, {:stream, {:up, eid, info}}, s = {uid, data}) when eid == uid do
    case data.last_stream == info["started_at"] do
      true ->
        {:ok, s}

      false ->
        {
          do_disc_hook(s),
          {uid, Map.put(data, :last_stream, info["started_at"])}
        }
    end
  end

  # default
  def handle_event(_), do: :ignore

  defp delay_asking_for_info() do
    {
      :in,
      :info_wait,
      3 * 1000 ,
      {:send, :me, :get_info, nil}
    }
  end

  defp do_disc_hook(s) do
    {
      :in,
      :disc_delay,
      60 * 1000 * 3,
      {:job, :me, :hook, disc_call(s)}
    }
  end

  defp disc_call({uid, %{hook: nil}}), do: {&Discord.fake_hook/1, [uid]}
  defp disc_call({uid, %{hook: hook}}), do: {&Discord.webhook/2, [uid, hook]}
end
