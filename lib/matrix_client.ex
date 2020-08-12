defmodule MatrixClient do
  @moduledoc """
  Documentation for `MatrixClient`.
  """

  alias MatrixClient.{Session}
  alias MatrixSDK.{API, Auth, RoomEvent}

  def new_session(url) do
    Session.start_link(url)
  end

  def login_user(session, username, password) do
    {:ok, url} = Session.get(session, :url)
    auth = Auth.login_user(username, password)
    handle_result(
      API.login(url, auth),
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
    handle_result(API.logout(url, token))
  end

  def join_room(session, room_id, opts \\ %{}) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(API.join_room(url, token, room_id, opts))    
  end

  def leave_room(session, room_id) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(API.leave_room(url, token, room_id))
  end

  def joined_rooms(session) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    handle_result(
      API.joined_rooms(url, token),
      fn body -> {:ok, Map.get(body, "joined_rooms")} end
    )
  end

  def send_message(session, room_id, message) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    room_event = RoomEvent.message(room_id, :text, message)
    handle_result(
      API.send_room_event(url, token, room_event, tx_id())
    )
  end

  def room_messages(session, room_id, opts \\ %{}) do
    {url, token} = url_token(session)
    timestamp = "t123456"
    dir = "f"
    handle_result(
      API.room_messages(url, token, room_id, timestamp, dir, opts)
    )
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
	h.(body_helper(resp))
      {:ok, resp} -> {:error, body_helper(resp)}
      {:error, _} = e -> e
    end
  end

  defp body_helper(response) do
    body = response.body
    Map.put(body, :status, response.status)
  end

  defp tx_id do
    100
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
  end

  defp url_token(session) do
    {:ok, url} = Session.get(session, :url)
    {:ok, token} = Session.get(session, :token)
    {url, token}
  end

end
