#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <steamworks>

#define PLUGIN_VERSION "1.1.0"

enum RequestKind
{
    RequestKind_None = 0,
    RequestKind_CreateNeed,
    RequestKind_CreateMapChange,
    RequestKind_UpdateMessage
};

enum MessageKind
{
    MessageKind_None = 0,
    MessageKind_Need,
    MessageKind_MapChange
};

public Plugin myinfo =
{
    name = "GR !need",
    author = "ThatOneRicsi",
    description = "Lets players send a Discord webhook need notification with !need",
    version = PLUGIN_VERSION,
    url = "https://globalretake.com"
};

ConVar gCvCooldownSeconds;
ConVar gCvWebhookUrl;
ConVar gCvModeLabel;
ConVar gCvModeSource;
ConVar gCvPingText;
ConVar gCvPlainContent;
ConVar gCvMapChangeEnabled;
ConVar gCvMapChangeContent;
ConVar gCvImageBaseUrl;
ConVar gCvImageExtension;
ConVar gCvImageIncludePrefix;
ConVar gCvAnnounceText;
ConVar gCvUsername;
ConVar gCvAvatarUrl;
ConVar gCvEmbedTitle;
ConVar gCvEmbedDescription;
ConVar gCvEmbedColor;
ConVar gCvConnectText;
ConVar gCvMaxPlayersOverride;
ConVar gCvServerName;
ConVar gCvServerNameLabel;
ConVar gCvServerTag;
ConVar gCvServerTagLabel;
ConVar gCvStatusLabel;
ConVar gCvStatusText;
ConVar gCvInactiveStatusText;
ConVar gCvStatusUpdatesEnabled;
ConVar gCvStatusUpdateDelay;
ConVar gCvPlayersLabel;
ConVar gCvConnectLabel;
ConVar gCvRequesterLabel;
ConVar gCvFooterText;

float gNextAllowedUse = 0.0;
bool gHasSteamWorks = false;
bool gWebhookPending = false;
int gPendingRequesterSerial = 0;
RequestKind gPendingRequestKind = RequestKind_None;
char gPendingRequesterName[MAX_NAME_LENGTH];

bool gHasLastMessage = false;
MessageKind gLastMessageKind = MessageKind_None;
char gLastMessageId[64];
char gLastRequesterName[MAX_NAME_LENGTH];

Handle gStatusUpdateTimer = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_need", Command_Need, "Sends a Discord webhook notification for players who need more people.");

    CreateConVar("sm_needwebhook_version", PLUGIN_VERSION, "Need Webhook plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    gCvCooldownSeconds = CreateConVar("sm_needwebhook_cooldown", "1200", "Cooldown in seconds between successful !need uses.", FCVAR_NONE, true, 0.0);
    gCvWebhookUrl = CreateConVar("sm_needwebhook_url", "", "Discord webhook URL.", FCVAR_PROTECTED);
    gCvModeLabel = CreateConVar("sm_needwebhook_mode", "Casual", "Custom fallback game mode label shown in the Discord message.");
    gCvModeSource = CreateConVar("sm_needwebhook_mode_source", "auto", "Game mode source: auto or custom.");
    gCvPingText = CreateConVar("sm_needwebhook_ping", "@everyone", "Optional ping text sent above the normal !need message.");
    gCvPlainContent = CreateConVar("sm_needwebhook_message", "Players needed!", "Plain Discord message text sent for !need. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER} {SERVER} {TAG}");
    gCvMapChangeEnabled = CreateConVar("sm_needwebhook_mapchange_enabled", "1", "Send a webhook message when the map changes.", FCVAR_NONE, true, 0.0, true, 1.0);
    gCvMapChangeContent = CreateConVar("sm_needwebhook_mapchange_message", "Map changed to {MAP}", "Plain Discord message text sent on map changes without a ping. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER} {SERVER} {TAG}");
    gCvImageBaseUrl = CreateConVar("sm_needwebhook_image_base", "", "Base image URL without trailing slash. The current map name will be appended.");
    gCvImageExtension = CreateConVar("sm_needwebhook_image_ext", "jpg", "Map image extension used with sm_needwebhook_image_base.");
    gCvImageIncludePrefix = CreateConVar("sm_needwebhook_image_include_prefix", "1", "Use the full map name for the image URL, including prefixes like de_ and cs_. Set to 0 to strip the prefix.", FCVAR_NONE, true, 0.0, true, 1.0);
    gCvAnnounceText = CreateConVar("sm_needwebhook_announce", "Need message sent", "In-game confirmation text.");
    gCvUsername = CreateConVar("sm_needwebhook_username", "Need Bot", "Webhook username override.");
    gCvAvatarUrl = CreateConVar("sm_needwebhook_avatar_url", "", "Webhook avatar URL.");
    gCvEmbedTitle = CreateConVar("sm_needwebhook_embed_title", "{CURRENT}/{MAX} - {MODE}", "Embed title template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER} {SERVER} {TAG}");
    gCvEmbedDescription = CreateConVar("sm_needwebhook_embed_description", "{MAP}\\n{CONNECT}", "Embed description template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER} {SERVER} {TAG}");
    gCvEmbedColor = CreateConVar("sm_needwebhook_embed_color", "#5865F2", "Embed color as decimal, #RRGGBB, or 0xRRGGBB.");
    gCvConnectText = CreateConVar("sm_needwebhook_connect", "connect 127.0.0.1:27015", "Connect text shown in the embed.");
    gCvMaxPlayersOverride = CreateConVar("sm_needwebhook_max_players", "0", "Maximum player count shown in the embed. Set to 0 to auto-detect.");
    gCvServerName = CreateConVar("sm_needwebhook_server_name", "", "Server name field shown in the embed. Leave empty to use hostname.");
    gCvServerNameLabel = CreateConVar("sm_needwebhook_server_name_label", "Server", "Embed field label for the server name.");
    gCvServerTag = CreateConVar("sm_needwebhook_tag", "", "Optional tag field shown in the embed, such as Official or Verified.");
    gCvServerTagLabel = CreateConVar("sm_needwebhook_tag_label", "Tag", "Embed field label for the optional tag.");
    gCvStatusLabel = CreateConVar("sm_needwebhook_status_label", "Status", "Embed field label for server status.");
    gCvStatusText = CreateConVar("sm_needwebhook_status_text", "Active", "Embed field value used while players are online.");
    gCvInactiveStatusText = CreateConVar("sm_needwebhook_inactive_status_text", "Inactive", "Embed field value used when no real players are online.");
    gCvStatusUpdatesEnabled = CreateConVar("sm_needwebhook_status_updates", "1", "Edit the last webhook message to keep the player count and status fresh.", FCVAR_NONE, true, 0.0, true, 1.0);
    gCvStatusUpdateDelay = CreateConVar("sm_needwebhook_status_update_delay", "3.0", "Delay in seconds before coalescing a player-count/status update.", FCVAR_NONE, true, 0.0);
    gCvPlayersLabel = CreateConVar("sm_needwebhook_players_label", "Players", "Embed field label for player count.");
    gCvConnectLabel = CreateConVar("sm_needwebhook_connect_label", "Command to connect", "Embed field label for the connect command.");
    gCvRequesterLabel = CreateConVar("sm_needwebhook_requester_label", "Needed by", "Embed field label for the player who used !need.");
    gCvFooterText = CreateConVar("sm_needwebhook_footer", "IP: {CONNECT}", "Embed footer template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER} {SERVER} {TAG}");

    AutoExecConfig(true, "need_webhook");
    gHasSteamWorks = LibraryExists("SteamWorks");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "SteamWorks"))
    {
        gHasSteamWorks = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "SteamWorks"))
    {
        gHasSteamWorks = false;
    }
}

