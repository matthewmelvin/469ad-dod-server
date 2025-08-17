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
	HookEvent("player_team", EventPlayerTeam);
	HookEvent("dod_round_start", EventRoundStart);
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

public EventPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
		return;

	// team-join balancing disabled until the first death
	// stop from interfering with plugins like jagdswitcher
	if (g_IsNewRound)
		return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	new newTeam = GetEventInt(event, "team");
	new oldTeam = GetEventInt(event, "oldteam");

	// only balance if newly joining play
	if ((newTeam < 2) || (oldTeam >= 2))
		return;

	if ((newTeam == 3) & (GetUserAdmin(client) != INVALID_ADMIN_ID)) {
		// force switch regardless of balance
		newTeam = (newTeam == 2) ? 3 : 2;
		PrintToServer("[NewTeamBalancer] %N joined - switching admin.", client, newTeam, oldTeam);
		SwitchTeam(client, newTeam, oldTeam);
		return;
	}

	if (GetConVarBool(dbugEnabled))
		PrintToServer("[NewTeamBalancer] %N joined - checking balance.", client, newTeam, oldTeam);

	// delay so the join can finish
	CheckAndBalance(client, newTeam, 0.0);
}

public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
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
				int oldTeam = (team == 2) ? 3 : 2;
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
					SwitchTeam(client, newTeam, oldTeam);
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

	if (oldTeam < 2) {
		// cancel pending class choice from old team
		FakeClientCommand(client, "joinclass 0");		
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
