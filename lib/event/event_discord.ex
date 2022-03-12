defmodule TwitchDiscordConnector.Event.DiscEvents do
  @moduledoc """
  Event handler for discord interactions.

  Listens for events that might trigger messages to discord.
  """

  # alias TwitchDiscordConnector.JsonDB.TwitchUserDB
  alias TwitchDiscordConnector.Discord
  # alias TwitchDiscordConnector.Util.L

  # state: {user id, hook url, [keyword list]}
  def init({user_id, user_info}) do
    {
      user_id,
      %{
        user: user_info,
        hook: user_info.hook,
        last_stream: nil
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

  @doc """
  Send discord hook in response to stream, unless we've already sent a notification for this stream.
  """

  def handle_event({_, :twitch}, {:stream, {event, e_uid, info}}, s = {uid, _}) do
    # L.d("Event.Discord] Stream event: {#{event}, #{e_uid}, info} (uid == e_uid: #{uid == e_uid})")

    if e_uid == uid do
      my_stream(s, event, info)
    else
      other_stream(s, event, info)
    end
  end

  # default
  def handle_event(_), do: :ignore

  # %{
  #   "event" => %{
  #     "broadcaster_user_id" => "503254",
  #     "broadcaster_user_login" => "aeturnum",
  #     "broadcaster_user_name" => "aeturnum",
  #     "id" => "45800882589",
  #     "started_at" => "2022-03-10T18:46:14Z",
  #     "type" => "live"
  #   },
  #   "subscription" => %{
  #     "condition" => %{
  #       "broadcaster_user_id" => "503254"},
  #       "cost" => 1,
  #       "created_at" => "2022-03-10T16:32:49.659178473Z",
  #       "id" => "a596f07d-1e22-4422-b6b2-73f53ec68b1d",
  #       "status" => "enabled",
  #       "transport" => %{
  #           "callback" => "https://twitch.naturecultur.es/hook/stream?user_id=503254",
  #           "method" => "webhook"
  #       },
  #     "type" => "stream.online",
  #     "version" => "1"
  #   }
  # }
  defp my_stream(s = {uid, data}, "stream.online", %{"event" => event}) do
    if data.last_stream == event["started_at"] do
      {:ok, s}
    else
      {
        do_disc_hook(s),
        {uid, Map.put(data, :last_stream, event["started_at"])}
      }
    end
  end

  defp my_stream(s, _, _info), do: {:ok, s}

  defp other_stream(s, _event, _info) do
    {:ok, s}
  end

  # defp delay_asking_for_info() do
  #   {
  #     :in,
  #     :info_wait,
  #     3 * 1000,
  #     {:send, :me, :get_info, nil}
  #   }
  # end

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
