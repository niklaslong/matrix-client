# MatrixClient

Grounds for experimenting with higher level abstractions of [matrix-elixir-sdk]()

Not ready for use yet.

## Usage

You will want to install synapse locally to be able to run the tests.

```
cd synapse
source env/bin/activate
synctl start
```

### Testing

When doing development the main test module is run against an external matrix server.

To run the test module with external enabled:

```
mix test --include external:true
```

### Example Usage

```elixir
{:ok, pid} = MatrixClient.new_session("http://localhost:8008")

:ok = MatrixClient.register_user(pid, "foo", "bar")

# Logging in is optional since an access token is received upon registering
:ok = MatrixClient.login_user("foo", "bar")

%{"room_id" => room_id} = MatrixClient.create_room(pid, "coolroom")

MatrixClient.send_text_message(pid, room_id, "Hello, World!")

MatrixClient.sync(pid)

IO.inspect(MatrixClient.room_timeline(pid, room_id))

MatrixClient.logout(pid)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `matrix_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:matrix_client, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/matrix_client](https://hexdocs.pm/matrix_client).

