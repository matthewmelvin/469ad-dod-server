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
new Handle:dbugEnabled = INVALID_HANDLE;
new Handle:adminImmune = INVALID_HANDLE;
new Handle:maxTeamDiff = INVALID_HANDLE;

public OnPluginStart()
{
	cvarEnabled = CreateConVar("new_team_balancer_enable", "1", "Enables the DOD:S Balancer plugin");
	dbugEnabled = CreateConVar("new_team_balancer_debug", "0", "Enable debug logging for DOD:S Balancer");
	adminImmune = CreateConVar("new_team_balancer_admins", "0", "Enable DOD:S Balance admin immunity");
	maxTeamDiff = CreateConVar("new_team_balancer_maxdiff", "1", "Max imbalance for DOD:S Balancer to ignore");

	HookEvent("player_death", EventPlayerDeath);
	HookEvent("player_team", EventPlayerTeam);
	PrintToServer("[NewTeamBalancer] multiple events hooked, plugin ready.");
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

	// only balance if newly joining play
	if ((newTeam < 2) || (oldTeam >= 2))
		return;

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] %N joined: - checking balance.", client, newTeam, oldTeam);

	CheckAndBalance(client, newTeam);
}

public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	new victimClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victimClient <= 0 || !IsClientInGame(victimClient))
		return;

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] %N died: - checking balance.", victimClient);

	new team = GetClientTeam(victimClient);

	CheckAndBalance(victimClient, team);
}

public CheckAndBalance(client, int team)
{
	new isBot = IsFakeClient(client);

	if (GetConVarBool(dbugEnabled)) {
		if (!isBot)
			PrintToServer("[NewTeamBalancer] %N is a human. Ignoring bots in the team count.", client);
		else
			PrintToServer("[NewTeamBalancer] %N is a bot. Including all in the team count.", client);
	}

	new team1 = 0;
	new team2 = 0;

	new t; for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;

		if (!isBot && IsFakeClient(i))
			continue;

		if (i == client)
			t = team;
		else
			t = GetClientTeam(i);

		if (t == 2)
			team1++;
		else if (t == 3)
			team2++;
	}

	new maxDiff = GetConVarInt(maxTeamDiff);
	if (maxDiff < 1) {
		SetConVarInt(maxTeamDiff, 1);
		maxDiff = 1;
	}
	if (maxDiff > 5) {
		SetConVarInt(maxTeamDiff, 5);
		maxDiff = 5;
	}
	new curDiff = team1 - team2;

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] %N - team: %d, counts: %d vs %d, diff: %d, max: %d",
			client, (team-1), team1, team2, curDiff, maxDiff);

	if (curDiff > maxDiff || -curDiff > maxDiff)
	{
		if ((team == 2 && curDiff > maxDiff) || (team == 3 && -curDiff > maxDiff))
		{
			if (GetConVarBool(adminImmune) && GetUserAdmin(client) != INVALID_ADMIN_ID) {
				PrintToServer("[NewTeamBalancer] teams are out of balance, but %N is an admin.", client);
			} else {
				if (GetConVarBool(dbugEnabled))
					PrintToServer("[NewTeamBalancer] teams are out of balance, %N will be swapped", client);
				CreateTimer(0.3, TimerSwitchTeam, client);
			}
		} else {
			if (GetConVarBool(dbugEnabled))
				PrintToServer("[NewTeamBalancer] teams are out of balance, but %N already there.", client);
		}
	} else {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] teams are in balance, leaving %N alone.", client);
	}
}

public GetOtherTeam(team)
{
	if (team == 2)
		return 3;
	else if (team == 3)
		return 2;
	else
		return team;
}

public Action:TimerSwitchTeam(Handle:timer, any:client)
{
	ChangeClientTeam(client, GetOtherTeam(GetClientTeam(client)));
	PrintToServer("[NewTeamBalancer] %N has been switched to balance the teams.", client);
	PrintToChatAll("\x04[NewBal]\x01 %N has been switched to balance the teams.", client);
	return Plugin_Handled;
}
