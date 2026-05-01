/*#if defined _steamworks_included
 #endinput
#endif
#define _steamworks_included

// General result codes
enum EResult
{
	k_EResultOK	= 1,							// success
	k_EResultFail = 2,							// generic failure 
	k_EResultNoConnection = 3,					// no/failed network connection
        k_EResultInvalidProtocolVer = 7,			// protocol version is incorrect
	k_EResultBusy = 10,							// called method busy - action not taken
	k_EResultInvalidState = 11,					// called object was in an invalid state
	k_EResultAccessDenied = 15,					// access is denied
	k_EResultTimeout = 16,						// operation timed out
	k_EResultInvalidSteamID = 19,				// steamID is invalid
	k_EResultServiceUnavailable = 20,			// The requested service is currently unavailable
        k_EResultEncryptionFailure = 23,			// Encryption or Decryption failed
	k_EResultInsufficientPrivilege = 24,		// Insufficient privilege
	k_EResultLimitExceeded = 25,				// Too much of a good thing
        k_EResultDuplicateRequest = 29,				// The request is a duplicate and the action has already occurred in the past, ignored this time
	k_EResultIPNotFound = 31,					// IP address not found
	k_EResultLogonSessionReplaced = 34,
	k_EResultConnectFailed = 35,
	k_EResultHandshakeFailed = 36,
	k_EResultIOFailure = 37,
	k_EResultRemoteDisconnect = 38,
        k_EResultIPLoginRestrictionFailed = 72,
	k_EResultUnexpectedError = 79,				// something happened that we didn't expect to ever happen
	k_EResultDisabled = 80,						// The requested service has been configured to be unavailable
};

// results from UserHasLicenseForApp
enum EUserHasLicenseForApp
{
	k_EUserHasLicenseResultHasLicense = 0,					// User has a license for specified app
	k_EUserHasLicenseResultDoesNotHaveLicense = 1,			// User does not have a license for the specified app
	k_EUserHasLicenseResultNoAuth = 2,						// User has not been authenticated
};
*/

/**
 * Gets the current status of VAC on the server.
 *
 * @return A bool representing the current VAC status.
 */
//native bool:Steamworks_IsVACEnabled();

/**
 * Gets the server's external IP address, as reported by Steam.
 *
 * @param octets    Reference to an array to be filled with the octets of 
 *                  the IP address.
 * 
 * @noreturn
 */
//native Steamworks_GetPublicIP(addr[4]);

/**
 * Gets the server's external IP address, as reported by Steam.
 * 
 * @return IP in int32 representation
 */
//native Steamworks_GetPublicIPCell();

/**
 * Gets the current Steam connection state, the forwards below fire 
 * whenever this changes.
 *
 * @return Steam connection state.
 */
//native bool:Steamworks_IsConnected();

/**
 * Checks if Steam is loaded
 *
 * @return Steam loaded state.
 */
//native bool:Steamworks_IsLoaded();

/**
 * Changes the game description, as reported in the server browser.
 *
 * @param desc      New game description
 * 
 * @noreturn
 */
//native Steamworks_SetGameDescription(const String:desc[]);

/**
 * Sets an entry in the server's list of rules. This list is used to 
 * build the response to the A2S_RULES query and is generally known as 
 * the list of public convars.
 *
 * @param key       Name of the key to set, is created if it does not already
 *                  exist.
 * @param value     Value of the key to set, the named key is removed if this 
 *                  is blank.
 *
 * @noreturn
 */
//native Steamworks_SetRule(const String:key[], const String:value[]);

/**
 * Clears the server's list of rules. This list is used to build the 
 * response to the A2S_RULES query and is generally known as the list of 
 * public convars.
 *
 * @noreturn
 */
//native Steamworks_ClearRules();

/**
 * Force a heartbeat to the Steam servers at the next opportunity
 *
 * @noreturn
 */
//native Steamworks_ForceHeartbeat();

/**
 * Checks if the Steam master servers are reporting your server as 
 * outdated
 *
 * @return True or false
 */
//native bool:Steamworks_WasRestartRequested();

/**
 * Checks if a client owns license for the specified AppID
 *
 * @param client    Client index on the server
 * @param appID     AppID index
 * 
 * @return One of EUserHasLicenseForApp values
 */
//native EUserHasLicenseForApp:Steamworks_UserHasSubscription(client, appID);


/**
 * Fired upon a successfull connection to Steam.
 *
 * @noreturn
 */
//forward Steamworks_OnServersConnected();

/**
 * Fired if an attempted connection to Steam fails
 *
 * @param EResult   Reason of failure
 *
 * @noreturn
 */
//forward Steamworks_OnServersConnectFailure(EResult:result);

/**
 * Fired upon disconnection from Steam.
 *
 * @param EResult   Reason of disconnection
 *
 * @noreturn
 */
//forward Steamworks_OnServersDisconnected(EResult:result);

/**
 * Fires whenever a Family Options(formerly "Sharing") user has passed authentication validation
 *
 * @param steamID       Client SteamID
 * @param ownerSteamID      Owner SteamID
 *
 * @noreturn
 */
forward SteamWorksL4D2_OnFamilySharingDetected(const String:steamID[], const String:ownerSteamID[]);


public Extension:__ext_SteamWorks = 
{
	name = "Steamworks - Left 4 Dead 2",
	file = "SteamWorks-left4dead2.ext",
	
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
	
};
