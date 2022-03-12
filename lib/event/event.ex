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
  use Stenotype

  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Event.Module

  @name Event

  @type delay_atom :: :in | :delay
  @type f_call() :: {fun(), list()}
  @type addr() :: integer() | :me
  # @type action() ::
  #         {:brod, atom(), any()}
  #         | {:send, addr(), atom(), any()}
  #         | {:job, addr(), atom(), f_call()}
  #         | {delay_atom(), integer(), action()}
  #         | {:cancel, integer()}
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

  @doc """
  Set the run level of the internal vm.`

  Returns `{:ok, listener_id}`
  """
  @spec set_run_level(integer()) :: :ok
  def set_run_level(level) do
    GenServer.call(@name, {:set_run_level, level})
  end

  ########################
  ### Init ###############
  ########################

  def start_link(modules) do
    GenServer.start_link(__MODULE__, modules, name: @name)
  end

  @type name :: binary() | atom()
  @type data :: any()
  @type address :: atom() | integer()
  @type func :: {fun(), list(any())}

  @type broadcast :: {:brod, name()} | {:brod, name(), data()}
  # `to` can be :me or addr
  @type send :: {:send, address(), name(), data()} | {:send, address(), name()}
  # `to` can be :me, :brod or addr
  @type job :: {:job, address(), name(), func()}
  # what can be any action
  @type delay :: {:in, integer(), action()}
  # cancel a delay task
  @type cancel :: {:cancel, integer()}

  @type action :: broadcast() | send() | job() | delay() | cancel()

  @rl_halt :halt
  @rl_running :running

  @type state :: %{
          run_level: atom(),
          # next id for new modules
          next_id: integer(),
          # modules who are getting notified of events
          listeners: list(Module.t()),
          # unfinished tasks
          tasks: list(Task.t()),
          # actions to be executed
          action_queue: list(action())
        }

  def init(modules) do
    {
      :ok,
      make_start_state(modules)
    }
  end

  defp make_start_state(modules) do
    mod_and_args = Enum.map(modules, &to_mod_and_args/1)

    state = %{
      run_level: @rl_halt,
      next_id: 0,
      listeners: [],
      tasks: [],
      action_queue: []
    }

    Enum.reduce(
      mod_and_args,
      state,
      &add_mod_as_listener/2
    )
  end

  defp to_mod_and_args({mod, arg}), do: {mod, arg}
  defp to_mod_and_args(mod), do: {mod, []}

  defp add_mod_as_listener({mod, arg}, state) do
    module = Module.new(state.next_id, {mod, arg})
    debug("[Event] Added #{module} with Module #{inspect(mod)}")

    module =
      case state.run_level do
        :halt ->
          module

        _ ->
          initialize_module(module)
      end

    %{state_inc_id(state) | listeners: [module | state.listeners]}
  end

  defp initialize_module(module = %{status: :created}) do
    send_event(module, {:event, :added, :event}, {:send, %{}})
    # |> L.ins(label: "[Event] initialize_module(#{ins(module)})")
  end

  defp initialize_module(module), do: module

  ########################
  ### Handles ############
  ########################

  @spec handle_call(any(), any(), state()) :: {:reply, any(), state()}
  def handle_call({:add_lis, module, init_arg}, _from, state) do
    # todo: maybe init?
    new_state = add_mod_as_listener({module, init_arg}, state)
    {:reply, {:ok, new_state.next_id}, new_state}
  end

  def handle_call({:get_state, addr}, _from, s) do
    with {:ok, listener} <- find_addr(s, addr) do
      {:reply, {:ok, elem(listener, 3)}, s}
    end
  end

  # this doesn't handle unexpected transitions but it's fine
  def handle_call({:set_run_level, 0}, _from, s) do
    {:reply, :ok, %{s | run_level: 0}}
  end

  def handle_call({:set_run_level, 1}, _from, s) do
    s = %{s | run_level: 1}
    s = %{s | listeners: Enum.map(s.listeners, &initialize_module/1)}

    s =
      Enum.reduce(
        s.action_queue,
        s,
        fn action, state ->
          info("[Event] processing action: #{to_s(action)}")
          process_action(action, state)
        end
      )

    {:reply, :ok, %{s | action_queue: []}}
  end

  def handle_call(info, _from, state) do
    error("[Event] unexpected call: #{inspect(info)}")
    {:reply, nil, state}
  end

  def handle_cast(action?, state) do
    {:noreply,
     case action_type(action?) do
       :unknown ->
         error("Manager: unexpected cast: #{inspect(action?)}")
         state

       _ ->
         process_action(action?, state)
     end}
  end

  # todo: add shutdown event

  defp action_type({{:brod, _data}, _src}), do: :brod
  defp action_type({{:send, _to, _data}, _src}), do: :send
  defp action_type({:delay, _name, _ms, _action, _context}), do: :delay
  defp action_type({{:job, _to, _func, _args}, _src}), do: :job
  defp action_type({:cancel_delay, _delay_id}), do: :cancel
  defp action_type(_), do: :unknown

  defp process_action(action, state = %{run_level: rl}) do
    if rl < 1 do
      #
      %{state | action_queue: state.actions ++ [action]}
    else
      case action do
        {{:brod, data}, src} ->
          send_broadcast(state, src, data)

        {{:send, to, data}, src} ->
          send_send(state, src, to, data)

        {:delay, name, ms, action, context} ->
          delay_action(state, name, ms, action, context)

        {{:job, to, func, args}, src} ->
          start_job(state, to, {func, args}, src)

        {:cancel_delay, delay_id} ->
          cancel_delay(state, delay_id)
      end

      # |> L.ins(label: "[Event] executing action #{inspect(action)}")
    end
  end

  #######################
  ### Doers #############
  #######################

  defp send_broadcast(state, src, data) do
    Map.update!(state, :listeners, fn listeners ->
      Enum.map(
        listeners,
        fn listener ->
          send_event(listener, src, {:brod, data})
        end
      )
    end)
  end

  defp send_send(state, src, to, data) do
    Map.update!(state, :listeners, fn listeners ->
      Enum.map(
        listeners,
        fn
          mod = %{id: addr} when addr == to ->
            send_event(mod, src, {:send, data})

          mod ->
            mod
        end
      )
    end)
  end

  defp delay_action(state = %{tasks: tsks}, name, ms, action, context) do
    with {from, _} <- context,
         {:ok, tsk} <- Task.start(fn -> do_delay_action(name, ms, {action, context}) end),
         # send notification that task can be cancelled
         :ok <- Event.send({:event, :delay_started}, {from, from}, {name, tsk}) do
      %{state | tasks: [tsk | tsks]}
    end
  end

  defp start_job(state, to, {func, args}, src) do
    Task.start(fn -> do_job({func, args}, to, src) end)
    state
  end

  defp cancel_delay(state = %{tasks: tsks}, delay_id) do
    # this is possible because the "task id" we provide is just the task handle
    Task.shutdown(delay_id, 0)
    %{state | tasks: Enum.filter(tsks, fn tsk -> tsk != delay_id end)}
    # {id, mod_info, tsks |> Enum.filter(fn tsk -> tsk != delay_id end)}
  end

  defp do_delay_action(name, ms, {action, {from_id, channel}}) do
    debug("#{to_s(name)}: delaying #{to_s(action)} by #{ms}ms")
    :timer.sleep(ms)

    debug("#{to_s(name)}: executing #{to_s(action)}")

    Module.norm_action(action, from_id)
    |> handle_action({from_id, channel})
    |> L.ins()
  end

  defp do_job({f, args}, to, {job_channel, name, from}) do
    debug("Running job[#{to_s(name)}]...")
    r = do_apply(f, args)
    debug("Job[#{to_s(name)}] #{to_s(f)}(#{to_s(args)}) -> #{to_s(r)}")

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

  @spec send_event(Module.t(), Module.source(), Module.event_data()) :: Module.t()
  defp send_event(module, src, event_data) do
    # L.d("send_event(#{lis_s(lis)}, #{inspect({ev_ch, name, from})}, #{inspect({type, data})})")

    {new_module, actions} = Module.send_event(module, src, event_data)
    # side effects!
    do_responses(actions, new_module)
    new_module
  end

  defp do_responses([], _), do: :ok

  defp do_responses(action_list, actor) do
    logs =
      Enum.map(action_list, fn action -> handle_action(action, {actor.id, actor.channel}) end)

    debug([
      "#{actor}() ->",
      "{",
      "#{Enum.join(logs, "\n")},",
      "#{to_s(actor.state)},",
      "}"
    ])

    :ok
  end

  #   {:brod, name, data \\ nil}
  #   {:send, to, name, data \\ nil} # to can be :me
  #   {:job, to, name, {function, args}} # to can be :me, :brod or addr
  #   {:in, ms, what} # what can be any action
  #   {:cancel, delay_id} # cancel a delay task

  defp handle_action({:brod, name, data}, {_, channel}) do
    # queue broadcast
    Event.broadcast({channel, name}, data)
    "broadcast] |#{to_s({channel, name})}|: #{to_s(data)})"
  end

  defp handle_action({:send, to, name, data}, {from, channel}) do
    # queue broadcast
    Event.send({channel, name}, {from, to}, data)
    "send] |#{to_s({channel, name})}| #{to_s(from)} -> #{to_s(to)}: #{to_s(data)})"
  end

  defp handle_action({:job, to, name, {func, args}}, {from, _}) do
    Event.job(name, {from, to}, func, args)
    "starting job] #{to_s({name})} for #{to_s(to)}: #{to_s(func)}(#{to_s(args)}))"
  end

  defp handle_action({:delay, name, ms, action}, ctx) do
    delay(name, ms, action, ctx)
    "delay] #{to_s(name)} in #{ms}ms: #{to_s(action)})"
  end

  defp handle_action({:cancel, delay_id}, _) do
    cancel_delay(delay_id)
    "cancelling] delay #{delay_id}"
  end

  defp handle_action({unknown, state}, channel) do
    L.ins(unknown, label: "handle_action unknown argument from #{inspect(channel)}")
    state
  end

  ########################
  ### Helpers ############
  ########################

  @spec state_inc_id(state()) :: state()
  defp state_inc_id(s = %{next_id: nid}), do: %{s | next_id: nid + 1}

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

  defp ins(o), do: inspect(o, pretty: true)

  # defp lis_s({m_id, _mod, m_ch, _last_state}), do: "#{m_ch}[#{m_id}]"
end
