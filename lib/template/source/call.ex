defmodule TwitchDiscordConnector.Template.SrcCall do
  @derive [Poison.Encoder]
  defstruct src: "", args: [], keys: []

  alias TwitchDiscordConnector.Template.SrcCall
  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Template.SrcServer

  def unwrap(text) do
    Poison.decode!(text)
  end

  @unwrap Src.new(
            "template.unwrap",
            "Builtin function to handle JSON objects with identical keys to our template format",
            "{}",
            &SrcCall.unwrap/1,
            false
          )

  def new(path, args, keys \\ [])

  def new(s = %Src{}, args, keys) do
    %SrcCall{
      src: s,
      args: args,
      keys: keys
    }
  end

  def new(s, args, keys) when is_binary(s) do
    %SrcCall{
      src: SrcServer.load(s),
      args: args,
      keys: keys
    }
  end

  def call(s = %SrcCall{}) do
    with result <- Src.call(s.src, s.args) do
      case s.keys do
        [] ->
          result

        _ ->
          Enum.reduce(s.keys, result, fn key, i_result ->
            i_result[key]
          end)
      end
    end
  end

  def maybe_wrap(node = %{"src" => s, "args" => _, "keys" => _}) do
    case SrcServer.exists?(s) do
      false ->
        with json_node <- Poison.encode!(node) do
          SrcCall.new(@unwrap, [json_node])
        end

      true ->
        node
    end
  end

  def maybe_wrap(node = %SrcCall{}), do: node

  def maybe_wrap(node) when is_map(node) do
    Enum.reduce(
      node,
      %{},
      fn {key, sub_node}, new_map ->
        Map.put(new_map, key, maybe_wrap(sub_node))
      end
    )
  end

  def maybe_wrap(node), do: node

  def load_src_calls(%{"src" => s, "args" => args, "keys" => keys}) do
    SrcCall.new(SrcServer.load(s), args, keys)
  end

  def load_src_calls(map = %{}) do
    Enum.reduce(map, %{}, fn {key, node}, new_map ->
      Map.put(new_map, key, load_src_calls(node))
    end)
  end

  def load_src_calls(non_map), do: non_map

  def replace_with_results(node = %SrcCall{}, call_results) do
    # go through the nested keys
    Enum.reduce(
      node.keys,
      call_results[node.src.path],
      fn next_key, intermediate -> intermediate[next_key] end
    )
  end

  def replace_with_results(map = %{}, call_results) do
    Enum.reduce(map, %{}, fn {key, node}, new_map ->
      Map.put(new_map, key, replace_with_results(node, call_results))
    end)
  end

  def replace_with_results(node, _), do: node

  defimpl Poison.Encoder, for: SrcCall do
    def encode(%{src: s, args: args, keys: keys}, options) do
      Poison.encode!(%{src: s.path, args: args, keys: keys}, options)
    end
  end

  defimpl String.Chars, for: SrcCall do
    def to_string(s), do: "sCall:#{s.src}(#{inspect(s.args)}).#{inspect(s.keys)}"
  end
end
