defmodule TwitchDiscordConnectorTest.Event do
  use ExUnit.Case

  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Util.L

  def call_map(kwargs) do
    [:type, :channel, :name, :data]
    |> Enum.reduce(%{}, fn kw, map ->
      case Keyword.get(kwargs, kw, nil) do
        nil -> map
        value -> Map.put(map, kw, value)
      end
    end)
  end

  def act_map(action, save, prev), do: %{action: action, sto: save, prev: prev}
  def act_map(action, save), do: %{action: action, sto: save}

  #############################
  ### Testing State Machine ###
  #############################

  defmodule TestEventModule do
    def init(instructions), do: %{ins: instructions, sto: nil, calls: []}

    def channel(), do: :test_event_module

    # handle_event(ctx, event, state)
    def handle_event({type, channel}, {name, data}, state) do
      # IO.puts("handle_event(#{inspect({name, data})})")

      choose_response(
        TwitchDiscordConnectorTest.Event.call_map(
          type: type,
          channel: channel,
          name: name,
          data: data
        ),
        state
      )
    end

    def choose_response(_, s = %{sto: {:failure, _}}), do: {:ok, s}

    def choose_response(call_map, state) do
      with action <- match_call(state.ins, call_map),
           state_with_call <- %{state | calls: [call_map | state.calls]},
           success <- {action.action, %{state_with_call | sto: action.sto}} do
        case action do
          %{prev: p} ->
            case p == state.sto do
              true -> success
              false -> {:ok, %{state_with_call | sto: {:failure, state.sto}}}
            end

          %{} ->
            success
        end
      end
    end

    def make_states(state, action, call_map) do
      with state_with_call <- %{state | calls: [call_map | state.calls]},
           fail_state <- {:ok, %{state_with_call | sto: {:failure, state.sto}}} do
        success_state =
          {action.action,
           %{
             state_with_call
             | sto:
                 case action.sto do
                   {:call_field, field} -> Map.get(call_map, field)
                   _ -> action.sto
                 end
           }}

        {fail_state, success_state}
      end
    end

    defp match_call(list, call_map) do
      case Enum.filter(list, fn {exp_call, _} -> map_subset?(call_map, exp_call) end) do
        [{_, action}] -> action
        [] -> %{action: :ok, sto: :not_found}
        other -> IO.puts("Unexpected result: #{other}")
      end
    end

    defp map_subset?(superset, subset) do
      Enum.all?(subset, fn {key, val} ->
        Map.get(superset, key, "#{inspect(val)}+") == val
      end)
    end
  end

  ################
  #### Tests #####
  ################

  test "broadcast" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {call_map(name: :added), act_map({:brod, :b_test}, :got_added)},
          {call_map(type: :brod, name: :b_test), act_map(:ok, :got_test)}
        ]
      )

    {:ok, final_state} = Event.get_state(mod_id)
    assert final_state.sto == :got_test
  end

  test "send" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {call_map(name: :added), act_map({:send, :me, :send_test}, :got_added)},
          {call_map(type: :send, name: :send_test), act_map(:ok, :got_send, :got_added)}
        ]
      )

    {:ok, final_state} = Event.get_state(mod_id)
    assert final_state.sto == :got_send
  end

  test "job" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {
            call_map(name: :added),
            act_map({:job, :me, :test_job, {&String.capitalize/1, ["a"]}}, :job_start)
          },
          {
            call_map(type: :send, channel: :me, name: :test_job, data: "A"),
            act_map(:ok, :job_done)
          }
        ]
      )

    :timer.sleep(50)
    {:ok, final_state} = Event.get_state(mod_id)
    assert final_state.sto == :job_done
  end

  test "delay" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {
            call_map(name: :added),
            act_map({:in, :wait, 100, {:brod, :delay_done}}, :delay_start)
          },
          {
            call_map(name: :delay_started, channel: :me),
            act_map(:ok, :got_id, :delay_start)
          },
          {
            call_map(type: :brod, name: :delay_done),
            act_map(:ok, :delay_done, :got_id)
          }
        ]
      )

    :timer.sleep(50)
    {:ok, intermediate_state} = Event.get_state(mod_id)
    assert intermediate_state.sto == :got_id

    :timer.sleep(70)
    {:ok, end_state} = Event.get_state(mod_id)
    # IO.inspect(end_state.calls, pretty: true)
    assert end_state.sto == :delay_done
  end

  # test "cancel delay" do
  #   {:ok, mod_id} =
  #     Event.add_listener(
  #       TestEventModule,
  #       [
  #         {
  #           call_map(name: :added),
  #           act_map({:in, 100, {:brod, :delay_done}}, :delay_start)
  #         },
  #         {
  #           call_map(name: :delay_started, channel: :me),
  #           act_map({:cancel, :dunno}, :got_id, :delay_start)
  #         },
  #         {
  #           call_map(type: :brod, name: :delay_done),
  #           act_map(:ok, :delay_done, :got_id)
  #         }
  #       ]
  #     )

  #   :timer.sleep(50)
  #   {:ok, intermediate_state} = Event.get_state(mod_id)
  #   assert intermediate_state.sto == :got_id

  #   :timer.sleep(70)
  #   {:ok, end_state} = Event.get_state(mod_id)
  #   IO.inspect(end_state.calls, pretty: true)
  #   assert end_state.sto == :delay_done
  # end

  test "communication" do
    {:ok, recver_id} =
      Event.add_listener(
        TestEventModule,
        [
          {
            call_map(type: :send, channel: :test_event_module, name: :ipc, data: "Hi"),
            act_map(:ok, :recvd)
          }
        ]
      )

    {:ok, sender_id} =
      Event.add_listener(
        TestEventModule,
        [
          {
            call_map(name: :added),
            act_map({:send, recver_id, :ipc, "Hi"}, :sent)
          }
        ]
      )

    :timer.sleep(50)
    {:ok, sender_state} = Event.get_state(sender_id)
    {:ok, recvr_state} = Event.get_state(recver_id)
    assert sender_state.sto == :sent
    assert recvr_state.sto == :recvd
  end

  test "getting lost" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {call_map(name: :added), act_map({:brod, :lost}, :got_added)},
          {call_map(type: :send, name: :lost), act_map(:ok, :got_lost)}
        ]
      )

    # Event.emit(:blah, -1, :blah)
    # :timer.sleep(300)

    {:ok, final_state} = Event.get_state(mod_id)
    assert final_state.sto == :not_found
  end

  test "failure" do
    {:ok, mod_id} =
      Event.add_listener(
        TestEventModule,
        [
          {call_map(name: :added), act_map({:brod, :lost}, :got_added, :notexist)}
        ]
      )

    # Event.emit(:blah, -1, :blah)
    # :timer.sleep(300)

    {:ok, final_state} = Event.get_state(mod_id)

    assert final_state.sto == {:failure, nil}
    assert final_state.calls == [%{channel: :event, data: %{}, name: :added, type: :send}]
  end
end
