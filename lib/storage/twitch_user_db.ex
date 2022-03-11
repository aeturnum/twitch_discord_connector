defmodule TwitchDiscordConnector.JsonDB.TwitchUserDB do
  @moduledoc """
  Helpers for putting user data into the json file or getting it out

  Future use will probably cut down the amount of information stored.
  """
  # Common method for saving and getting twitch data
  defstruct uid: "", info: nil, hook: nil, online_sub: nil, offline_sub: nil, state: %{}

  alias TwitchDiscordConnector.JsonDB.TwitchUserDB
  alias TwitchDiscordConnector.JsonDB
  alias TwitchDiscordConnector.Util.H

  @dbkey "twitch_users"
  @twitch_info_fields ["login", "display_name", "description"]

  @doc """
  Get all user ids stored under the global key

  Returns `list` of `binaries` of numbers.
  """
  def user_ids() do
    JsonDB.get(@dbkey, %{})
    |> Map.keys()
  end

  def save_user(user) do
    JsonDB.insert(
      @dbkey,
      %{
        "info" => user.info,
        "hook" => user.hook,
        "online_sub" => user.online_sub,
        "offline_sub" => user.offline_sub,
        "state" => user.state
      },
      key: user.uid
    )

    user
  end

  def save_user_info(user, info_from_twitch) do
    with info_fields <- H.grab_keys(%{}, info_from_twitch, @twitch_info_fields) do
      %{user | info: info_fields}
      |> save_user()
    end
  end

  @doc """
  Load a user with the given `uid`

  Returns a `TwitchUserDB` structure with the user data
  """
  def load_user(uid) do
    with uid <- H.str(uid),
         user_map <- JsonDB.get(@dbkey, %{}) |> Map.get(uid, %{}) do
      %TwitchUserDB{
        uid: uid,
        info: Map.get(user_map, "info", nil),
        hook: Map.get(user_map, "hook", nil),
        online_sub: Map.get(user_map, "online_sub", nil),
        offline_sub: Map.get(user_map, "offline_sub", nil),
        state: Map.get(user_map, "state", %{})
      }
    end
  end

  def load_online_sub(uid), do: load_user(uid).online_sub
  def load_offline_sub(uid), do: load_user(uid).offline_sub

  def load_hook(uid), do: load_user(uid).hook

  # defimpl String.Chars, for: Ping do
  #   def to_string(p = %Ping{}) do
  #     "%Ping[#{p.id}]: #{Ping.command(p)}"
  #   end
  # end

  defimpl String.Chars, for: TwitchUserDB do
    def to_string(s), do: "#{state_name(s)}#{state_flags(s)}"
    def state_name(%{uid: uid, info: nil}), do: "TUser[#{uid}]"
    def state_name(%{uid: uid, info: %{"display_name" => d}}), do: "TU[#{d}(#{uid})]"
    def state_flags(s), do: "#{state_hook(s)}#{state_subn(s)}#{state_subf(s)}"
    def state_hook(%{hook: nil}), do: "[_]"
    def state_hook(%{hook: _}), do: "[H]"
    def state_subn(%{online_sub: nil}), do: "[N_]"
    def state_subn(%{online_sub: _}), do: "[NS]"
    def state_subf(%{offline_sub: nil}), do: "[F_]"
    def state_subf(%{offline_sub: _}), do: "[FS]"
  end
end
