defmodule Err do
  @moduledoc """

  > Too err is human.
  > - Everyone after making a mistake.

  Err is a tiny library for dealing with errors. A more detailed explanation is available at [Leveraging Exceptions to handle errors in Elixir](https://leandrocp.com.br/2020/08/leveraging-exceptions-to-handle-errors-in-elixir/).

  """

  @doc """
  Wraps an `Exception` and its `opts` to return a valid exception.

  Any exception can be used, either from Elixir standard library, a third-party library, or defined by you in your application.

  ## Examples

      iex> Err.wrap(KeyError, key: :id)
      %KeyError{key: :id}

      iex> Err.wrap(MyApp.CustomError, changeset: changeset)
      %MyApp.CustomError{changeset: changeset}

  Passing only opts will build an `Err.GenericError` exception:

      iex> Err.wrap(reason: :boom)
      %Err.GenericError{reason: :boom}

  """
  def wrap(exception, opts \\ [])

  def wrap(exception, opts) when is_atom(exception) do
    struct(exception, opts)
  end

  def wrap(opts, _) do
    struct(Err.GenericError, opts)
  end

  @doc """
  Returns a message for a given `exception` or the message defined by `mod`.

  ## Examples

      iex> Err.wrap(ArgumentError) |> Err.message()
      "argument error"

      iex> Err.wrap(reason: :invalid_value) |> Err.message()
      "generic error: :invalid_value"

  If you pass a module to the generic error, it will call the function `format_error(reason)`
  on that module to format the message:

      iex> Err.wrap(mod: MyApp.Auth, reason: :insufficient_permissions) |> Err.message()
      "Unable to perform action due to insufficient permissions."

  See `Err.GenericError` or README for a complete example.

  """
  def message(%_{mod: mod, reason: reason}) when not is_nil(mod) do
    mod.format_error(reason)
  end

  def message(exception) do
    Exception.message(exception)
  end
end