public void OnMapStart()
{
    if (!gCvMapChangeEnabled.BoolValue)
    {
        return;
    }

    CreateTimer(5.0, Timer_SendMapChangeWebhook, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
    if (client > 0 && !IsFakeClient(client))
    {
        ScheduleStatusUpdate();
    }
}

public void OnClientDisconnect_Post(int client)
{
    if (client > 0 && !IsFakeClient(client))
    {
        ScheduleStatusUpdate();
    }
}

public Action Command_Need(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    if (!gHasSteamWorks)
    {
        ReplyToCommand(client, "[Need] Discord sending requires the SteamWorks extension. Install SteamWorks.ext first.");
        return Plugin_Handled;
    }

    if (!HasConfiguredWebhook())
    {
        ReplyToCommand(client, "[Need] Webhook URL is not configured.");
        return Plugin_Handled;
    }

    float now = GetEngineTime();
    if (now < gNextAllowedUse)
    {
        int remaining = RoundToCeil(gNextAllowedUse - now);
        ReplyToCommand(client, "[Need] Please wait %d more second%s before using !need again.", remaining, remaining == 1 ? "" : "s");
        return Plugin_Handled;
    }

    if (gWebhookPending)
    {
        ReplyToCommand(client, "[Need] A webhook request is already being sent. Please wait a moment.");
        return Plugin_Handled;
    }

    if (!StartCreateWebhookRequest(RequestKind_CreateNeed, client))
    {
        ReplyToCommand(client, "[Need] Failed to build or send the webhook request.");
    }

    return Plugin_Handled;
}

public Action Timer_SendMapChangeWebhook(Handle timer)
{
    if (!gCvMapChangeEnabled.BoolValue || !gHasSteamWorks || !HasConfiguredWebhook())
    {
        return Plugin_Stop;
    }

    if (gWebhookPending)
    {
        CreateTimer(5.0, Timer_SendMapChangeWebhook, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    StartCreateWebhookRequest(RequestKind_CreateMapChange, 0);
    return Plugin_Stop;
}

public Action Timer_ProcessStatusUpdate(Handle timer)
{
    gStatusUpdateTimer = INVALID_HANDLE;

    if (!gCvStatusUpdatesEnabled.BoolValue || !gHasLastMessage || !gHasSteamWorks || !HasConfiguredWebhook())
    {
        return Plugin_Stop;
    }

    if (gWebhookPending)
    {
        ScheduleStatusUpdate();
        return Plugin_Stop;
    }

    StartUpdateWebhookRequest();
    return Plugin_Stop;
}

bool StartCreateWebhookRequest(RequestKind requestKind, int client)
{
    char payload[16384];
    if (!BuildWebhookPayload(requestKind == RequestKind_CreateMapChange ? MessageKind_MapChange : MessageKind_Need, client, payload, sizeof(payload), true))
    {
        return false;
    }

    char webhookUrl[512];
    if (!GetWebhookExecutionUrl(webhookUrl, sizeof(webhookUrl), true))
    {
        return false;
    }

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, webhookUrl);
    if (request == INVALID_HANDLE)
    {
        return false;
    }

    SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", payload, strlen(payload));
    SteamWorks_SetHTTPCallbacks(request, OnWebhookCompleted);

    if (!SteamWorks_SendHTTPRequest(request))
    {
        delete request;
        return false;
    }

    gWebhookPending = true;
    gPendingRequestKind = requestKind;
    gPendingRequesterSerial = client > 0 ? GetClientSerial(client) : 0;

    if (client > 0 && IsClientInGame(client))
    {
        GetClientName(client, gPendingRequesterName, sizeof(gPendingRequesterName));
    }
    else
    {
        gPendingRequesterName[0] = '\0';
    }

    return true;
}

bool StartUpdateWebhookRequest()
{
    if (!gHasLastMessage)
    {
        return false;
    }

    char payload[16384];
    if (!BuildWebhookPayload(gLastMessageKind, 0, payload, sizeof(payload), false))
    {
        return false;
    }

    char webhookMessageUrl[640];
    if (!GetWebhookMessageUrl(gLastMessageId, webhookMessageUrl, sizeof(webhookMessageUrl)))
    {
        return false;
    }

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPATCH, webhookMessageUrl);
    if (request == INVALID_HANDLE)
    {
        return false;
    }

    SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", payload, strlen(payload));
    SteamWorks_SetHTTPCallbacks(request, OnWebhookCompleted);

    if (!SteamWorks_SendHTTPRequest(request))
    {
        delete request;
        return false;
    }

    gWebhookPending = true;
    gPendingRequestKind = RequestKind_UpdateMessage;
    gPendingRequesterSerial = 0;
    gPendingRequesterName[0] = '\0';
    return true;
}

bool BuildWebhookPayload(MessageKind messageKind, int client, char[] buffer, int maxlen, bool includeIdentity)
{
    int currentPlayers = GetRealPlayerCount();
    int maxPlayers = GetConfiguredMaxPlayers();

    char modeLabel[128];
    char content[1024];
    char mapName[PLATFORM_MAX_PATH];
    char username[128];
    char avatarUrl[512];
    char embedTitleTemplate[256];
    char embedDescriptionTemplate[512];
    char connectText[192];
    char serverName[192];
    char serverNameLabel[64];
    char serverTag[64];
    char serverTagLabel[64];
    char statusLabel[64];
    char statusText[128];
    char playersLabel[64];
    char connectLabel[64];
    char requesterLabel[64];
    char footerTemplate[256];
    char playerName[MAX_NAME_LENGTH];

    ResolveModeLabel(modeLabel, sizeof(modeLabel));
    BuildPlainContent(messageKind, client, content, sizeof(content), currentPlayers, maxPlayers, modeLabel);
    GetCurrentMap(mapName, sizeof(mapName));
    gCvUsername.GetString(username, sizeof(username));
    gCvAvatarUrl.GetString(avatarUrl, sizeof(avatarUrl));
    gCvEmbedTitle.GetString(embedTitleTemplate, sizeof(embedTitleTemplate));
    gCvEmbedDescription.GetString(embedDescriptionTemplate, sizeof(embedDescriptionTemplate));
    gCvConnectText.GetString(connectText, sizeof(connectText));
    GetServerDisplayName(serverName, sizeof(serverName));
    gCvServerNameLabel.GetString(serverNameLabel, sizeof(serverNameLabel));
    gCvServerTag.GetString(serverTag, sizeof(serverTag));
    gCvServerTagLabel.GetString(serverTagLabel, sizeof(serverTagLabel));
    gCvStatusLabel.GetString(statusLabel, sizeof(statusLabel));
    GetDynamicStatusText(statusText, sizeof(statusText), currentPlayers);
    gCvPlayersLabel.GetString(playersLabel, sizeof(playersLabel));
    gCvConnectLabel.GetString(connectLabel, sizeof(connectLabel));
    gCvRequesterLabel.GetString(requesterLabel, sizeof(requesterLabel));
    gCvFooterText.GetString(footerTemplate, sizeof(footerTemplate));

    if (messageKind == MessageKind_Need)
    {
        if (client > 0 && IsClientInGame(client))
        {
            GetClientName(client, playerName, sizeof(playerName));
        }
        else
        {
            strcopy(playerName, sizeof(playerName), gLastRequesterName);
        }
    }
    else
    {
        playerName[0] = '\0';
    }

    char embedTitle[256];
    char embedDescription[768];
    char footerText[256];
    ApplyTemplate(embedTitleTemplate, embedTitle, sizeof(embedTitle), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);
    ApplyTemplate(embedDescriptionTemplate, embedDescription, sizeof(embedDescription), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);
    ApplyTemplate(footerTemplate, footerText, sizeof(footerText), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);

    char playersValue[32];
    FormatEx(playersValue, sizeof(playersValue), "%d / %d", currentPlayers, maxPlayers);

    char connectCode[256];
    FormatEx(connectCode, sizeof(connectCode), "```%s```", connectText);

    char escapedUsername[256];
    char escapedAvatarUrl[768];
    char escapedContent[2048];
    char escapedEmbedTitle[512];
    char escapedEmbedDescription[1536];
    char escapedServerNameLabel[128];
    char escapedServerName[384];
    char escapedServerTagLabel[128];
    char escapedServerTag[128];
    char escapedStatusLabel[128];
    char escapedStatusText[256];
    char escapedPlayersLabel[128];
    char escapedPlayersValue[128];
    char escapedConnectLabel[128];
    char escapedConnectCode[512];
    char escapedRequesterLabel[128];
    char escapedPlayerName[256];
    char escapedFooterText[512];

    JsonEscape(username, escapedUsername, sizeof(escapedUsername));
    JsonEscape(avatarUrl, escapedAvatarUrl, sizeof(escapedAvatarUrl));
    JsonEscape(content, escapedContent, sizeof(escapedContent));
    JsonEscape(embedTitle, escapedEmbedTitle, sizeof(escapedEmbedTitle));
    JsonEscape(embedDescription, escapedEmbedDescription, sizeof(escapedEmbedDescription));
    JsonEscape(serverNameLabel, escapedServerNameLabel, sizeof(escapedServerNameLabel));
    JsonEscape(serverName, escapedServerName, sizeof(escapedServerName));
    JsonEscape(serverTagLabel, escapedServerTagLabel, sizeof(escapedServerTagLabel));
    JsonEscape(serverTag, escapedServerTag, sizeof(escapedServerTag));
    JsonEscape(statusLabel, escapedStatusLabel, sizeof(escapedStatusLabel));
    JsonEscape(statusText, escapedStatusText, sizeof(escapedStatusText));
    JsonEscape(playersLabel, escapedPlayersLabel, sizeof(escapedPlayersLabel));
    JsonEscape(playersValue, escapedPlayersValue, sizeof(escapedPlayersValue));
    JsonEscape(connectLabel, escapedConnectLabel, sizeof(escapedConnectLabel));
    JsonEscape(connectCode, escapedConnectCode, sizeof(escapedConnectCode));
    JsonEscape(requesterLabel, escapedRequesterLabel, sizeof(escapedRequesterLabel));
    JsonEscape(playerName, escapedPlayerName, sizeof(escapedPlayerName));
    JsonEscape(footerText, escapedFooterText, sizeof(escapedFooterText));

    char fields[4096];
    bool hasPreviousField = false;
    fields[0] = '\0';

    if (serverName[0] != '\0')
    {
        if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedServerNameLabel, escapedServerName, true))
        {
            return false;
        }
        hasPreviousField = true;
    }

    if (serverTag[0] != '\0')
    {
        if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedServerTagLabel, escapedServerTag, true))
        {
            return false;
        }
        hasPreviousField = true;
    }

    if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedStatusLabel, escapedStatusText, true))
    {
        return false;
    }
    hasPreviousField = true;
    if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedPlayersLabel, escapedPlayersValue, true))
    {
        return false;
    }
    hasPreviousField = true;
    if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedConnectLabel, escapedConnectCode, false))
    {
        return false;
    }
    hasPreviousField = true;

    if (messageKind == MessageKind_Need && escapedPlayerName[0] != '\0')
    {
        if (!AppendEmbedField(fields, sizeof(fields), hasPreviousField, escapedRequesterLabel, escapedPlayerName, false))
        {
            return false;
        }
    }

    char imageUrl[512];
    char escapedImageUrl[768];
    BuildMapImageUrl(mapName, imageUrl, sizeof(imageUrl));
    JsonEscape(imageUrl, escapedImageUrl, sizeof(escapedImageUrl));

    int embedColor = ParseEmbedColor();

    if (includeIdentity)
    {
        if (imageUrl[0] != '\0')
        {
            int written = FormatEx(
                buffer,
                maxlen,
                "{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[%s],\"footer\":{\"text\":\"%s\"},\"image\":{\"url\":\"%s\"}}]}",
                escapedUsername,
                escapedAvatarUrl,
                escapedContent,
                escapedEmbedTitle,
                escapedEmbedDescription,
                embedColor,
                fields,
                escapedFooterText,
                escapedImageUrl
            );
            return written > 0 && written < maxlen - 1;
        }

        int written = FormatEx(
            buffer,
            maxlen,
            "{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[%s],\"footer\":{\"text\":\"%s\"}}]}",
            escapedUsername,
            escapedAvatarUrl,
            escapedContent,
            escapedEmbedTitle,
            escapedEmbedDescription,
            embedColor,
            fields,
            escapedFooterText
        );
        return written > 0 && written < maxlen - 1;
    }

    if (imageUrl[0] != '\0')
    {
        int written = FormatEx(
            buffer,
            maxlen,
            "{\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[%s],\"footer\":{\"text\":\"%s\"},\"image\":{\"url\":\"%s\"}}]}",
            escapedContent,
            escapedEmbedTitle,
            escapedEmbedDescription,
            embedColor,
            fields,
            escapedFooterText,
            escapedImageUrl
        );
        return written > 0 && written < maxlen - 1;
    }

    int written = FormatEx(
        buffer,
        maxlen,
        "{\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[%s],\"footer\":{\"text\":\"%s\"}}]}",
        escapedContent,
        escapedEmbedTitle,
        escapedEmbedDescription,
        embedColor,
        fields,
        escapedFooterText
    );
    return written > 0 && written < maxlen - 1;
}

