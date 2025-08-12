#include <sourcemod>
#include <sdktools>

#define MAX_PLAYERS 64

int trackTeam[MAX_PLAYERS + 1];

ConVar g_CvarBotLimitMax;
ConVar g_CvarDynBotDebug;

public Plugin myinfo = 
{
	name = "Dynamic Bot Limit",
	author = "Mloe",
	description = "Dynamicly adjust the number of bots",
	version = "0.1",
	url = ""
};

new bool:g_IsRoundStarted = false;
new bool:g_IsHibernating = true;
new g_RealMaxBots = 0;


public void OnPluginStart()
{
	g_CvarBotLimitMax = CreateConVar("dynamic_bot_limit_max", "20", "Maximum number of bots when adjusting the limit");
	g_CvarDynBotDebug = CreateConVar("dynamic_bot_debug_log", "1", "Enable debug logging when concidering the limit");
	HookEvent("dod_round_start", Event_RoundStart);
	HookEvent("dod_game_over", Event_GameOver);
        HookEvent("player_team", Event_PlayerTeam);
        HookEvent("player_disconnect", Event_Disconnect);
	PrintToServer("[DynamicBotLimit] multiple events hooked, plugin ready.");

	for (int client = 1; client <= MaxClients; client++) {
	        if (IsClientInGame(client) && !IsFakeClient(client)) {
			trackTeam[client] = GetClientTeam(client);
			g_IsRoundStarted = false;
		}
	}
}

public OnMapStart()
{
	g_IsRoundStarted = false;

	int alliesSpawns = CountSpawns("info_player_allies");
	int axisSpawns   = CountSpawns("info_player_axis");

	int minSpawns = (alliesSpawns < axisSpawns) ? alliesSpawns : axisSpawns;
	int maxBots   = (2 * minSpawns) - 2;

	if (maxBots >= g_CvarBotLimitMax.IntValue) {
		maxBots = g_CvarBotLimitMax.IntValue;
	}
	PrintToServer("[DynamicBotLimit] new map - allies: %d, axis: %d, bots: %d", alliesSpawns, axisSpawns, maxBots);

	g_RealMaxBots = maxBots;
}

public void Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("[DynamicBotLimit] game over - bots disabled until next level.");
	ServerCommand("rcbotd config max_bots 0");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_IsHibernating || g_IsRoundStarted)
		return;

	g_IsRoundStarted = true;

	PrintToServer("[DynamicBotLimit] game started - overriding default max: %d", g_RealMaxBots);
	SetNewMaxBots(0);
}

public void Event_Disconnect(Event event, const char[] name, bool dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client)) {
		char reason[256];
		event.GetString("reason", reason, sizeof(reason));

		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N disconnected - %s", client, reason);

		if (g_IsHibernating)
			return;

		if (StrContains(reason, "server is hibernating", true) != -1) {
			g_IsHibernating = true;
			PrintToServer("[DynamicBotLimit] hibernating - bots disabled to allow sleep.");
			ServerCommand("rcbotd config max_bots 0");
		}
	} else {
		if (trackTeam[client] < 0) {
			if (GetConVarBool(g_CvarDynBotDebug))
				PrintToServer("[DynamicBotLimit] %N aborted - decrease the bot count", client);
			SetNewMaxBots(-1);
		}
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (IsFakeClient(client)) {
		if (g_IsHibernating) {
			PrintToServer("[DynamicBotLimit] hibernating - blocking bot from joining.");
			KickClient(client, "Blocking bot, server is hibernating");
			ServerCommand("rcbotd config max_bots 0");
			return false;
		}
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N connected - Added to server", client);
	} else {
		if (g_IsHibernating) {
			g_IsHibernating = false;
			PrintToServer("[DynamicBotLimit] server resuming - resetting bot limit.");
			SetNewMaxBots(0);
		}
	}

	return true;	
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	trackTeam[client] = -1;

	if (GetConVarBool(g_CvarDynBotDebug))
		PrintToServer("[DynamicBotLimit] %N connected - increase the bot count", client);
	SetNewMaxBots(1);
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new newTeam = GetEventInt(event, "team");
        new oldTeam = GetEventInt(event, "oldteam");

        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
                return;

	trackTeam[client] = newTeam;

	// join play from unassigned/spectator
	if ((newTeam >= 2) && (oldTeam < 2)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N joined play: - decrease the bot count", client);
		SetNewMaxBots(-1);
		return;
	}

	// join spectators from active play
	if ((newTeam == 1) && (oldTeam >= 2)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N spectating: - increase the bot count", client);
		SetNewMaxBots(1);
	}

	// disconnected from spectator/unassigned
	if ((newTeam == 0) && (oldTeam < 2)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N disconnected: - decrease the bot count", client);
		SetNewMaxBots(-1);
	}
}

int CountSpawns(const char[] classname)
{
	int count = 0;
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, classname)) != -1) {
		count++;
	}
	return count;
}

void SetNewMaxBots(int change)
{

	g_RealMaxBots = g_RealMaxBots + change;
	char cmd[64];
	Format(cmd, sizeof(cmd), "rcbotd config max_bots %d", g_RealMaxBots);
	if (GetConVarBool(g_CvarDynBotDebug))
		PrintToServer("[DynamicBotLimit] %s", cmd);
	ServerCommand(cmd);
}
