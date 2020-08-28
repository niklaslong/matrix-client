defmodule MatrixClientTest do
  use ExUnit.Case
  doctest MatrixClient

  test "register user" do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    {:ok, body} = MatrixClient.register_user(pid, Rando.string(), Rando.string())
    assert body.status == 200
  end

  test "login and logout" do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    username = Rando.string()
    password = Rando.string()
    {:ok, _} = MatrixClient.register_user(pid, username, password)

    :ok = MatrixClient.login_user(pid, username, password)

    result = MatrixClient.logout(pid)
    assert result.status == 200
  end
end
