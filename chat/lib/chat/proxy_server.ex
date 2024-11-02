defmodule Chat.ProxyServer do
  require Logger

  # Create listening socket on the server
  def start(port \\ 6666) do
    opts = [:binary, active: true, packet: :line, reuseaddr: true]
    {:ok, listen_socket} = :gen_tcp.listen(port, opts)
    Logger.info("#{inspect(self())}: listening on port #{port}, socket #{inspect(listen_socket)}")
    accept(listen_socket)
  end

  # Spawn a process for each accepted socket
  def accept(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    pid = spawn(fn -> loop(socket) end)
    :gen_tcp.controlling_process(socket, pid)
    Logger.info("#{inspect(pid)} spawned to handle #{inspect(socket)}")
    accept(listen_socket)
  end

  # Handles incoming messages for the socket
  def loop(socket) do
    receive do
      {:tcp, ^socket, data} ->
        parse_message(normalize_input(data), socket)
        loop(socket)

      {:tcp_closed, ^socket} ->
        Chat.Server.remove_nickname(self())

        Logger.info(
          "#{inspect(self())}: closing socket #{inspect(socket)} and releasing nickname"
        )

        :ok = :gen_tcp.close(socket)

      # Handle chat messages from other processes
      {:chat_message, from_nickname, message} ->
        Logger.info("Received message from #{from_nickname} to #{inspect(self())}: #{message}")

        send_response(socket, "[#{from_nickname}]: #{message}")
        loop(socket)
    end
  end

  # Ensure each message received is in a valid format to be processed
  defp normalize_input(data) do
    data
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  # Ensure only one argument is processed for NICK/N, the rest are ignored
  defp parse_message("/NICK " <> args, socket) do
    [nick | _] = String.split(args, " ", parts: 2)
    validate_nick(nick, socket)
  end

  defp parse_message("/N " <> args, socket) do
    [nick | _] = String.split(args, " ", parts: 2)
    validate_nick(nick, socket)
  end

  # Parse the line to send information to nicknames
  defp parse_message("/SEND " <> args, socket) do
    case Chat.Server.get_nickname_by_pid(self()) do
      {:error, :not_found} ->
        send_response(socket, "You must set a nickname before using /SEND.")

      {:ok, from_nickname} ->
        case String.split(args, " ", parts: 2) do
          [names, message] when message != "" ->
            names_list = String.split(names, ";")
            handle_send(names_list, message, socket, from_nickname)

          _ ->
            send_response(socket, "Invalid format. Usage: /SEND nickname(s) message")
        end
    end
  end

  defp parse_message("/S " <> args, socket) do
    case Chat.Server.get_nickname_by_pid(self()) do
      {:error, :not_found} ->
        send_response(socket, "You must set a nickname before using /S.")

      {:ok, from_nickname} ->
        case String.split(args, " ", parts: 2) do
          [names, message] when message != "" ->
            names_list = String.split(names, ";")
            handle_send(names_list, message, socket, from_nickname)

          _ ->
            send_response(socket, "Invalid format. Usage: /S nickname(s) message")
        end
    end
  end

  # Ignore any arguments after the command
  defp parse_message("/LIST", socket), do: handle_list(socket)
  defp parse_message("/L", socket), do: handle_list(socket)

  # Validate input for BCAST
  defp parse_message("/BCAST " <> args, socket) do
    case Chat.Server.get_nickname_by_pid(self()) do
      {:error, :not_found} ->
        send_response(socket, "You must set a nickname before using /BCAST.")

      {:ok, from_nickname} ->
        handle_bcast(args, socket, from_nickname)
    end
  end

  defp parse_message("/B " <> args, socket) do
    case Chat.Server.get_nickname_by_pid(self()) do
      {:error, :not_found} ->
        send_response(socket, "You must set a nickname before using /B.")

      {:ok, from_nickname} ->
        handle_bcast(args, socket, from_nickname)
    end
  end

  # Handle invalid commands
  defp parse_message(_, socket) do
    error_message =
      "ERROR: Invalid command. Valid commands are: " <>
        "/NICK or /N (One word minimum), " <>
        "/LIST or /L, " <>
        "/BCAST or /B (One word minimum), " <>
        "/SEND or /S (Two words minimum)."

    send_error(socket, error_message)
    Logger.info("User input a invalid command")
  end

  # Validate the nickname
  defp validate_nick(name, socket) do
    regex = ~r/^[A-Za-z][A-Za-z0-9_]{0,9}$/

    cond do
      String.length(name) > 10 ->
        send_error(socket, "Nickname cannot exceed 10 characters.")

      Regex.match?(regex, name) ->
        # Attempt to set the nickname via Chat.Server
        case Chat.Server.set_nick(self(), name) do
          :ok ->
            send_response(socket, "Nickname successfully set to #{name}")

          {:error, reason} ->
            send_error(socket, "Error: #{reason} - nickname is already in use !")
            Logger.info("Client #{inspect(self())} failed to set nickname to #{name}: #{reason}")
        end

      # Covers names where the first element is invalid, or contains invalid characters
      true ->
        send_error(
          socket,
          "Invalid nickname. Must start with a letter and contain only letters, numbers, or underscores."
        )

        Logger.info("Client #{inspect(self())} provided invalid nickname '#{name}'.")
    end
  end

  # Call functions from Chat.Server to retrieve users
  defp handle_list(socket) do
    case Chat.Server.get_all_nicknames() do
      [] ->
        send_response(socket, "No users currently connected.")

        Logger.info("Client #{inspect(self())} retrieved nicknames, but table is empty.")

      nicknames ->
        users_list = Enum.join(nicknames, ", ")
        send_response(socket, "Connected users: #{users_list}")
        Logger.info("Client #{inspect(self())} retrieved nicknames.")
    end
  end

  # Send messages to registered users
  defp handle_send(nicknames, message, socket, from_nickname) do
    for nickname <- nicknames do
      case Chat.Server.get_pid_by_nickname(nickname) do
        {:ok, _pid} ->
          send_response(socket, "Message sent to #{nickname}")
          Chat.Server.send_message(from_nickname, nickname, message)

        {:error, :not_found} ->
          send_response(socket, "Nickname #{nickname} not registered.")
      end
    end
  end

  # Send a message to all registered users
  defp handle_bcast(message, socket, from_nickname) do
    case Chat.Server.get_all_nicknames() do
      [] ->
        send_response(socket, "No users currently connected.")

      nicknames ->
        for nickname <- nicknames do
          case Chat.Server.get_pid_by_nickname(nickname) do
            {:ok, _pid} ->
              # Send the broadcast message to each user's PID
              Chat.Server.send_message(from_nickname, nickname, message)
              send_response(socket, "Message broadcasted to #{nickname}")

            {:error, :not_found} ->
              nil
          end
        end
    end
  end

  # Send a successful response to the client
  defp send_response(socket, message) do
    :gen_tcp.send(socket, "#{message}\n")
  end

  # Send an error message to the client
  defp send_error(socket, error_message) do
    :gen_tcp.send(socket, "#{error_message}\n")
  end
end