bool AppendEmbedField(char[] buffer, int maxlen, bool hasPreviousField, const char[] name, const char[] value, bool inlineField)
{
    char fieldJson[768];
    int written = FormatEx(
        fieldJson,
        sizeof(fieldJson),
        "%s{\"name\":\"%s\",\"value\":\"%s\",\"inline\":%s}",
        hasPreviousField ? "," : "",
        name,
        value,
        inlineField ? "true" : "false"
    );

    if (written <= 0 || written >= sizeof(fieldJson) - 1)
    {
        return false;
    }

    if (strlen(buffer) + written >= maxlen)
    {
        return false;
    }

    StrCat(buffer, maxlen, fieldJson);
    return true;
}

void BuildPlainContent(MessageKind messageKind, int client, char[] buffer, int maxlen, int currentPlayers, int maxPlayers, const char[] modeLabel)
{
    char mapName[PLATFORM_MAX_PATH];
    char connectText[192];
    char playerName[MAX_NAME_LENGTH];
    char serverName[192];
    char serverTag[64];
    char messageTemplate[512];
    char pingTemplate[256];
    char messageText[768];
    char pingText[384];

    GetCurrentMap(mapName, sizeof(mapName));
    gCvConnectText.GetString(connectText, sizeof(connectText));
    GetServerDisplayName(serverName, sizeof(serverName));
    gCvServerTag.GetString(serverTag, sizeof(serverTag));

    if (messageKind == MessageKind_Need)
    {
        gCvPlainContent.GetString(messageTemplate, sizeof(messageTemplate));
        gCvPingText.GetString(pingTemplate, sizeof(pingTemplate));

        if (client > 0 && IsClientInGame(client))
        {
            GetClientName(client, playerName, sizeof(playerName));
        }
        else
        {
            strcopy(playerName, sizeof(playerName), gLastRequesterName);
        }

        ApplyTemplate(messageTemplate, messageText, sizeof(messageText), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);
        ApplyTemplate(pingTemplate, pingText, sizeof(pingText), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);
        TrimString(messageText);
        TrimString(pingText);

        if (pingText[0] != '\0' && messageText[0] != '\0')
        {
            FormatEx(buffer, maxlen, "%s\n%s", pingText, messageText);
        }
        else if (pingText[0] != '\0')
        {
            strcopy(buffer, maxlen, pingText);
        }
        else
        {
            strcopy(buffer, maxlen, messageText);
        }

        return;
    }

    gCvMapChangeContent.GetString(messageTemplate, sizeof(messageTemplate));
    playerName[0] = '\0';
    ApplyTemplate(messageTemplate, messageText, sizeof(messageText), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName, serverName, serverTag);
    strcopy(buffer, maxlen, messageText);
}

