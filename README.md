# GR !need - Discord Webhook Plugin

**Author:** ThatOneRicsi  
**Version:** 1.0.0  
**Website:** https://globalretake.com

## Overview

GR !need is a SourceMod plugin that allows players to send a Discord webhook notification with the `!need` command. When players use this command, a rich Discord message is sent to a configured webhook URL containing server information, player count, map details, and other customizable content.

## Features

- Discord webhook integration
- Player count in embeds
- Map information and images
- Template variables for customization
- Cooldown to prevent spam
- Customizable embed colors
- Custom webhook username and avatar
- Customizable embed fields and footer

## Requirements

- SourceMod 1.11 or later
- **SteamWorks Extension** - This plugin requires the SteamWorks extension to send HTTP requests to Discord

## Disclaimer

This plugin is primarily designed for Discord webhooks, though Discord alternatives that support webhooks may work. It is mainly developed for CS:GO, but other Source engine games may work as well.

## Installation

1. **Extract the plugin files:**
   - Copy `need_webhook.smx` to `addons/sourcemod/plugins/`
   - Copy `need_webhook.cfg` to `cfg/sourcemod/`

2. **Load the plugin:**
   - Restart your server or run: `sm plugins load need_webhook`

3. **Configure the webhook URL:**
   - Edit `cfg/sourcemod/need_webhook.cfg` and set your Discord webhook URL:
   ```
   sm_needwebhook_url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
   ```

### Compiling from source (optional)

If you want to compile the plugin yourself:

1. Copy `need_webhook.sp` to `addons/sourcemod/scripting/`
2. Run `./spcomp.exe need_webhook.sp`
3. Copy the generated `need_webhook.smx` to `addons/sourcemod/plugins/`

## Configuration

All configuration is done through ConVars in `cfg/sourcemod/need_webhook.cfg`:

### Core Settings

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_url` | *(empty)* | **REQUIRED** - Your Discord webhook URL |
| `sm_needwebhook_cooldown` | `1200` | Cooldown in seconds between `!need` uses (0 = no cooldown) |
| `sm_needwebhook_announce` | `Need message sent` | In-game chat message after successful send |

### Message Content

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_message` | `Players needed! @everyone` | Plain text content in the Discord message (great for pings) |
| `sm_needwebhook_username` | `Need Bot` | Display name of the webhook in Discord |
| `sm_needwebhook_avatar_url` | *(empty)* | Avatar URL for the webhook user |

### Embed Customization

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_embed_title` | `{CURRENT}/{MAX} - {MODE}` | Embed title with template variables |
| `sm_needwebhook_embed_description` | `{MAP}` | Embed description with template variables |
| `sm_needwebhook_embed_color` | `#5865F2` | Embed color (supports decimal, #RRGGBB, or 0xRRGGBB) |
| `sm_needwebhook_mode` | `Casual` | Game mode label for the {MODE} token |

### Server Information

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_connect` | `connect 127.0.0.1:27015` | Connection command text (replace with your server IP:port) |
| `sm_needwebhook_max_players` | `0` | Max player count shown (0 = auto-detect) |

### Embed Fields

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_status_label` | `Status` | Field name for server status |
| `sm_needwebhook_status_text` | `Active` | Field value for server status |
| `sm_needwebhook_players_label` | `Players` | Field name for player count |
| `sm_needwebhook_connect_label` | `Command to connect` | Field name for connection command |
| `sm_needwebhook_requester_label` | `Needed by` | Field name for the player who used !need |
| `sm_needwebhook_footer` | `IP: {CONNECT}` | Footer text with template variables |

### Map Images

| ConVar | Default | Description |
|--------|---------|-------------|
| `sm_needwebhook_image_base` | *(empty)* | Base URL for map images (e.g., `https://example.com/maps`) |
| `sm_needwebhook_image_ext` | `jpg` | Image file extension (jpg, png, webp, etc.) |
| `sm_needwebhook_image_include_prefix` | `1` | Include map prefixes (de_, cs_) in image URL (0 = strip them) |

## Usage

### Player Command

Players use the following chat command on the server:

```
!need
```

This sends a Discord message to the configured webhook and displays a confirmation message in-game.

### Cooldown

- The cooldown timer is **global** - once a successful `!need` is used, no player can use it again until the cooldown expires
- The cooldown is measured in seconds and resets after each successful use
- Players attempting to use `!need` during cooldown will receive feedback on how many seconds remain

## Template Variables

The following tokens can be used in template fields (embed title, description, footer):

