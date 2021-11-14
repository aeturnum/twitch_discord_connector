defmodule TwitchDiscordConnector.Template do
  @moduledoc """
  Module to fill in template values in JSON using psudo-RPC mechanisms.

  Designed to allow storing the template of the strucutre we want to send *with* a list of the values we're going to
  use from RPC calls.

  Major components include:
    - basic structure for noting where RPC values go
    - format for specifying supported RPC calls
  """

  # Sample
  # {
  #   "test rpc": {
  #     "src": "twitch.user.info",
  #     "args": ["35634557"],
  #     "keys": ["display_name"] # optional list of keys to traverse to get to final value
  #   },
  #   "rpc for object with src and args": {
  #     "src": "template.unwrap",
  #     "args": ["{\"src\": \"test\", \"args\": \"a non-rpc format\"}"],
  #   },
  # }

  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Util.H
  alias TwitchDiscordConnector.Template.SrcCall

  @task_timeout 5000

  def load_calls(template), do: SrcCall.maybe_wrap(template)

  def resolve(template), do: SrcCall.maybe_wrap(template) |> do_resolve()

  def check(template), do: validate(template)

  defp validate(template) do
    SrcCall.maybe_wrap(template)
    :ok
  end

  defp do_resolve(template) do
    with calls <- collect_calls(template),
         call_map <- order_by_dependency(calls),
         # todo: add dependency graph for calls
         results <- do_calls(call_map) |> L.ins("call results") do
      SrcCall.replace_with_results(template, results)
    end
  end

  @spec collect_result({Task.t(), map()}, map()) :: map()
  defp collect_result({task, nil}, results) do
        L.e("Task timed out!")
        Task.shutdown(task, :brutal_kill)
        results
  end

  defp collect_result({task, {:exit, reason}}, results) do
        L.e("Task failed: #{inspect(reason)}")
        results
  end

  defp collect_result({task, {:ok, {name, {:ok, value}}}}, results) do
        Map.put(results, name, H.unwrap?(value, :ok))
  end

  defp collect_result({task, {:ok, {name, {:error, value}}}}, results) do
        L.e("Task #{name} succeded but had internal error: #{inspect(value)}")
        results
  end

  @spec do_calls(map(), map(), non_neg_integer()) :: map()
  defp do_calls(call_map, prev_results \\ %{}, level \\ 0) do
    if Map.has_key?(call_map, level) do
      do_calls(
        call_map,
        call_map[level]
        # |> L.ins("map[#{level}]")
        |> Enum.map(fn {src_call, _} -> SrcCall.task(src_call, prev_results) end)
        # thank you https://stackoverflow.com/questions/42330425/how-to-await-multiple-tasks-in-elixir
        |> Task.yield_many(@task_timeout)
        |> Enum.reduce(prev_results, &collect_result/2),
        # |> L.ins("map[#{level}] results"),
        level + 1
      )
    else
      prev_results
    end
  end

  defp order_by_dependency(calls) do
    Enum.reduce(calls, %{}, fn src_call, deps ->
      with {degree, this_deps} <- SrcCall.depends_on(src_call),
           calls_at_this_degree <- Map.get(deps, degree, []) do
        Map.put(deps, degree, [
          {src_call, this_deps} | calls_at_this_degree
        ])
      end
    end)

    # |> L.ins("find_dependencies")
  end

  defp collect_call(s = %SrcCall{}, acc) do
    {s, [s | Enum.reduce(s.args, acc, fn arg, acc -> collect_call(arg, acc) |> elem(1) end)]}
  end

  defp collect_call(s, acc), do: {s, acc}

  defp collect_calls(template) do
    H.walk_map(template, &collect_call/2, [])
    |> elem(1)
  end
end
