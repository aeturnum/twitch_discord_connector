defmodule TwitchDiscordConnector.Event do
  @moduledoc """
  Event System

  Simple messaging system used to allow different elements of the server to communicate with each other.

  Required functions to be a listener:
    init({your_address, args}) -> state
    channel() -> channel atom
    handle_event(from, event, state)
  valid responses:
    :ignore
    {:ok, new_state}
    {action, new_state}
    {[actions], new_state}
  actions:
    {:brod, name, data \\ nil}
    {:send, to, name, data \\ nil} # `to` can be :me or addr
    {:job, to, name, {function, args}} # `to` can be :me, :brod or addr
    {:in, ms, what} # what can be any action
    {:cancel, delay_id} # cancel a delay task
  callback format:
  handle_event(ctx, event, state)
    where ctx is:
      {:brod, channel} # broadcast
      {:send, channel} # sent to your address
      :me # sent to your address by yourself
    where event is:
      {name, data}
    state is state

  delay tasks, once started, will generate a callback equivilent to the job starter returning:
  {:send, :me, :started, delay_id} on the :event channel.
  This can be used to cancel the delay

  internal state: {next_id, listeners, tasks}
  listener: {id, elixir_module, tag, state}
  """
  use GenServer

  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Util.L

  @name Event

  @type delay_atom :: :in | :delay
  @type f_call() :: {fun(), list()}
  @type addr() :: integer() | :me
  @type action() ::
          {:brod, atom(), any()}
          | {:send, addr(), atom(), any()}
          | {:job, addr(), atom(), f_call()}
          | {delay_atom(), integer(), action()}
          | {:cancel, integer()}
  @type response() :: :ignore | {action(), map()} | {[action()], map()}

  @doc """
  Broadcast a message to every listener from `channel` with name `message_name`.
  Optionally include an arbitraty `data` argument (will be `nil` is excluded)

  Returns `:ok`
  """
  @spec broadcast({atom(), atom()}, any()) :: :ok
  def broadcast({channel, message_name}, data \\ nil) do
    GenServer.cast(@name, {{:brod, data}, {channel, message_name, :brod}})
  end

  @doc """
  Send a message to one listener from `channel` with name `message_name`.
  Must specify `from` and `to`. `from` may be a special case atom `:me` which deisgnates it is a message sent by
  the target.
  Optionally include an arbitraty `data` argument (will be `nil` is excluded)

  Returns `:ok`
  """
  @spec send({atom(), atom()}, {addr(), addr()}, any()) :: :ok
  def send({channel, message_name}, {from, to}, data \\ %{}) do
    GenServer.cast(@name, {{:send, to, data}, {channel, message_name, from}})
  end

  @doc """
  Execute an action (as defined by an internal format) in `ms` milliseconds.
  This function isn't really designed to be called by outsiders and so a later
  update may add a pathway to start a delay that doesn't generate an internal
  callback with the handle.

  Will cause a callback to the listener in the `from` field with the delay handle
  in case you want to cancel the delay.

  Returns `:ok`
  """
  @spec delay(atom(), integer(), action(), {addr(), atom()}) :: :ok
  def delay(name, ms, action, {from, channel}) do
    GenServer.cast(@name, {:delay, name, ms, action, {from, channel}})
  end

  @doc """
  Execute a job and return the result to a listener. Should also probably be changed
  as all of the jobs I've written so far are responding to the listener that started
  them.

  Returns `:ok`
  """
  @spec job(atom(), {addr(), addr()}, fun(), list()) :: :ok
  def job(name, {from, to}, func, args \\ []) do
    GenServer.cast(@name, {{:job, to, func, args}, {:job, name, from}})
  end

  @doc """
  Cancel a delay using the handle

  Returns `:ok`
  """
  def cancel_delay(delay_id) do
    GenServer.cast(@name, {:cancel_delay, delay_id})
  end

  @doc """
  Add a listener using the specified module and argument.

  `module` is an Elixer module
  `init_arg` is anything, but will default to an empty list

  Can be used to load listeners after start

  Returns `{:ok, listener_id}`
  """
  @spec add_listener(module(), list()) :: {:ok, integer()}
  def add_listener(module, init_arg \\ []) do
    GenServer.call(@name, {:add_lis, module, init_arg})
  end

  @doc """
  Get the current state of a listener as specified by the id.`

  Mostly used for testing.

  Returns `{:ok, listener_id}`
  """
  @spec get_state(integer()) :: {:ok, map()} | {:error, binary()}
  def get_state(address) do
    GenServer.call(@name, {:get_state, address})
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
        # listeners
        [],
        # tasks
        []
      }
      |> make_start_state(modules)
    }
  end

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

  # defp send_event(lis = {m_id, mod, m_ch, last_state}, {channel, name, from}, {type, data}) do
  defp add_mod_to_list({mod, arg}, {next_id, list}) do
    with channel <- mod.channel(),
         mod_state <- mod.init(arg),
         init_listener <- {next_id, mod, channel, mod_state},
         state_tuple <- send_event(init_listener, {:event, :added, :event}, {:send, %{}}) do
      L.d("Added #{lis_s(state_tuple)} with Module #{inspect(mod)}")
      {next_id + 1, [state_tuple | list]}
    end
  end

  ########################
  ### Handles ############
  ########################

  def handle_call({:add_lis, module, init_arg}, _from, {nid, mod_list, tsks}) do
    with {id, new_list} <- add_mod_to_list({module, init_arg}, {nid, mod_list}) do
      {:reply, {:ok, nid}, {id, new_list, tsks}}
    end
  end

  def handle_call({:get_state, addr}, _from, s) do
    with {:ok, listener} <- find_addr(s, addr) do
      {:reply, {:ok, elem(listener, 3)}, s}
    end
  end

  def handle_call(info, _from, state) do
    L.e("Manager: unexpected call: #{inspect(info)}")
    {:reply, nil, state}
  end

  def handle_cast({{:brod, data}, src}, state) do
    {:noreply, send_broadcast(state, src, data)}
  end

  def handle_cast({{:send, to, data}, src}, state) do
    {:noreply, send_send(state, src, to, data)}
  end

  def handle_cast({:delay, name, ms, action, context}, state) do
    {:noreply, delay_action(state, name, ms, action, context)}
  end

  def handle_cast({{:job, to, func, args}, src}, state) do
    {:noreply, start_job(state, to, {func, args}, src)}
  end

  def handle_cast({:cancel_delay, delay_id}, state) do
    {:noreply, cancel_delay(state, delay_id)}
  end

  # todo: add shutdown event

  #######################
  ### Doers #############
  #######################

  defp send_broadcast({nid, mod_info, tsks}, src, data) do
    {
      nid,
      mod_info
      |> Enum.map(fn listener ->
        send_event(listener, src, {:brod, data})
      end),
      tsks
    }
  end

  defp send_send({nid, mod_info, tsks}, src, to, data) do
    {
      nid,
      mod_info
      |> Enum.map(fn lis = {addr, _, _, _} ->
        case addr == to do
          false -> lis
          true -> send_event(lis, src, {:send, data})
        end
      end),
      tsks
    }
  end

  defp delay_action({id, mod_info, tsks}, name, ms, action, context) do
    with {from, _} <- context,
         {:ok, tsk} <- Task.start(fn -> do_delay_action(name, ms, {action, context}) end),
         # send notification that task can be cancelled
         :ok <- Event.send({:event, :delay_started}, {from, from}, {name, tsk}) do
      {
        id,
        mod_info,
        [tsk | tsks]
      }
    end
  end

  defp start_job(state, to, {func, args}, src) do
    Task.start(fn -> do_job({func, args}, to, src) end)
    state
  end

  defp cancel_delay({id, mod_info, tsks}, delay_id) do
    # this is possible because the "task id" we provide is just the task handle
    Task.shutdown(delay_id, 0)
    {id, mod_info, tsks |> Enum.filter(fn tsk -> tsk != delay_id end)}
  end

  defp do_delay_action(name, ms, {action, {from_id, channel}}) do
    L.d("#{inspect(name)}: delaying #{inspect(action)} by #{ms}ms")
    :timer.sleep(ms)

    L.d("#{inspect(name)}: executing #{inspect(action)}")

    norm_action(action, from_id)
    |> handle_response({from_id, channel})
    |> L.ins()
  end

  defp do_job({f, args}, to, {job_channel, name, from}) do
    # L.d("Running job[#{inspect(name)}]...")
    r = do_apply(f, args)
    L.d("Job[#{inspect(name)}] #{inspect(f)}(#{inspect(args)}) -> #{inspect(r, pretty: true)}")

    case to do
      :brod -> Event.broadcast({job_channel, name}, r)
      _ -> Event.send({job_channel, name}, {from, to}, r)
    end
  end

  # handle_event(ctx, event, state)
  #   where ctx is:
  #     {:brod, channel} # broadcast
  #     {:send, channel} # sent to your address
  #     :me # sent to your address by yourself
  #   where event is:
  #     {name, data}
  #   state is state

  defp send_event(lis = {mod_id, mod, mod_ch, last_state}, {ev_ch, name, from}, {type, data}) do
    # L.d("send_event(#{lis_s(lis)}, #{inspect({ev_ch, name, from})}, #{inspect({type, data})})")

    {
      mod_id,
      mod,
      mod_ch,
      with ctx <- make_context(type, ev_ch, from, mod_id),
           event <- {name, data} do
        try do
          mod.handle_event(ctx, event, last_state)
        rescue
          FunctionClauseError ->
            # last_state
            # |> L.ins(
            #   label: "#{lis_s(lis)} does not handle (#{inspect(ctx)}, #{inspect(event)}, state)"
            # )

            :ignore

          other ->
            L.e(
              "Unknown error when calling (#{inspect(ctx)}, #{inspect(event)}, state)
              on #{lis_s(lis)}: #{inspect(other)}"
            )

            :ignore
        end
        |> normalize_response({mod_id, last_state})
        |> do_responses({lis, ctx, event})
      end
    }
  end

  defp make_context(:send, channel, from, to) do
    case from == to do
      true -> {:send, :me}
      false -> {:send, channel}
    end
  end

  defp make_context(:brod, channel, _, _), do: {:brod, channel}

  defp normalize_response(:ignore, {_, last_state}), do: {:ignore, last_state}
  defp normalize_response({:ok, s}, _), do: {:ok, s}

  defp normalize_response({a, s}, info) when not is_list(a),
    do: normalize_response({[a], s}, info)

  defp normalize_response({a, s}, {my_id, _}) do
    # L.i("Final normalize_response: {#{inspect(a)}, s}")

    {
      Enum.map(
        a,
        fn a -> norm_action(a, my_id) end
      ),
      s
    }
  end

  defp norm_action(a = {:brod, _}, _), do: Tuple.append(a, nil)
  defp norm_action(a = {:brod, _, _}, _), do: a
  defp norm_action({:send, to, name}, my_id), do: {:send, to_addr(to, my_id), name, nil}
  defp norm_action({:send, to, name, data}, my_id), do: {:send, to_addr(to, my_id), name, data}
  defp norm_action({:in, name, ms, what}, _), do: {:delay, name, ms, what}
  defp norm_action({:job, to, name, f}, my_id), do: {:job, to_addr(to, my_id), name, f}

  defp to_addr(:brod, _), do: :brod
  defp to_addr(:me, my_id), do: my_id
  defp to_addr(other, _), do: other

  defp do_responses({:ignore, state}, _) do
    # L.d("#{lis_s(lis)}(#{inspect(ctx)},#{inspect(event)}) -> :ignore")
    state
  end

  defp do_responses({:ok, state}, {lis, ctx, event}) do
    L.ins(state, label: "#{lis_s(lis)}(#{inspect(ctx)},#{inspect(event)}) -> {:ok, ")
  end

  defp do_responses({action_list, state}, {lis, ctx, event}) do
    with {from, _mod, channel, _state} <- lis do
      logs = Enum.map(action_list, fn action -> handle_response(action, {from, channel}) end)
      L.d("#{lis_s(lis)}(#{inspect(ctx)},#{inspect(event)}) ->
{
#{Enum.join(logs, "\n")},
#{inspect(state, pretty: true)},
}")
      state
    end
  end

  #   {:brod, name, data \\ nil}
  #   {:send, to, name, data \\ nil} # to can be :me
  #   {:job, to, name, {function, args}} # to can be :me, :brod or addr
  #   {:in, ms, what} # what can be any action
  #   {:cancel, delay_id} # cancel a delay task

  defp handle_response({:brod, name, data}, {_, channel}) do
    # queue broadcast
    Event.broadcast({channel, name}, data)
    "broadcast] |#{inspect({channel, name})}|: #{inspect(data)})"
  end

  defp handle_response({:send, to, name, data}, {from, channel}) do
    # queue broadcast
    Event.send({channel, name}, {from, to}, data)
    "send] |#{inspect({channel, name})}| #{inspect(from)} -> #{inspect(to)}: #{inspect(data)})"
  end

  defp handle_response({:job, to, name, {func, args}}, {from, _}) do
    Event.job(name, {from, to}, func, args)
    "starting job] #{inspect({name})} for #{inspect(to)}: #{inspect(func)}(#{inspect(args)}))"
  end

  defp handle_response({:delay, name, ms, action}, ctx) do
    delay(name, ms, action, ctx)
    "delay] #{inspect(name)} in #{ms}ms: #{inspect(action)})"
  end

  defp handle_response({:cancel, delay_id}, _) do
    cancel_delay(delay_id)
    "cancelling] delay #{delay_id}"
  end

  defp handle_response({unknown, state}, channel) do
    L.ins(unknown, label: "handle_response unknown argument from #{inspect(channel)}")
    state
  end

  ########################
  ### Helpers ############
  ########################

  defp find_addr(s, addr) do
    # {next_id, listeners, tasks}
    s
    |> elem(1)
    |> Enum.reduce_while(
      {:error, "Could not find id #{inspect(addr)}"},
      # {id, elixir_module, channel, state}
      fn lis = {id, _, _, _}, def_result ->
        if id == addr do
          {:halt, {:ok, lis}}
        else
          {:cont, def_result}
        end
      end
    )
  end

  defp do_apply(f, args) when is_list(args), do: apply(f, args)
  defp do_apply(f, arg), do: apply(f, [arg])

  defp lis_s({m_id, _mod, m_ch, _last_state}), do: "#{m_ch}[#{m_id}]"
end
