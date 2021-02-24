defmodule TwitchDiscordConnector.Template.SrcCall do
  @derive [Poison.Encoder]
  defstruct src: "", args: [], keys: []

  alias TwitchDiscordConnector.Template.SrcCall
  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Util.H
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
      args: ensure_list(args),
      keys: ensure_list(keys)
    }
  end

  def new(s, args, keys) when is_binary(s) do
    %SrcCall{
      src: SrcServer.load(s),
      args: ensure_list(args),
      keys: ensure_list(keys)
    }
  end

  defp ensure_list(l) when is_list(l), do: l
  defp ensure_list(l), do: [l]

  def glyph(s = %SrcCall{}) do
    with args <- Enum.map(s.args, &L.to_s/1),
         arg_str <- Enum.join(args, ",") do
      "#{s.src.path}(#{arg_str})"
    end
  end

  # def glyph(o) do
  #   case Enumerable.impl_for(o) do
  #     nil ->
  #       case String.Chars.impl_for(o) do
  #         nil -> "#{inspect(o)}"
  #         _ -> "#{o}"
  #       end

  #     _ ->
  #       with args <- Enum.map(o, &glyph/1),
  #            arg_str <- Enum.join(args, ",") do
  #         arg_str
  #       end
  #   end
  # end

  def task(sc = %SrcCall{}, results) do
    with args <- Enum.map(sc.args, fn arg -> replace_arg(arg, results) end) do
      Task.async(fn -> {glyph(sc), Src.call(sc.src, args)} end)
    end
  end

  def replace_arg(sc = %SrcCall{}, results), do: resolve_call(sc, results)
  def replace_arg(o, _), do: o

  # def call(s = %SrcCall{}) do
  #   with result <- Src.call(s.src, s.args) do
  #     case s.keys do
  #       [] ->
  #         result

  #       _ ->
  #         Enum.reduce(s.keys, result, fn key, i_result ->
  #           i_result[key]
  #         end)
  #     end
  #   end
  # end

  def depends_on(s = %SrcCall{}) do
    # L.d("depends_on(#{s})")

    Enum.reduce(s.args, [], fn
      sc = %SrcCall{}, deps ->
        with {count, arg_deps} <- depends_on(sc) do
          [{1 + count, SrcCall.glyph(sc), arg_deps} | deps]
        end

      _, deps ->
        deps
    end)
    |> case do
      [] ->
        {0, []}

      dep_list ->
        Enum.reduce(dep_list, {1, dep_list}, fn {count, _, _}, {t_max, list} ->
          {max(count, t_max), list}
        end)
    end
  end

  def maybe_wrap(node) do
    H.walk_map(node, fn
      node = %{"src" => s, "args" => _, "keys" => _} ->
        # L.d("maybe_wrap(node) -> replacing #{L.to_s(node)}!")

        case SrcServer.exists?(s) do
          false ->
            with json_node <- Poison.encode!(node) do
              SrcCall.new(@unwrap, [json_node])
            end

          true ->
            node
        end

      x ->
        x
    end)
  end

  def load_src_calls(map) do
    H.walk_map(map, fn
      %{"src" => s, "args" => args, "keys" => keys} -> SrcCall.new(SrcServer.load(s), args, keys)
      x -> x
    end)
  end

  def resolve_call(call = %SrcCall{}, call_results) do
    # L.d("resolve_call(#{call})")

    with our_result <- Map.get(call_results, SrcCall.glyph(call)) do
      try do
        case call.keys do
          [] ->
            our_result

          k ->
            # L.d("get_in(#{inspect(our_result)}, #{inspect(k)})")
            get_in(our_result, k)
        end
      rescue
        err ->
          L.e("Call #{call} couldn't keys from #{inspect(our_result)} : #{inspect(err)}")

          nil
      end
    end
  end

  def replace_with_results(map, call_results) do
    H.walk_map(map, fn
      node = %SrcCall{} ->
        resolve_call(node, call_results)

      x ->
        x
    end)
  end

  defimpl Poison.Encoder, for: SrcCall do
    def encode(%{src: s, args: args, keys: keys}, options) do
      Poison.encode!(%{src: s.path, args: args, keys: keys}, options)
    end
  end

  defimpl String.Chars, for: SrcCall do
    def to_string(s), do: "sCall{#{SrcCall.glyph(s)}}#{keys(s.keys)}"
    def keys([]), do: ""
    def keys(o), do: ".#{L.to_s(o)}"
  end
end
