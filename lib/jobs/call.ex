defmodule TwitchDiscordConnector.Job.Call do
  defstruct mod: "", fun: "", args: []

  alias TwitchDiscordConnector.Job.Call

  def new(func, args \\ []) do
    info = Function.info(func)

    %Call{
      mod: Keyword.get(info, :module) |> Atom.to_string(),
      fun: Keyword.get(info, :name) |> Atom.to_string(),
      args: args
    }
  end

  def load(map) do
    %Call{
      mod: Map.get(map, "mod"),
      fun: Map.get(map, "fun"),
      args: Map.get(map, "args")
    }
  end

  def run(%{mod: m, fun: f, args: a}) do
    apply(String.to_existing_atom(m), String.to_existing_atom(f), a)
  end

  #   "call" => {
  #     "mod" => "TwitchDiscordConnector.Tasks.Manager", # Atom.to_string()
  #     "fun" => "check_tasks", # Atom.to_string()
  #     "args" => []
  #   },

  # I don't think I need this?
  # defimpl Poison.Encoder, for: TwitchDiscordConnector.Tasks.TaskCall do
  #   def encode(%{mod: m, fun: f, args: a}, options) do

  #   end
  # end
end
