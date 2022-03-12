defmodule TwitchDiscordConnector.Event.TwitchUser do
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB

  alias TwitchDiscordConnector.Twitch
  # alias TwitchDiscordConnector.Util.H
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Util.Live
  # alias TwitchDiscordConnector.Twitch.Bot
  alias TwitchDiscordConnector.Event.Helpers

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
    L.i("[TwitchUser] Was added...")

    if Live.is_live() do
      {[], s}
      |> maybe_get_info()
      |> schedule_sub_and_return()
    else
      {[], s}
      |> maybe_get_info()
    end

    # |> L.ins(label: "[TwitchUser] Added return")
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
  handle_event has several prototypes:
  handle_event({:send, :me}, {:user_info, info}, state) ->
    Records the information that twitch sends us in `info`
  handle_event({:send, :me}, {:subscribe, info}, state) ->
    Records that we have an active user subscrption, unless the call
    fails and then we subscribe again after 30s
  handle_event({:send, :me}, {:delay_started, {:sub_delay, _}}, state) ->
    Notification that a delay has been started on our behalf. We ignore this call.
  Save information for this twitch user.
  """
  def handle_event({:send, :me}, {:user_info, info}, state) do
    unwrap_result(info, state, %{
      :ok => fn uinfo ->
        with new_state <- TwitchUserDB.save_user_info(state, uinfo) do
          {info_broadcast(new_state), new_state}
        end
      end,
      :error => fn err ->
        L.e("Error getting user info: #{inspect(err)}")
        {[], state} |> maybe_get_info()
      end
    })
  end

  # values ms   * sec * min * hours
  @one_day 1000 * 60 * 60 * 24

  def handle_event({:send, :me}, {:subscribe_status, info}, state) do
    unwrap_result(info, state, %{
      :ok => fn sub_list ->
        actions =
          [
            {"stream.online", sub_online_job(state)},
            {"stream.offline", sub_offline_job(state)}
          ]
          |> Enum.reduce(
            [sub_status_later(state, @one_day)],
            fn {to_check, job}, task_list ->
              unless to_check in sub_list do
                [job | task_list]
              else
                task_list
              end
            end
          )

        {actions, state}
      end,
      :error =>
        error_function("Error Checking Subscription", sub_status_later(state, 30 * 1000), state)
    })

    # with sub <- unwrap_result(info, state),
    #      new_state <- %{state | sub: sub} |> TwitchUserDB.save_user() do
    #   {sub_later(new_state), new_state}
    # end
  end

  def handle_event({:send, :me}, {:subscribe_online, info}, state) do
    unwrap_result(info, state, %{
      :ok => fn on_sub ->
        {[], %{state | online_sub: on_sub} |> TwitchUserDB.save_user()}
      end,
      :error =>
        error_function(
          "Error Subscribing Online",
          Helpers.delay(30 * 1000, sub_online_job(state)),
          state
        )
    })
  end

  def handle_event({:send, :me}, {:subscribe_offline, info}, state) do
    unwrap_result(info, state, %{
      :ok => fn off_sub ->
        {[], %{state | offline_sub: off_sub} |> TwitchUserDB.save_user()}
      end,
      :error =>
        error_function(
          "Error Subscribing Offline",
          Helpers.delay(30 * 1000, sub_offline_job(state)),
          state
        )
    })
  end

  ####################
  ## Delay Handles ###
  ####################

  def handle_event({:send, :me}, {:delay_started, {:sub_delay, _}}, state) do
    L.d("#{state}: Ignoring notification about sub_delay handle")
    {:ok, state}
  end

  ######################
  ## Other Callbacks ###
  ######################

  # default
  def handle_event(_), do: :ignore

  ###############
  ## Helpers ####
  ###############

  # get info if it's nil
  defp maybe_get_info({a, s = %{info: nil}}) do
    {
      [Helpers.job(:user_info, info_call(s)) | a],
      s
    }
  end

  # broadcast info if we have it
  defp maybe_get_info({a, s}) do
    {[info_broadcast(s) | a], s}
  end

  defp schedule_sub_and_return({a, s}) do
    {[sub_status_later(s) | a], s}
  end

  # delay is in ms
  # defp sub_later(s, delay \\ 0),
  #   do: {:in, :sub_delay, Expires.expires_in?(s_i) + delay, sub_job(s)}

  # defp sub_later(s, delay \\ 0), do: Helpers.delay(delay, sub_job(s))
  defp sub_status_later(s, delay \\ 0), do: Helpers.delay(delay, sub_status_job(s))

  defp sub_status_job(s), do: Helpers.job(:subscribe_status, sub_status_call(s), :me)
  defp sub_online_job(s), do: Helpers.job(:subscribe_online, sub_online_call(s), :me)
  defp sub_offline_job(s), do: Helpers.job(:subscribe_offline, sub_offline_call(s), :me)
  # defp do_disc_hook(s), do: {:in, :disc_delay, 60 * 1000 * 3, {:job, :me, :hook, disc_call(s)}}

  defp info_broadcast(s) do
    Helpers.broadcast(:twitch_user_info, s)
  end

  defp info_call(s), do: Helpers.function_call(&Twitch.User.info_id/1, [s.uid])

  defp sub_status_call(s),
    do: Helpers.function_call(&Twitch.Subs.current_subscriptions/1, [s.uid])

  defp sub_online_call(s),
    do: Helpers.function_call(&Twitch.Subs.subscribe_online/1, [s.uid])

  defp sub_offline_call(s),
    do: Helpers.function_call(&Twitch.Subs.subscribe_offline/1, [s.uid])

  # defp disc_call(s), do: {&Discord.webhook/1, [s.uid]}

  defp error_function(label, error_call, state) do
    fn {code, error_info} ->
      case code do
        401 ->
          # really we should have a job do this...
          Twitch.Auth.refresh_auth()

        _ ->
          nil
      end

      L.e("#{label}: #{inspect(error_info)}")
      {error_call, state}
    end
  end

  defp unwrap_result(result, state, func_map) do
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