void ResolveModeLabel(char[] buffer, int maxlen)
{
    char modeSource[16];
    gCvModeSource.GetString(modeSource, sizeof(modeSource));
    TrimString(modeSource);

    if (StrEqual(modeSource, "custom", false))
    {
        gCvModeLabel.GetString(buffer, maxlen);
        return;
    }

    if (GetAutomaticModeLabel(buffer, maxlen))
    {
        return;
    }

    gCvModeLabel.GetString(buffer, maxlen);
}

bool GetAutomaticModeLabel(char[] buffer, int maxlen)
{
    ConVar gameTypeCvar = FindConVar("game_type");
    ConVar gameModeCvar = FindConVar("game_mode");

    if (gameTypeCvar == null || gameModeCvar == null)
    {
        return false;
    }

    int gameType = gameTypeCvar.IntValue;
    int gameMode = gameModeCvar.IntValue;

    if (gameType == 0)
    {
        switch (gameMode)
        {
            case 0:
            {
                strcopy(buffer, maxlen, "Casual");
                return true;
            }
            case 1:
            {
                strcopy(buffer, maxlen, "Competitive");
                return true;
            }
            case 2:
            {
                strcopy(buffer, maxlen, "Wingman");
                return true;
            }
            case 3:
            {
                strcopy(buffer, maxlen, "Weapons Expert");
                return true;
            }
        }
    }
    else if (gameType == 1)
    {
        switch (gameMode)
        {
            case 0:
            {
                strcopy(buffer, maxlen, "Arms Race");
                return true;
            }
            case 1:
            {
                strcopy(buffer, maxlen, "Demolition");
                return true;
            }
            case 2:
            {
                strcopy(buffer, maxlen, "Deathmatch");
                return true;
            }
        }
    }
    else if (gameType == 2 && gameMode == 0)
    {
        strcopy(buffer, maxlen, "Training");
        return true;
    }
    else if (gameType == 3 && gameMode == 0)
    {
        strcopy(buffer, maxlen, "Custom");
        return true;
    }
    else if (gameType == 4 && gameMode == 0)
    {
        strcopy(buffer, maxlen, "Guardian");
        return true;
    }
    else if (gameType == 5 && gameMode == 0)
    {
        strcopy(buffer, maxlen, "Co-op Strike");
        return true;
    }
    else if (gameType == 6 && gameMode == 0)
    {
        strcopy(buffer, maxlen, "Danger Zone");
        return true;
    }

    FormatEx(buffer, maxlen, "Type %d / Mode %d", gameType, gameMode);
    return true;
}

