defmodule TwitchDiscordConnectorTest.Event.Twitch do
  use ExUnit.Case

  alias TwitchDiscordConnector.Event.TwitchUser
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB
  alias TwitchDiscordConnector.Util.L

  test "added" do
    # %{channel: :event, data: %{}, name: :added, type: :send}
    # not a real user
    user = TwitchUserDB.load_user(0)

    {actions, state} = TwitchUser.handle_event({:send, :event}, {:added, nil}, user)

    # we don't sub in tests anymore
    # assert action_exists(actions, {:job, :me, :subscribe, {:ok, ["0", 28800]}}) == true
    assert action_exists(actions, {:job, :me, :user_info, {:ok, ["0"]}}) == true
  end

  test "set user info" do
    # %{channel: :event, data: %{}, name: :added, type: :send}
    # not a real user
    user = TwitchUserDB.load_user(1)

    {_, state} =
      TwitchUser.handle_event({:send, :me}, {:user_info, {:ok, %{"login" => "bar"}}}, user)

    assert state.info["login"] == "bar"

    user = TwitchUserDB.load_user(1)
    assert user.info["login"] == "bar"
  end

  def action_exists(action_list, desired_act) do
    Enum.any?(action_list, fn a -> compare_action(desired_act, a) end)
  end

  def compare_action({:job, d1, n1, {_, a1}}, {:job, d2, n2, {_, a2}}) do
    d1 == d2 && n1 == n2 && a1 == a2
  end
end
