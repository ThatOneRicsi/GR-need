# GR !need

Discord webhook plugin for SourceMod that lets players use `!need` to post a configurable "we need more players" message to Discord.

**Author:** ThatOneRicsi  
**Version:** 1.1.0  
**Website:** https://globalretake.com

## What It Does

When a player types `!need`, the plugin sends a Discord webhook with:

- Optional ping text separate from the main message text
- An embed with current player count, max players, mode, map, connect command, requester name, server name, and optional tag
- Optional map image support
- A global cooldown to stop server-wide spam

The plugin can also:

- Send a non-ping webhook when the map changes
- Edit the last webhook message as players join or leave
- Mark the server status inactive when no real players remain

The cooldown is only consumed after Discord accepts the `!need` webhook. Failed requests do not consume the cooldown.

## Features

- Discord webhook support through the SourceMod `SteamWorks` extension
- Rich embed formatting with configurable title, description, footer, and field labels
- Automatic or custom game mode labels
- Configurable server name and optional tag field
- Separate ping text for `!need` plus a dedicated map-change message without pinging
- Last-message tracking with webhook edits for live player count and status updates
- Template tokens such as `{CURRENT}`, `{MAX}`, `{MODE}`, `{MAP}`, `{CONNECT}`, `{PLAYER}`, `{SERVER}`, and `{TAG}`
- Optional map image URLs with prefix stripping support
- Safer webhook flow with in-flight request protection
- Safer payload handling for large messages and escaped characters

## Requirements

- SourceMod 1.11 or newer
- SteamWorks extension installed on the server
- A valid Discord webhook URL
- Outbound network access from your server to Discord

## Included Files

- `addons/sourcemod/plugins/need_webhook.smx`
- `addons/sourcemod/scripting/need_webhook.sp`
- `addons/sourcemod/scripting/include/steamworks.inc`
- `cfg/sourcemod/need_webhook.cfg`

## Installation

1. Copy `need_webhook.smx` into `addons/sourcemod/plugins/`.
2. Copy `cfg/sourcemod/need_webhook.cfg` into `cfg/sourcemod/`.
3. Restart the server or run `sm plugins load need_webhook`.
4. Set `sm_needwebhook_url` in the config.

Optional source files for recompiling:

- `addons/sourcemod/scripting/need_webhook.sp`
- `addons/sourcemod/scripting/include/steamworks.inc`

## First-Time Setup

At minimum, configure:

```txt
sm_needwebhook_url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
sm_needwebhook_connect "connect YOUR_IP:YOUR_PORT"
```

Good next settings to review:

- `sm_needwebhook_ping`
- `sm_needwebhook_message`
- `sm_needwebhook_mode_source`
- `sm_needwebhook_server_name`
- `sm_needwebhook_tag`
- `sm_needwebhook_mapchange_enabled`
- `sm_needwebhook_status_updates`

## Command

Players use:

```txt
!need
```

Internally this is the SourceMod command:

```txt
sm_need
```

## Behavior

### Cooldown

- The cooldown is global, not per-player.
- A successful `!need` blocks further `!need` usage for everyone until the cooldown expires.
- Failed `!need` webhook sends do not start the cooldown.

### Success and failure handling

- The server only announces success after Discord returns a successful response.
- If a webhook request is already in flight, new requests are temporarily blocked.
- If Discord rejects the webhook, the requester gets an error message and can try again.

### Map change and live updates

- When enabled, a map change posts a separate webhook without ping text.
- The plugin stores the last message ID returned by Discord.
- When players join or leave, the plugin can edit that last message to keep `Players` and `Status` current.
- When the server empties out, status changes from the active text to the inactive text.

## Configuration

All settings are controlled through `cfg/sourcemod/need_webhook.cfg`.

### Core

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_url` | `(empty)` | Discord webhook URL. Required. |
| `sm_needwebhook_cooldown` | `1200` | Global cooldown in seconds between successful `!need` uses. |
| `sm_needwebhook_announce` | `Need message sent` | In-game text printed after a successful `!need`. |

### Webhook content

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_ping` | `@everyone` | Optional ping text placed above the normal `!need` message. |
| `sm_needwebhook_message` | `Players needed!` | Plain text content for `!need`. |
| `sm_needwebhook_mapchange_enabled` | `1` | Send a webhook when the map changes. |
| `sm_needwebhook_mapchange_message` | `Map changed to {MAP}` | Plain text content for map-change messages. |
| `sm_needwebhook_username` | `Need Bot` | Webhook display name override. |
| `sm_needwebhook_avatar_url` | `(empty)` | Webhook avatar URL. Leave empty to use the webhook default. |

### Embed templates and mode

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_embed_title` | `{CURRENT}/{MAX} - {MODE}` | Embed title template. |
| `sm_needwebhook_embed_description` | `{MAP}\n{CONNECT}` | Embed description template. |
| `sm_needwebhook_embed_color` | `#5865F2` | Embed color as decimal, `#RRGGBB`, or `0xRRGGBB`. |
| `sm_needwebhook_mode_source` | `auto` | Use `auto` to detect the game mode or `custom` to force `sm_needwebhook_mode`. |
| `sm_needwebhook_mode` | `Casual` | Custom fallback mode label used when auto detection is disabled or unavailable. |

