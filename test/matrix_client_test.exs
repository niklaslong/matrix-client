defmodule MatrixClientTest do
  use ExUnit.Case
  doctest MatrixClient

  test "register user" do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    {:ok, body} = MatrixClient.register_user(pid, "foo", "bar")
    assert body.status == 200
  end
end
