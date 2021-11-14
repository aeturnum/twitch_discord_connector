defmodule TwitchDiscordConnector.Util.Live do
  use GenServer

  alias TwitchDiscordConnector.Util.L

  @name Live
  @live "https://twitch.naturecultur.es/live"

  @spec get_ref() :: binary()
  def get_ref() do
    GenServer.call(@name, :ref)
  end

  @spec is_live() :: boolean()
  def is_live() do
    GenServer.call(@name, :live)
  end

  # handle cast / call

  def handle_call(:ref, _from, {ref, live}), do: {:reply, ref, {ref, live}}

  def handle_call(:live, _from, {ref, nil}) do
    with live <- check_live(ref) do
      if live == false do
        L.w("!!!!Server is not live!!!!")
      end
      {:reply, live, {ref, live}}
    end
  end
  def handle_call(:live, _from, {ref, live}), do: {:reply, live, {ref, live}}

  def handle_call(any, _from, state) do
    IO.puts("Twitch.Bot: unexpected call: #{inspect(any)}")
    {:reply, :ok, state}
  end

  def handle_cast(any, state) do
    IO.puts("Twitch.Bot: unexpected cast: #{inspect(any)}")
    {:noreply, state}
  end


  # work functions
  defp check_live(ref) do
    case HTTPoison.get(@live) do
      {:ok, %{body: maybe_ref}} -> maybe_ref == ref
      {:error, _} ->
        false
    end
  end


  # process functions
  def init(_opts), do: {:ok, {make_ref() |> :erlang.ref_to_list() |> List.to_string(), nil}}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
end
