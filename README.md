# Err

> Too err is human.
> - Everyone after making a mistake.

Err is a tiny library for dealing with errors. A more detailed explanation is available at [Leveraging Exceptions to handle errors in Elixir](https://leandrocp.com.br/2020/08/leveraging-exceptions-to-handle-errors-in-elixir/), or just keep reading for an example of usage.

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

The main idea is to wrap exceptions, either from Elixir standard library, third-party libraries, or defined in your app. Those exceptions can be used to `raise` or to display a message by calling `Err.message/1`, so instead of spreading atoms or strings as errors in your app, you can rely on `Err` functions to handle it.


```elixir
defmodule MyApp.Auth do
  # Just an example
  def can?(current_user, permission)

  def format_error(:insufficient_permissions) do
    "Unable to perform action due to insufficient permissions."
  end
end

defmodule MyApp.DataIngestion do
  @doc """
    Some complex function that needs to deal with different errors.
    Keep in mind that's just an example to show how to use Err API.
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

Let's understand what's happening in this example.

The example function `MyApp.DataIngestion.import/2` may cause different errors: user may not have permission to perfom that import, file may be missing or corrupt, the import routine may fail for whatever reason. Each one of those situations are captured by `Err.wrap` but with its own details:

`Err.wrap(mod: MyApp.Auth, reason: :insufficient_permissions)`

Returns a generic error that will call `MyApp.Auth.format_error/1` function to return a formatted message for that `reason`.

`Err.wrap(reason: reason)`
 
Another generic error but this time it will be formatted by `Err.Generic.message/1` so you don't need to handle it. It's the most simple kind of error.

`Err.wrap(File.Error, action: "read file", reason: reason, path: csv_file_path)`

Leverages the Elixir exception `File.Error` to return the proper message of what happened when reading that file.

And finally to display the right message to the user, just call `Err.message(error)`.

Note that `:insufficient_permissions` probably is an error that happens a lot in many different places so you don't need to duplicate that message everywhere, also your web layer doesn't need to know about the error, its only responsibility is to display the error that was already defined by your context or lib layer.
