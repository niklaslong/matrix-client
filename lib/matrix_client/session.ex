defmodule MatrixClient.Session do
  use Agent

  @doc """
  Starts a new session with a base_url.
  """
  def start_link(url) do
    Agent.start_link(fn -> %{url: url} end)
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get(bucket, key) do
    case Agent.get(bucket, &Map.get(&1, key)) do
      nil -> {:error, "Missing #{key} field in session"}
      field -> {:ok, field}
    end
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def put(bucket, key, value) do
    Agent.update(bucket, &Map.put(&1, key, value))
  end
end
