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

  use GenServer
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Template.SrcCall
  alias TwitchDiscordConnector.Template

  @name Template
  @task_timeout 5000

  def check(template) do
    GenServer.call(@name, {:check, template})
  end

  def list() do
    GenServer.call(@name, :list)
  end

  def load_calls(template) do
    GenServer.call(@name, {:load, template})
  end

  def resolve(template) do
    GenServer.call(@name, {:resolve, template})
  end

  def terminate(reason, state) do
    IO.puts("SrcServer.terminate - #{inspect(reason)}, #{inspect(state)}")
  end

  def handle_cast(arg, state) do
    IO.puts("SrcServer.handle_cast - #{inspect(arg)}, #{inspect(state)}")
    {:noreply, state}
  end

  def handle_call({:load, template}, _from, state) do
    {:reply, SrcCall.maybe_wrap(template), state}
  end

  def handle_call({:resolve, template}, _from, state) do
    {:reply, SrcCall.maybe_wrap(template) |> do_resolve(), state}
  end

  def handle_call({:check, template}, _from, state) do
    {:reply, validate(template), state}
  end

  def handle_call(arg, _from, state) do
    IO.puts("SrcServer: Unexpected handle_call: #{inspect(arg)}")
    {:reply, nil, state}
  end

  def handle_info(msg, state) do
    IO.puts("SrcServer.handle_info: #{inspect(self())} #{inspect(msg)}")
    {:noreply, state}
  end

  defp validate(template) do
    SrcCall.maybe_wrap(template)
    :ok
  end

  defp do_resolve(template) do
    with calls <- collect_calls(template),
         results <- do_calls(calls) do
      SrcCall.replace_with_results(template, results)
    end
  end

  defp do_calls(calls) do
    calls
    |> Enum.map(fn src_call -> Src.task(src_call.src, src_call.args) end)
    # thank you https://stackoverflow.com/questions/42330425/how-to-await-multiple-tasks-in-elixir
    |> Task.yield_many(@task_timeout)
    |> Enum.reduce(%{}, fn {task, result}, results ->
      case result do
        nil ->
          L.e("Task timed out!")
          Task.shutdown(task, :brutal_kill)

        {:exit, reason} ->
          L.e("Task failed: #{inspect(reason)}")

        {:ok, {name, {code, value}}} ->
          case code do
            :ok ->
              Map.put(results, name, value)

            :error ->
              L.e("Task #{name} succeded but had internal error: #{inspect(value)}")
              results
          end
      end
    end)
  end

  defp collect_calls(template, calls \\ [])

  defp collect_calls(s = %SrcCall{}, calls), do: [s | calls]

  defp collect_calls(template = %{}, calls) do
    Enum.reduce(template, calls, fn
      {_, value}, list -> collect_calls(value, list)
    end)
  end

  defp collect_calls(_, calls), do: calls

  def init(_) do
    {
      :ok,
      # tasks
      []
    }
  end

  def start_link(modules) do
    GenServer.start_link(__MODULE__, modules, name: @name)
  end
end
