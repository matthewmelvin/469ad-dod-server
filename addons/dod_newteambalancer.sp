#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "New Team Balancer",
	author = "Mloe",
	description = "Keeps DOD:S teams (roughly) even",
	version = "0.2",
	url = ""
};

new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:maxteamdiff = INVALID_HANDLE;
new Handle:dbugEnabled = INVALID_HANDLE;
new Handle:adminImmune = INVALID_HANDLE;

public OnPluginStart()
{
	cvarEnabled = CreateConVar("new_team_balancer_enable", "1", "Enables the DOD:S Balancer plugin");
	dbugEnabled = CreateConVar("new_team_balancer_debug", "0", "Enable debug logging for DOD:S Balancer");
	adminImmune = CreateConVar("new_team_balancer_admins", "0", "Enable DOD:S Balance admin immunity");
	maxteamdiff = CreateConVar("new_team_balancer_maxteamdiff", "1", "Max team player difference 1-5");

	HookEvent("player_death", EventPlayerDeath);
	HookEvent("player_team", EventPlayerTeam);
	PrintToServer("[NewTeamBalancer] player_death and player_team events hooked, plugin ready.");
}

public EventPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0 || !IsClientInGame(client))
		return;

	new newTeam = GetEventInt(event, "team");
	new oldTeam = GetEventInt(event, "oldteam");

	if ((newTeam < 2) || (oldTeam >= 2))
		return;

	CheckAndBalance(client);
}

public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	new victimClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victimClient <= 0 || !IsClientInGame(victimClient))
		return;

	CheckAndBalance(victimClient);
}

public CheckAndBalance(client)
{
	decl String:clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
	new isBot = IsFakeClient(client);

	if (GetConVarBool(dbugEnabled)) {
		if (!isBot)
			PrintToServer("[NewTeamBalancer] %s is a human. Ignoring bots in the team count.", clientName);
		else
			PrintToServer("[NewTeamBalancer] %s is a bot. Including all in the team count.", clientName);
	}

	new team1 = 0;
	new team2 = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) continue;

		if (!isBot && IsFakeClient(i)) continue;

		if (GetClientTeam(i) == 2)
			team1++;
		else if (GetClientTeam(i) == 3)
			team2++;
	}

	new maxDiff = GetConVarInt(maxteamdiff);
	if (maxDiff < 1 || maxDiff > 5)
	{
		SetConVarInt(maxteamdiff, 1);
		maxDiff = 1;
	}
	new curDiff = team1 - team2;
	new team = GetClientTeam(client);

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] (%s) team: %d, counts: %d vs %d, diff: %d, max: %d",
			clientName, (team-1), team1, team2, curDiff, maxDiff);

	if (curDiff > maxDiff || -curDiff > maxDiff)
	{
		if ((team == 2 && curDiff > maxDiff) || (team == 3 && -curDiff > maxDiff))
		{
			if (GetConVarBool(adminImmune) && GetUserAdmin(client) != INVALID_ADMIN_ID) {
				PrintToServer("[NewTeamBalancer] teams are out of balance, but %s is an admin.", clientName);
			} else {
				if (GetConVarBool(dbugEnabled))
					PrintToServer("[NewTeamBalancer] teams are out of balance, %s will be swapped", clientName);
				CreateTimer(0.2, TimerSwitchTeam, client);
			}
		} else {
			if (GetConVarBool(dbugEnabled))
				PrintToServer("[NewTeamBalancer] teams are out of balance, but %s already there.", clientName);
		}
	} else {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] teams are in balance, leaving %s alone.", clientName);
	}
}

public GetOtherTeam(team)
{
	if (team == 3)
		return 2;
	else
		return 3;
}

public Action:TimerSwitchTeam(Handle:timer, any:client)
{
	decl String:clientName[64];
	ChangeClientTeam(client, GetOtherTeam(GetClientTeam(client)));
	GetClientName(client, clientName, sizeof(clientName));
	PrintToServer("[NewTeamBalancer] %s has been switched to balance the teams.", clientName);
	PrintToChatAll("\x04[NewBal]\x01 %s has been switched to balance the teams.", clientName);		
	return Plugin_Handled;
}
