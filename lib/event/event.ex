defmodule TwitchDiscordConnector.Event do
  use GenServer

  @name Event

  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Util.L

  # Required functions:
  #   init({your_address, args}) -> state
  #   channel() -> channel atom
  #   handle_event(from, event, state)
  # valid responses:
  #   :ignore
  #   {:ok, new_state}
  #   {action, new_state}
  #   {[actions], new_state}
  # actions:
  #   {:broad, name, data \\ nil}
  #   {:send, to, name, data \\ nil} # to can be :me
  #   {:job, to, name, {function, args}} # to can be :me, :broad or addr
  #   {:in, ms, what} # what can be any action
  # callback format:
  # handle_event(from, event, state)
  #   where from is:
  #     {:broad, tag}
  #     :me # special case for sending to yourself
  #     {:from, id}

  # {:job, {0, :subscribe}, data}
  def emit(channel, src_id, name, data \\ %{}) do
    GenServer.cast(@name, {{:emit, name, data}, {channel, src_id}})
  end

  def delay(ms, channel, src_id, name, data \\ %{}) do
    GenServer.cast(@name, {{:delay, ms, name, data}, {channel, src_id}})
  end

  def add_module(module, init_arg \\ []) do
    GenServer.call(@name, {:add_mod, module, init_arg})
  end

  ########################
  ### Init ###############
  ########################

  def start_link(modules) do
    GenServer.start_link(__MODULE__, modules, name: @name)
  end

  def init(modules) do
    {
      :ok,
      {
        0,
        # module to state map
        [],
        # tasks
        []
      }
      |> make_start_state(modules)

      # ,
      # {:continue, []}
    }
  end

  # def handle_continue([], state) do
  #   {:noreply, state}
  # end

  defp make_start_state({id, mods, tks}, modules) do
    with mod_and_args <- Enum.map(modules, &to_mod_and_args/1),
         {id, mods} <- Enum.reduce(mod_and_args, {id, mods}, &add_mod_to_list/2) do
      {
        id,
        Enum.reverse(mods),
        tks
      }
    end
  end

  defp to_mod_and_args({mod, arg}), do: {mod, arg}
  defp to_mod_and_args(mod), do: {mod, []}

  defp add_mod_to_list({mod, arg}, {next_id, list}) do
    with channel <- mod.channel(),
         mod_state <- mod.init(arg),
         init_state_tuple <- {next_id, mod, channel, mod_state},
         state_tuple <- send_event(init_state_tuple, :event, {:event, :added, %{}}) do
      {next_id + 1, [state_tuple | list]}
    end
  end

  ########################
  ### Handles ############
  ########################

  def handle_call({:add_mod, module, init_arg}, _from, {nid, mod_list, tsks}) do
    with {id, new_list} <- add_mod_to_list({module, init_arg}, {nid, mod_list}) do
      {:reply, :ok, {id, new_list, tsks}}
    end
  end

  def handle_call(info, _from, state) do
    L.e("Manager: unexpected call: #{inspect(info)}")
    {:reply, nil, state}
  end

  def handle_cast({{:emit, name, data}, {channel, src_id}}, state) do
    {:noreply, emit_event(state, channel, src_id, name, data)}
  end

  def handle_cast({{:delay, ms, name, data}, {channel, src_id}}, state) do
    {:noreply, delay_event(state, ms, channel, src_id, name, data)}
  end

  # todo: add shutdown event

  defp send_event({id, module, channel, last_state}, src_id, event) do
    {
      id,
      module,
      channel,
      try do
        event
        # |> L.ins(label: "Sending event to #{inspect(key)}(#{inspect(last_state)})")
        |> module.handle_event({src_id, id}, last_state)
        |> L.ins(
          label:
            "#{inspect(channel)}::#{id} response to #{inspect(event)},#{inspect({src_id, id})}"
        )
        |> handle_response({channel, id})

        # |> L.ins(label: "module state")
      rescue
        FunctionClauseError ->
          last_state
          |> L.ins(label: "#{inspect(channel)}::#{id} does not handle #{inspect(event)}")
      end
    }
  end

  defp emit_event({nid, mod_info, tsks}, channel, src_id, name, data) do
    L.d("Emitting #{inspect({channel, name, data})}")

    {
      nid,
      mod_info
      |> Enum.map(fn info ->
        send_event(info, src_id, {channel, name, data})
      end),
      tsks
    }
  end

  defp delay_event({id, mod_info, tsks}, ms, channel, src_id, name, data) do
    {
      id,
      mod_info,
      [Task.start(fn -> delay_task(ms, channel, src_id, name, data) end) | tsks]
    }
  end

  defp delay_task(ms, channel, src_id, name, data) do
    :timer.sleep(ms)
    L.d("delay_task started by #{inspect(channel)}::#{src_id} executing after #{ms}ms")
    Event.emit(channel, src_id, name, data)
  end

  defp handle_response({:ok, state}, _), do: state

  # allow callers omit data for emits
  defp handle_response({{:emit, name}, state}, ch_info),
    do: handle_response({{:emit, name, nil}, state}, ch_info)

  defp handle_response({{:emit, name, data}, state}, {channel, src_id}) do
    # queue using ipc mechanism to avoid loops
    emit(channel, src_id, name, data)
    state
  end

  defp handle_response({{:delay, ms, name}, state}, ch_info),
    do: handle_response({{:delay, ms, name, nil}, state}, ch_info)

  defp handle_response({{:delay, ms, name, data}, state}, {channel, src_id}) do
    Event.delay(ms, channel, src_id, name, data)
    state
  end

  defp handle_response({unknown, state}, channel) do
    L.ins(unknown, label: "handle_response unknown argument from #{inspect(channel)}")
    state
  end
end
