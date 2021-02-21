defmodule TwitchDiscordConnector.Util.L do
  @moduledoc """
  Logging helpers

  Todo: expand significantly and add lots of formatting options
  """
  require Logger
  # Process.info(self(), :current_stacktrace)

  defp do_log(line, f) do
    f.(line)

    # if Application.get_env(:twitch_discord_connector, :environment) == :test do
    #   IO.puts(line)
    # end

    line
  end

  # defp update_mod_vals(map, mod) do
  #   {_, result} =
  #     mod
  #     |> Atom.to_string()
  #     |> String.split(".")
  #     |> Enum.reduce(
  #       {[], map},
  #       fn
  #         "Elixir", {[], map} ->
  #           # don't insert implict elixir atoms
  #           {["Elixir"], map}

  #         next_part, {rev_list, map} ->
  #           # don't add anything for the first round
  #           with next_list <- [next_part | rev_list],
  #                this_atom <- next_list |> Enum.reverse() |> Enum.join(".") |> String.to_atom(),
  #                last_value <- Map.get(map, this_atom, 0) do
  #             {
  #               next_list,
  #               Map.put(map, this_atom, last_value + 1)
  #             }
  #           end
  #       end
  #     )

  # defp split_mod(mod), do: mod |> Atom.to_string() |> String.split(".")

  # defp update_stack_height() do
  #   with base <- base_mod(mod) do
  #   end
  # end

  # defp stack_structure(s) do
  #   Enum.reduce(
  #     s |> IO.inspect(),
  #     %{stack_height: %{}},
  #     # {mod, atom_name, arity, [file: path, line: line]}
  #     fn l = {mod, _, _, [file: _path, line: _]}, meta ->
  #       %{meta | stack_height: update_mod_vals(meta.stack_height, mod)}
  #     end
  #   )
  #   |> IO.inspect()

  #   s
  # end

  # {Conmon.Service.UDPServer, :init, 1, [file: 'lib/Services/udpserver.ex', line: 20]}
  defp trace_line({mod, atom_name, arity, [file: _path, line: line]}),
    do: "    #{line}| #{mod}.#{atom_name}/#{arity}\n"

  defp loc_name({_, _atom_name, _, [file: path, line: line]}),
    do: "[#{Path.basename(path)}::#{line}]"

  defp stack() do
    with {_, list} <- Process.info(self(), :current_stacktrace) do
      # first stack is from Process
      list
      |> Enum.drop(1)
      |> Enum.filter(fn {mod, _, _, _} -> mod != __MODULE__ end)
    end
  end

  defp top_frame(), do: List.first(stack())

  def t(line \\ "") do
    with stack <- stack(),
         str_list <- Enum.map(stack, &trace_line/1),
         do: d("#{line}:#{str_list}")
  end

  defp loc_prefix, do: loc_name(top_frame())

  defp log_str(s), do: "#{loc_prefix()} #{s}"

  def d(s), do: do_log(log_str(s), &Logger.debug/1)
  def e(s), do: do_log(log_str(s), &Logger.error/1)
  def w(s), do: do_log(log_str(s), &Logger.warn/1)
  def i(s), do: do_log(log_str(s), &Logger.info/1)

  # todo: error
  def ins(obj, opts \\ []) do
    opts = to_ins_list(opts)

    "#{inspect(obj, Keyword.merge([pretty: true], opts))}"
    |> do_i_label(opts)
    |> do_i_prefix(opts)
    |> do_log(&Logger.debug/1)

    obj
  end

  defp to_ins_list(s) when is_binary(s), do: [label: s]
  defp to_ins_list(o) when is_list(o), do: o

  defp do_i_label(s, opts) do
    case Keyword.get(opts, :label, nil) do
      nil -> s
      label -> "#{label}: #{s}"
    end
  end

  defp do_i_prefix(s, _), do: log_str(s)
end
