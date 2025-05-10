#include <sourcemod>
#include <sdktools>

#define MAX_PLAYERS 64

int stuckTime[MAX_PLAYERS + 1];

ConVar g_CvarMaxStuckTime;
ConVar g_CvarDistThreshold;

public Plugin myinfo = 
{
    name = "Unstick Origin Bots",
    author = "Mloe",
    description = "Kills glitched bots stuck at x=0,y=0",
    version = "0.1",
    url = ""
};

public void OnPluginStart()
{
     g_CvarMaxStuckTime = CreateConVar("stuckbot_max_stuck_time", "20", "Seconds a bot must be stuck before being killed", FCVAR_NONE, true, 1.0);
     g_CvarDistThreshold = CreateConVar("stuckbot_dist_threshold", "100.0", "Max distance from origin to consider stuck", FCVAR_NONE, true, 0.0);
}

public void OnConfigsExecuted()
{
    CreateTimer(1.0, Timer_CheckPlayers, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
     PrintToServer("[StuckBotKiller] Bots within %.1f of 0,0 for %d secs concidered stuck.",
        g_CvarDistThreshold.FloatValue,
        g_CvarMaxStuckTime.IntValue);
}

public Action Timer_CheckPlayers(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || !IsFakeClient(client))
        {
            stuckTime[client] = 0;
            continue;
        }


        float pos[3];
        GetClientAbsOrigin(client, pos);

        float distance = SquareRoot(pos[0] * pos[0] + pos[1] * pos[1]);
        // PrintToServer("[StuckBotKiller] Bot %N is %.1f from the origin", client, distance);
        if (distance <= g_CvarDistThreshold.FloatValue) 
        {
            stuckTime[client]++;

            if (stuckTime[client] < g_CvarMaxStuckTime.IntValue) 
            {
                // PrintToServer("[StuckBotKiller] Bot %N in the detection zone (%.1f, %.1f)", client, pos[0], pos[1]);
            }
            else
            {
                PrintToServer("[StuckBotKiller] Bot %N stuck in the middle (%.1f, %.1f)", client, pos[0], pos[1]);
		PrintToChatAll("[StuckBotKiller] Bot %N stuck in the middle, killing.", client);
                ForcePlayerSuicide(client);
                stuckTime[client] = 0; // Reset after action
            }
        }
        else
        {
            stuckTime[client] = 0;
        }
    }
    return Plugin_Continue;
}

