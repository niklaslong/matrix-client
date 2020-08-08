defmodule MatrixClientTest do
  use ExUnit.Case
  doctest MatrixClient

  test "greets the world" do
    assert MatrixClient.hello() == :world
  end
end
