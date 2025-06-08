#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_PLAYERS 64

int stuckTime[MAX_PLAYERS + 1];
float lastPos[MAX_PLAYERS + 1][2];

ConVar g_CvarMaxStuckTime;
ConVar g_CvarDistThreshold;

public Plugin myinfo = 
{
    name = "Unstick Stationary Bots",
    author = "Mloe",
    description = "Kills glitched bots that are not moving",
    version = "0.1",
    url = ""
};

public void OnPluginStart()
{
     g_CvarMaxStuckTime = CreateConVar("stuckbot_max_stuck_time", "30", "Seconds a bot must be stuck before being killed", FCVAR_NONE, true, 1.0);
     g_CvarDistThreshold = CreateConVar("stuckbot_dist_threshold", "0.5", "Minimum movement required reset the stuck timer", FCVAR_NONE, true, 0.0);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    stuckTime[client] = 0;
    lastPos[client][0] = 0.0;
    lastPos[client][1] = 0.0;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    // Placeholder if needed — no special logic here for now
    return Plugin_Continue;
}

public void OnConfigsExecuted()
{
    CreateTimer(1.0, Timer_CheckPlayers, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckPlayers(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || !IsFakeClient(client) || IsWeaponActive(client))
        {
            stuckTime[client] = 0;
            continue;
        }

        float pos[3];
        GetClientAbsOrigin(client, pos);

        float dx = pos[0] - lastPos[client][0];
        float dy = pos[1] - lastPos[client][1];
        float dist = SquareRoot(dx * dx + dy * dy);

        if (dist <= g_CvarDistThreshold.FloatValue) 
        {
            stuckTime[client]++;

            if (stuckTime[client] >= g_CvarMaxStuckTime.IntValue) 
            {
                PrintToServer("[StuckBotKiller] Bot %N has not moved in %d seconds (%.1f, %.1f)", client, stuckTime[client], pos[0], pos[1]);
		PrintToChatAll("[StuckBotKiller] Bot %N is not moving and will be respawned.", client);
                KillClient(client); // work around because ForcePlayerSuicide() did not work
		stuckTime[client] = 0;
            }
        }
        else
        {
            stuckTime[client] = 0;
        }

        // Update the last known position
        lastPos[client][0] = pos[0];
        lastPos[client][1] = pos[1];
    }
    return Plugin_Continue;
}

bool IsWeaponActive(int client) {
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon <= 0 || !IsValidEntity(weapon))
        return false;

    // Check if the weapon has either deployment or zoom flag set
    if (HasEntProp(weapon, Prop_Send, "m_bDeployed") && GetEntProp(weapon, Prop_Send, "m_bDeployed") != 0)
    {
        return true;
    }

    if (HasEntProp(weapon, Prop_Send, "m_bZoomed") && GetEntProp(weapon, Prop_Send, "m_bZoomed") != 0)
    {
        return true;
    }

    return false;
}

void KillClient(int client)
{
    ForcePlayerSuicide(client);

    // Fallback in case suicide fails
    CreateTimer(0.1, Timer_KillWithDamage, GetClientUserId(client));
}

public Action Timer_KillWithDamage(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    SDKHooks_TakeDamage(client, client, client, 9999.0, DMG_GENERIC);
    return Plugin_Stop;
}
