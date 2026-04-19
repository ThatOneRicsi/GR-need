# GR !need

Discord webhook plugin for SourceMod that lets players use `!need` to post a configurable "we need more players" message to Discord.

**Author:** ThatOneRicsi  
**Version:** 1.0.1  
**Website:** https://globalretake.com

## What It Does

When a player types `!need`, the plugin sends a Discord webhook with:

- Plain text content for role pings or attention text
- An embed with current player count, max players, mode, map, connect command, and requester name
- Optional map image support
- A global cooldown to stop server-wide spam

The webhook is only treated as successful after Discord accepts it. Failed requests do not consume the cooldown.

## Features

- Discord webhook support through the SourceMod `SteamWorks` extension
- Rich embed formatting with configurable title, description, footer, and field labels
- Template tokens such as `{CURRENT}`, `{MAX}`, `{MODE}`, `{MAP}`, `{CONNECT}`, and `{PLAYER}`
- Optional map image URLs with prefix stripping support
- Global cooldown between successful uses
- Safer webhook flow with in-flight request protection
- Safer payload handling for large messages and escaped characters

## Requirements

- SourceMod 1.11 or newer
- SteamWorks extension installed on the server
- A valid Discord webhook URL
- Outbound network access from your server to Discord

## Included Files

Repository layout:

- `addons/sourcemod/plugins/need_webhook.smx`
- `addons/sourcemod/scripting/need_webhook.sp`
- `addons/sourcemod/scripting/include/steamworks.inc`
- `cfg/sourcemod/need_webhook.cfg`

Release zip files:

- `GR_need_webhook_release_pasteable.zip`
  Contains server-ready folder structure for direct extraction into the CS:GO server root.
- `GR_need_webhook_release_with_source.zip`
  Same folder structure plus `need_webhook.sp`.
- `GR_need_webhook_release_flat.zip`
  Contains `need_webhook.smx`, `need_webhook.cfg`, and `need_webhook.sp` in a flat layout with no folders.

## Installation

### Option 1: Use the pasteable release zip

1. Extract `GR_need_webhook_release_pasteable.zip` into your server root.
2. Restart the server or load the plugin manually.
3. Edit `cfg/sourcemod/need_webhook.cfg`.
4. Set `sm_needwebhook_url` to your Discord webhook.

### Option 2: Manual install

Copy these files:

- `addons/sourcemod/plugins/need_webhook.smx` -> `addons/sourcemod/plugins/`
- `cfg/sourcemod/need_webhook.cfg` -> `cfg/sourcemod/`

Optional source files:

- `addons/sourcemod/scripting/need_webhook.sp`
- `addons/sourcemod/scripting/include/steamworks.inc`

Then restart the server or run:

```txt
sm plugins load need_webhook
```

## First-Time Setup

Open `cfg/sourcemod/need_webhook.cfg` and configure at least:

```txt
sm_needwebhook_url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
sm_needwebhook_connect "connect YOUR_IP:YOUR_PORT"
```

Recommended values to review right away:

- `sm_needwebhook_message`
- `sm_needwebhook_mode`
- `sm_needwebhook_max_players`
- `sm_needwebhook_announce`
- `sm_needwebhook_image_base`

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
- Failed webhook sends do not start the cooldown.

### Success and failure handling

- The server only announces success after Discord returns a successful response.
- If a webhook request is already in flight, new requests are temporarily blocked.
- If Discord rejects the webhook, the requester gets an error message and can try again.

## Configuration

All settings are controlled through `cfg/sourcemod/need_webhook.cfg`.

### Core

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_url` | `(empty)` | Discord webhook URL. Required. |
| `sm_needwebhook_cooldown` | `1200` | Global cooldown in seconds between successful uses. |
| `sm_needwebhook_announce` | `Need message sent` | In-game text printed after a successful webhook. |

### Webhook content

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_message` | `Players needed! @EU server ping` | Plain text content outside the embed. Good for role or everyone pings. |
| `sm_needwebhook_username` | `Need Bot` | Webhook display name override. |
| `sm_needwebhook_avatar_url` | `(empty)` | Webhook avatar URL. Leave empty to use the webhook default. |

