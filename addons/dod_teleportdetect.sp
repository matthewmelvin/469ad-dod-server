#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION 	"1.0+logonly"

float lastpos[MAXPLAYERS+1][3];
bool allowedteleport[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[RCBOT2] teleportation detect",
	author = "requested by INsane",
	description = "detect teleportation bug for bots",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=350861"
};

public void OnPluginStart()
{
	CreateConVar("rcbot2_fix_version", PLUGIN_VERSION, "Version of the plugin", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("player_spawn", PlayerSpawnEvent);
}


public void OnGameFrame()
{
	for(int i = 1; i<=MaxClients; i++)
	{
		if(ValidPlayer(i, true) && IsFakeClient(i))
		{
			float vecBotPosition[3];
			GetClientAbsOrigin(i, vecBotPosition);
			
			//first teleport right after spawn is normal (allowed)
			if (!allowedteleport[i])
				allowedteleport[i] = true;
			else
			{
				//check if distance is too far ... assuming not allowed teleportation (change distance if needed)
				float distancemoved = GetVectorDistance(lastpos[i], vecBotPosition);
				if (distancemoved > 50)
				{
					PrintToServer("[TeleportDetect] %N from %d,%d,%d to %d,%d,%d (distance: %d)", i, RoundToNearest(lastpos[i][0]), RoundToNearest(lastpos[i][1]), RoundToNearest(lastpos[i][2]), RoundToNearest(vecBotPosition[0]), RoundToNearest(vecBotPosition[1]), RoundToNearest(vecBotPosition[2]), RoundToNearest(distancemoved));
				}
			}
			lastpos[i][0] = vecBotPosition[0];
			lastpos[i][1] = vecBotPosition[1];
			lastpos[i][2] = vecBotPosition[2];
		}
	}
}

public void PlayerSpawnEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	allowedteleport[iClient] = false;
}

stock bool:ValidPlayer(client,bool:check_alive=false,bool:alivecheckbyhealth=false) {
  if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
  {
    if(check_alive && !IsPlayerAlive(client))
    {
      return false;
    }
    if(alivecheckbyhealth&&GetClientHealth(client)<1) {
      return false;
    }
    return true;
  }
  return false;
}
