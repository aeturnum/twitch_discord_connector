defmodule TwitchDiscordConnector.Event.Module do
  alias TwitchDiscordConnector.Util.L

  use Stenotype

  defstruct elixir_module: nil, channel: :unset, state: %{}, id: :unset, status: :created

  @type event_addr :: integer() | atom()
  @type event_type :: :send | :brod
  @type send_event :: {type :: event_type(), data :: any()}
  @type event_data :: {name :: event_addr(), data :: any()}
  @type source :: {channel :: atom(), name :: atom(), from :: event_addr()}
  @type status :: :created | :running
  @type t :: %__MODULE__{
          elixir_module: module(),
          channel: atom(),
          state: map() | list(),
          id: integer(),
          status: status()
        }

  # @init_name :added
  @status_created :created
  @status_running :running

  def new(id, {module, init_arg}) do
    %__MODULE__{
      id: id,
      elixir_module: module,
      channel: module.channel(),
      state: module.init(init_arg),
      status: @status_created
    }
  end

  @spec send_event(t(), source(), event_data()) :: {t(), list()}
  def send_event(module, {ev_ch, name, from}, {type, data}) do
    ctx = make_context(type, ev_ch, from, module.id)
    event = {name, data}

    module
    |> call_handle_event(ctx, event)
    |> log_result(ctx, event, module)
    |> normalize_response(module)
    |> update_status(name)
  end

  defp call_handle_event(module, context, event) do
    try do
      module.elixir_module.handle_event(context, event, module.state)
    rescue
      FunctionClauseError ->
        # last_state
        # |> L.ins(
        #   label: "#{module} does not handle (#{inspect(context)}, #{inspect(event)}, state)"
        # )

        :ignore

      other ->
        error("Unknown error when calling (#{inspect(context)}, #{inspect(event)}, state)
          on #{module}: #{L.to_s(other)}")

        :ignore
    end
  end

  defp make_context(:send, channel, from, to) do
    if from == to do
      {:send, :me}
    else
      {:send, channel}
    end
  end

  defp make_context(:brod, channel, _, _), do: {:brod, channel}

  defp update_status({module = %{status: :created}, actions}, :added) do
    {%{module | status: @status_running}, actions}
  end

  defp update_status(arg, _), do: arg

  defp log_result(result, ctx, event, module) do
    label = "Mod[#{to_s(module.elixir_module)}] handle_event(#{to_s(ctx)}, #{to_s(event)}, state)"

    case result do
      :ignore ->
        debug(label <> " -> :ignore")

      {:ok, s} ->
        debug([label, "State: #{to_s(s)}"])

      {acts, s} ->
        debug([label, "State: #{to_s(s)}", "Actions:"] ++ acts)
    end

    result
  end

  defp normalize_response(:ignore, module), do: {module, []}
  defp normalize_response({:ok, s}, module), do: {%{module | state: s}, []}

  # defp normalize_response({a, s}, info) when not is_list(a),
  #   do: normalize_response({[a], s}, info)

  defp normalize_response({acts, s}, module) do
    # L.i("Final normalize_response: {#{inspect(a)}, s}")

    {
      %{module | state: s},
      acts
      |> List.wrap()
      |> Enum.map(fn a -> norm_action(a, module.id) end)
    }
  end

  def norm_action(a = {:brod, _}, _), do: Tuple.append(a, nil)
  def norm_action(a = {:brod, _, _}, _), do: a
  def norm_action({:send, to, name}, my_id), do: {:send, to_addr(to, my_id), name, nil}
  def norm_action({:send, to, name, data}, my_id), do: {:send, to_addr(to, my_id), name, data}
  def norm_action({:in, ms, what}, _), do: {:delay, :unnamed, ms, what}
  def norm_action({:in, name, ms, what}, _), do: {:delay, name, ms, what}
  def norm_action({:job, to, name, f}, my_id), do: {:job, to_addr(to, my_id), name, f}

  defp to_addr(:brod, _), do: :brod
  defp to_addr(:me, my_id), do: my_id
  defp to_addr(other, _), do: other
end

defimpl String.Chars, for: TwitchDiscordConnector.Event.Module do
  def to_string(module) do
    "#{module.channel}[#{module.id}]"
  end
end
