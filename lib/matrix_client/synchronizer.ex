defmodule MatrixClient.Synchronizer do
  use GenServer

  @ten_seconds 10000

  def init(opts) do
    Process.link(opts.session)
    Process.send_after(self(), :sync, @ten_seconds)
    {:ok, opts}
  end

  def handle_info(:sync, state) do

    opts =
    if state.since do
      %{since: state.since}
    else
      %{}
    end

    data = MatrixClient.Session.sync(state.session, opts)
    next_batch = Map.get(data, "next_batch")
    sync_presence(state.session, data)
    #sync_account_data(session, data)
    sync_rooms(state.session, data)

    Process.send_after(self(), :sync, @ten_seconds)

    {:noreply, Map.put(state, :since, next_batch)}
  end

  defp sync_presence(session, data) do
    presence = Map.get(data, "presence")
    if presence do
      events = Map.get(data, "events")
      Enum.map(
	fn event ->
	  sync_presence_event(session, event)
	end,
	events
      )      
    end
  end

  defp sync_presence_event(session, event) do
    content = Map.get(event, "content")
    if content do
      MatrixClient.Session.put_map(session, content)
    end
  end

  defp sync_rooms(session, data) do
    rooms = Map.get(data, "rooms")
    if rooms do
      sync_rooms_join(session, rooms)
      sync_rooms_invite(session, rooms)
      sync_rooms_leave(session, rooms)
    end
  end

  defp sync_rooms_join(session, rooms) do
    joins = Map.get(rooms, "join")
    Enum.map(
      fn {room_id, state} ->
	sync_join(session, room_id, state)
      end,
      joins
    )  
  end

  defp sync_join(session, room_id, state) do
    events = Map.get(state, "events")
    MatrixClient.Session.put_room_events_join(session, room_id, events)
  end

  defp sync_rooms_invite(session, rooms) do
    invites = Map.get(rooms, "invite")
    Enum.map(
      fn {room_id, state} ->
	sync_invite(session, room_id, state)
      end,
      invites
    )
  end

  defp sync_invite(session, room_id, state) do
    events = Map.get(state, "events")
    MatrixClient.Session.put_room_events_invite(session, room_id, events)
  end

  defp sync_rooms_leave(session, rooms) do
    leaves = Map.get(rooms, "leave")
    Enum.map(
      fn {room_id, state} ->
	sync_leave(session, room_id, state)
      end,
      leaves
    )
  end

  defp sync_leave(session, room_id, state) do
    events = Map.get(state, "events")
    MatrixClient.Session.put_room_events_leave(session, room_id, events)    
  end

end
