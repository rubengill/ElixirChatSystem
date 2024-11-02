# Elixir Chat System

An Elixir-based real-time messaging platform created with Elixir to facilitate communication between users over TCP connections. This system supports setting nicknames, listing active users, sending direct messages, and broadcasting messages to all users. A Java client is provided to interact with the chat server seamlessly.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Starting the Chat Server](#starting-the-chat-server)
  - [Starting the Proxy Server](#starting-the-proxy-server)
  - [Running the Java Client](#running-the-java-client)
- [Commands](#commands)
  - [Setting a Nickname](#setting-a-nickname)
  - [Listing Active Users](#listing-active-users)
  - [Sending Direct Messages](#sending-direct-messages)
  - [Broadcasting Messages](#broadcasting-messages)
- [Testing](#testing)
- [License](#license)

## Features

- **Nickname Management**: Users can set and change their unique nicknames.
- **User Listing**: Retrieve a list of all active nicknames.
- **Direct Messaging**: Send messages to specific users.
- **Broadcast Messaging**: Send messages to all registered users.
- **Concurrent Connections**: Supports multiple simultaneous TCP connections.
- **Error Handling**: Validates commands and provides appropriate feedback.
- **Persistent State**: Utilizes ETS tables for state management and crash recovery.
- **Multiple Nodes**: Proxy Servers can be ran on different nodes

## Architecture

The system consists of two main Elixir modules and a Java client:

1. **Chat.Server**
   - **Type**: GenServer
   - **Role**: A globally-registered GenServer that manages nicknames and message handling using ETS tables.

2. **Chat.ProxyServer**
   - **Type**: Proxy Server
   - **Role**: Handles incoming TCP connections, spawns proxy processes for each client, each process interfaces with the `Chat.Server`.

3. **Java Client**
   - **Functionality**: Connects to the `Chat.ProxyServer`, allows users to input commands, and displays messages from other users.

## Requirements

Ensure the following software is installed on your system to successfully set up and run the Chat System:

- **Elixir**: Version `1.17.2`
- **Erlang/OTP**: Version `27.0`
- **Java**: JDK `17`
- **Mix**: Included with Elixir for managing projects

### Installation Links

- **Elixir**: [Installation Guide](https://elixir-lang.org/install.html)

> **Note:** These are the versions used during development and testing. While newer versions may be compatible, using these specific versions ensures compatibility and reduces the likelihood of encountering unexpected issues.

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/rubengill/ElixirChatSystem.git
cd ElixirChatSystem
```

### 2. Compile the Elixir Project
```bash
mix compile
```

### 3. Start the Chat.Server
```bash
iex -S mix
```

### 4. Start the Chat.ProxyServer
```bash
Chat.ProxyServer.start()
```

### 5. Compile the Java Client 
> **Note:** Ensure in the root mix directory
```bash
javac ChatClient.java
```

### 6. Run the Java Client 
> **Note:** Ensure in the root mix directory
```bash
java ChatClient
```

## Commands

Users interact with the chat system using specific commands. Commands are case-sensitive.

### Setting a Nickname

- **Command Variants**: `/NICK`, `/N`
- **Usage**: `/NICK <nickname>`
  - `<nickname>`: The nickname to register the process.

**Rules**:
- Must start with an alphabet.
- Can contain alphanumeric characters and underscores.
- Maximum length of 10 characters.
- Nicknames must be unique.
- Required before sending or receiving messages.

**Examples**:
- `/NICK homer`
- `/N homer`

**Responses**:
- **Success**: Confirmation message.
- **Failure**: Error indicating nickname is invalid or already in use.

### Listing Active Users

- **Command Variants**: `/LIST`, `/L`
- **Usage**: `/LIST`

**Description**: Retrieves a list of all currently registered nicknames.

**Examples**:
- `/LIST`
- `/L`

### Sending Direct Messages

- **Command Variants**: `/SEND`, `/S`
- **Usage**: `/SEND <nicknames> <message>`
  - `<nicknames>`: One or more nicknames separated by semicolons (;).
  - `<message>`: The message to be sent.

**Examples**:
- `/SEND homer hello world`
- `/S homer;bart hello everyone`

**Responses**:
- **Success**: Message delivered confirmation.
- **Failure**: Error indicating invalid recipients.

### Broadcasting Messages

- **Command Variants**: `/BCAST`, `/B`
- **Usage**: `/BCAST <message>`

**Examples**:
- `/BCAST hello all`
- `/B this is a broadcast message`

**Responses**:
- **Success**: Message broadcast confirmation.
- **Failure**: No users to broadcast message too.

---

## Testing

To ensure the chat system functions correctly, follow these testing steps:

1. **Start the Chat Server and Proxy Server**
   - Run the following command:
     ```
     iex -S mix
     Chat.ProxyServer.start()
     ```

2. **Run Multiple Java Clients**
   - Open multiple terminal windows and run the Java client in each:
   > **Note:** Ensure ChatClient.java is compiled
     ```
     java ChatClient
     ```

3. **Set Nicknames**
   - In each client, set a unique nickname:
     ```
     /NICK user1
     /NICK user2
     ```

4. **List Active Users**
   - Use the `/LIST` command to verify active nicknames:
     ```
     /LIST
     ```

5. **Send Direct Messages**
   - From `user1`, send a message to `user2`:
     ```
     /SEND user2 Hello, user2!
     ```

6. **Broadcast Messages**
   - From `user1`, broadcast a message to all users:
     ```
     /BCAST Hello!
     ```

7. **Change Nicknames**
   - Change a user's nickname and ensure the update reflects across all clients:
     ```
     /NICK newUser1
     ```

8. **Invalid Commands**
   - Test invalid commands to ensure proper error handling:
     ```
     /RANDOM
     /SEND hello
     /NICK
     ```

---

## License

This project is licensed under the MIT License.
