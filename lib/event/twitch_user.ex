defmodule TwitchDiscordConnector.Event.TwitchUser do
  alias TwitchDiscordConnector.JsonDB.TwitchDB

  alias TwitchDiscordConnector.Discord
  alias TwitchDiscordConnector.Job.Manager
  alias TwitchDiscordConnector.Twitch
  alias TwitchDiscordConnector.Util.H
  alias TwitchDiscordConnector.Util.Expires
  alias TwitchDiscordConnector.Util.L

  # opts = {info, flags = %{}}
  def init(user_id) do
    TwitchDB.load_user(user_id)
    |> log_state("init")
  end

  def channel(), do: :twitch_user

  ###############
  ## Events #####
  ###############

  # startup event
  def handle_event({:event, :added, _}, {_, my_id}, s) do
    # Manager.start({:user_info, d}, {&Twitch.User.info_id/1, [s.uid]})
    # Manager.start({:list_subs, d}, {&Twitch.User.subs/0, []})
    maybe_get_info(s, my_id)
    |> schedule_sub_and_return()
  end

  ##################
  ## Job Results ###
  ##################

  # %{
  #    "broadcaster_type" => "partner",
  #    "description" => "I play Pokémon GO everyday unironically and am the self-proclaimed team leader of Team Mystic. We catch shinies all day SLIDE THROUGH!",
  #    "display_name" => "theMYSTIC7hwd",
  #    "id" => "171122649",
  #    "login" => "themystic7hwd",
  #    "offline_image_url" => "https://static-cdn.jtvnw.net/jtv_user_pictures/f09e413e-54e2-4aba-9594-bc701afc674d-channel_offline_image-1920x1080.jpeg",
  #    "profile_image_url" => "https://static-cdn.jtvnw.net/jtv_user_pictures/fd600e422372c53d-profile_image-300x300.png",
  #    "type" => "",
  #    "view_count" => 632209
  #
  def handle_event({:job, :user_info, info}, {s, m}, state) when s == m do
    {
      :ok,
      unwrap_result(info, state, :user_info, fn uinfo ->
        %{state | info: %{} |> H.grab_keys(uinfo, ["login", "display_name", "description"])}
        |> TwitchDB.save_user()
      end)
    }
  end

  def handle_event({:job, :subscribe, info}, {s, m}, state) when s == m do
    {
      :ok,
      unwrap_result(info, state, :subscribe, fn sub ->
        %{state | sub: sub}
        |> TwitchDB.save_user()
      end)
    }
  end

  ######################
  ## Other Callbacks ###
  ######################

  # Event.emit(:twitch, :stream, {:ended, %{uid: user_id}})

  def handle_event({:twitch, :stream, {:ended, eid}}, _, s = %{uid: uid}) when eid == uid do
    L.d("#{s}: Got :stream :ended notification")
    {:ok, s}
  end

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
  def handle_event({:twitch, :stream, {:up, eid, info}}, _, s = %{uid: uid}) when eid == uid do
    with stream_timestamp <- info["started_at"],
         do_disc_hook <- {:delay, 60 * 3 * 1000, :disc_hook},
         state_with_stream <- %{s | state: Map.put(s.state, "started_at", stream_timestamp)} do
      case Map.get(s, "last_stream", nil) do
        nil ->
          {do_disc_hook, state_with_stream}

        stream_dt ->
          case stream_dt == stream_timestamp do
            true -> {:ok, s}
            false -> {do_disc_hook, state_with_stream}
          end
      end
    end
  end

  def handle_event({:twitch_user, :disc_hook, _}, {src, d}, s) when src == d do
    Manager.start({:stream_notify, d}, {&Discord.webhook/1, [s.uid]})
    {:ok, s}
  end

  def handle_event({:twitch_user, :do_sub, _}, {src, d}, s) when src == d do
    Manager.start({:subscribe, d}, {&Twitch.Subs.subscribe/2, [s.uid, 60 * 60 * 8]})
    {:ok, s}
  end

  # default
  def handle_event(_, _, state) do
    {:ok, state}
  end

  ###############
  ## Helpers ####
  ###############

  defp maybe_get_info(s = %{info: nil}, my_id) do
    Manager.start({:user_info, my_id}, {&Twitch.User.info_id/1, [s.uid]})
    s
  end

  defp maybe_get_info(s, _), do: s

  defp schedule_sub_and_return(s = %{sub: nil}) do
    {{:emit, :do_sub}, s}
  end

  defp schedule_sub_and_return(s = %{sub: s_info}) do
    {{:delay, Expires.expires_in?(s_info), :do_sub}, s}
  end

  defp unwrap_result(result, state, tag, func) do
    case result do
      {:ok, good_info} ->
        func.(good_info)

      _ ->
        L.e(
          "#{state}: Unexpected response from #{inspect(tag)} call: #{
            inspect(result, pretty: true)
          }"
        )

        state
    end
  end

  defp log_state(s, label \\ "") do
    L.ins(s, label: label)
    s
  end

  # defp s_s(s), do: "#{state_name(s)}#{state_flags(s)}"
  # defp state_name(%{uid: uid, info: nil}), do: "TUser[#{uid}]"
  # defp state_name(%{uid: uid, info: %{"display_name" => d}}), do: "TU[#{d}(#{uid})]"
  # defp state_flags(s), do: "#{state_hook(s)}#{state_sub(s)}"
  # defp state_hook(%{hook: nil}), do: "[_]"
  # defp state_hook(%{hook: _}), do: "[H]"
  # defp state_sub(%{sub: nil}), do: "[_]"
  # defp state_sub(%{sub: _}), do: "[S]"
end
