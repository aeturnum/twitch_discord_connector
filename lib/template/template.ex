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
  alias TwitchDiscordConnector.Template

  @task_timeout 5000

  def load_calls(template), do: SrcCall.maybe_wrap(template)

  def resolve(template), do: SrcCall.maybe_wrap(template) |> do_resolve()

  def check(template), do: validate(template)

  defp validate(template) do
    SrcCall.maybe_wrap(template)
    :ok
  end

  defp do_resolve(template) do
    with calls <- collect_calls(template) |> L.ins_("collect calls"),
         call_map <- find_dependencies(calls) |> L.ins("dependencies"),
         # todo: add dependency graph for calls
         results <- do_calls(call_map) |> L.ins("results") do
      SrcCall.replace_with_results(template, results)
    end
  end

  defp collect_result({task, result}, results) do
    L.d("Checking task: #{inspect(result)}")

    case result do
      nil ->
        L.e("Task timed out!")
        Task.shutdown(task, :brutal_kill)
        results

      {:exit, reason} ->
        L.e("Task failed: #{inspect(reason)}")
        results

      {:ok, {name, {code, value}}} ->
        case code do
          :ok ->
            value =
              case value do
                # atomception
                {:ok, real_value} -> real_value
                _ -> value
              end

            Map.put(results, name, value)

          :error ->
            L.e("Task #{name} succeded but had internal error: #{inspect(value)}")
            results
        end
    end
  end

  defp do_calls(call_map, prev_results \\ %{}, level \\ 0) do
    case Map.has_key?(call_map, level) do
      true ->
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

      false ->
        prev_results
    end
  end

  defp find_dependencies(calls) do
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
    acc =
      Enum.reduce(s.args, acc, fn
        s = %SrcCall{}, acc -> [s | acc]
        _, acc -> acc
      end)

    {s, [s | acc]}
  end

  defp collect_call(s, acc), do: {s, acc}

  defp collect_calls(template) do
    H.walk_map(
      template,
      &collect_call/2,
      []
    )
    |> elem(1)
  end
end
