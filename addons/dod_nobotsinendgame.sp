// no_bots_in_endgame.sp
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
    name = "No Bots in Endgame",
    author = "Mloe",
    description = "Sets RCBot max_bots to 0 at end of DoD:S rounds.",
    version = "0.1",
    url = ""
};

public void OnPluginStart()
{
    HookEvent("dod_game_over", OnGameOver);
    PrintToServer("[NoBotsInEndgame] dod_game_over event hooked, plugin ready.");
}

public void OnGameOver(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[NoBotsInEndgame] dod_game_over event fired, disabling bots.");
    ServerCommand("rcbotd config max_bots 0");
}
