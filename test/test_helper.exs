ExUnit.start()
ExUnit.configure(exclude: [external: true])

# Mostly taken from here https://elixirforum.com/t/generating-5-000-random-strings-improving-performance-by-an-order-of-magnitude-but-can-it-be-better/23206/5

defmodule Rando do
  chars = 'abcdefghijklmnopqrstuvwxyz123456789'

  @chars List.to_tuple(chars)

  def string() do
    generate_rand_string()
  end

  defp generate_rand_string() do
    0
    |> generate_rand_string()
    |> IO.iodata_to_binary()
  end

  defp generate_rand_string(n) when n == 10 do
    []
  end

  defp generate_rand_string(n) do
    [elem(@chars, :rand.uniform(35) - 1), generate_rand_string(n + 1)]
  end

  def user() do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    username = string()
    password = string()
    :ok = MatrixClient.register_user(pid, username, password)

    pid
  end

  def user2() do
    {:ok, pid} = MatrixClient.new_session("http://localhost:8008")
    username = string()
    password = string()
    :ok = MatrixClient.register_user(pid, username, password)

    {pid, username}
  end
end
