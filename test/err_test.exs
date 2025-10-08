defmodule ErrTest do
  use ExUnit.Case, async: true
  doctest Err

  test "ok" do
    assert Err.ok(:value) == {:ok, :value}
    assert Err.ok(1 + 2) == {:ok, 3}
  end

  test "error" do
    assert Err.error(:boom) == {:error, :boom}
    assert Err.error(1 + 2) == {:error, 3}
  end

  test "unwrap_or" do
    assert unwrap_or(nil, :not_found) == :not_found
    assert unwrap_or({:ok, 1}, :error) == 1
    assert unwrap_or({:ok, 1, %{source: :user}}, :error) == [1, %{source: :user}]
    assert unwrap_or({:ok, 1, 2, 3}, :error) == [1, 2, 3]
    assert unwrap_or({:error, :boom}, 2) == 2
    assert unwrap_or({:error, :boom, %{code: 500}}, 2) == 2
    assert unwrap_or({:maybe, 1}, :error) == {:maybe, 1}
    assert unwrap_or("car", "bike") == "car"
  end

  test "unwrap_or_lazy" do
    assert unwrap_or_lazy({:ok, :conn}, fn [value] -> to_string(value) end) == :conn

    assert unwrap_or_lazy({:ok, :conn, :meta}, fn _ -> :fallback end) ==
             [:conn, :meta]

    assert unwrap_or_lazy({:error, "error connecting"}, fn message ->
             String.capitalize(message)
           end) == "Error connecting"

    assert unwrap_or_lazy({:error, :boom, %{code: 500}}, fn values -> values end) ==
             [:boom, %{code: 500}]

    assert unwrap_or_lazy(nil, fn [] -> :guest end) == :guest
    assert unwrap_or_lazy("car", fn _ -> :bike end) == "car"
  end

  test "and_then" do
    assert and_then({:ok, 100}, fn count -> "#{count} users" end) == "100 users"

    assert and_then({:ok, :user, %{id: 1}}, fn values -> Enum.reverse(values) end) ==
             [%{id: 1}, :user]

    assert and_then({:error, :db_error}, fn count -> "#{count} users" end) == {:error, :db_error}
    assert and_then(nil, fn value -> value end) == nil
    assert and_then("guest", &String.upcase/1) == "GUEST"
  end

  test "map" do
    assert map({:ok, 5}, fn num -> num * 2 end) == {:ok, 10}
    assert map({:ok, "hello"}, &String.upcase/1) == {:ok, "HELLO"}

    assert map({:ok, :user, %{id: 1}}, fn values -> Enum.reverse(values) end) ==
             {:ok, [%{id: 1}, :user]}

    assert map({:error, :timeout}, fn num -> num * 2 end) == {:error, :timeout}
    assert map(nil, fn num -> num * 2 end) == nil
    assert map("hello", &String.upcase/1) == "HELLO"
  end

  test "map_err" do
    assert map_err({:error, :timeout}, fn reason -> "#{reason}_error" end) ==
             {:error, "timeout_error"}

    assert map_err({:error, 404}, fn code -> "HTTP #{code}" end) == {:error, "HTTP 404"}

    assert map_err({:error, :boom, %{code: 500}}, fn values -> Enum.reverse(values) end) ==
             {:error, [%{code: 500}, :boom]}

    assert map_err({:ok, "success"}, fn reason -> "#{reason}_error" end) == {:ok, "success"}
    assert map_err(nil, fn reason -> "#{reason}_error" end) == nil
  end

  test "is_ok" do
    assert Err.is_ok({:ok, 1})
    assert Err.is_ok({:ok, 1, 2})
    refute Err.is_ok({:error, :timeout})
    refute Err.is_ok(nil)
    refute Err.is_ok("value")
  end

  test "is_err" do
    assert Err.is_err({:error, :timeout})
    assert Err.is_err({:error, 404, "Not Found"})
    refute Err.is_err({:ok, 1})
    refute Err.is_err(nil)
    refute Err.is_err("error")
  end

  test "flatten" do
    assert Err.flatten({:ok, {:ok, 1}}) == {:ok, 1}
    assert Err.flatten({:ok, {:ok, 1, :meta}}) == {:ok, 1, :meta}
    assert Err.flatten({:ok, {:error, :timeout}}) == {:error, :timeout}
    assert Err.flatten({:error, :failed}) == {:error, :failed}
    assert Err.flatten({:ok, "value"}) == {:ok, "value"}
  end

  test "all" do
    assert Err.all([{:ok, 1}, {:ok, 2}, {:ok, 3}]) == {:ok, [1, 2, 3]}
    assert Err.all([{:ok, 1}, {:error, :timeout}, {:ok, 3}]) == {:error, :timeout}
    assert Err.all([]) == {:ok, []}
    assert Err.all([{:ok, "a"}, {:ok, "b"}]) == {:ok, ["a", "b"]}
  end

  test "values" do
    assert Err.values([{:ok, 1}, {:error, :timeout}, {:ok, 2}]) == [1, 2]
    assert Err.values([{:ok, "a"}, {:ok, "b"}]) == ["a", "b"]
    assert Err.values([{:error, :x}, {:error, :y}]) == []
    assert Err.values([]) == []
  end

  test "partition" do
    assert Err.partition([{:ok, 1}, {:error, "a"}, {:ok, 2}]) == {[1, 2], ["a"]}
    assert Err.partition([{:ok, "x"}, {:ok, "y"}]) == {["x", "y"], []}
    assert Err.partition([{:error, :timeout}, {:error, :crash}]) == {[], [:timeout, :crash]}
    assert Err.partition([]) == {[], []}
  end

  test "replace" do
    assert Err.replace({:ok, 1}, 999) == {:ok, 999}
    assert Err.replace({:ok, "old"}, "new") == {:ok, "new"}
    assert Err.replace({:error, :timeout}, 999) == {:error, :timeout}
    assert Err.replace(nil, 999) == nil
  end

  test "replace_lazy" do
    assert Err.replace_lazy({:ok, 1}, fn _ -> 999 end) == {:ok, 999}
    assert Err.replace_lazy({:ok, "old"}, fn _ -> "new" end) == {:ok, "new"}
    assert Err.replace_lazy({:error, :timeout}, fn _ -> 999 end) == {:error, :timeout}
    assert Err.replace_lazy(nil, fn _ -> 999 end) == nil
  end

  test "replace_err" do
    assert Err.replace_err({:error, :timeout}, :network_error) == {:error, :network_error}
    assert Err.replace_err({:error, 404}, :not_found) == {:error, :not_found}
    assert Err.replace_err({:ok, 1}, :error) == {:ok, 1}
    assert Err.replace_err(nil, :error) == nil
  end

  test "replace_err_lazy" do
    assert Err.replace_err_lazy({:error, :timeout}, fn _ -> :network_error end) ==
             {:error, :network_error}

    assert Err.replace_err_lazy({:error, 404}, fn _ -> :not_found end) == {:error, :not_found}
    assert Err.replace_err_lazy({:ok, 1}, fn _ -> :error end) == {:ok, 1}
    assert Err.replace_err_lazy(nil, fn _ -> :error end) == nil
  end

  test "wrap" do
    assert Err.wrap(ArgumentError) == %ArgumentError{message: "argument error"}
    assert Err.wrap(KeyError, key: :id) == %KeyError{key: :id}
    assert Err.wrap(Err.GenericError, reason: :app_error) == %Err.GenericError{reason: :app_error}
    assert Err.wrap(reason: :app_error) == %Err.GenericError{reason: :app_error}
  end

  test "message" do
    assert Err.wrap(ArgumentError) |> Err.message() == "argument error"
    assert Err.wrap(KeyError, key: :id) |> Err.message() == "key :id not found"

    assert Err.wrap(Err.GenericError, reason: :app_error) |> Err.message() ==
             "generic error :app_error"

    assert Err.wrap(ErrTest.CustomError, reason: :boom) |> Err.message() == "custom: :boom"
  end

  test "raise" do
    assert_raise Err.GenericError, fn ->
      raise Err.wrap(reason: :boom)
    end

    assert_raise ErrTest.CustomError, fn ->
      raise Err.wrap(ErrTest.CustomError, reason: :boom)
    end
  end

  test "module override" do
    assert Err.wrap(mod: __MODULE__, reason: :custom) |> Err.message() == "custom error"

    assert Err.wrap(ErrTest.CustomError, mod: __MODULE__, reason: :boom) |> Err.message() ==
             "custom error"
  end

  def format_error(_), do: "custom error"

  defp unwrap_or(value, default), do: Err.unwrap_or(value, default)
  defp unwrap_or_lazy(value, fun), do: Err.unwrap_or_lazy(value, fun)
  defp and_then(value, fun), do: Err.and_then(value, fun)
  defp map(value, fun), do: Err.map(value, fun)
  defp map_err(value, fun), do: Err.map_err(value, fun)

  defmodule CustomError do
    defexception [:mod, :reason]

    @impl true
    def message(%__MODULE__{reason: reason}) do
      "custom: #{inspect(reason)}"
    end
  end
end