void GetServerDisplayName(char[] buffer, int maxlen)
{
    gCvServerName.GetString(buffer, maxlen);
    TrimString(buffer);

    if (buffer[0] != '\0')
    {
        return;
    }

    ConVar hostnameCvar = FindConVar("hostname");
    if (hostnameCvar != null)
    {
        hostnameCvar.GetString(buffer, maxlen);
        TrimString(buffer);
        return;
    }

    buffer[0] = '\0';
}

void GetDynamicStatusText(char[] buffer, int maxlen, int currentPlayers)
{
    if (currentPlayers <= 0)
    {
        gCvInactiveStatusText.GetString(buffer, maxlen);
        return;
    }

    gCvStatusText.GetString(buffer, maxlen);
}

bool HasConfiguredWebhook()
{
    char webhookUrl[512];
    gCvWebhookUrl.GetString(webhookUrl, sizeof(webhookUrl));
    TrimString(webhookUrl);
    return webhookUrl[0] != '\0';
}

bool GetWebhookExecutionUrl(char[] buffer, int maxlen, bool waitForBody)
{
    gCvWebhookUrl.GetString(buffer, maxlen);
    TrimString(buffer);

    if (buffer[0] == '\0')
    {
        return false;
    }

    if (!waitForBody)
    {
        return true;
    }

    if (StrContains(buffer, "wait=", false) != -1)
    {
        return true;
    }

    char originalUrl[512];
    strcopy(originalUrl, sizeof(originalUrl), buffer);

    if (StrContains(buffer, "?", false) == -1)
    {
        FormatEx(buffer, maxlen, "%s?wait=true", originalUrl);
    }
    else
    {
        FormatEx(buffer, maxlen, "%s&wait=true", originalUrl);
    }

    return true;
}

