defmodule MatrixClient.Session do
  use Agent

  @doc """
  Starts a new session with a base_url.
  """
  def start_link(url) do
    Agent.start_link(fn ->
      %{url: url, rooms: %{}, invites: %{}, aliases: %{ids: %{}, aliases: %{}}}
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

  def update_rooms(bucket, new_rooms) do
    put(bucket, :rooms, new_rooms)
  end

  def update_invites(bucket, new_invites) do
    put(bucket, :invites, new_invites)
  end

  def update_aliases(bucket, new_aliases) do
    put(bucket, :aliases, new_aliases)
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

    new_aliases = Enum.reduce(join_rooms, get_aliases(bucket), &sync_alias/2)
    update_aliases(bucket, new_aliases)

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

  def sync_alias({room_id, room_data}, aliases) do
    %{"timeline" => %{"events" => events}} = room_data

    case filter_alias_event(events) do
      [ae] -> alias_helper_ids(aliases, room_id, ae["content"]["alias"])
      _ -> aliases
    end
  end

  defp alias_helper_ids(aliases, room_id, a) do
    ids = aliases[:ids]
    new_ids = Map.put(ids, room_id, a)
    new_aliases = Map.put(aliases, :ids, new_ids)
    alias_helper_aliases(new_aliases, room_id, a)
  end

  defp alias_helper_aliases(aliases, room_id, a) do
    as = aliases[:aliases]
    new_aliases = Map.put(as, a, room_id)
    Map.put(aliases, :aliases, new_aliases)
  end

  defp filter_alias_event(events) do
    Enum.filter(events, fn e ->
      e["type"] == "m.room.canonical_alias"
    end)
  end
end
