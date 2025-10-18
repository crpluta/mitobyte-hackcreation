# Multiplayer Setup Guide

## Overview
This game now supports WiFi-based multiplayer using Godot's built-in ENet networking. One player hosts the game (acting as both server and player), while others connect as clients.

## Features
- **LAN/WiFi Multiplayer**: Play with friends on the same network
- **Quest Locking**: Quests can only be accepted by one player at a time
- **Position Synchronization**: See other players move in real-time
- **Player Names**: Each player has a unique name displayed above their character

---

## Quick Start Guide

### For the HOST (Your Machine)

1. **Launch the Game**
   - Run the game executable or press F5 in Godot Editor

2. **Open Multiplayer Lobby**
   - From the title screen, click **"Multiplayer"**

3. **Enter Your Details**
   - **Player Name**: Enter your name (e.g., "Alice")
   - **Port**: Leave as `7777` (or choose a different port)
   - **IP**: Ignore this field (it's for clients)

4. **Host the Game**
   - Click **"Host Game"**
   - You should see: "Server started!"

5. **Find Your IP Address**
   - **On Windows**:
     - Open Command Prompt (cmd)
     - Type: `ipconfig`
     - Look for "IPv4 Address" under your WiFi adapter
     - Example: `192.168.1.5`

   - **On Mac/Linux**:
     - Open Terminal
     - Type: `ifconfig` or `ip addr`
     - Look for your WiFi adapter's inet address
     - Example: `192.168.1.5`

6. **Share Your IP with Players**
   - Tell your friends: "Connect to `192.168.1.5` port `7777`"

7. **Wait for Players**
   - You'll see players appear in the "Players" list as they connect

8. **Start the Game**
   - Once everyone has joined, click **"Start Game"**
   - This will load everyone into the main game

---

### For CLIENTS (Other Players)

1. **Get Connection Info from Host**
   - Ask the host for their **IP address** and **port number**
   - Example: `192.168.1.5` and `7777`

2. **Launch the Game**
   - Run the game executable or press F5 in Godot Editor

3. **Open Multiplayer Lobby**
   - From the title screen, click **"Multiplayer"**

4. **Enter Connection Details**
   - **Player Name**: Enter your unique name (e.g., "Bob")
   - **Server IP**: Enter the host's IP address (e.g., `192.168.1.5`)
   - **Port**: Enter the port number (e.g., `7777`)

5. **Join the Game**
   - Click **"Join Game"**
   - You should see: "Connected to server!"
   - Your name will appear in the host's player list

6. **Wait for Host to Start**
   - The host will start the game when ready
   - You'll automatically be loaded into the game

---

## In-Game Multiplayer Features

### Quest System
- **Quest Locking**: When you accept a quest from Deckard Cain or a quest giver, it becomes locked to you
- **Other Players**: Will see "(Taken by [YourName])" on locked quests
- **Quest Release**: Quests are automatically unlocked when:
  - You complete the quest
  - You disconnect from the game

### Player Movement
- **Real-time Sync**: All player positions are synchronized automatically
- **Name Tags**: Each player has their name displayed above their head
- **Controls**: Same as solo mode (WASD to move, Shift to sprint)

### Shared World
- All players share the same game world
- NPCs and environment are visible to everyone
- Quest progress is individual (not shared)

---

## Troubleshooting

### "Failed to create server"
- **Solution**: Port might be in use. Try a different port number (e.g., 7778, 7779)

### "Connection failed" (Client)
- **Check IP Address**: Make sure you entered the correct host IP
- **Check Port**: Ensure you're using the same port as the host
- **Firewall**: The host may need to allow the port through their firewall
- **Same Network**: Both host and client must be on the same WiFi network

### "Players can see each other but can't accept quests"
- This is normal - only one player can accept a given quest
- Try different quests or wait for other players to complete theirs

### Camera not following my character
- This should auto-fix after spawning
- If not, restart the game and reconnect

---

## Network Configuration

### Default Settings
- **Protocol**: ENet (UDP-based)
- **Port**: 7777
- **Max Players**: 8 (including host)

### Firewall Configuration (if needed)

**Windows Firewall:**
1. Open Windows Defender Firewall
2. Click "Advanced settings"
3. Click "Inbound Rules" → "New Rule"
4. Choose "Port" → Click "Next"
5. Select "UDP" → Enter port 7777 → Click "Next"
6. Allow the connection → Click "Next"
7. Name it "Godot Game" → Click "Finish"

**Mac Firewall:**
1. System Preferences → Security & Privacy → Firewall
2. Click "Firewall Options"
3. Add your game application
4. Set to "Allow incoming connections"

---

## Advanced: Running a Dedicated Server

If you want to run the game as a headless server (no graphics):

1. Export the game as a server build
2. Run from command line:
   ```bash
   ./YourGame.exe --headless --server --port 7777
   ```
3. Note: This requires additional scripting (not included in current build)

---

## Technical Details

### Architecture
- **Server-Client Model**: Host acts as authoritative server
- **Peer ID 1**: Always the host/server
- **Peer ID 2+**: Clients

### Synchronized Data
- Player position (Vector3)
- Player rotation (Vector3)
- Quest locks (Dictionary)

### RPC Calls
- `register_player`: Client registers their name with server
- `_sync_quest_lock`: Server broadcasts quest assignments
- `_request_quest_lock`: Client requests to accept a quest
- `_sync_quest_unlock`: Server releases a quest

---

## Tips for Best Experience

1. **Use Wired Connection**: If possible, connect via Ethernet for better performance
2. **Close Background Apps**: Reduce network congestion
3. **Same Subnet**: Ensure all players are on the same network subnet
4. **Coordinate Quests**: Communicate with teammates about which quests to take
5. **Host Specs**: The host machine should have decent CPU/RAM (it runs the server)

---

## Known Limitations

- No internet/WAN support (LAN/WiFi only)
- No player collision (players can walk through each other)
- No chat system (use voice chat externally)
- Shop purchases are not synchronized
- Worker NPC assignments are local only

---

## Support

If you encounter issues:
1. Check console output (visible in Godot editor with F5)
2. Verify IP addresses with `ping` command
3. Test with 2 players first before adding more
4. Restart both host and client if connection hangs

Enjoy playing together!
