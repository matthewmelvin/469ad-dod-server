#include <sourcemod>
#include <sdktools>

ConVar g_CvarBotLimitMax;
ConVar g_CvarBotLimitDelay;

public Plugin myinfo = 
{
    name = "Dynamic Bot Limit",
    author = "Mloe",
    description = "Stop bots taking all the spawn slots",
    version = "0.1",
    url = ""
};


public void OnPluginStart()
{
    HookEvent("dod_round_start", Event_RoundStart);
    PrintToServer("[DynamicBotLimit] teamplay_round_start event hooked, plugin ready.");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    CreateTimer(g_CvarBotLimitDelay.FloatValue, Timer_SetBotLimit);
    PrintToServer("[DynamicBotLimit] teamplay_round_start event fired, timer set.");
}

public Action Timer_SetBotLimit(Handle timer)
{
    int alliesSpawns = CountSpawns("info_player_allies");
    int axisSpawns   = CountSpawns("info_player_axis");

    int minSpawns = (alliesSpawns < axisSpawns) ? alliesSpawns : axisSpawns;
    int maxBots   = (2 * minSpawns) - 2;

    if (maxBots >= g_CvarBotLimitMax.IntValue) {
        maxBots = g_CvarBotLimitMax.IntValue;
    }

    PrintToServer("[DynamicBotLimit] Allies: %d, Axis: %d - Max Bots: %d", alliesSpawns, axisSpawns, maxBots);

    if (maxBots < g_CvarBotLimitMax.IntValue) {
        char cmd[64];
        Format(cmd, sizeof(cmd), "rcbotd config max_bots %d", maxBots);
        PrintToServer("[DynamicBotLimit] %s", cmd);
        ServerCommand(cmd);
    }

    return Plugin_Stop;
}

int CountSpawns(const char[] classname)
{
    int count = 0;
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        count++;
    }
    return count;
}
