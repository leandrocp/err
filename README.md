# Err

Err is a tiny library for dealing with errors. A more detailed explanation is available at [Leveraging Exceptions to handle errors in Elixir](https://leandrocp.com.br/2020/08/leveraging-exceptions-to-handle-errors-in-elixir/).

> "Too err is human."
> - Everyone after making a mistake.

[Documentation](https://hexdocs.pm/err) | [Package](https://hex.pm/packages/err)

Note: this library is still **experimental** and the API may change.

## Installation

You can install `err` by adding it to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:err, "~> 0.1.0"}
  ]
end
```

## Usage

At this moment the lib is composed of two functions: `wrap/2` and `message/1`, and as the name suggest the former will wrap an exception and its options and the the latter will format an exception into a friendly message for you:

```elixir
iex> Err.wrap(KeyError, key: :id)
%KeyError{key: :id, message: nil, term: nil}

iex> Err.wrap(KeyError, key: :id) |> Err.message()
"key :id not found

iex> Err.wrap(reason: :invalid_user)
%Err.GenericError{changeset: nil, mod: nil, reason: :invalid_user}

iex> Err.wrap(reason: :invalid_user) |> Err.message()
"generic error :invalid_user"
```

Ok, but why not just build and call exception directly? Having a single and common API allows to have custom logic like building an `Err.GenericError` or extend it to support more features, and also it's a benefit having a single API to deal with errors.

## Complete example

The main idea is to wrap exceptions, either from Elixir standard library, third-party libraries, or defined in your app. Those exceptions can be used to `raise` or to display a message by calling `Err.message/1`, so instead of spreading atoms or strings as errors in your app, you can rely on `Err` functions to handle it:


```elixir
defmodule MyApp.Auth do
  # Just an example
  def can?(current_user, permission) do
    # code here to check permission
  end

  def format_error(:insufficient_permissions) do
    "Unable to perform action due to insufficient permissions."
  end
end

defmodule MyApp.DataIngestion do
  @doc """
    Some complex function that needs to deal with different errors.
    Keep in mind that's just an example to show how to use the Err API.
  """
  @spec import(User.t, Path.t) :: {:ok, map()} | {:error, Err.t}
  def import(current_user, csv_file_path) do
    with {:check_permission, true} <- {:check_permission, Auth.can?(current_user, :import},
         {:read_file, {:ok, contet}} <- {:read_file, File.read(csv_file_path)},
         {:import, {:ok, data}} <- {:import, do_import(content)} do
      {:ok, data}
    else
      {:check_permission, _} ->
        {:error, Err.wrap(mod: MyApp.Auth, reason: :insufficient_permissions)}

      {:read_file, {:error, reason}} ->
        {:error, Err.wrap(File.Error, action: "read file", reason: reason, path: csv_file_path)}

      {:import, {:error, reason}} ->
        {:error, Err.wrap(reason: reason)}
  end
end

def MyAppWeb.DataIngestionLive do
  def handle_event("import", %{"csv_file_path" => csv_file_path}, socket) do
    case MyApp.DataIngestion.import(socket.assigns.current_user, csv_file_path) do
      {:ok, _} ->
        put_flash(socket, :info, "File imported!")

      {:ok, error} ->
        # could be either a error related to permission, file, or import.
        put_flash(socket, :error, Err.message(error))
    end
  end
end
```

In case something unexpected happens, that function may return different errors:

```elixir
iex> {:error, error} = MyApp.DataIngestion.import(current_user, "/data/import.csv")
iex> Err.message(error)
```

Possible outcomes:

1. "Unable to perform action due to insufficient permissions."
2. "could not read file \"/data/import.csv\": no such file or directory"
3. whatever error message is returned by `do_import`

Meaning it's responsibility of the business logic or context to define the error and what should be displayed for the user.

In a LiveView, Controller, CLI, etc. you would call something like:

```elixir
put_flash(socket, :error, Err.message(error))
```

Or if that function is also called by a background worker, you could call:

```elixir
Logger.error(fn -> inspect(error) end)
raise error
```

Because in this case, there's no interface to display, so the best you can do is raise or log something.

Another benefit is wrapping a generic error with a related module:

```elixir
Err.wrap(mod: MyApp.Auth, reason: :insufficient_permissions)
```

That kind of error happens everywhere but there's no need to duplicate the same error message over and over again. The function `MyApp.Auth.format_error(:insufficient_permissions)` will be called to resolve that message so it can be reused.

## TODO

- Add specs
- Explain the usage of changesets
- Validate exceptions and fields