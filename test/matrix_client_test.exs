defmodule MatrixClientTest do
  use ExUnit.Case, async: false
  doctest MatrixClient

  test "register user" do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    :ok = MatrixClient.register_user(pid, Rando.string(), Rando.string())

    :timer.sleep(3000)
  end

  test "login and logout" do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    username = Rando.string()
    password = Rando.string()
    :ok = MatrixClient.register_user(pid, username, password)

    :ok = MatrixClient.login_user(pid, username, password)

    result = MatrixClient.logout(pid)
    assert result.status == 200

    :timer.sleep(3000)    
  end

  test "create anonymous room" do
    pid = Rando.user()

    %{:status => 200, "room_id" => room_id_a} = MatrixClient.create_anonymous_room(pid)

    {:ok, room_ids} = MatrixClient.joined_rooms(pid)

    assert length(room_ids) == 1

    [room_id_b] = room_ids

    assert room_id_b == room_id_a

    MatrixClient.logout(pid)

    :timer.sleep(3000)    
  end

  test "send message, sync and check timeline" do
    pid = Rando.user()

    %{:status => 200, "room_id" => room_id} = MatrixClient.create_anonymous_room(pid)

    %{:status => 200, "event_id" => event_id} = MatrixClient.send_text_message(pid, room_id, "Hello, World!")

    MatrixClient.sync(pid)

    {:ok, timeline} = MatrixClient.room_timeline(pid, room_id)

    filtered_events = Enum.filter(timeline, fn e ->
      e["event_id"] == event_id
    end)

    assert length(filtered_events) == 1

    [event] = filtered_events

    %{"body" => message, "msgtype" => "m.text"} = event["content"]

    assert message == "Hello, World!"

    MatrixClient.logout(pid)

    :timer.sleep(3000)
  end
end
