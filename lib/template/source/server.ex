defmodule TwitchDiscordConnector.Template.SrcServer do
  @name TemplateSrcServer
  use GenServer

  use Stenotype

  # alias TwitchDiscordConnector.Util.L

  def register(src = %{path: path}) do
    GenServer.cast(@name, {:register, path, src})

    info("Source #{path} registered!")
    src
  end

  def exists?(path) do
    GenServer.call(@name, {:exists, path})
  end

  def list(public_only \\ false) do
    GenServer.call(@name, {:list, public_only})
  end

  def load(path) do
    GenServer.call(@name, {:load, path})
    # |> IO.inspect(label: "load #{path}?:")
  end

  # stubs to log if we get an unexpected call

  def terminate(reason, state) do
    IO.puts("SrcServer.terminate - #{inspect(reason)}, #{inspect(state)}")
  end

  def handle_cast({:register, path, src}, state) do
    case Map.has_key?(state, path) do
      true -> raise RuntimeError, message: "Duplicate Src registered for path '#{path}': #{src}"
      _ -> {:noreply, Map.put(state, path, src)}
    end
  end

  def handle_cast(arg, state) do
    IO.puts("SrcServer.handle_cast - #{inspect(arg)}, #{inspect(state)}")
    {:noreply, state}
  end

  def handle_call({:list, public_only}, _from, state) do
    {
      :reply,
      Map.values(state)
      |> Enum.filter(fn src ->
        if public_only do
          src.public
        else
          true
        end
      end),
      state
    }
  end

  def handle_call({:load, path}, _from, state) do
    {:reply, Map.get(state, path), state}
  end

  def handle_call({:exists, path}, _from, state) do
    {:reply, Map.has_key?(state, path), state}
  end

  # def handle_call(arg, _from, state) do
  #   IO.puts("SrcServer: Unexpected handle_call: #{inspect(arg)}")
  #   {:reply, nil, state}
  # end

  def handle_info(msg, state) do
    IO.puts("SrcServer.handle_info: #{inspect(self())} #{inspect(msg)}")
    {:noreply, state}
  end

  # loading code

  def start_link(modules) do
    GenServer.start_link(__MODULE__, modules, name: @name)
  end

  def init(_) do
    {:ok, %{}}
  end
end