| Token | Replaced With |
|-------|----------------|
| `{CURRENT}` | Current player count |
| `{MAX}` | Maximum player count |
| `{MODE}` | Game mode (from `sm_needwebhook_mode`) |
| `{MAP}` | Current map name |
| `{CONNECT}` | Connection command |
| `{PLAYER}` | Name of the player who used !need |

**Example Template:**
```
sm_needwebhook_embed_title "🔥 {CURRENT}/{MAX} players needed on {MAP}!"
sm_needwebhook_embed_description "{MODE} Mode - {PLAYER} needs you!"
sm_needwebhook_footer "Connect: {CONNECT}"
```

## Map Image Configuration

To display map images in your Discord messages:

1. **Prepare Your Images:**
   - Create a web-accessible directory for map images
   - Image files should be named according to map names with optional prefixes
   - Examples: `dust2.jpg`, `de_mirage.jpg`, `cs_office.jpg`

2. **Configure the Base URL:**
   ```
   sm_needwebhook_image_base "https://example.com/maps"
   sm_needwebhook_image_ext "jpg"
   sm_needwebhook_image_include_prefix "1"
   ```

3. **How Image URLs are Built:**
   - With `image_include_prefix = 1`: `https://example.com/maps/de_dust2.jpg`
   - With `image_include_prefix = 0` (strips de_): `https://example.com/maps/dust2.jpg`

## Discord Webhook Setup

### Creating a Webhook

1. Open your Discord server settings
2. Navigate to **Integrations** > **Webhooks**
3. Click **New Webhook**
4. Configure the webhook:
   - **Name:** Choose any name (e.g., "Server Notifications")
   - **Channel:** Select the channel where `!need` messages should appear
   - **Avatar** (optional): Upload a custom avatar
5. Click **Copy Webhook URL**
6. Paste the URL into your config file

### Webhook Permissions

Ensure the webhook has permission to send messages in the target channel.

## Configuration Examples

### Basic Setup
Add these lines to `cfg/sourcemod/need_webhook.cfg`:

```
sm_needwebhook_url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
sm_needwebhook_connect "connect 127.0.0.1:27015"
```

This gives you a working setup with default embed formatting.

### Custom Message with Ping
To send a custom message that pings a role:

```
sm_needwebhook_message "@everyone Server needs players!"
sm_needwebhook_embed_title "{CURRENT}/{MAX} - Help needed!"
```

### Map Images
To show map screenshots in Discord:

```
sm_needwebhook_image_base "https://example.com/maps"
sm_needwebhook_image_ext "jpg"
sm_needwebhook_image_include_prefix "0"
```

This will display images like `https://example.com/maps/dust2.jpg` for the current map.

### Custom Embed Styling
For a more detailed embed:

```
sm_needwebhook_embed_title "🔥 {CURRENT}/{MAX} players needed!"
sm_needwebhook_embed_description "Map: {MAP}\nMode: {MODE}\nRequested by: {PLAYER}"
sm_needwebhook_embed_color "#ff0000"
sm_needwebhook_footer "Join now: {CONNECT}"
```

### Disable Cooldown
To allow unlimited `!need` commands:

```
sm_needwebhook_cooldown "0"
```

### Competitive Server Setup
For a competitive server:

```
sm_needwebhook_mode "Competitive"
sm_needwebhook_embed_title "{CURRENT}/{MAX} - {MODE} Match"
sm_needwebhook_status_text "Matchmaking"
sm_needwebhook_cooldown "300"
```

## Troubleshooting

### Plugin Fails to Load
- **Cause:** SteamWorks extension is not installed
- **Solution:** Install the SteamWorks extension for SourceMod

### Command Shows "Webhook URL is not configured"
- **Cause:** `sm_needwebhook_url` is empty
- **Solution:** Set your Discord webhook URL in `cfg/sourcemod/need_webhook.cfg`

### Messages Don't Appear in Discord
- **Cause:** Webhook URL is incorrect or Discord API is unreachable
- **Solution:** Verify your webhook URL is correct and the webhook exists

### "Please wait X more seconds" Message
- **Cause:** Cooldown timer hasn't expired
- **Solution:** Wait for the cooldown period to end

### Maps Not Appearing as Images
- **Cause:** Base URL is empty or incorrect, image files don't exist
- **Solution:** Set `sm_needwebhook_image_base` correctly and ensure image files exist

### Special Characters Display Incorrectly in Discord
- **Cause:** JSON escaping issues
- **Solution:** The plugin automatically escapes special characters

## License

This plugin is licensed under the MIT License. You are free to use, modify, and distribute it as you wish.

---

**Compatible SourceMod Version:** 1.11+  
**Dependencies:** SteamWorks Extension
