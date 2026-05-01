Drop this folder's contents into your game server root so the paths line up as:

- addons/sourcemod/plugins/need_webhook.smx
- addons/sourcemod/extensions/steamworks.ext.so
- addons/sourcemod/scripting/need_webhook.sp
- addons/sourcemod/scripting/include/steamworks.inc
- addons/sourcemod/scripting/include/steamworks-l4d2.inc
- cfg/sourcemod/need_webhook.cfg

Notes:
- The included SteamWorks binary is Linux: steamworks.ext.so
- The webhook config in cfg/sourcemod/need_webhook.cfg is prefilled
- If the server still does not send, check the SourceMod logs for SteamWorks load errors or webhook timeout/failure messages
