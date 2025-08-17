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

#define MAX_PLAYERS 64

new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:dbugEnabled = INVALID_HANDLE;
new Handle:adminImmune = INVALID_HANDLE;
new Handle:maxTeamDiff = INVALID_HANDLE;

new Handle:g_PendingSwitch[MAXPLAYERS + 1];

public OnPluginStart()
{
	cvarEnabled = CreateConVar("new_team_balancer_enable", "1", "Enables the DOD:S Balancer plugin");
	dbugEnabled = CreateConVar("new_team_balancer_debug", "0", "Enable debug logging for DOD:S Balancer");
	adminImmune = CreateConVar("new_team_balancer_admins", "0", "Enable DOD:S Balance admin immunity");
	maxTeamDiff = CreateConVar("new_team_balancer_maxdiff", "1", "Max imbalance for DOD:S Balancer to ignore");

	HookEvent("player_death", EventPlayerDeath);
	PrintToServer("[NewTeamBalancer] player_death events hooked, plugin ready.");

	for (int client = 1; client <= MaxClients; client++) {
		g_PendingSwitch[client] = INVALID_HANDLE;
	}
}

public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim <= 0 || !IsClientInGame(victim))
		return;

	if (GetConVarBool(dbugEnabled))
		if (attacker > 0)
			PrintToServer("[NewTeamBalancer] %N was killed - checking balance.", victim);
		else
			PrintToServer("[NewTeamBalancer] %N has died - checking balance.", victim);

	new team = GetClientTeam(victim);

	if (attacker > 0) {
		// delay the move so it doesnt look like a team kill
		CheckAndBalance(victim, team, 6.2);
	} else {
		CheckAndBalance(victim, team, 0.0);
	}
}

public CheckAndBalance(client, int team, float delay)
{
	if (g_PendingSwitch[client] != INVALID_HANDLE) {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] %N is already pending a switch. Ignoring event.", client);
		return;
	}

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
		else if (g_PendingSwitch[i] != INVALID_HANDLE) {
			ResetPack(g_PendingSwitch[i]);
			ReadPackCell(g_PendingSwitch[i]);
			t = ReadPackCell(g_PendingSwitch[i]);
		} else
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
				int newTeam = (team == 2) ? 3 : 2;
				if (delay > 0) {
					if (GetConVarBool(dbugEnabled))
						PrintToServer("[NewTeamBalancer] teams are out of balance, %N will be swapped", client);
					Handle swapData = CreateDataPack();
					WritePackCell(swapData, client);
					WritePackCell(swapData, newTeam);
					WritePackCell(swapData, team);
					g_PendingSwitch[client] = swapData;
					CreateTimer(delay, TimerSwitchTeam, swapData);
				} else {
					if (GetConVarBool(dbugEnabled))
						PrintToServer("[NewTeamBalancer] teams are out of balance, swapping %N now", client);
					SwitchTeam(client, newTeam, team);
				}
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

public SwitchTeam(client, int newTeam, int oldTeam)
{
	int curTeam = GetClientTeam(client);

	if (curTeam == newTeam) {
		PrintToServer("[NewTeamBalancer] %N already switched - aborted: %d == %d",  client, (curTeam-1), (newTeam-1));
		return;
	}

	if (curTeam != oldTeam) {
		PrintToServer("[NewTeamBalancer] %N moved somewhere - aborted: %d != %d", client, (curTeam-1), (oldTeam-1));
		return;
	}

	ChangeClientTeam(client, newTeam);
	PrintToServer("[NewTeamBalancer] %N has been switched teams: from %d to %d", client, (oldTeam-1), (newTeam-1));
	PrintToChatAll("\x04[NewBal]\x01 %N has been switched to balance the teams.", client);
}

public Action:TimerSwitchTeam(Handle:timer, any:swapData)
{
	ResetPack(swapData);
	int client = ReadPackCell(swapData);
	int newTeam = ReadPackCell(swapData);
	int oldTeam = ReadPackCell(swapData);
	CloseHandle(swapData);
	g_PendingSwitch[client] = INVALID_HANDLE;

	SwitchTeam(client, newTeam, oldTeam);
	return Plugin_Handled;
}
