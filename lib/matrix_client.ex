defmodule MatrixClient do
  @moduledoc """
  Documentation for `MatrixClient`.
  """

  alias MatrixClient.{Session}
  alias MatrixSDK.{Client}

  def new_session(url) do
    Session.start_link(url)
  end

  def spec_versions(session) do
    {:ok, url} = Session.get(session, :url)
    handle_result(Client.spec_versions(url))
  end

  def server_discovery(session) do
    {:ok, url} = Session.get(session, :url)
    handle_result(Client.server_discovery(url))
  end

  def register_user(session, username, password) do
    {:ok, url} = Session.get(session, :url)
    auth = Client.Auth.login_dummy()
    opts = %{username: username}

    handle_result(
      Client.register_user(url, password, auth, opts),
      fn body ->
        case Map.get(body, "access_token") do
          nil -> {:error, "No token found"}
          token -> Session.put(session, :token, token)
        end
      end
    )
  end

  def login_user(session, username, password) do
    {:ok, url} = Session.get(session, :url)
    auth = Client.Auth.login_user(username, password)

    handle_result(
      Client.login(url, auth),
      fn body ->
        token = Map.get(body, "access_token")

        if token do
          Session.put(session, :token, token)
        else
          {:error, "Invalid token value: #{token}"}
        end
      end
    )
  end

  def logout(session) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(Client.logout(url, token))
  end

  def create_room(session, name, opts \\ %{}) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    new_opts = Map.put(opts, :room_alias_name, name)
    handle_result(Client.create_room(url, token, new_opts))
  end

  def create_anonymous_room(session, opts \\ %{}) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(Client.create_room(url, token, opts))
  end

  def join_room(session, room_id, opts \\ %{}) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(Client.join_room(url, token, room_id, opts))
  end

  def leave_room(session, room_id) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(Client.leave_room(url, token, room_id))
  end

  def joined_rooms(session) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)

    handle_result(
      Client.joined_rooms(url, token),
      fn body -> {:ok, joined_rooms_formatter(session, body["joined_rooms"])} end
    )
  end

  defp joined_rooms_formatter(session, room_ids) do
    aliases = Session.get_aliases(session)

    Enum.map(room_ids, fn room_id ->
      case aliases[room_id] do
        nil -> %{room_id: room_id}
        a -> %{room_id: room_id, alias: a}
      end
    end)
  end

  def send_text_message(session, room_id, message) do
    send_message(session, room_id, :text, message)
  end

  def send_message(session, room_id, type, message) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)

    room_event =
      Client.RoomEvent.message(
        room_id,
        type,
        message,
        tx_id()
      )

    handle_result(Client.send_room_event(url, token, room_event))
  end

  def sync(pid, opts \\ %{}) do
    {:ok, url} = Session.get(pid, :url)
    {:ok, token} = Session.get(pid, :token)

    new_opts =
      case Session.get(pid, :next_batch) do
        {:ok, next_batch} -> Map.put(opts, :since, next_batch)
        _ -> opts
      end

    handle_result(
      Client.sync(url, token, new_opts),
      fn body ->
        Session.sync_rooms(pid, body)
      end
    )
  end

  def room_timeline(pid, room_id) do
    ids = Session.get_ids(pid)

    new_id =
      case ids[room_id] do
        nil -> room_id
        id -> id
      end

    Session.room_timeline(pid, new_id)
  end

  def invite_to_room(pid, room_id, user_id) do
    {:ok, url} = Session.get(pid, :url)
    {:ok, token} = Session.get(pid, :token)
    handle_result(Client.room_invite(url, token, room_id, user_id))
  end

  def invites(pid) do
    Session.get_invites(pid)
  end

  def rooms(pid) do
    Session.get_rooms(pid)
  end

  def accept_invite(pid, room_id) do
    %{status: 200} = join_room(pid, room_id)
    Session.delete_invite(pid, room_id)
  end

  def next_room_messages(pid, room_id) do
    get_room_messages(pid, room_id, "f")
  end

  def prev_room_messages(pid, room_id) do
    get_room_messages(pid, room_id, "b")
  end

  defp get_room_messages(pid, room_id, direction) do
    {:ok, url} = Session.get(pid, :url)
    {:ok, token} = Session.get(pid, :token)
    ids = Session.get_ids(pid)

    new_id =
      case ids[room_id] do
        nil -> room_id
        id -> id
      end

    case Session.prev_batch(pid, new_id) do
      {:ok, prev} ->
        filter_messages(Client.room_messages(url, token, new_id, prev, direction))

      {:error, _} = e ->
        e
    end
  end

  defp filter_messages(result) do
    handle_result(result, fn body ->
      Enum.filter(body["chunk"], fn m ->
        m["type"] == "m.room.message"
      end)
    end)
  end

  defp handle_result(result, handler \\ nil) do
    h =
      if handler do
        handler
      else
        fn body -> body end
      end

    case result do
      {:ok, %{status: 200} = resp} ->
        h.(body_formatter(resp))

      {:ok, resp} ->
        {:error, body_formatter(resp)}

      {:error, _} = e ->
        e
    end
  end

  defp body_formatter(response) do
    body = response.body
    Map.put(body, :status, response.status)
  end

  defp tx_id do
    100
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
  end
end
