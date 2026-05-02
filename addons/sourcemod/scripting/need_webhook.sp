#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <steamworks>

#define PLUGIN_VERSION "1.0.4"
#define WEBHOOK_TIMEOUT_SECONDS 20.0
#define WEBHOOK_TIMEOUT_MS 20000

public Plugin myinfo =
{
    name = "GR !need",
    author = "ThatOneRicsi",
    description = "Lets players send a Discord webhook need notification with !need",
    version = PLUGIN_VERSION,
    url = "https://globalretake.com"
};

ConVar gCvCooldownSeconds;
ConVar gCvFailureCooldownSeconds;
ConVar gCvWebhookUrl;
ConVar gCvModeLabel;
ConVar gCvPlainContent;
ConVar gCvImageBaseUrl;
ConVar gCvImageExtension;
ConVar gCvImageIncludePrefix;
ConVar gCvAnnounceText;
ConVar gCvAnnounceMode;
ConVar gCvUsername;
ConVar gCvAvatarUrl;
ConVar gCvEmbedTitle;
ConVar gCvEmbedDescription;
ConVar gCvEmbedColor;
ConVar gCvConnectText;
ConVar gCvMaxPlayersOverride;
ConVar gCvStatusLabel;
ConVar gCvStatusText;
ConVar gCvPlayersLabel;
ConVar gCvConnectLabel;
ConVar gCvRequesterLabel;
ConVar gCvFooterText;

