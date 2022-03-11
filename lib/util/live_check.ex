defmodule TwitchDiscordConnector.Util.Live do
  use GenServer

  alias TwitchDiscordConnector.Util.L

  @name Live
  @live "https://twitch.naturecultur.es/live"
  @ref make_ref() |> :erlang.ref_to_list() |> List.to_string()

  @spec get_ref() :: binary()
  def get_ref() do
    L.d("Starting get_ref...")

    @ref
    |> L.ins(label: "Ending get_ref...")
  end

  @spec is_live() :: boolean()
  def is_live() do
    L.d("Starting is_live...")

    GenServer.call(@name, :live)
    |> L.ins(label: "Ending is_live...")
  end

  # handle cast / call

  # def handle_call(:ref, _from, {ref, live}), do: {:reply, ref, {ref, live}}

  def handle_call(:live, _from, nil) do
    with live <- check_live() do
      if live == false do
        L.w("!!!!Server is not live!!!!")
      end

      {:reply, live, live}
    end
  end

  def handle_call(:live, _from, live), do: {:reply, live, live}

  def handle_call(any, _from, state) do
    IO.puts("Twitch.Bot: unexpected call: #{inspect(any)}")
    {:reply, :ok, state}
  end

  def handle_cast(any, state) do
    IO.puts("Twitch.Bot: unexpected cast: #{inspect(any)}")
    {:noreply, state}
  end

  # work functions
  defp check_live() do
    case HTTPoison.get(@live) do
      {:ok, %{body: maybe_ref}} ->
        maybe_ref == @ref

      {:error, _} ->
        false
    end
    |> L.ins(label: "check_live(#{inspect(@ref)}})")
  end

  # process functions
  def init(_opts), do: {:ok, nil}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
end
