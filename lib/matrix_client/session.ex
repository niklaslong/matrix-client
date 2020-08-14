defmodule MatrixClient.Session do
  use Agent

  @doc """
  Starts a new session with a base_url.
  """
  def start_link(url) do
    rooms_state = %{join: %{}, invite: %{}, leave: %{}}
    Agent.start_link(fn -> %{url: url, rooms: rooms_state} end)
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

  def put_map(bucket, m) do
    Enum.map(
      fn {k, v} ->
	put(bucket, k, v)
      end,
      m
    )
  end

  def put_room(bucket, key, room_id, new_room_state) do
    {:ok, rooms} = get(bucket, :rooms)
    section = Map.get(rooms, key)
    
    new_section = Map.put(section, room_id, new_room_state)
    new_rooms = Map.put(rooms, key, new_section)
    
    put(bucket, :rooms, new_rooms)
  end

  def put_room_events_join(bucket, room_id, event) do
    put_room(bucket, :join, room_id, event)
  end

  def put_room_events_invite(bucket, room_id, event) do
    put_room(bucket, :invite, room_id, event)
  end

  def put_room_events_leave(bucket, room_id, event) do
    put_room(bucket, :leave, room_id, event)
  end

  def start_sync(pid) do
    MatrixClient.Synchronizer.start_link(%{session: pid})
  end

  def sync(pid, opts \\ %{}) do
    {:ok, url} = get(pid, :url)
    {:ok, token} = get(pid, :token)
    MatrixSDK.API.sync(url, token, opts)
  end
end
