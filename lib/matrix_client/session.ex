defmodule MatrixClient.Session do
  use Agent

  @doc """
  Starts a new session with a base_url.
  """
  def start_link(url) do
    Agent.start_link(fn ->
      %{url: url, rooms: %{}, invites: %{}, aliases: %{}, ids: %{}}
    end)
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

  def get_invites(bucket) do
    Agent.get(bucket, &Map.get(&1, :invites))
  end

  def get_aliases(bucket) do
    Agent.get(bucket, &Map.get(&1, :aliases))
  end

  def get_ids(bucket) do
    Agent.get(bucket, &Map.get(&1, :ids))
  end

  def update_rooms(bucket, new_rooms) do
    put(bucket, :rooms, new_rooms)
  end

  def update_invites(bucket, new_invites) do
    put(bucket, :invites, new_invites)
  end

  def update_aliases(bucket, alias_updates, aliases) do
    new_aliases = Map.new(alias_updates)
    put(bucket, :aliases, Map.merge(aliases, new_aliases))
  end

  def update_ids(bucket, alias_updates, ids) do
    new_updates = Enum.map(alias_updates, fn {room_id, a} -> {a, room_id} end)
    new_ids = Map.new(new_updates)
    put(bucket, :ids, Map.merge(ids, new_ids))
  end

  def update_next_batch(bucket, next_batch) do
    put(bucket, :next_batch, next_batch)
  end

  def delete_invite(bucket, room_id) do
    invites = get_invites(bucket)
    update_invites(bucket, Map.delete(invites, room_id))
  end

  def room_join_data(data) do
    %{"rooms" => rooms} = data
    rooms["join"]
  end

  def room_invite_data(data) do
    %{"rooms" => rooms} = data
    rooms["invite"]
  end

  def room_leave_data(data) do
    %{"rooms" => rooms} = data
    rooms["leave"]
  end

  def sync_rooms(bucket, data) do
    join_rooms = room_join_data(data)
    new_rooms = Enum.reduce(join_rooms, get_rooms(bucket), &sync_room/2)
    update_rooms(bucket, new_rooms)

    alias_updates = Enum.reduce(join_rooms, [], &sync_alias/2)
    update_aliases(bucket, alias_updates, get_aliases(bucket))
    update_ids(bucket, alias_updates, get_ids(bucket))

    invite_rooms = room_invite_data(data)
    new_invites = Enum.reduce(invite_rooms, get_invites(bucket), &sync_invite/2)
    update_invites(bucket, new_invites)

    leave_rooms = room_leave_data(data)
    new_rooms2 = Enum.reduce(leave_rooms, get_rooms(bucket), &sync_leave/2)
    update_rooms(bucket, new_rooms2)

    %{"next_batch" => next_batch} = data
    update_next_batch(bucket, next_batch)
  end

  def sync_room({room_id, room_data}, rooms) do
    %{"timeline" => %{"events" => timeline, "prev_batch" => prev_batch}} = room_data

    if rooms[room_id] do
      old_t = rooms[room_id][:timeline]

      new_timeline =
        old_t
        |> Enum.concat(timeline)
        |> Enum.uniq()

      Map.put(rooms, room_id, %{timeline: new_timeline, prev_batch: prev_batch})
    else
      room = %{timeline: timeline, prev_batch: prev_batch}
      Map.put(rooms, room_id, room)
    end
  end

  def room_timeline(bucket, room_id) do
    rooms = get_rooms(bucket)

    case rooms[room_id] do
      nil -> {:error, "#{room_id} not found"}
      room -> {:ok, room[:timeline]}
    end
  end

  def prev_batch(bucket, room_id) do
    rooms = get_rooms(bucket)

    case rooms[room_id] do
      nil -> {:error, "#{room_id} not found. Try syncing."}
      room -> {:ok, room[:prev_batch]}
    end
  end

  def sync_invite({room_id, invite_data}, rooms) do
    %{"invite_state" => %{"events" => events}} = invite_data
    sender = invite_sender(events)
    Map.put(rooms, room_id, sender)
  end

  def invite_sender(events) do
    [event] = filter_invite_events(events)
    %{"sender" => sender} = event
    sender
  end

  def filter_invite_events(events) do
    Enum.filter(events, fn event ->
      %{"type" => type} = event
      type == "m.room.join_rules"
    end)
  end

  def sync_leave({room_id, _}, rooms) do
    Map.delete(rooms, room_id)
  end

  def sync_alias({room_id, room_data}, updates) do
    %{"timeline" => %{"events" => events}} = room_data

    case filter_alias_event(events) do
      [e] -> [{room_id, e["content"]["alias"]} | updates]
      _ -> updates
    end
  end

  defp filter_alias_event(events) do
    Enum.filter(events, fn e ->
      e["type"] == "m.room.canonical_alias"
    end)
  end
end
