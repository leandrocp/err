defmodule Err do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  @typedoc """
  A result type representing either success or failure.

  Can be:
  - `{:ok, value}` - A successful result with a value
  - `{:error, error}` - A failed result with an error
  - Any tuple starting with `:ok` or `:error` (supports multiple elements)
  """
  @type result :: tuple()

  @typedoc """
  An option type representing either some value or none.

  Can be:
  - `value` - Some value is present
  - `nil` - No value (none)
  """
  @type option :: any() | nil

  @typedoc """
  Either a `t:result/0` or an `t:option/0` type.
  """
  @type value :: result() | option()

  @doc """
  Wraps `value` in an `{:ok, value}` tuple.

  ## Examples

      iex> Err.ok(%{id: 1, email: "john@example.com"})
      {:ok, %{email: "john@example.com", id: 1}}

      iex> Err.ok({:ok, 100})
      {:ok, {:ok, 100}}

  """
  @spec ok(any()) :: result()
  def ok(value), do: {:ok, value}

  @doc """
  Wraps `value` in an `{:error, value}` tuple.

  ## Examples

      iex> Err.error(:timeout)
      {:error, :timeout}

      iex> Err.error({:validation_failed, :email})
      {:error, {:validation_failed, :email}}

  """
  @spec error(any()) :: result()
  def error(value), do: {:error, value}

  @doc """
  Returns the wrapped `value` or `default` when the result is error or value is empty.

  For two-element result tuples (`{:ok, value}`) it returns `value`. When the tuple
  contains additional metadata, it returns the remaining elements as a list.

  Accepts `nil`, any `{:ok, value}` or `{:error, reason}` tuple (with or without extra metadata),
  and other terms.

  ## Examples

      iex> Err.unwrap_or({:ok, "config.json"}, "default.json")
      "config.json"

      iex> Err.unwrap_or({:ok, :user, %{role: :admin}}, [])
      [:user, %{role: :admin}]

      iex> Err.unwrap_or({:error, :not_found}, "default.json")
      "default.json"

      iex> Err.unwrap_or(nil, "default.json")
      "default.json"

  """
  @spec unwrap_or(value(), any()) :: any()
  def unwrap_or(value, default)
  def unwrap_or(nil, default), do: default
  def unwrap_or({:ok, value}, _default), do: value
  def unwrap_or({:error, _}, default), do: default

  def unwrap_or(tuple, default) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      :error -> default
      _ -> tuple
    end
  end

  def unwrap_or(other, _default), do: other

  @doc """
  Returns the wrapped value or computes it from `default_fun` when the result is an error or value
  is empty.

  For successful tuples (`{:ok, value}`) the unwrapped value is returned. When the tuple contains
  extra data, the remaining elements are returned as a list. For error tuples the extracted value(s)
  are passed to `default_fun`.

  The function receives the extracted value(s): a single value for two-element tuples or a list for
  larger tuples.

  This is the lazy version of `unwrap_or/2` - the function is only called when needed.

  ## Examples

      iex> Err.unwrap_or_lazy({:ok, "config.json"}, fn _ -> "default.json" end)
      "config.json"

      iex> Err.unwrap_or_lazy({:ok, :admin, %{perms: [:read]}}, fn _ -> [] end)
      [:admin, %{perms: [:read]}]

      iex> Err.unwrap_or_lazy({:error, :enoent}, fn reason -> "Error: \#{reason}" end)
      "Error: enoent"

      iex> Err.unwrap_or_lazy(nil, fn _ -> %{role: :guest} end)
      %{role: :guest}

  """
  @spec unwrap_or_lazy(value(), (any() -> any())) :: any()
  def unwrap_or_lazy(nil, default_fun), do: default_fun.([])
  def unwrap_or_lazy({:ok, value}, _default_fun), do: value
  def unwrap_or_lazy({:error, reason}, default_fun), do: default_fun.(reason)

  def unwrap_or_lazy(tuple, default_fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        tuple |> Tuple.delete_at(0) |> Tuple.to_list()

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        default_fun.(payload)

      _ ->
        tuple
    end
  end

  def unwrap_or_lazy(other, _default_fun), do: other

  @doc """
  Returns the wrapped value from an `{:ok, value}` tuple or raises the provided exception.

  For two-element result tuples (`{:ok, value}`) it returns `value`. When the tuple contains
  additional metadata, it returns the remaining elements as a list.

  If the value is `{:error, _}`, `nil`, or any other value, raises the provided exception.

  ## Examples

      iex> Err.expect!({:ok, "config.json"}, RuntimeError.exception("config not found"))
      "config.json"

      iex> Err.expect!({:ok, :user, %{role: :admin}}, RuntimeError.exception("user not found"))
      [:user, %{role: :admin}]

  """
  @spec expect!(value(), Exception.t()) :: any()
  def expect!(value, exception)

  def expect!({:ok, value}, _exception), do: value

  def expect!(tuple, exception) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      _ -> raise exception
    end
  end

  def expect!(_value, exception), do: raise(exception)

  @doc """
  Returns the wrapped error from an `{:error, reason}` tuple or raises the provided exception.

  For two-element error tuples (`{:error, reason}`) it returns `reason`. When the tuple contains
  additional metadata, it returns the remaining elements as a list.

  If the value is `{:ok, _}`, `nil`, or any other value, raises the provided exception.

  ## Examples

      iex> Err.expect_err!({:error, :timeout}, RuntimeError.exception("expected an error"))
      :timeout

      iex> Err.expect_err!({:error, 404, "Not Found"}, RuntimeError.exception("expected an error"))
      [404, "Not Found"]

  """
  @spec expect_err!(value(), Exception.t()) :: any()
  def expect_err!(value, exception)

  def expect_err!({:error, reason}, _exception), do: reason

  def expect_err!(tuple, exception) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      _ -> raise exception
    end
  end

  def expect_err!(_value, exception), do: raise(exception)

  @doc """
  Chains the result by calling `fun` when the value is present.

  For `{:ok, value}` the extracted value (or list of values) is passed to `fun`.
  Error tuples and `nil` are returned unchanged, allowing the pipeline to short-circuit.

  ## Examples

      iex> Err.and_then({:ok, 5}, fn num -> num * 2 end)
      10

      iex> Err.and_then(5, fn num -> num * 2 end)
      10

      iex> Err.and_then({:ok, :admin, %{id: 1}}, fn [role, user] -> {:ok, %{role: role, user_id: user.id}} end)
      {:ok, %{role: :admin, user_id: 1}}

      iex> Err.and_then({:error, :timeout}, fn num -> {:ok, num * 2} end)
      {:error, :timeout}

      iex> Err.and_then(nil, fn value -> {:ok, value} end)
      nil

  """
  @spec and_then(value(), (any() -> any())) :: any()
  def and_then(value, fun)
  def and_then(nil, _fun), do: nil
  def and_then({:ok, value}, fun), do: fun.(value)
  def and_then({:error, _} = error, _fun), do: error

  def and_then(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        fun.(payload)

      :error ->
        tuple

      _ ->
        fun.(tuple)
    end
  end

  def and_then(other, fun), do: fun.(other)

  @doc """
  Transforms the success value inside an `{:ok, value}` tuple or some value by applying a function to it.

  For Result types (`{:ok, value}` or `{:error, reason}`), applies the function to the value
  if it's `{:ok, _}`, otherwise returns the error unchanged.

  For Option types (`nil` or any value), applies the function to the value if it's not `nil`,
  otherwise returns `nil`.

  ## Examples

      iex> Err.map({:ok, 5}, fn num -> num * 2 end)
      {:ok, 10}

      iex> Err.map({:ok, "hello"}, &String.upcase/1)
      {:ok, "HELLO"}

      iex> Err.map({:error, :timeout}, fn num -> num * 2 end)
      {:error, :timeout}

      iex> Err.map(nil, fn num -> num * 2 end)
      nil

      iex> Err.map("hello", &String.upcase/1)
      "HELLO"

  """
  @spec map(value(), (any() -> any())) :: value()
  def map(value, fun)
  def map(nil, _fun), do: nil
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _fun), do: error

  def map(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        List.to_tuple([:ok, fun.(payload)])

      :error ->
        tuple

      _ ->
        fun.(tuple)
    end
  end

  def map(other, fun), do: fun.(other)

  @doc """
  Transforms the error inside an `{:error, reason}` tuple by applying a function to it.

  For Result types (`{:ok, value}` or `{:error, reason}`), applies the function to the error
  if it's `{:error, _}`, otherwise returns the ok tuple unchanged.

  Ignores `nil` and non-Result values, returning them unchanged.

  ## Examples

      iex> Err.map_err({:error, 404}, fn code -> "HTTP \#{code}" end)
      {:error, "HTTP 404"}

      iex> Err.map_err({:ok, "success"}, fn reason -> "\#{reason}_error" end)
      {:ok, "success"}

      iex> Err.map_err(nil, fn reason -> "\#{reason}_error" end)
      nil

      iex> Err.map_err(404, fn reason -> "\#{reason}_error" end)
      404

  """
  @spec map_err(value(), (any() -> any())) :: value()
  def map_err(value, fun)
  def map_err(nil, _fun), do: nil
  def map_err({:ok, _} = ok, _fun), do: ok
  def map_err({:error, reason}, fun), do: {:error, fun.(reason)}

  def map_err(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        tuple

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        List.to_tuple([:error, fun.(payload)])

      _ ->
        tuple
    end
  end

  def map_err(other, _fun), do: other

  @doc """
  Checks if a value is an `{:ok, ...}` result tuple.

  Returns `true` for any tuple starting with `:ok`, `false` otherwise.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_ok({:ok, 1})
      true

      iex> Err.is_ok({:ok, 1, 2})
      true

      iex> Err.is_ok({:error, :timeout})
      false

      iex> Err.is_ok(nil)
      false

      iex> Err.is_ok("value")
      false

      def my_function(result) when is_ok(result)

  """
  @spec is_ok(any()) :: boolean()
  defguard is_ok(value) when is_tuple(value) and tuple_size(value) >= 2 and elem(value, 0) == :ok

  @doc """
  Checks if a value is an `{:error, ...}` result tuple.

  Returns `true` for any tuple starting with `:error`, `false` otherwise.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_err({:error, :timeout})
      true

      iex> Err.is_err({:error, 404, "Not Found"})
      true

      iex> Err.is_err({:ok, 1})
      false

      iex> Err.is_err(nil)
      false

      iex> Err.is_err("error")
      false

      def my_function(result) when is_err(result)

  """
  @spec is_err(any()) :: boolean()
  defguard is_err(value)
           when is_tuple(value) and tuple_size(value) >= 2 and elem(value, 0) == :error

  @doc """
  Checks if a value is "some" (not `nil`).

  Returns `true` for any value except `nil`.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_some(1)
      true

      iex> Err.is_some("hello")
      true

      iex> Err.is_some({:ok, 1})
      true

      iex> Err.is_some(false)
      true

      iex> Err.is_some(nil)
      false

      def my_function(value) when is_some(value)

  """
  @spec is_some(any()) :: boolean()
  defguard is_some(value) when value != nil

  @doc """
  Flattens a nested result into a single layer.

  If the outer result is `{:ok, inner}` and inner is also a result tuple,
  returns the inner result. Otherwise returns the value unchanged.

  ## Examples

      iex> Err.flatten({:ok, {:ok, 1}})
      {:ok, 1}

      iex> Err.flatten({:ok, {:ok, 1, :meta}})
      {:ok, 1, :meta}

      iex> Err.flatten({:ok, {:error, :timeout}})
      {:error, :timeout}

      iex> Err.flatten({:error, :failed})
      {:error, :failed}

      iex> Err.flatten({:ok, "value"})
      {:ok, "value"}

  """
  @spec flatten(value()) :: result()
  def flatten(value)
  def flatten({:ok, {:ok, _} = inner}), do: inner
  def flatten({:ok, {:error, _} = inner}), do: inner

  def flatten({:ok, inner} = outer) when is_tuple(inner) do
    case elem(inner, 0) do
      :ok -> inner
      :error -> inner
      _ -> outer
    end
  end

  def flatten(other), do: other

  @doc """
  Combines a list of values into a single result.

  - If all values are `{:ok, value}`, returns `{:ok, list_of_values}`.
  - If any value is an error, returns the first error encountered (fail fast).
  - If any value is `nil`, returns `nil`

  ## Examples

      iex> Err.all([{:ok, 1}, {:ok, 2}, {:ok, 3}])
      {:ok, [1, 2, 3]}

      iex> Err.all([{:ok, 1}, {:error, :timeout}, {:ok, 3}])
      {:error, :timeout}

      iex> Err.all([{:ok, 1}, nil, {:ok, 3}])
      nil

      iex> Err.all([])
      {:ok, []}

      iex> Err.all([{:ok, "a"}, {:ok, "b"}])
      {:ok, ["a", "b"]}

  """
  @spec all([value()]) :: value()
  def all(values) do
    all_impl(values, [])
  end

  defp all_impl([], acc), do: {:ok, Enum.reverse(acc)}

  defp all_impl([nil | _], _acc), do: nil

  defp all_impl([{:ok, value} | rest], acc) do
    all_impl(rest, [value | acc])
  end

  defp all_impl([{:error, _} = error | _], _acc), do: error

  defp all_impl([tuple | rest], acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        all_impl(rest, [payload | acc])

      :error ->
        tuple

      _ ->
        all_impl(rest, [tuple | acc])
    end
  end

  defp all_impl([value | rest], acc) do
    all_impl(rest, [value | acc])
  end

  @doc """
  Extracts all success values from a list of results.

  Returns a list containing all values, except `{:error, _}` tuples or `nil`.

  ## Examples

      iex> Err.values([{:ok, 1}, {:error, :timeout}, {:ok, 2}])
      [1, 2]

      iex> Err.values([{:ok, 1}, nil, 2])
      [1, 2]

      iex> Err.values([{:ok, "a"}, {:ok, "b"}])
      ["a", "b"]

      iex> Err.values([{:error, :x}, {:error, :y}])
      []

      iex> Err.values([1])
      [1]

      iex> Err.values([])
      []

  """
  @spec values([value()]) :: list()
  def values(results) do
    values_impl(results, [])
  end

  defp values_impl([], acc), do: Enum.reverse(acc)

  defp values_impl([nil | rest], acc) do
    values_impl(rest, acc)
  end

  defp values_impl([{:ok, value} | rest], acc) do
    values_impl(rest, [value | acc])
  end

  defp values_impl([{:error, _} | rest], acc) do
    values_impl(rest, acc)
  end

  defp values_impl([tuple | rest], acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        values_impl(rest, [payload | acc])

      :error ->
        values_impl(rest, acc)

      _ ->
        values_impl(rest, [tuple | acc])
    end
  end

  defp values_impl([value | rest], acc) do
    values_impl(rest, [value | acc])
  end

  @doc """
  Splits a list of results into ok values and error values.

  Returns a tuple `{ok_values, error_values}` where:
  - `ok_values` contains all values from `{:ok, value}` tuples
  - `error_values` contains all values from `{:error, reason}` tuples

  Any other value is ignored.

  ## Examples

      iex> Err.partition([{:ok, 1}, {:error, "a"}, {:ok, 2}])
      {[1, 2], ["a"]}

      iex> Err.partition([1, nil])
      {[], []}

      iex> Err.partition([{:ok, "x"}, {:ok, "y"}])
      {["x", "y"], []}

      iex> Err.partition([{:error, :timeout}, {:error, :crash}])
      {[], [:timeout, :crash]}

      iex> Err.partition([])
      {[], []}

  """
  @spec partition([value()]) :: {ok_values :: any(), error_values :: any()}
  def partition(results) do
    partition_impl(results, [], [])
  end

  defp partition_impl([], ok_acc, err_acc) do
    {Enum.reverse(ok_acc), Enum.reverse(err_acc)}
  end

  defp partition_impl([{:ok, value} | rest], ok_acc, err_acc) do
    partition_impl(rest, [value | ok_acc], err_acc)
  end

  defp partition_impl([{:error, reason} | rest], ok_acc, err_acc) do
    partition_impl(rest, ok_acc, [reason | err_acc])
  end

  defp partition_impl([tuple | rest], ok_acc, err_acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        partition_impl(rest, [payload | ok_acc], err_acc)

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        partition_impl(rest, ok_acc, [payload | err_acc])

      _ ->
        partition_impl(rest, ok_acc, err_acc)
    end
  end

  defp partition_impl([_value | rest], ok_acc, err_acc) do
    partition_impl(rest, ok_acc, err_acc)
  end

  @doc """
  Replaces the value inside an `{:ok, value}` tuple with a new value.

  If the result is `{:ok, _}`, returns `{:ok, new_value}`.
  Otherwise returns the original value unchanged.

  ## Examples

      iex> Err.replace({:ok, "old"}, "new")
      {:ok, "new"}

      iex> Err.replace({:error, :timeout}, 999)
      {:error, :timeout}

      iex> Err.replace(nil, 999)
      nil

      iex> Err.replace(100, 999)
      100

  """
  @spec replace(value(), any()) :: value()
  def replace({:ok, _}, new_value), do: {:ok, new_value}
  def replace({:error, _} = error, _new_value), do: error

  def replace(tuple, new_value) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> {:ok, new_value}
      _ -> tuple
    end
  end

  def replace(other, _new_value), do: other

  @doc """
  Replaces the value inside an `{:ok, value}` tuple by calling a function.

  If the result is `{:ok, _}`, calls the function and returns `{:ok, result}`.
  Otherwise returns the original value unchanged without calling the function.

  This is the lazy version of `replace/2` - the function is only called when needed.

  ## Examples

      iex> Err.replace_lazy({:ok, 1}, fn value -> value + 1 end)
      {:ok, 2}

      iex> Err.replace_lazy({:error, :timeout}, fn value -> value + 1 end)
      {:error, :timeout}

      iex> Err.replace_lazy(nil, fn value -> value + 1 end)
      nil

  """
  @spec replace_lazy(value(), (any() -> any())) :: value()
  def replace_lazy({:ok, value}, fun), do: {:ok, fun.(value)}
  def replace_lazy({:error, _} = error, _fun), do: error

  def replace_lazy(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        value = elem(tuple, 1)
        {:ok, fun.(value)}

      _ ->
        tuple
    end
  end

  def replace_lazy(other, _fun), do: other

  @doc """
  Replaces the error inside an `{:error, reason}` tuple with a new value.

  If the result is `{:error, _}`, returns `{:error, new_error}`.
  Otherwise returns the original value unchanged.

  ## Examples

      iex> Err.replace_err({:error, :timeout}, :network_error)
      {:error, :network_error}

      iex> Err.replace_err({:error, 404}, :not_found)
      {:error, :not_found}

      iex> Err.replace_err({:ok, 1}, :error)
      {:ok, 1}

      iex> Err.replace_err(nil, :error)
      nil

  """
  @spec replace_err(value(), any()) :: value()
  def replace_err({:ok, _} = ok, _new_error), do: ok
  def replace_err({:error, _}, new_error), do: {:error, new_error}

  def replace_err(tuple, new_error) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error -> {:error, new_error}
      _ -> tuple
    end
  end

  def replace_err(other, _new_error), do: other

  @doc """
  Replaces the error inside an `{:error, reason}` tuple by calling a function.

  If the result is `{:error, _}`, calls the function and returns `{:error, result}`.
  Otherwise returns the original value unchanged without calling the function.

  This is the lazy version of `replace_err/2` - the function is only called when needed.

  ## Examples

      iex> Err.replace_err_lazy({:error, 404}, fn value -> "Status: \#{value}" end)
      {:error, "Status: 404"}

      iex> Err.replace_err_lazy({:ok, 1}, fn _ -> :error end)
      {:ok, 1}

      iex> Err.replace_err_lazy(nil, fn _ -> :error end)
      nil

  """
  @spec replace_err_lazy(any(), (any() -> any())) :: any()
  def replace_err_lazy({:ok, _} = ok, _fun), do: ok
  def replace_err_lazy({:error, reason}, fun), do: {:error, fun.(reason)}

  def replace_err_lazy(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error ->
        reason = elem(tuple, 1)
        {:error, fun.(reason)}

      _ ->
        tuple
    end
  end

  def replace_err_lazy(other, _fun), do: other

  @doc """
  Returns the first value if it is present/successful, otherwise returns the second value.

  For Result types (`{:ok, value}` or `{:error, reason}`), returns the first value if it's `{:ok, _}`,
  otherwise returns the second value.

  For Option types (`nil` or any value), returns the first value if it's not `nil`,
  otherwise returns the second value.

  ## Examples

      iex> Err.or_else({:ok, "cache.db"}, {:ok, "disk.db"})
      {:ok, "cache.db"}

      iex> Err.or_else({:ok, "cache.db"}, {:error, :unavailable})
      {:ok, "cache.db"}

      iex> Err.or_else({:error, :cache_miss}, {:ok, "disk.db"})
      {:ok, "disk.db"}

      iex> Err.or_else({:error, :cache_miss}, {:error, :disk_full})
      {:error, :disk_full}

      iex> Err.or_else("primary", "backup")
      "primary"

      iex> Err.or_else(nil, "backup")
      "backup"

  """
  @spec or_else(value(), value()) :: value()
  def or_else(nil, second), do: second
  def or_else({:ok, _} = first, _second), do: first
  def or_else({:error, _}, second), do: second
  def or_else(first, _second), do: first

  @doc """
  Returns the first value if it is present/successful, otherwise calls the function to compute
  an alternative value.

  For Result types (`{:ok, value}` or `{:error, reason}`), returns the first value if it's `{:ok, _}`,
  otherwise calls the function with the error reason.

  For Option types (`nil` or any value), returns the first value if it's not `nil`,
  otherwise calls the function.

  This is the lazy version of `or_else/2` - the function is only called when needed.

  ## Examples

      iex> Err.or_else_lazy({:ok, "cache.db"}, fn _ -> {:ok, "disk.db"} end)
      {:ok, "cache.db"}

      iex> Err.or_else_lazy({:error, :cache_miss}, fn _reason -> {:ok, "disk.db"} end)
      {:ok, "disk.db"}

      iex> Err.or_else_lazy({:error, :timeout}, fn reason -> {:error, "Fallback failed: \#{reason}"} end)
      {:error, "Fallback failed: timeout"}

      iex> Err.or_else_lazy("primary", fn _ -> "backup" end)
      "primary"

      iex> Err.or_else_lazy(nil, fn _ -> "backup" end)
      "backup"

  """
  @spec or_else_lazy(value(), (any() -> any())) :: value()
  def or_else_lazy(value, fun)
  def or_else_lazy(nil, fun), do: fun.(nil)
  def or_else_lazy({:ok, _} = first, _fun), do: first
  def or_else_lazy({:error, reason}, fun), do: fun.(reason)
  def or_else_lazy(first, _fun), do: first

  @spec wrap(atom() | keyword()) :: struct()
  @spec wrap(atom(), keyword()) :: struct()
  def wrap(exception, opts \\ [])

  def wrap(exception, opts) when is_atom(exception) do
    struct(exception, opts)
  end

  def wrap(opts, _) do
    struct(Err.GenericError, opts)
  end

  @spec message(struct()) :: String.t()
  def message(%_{mod: mod, reason: reason}) when not is_nil(mod) do
    mod.format_error(reason)
  end

  def message(exception) do
    Exception.message(exception)
  end
end
