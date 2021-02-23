defmodule TwitchDiscordConnector.Util.H do
  @moduledoc """
  Random Helpers
  """

  alias TwitchDiscordConnector.Util.L

  # https://stackoverflow.com/questions/32001606/how-to-generate-a-random-url-safe-string-with-elixir
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  def now(offset \\ 0), do: DateTime.now!("Etc/UTC") |> DateTime.add(offset, :second)

  def grab_keys(tgt, src, keys) do
    Enum.reduce(keys, tgt, fn key, acc -> Map.put(acc, key, Map.get(src, key, nil)) end)
  end

  def str(o) when is_binary(o), do: o
  def str(o) when is_integer(o), do: Integer.to_string(o)

  def walk_map(map, fun) do
    # L.d("walk_map/2 called: #{L.to_s(map)}, #{L.to_s(fun)}")
    {xform_map, nil} = walk_map(map, fun, nil)
    xform_map
  end

  def walk_map(map, fun, global_acc) do
    # L.d("walk_map(#{L.to_s(map)}, #{L.to_s(fun)}, #{L.to_s(global_acc)})")

    case visit_map_term(map, fun, global_acc) do
      # the function didn't change the term, so we can walk it
      {^map, new_global_acc} ->
        do_walk(map, fun, new_global_acc)

      # This clause means that the term was replaced and we shouldn't do a walk, we should just settle on this
      other ->
        other
    end
  end

  defp visit_map_term(term, fun, nil), do: {fun.(term), nil}
  defp visit_map_term(term, fun, acc), do: fun.(term, acc)

  defp do_walk(cont, _, global_acc) when is_struct(cont), do: {cont, global_acc}

  defp do_walk(cont, fun, global_acc) when is_map(cont) or is_list(cont) or is_tuple(cont) do
    Enum.reduce(
      cont,
      {get_container(cont), global_acc},
      fn term, {new_container, g_acc} ->
        with next_val <- term_val(new_container, term),
             {new_val, new_g_acc} <- walk_map(next_val, fun, g_acc) do
          {pack_container(new_container, term, new_val), new_g_acc}
        end
      end
    )
  end

  defp do_walk(cont, _, global_acc), do: {cont, global_acc}

  defp get_container(c) when is_list(c), do: []
  defp get_container(c) when is_tuple(c), do: []
  defp get_container(c) when is_map(c), do: %{}

  defp term_val(cont, term) when is_list(cont), do: term
  defp term_val(cont, {_, val}) when is_map(cont), do: val

  defp pack_container(acc, {key, _}, new_val) when is_map(acc), do: Map.put(acc, key, new_val)
  defp pack_container(acc, _, new_val) when is_list(acc), do: acc ++ [new_val]
end