bool GetWebhookMessageUrl(const char[] messageId, char[] buffer, int maxlen)
{
    char webhookUrl[512];
    if (!GetWebhookExecutionUrl(webhookUrl, sizeof(webhookUrl), false))
    {
        return false;
    }

    char baseWebhookUrl[512];
    strcopy(baseWebhookUrl, sizeof(baseWebhookUrl), webhookUrl);

    char webhookQuery[512];
    webhookQuery[0] = '\0';

    int queryPos = FindCharInString(baseWebhookUrl, '?');
    if (queryPos != -1)
    {
        int queryOutPos = 0;
        int webhookLen = strlen(baseWebhookUrl);
        for (int i = queryPos; i < webhookLen && queryOutPos < sizeof(webhookQuery) - 1; i++)
        {
            webhookQuery[queryOutPos++] = baseWebhookUrl[i];
        }

        webhookQuery[queryOutPos] = '\0';
        baseWebhookUrl[queryPos] = '\0';
    }

    if (webhookQuery[0] != '\0')
    {
        FormatEx(buffer, maxlen, "%s/messages/%s%s", baseWebhookUrl, messageId, webhookQuery);
    }
    else
    {
        FormatEx(buffer, maxlen, "%s/messages/%s", baseWebhookUrl, messageId);
    }

    return true;
}

void ScheduleStatusUpdate()
{
    if (!gCvStatusUpdatesEnabled.BoolValue || !gHasLastMessage)
    {
        return;
    }

    if (gStatusUpdateTimer != INVALID_HANDLE)
    {
        return;
    }

    gStatusUpdateTimer = CreateTimer(gCvStatusUpdateDelay.FloatValue, Timer_ProcessStatusUpdate, _, TIMER_FLAG_NO_MAPCHANGE);
}

void CaptureLastMessageFromResponse(Handle request, MessageKind messageKind)
{
    int bodySize = 0;
    if (!SteamWorks_GetHTTPResponseBodySize(request, bodySize) || bodySize <= 0)
    {
        LogError("[Need] Discord returned a successful webhook response without a readable body. The last message ID could not be stored.");
        return;
    }

    char body[4096];
    int readLength = bodySize + 1;
    if (readLength > sizeof(body))
    {
        readLength = sizeof(body);
    }

    if (!SteamWorks_GetHTTPResponseBodyData(request, body, readLength))
    {
        LogError("[Need] Failed to read the Discord webhook response body. The last message ID could not be stored.");
        return;
    }

    body[readLength - 1] = '\0';

    if (!ExtractJsonString(body, "id", gLastMessageId, sizeof(gLastMessageId)))
    {
        LogError("[Need] Failed to extract the Discord message ID from the webhook response body.");
        return;
    }

    gHasLastMessage = true;
    gLastMessageKind = messageKind;

    if (messageKind == MessageKind_Need)
    {
        strcopy(gLastRequesterName, sizeof(gLastRequesterName), gPendingRequesterName);
    }
    else
    {
        gLastRequesterName[0] = '\0';
    }
}