### Embed templates

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_embed_title` | `{CURRENT}/{MAX} - {MODE}` | Embed title template. |
| `sm_needwebhook_embed_description` | `{MAP}\n{CONNECT}` | Embed description template. |
| `sm_needwebhook_embed_color` | `#5865F2` | Embed color as decimal, `#RRGGBB`, or `0xRRGGBB`. |
| `sm_needwebhook_mode` | `Casual` | Game mode label used by `{MODE}`. |

### Server info

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_connect` | `connect 127.0.0.1:27015` | Connect command shown in the embed. |
| `sm_needwebhook_max_players` | `0` | Max players shown in the embed. `0` means auto-detect. |

### Embed field labels and footer

| ConVar | Default | Description |
|---|---|---|
| `sm_needwebhook_status_label` | `Status` | Field name for the status field. |
| `sm_needwebhook_status_text` | `Active` | Field value for the status field. |
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

These tokens can be used in title, description, and footer templates:

| Token | Value |
|---|---|
| `{CURRENT}` | Current real human player count |
| `{MAX}` | Configured or detected max player count |
| `{MODE}` | Value of `sm_needwebhook_mode` |
| `{MAP}` | Current map name |
| `{CONNECT}` | Value of `sm_needwebhook_connect` |
| `{PLAYER}` | Name of the player who used `!need` |

Example:

```txt
sm_needwebhook_embed_title "{CURRENT}/{MAX} - {MODE}"
sm_needwebhook_embed_description "{MAP}\n{CONNECT}"
sm_needwebhook_footer "Requested by {PLAYER}"
```

## Map Images

If `sm_needwebhook_image_base` is set, the plugin appends the current map name and extension to build the image URL.

Examples:

```txt
sm_needwebhook_image_base "https://example.com/maps"
sm_needwebhook_image_ext "jpg"
sm_needwebhook_image_include_prefix "1"
```

With `de_dust2`:

- Prefix kept: `https://example.com/maps/de_dust2.jpg`
- Prefix stripped: `https://example.com/maps/dust2.jpg`

## Example Configurations

### Basic

```txt
sm_needwebhook_url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
sm_needwebhook_connect "connect 203.0.113.10:27015"
```

### Ping a role

```txt
sm_needwebhook_message "@everyone Server needs players!"
sm_needwebhook_embed_title "{CURRENT}/{MAX} - Help needed"
```

### Competitive server

```txt
sm_needwebhook_mode "Competitive"
sm_needwebhook_status_text "Matchmaking"
sm_needwebhook_cooldown "300"
sm_needwebhook_embed_title "{CURRENT}/{MAX} - {MODE}"
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

This repository already includes `addons/sourcemod/scripting/include/steamworks.inc` so local recompiles are easier.

## Troubleshooting

### Plugin says SteamWorks is required

Cause:
The SteamWorks extension is not installed or not loaded.

Fix:
Install a compatible SteamWorks extension for your SourceMod version and game.

### `!need` says the webhook URL is not configured

Cause:
`sm_needwebhook_url` is empty or still set to the placeholder value.

Fix:
Set the real Discord webhook URL in `cfg/sourcemod/need_webhook.cfg`.

### Nothing appears in Discord

Cause:

- Bad webhook URL
- Discord webhook deleted
- Server cannot reach Discord
- Discord rejected the payload

Fix:

- Re-copy the webhook URL
- Test server outbound connectivity
- Check SourceMod error logs
- Keep embed text shorter if you heavily customized the message

### Players get a failure message instead of a success message

Cause:
Discord rejected the request or the request failed in transit.

Fix:
Check the server logs and validate the webhook URL and payload content.

### A player sees "A webhook request is already being sent"

Cause:
Another `!need` request is currently in progress.

Fix:
Wait a moment and try again.

### Map image does not show

Cause:

- `sm_needwebhook_image_base` is empty
- Wrong image URL or extension
- Image file does not exist at the expected path

Fix:
Confirm the final generated URL is valid in a browser.

## Notes

- Designed mainly for CS:GO / Source engine servers.
- Other SourceMod-supported games may also work.
- This plugin depends on Discord-style webhooks and is primarily intended for Discord.

## License

This project is licensed under the MIT License.
