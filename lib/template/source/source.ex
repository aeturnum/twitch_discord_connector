defmodule TwitchDiscordConnector.Template.Src do
  @derive {Inspect, only: [:path, :module, :function]}
  defstruct path: "",
            name: "",
            description: "",
            sample: "",
            module: "",
            function: "",
            public: false

  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Util.L
  # alias TwitchDiscordConnector.Template.SrcServer

  def new(path, desc, sample, fcall, public \\ true) do
    info = Function.info(fcall)

    %Src{
      path: path,
      name: String.split(path, ".") |> List.last(),
      description: desc,
      sample: sample,
      module: Keyword.get(info, :module) |> Atom.to_string(),
      function: Keyword.get(info, :name) |> Atom.to_string(),
      public: public
    }

    # |> SrcServer.register()
  end

  def call(s = %Src{}, args) do
    # L.d("call(#{s}, #{inspect(args)})")

    with module <- String.to_existing_atom(s.module),
         func_atom <- String.to_existing_atom(s.function) do
      try do
        {:ok, apply(module, func_atom, args)}
      rescue
        err -> {:error, err}
      end
    end
  end

  defimpl String.Chars, for: TwitchDiscordConnector.Template.Src do
    def to_string(s), do: "Src|#{s.path}|#{s.module}.#{s.function}>"
  end
end
