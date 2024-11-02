defmodule Chat.Server do
  use GenServer
  require Logger

  @ets_table Chat.Table

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: {:global, :chat_server})
  end

  @impl true
  def init(:ok) do
    Logger.info("Chat.Server created, with ETS table #{@ets_table}.")
    {:ok, %{}}
  end

  def set_nick(pid, nickname) do
    GenServer.call({:global, :chat_server}, {:set_nick, pid, nickname})
  end

  def get_all_nicknames() do
    GenServer.call({:global, :chat_server}, :get_all_nicknames)
  end

  def remove_nickname(pid) do
    GenServer.call({:global, :chat_server}, {:remove_nickname, pid})
  end

  def get_pid_by_nickname(nickname) do
    GenServer.call({:global, :chat_server}, {:get_pid_by_nickname, nickname})
  end

  def send_message(from_nickname, to_nickname, message) do
    GenServer.call({:global, :chat_server}, {:send_message, from_nickname, to_nickname, message})
  end

  def get_nickname_by_pid(pid) do
    GenServer.call({:global, :chat_server}, {:get_nickname_by_pid, pid})
  end

  @impl true
  def handle_call({:set_nick, pid, nickname}, _, state) do
    case :ets.lookup(@ets_table, nickname) do
      [{^nickname, ^pid}] ->
        {:reply, :ok, state}

      [{^nickname, _}] ->
        {:reply, {:error, :nickname_taken}, state}

      [] ->
        # Check if the PID already has a nickname
        case get_nickname_by_pid_direct(pid) do
          {:ok, old_nickname} ->
            # Delete the old nickname
            :ets.delete(@ets_table, old_nickname)

            Logger.info(
              "Client #{inspect(pid)} changed nickname from #{old_nickname} to #{nickname}."
            )

          :error ->
            Logger.info("Client #{inspect(pid)} set new nickname #{nickname}.")
        end

        # Insert the new nickname and associate it with the pid
        :ets.insert(@ets_table, {nickname, pid})
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:remove_nickname, pid}, _, state) do
    case get_nickname_by_pid_direct(pid) do
      :error ->
        # No nickname found for this PID
        {:reply, {:error, :not_found}, state}

      {:ok, nickname} ->
        # Remove the nickname from the ETS table
        :ets.delete(@ets_table, nickname)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:get_all_nicknames, _, state) do
    # Retrieve only the nicknames from the ETS table
    nicknames = :ets.select(@ets_table, [{{:"$1", :_}, [], [:"$1"]}])
    {:reply, nicknames, state}
  end

  @impl true
  def handle_call({:get_pid_by_nickname, nickname}, _, state) do
    result =
      case :ets.lookup(@ets_table, nickname) do
        [{^nickname, pid}] -> {:ok, pid}
        [] -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:send_message, from_nickname, to_nickname, message}, _, state) do
    # Look up the PID for the sender's nickname
    case get_pid_by_nickname_direct(from_nickname) do
      {:ok, _} ->
        # Look up the PID for the receiver's nickname
        case get_pid_by_nickname_direct(to_nickname) do
          {:ok, to_pid} ->
            # Send the message to the receiver's PID
            send(to_pid, {:chat_message, from_nickname, message})
            {:reply, :ok, state}

          {:error, :not_found} ->
            # Receiver's nickname not found
            {:reply, {:error, :to_nickname_not_found}, state}
        end

      {:error, :not_found} ->
        # Sender's nickname not found
        {:reply, {:error, :from_nickname_not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_nickname_by_pid, pid}, _, state) do
    case :ets.match_object(@ets_table, {:"$1", pid}) do
      [{nickname, ^pid}] ->
        {:reply, {:ok, nickname}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  # Directly retrieves the nickname associated with a PID without GenServer.call
  defp get_nickname_by_pid_direct(pid) do
    case :ets.match_object(@ets_table, {:"$1", pid}) do
      [{nickname, ^pid}] -> {:ok, nickname}
      [] -> :error
    end
  end

  # Directly retrieves the PID associated with a nickname without GenServer.call
  defp get_pid_by_nickname_direct(nickname) do
    case :ets.lookup(@ets_table, nickname) do
      [{^nickname, pid}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end