float gNextAllowedUse = 0.0;
bool gHasSteamWorks = false;
bool gWebhookPending = false;
Handle gPendingWebhookRequest = INVALID_HANDLE;
Handle gWebhookTimeoutTimer = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_need", Command_Need, "Sends a Discord webhook notification for players who need more people.");

    CreateConVar("sm_needwebhook_version", PLUGIN_VERSION, "Need Webhook plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    gCvCooldownSeconds = CreateConVar("sm_needwebhook_cooldown", "1200", "Cooldown in seconds between successful !need uses.", FCVAR_NONE, true, 0.0);
    gCvFailureCooldownSeconds = CreateConVar("sm_needwebhook_failure_cooldown", "60", "Cooldown in seconds after a failed or timed out !need attempt to prevent retry spam.", FCVAR_NONE, true, 0.0);
    gCvWebhookUrl = CreateConVar("sm_needwebhook_url", "", "Discord webhook URL.", FCVAR_PROTECTED);
    gCvModeLabel = CreateConVar("sm_needwebhook_mode", "Casual", "Game mode label shown in the Discord message.");
    gCvPlainContent = CreateConVar("sm_needwebhook_message", "Players needed! @EU server ping", "Plain Discord message text sent outside the embed.");
    gCvImageBaseUrl = CreateConVar("sm_needwebhook_image_base", "", "Base image URL without trailing slash. The current map name will be appended.");
    gCvImageExtension = CreateConVar("sm_needwebhook_image_ext", "jpg", "Map image extension used with sm_needwebhook_image_base.");
    gCvImageIncludePrefix = CreateConVar("sm_needwebhook_image_include_prefix", "1", "Use the full map name for the image URL, including prefixes like de_ and cs_. Set to 0 to strip the prefix.", FCVAR_NONE, true, 0.0, true, 1.0);
    gCvAnnounceText = CreateConVar("sm_needwebhook_announce", "Need message sent", "In-game confirmation text.");
    gCvAnnounceMode = CreateConVar("sm_needwebhook_announce_mode", "1", "Who receives the in-game confirmation text: 0 = disabled, 1 = requester only, 2 = everyone.", FCVAR_NONE, true, 0.0, true, 2.0);
    gCvUsername = CreateConVar("sm_needwebhook_username", "Need Bot", "Webhook username override.");
    gCvAvatarUrl = CreateConVar("sm_needwebhook_avatar_url", "", "Webhook avatar URL.");
    gCvEmbedTitle = CreateConVar("sm_needwebhook_embed_title", "{CURRENT}/{MAX} - {MODE}", "Embed title template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT}");
    gCvEmbedDescription = CreateConVar("sm_needwebhook_embed_description", "{MAP}\\n{CONNECT}", "Embed description template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT}");
    gCvEmbedColor = CreateConVar("sm_needwebhook_embed_color", "#5865F2", "Embed color as decimal, #RRGGBB, or 0xRRGGBB.");
    gCvConnectText = CreateConVar("sm_needwebhook_connect", "connect 127.0.0.1:27015", "Connect text shown in the embed.");
    gCvMaxPlayersOverride = CreateConVar("sm_needwebhook_max_players", "0", "Maximum player count shown in the embed. Set to 0 to auto-detect.");
    gCvStatusLabel = CreateConVar("sm_needwebhook_status_label", "Status", "Embed field label for server status.");
    gCvStatusText = CreateConVar("sm_needwebhook_status_text", "Active", "Embed field value for server status.");
    gCvPlayersLabel = CreateConVar("sm_needwebhook_players_label", "Players", "Embed field label for player count.");
    gCvConnectLabel = CreateConVar("sm_needwebhook_connect_label", "Command to connect", "Embed field label for the connect command.");
    gCvRequesterLabel = CreateConVar("sm_needwebhook_requester_label", "Needed by", "Embed field label for the player who used !need.");
    gCvFooterText = CreateConVar("sm_needwebhook_footer", "IP: {CONNECT}", "Embed footer template. Tokens: {CURRENT} {MAX} {MODE} {MAP} {CONNECT} {PLAYER}");

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

public void OnPluginEnd()
{
    ClearWebhookPendingState(false);
}

void NotifyClient(int client, const char[] message)
{
    if (client <= 0 || !IsClientInGame(client) || message[0] == '\0')
    {
        return;
    }

    PrintToChat(client, "%s", message);
}

void AnnounceSuccessfulSend(int requester)
{
    StartCooldown(gCvCooldownSeconds.FloatValue);

    char announceText[192];
    gCvAnnounceText.GetString(announceText, sizeof(announceText));
    if (announceText[0] == '\0')
    {
        strcopy(announceText, sizeof(announceText), "Need message sent");
    }

    int announceMode = gCvAnnounceMode.IntValue;
    if (announceMode == 2)
    {
        PrintToChatAll("%s", announceText);
    }
    else if (announceMode == 1)
    {
        NotifyClient(requester, announceText);
    }
}

void StartCooldown(float seconds)
{
    if (seconds <= 0.0)
    {
        return;
    }

    float nextAllowedUse = GetEngineTime() + seconds;
    if (nextAllowedUse > gNextAllowedUse)
    {
        gNextAllowedUse = nextAllowedUse;
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

    char webhookUrl[512];
    gCvWebhookUrl.GetString(webhookUrl, sizeof(webhookUrl));

    TrimString(webhookUrl);
    if (webhookUrl[0] == '\0')
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

    char payload[16384];
    if (!BuildWebhookPayload(client, payload, sizeof(payload)))
    {
        ReplyToCommand(client, "[Need] The webhook payload is too large or invalid. Reduce the configured message size.");
        return Plugin_Handled;
    }

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, webhookUrl);
    if (request == INVALID_HANDLE)
    {
        StartCooldown(gCvFailureCooldownSeconds.FloatValue);
        ReplyToCommand(client, "[Need] Failed to create the webhook request.");
        return Plugin_Handled;
    }

    if (!SteamWorks_SetHTTPCallbacks(request, OnWebhookCompleted))
    {
        delete request;
        StartCooldown(gCvFailureCooldownSeconds.FloatValue);
        ReplyToCommand(client, "[Need] Failed to initialize the webhook callback.");
        return Plugin_Handled;
    }

    SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, RoundToNearest(WEBHOOK_TIMEOUT_SECONDS));
    SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, WEBHOOK_TIMEOUT_MS);
    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", payload, strlen(payload));

    gWebhookPending = true;
    gPendingWebhookRequest = request;
    StartWebhookTimeoutTimer();

    if (!SteamWorks_SendHTTPRequest(request))
    {
        ClearWebhookPendingState(true);
        StartCooldown(gCvFailureCooldownSeconds.FloatValue);
        ReplyToCommand(client, "[Need] Failed to send the webhook request.");
        return Plugin_Handled;
    }

    AnnounceSuccessfulSend(client);
    ClearWebhookPendingState(false);

    return Plugin_Handled;
}