bool ExtractJsonString(const char[] input, const char[] key, char[] buffer, int maxlen)
{
    char keyNeedle[64];
    FormatEx(keyNeedle, sizeof(keyNeedle), "\"%s\"", key);

    int keyPos = StrContains(input, keyNeedle, false);
    if (keyPos == -1)
    {
        buffer[0] = '\0';
        return false;
    }

    int length = strlen(input);
    int colonPos = -1;
    for (int i = keyPos + strlen(keyNeedle); i < length; i++)
    {
        if (input[i] == ':')
        {
            colonPos = i;
            break;
        }

        if (input[i] != ' ' && input[i] != '\t' && input[i] != '\r' && input[i] != '\n')
        {
            buffer[0] = '\0';
            return false;
        }
    }

    if (colonPos == -1)
    {
        buffer[0] = '\0';
        return false;
    }

    int valueStart = -1;
    for (int i = colonPos + 1; i < length; i++)
    {
        if (input[i] == '"')
        {
            valueStart = i + 1;
            break;
        }

        if (input[i] != ' ' && input[i] != '\t' && input[i] != '\r' && input[i] != '\n')
        {
            buffer[0] = '\0';
            return false;
        }
    }

    if (valueStart == -1)
    {
        buffer[0] = '\0';
        return false;
    }

    int outPos = 0;
    bool escaped = false;
    for (int i = valueStart; i < length && outPos < maxlen - 1; i++)
    {
        char c = input[i];

        if (escaped)
        {
            buffer[outPos++] = c;
            escaped = false;
            continue;
        }

        if (c == '\\')
        {
            escaped = true;
            continue;
        }

        if (c == '"')
        {
            buffer[outPos] = '\0';
            return outPos > 0;
        }

        buffer[outPos++] = c;
    }

    buffer[0] = '\0';
    return false;
}

void ClearPendingState()
{
    gWebhookPending = false;
    gPendingRequestKind = RequestKind_None;
    gPendingRequesterSerial = 0;
    gPendingRequesterName[0] = '\0';
}

public int OnWebhookCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, any data)
{
    RequestKind requestKind = gPendingRequestKind;
    int requester = GetClientFromSerial(gPendingRequesterSerial);
    bool success = !failure && requestSuccessful && (statusCode == k_EHTTPStatusCode204NoContent || statusCode == k_EHTTPStatusCode200OK);

    if (!success)
    {
        LogError("[Need] Discord webhook failed. kind=%d failure=%d successful=%d status=%d", requestKind, failure, requestSuccessful, statusCode);

        if (requestKind == RequestKind_CreateNeed && requester > 0 && IsClientInGame(requester))
        {
            ReplyToCommand(requester, "[Need] Discord webhook failed. Please try again in a moment.");
        }
    }
    else if (requestKind == RequestKind_CreateNeed)
    {
        CaptureLastMessageFromResponse(request, MessageKind_Need);
        gNextAllowedUse = GetEngineTime() + gCvCooldownSeconds.FloatValue;

        char announceText[192];
        gCvAnnounceText.GetString(announceText, sizeof(announceText));
        if (announceText[0] == '\0')
        {
            strcopy(announceText, sizeof(announceText), "Need message sent");
        }

        PrintToChatAll("%s", announceText);
    }
    else if (requestKind == RequestKind_CreateMapChange)
    {
        CaptureLastMessageFromResponse(request, MessageKind_MapChange);
    }

    ClearPendingState();
    delete request;
    return 0;
}

void BuildMapImageUrl(const char[] mapName, char[] buffer, int maxlen)
{
    char baseUrl[384];
    char extension[32];
    char imageMapName[PLATFORM_MAX_PATH];

    gCvImageBaseUrl.GetString(baseUrl, sizeof(baseUrl));
    gCvImageExtension.GetString(extension, sizeof(extension));

    TrimString(baseUrl);
    TrimString(extension);

    if (baseUrl[0] == '\0')
    {
        buffer[0] = '\0';
        return;
    }

    GetImageMapName(mapName, imageMapName, sizeof(imageMapName));

    int baseLen = strlen(baseUrl);
    bool hasSlash = baseLen > 0 && baseUrl[baseLen - 1] == '/';
    bool hasExt = extension[0] != '\0';

    if (hasSlash && hasExt)
    {
        FormatEx(buffer, maxlen, "%s%s.%s", baseUrl, imageMapName, extension);
    }
    else if (hasSlash)
    {
        FormatEx(buffer, maxlen, "%s%s", baseUrl, imageMapName);
    }
    else if (hasExt)
    {
        FormatEx(buffer, maxlen, "%s/%s.%s", baseUrl, imageMapName, extension);
    }
    else
    {
        FormatEx(buffer, maxlen, "%s/%s", baseUrl, imageMapName);
    }
}

