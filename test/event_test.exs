defmodule TwitchDiscordConnectorTest.Event do
  use ExUnit.Case

  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Util.L

  defmodule TestEventModule do
    def init(arg), do: arg

    def channel(), do: :test_event_module

    # def handle_event({:event, :added, _}, state) do
    #   choose_response(:added, state)
    # end

    # def handle_event({:test_event_module, :test, _}, state) do
    #   choose_response(:test, state)
    # end

    def handle_event({_, event, _}, route, state) do
      L.ins(route, label: "route")
      choose_response(event, state)
    end

    def choose_response(event, state) do
      {
        Enum.reduce(state, :ok, fn {expected_event, response}, def_response ->
          case expected_event == event do
            true -> response
            false -> def_response
          end
        end),
        state
      }
    end

    # def handle_event(info, state) do
    #   L.ins(info, label: "event info")
    #   # L.ins(state, label: "state")
    #   {:ok, state |> L.ins(label: "state")}
    # end
  end

  test "add" do
    Event.add_module(
      TestEventModule,
      [
        {:added, {:emit, :test, []}},
        {:blah, {:delay, 100, :done, []}}
      ]
    )

    Event.emit(:blah, -1, :blah)
    :timer.sleep(300)
  end
end
