/*
dodsBalancer.sp

Description:
	Keeps DOD:S teams (roughly) even

Versions:
	1.1.0	* concider humans seperately from bots
		* configurable admin immunity
		* add debug variable and logging
	1.0.1	* add max team difference by [BzzB]HGSteiner
	1.0	* Initial Release
		
*/

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.1.0"

#define TEAM_1 2
#define TEAM_2 3

public Plugin:myinfo =
{
	name = "DOD:S Balancer",
	author = "AMP + Mloe",
	description = "Keeps DOD:S teams (roughly) even",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:maxteamdiff = INVALID_HANDLE;
new Handle:dbugEnabled = INVALID_HANDLE;
new Handle:adminImmune = INVALID_HANDLE;

public OnPluginStart()
{
	cvarEnabled = CreateConVar("sm_dods_balancer_enable", "1", "Enables the DOD:S Balancer plugin");

	dbugEnabled = CreateConVar("sm_dods_balancer_debug", "0", "Enable debug logging for DOD:S Balancer");

	adminImmune = CreateConVar("sm_dods_balancer_admins", "0", "Enable DOD:S Balance admin immunity");
	
	maxteamdiff = CreateConVar("sm_dods_balancer_maxteamdiff", "1", "Max team player difference 1-5");

	CreateConVar("sm_dods_balancer_version", PLUGIN_VERSION, "DOD:S Balancer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookEvent("player_death", EventPlayerDeath);
}

public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	new victimClient = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:victimName[64];
	GetClientName(victimClient, victimName, sizeof(victimName));
	new victimFake = IsFakeClient(victimClient);
	if (GetConVarBool(dbugEnabled)) {
		if (!victimFake)
			PrintToServer("[NewBal] %s is a human. Ignoring bots in the team count.", victimName);
		else
			PrintToServer("[NewBal] %s is a bot. Including all in the team count.", victimName);
	}
	
	new team1;
	new team2;
	for (new i = 1; i < MaxClients; i++) {
		if (!IsClientInGame(i)) continue;

		if (!victimFake && IsFakeClient(i)) continue;

		if (GetClientTeam(i) == TEAM_1)
			team1++;
		else if (GetClientTeam(i) == TEAM_2)
			team2++;
	}

	new maxDiff = GetConVarInt(maxteamdiff);
	if (maxDiff < 1 || maxDiff > 5) {
		SetConVarInt(maxteamdiff, 1);
		maxDiff = 1;
	}
	new curDiff = team1 - team2;
	new team = GetClientTeam(victimClient);

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewBal] player: %s, team: %d, counts: %d vs %d, diff: %d, max: %d", victimName, (team-1), team1, team2, curDiff, maxDiff);

	if (curDiff > maxDiff || -curDiff > maxDiff) {
		if ((team == TEAM_1 && curDiff > maxDiff) || (team == TEAM_2 && -curDiff > maxDiff)) {
			if (GetConVarBool(adminImmune) && GetUserAdmin(victimClient) != INVALID_ADMIN_ID) {
				PrintToServer("[NewBal] teams are out of balance, but %s is an admin.", victimName);
			} else {
				if (GetConVarBool(dbugEnabled))
					PrintToServer("[NewBal] teams are out of balance, %s will be swapped", victimName);
				CreateTimer(0.2, TimerSwitchTeam, victimClient);
			}
		} else {
			if (GetConVarBool(dbugEnabled))
				PrintToServer("[NewBal] teams are out of balance, but %s already there.", victimName);
		}
	} else {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewBal] teams are in balance, leaving %s alone.", victimName);
	}
}

public GetOtherTeam(team)
{
	if (team == TEAM_2)
		return TEAM_1;
	else
		return TEAM_2;
}

public Action:TimerSwitchTeam(Handle:timer, any:client)
{
	decl String:clientName[64];
	ChangeClientTeam(client, GetOtherTeam(GetClientTeam(client)));
	GetClientName(client, clientName, sizeof(clientName));
	PrintToServer("[NewBal] %s has been switched to balance the teams.", clientName);		
	PrintToChatAll("\x04[NewBal]\x01 %s has been switched to balance the teams.", clientName);		
	return Plugin_Handled;
}