bool BuildWebhookPayload(int client, char[] buffer, int maxlen)
{
    int currentPlayers = GetRealPlayerCount();
    int maxPlayers = GetConfiguredMaxPlayers();

    char modeLabel[128];
    char plainContent[512];
    char mapName[PLATFORM_MAX_PATH];
    char username[128];
    char avatarUrl[512];
    char embedTitleTemplate[256];
    char embedDescriptionTemplate[512];
    char connectText[192];
    char statusLabel[64];
    char statusText[128];
    char playersLabel[64];
    char connectLabel[64];
    char requesterLabel[64];
    char footerTemplate[256];
    char playerName[MAX_NAME_LENGTH];

    gCvModeLabel.GetString(modeLabel, sizeof(modeLabel));
    gCvPlainContent.GetString(plainContent, sizeof(plainContent));
    gCvUsername.GetString(username, sizeof(username));
    gCvAvatarUrl.GetString(avatarUrl, sizeof(avatarUrl));
    gCvEmbedTitle.GetString(embedTitleTemplate, sizeof(embedTitleTemplate));
    gCvEmbedDescription.GetString(embedDescriptionTemplate, sizeof(embedDescriptionTemplate));
    gCvConnectText.GetString(connectText, sizeof(connectText));
    gCvStatusLabel.GetString(statusLabel, sizeof(statusLabel));
    gCvStatusText.GetString(statusText, sizeof(statusText));
    gCvPlayersLabel.GetString(playersLabel, sizeof(playersLabel));
    gCvConnectLabel.GetString(connectLabel, sizeof(connectLabel));
    gCvRequesterLabel.GetString(requesterLabel, sizeof(requesterLabel));
    gCvFooterText.GetString(footerTemplate, sizeof(footerTemplate));
    GetCurrentMap(mapName, sizeof(mapName));
    GetClientName(client, playerName, sizeof(playerName));

    char embedTitle[256];
    char embedDescription[768];
    char footerText[256];
    ApplyTemplate(embedTitleTemplate, embedTitle, sizeof(embedTitle), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName);
    ApplyTemplate(embedDescriptionTemplate, embedDescription, sizeof(embedDescription), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName);
    ApplyTemplate(footerTemplate, footerText, sizeof(footerText), currentPlayers, maxPlayers, modeLabel, mapName, connectText, playerName);

    char playersValue[32];
    FormatEx(playersValue, sizeof(playersValue), "%d / %d", currentPlayers, maxPlayers);

    char connectCode[256];
    FormatEx(connectCode, sizeof(connectCode), "```%s```", connectText);

    char escapedUsername[256];
    char escapedAvatarUrl[768];
    char escapedPlainContent[1024];
    char escapedEmbedTitle[512];
    char escapedEmbedDescription[1536];
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
    JsonEscape(plainContent, escapedPlainContent, sizeof(escapedPlainContent));
    JsonEscape(embedTitle, escapedEmbedTitle, sizeof(escapedEmbedTitle));
    JsonEscape(embedDescription, escapedEmbedDescription, sizeof(escapedEmbedDescription));
    JsonEscape(statusLabel, escapedStatusLabel, sizeof(escapedStatusLabel));
    JsonEscape(statusText, escapedStatusText, sizeof(escapedStatusText));
    JsonEscape(playersLabel, escapedPlayersLabel, sizeof(escapedPlayersLabel));
    JsonEscape(playersValue, escapedPlayersValue, sizeof(escapedPlayersValue));
    JsonEscape(connectLabel, escapedConnectLabel, sizeof(escapedConnectLabel));
    JsonEscape(connectCode, escapedConnectCode, sizeof(escapedConnectCode));
    JsonEscape(requesterLabel, escapedRequesterLabel, sizeof(escapedRequesterLabel));
    JsonEscape(playerName, escapedPlayerName, sizeof(escapedPlayerName));
    JsonEscape(footerText, escapedFooterText, sizeof(escapedFooterText));

    char imageUrl[512];
    BuildMapImageUrl(mapName, imageUrl, sizeof(imageUrl));
    int embedColor = ParseEmbedColor();

    if (imageUrl[0] != '\0')
    {
        char escapedImageUrl[768];
        JsonEscape(imageUrl, escapedImageUrl, sizeof(escapedImageUrl));

        int written = FormatEx(
            buffer,
            maxlen,
            "{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[{\"name\":\"%s\",\"value\":\"%s\",\"inline\":true},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":true},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":false},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":false}],\"footer\":{\"text\":\"%s\"},\"image\":{\"url\":\"%s\"}}]}",
            escapedUsername,
            escapedAvatarUrl,
            escapedPlainContent,
            escapedEmbedTitle,
            escapedEmbedDescription,
            embedColor,
            escapedStatusLabel,
            escapedStatusText,
            escapedPlayersLabel,
            escapedPlayersValue,
            escapedConnectLabel,
            escapedConnectCode,
            escapedRequesterLabel,
            escapedPlayerName,
            escapedFooterText,
            escapedImageUrl
        );
        return written > 0 && written < maxlen - 1;
    }

    int written = FormatEx(
        buffer,
        maxlen,
        "{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\",\"embeds\":[{\"title\":\"%s\",\"description\":\"%s\",\"color\":%d,\"fields\":[{\"name\":\"%s\",\"value\":\"%s\",\"inline\":true},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":true},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":false},{\"name\":\"%s\",\"value\":\"%s\",\"inline\":false}],\"footer\":{\"text\":\"%s\"}}]}",
        escapedUsername,
        escapedAvatarUrl,
        escapedPlainContent,
        escapedEmbedTitle,
        escapedEmbedDescription,
        embedColor,
        escapedStatusLabel,
        escapedStatusText,
        escapedPlayersLabel,
        escapedPlayersValue,
        escapedConnectLabel,
        escapedConnectCode,
        escapedRequesterLabel,
        escapedPlayerName,
        escapedFooterText
    );
    return written > 0 && written < maxlen - 1;
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

    strcopy(buffer, maxlen, buffer[underscorePos + 1]);
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

