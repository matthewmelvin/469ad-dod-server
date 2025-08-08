#include <sourcemod>
#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "No Bot Friendly Fire",
	author = "Mloe",
	description = "Stop bots from hurting their team mates",
	version = "0.1",
	url = ""
}

public void OnPluginStart()
{
    PrintToServer("[NoBotsFriendlyFire] hooking OnTakeDamage on clients...");
}

public OnClientPutInServer(client)
{
	if (!IsFakeClient(client)) {
    		PrintToServer("[NoBotsFriendlyFire] hooking OnTakeDamage on %N", client);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public OnClientDisconnect(client)
{
	if (!IsFakeClient(client)) {
    		PrintToServer("[NoBotsFriendlyFire] unhooking OnTakeDamage on %N", client);
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action:OnTakeDamage(client, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if (!IsValidClient(client) || !IsValidClient(iAttacker) || !IsFakeClient(iAttacker))
	{
		return Plugin_Continue;
	}

	new TeamClient = GetClientTeam(client);
	new TeamAttacker = GetClientTeam(iAttacker);

	if ((TeamClient < 2) || (TeamAttacker < 2) || (TeamAttacker != TeamClient))
	{
		return Plugin_Continue;
	}

	char inflictor[64] = "unknown";
	char damageType[64];
	if (IsValidEdict(iInflictor))
	{
		GetEdictClassname(iInflictor, inflictor, sizeof(inflictor));
	}
	GetDamageTypeString(iDamageType, damageType, sizeof(damageType));
	

	if (StrEqual(inflictor, "player") || StrEqual(inflictor, "rocket_bazooka") || StrEqual(inflictor, "rocket_pschreck"))
	{
		PrintToServer("[NoBotsFriendlyFire] %N hurting %N blocked: %s / %s", iAttacker, client, inflictor, damageType);
		return Plugin_Handled;
	}

	PrintToServer("[NoBotsFriendlyFire] %N hurt %N indirectly: %s / %s", iAttacker, client, inflictor, damageType);
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	} else {
		return false;
	}
}

void GetDamageTypeString(int iDamageType, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "");
	
	// See https://developer.valvesoftware.com/wiki/Damage_types
	if (iDamageType & DMG_GENERIC)			Format(buffer, maxlen, "%sGENERIC ", buffer);
	if (iDamageType & DMG_CRUSH)			Format(buffer, maxlen, "%sCRUSH ", buffer);
	if (iDamageType & DMG_BULLET)			Format(buffer, maxlen, "%sBULLET ", buffer);
	if (iDamageType & DMG_SLASH)			Format(buffer, maxlen, "%sSLASH ", buffer);
	if (iDamageType & DMG_BURN)			Format(buffer, maxlen, "%sBURN ", buffer);
	if (iDamageType & DMG_VEHICLE)			Format(buffer, maxlen, "%sVEHICLE ", buffer);
	if (iDamageType & DMG_FALL)			Format(buffer, maxlen, "%sFALL ", buffer);
	if (iDamageType & DMG_BLAST)			Format(buffer, maxlen, "%sBLAST ", buffer);
	if (iDamageType & DMG_CLUB)			Format(buffer, maxlen, "%sCLUB ", buffer);
	if (iDamageType & DMG_SHOCK)			Format(buffer, maxlen, "%sSHOCK ", buffer);
	if (iDamageType & DMG_SONIC)			Format(buffer, maxlen, "%sSONIC ", buffer);
	if (iDamageType & DMG_ENERGYBEAM)		Format(buffer, maxlen, "%sENERGYBEAM ", buffer);
	if (iDamageType & DMG_PREVENT_PHYSICS_FORCE)	Format(buffer, maxlen, "%sPREVENT_PHYSICS_FORCE ", buffer);
	if (iDamageType & DMG_NEVERGIB)			Format(buffer, maxlen, "%sNEVERGIB ", buffer);
	if (iDamageType & DMG_ALWAYSGIB)     		Format(buffer, maxlen, "%sALWAYSGIB ", buffer);
	if (iDamageType & DMG_DROWN)			Format(buffer, maxlen, "%sDROWN ", buffer);
	if (iDamageType & DMG_PARALYZE)			Format(buffer, maxlen, "%sPARALYZE ", buffer);
	if (iDamageType & DMG_NERVEGAS)			Format(buffer, maxlen, "%sNERVEGAS ", buffer);
	if (iDamageType & DMG_RADIATION)		Format(buffer, maxlen, "%sRADIATION ", buffer);
	if (iDamageType & DMG_DROWNRECOVER)		Format(buffer, maxlen, "%sDROWNRECOVER ", buffer);
	if (iDamageType & DMG_ACID)			Format(buffer, maxlen, "%sACID ", buffer);
	if (iDamageType & DMG_SLOWBURN)			Format(buffer, maxlen, "%sSLOWBURN ", buffer);
	if (iDamageType & DMG_REMOVENORAGDOLL)		Format(buffer, maxlen, "%sREMOVENORAGDOLL ", buffer);
	if (iDamageType & DMG_PHYSGUN)			Format(buffer, maxlen, "%sPHYSGUN ", buffer);
	if (iDamageType & DMG_PLASMA)			Format(buffer, maxlen, "%sPLASMA ", buffer);
	if (iDamageType & DMG_AIRBOAT)			Format(buffer, maxlen, "%sAIRBOAT ", buffer);
	if (iDamageType & DMG_DISSOLVE)			Format(buffer, maxlen, "%sDISSOLVE ", buffer);
	if (iDamageType & DMG_BLAST_SURFACE)		Format(buffer, maxlen, "%sBLAST_SURFACE ", buffer);
	if (iDamageType & DMG_DIRECT)			Format(buffer, maxlen, "%sDIRECT ", buffer);
	if (iDamageType & DMG_BUCKSHOT)			Format(buffer, maxlen, "%sBUCKSHOT ", buffer);

	if (StrEqual(buffer, ""))
	{
		Format(buffer, maxlen, "UNKNOWN");
    	}
}
