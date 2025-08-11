#include <sourcemod>
#include <sdktools>

ConVar g_CvarBotLimitMax;
ConVar g_CvarDynBotDebug;

public Plugin myinfo = 
{
	name = "Dynamic Bot Limit",
	author = "Mloe",
	description = "Dynamicly adjust the number of bot during play",
	version = "0.1",
	url = ""
};

new bool:g_IsRoundStarted = false;
new g_RealMaxBots = 0;


public void OnPluginStart()
{
	g_CvarBotLimitMax = CreateConVar("dynamic_bot_limit_max", "20", "Maximum number of bots when adjusting the limit");
	g_CvarDynBotDebug = CreateConVar("dynamic_bot_debug_log", "1", "Enable debug logging when concidering the limit");
	HookEvent("dod_round_start", Event_RoundStart);
	HookEvent("dod_game_over", Event_GameOver);
        HookEvent("player_team", Event_PlayerTeam);
	PrintToServer("[DynamicBotLimit] multiple events hooked, plugin ready.");
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

	PrintToServer("[DynamicBotLimit] Allies: %d, Axis: %d - Max Bots: %d", alliesSpawns, axisSpawns, maxBots);
	g_RealMaxBots = maxBots;
}

public void Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("[DynamicBotLimit] game over - bots disabled until next level.");
	ServerCommand("rcbotd config max_bots 0");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_IsRoundStarted)
		return;

	g_IsRoundStarted = true;
	
	PrintToServer("[DynamicBotLimit] game started - setting new max: %d", g_RealMaxBots);
	SetNewBaxBots(0);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	if (GetConVarBool(g_CvarDynBotDebug))
		PrintToServer("[DynamicBotLimit] %N connected - increase the bot count", client);
	SetNewBaxBots(1);
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new newTeam = GetEventInt(event, "team");
        new oldTeam = GetEventInt(event, "oldteam");

        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
                return;

	// join play from unassigned/spectator
	if ((newTeam >= 2) && (oldTeam < 2)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N joined play: - decrease the bot count", client);
		SetNewBaxBots(-1);
		return;
	}

	// join spectators from active play
	if ((newTeam == 1) && (oldTeam >= 2)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N spectating: - increase the bot count", client);
		SetNewBaxBots(1);
	}

	// disconnected from spectator
	if ((newTeam == 0) && (oldTeam == 1)) {
		if (GetConVarBool(g_CvarDynBotDebug))
			PrintToServer("[DynamicBotLimit] %N disconnected: - decrease the bot count", client);
		SetNewBaxBots(-1);
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

void SetNewBaxBots(int change)
{

	g_RealMaxBots = g_RealMaxBots + change;
	char cmd[64];
	Format(cmd, sizeof(cmd), "rcbotd config max_bots %d", g_RealMaxBots);
	PrintToServer("[DynamicBotLimit] %s", cmd);
	ServerCommand(cmd);
}