void GetImageMapName(const char[] mapName, char[] buffer, int maxlen)
{
    strcopy(buffer, maxlen, mapName);

    if (gCvImageIncludePrefix.BoolValue)
    {
        return;
    }

    int underscorePos = FindCharInString(buffer, '_');
    if (underscorePos <= 0 || buffer[underscorePos + 1] == '\0')
    {
        return;
    }

    CopySubstring(buffer, underscorePos + 1, buffer, maxlen);
}

int GetRealPlayerCount()
{
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
        {
            continue;
        }

        count++;
    }

    return count;
}

int GetConfiguredMaxPlayers()
{
    int maxPlayers = gCvMaxPlayersOverride.IntValue;

    if (maxPlayers > 0)
    {
        return maxPlayers;
    }

    int visibleMax = GetMaxHumanPlayersFromServer();
    if (visibleMax > 0)
    {
        return visibleMax;
    }

    return GetMaxHumanPlayers();
}

int GetMaxHumanPlayersFromServer()
{
    ConVar maxPlayersCvar = FindConVar("sv_visiblemaxplayers");
    if (maxPlayersCvar != null)
    {
        int visibleMax = maxPlayersCvar.IntValue;
        if (visibleMax > 0)
        {
            return visibleMax;
        }
    }

    return 0;
}

void ApplyTemplate(const char[] input, char[] output, int maxlen, int currentPlayers, int maxPlayers, const char[] modeLabel, const char[] mapName, const char[] connectText, const char[] playerName, const char[] serverName, const char[] serverTag)
{
    strcopy(output, maxlen, input);

    char currentBuffer[16];
    char maxBuffer[16];
    IntToString(currentPlayers, currentBuffer, sizeof(currentBuffer));
    IntToString(maxPlayers, maxBuffer, sizeof(maxBuffer));

    ReplaceString(output, maxlen, "{CURRENT}", currentBuffer, false);
    ReplaceString(output, maxlen, "{MAX}", maxBuffer, false);
    ReplaceString(output, maxlen, "{MODE}", modeLabel, false);
    ReplaceString(output, maxlen, "{MAP}", mapName, false);
    ReplaceString(output, maxlen, "{CONNECT}", connectText, false);
    ReplaceString(output, maxlen, "{PLAYER}", playerName, false);
    ReplaceString(output, maxlen, "{SERVER}", serverName, false);
    ReplaceString(output, maxlen, "{TAG}", serverTag, false);
    ReplaceString(output, maxlen, "\\n", "\n", false);
}

int ParseEmbedColor()
{
    char colorValue[32];
    char normalizedColor[32];
    gCvEmbedColor.GetString(colorValue, sizeof(colorValue));
    TrimString(colorValue);

    if (colorValue[0] == '\0')
    {
        return 5793266;
    }

    if (colorValue[0] == '#')
    {
        CopySubstring(colorValue, 1, normalizedColor, sizeof(normalizedColor));
        return StringToInt(normalizedColor, 16);
    }

    if (strlen(colorValue) > 2 && colorValue[0] == '0' && (colorValue[1] == 'x' || colorValue[1] == 'X'))
    {
        CopySubstring(colorValue, 2, normalizedColor, sizeof(normalizedColor));
        return StringToInt(normalizedColor, 16);
    }

    return StringToInt(colorValue);
}

void CopySubstring(const char[] input, int start, char[] output, int maxlen)
{
    int length = strlen(input);
    int outPos = 0;

    for (int i = start; i < length && outPos < maxlen - 1; i++)
    {
        output[outPos++] = input[i];
    }

    output[outPos] = '\0';
}

void JsonEscape(const char[] input, char[] output, int maxlen)
{
    int outPos = 0;
    int length = strlen(input);

    for (int i = 0; i < length && outPos < maxlen - 1; i++)
    {
        int c = input[i];

        if (c == '"' || c == '\\')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = c;
            continue;
        }

        if (c == '\n')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 'n';
            continue;
        }

        if (c == '\r')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 'r';
            continue;
        }

        if (c == '\t')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 't';
            continue;
        }

        if (c == '\b')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 'b';
            continue;
        }

        if (c == '\f')
        {
            if (outPos >= maxlen - 2)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 'f';
            continue;
        }

        if (c >= 0 && c < 0x20)
        {
            if (outPos >= maxlen - 6)
            {
                break;
            }

            output[outPos++] = '\\';
            output[outPos++] = 'u';
            output[outPos++] = '0';
            output[outPos++] = '0';
            output[outPos++] = HexDigit((c >> 4) & 0x0F);
            output[outPos++] = HexDigit(c & 0x0F);
            continue;
        }

        output[outPos++] = view_as<char>(c);
    }

    output[outPos] = '\0';
}

char HexDigit(int value)
{
    return view_as<char>(value < 10 ? ('0' + value) : ('A' + value - 10));
}