### Server info

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_connect` | `connect 127.0.0.1:27015` | Connect command shown in the embed. |
| `sm_needwebhook_max_players` | `0` | Max players shown in the embed. `0` means auto-detect. |
| `sm_needwebhook_server_name` | `(hostname)` | Server name field. Leave empty to use the server hostname. |
| `sm_needwebhook_server_name_label` | `Server` | Field label for the server name. |
| `sm_needwebhook_tag` | `(empty)` | Optional extra tag such as `Official` or `Verified`. |
| `sm_needwebhook_tag_label` | `Tag` | Field label for the extra tag. |

### Status and live updates

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_status_label` | `Status` | Field name for the status field. |
| `sm_needwebhook_status_text` | `Active` | Status text used while real players are online. |
| `sm_needwebhook_inactive_status_text` | `Inactive` | Status text used when the server has no real players online. |
| `sm_needwebhook_status_updates` | `1` | Edit the last webhook message when player counts change. |
| `sm_needwebhook_status_update_delay` | `3.0` | Debounce delay before sending a status/player-count edit. |
| `sm_needwebhook_players_label` | `Players` | Field name for player count. |
| `sm_needwebhook_connect_label` | `Command to connect` | Field name for the connect command. |
| `sm_needwebhook_requester_label` | `Needed by` | Field name for the player who requested help. |
| `sm_needwebhook_footer` | `IP: {CONNECT}` | Footer template. |

### Map image options

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_image_base` | `(empty)` | Base URL used for map images. |
| `sm_needwebhook_image_ext` | `jpg` | File extension for map images. |
| `sm_needwebhook_image_include_prefix` | `1` | Keep map prefixes like `de_` and `cs_` when building the image URL. |

## Template Tokens

These tokens can be used in plain content, title, description, and footer templates:

| Token | Value |
|---|---|
| `{CURRENT}` | Current real human player count |
| `{MAX}` | Configured or detected max player count |
| `{MODE}` | Detected or custom game mode label |
| `{MAP}` | Current map name |
| `{CONNECT}` | Value of `sm_needwebhook_connect` |
| `{PLAYER}` | Name of the player who used `!need` |
| `{SERVER}` | Configured server name or hostname |
| `{TAG}` | Optional configured tag |

Example:

```txt
sm_needwebhook_ping "@everyone"
sm_needwebhook_message "{SERVER} needs players for {MODE}"
sm_needwebhook_embed_title "{SERVER} - {CURRENT}/{MAX}"
sm_needwebhook_footer "Requested by {PLAYER}"
```

## Example Configurations

### Competitive server with auto mode

```txt
sm_needwebhook_mode_source "auto"
sm_needwebhook_server_name "Global Retake EU #1"
sm_needwebhook_tag "Official"
sm_needwebhook_ping "@competitive"
sm_needwebhook_message "Need more players on {SERVER}"
```

### Custom fallback mode

```txt
sm_needwebhook_mode_source "custom"
sm_needwebhook_mode "Wingman"
```

### Map-change posts without pinging

```txt
sm_needwebhook_mapchange_enabled "1"
sm_needwebhook_mapchange_message "{SERVER} switched to {MAP}"
sm_needwebhook_ping "@everyone"
```

### Live status updates

```txt
sm_needwebhook_status_updates "1"
sm_needwebhook_status_text "Active"
sm_needwebhook_inactive_status_text "Inactive"
sm_needwebhook_status_update_delay "3.0"
```

### Map screenshots

```txt
sm_needwebhook_image_base "https://example.com/maps"
sm_needwebhook_image_ext "jpg"
sm_needwebhook_image_include_prefix "0"
```

## Compiling From Source

You need:

- `need_webhook.sp`
- `steamworks.inc`
- a SourceMod compiler such as `spcomp.exe`

Example:

```txt
spcomp.exe addons/sourcemod/scripting/need_webhook.sp
```

## Troubleshooting

### Plugin says SteamWorks is required

Install a compatible SteamWorks extension for your SourceMod version and game.

### `!need` says the webhook URL is not configured

Set the real Discord webhook URL in `cfg/sourcemod/need_webhook.cfg`.

### Nothing appears in Discord

Check:

- The webhook URL is still valid
- The server can reach Discord
- SourceMod error logs for failed HTTP requests
- Your payload size if you heavily customized the message

### The player count or status is not updating

Check:

- `sm_needwebhook_status_updates` is enabled
- A plugin message has already been sent and stored as the last message
- The webhook URL still has permission to edit its own messages

### Map image does not show

Confirm the final generated image URL is valid in a browser.

## Notes

- Designed mainly for CS:GO / Source engine servers.
- Other SourceMod-supported games may also work.
- This plugin depends on Discord-style webhooks and is primarily intended for Discord.

## License

This project is licensed under the MIT License.
