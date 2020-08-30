defmodule MatrixClient.Session do
  use Agent

  @doc """
  Starts a new session with a base_url.
  """
  def start_link(url) do
    Agent.start_link(fn -> %{url: url, rooms: %{}} end)
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

  def get_rooms(bucket) do
    Agent.get(bucket, &Map.get(&1, :rooms))
  end

  def update_rooms(bucket, new_rooms) do
    put(bucket, :rooms, new_rooms)
  end

  def room_join_data(data) do
    %{"rooms" => rooms} = data
    rooms["join"]
  end

  def sync_rooms(bucket, data) do
    join_rooms = room_join_data(data)
    new_rooms = Enum.reduce(join_rooms, get_rooms(bucket), &sync_room/2)
    update_rooms(bucket, new_rooms)
  end

  def sync_room({room_id, room_data}, rooms) do
    %{"timeline" => %{"events" => timeline}} = room_data

    if rooms[room_id] do
      new_timeline =
        rooms[room_id]
        |> Enum.concat(timeline)
        |> Enum.uniq()

      Map.put(rooms, room_id, new_timeline)
    else
      Map.put(rooms, room_id, timeline)
    end
  end

  def room_timeline(bucket, room_id) do
    rooms = get_rooms(bucket)

    case rooms[room_id] do
      nil -> {:error, "#{room_id} not found"}
      timeline -> {:ok, timeline}
    end
  end
end
