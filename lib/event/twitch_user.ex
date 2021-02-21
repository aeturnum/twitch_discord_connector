defmodule TwitchDiscordConnector.Event.TwitchUser do
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB

  alias TwitchDiscordConnector.Twitch
  alias TwitchDiscordConnector.Util.H
  alias TwitchDiscordConnector.Util.Expires
  alias TwitchDiscordConnector.Util.L

  # opts = {info, flags = %{}}
  def init(user_id) do
    TwitchUserDB.load_user(user_id)
    # |> log_state("init")
  end

  def channel(), do: :twitch_user

  ###############
  ## Events #####
  ###############

  # startup event
  def handle_event({:send, :event}, {:added, _}, s) do
    {[], s}
    |> maybe_get_info()
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
  @doc """
  Save information for this twitch user.
  """
  def handle_event({:send, :me}, {:user_info, info}, state) do
    {
      :ok,
      unwrap_result(info, state, %{
        :ok => fn uinfo ->
          %{state | info: %{} |> H.grab_keys(uinfo, ["login", "display_name", "description"])}
          |> TwitchUserDB.save_user()
        end,
        :error => fn err ->
          L.e("Error getting user info: #{inspect(err)}")
          {[], state} |> maybe_get_info()
        end
      })
    }
  end

  @doc """
  Save subscription information

  todo: record if the subscription has been confirmed or not.
  """
  def handle_event({:send, :me}, {:subscribe, info}, state) do
    unwrap_result(info, state, %{
      :ok => fn sub ->
        with new_state <- %{state | sub: sub} |> TwitchUserDB.save_user() do
          {sub_later(new_state), new_state}
        end
      end,
      :error => fn error_info ->
        L.e("Error subbing: #{inspect(error_info)}")
        {sub_later(state, 30 * 1000), state}
      end
    })

    # with sub <- unwrap_result(info, state),
    #      new_state <- %{state | sub: sub} |> TwitchUserDB.save_user() do
    #   {sub_later(new_state), new_state}
    # end
  end

  ####################
  ## Delay Handles ###
  ####################

  @doc """
  Save information for this twitch user.
  """
  def handle_event({:send, :me}, {:delay_started, {:sub_delay, _}}, s) do
    L.d("#{s}: Ignoring notification about sub_delay handle")
    {:ok, s}
  end

  ######################
  ## Other Callbacks ###
  ######################

  # default
  def handle_event(_), do: :ignore

  ###############
  ## Helpers ####
  ###############

  defp maybe_get_info({a, s = %{info: nil}}) do
    {
      [{:job, :me, :user_info, info_call(s)} | a],
      s
    }
  end

  defp maybe_get_info({a, s}), do: {a, s}

  defp schedule_sub_and_return({a, s = %{info: nil}}) do
    {
      [sub_job(s) | a],
      s
    }
  end

  defp schedule_sub_and_return({a, s}) do
    {
      [sub_later(s) | a],
      s
    }
  end

  # delay is in ms
  defp sub_later(s = %{sub: s_i}, delay \\ 0),
    do: {:in, :sub_delay, Expires.expires_in?(s_i) + delay, sub_job(s)}

  defp sub_job(s), do: {:job, :me, :subscribe, sub_call(s)}
  # defp do_disc_hook(s), do: {:in, :disc_delay, 60 * 1000 * 3, {:job, :me, :hook, disc_call(s)}}

  defp info_call(s), do: {&Twitch.User.info_id/1, [s.uid]}
  defp sub_call(s), do: {&Twitch.Subs.subscribe/2, [s.uid, 60 * 60 * 8]}
  # defp disc_call(s), do: {&Discord.webhook/1, [s.uid]}

  defp unwrap_result(result, state, func_map \\ %{}) do
    func_map = Map.put_new(func_map, :ok, fn x -> x end)

    case result do
      {atom, arg} ->
        func = func_map[atom]
        func.(arg)

      _ ->
        L.e("#{state}: Unexpected response: #{inspect(result, pretty: true)}")

        # return old state
        state
    end
  end

  # defp log_state(s, label \\ "") do
  #   L.ins(s, label: label)
  #   s
  # end

  # defp s_s(s), do: "#{state_name(s)}#{state_flags(s)}"
  # defp state_name(%{uid: uid, info: nil}), do: "TUser[#{uid}]"
  # defp state_name(%{uid: uid, info: %{"display_name" => d}}), do: "TU[#{d}(#{uid})]"
  # defp state_flags(s), do: "#{state_hook(s)}#{state_sub(s)}"
  # defp state_hook(%{hook: nil}), do: "[_]"
  # defp state_hook(%{hook: _}), do: "[H]"
  # defp state_sub(%{sub: nil}), do: "[_]"
  # defp state_sub(%{sub: _}), do: "[S]"
end
