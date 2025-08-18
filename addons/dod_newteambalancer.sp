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

new bool:g_IsMapStart = false;
new bool:g_IsNewRound = false;

public OnPluginStart()
{
	cvarEnabled = CreateConVar("new_team_balancer_enable", "1", "Enables the DOD:S Balancer plugin");
	dbugEnabled = CreateConVar("new_team_balancer_debug", "0", "Enable debug logging for DOD:S Balancer");
	adminImmune = CreateConVar("new_team_balancer_admins", "0", "Enable DOD:S Balance admin immunity");
	maxTeamDiff = CreateConVar("new_team_balancer_maxdiff", "1", "Max imbalance for DOD:S Balancer to ignore");

	HookEvent("player_death", EventPlayerDeath);
	HookEvent("dod_round_start", EventRoundStart);
	AddCommandListener(CommandJoinTeam, "jointeam");
	PrintToServer("[NewTeamBalancer] multiple events hooked, plugin ready.");

	for (int client = 1; client <= MaxClients; client++) {
		g_PendingSwitch[client] = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	g_IsMapStart = true;
}

public void EventRoundStart(Event event, const char[] name, bool dontBroadcast) {
	// dont block join-team balancing for the first round
	if (!g_IsMapStart) {
		g_IsNewRound = true;
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] new round - disabling team-join balancing");
	}
	g_IsMapStart = false;
}

public Action CommandJoinTeam(int client, const char[] command, int argc)
{
	if (!GetConVarBool(cvarEnabled))
		return Plugin_Continue;

	// team-join balancing disabled until the first death
	// stop from interfering with plugins like jagdswitcher
	if (g_IsNewRound)
		return Plugin_Continue;

	 if (!IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	int newTeam = StringToInt(arg);
	int oldTeam = GetClientTeam(client);

	// dont balance going to spectator
	if (newTeam == 1)
		return Plugin_Continue;

	if (GetConVarBool(dbugEnabled)) {
		if (newTeam == 0)
			PrintToServer("[NewTeamBalancer] %N auto-assigning - checking balance.", client);
		else if (oldTeam < 2)
			PrintToServer("[NewTeamBalancer] %N joining team - checking balance.", client);
		else
			PrintToServer("[NewTeamBalancer] %N switching team - checking balance.", client);
	}

	if (newTeam == 0) {
		// auto-assign, pick one and balance accordingly
		newTeam = GetRandomInt(2, 3);
		if (CheckBalance(client, newTeam)) {
			SwitchTeam(client, newTeam, 0);
		} else {
			newTeam = (newTeam == 2) ? 3 : 2;
			SwitchTeam(client, newTeam, 0);
		}
		PrintToServer("[NewTeamBalancer] %N has been auto-assigned to team: %d", client, (newTeam-1));
		return Plugin_Handled;
	}

	if (!CheckBalance(client, newTeam)) {
		PrintCenterText(client, "Team is full!");
		if (newTeam == 2) {
			PrintToChat(client, "The U.S. Army is full!");
		} else {
			PrintToChat(client, "The Wehrmacht is full!");
		}
		PrintToServer("[NewTeamBalancer] %N has been blocked from team: %d", client, (newTeam-1));
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (g_IsNewRound && (attacker > 0)) {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] first kill - re-enabling team-join balancing");
		g_IsNewRound = false;
	}

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim <= 0 || !IsClientInGame(victim))
		return;

	if (GetConVarBool(dbugEnabled))
		if (attacker > 0)
			PrintToServer("[NewTeamBalancer] %N was killed - checking balance.", victim);
		else
			PrintToServer("[NewTeamBalancer] %N has died - checking balance.", victim);

	new team = GetClientTeam(victim);

	if (CheckBalance(victim, team))
		return;

	int newTeam = (team == 2) ? 3 : 2;
	if (attacker > 0) {
		// delay the move so it looks like a team kill
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] teams are out of balance, swapping %N soon.", victim);
		Handle swapData = CreateDataPack();
		WritePackCell(swapData, victim);
		WritePackCell(swapData, newTeam);
		WritePackCell(swapData, team);
		g_PendingSwitch[victim] = swapData;
		CreateTimer(2.5, TimerSwitchTeam, swapData);
	} else {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] teams are out of balance, swapping %N now.", victim);
		SwitchTeam(victim, newTeam, team);
	}
}

public bool CheckBalance(client, int team)
{
	if (g_PendingSwitch[client] != INVALID_HANDLE) {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] %N is already pending a switch. Ignoring event.", client);
		return true;
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
				return true;
			} else {
				if (GetConVarBool(dbugEnabled))
					PrintToServer("[NewTeamBalancer] teams are out of balance, %N should be swapped.", client);
				return false;
			}
		} else {
			if (GetConVarBool(dbugEnabled))
				PrintToServer("[NewTeamBalancer] teams are out of balance, but %N already there.", client);
			return true;
		}
	}

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] teams are in balance, %N needs no change.", client);
	return true;
}

public void SwitchTeam(client, int newTeam, int oldTeam)
{
	ChangeClientTeam(client, newTeam);
	if (oldTeam >= 2) {
		PrintToServer("[NewTeamBalancer] %N has been switched teams: from %d to %d", client, (oldTeam-1), (newTeam-1));
		PrintToChatAll("\x04[NewBal]\x01 %N has been switched to balance the teams.", client);
	}
}

public Action TimerSwitchTeam(Handle:timer, any:swapData)
{
	ResetPack(swapData);
	int client = ReadPackCell(swapData);
	int newTeam = ReadPackCell(swapData);
	int oldTeam = ReadPackCell(swapData);
	CloseHandle(swapData);
	g_PendingSwitch[client] = INVALID_HANDLE;

	int curTeam = GetClientTeam(client);

	if (curTeam == newTeam) {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] %N already switched - aborted: %d == %d",  client, (curTeam-1), (newTeam-1));
	} else if (curTeam != oldTeam) {
		if (GetConVarBool(dbugEnabled))
			PrintToServer("[NewTeamBalancer] %N moved somewhere - aborted: %d != %d",  client, (curTeam-1), (oldTeam-1));
	} else {
		SwitchTeam(client, newTeam, oldTeam);
	}

	return Plugin_Handled;
}
