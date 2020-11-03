/*
 * Pings SM plugin.
 * 
 * Copyright (C) 2020 (Manuel|FrAgOrDiE)
 * https://github.com/manu-urba
 * 
 * This file is part of the Pings SourceMod plugin.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <cstrike>
#include <colorlib>

#define PREFIX_MAXLENGTH 128

public Plugin myinfo = 
{
	name = "Pings", 
	author = "FrAgOrDiE", 
	description = "Implements pings in Source Games", 
	version = "1.0", 
	url = "https://github.com/manu-urba"
};

int g_iBeamSprite;
int g_iHaloSprite;
int g_iSpam[MAXPLAYERS + 1];
int g_iOldButtons[MAXPLAYERS + 1];

ConVar cv_iRestrictedTeam;
ConVar cv_sMessagePrefix;

char g_sMessagePrefix[PREFIX_MAXLENGTH];

public void OnMapStart()
{
	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
	
	AddFileToDownloadsTable("sound/galaxy/ping.wav");
	PrecacheSound("galaxy/ping.wav");
	AddFileToDownloadsTable("sound/galaxy/ping2.wav");
	PrecacheSound("galaxy/ping2.wav");
}

public void OnPluginStart()
{
	LoadTranslations("Pings.phrases");
	
	strcopy(g_sMessagePrefix, sizeof(g_sMessagePrefix), "{darkblue}[{blue}Pings{darkblue}]{lightgreen} ");
	
	CreateTimer(5.0, Timer_CheckSpam, _, TIMER_REPEAT);
	
	AutoExecConfig_SetFile("Pings");
	cv_iRestrictedTeam = AutoExecConfig_CreateConVar("sm_pings_team", "0", "Which team is allowed to use pings? (0 = ALL, 1 = Terrorists (CSGO), 2 = Counter-Terrorists (CSGO))", FCVAR_NOTIFY, true, _, true, 2.0);
	cv_sMessagePrefix = AutoExecConfig_CreateConVar("sm_pings_prefix", "{darkblue}[{blue}Pings{darkblue}]{lightgreen} ", "Plugin prefix for messages");
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	HookConVarChange(cv_sMessagePrefix, CVC_Prefix);
}

public void CVC_Prefix(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_sMessagePrefix, sizeof(g_sMessagePrefix), newValue);
}

public Action Timer_CheckSpam(Handle timer)
{
	for (int i = 1; i <= MaxClients; ++i)
		g_iSpam[i] = 0;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	int iTeam = GetClientTeam(client);
	
	if (cv_iRestrictedTeam.IntValue == 1 && iTeam != CS_TEAM_T || cv_iRestrictedTeam.IntValue == 2 && iTeam != CS_TEAM_CT)
	{
		CPrintToChat(client, "%s%t", g_sMessagePrefix, "your team cant use pings");
		return Plugin_Continue;
	}
	
	bool pingVariant1 = buttons & IN_USE == IN_USE && g_iOldButtons[client] & IN_USE != IN_USE && buttons & IN_RELOAD;
	bool pingVariant2 = buttons & IN_USE == IN_USE && g_iOldButtons[client] & IN_USE != IN_USE && buttons & IN_ATTACK2;
	
	g_iOldButtons[client] = buttons;
	
	bool bIsPinging = pingVariant1 || pingVariant2;
	
	if (!bIsPinging)
		return Plugin_Continue;
		
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sMessagePrefix, "cant ping while dead");
		return Plugin_Continue;
	}
	
	if (g_iSpam[client] >= 2)
	{
		CPrintToChat(client, "%s%t", g_sMessagePrefix, "dont spam pings");
		return Plugin_Continue;
	}
	
	float fPos[3], buffer[6][3], fEyePos[3], fHitPos[3];
	
	GetClientEyePosition(client, fEyePos);
	
	TR_TraceRayFilter(fEyePos, angles, MASK_SOLID, RayType_Infinite, Trace_Filter, client);
	
	if (!TR_DidHit())
		return Plugin_Continue;
		
	TR_GetEndPosition(fHitPos);
	
	SubtractVectors(fHitPos, fEyePos, fPos);
	ScaleVector(fPos, 1 - 35.0 / GetVectorDistance(fEyePos, fHitPos));
	AddVectors(fEyePos, fPos, fPos);
	
	fPos[2] += 15;
	
	if (pingVariant1)
		EmitAmbientSound("galaxy/ping.wav", fPos, _, SNDLEVEL_RAIDSIREN);
	else if (pingVariant2)
		EmitAmbientSound("galaxy/ping2.wav", fPos, _, SNDLEVEL_RAIDSIREN);
	
	int iColor[4];
	
	Octahedron(fPos, buffer, 10.0);
	
	if (pingVariant1)
		iColor =  {0, 4, 117, 255};
	else if (pingVariant2)
		iColor =  {184, 0, 0, 255};
	
	SetupOctahedron(buffer, iColor);
	Octahedron(fPos, buffer, 15.0);
	
	if (pingVariant1)
		iColor =  {58, 150, 242, 255};
	else if (pingVariant2)
		iColor =  {242, 144, 63, 255};
	
	SetupOctahedron(buffer, iColor);
	Octahedron(fPos, buffer, 3.0);
	
	if (pingVariant1)
		iColor =  {255, 255, 255, 255};
	else if (pingVariant2)
		iColor =  {255, 255, 255, 255};
	
	SetupOctahedron(buffer, iColor, 0.2);
	
	if (pingVariant2)
	{
		float excl[2][3];
		excl[0][0] = buffer[0][0];
		excl[0][1] = buffer[0][1];
		excl[0][2] = buffer[0][2];
		excl[1][0] = buffer[0][0];
		excl[1][1] = buffer[0][1];
		excl[1][2] = buffer[0][2];
		excl[1][2] += 105;
		excl[0][2] += 65;
		iColor =  {255, 0, 0, 255};
		TE_SetupBRPAndSendToAll(excl[1], 16.0, 16.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[1], 12.0, 12.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[1], 8.0, 8.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[1], 4.0, 4.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		
		for (int i = 0; i < 16; i++)
		{
			excl[1][2] -= 2.5;
			TE_SetupBRPAndSendToAll(excl[1], 16.0, 4.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 9.0, 1.5, 1.5, iColor, 0, 0);
			TE_SetupBRPAndSendToAll(excl[1], 16.0, 16.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 0.2, 0.2, view_as<int>({255, 255, 255, 255}), 0, 0);
		}
		
		TE_SetupBRPAndSendToAll(excl[0], 16.0, 16.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[0], 12.0, 12.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[0], 8.0, 8.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
		TE_SetupBRPAndSendToAll(excl[0], 4.0, 4.1, g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, 2.0, 2.0, iColor, 0, 0);
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || i == client)
			continue;
		float fiPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", fiPos);
		fiPos[2] += 3;
		iColor =  {168, 37, 98, 255};
		TE_SetupBeamPoints(fiPos, fPos, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.8, 0.7, 0.7, 1, 0.0, iColor, 5);
		TE_SendToClient(i);
	}
	
	++g_iSpam[client];
	
	return Plugin_Continue;
}

void SetupOctahedron(float buffer[6][3], int color[4], float width = 0.5)
{
	TE_SetupBPAndSendToAll(buffer[0], buffer[1], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[0], buffer[2], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[0], buffer[3], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[0], buffer[4], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[1], buffer[2], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[1], buffer[4], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[4], buffer[3], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[2], buffer[3], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[5], buffer[1], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[5], buffer[2], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[5], buffer[3], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
	TE_SetupBPAndSendToAll(buffer[5], buffer[4], g_iBeamSprite, g_iHaloSprite, 0, 10, 10.0, width, width, 1, 0.0, color, 5);
}

void TE_SetupBPAndSendToAll(const float start[3], const float end[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed)
{
	TE_SetupBeamPoints(start, end, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
}

void TE_SetupBRPAndSendToAll(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
{
	TE_SetupBeamRingPoint(center, Start_Radius, End_Radius, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, Color, Speed, Flags);
	TE_SendToAll();
}

stock void Octahedron(float center[3], float buffer[6][3], float ampitude)
{
	buffer[0][0] = center[0];
	buffer[0][1] = center[1];
	buffer[0][2] = center[2] + ampitude;
	buffer[1][0] = center[0] - ampitude / 2;
	buffer[1][1] = center[1] + ampitude / 2;
	buffer[1][2] = center[2];
	buffer[2][0] = center[0] - ampitude / 2;
	buffer[2][1] = center[1] - ampitude / 2;
	buffer[2][2] = center[2];
	buffer[3][0] = center[0] + ampitude / 2;
	buffer[3][1] = center[1] - ampitude / 2;
	buffer[3][2] = center[2];
	buffer[4][0] = center[0] + ampitude / 2;
	buffer[4][1] = center[1] + ampitude / 2;
	buffer[4][2] = center[2];
	buffer[5][0] = center[0];
	buffer[5][1] = center[1];
	buffer[5][2] = center[2] - ampitude;
}

public void OnClientDisconnect(int client)
{
	g_iOldButtons[client] = 0;
}

bool Trace_Filter(int entity, int contentsMask, any data)
{
	return entity != data;
} 