public void OnWebhookCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
    bool success = !failure && requestSuccessful && (statusCode == k_EHTTPStatusCode204NoContent || statusCode == k_EHTTPStatusCode200OK);
    delete request;

    if (!success)
    {
        LogError("[Need] Discord webhook failed. failure=%d successful=%d status=%d", failure, requestSuccessful, statusCode);
    }
}

void StartWebhookTimeoutTimer()
{
    if (gWebhookTimeoutTimer != null)
    {
        delete gWebhookTimeoutTimer;
    }

    gWebhookTimeoutTimer = CreateTimer(WEBHOOK_TIMEOUT_SECONDS, OnWebhookTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnWebhookTimeout(Handle timer)
{
    if (timer == gWebhookTimeoutTimer)
    {
        gWebhookTimeoutTimer = null;
    }

    if (gWebhookPending)
    {
        LogError("[Need] Webhook callback timed out after the request was already handed off.");
        ClearWebhookPendingState(false);
    }

    return Plugin_Stop;
}

void ClearWebhookPendingState(bool closeRequest)
{
    if (gWebhookTimeoutTimer != null)
    {
        delete gWebhookTimeoutTimer;
        gWebhookTimeoutTimer = null;
    }

    gWebhookPending = false;

    if (closeRequest && gPendingWebhookRequest != INVALID_HANDLE)
    {
        delete gPendingWebhookRequest;
    }

    gPendingWebhookRequest = INVALID_HANDLE;
}

void ApplyTemplate(const char[] input, char[] output, int maxlen, int currentPlayers, int maxPlayers, const char[] modeLabel, const char[] mapName, const char[] connectText, const char[] playerName)
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
    ReplaceString(output, maxlen, "\\n", "\n", false);
}

int ParseEmbedColor()
{
    char colorValue[32];
    gCvEmbedColor.GetString(colorValue, sizeof(colorValue));
    TrimString(colorValue);

    if (colorValue[0] == '\0')
    {
        return 5793266;
    }

    if (colorValue[0] == '#')
    {
        return StringToInt(colorValue[1], 16);
    }

    if (strlen(colorValue) > 2 && colorValue[0] == '0' && (colorValue[1] == 'x' || colorValue[1] == 'X'))
    {
        return StringToInt(colorValue[2], 16);
    }

    return StringToInt(colorValue);
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
