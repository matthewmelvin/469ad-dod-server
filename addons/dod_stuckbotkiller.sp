#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_PLAYERS 64

int stuckTime[MAX_PLAYERS + 1];
float lastPos[MAX_PLAYERS + 1][3];
float spawnPos[MAX_PLAYERS + 1][3];
float totalDist[MAX_PLAYERS + 1];

ConVar g_CvarMaxStuckTime;
ConVar g_CvarDistThreshold;
ConVar g_CvarTrackingDebug;

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
	g_CvarMaxStuckTime = CreateConVar("stuckbot_max_stuck_time", "30", "Seconds a bot must be stuck before being killed");
	g_CvarDistThreshold = CreateConVar("stuckbot_dist_threshold", "0.5", "Minimum movement required reset the stuck timer");
	g_CvarTrackingDebug = CreateConVar("stuckbot_dist_debug_log", "0", "Enable debug logging when calculating movement");

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	PrintToServer("[StuckBotKiller] player_spawn event hooked, plugin ready.");

        for (int client = 1; client <= MaxClients; client++) {
                if (IsClientInGame(client) && IsFakeClient(client)) {
			stuckTime[client] = 0;
			lastPos[client][0] = lastPos[client][1] = lastPos[client][2] = 0.0;
			spawnPos[client][0] = spawnPos[client][1] = spawnPos[client][2] = 0.0;
			totalDist[client] = 0.0;
		}
	}
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
		return;

	stuckTime[client] = 0;
	lastPos[client][0] = lastPos[client][1] = lastPos[client][2] = 0.0;
	spawnPos[client][0] = spawnPos[client][1] = spawnPos[client][2] = 0.0;
	totalDist[client] = 0.0;
}

public void OnConfigsExecuted()
{
    CreateTimer(1.0, Timer_CheckPlayers, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || !IsClientInGame(client) || !IsFakeClient(client))
		return;
	
	// record spawn position
	GetClientAbsOrigin(client, spawnPos[client]);

	// reset tracking
	stuckTime[client] = 0;
	totalDist[client] = 0.0;

	if (GetConVarBool(g_CvarTrackingDebug))
		PrintToServer("[StuckBotKiller] %N is newly spawned, %.1f travelled (%.1f, %.1f)",
			client, totalDist[client], spawnPos[client][0], spawnPos[client][1]);
}

public Action Timer_CheckPlayers(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || !IsFakeClient(client)) {
			continue;
		}

		float pos[3];
		GetClientAbsOrigin(client, pos);

		float dist;
		dist = GetVectorDistance2D(pos, lastPos[client]);
		totalDist[client] += dist;
		if (GetConVarBool(g_CvarTrackingDebug))
			PrintToServer("[StuckBotKiller] %N moved %.1f, %.1f total travel (%.1f, %.1f)",
				client, dist, totalDist[client], pos[0], pos[1]);

		if (dist <= g_CvarDistThreshold.FloatValue) {
			if (!IsWeaponActive(client)) {
				stuckTime[client]++;
			}
		} else {
			stuckTime[client] = 0;
		}

		if (stuckTime[client] >= g_CvarMaxStuckTime.IntValue) {
			dist = GetVectorDistance2D(pos, spawnPos[client]);

			PrintToServer("[StuckBotKiller] %N has not moved in %d seconds (%.1f, %.1f)",
				client, stuckTime[client], pos[0], pos[1]);
			if (GetConVarBool(g_CvarTrackingDebug))
				PrintToServer("[StuckBotKiller] %N is %.1f from spawn, %.1f travelled (%.1f, %.1f)",
					client, dist, totalDist[client], spawnPos[client][0], spawnPos[client][1]);
			PrintToChatAll("[StuckBotKiller] %N is not moving and will be respawned.", client);
			KillClient(client); // work around because ForcePlayerSuicide() did not work
            	}

	        lastPos[client][0] = pos[0];
		lastPos[client][1] = pos[1];
		lastPos[client][2] = pos[2];
	}
	return Plugin_Continue;
}

float GetVectorDistance2D(const float vec1[3], const float vec2[3])
{
    float dx = vec1[0] - vec2[0];
    float dy = vec1[1] - vec2[1];
    return SquareRoot(dx*dx + dy*dy);
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
