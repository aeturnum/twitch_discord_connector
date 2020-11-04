defmodule TwitchDiscordConnector.Event.DiscEvents do
  @moduledoc """
  Event handler for discord interactions.

  Listens for events that might trigger messages to discord.
  """

  alias TwitchDiscordConnector.JsonDB.TwitchUserDB
  alias TwitchDiscordConnector.Discord

  # state: {user id, hook url, [keyword list]}
  def init(user_id) do
    with %{uid: uid, hook: hook_url} <- TwitchUserDB.load_user(user_id) do
      case hook_url do
        nil -> {uid, []}
        value -> {uid, [hook: value]}
      end
    end
  end

  def channel(), do: :discord_manager

  #############
  ## Events ###
  #############

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
    case Keyword.get(data, :last_stream, nil) == info["started_at"] do
      true ->
        {:ok, s}

      false ->
        {
          do_disc_hook(s),
          {uid, Keyword.put(data, :last_stream, info["started_at"])}
        }
    end
  end

  # default
  def handle_event(_), do: :ignore

  defp do_disc_hook(s) do
    {
      :in,
      :disc_delay,
      60 * 1000 * 3,
      {:job, :me, :hook, disc_call(s)}
    }
  end

  defp disc_call({uid, data}) do
    case Keyword.get(data, :hook, nil) do
      nil ->
        {&Discord.fake_hook/1, [uid]}

      hook ->
        {&Discord.webhook/2, [uid, hook]}
    end
  end
end
