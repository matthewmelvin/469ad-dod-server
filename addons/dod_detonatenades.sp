/**
* DoD:S DetoNades by Root
*
* Description:
*   Detonates a grenade when it collides with a player.
*
* Version 1.1-modern
* Original: http://goo.gl/4nKhJ
*/

#include <sdkhooks>

// ====[ CONSTANTS ]==========================================================
#define PLUGIN_NAME    "DoD:S DetoNades"
#define PLUGIN_VERSION "1.1-modern"

enum GrenadeIndex
{
    GRENADE_FRAG_US,
    GRENADE_FRAG_GER,
    GRENADE_RIFLE_US,
    GRENADE_RIFLE_GER,
    GRENADE_COUNT
};

enum GrenadeType
{
    GRENADE_FRAG,
    GRENADE_RIFLE
};

ConVar g_NadesType[GrenadeType];

char g_LiveGrenades[GRENADE_COUNT][] = {
    "grenade_frag_us",
    "grenade_frag_ger",
    "grenade_riflegren_us",
    "grenade_riflegren_ger"
};

// ====[ PLUGIN INFO ]========================================================
public Plugin myinfo = {
    name        = PLUGIN_NAME,
    author      = "Root"
    description = "Detonates a grenade when it collides with a player",
    version     = PLUGIN_VERSION,
    url         = "http://dodsplugins.com/"
}

// ====[ INIT ]===============================================================
public void OnPluginStart()
{
    CreateConVar("dod_detonades_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

    g_NadesType[GRENADE_FRAG]  = CreateConVar("dod_detonade_frag_grenades",  "0", "Detonate frag grenade on player collision",  FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_NadesType[GRENADE_RIFLE] = CreateConVar("dod_detonade_rifle_grenades", "1", "Detonate rifle grenade on player collision", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}

// ====[ ENTITY HOOKS ]=======================================================
public void OnEntityCreated(int entity, const char[] classname)
{
    if ((StrEqual(classname, g_LiveGrenades[GRENADE_FRAG_US]) ||
         StrEqual(classname, g_LiveGrenades[GRENADE_FRAG_GER])) &&
        GetConVarBool(g_NadesType[GRENADE_FRAG]))
    {
        SetEntProp(entity, Prop_Send, "m_bIsLive", true, true);
    }

    if ((StrEqual(classname, g_LiveGrenades[GRENADE_RIFLE_US]) ||
         StrEqual(classname, g_LiveGrenades[GRENADE_RIFLE_GER])) &&
        GetConVarBool(g_NadesType[GRENADE_RIFLE]))
    {
        SetEntProp(entity, Prop_Send, "m_bIsLive", true, true);
    }
}

// ====[ CLIENT HOOKS ]=======================================================
public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttackPost, TraceAttackPost);
}

// ====[ GRENADE HIT HANDLER ]===============================================
public void TraceAttackPost(int victim, int attacker, int inflictor, float damage,
                            int damagetype, int ammotype, int hitbox, int hitgroup)
{
    if (1 <= victim <= MaxClients &&
        inflictor > MaxClients &&
        GetEntProp(inflictor, Prop_Send, "m_bIsLive", true))
    {
        SetEntProp(inflictor, Prop_Data, "m_takedamage", 2);
        SetEntProp(inflictor, Prop_Data, "m_iHealth", 1);
        SDKHooks_TakeDamage(inflictor, 0, 0, 1.0);
    }
}
