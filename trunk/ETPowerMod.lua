




--et.trap_SendServerCommand( -1,"cpm \"\"\n")		
--tonumber(et.trap_Cvar_Get("cvar"))
ETPowerModVersion = "0.5"
ETPowerMute = {}
ETSTFU = {}
ETCantVote = {}
ETPowerUserL0 = {}
ETPowerUserL1 = {}
ETPowerUserL2 = {}
ETPowerUserL3 = {}
ETPowerUserL4 = {}
ETRules = ""
ETAbuserMonitor = {}
ETSpecLock = {}
ETLockTeams = false
ETRWins = 0
ETBWins = 0
ETMaps = 0
ETWinStreak = {["R"]=0,["B"]=0}
ETPrevGameState=-1
ETCurrGameState=-1
ETPlayerAlarm = {}
ETPlayerFire={}
ETTeamsLock = -1
ETAutoBalanceTime = 0
ETProtectedNames = {}
ETClanTagProtection = {}
ETIACNextLinePID = -1
ETIACINFO = {}

et.GS_INITIALIZE = -1
et.GS_PLAYING=0
et.GS_WARMUP_COUNTDOWN=1
et.GS_WARMUP=2
et.GS_INTERMISSION=3
et.GS_WAITING_FOR_PLAYERS=4
et.GS_RESET=5
et.MAX_CLIENTS = 	64
et.CS_MODELS =      64
et.MAX_MODELS = 	256
et.CS_SOUNDS =      (et.CS_MODELS + et.MAX_MODELS         )	--320
et.MAX_SOUNDS = 	256
et.CS_SHADERS =     (et.CS_SOUNDS + et.MAX_SOUNDS         )	--576
et.MAX_CS_SHADERS = 32
et.CS_SHADERSTATE = (et.CS_SHADERS + et.MAX_CS_SHADERS    )	--608
et.CS_SKINS =      	(et.CS_SHADERSTATE +   1              )	--609
et.MAX_CS_SKINS = 	64
et.CS_CHARACTERS =  (et.CS_SKINS + et.MAX_CS_SKINS        )	--673
et.MAX_CHARACTERS = 16
et.CS_PLAYERS =     (et.CS_CHARACTERS + et.MAX_CHARACTERS )	--689

function et_AdminSay(PlayerID, msg)
	local AdminCount=0
	local i = 0
	while(i<tonumber(et.trap_Cvar_Get("sv_maxclients"))) do
		if(PowerUserLevel(i)~=nil and i~=PlayerID) then
			NumPrivateMessage(i,PlayerID,msg,false)
			AdminCount=AdminCount+1
		end
		i=i+1
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"" .. et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ) .. "^7: ^1(Private to " .. AdminCount .. " Admins)^7" .. msg .. "\"\n")
	return 1
end

function et_AutoSAL( PlayerID )
	local CurrentLevel =0
	if(et.gentity_get(PlayerID,"sess.semiadmin")~=0) then
		CurrentLevel = et.gentity_get(PlayerID,"sess.semiadmin")
	end
	if et.trap_Cvar_Get("b_semiadminlevels") == "0" or et.trap_Cvar_Get("b_semiadminlevels")=="" then
		et.trap_Cvar_Set("p_puSALevel","0")
	end
	local ForcedLevel = tonumber(et.trap_Cvar_Get("p_puSALevel"))
	if ForcedLevel==nil then
		et.trap_Cvar_Set("p_puSALevel","0")
	else
		if CurrentLevel == 0 then
			et.gentity_set(PlayerID,"sess.semiadmin",ForcedLevel)
		end
	end
end

function et_ClientBegin( clientNum )
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( et.trap_GetUserinfo( clientNum ), "name" ) )
	local i =  tonumber(et.trap_Cvar_Get("ps_AlarmTime"))
	if(i~=nil) then
		SetAlarm(PlayerID, tonumber(et.trap_Cvar_Set("ps_AlarmTime")))
	end
	ModInfo(clientNum)
	CheckNameProtection(clientNum)
	LoadMutes()
	LoadCantVotes()
	if(LoadClanProtection()==1) then
		CheckClanProtection(clientNum)
	end
	if (checkMute(clientNum)) then
		et.trap_SendConsoleCommand(et.EXEC_APPEND, "mute " .. "\"" .. PlayerName .. "\"" .. "\n" )
	end
	if PowerUserLevel( clientNum )~=nil then
		et_AutoSAL(clientNum)		
	end
	if checkAutoAnnounce(clientNum) then
		AnnounceMe(clientNum)
	end
end

function et_ClientCommand( clientNum, command )
	arg0 = string.lower(et.trap_Argv(0))
	--CheckAlarm(et.trap_Milliseconds())
	if arg0 == "say" then
		return et_ClientSay( clientNum, et.SAY_ALL, et.ConcatArgs(1))
	elseif arg0 == "say_team" then
		return et_ClientSay( clientNum, et.SAY_TEAM, et.ConcatArgs(1))
	elseif arg0 == "say_buddy" then
		return et_ClientSay( clientNum, et.SAY_BUDDY, et.ConcatArgs(1))
	elseif arg0 == "say_teamnl" then
		return et_ClientSay( clientNum, et.SAY_TEAMNL, et.ConcatArgs(1))
	elseif arg0 == "say_admin" then
		return et_AdminSay(clientNum, et.ConcatArgs(1))
	elseif (arg0 == "callvote") then
		if checkVote(clientNum) then
			et.trap_SendServerCommand( clientNum,"cpm \"You are unable to vote.\"\n")
			return 1
		end
	elseif (arg0 == "team") then
		if(checkSpecLock(clientNum) or (tonumber(et.trap_Cvar_Get("ps_lockteams"))~=-1)) then
			et.trap_SendServerCommand( clientNum,"cpm \"You are unable switch teams.\"\n")
			BalanceCheck()
			return 1
		end
	elseif (arg0 == "m") then
		if(et.trap_Argc()>2) then
		if(isPlayer(et.trap_Argv(1))) then
			NumPrivateMessage(tonumber(et.trap_Argv(1)),clientNum,et.ConcatArgs(2),true)
			return 1
		end
		end
	else
		return PowerUserEmulation(clientNum)
	end
	return 0
end 

function et_ClientDisconnect( PlayerID )
	BalanceCheck()
	et.trap_Cvar_Set("ps_AlarmTime" .. PlayerID,"")
	ETIACINFO[PlayerID]=nil
end

function et_ClientSay(clientNum,mode,text)
	local command1=""
	local commands = 0
	local first = ""
	local second = ""
	local third = ""
	local returnVal = 0
	s,e,first,second,third = string.find(text,"%s*([^%s+]+)%s+(%p*%w*)%s+(.*)")
	if(mode==et.SAY_ALL) then
		command1="say"
	elseif (mode==et.SAY_TEAM or mode==et.SAY_TEAMNL) then
		command1="say_team"
	else
		command1="say_buddy"
	end
	if(third~=nil) then
		commands=4
	else
		s,e,first,second = string.find(text,"%s*([^%s+]+)%s+(.+)%s*")
			third=""
			if(second~=nil) then
				commands = 3
			else
				second=""
				first = et.ConcatArgs(1)
				commands = 2
			end
	end
	if PowerUserLevel(clientNum)~=nil then
		return PowerUserCommand(clientNum,command1, first, second, third, commands) 
	end
	return ClientUserCommand(clientNum, command1, first, second, third, commands)	
end

function et_ClientUserinfoChanged( clientNum )
	if(LoadClanProtection()==1) then
		CheckClanProtection(clientNum)
	end
	CheckNameProtection(clientNum)
end

function et_ConsoleCommand()
	if string.lower(et.trap_Argv(0)) == "load" then
		LoadPowerUsers()
		return 1
	elseif ( string.lower(et.trap_Argv(0)) == "setpu" and et.trap_Argc() >= 3 ) then
		if(tonumber(et.trap_Argv(1))==nil or tonumber(et.trap_Argv(2))==nil) then
			et.G_Print("you didn't format it correctly")
			return 1
		end
		PID = tonumber(et.trap_Argv(1))
		level = tonumber(et.trap_Argv(2))
		CreatePowerUser(PID, level)
		return 1
	elseif ( string.lower(et.trap_Argv(0)) == "listpu" ) then
		PowerUserList()
		return 1
	elseif ( string.lower(et.trap_Argv(0)) == "removepuguid" and et.trap_Argc() >= 2 ) then
		if ( tonumber(et.trap_Argv(1)) ~= nil ) then
			RemoveGUIDPowerUser(tonumber(et.trap_Argv(1)))
		end
		return 1
	elseif ( string.lower(et.trap_Argv(0)) == "removepuip" and et.trap_Argc() >= 2 ) then
		if ( tonumber(et.trap_Argv(1)) ~= nil ) then
			RemoveIPPowerUser(tonumber(et.trap_Argv(1)))
		end
		return 1
	elseif (string.lower(et.trap_Argv(0)) == "setpuguid" and et.trap_Argc() >=3 ) then
		if(tonumber(et.trap_Argv(1))==nil) then
			et.G_Print("you didn't format it correctly")
			return 1
		end
		level=tonumber(1)
		GUID=et.trap_Argv(2)
		if(et.trap_Argc() > 3) then
			Name = et.ConcatArgs(3)
		else
			Name = "Name Not Given"
		end
		AddPUGUID(GUID,Name,level)
	elseif (string.lower(et.trap_Argv(0)) == "setpuip" and et.trap_Argc() >=3 ) then
		if(tonumber(et.trap_Argv(1))==nil) then
			et.G_Print("you didn't format it correctly")
			return 1
		end
		level=tonumber(1)
		IP=et.trap_Argv(2)
		if(et.trap_Argc() > 3) then
			Name = et.ConcatArgs(3)
		else
			Name = "Name Not Given"
		end
		AddPUIP(IP,Name,level)
	elseif (string.lower(et.trap_Argv(0)) == "playsound" and et.trap_Argc() >=3 ) then
		PlaySound( et.trap_Argv(1) , et.trap_Argv(2))
		return 1
	elseif (string.lower(et.trap_Argv(0)) == "playsound_env" and et.trap_Argc() >=3 ) then
		PlaySoundGlobal(et.trap_Argv(2))
		return 1
	elseif (string.lower(et.trap_Argv(0)) == "playsound_env" and et.trap_Argc() ==2 ) then
		PlaySoundGlobal(et.trap_Argv(1))
		return 1
	elseif (string.lower(et.trap_Argv(0)) == "sayas" and et.trap_Argc() >=3) then
		SayAs(et.trap_Argv(1), et.ConcatArgs(2))
		return 1
	elseif (string.lower(et.trap_Argv(0)) == "ircas" and et.trap_Argc() >=3) then
		IRCAs(et.trap_Argv(1), et.ConcatArgs(2))
		return 1
	else
		return PowerUserEmulation(-1)
	end
	return 0
end

function et_InitGame( levelTime, randomSeed, restart )
	local currentver = et.trap_Cvar_Get("mod_version")
	et.G_Print( "Gotenks ETPowerMod, PowerMod version " .. ETPowerModVersion .. "\n" )
	et.RegisterModname( "Gotenks_PowerMod-" .. ETPowerModVersion .. " " .. et.FindSelf() )
	et.trap_SendConsoleCommand(et.EXEC_APPEND, "forcecvar mod_version \"" .. currentver .. " - ETPowerMod\"" .. "\n" )
	et.G_Print("Loading Power User Prifiles\n")
	LoadPowerUsers()
	et.G_Print("----------------------------------------------------\n")
	et.G_Print("Loading Protected Names\n")
	LoadNameProtection()
	et.G_Print("----------------------------------------------------\n")
	loadRules()
	ETPowerUserL0[-1]=true
	if(tonumber(et.trap_Cvar_Get("p_unlocktime"))==nil) then
		et.trap_Cvar_Set("p_unlocktime",0)
	end
	if(tonumber(et.trap_Cvar_Get("ps_lockteams"))==nil or tonumber(et.trap_Cvar_Get("ps_lockteams"))<et.trap_Milliseconds()) then
		et.trap_Cvar_Set("ps_lockteams",-1)
	end
end

function et_Print( text )
	local t = ParseString(text)
	if(t[1] == "Vote" and t[2]== "Passed:") then
		if(t[3]==("Shuffle")) then
			ResetStreaks()
			ShuffleLock()
		end
	end	
	if(string.lower(t[1])=="etpro" and string.lower(t[2])=="iac:") then
		ReadIAC(text)
	end
	if(t[1]=="etpro:" and t[2]=="cannot" ) then
		et.trap_SendServerCommand( -1,"cpm \"lua Error = " .. text .. "\"\n")
	end
end

function et_RunFrame( levelTime )
	local tempNo = tonumber(et.trap_Cvar_Get("ps_lockteams"))
	FixWinStreak()
	CheckAlarm(et.trap_Milliseconds())
	if(tempNo<et.trap_Milliseconds()) then
		et.trap_Cvar_Set("ps_lockteams",-1)
	end
	if(ETAutoBalanceTime<=et.trap_Milliseconds() and et.trap_Milliseconds()~=0) then
		FixBalance()
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function AddBadUser(PlayerID, Reason)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	local name = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ))
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		ETAbuserMonitor[ip]={[1]=name, [2]=guid, [3]=ip, [4]=Reason}
		ETAbuserMonitor[guid]={[1]=name, [2]=guid, [3]=ip, [4]=Reason}
		return 1
	end
	return 0
end

function AddCantVoteGUID(GUID)
	s,e,GUID = string.find(GUID,"(%x+)")
	GUID = string.upper(GUID)
	local CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerNoVotesGUIDs"))
	local i = 1
	while(i<=table.getn(CantVotes)) do
		if(GUID==CantVotes[i]) then
			return 0
		end
		i=i+1
	end
	CantVotes[i]=GUID
	et.trap_Cvar_Set("ps_PowerNoVotesGUIDs",table.concat(CantVotes," "))
	ETCantVote[GUID] = true
	return 1
end 

function AddCantVoteIP(IP)
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	local CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerNoVotesIPs"))
	local i = 1
	while(i<=table.getn(CantVotes)) do
		if(IP==CantVotes[i]) then
			return 0
		end
		i=i+1
	end
	CantVotes[i]=IP
	et.trap_Cvar_Set("ps_PowerNoVotesIPs",table.concat(CantVotes," "))
	ETCantVote[IP] = true
	return 1
end

function AddMuteGUID(GUID)
	s,e,GUID = string.find(GUID,"(%x+)")
	GUID = string.upper(GUID)
	local Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteGUIDs"))
	local i = 1
	while(i<=table.getn(Mutes)) do
		if(GUID==Mutes[i]) then
			return 0
		end
		i=i+1
	end
	Mutes[i]=GUID
	et.trap_Cvar_Set("ps_PowerMuteGUIDs",table.concat(Mutes," "))
	ETPowerMute[GUID] = true
	return 1
end 

function AddMuteIP(IP)
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	local Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteIP"))
	local i = 1
	while(i<=table.getn(Mutes)) do
		if(IP==Mutes[i]) then
			return 0
		end
		i=i+1
	end
	Mutes[i]=IP
	et.trap_Cvar_Set("ps_PowerMuteIP",table.concat(Mutes," "))
	ETPowerMute[IP] = true
	return 1
end

function AddPowerUserGUID(GUID)
	s,e,GUID,level = string.find(GUID,"(%x+)@(%d)")
	level=tonumber(level)
	if level == 0 then
		ETPowerUserL0[GUID] = true
	elseif level == 1 then
		ETPowerUserL1[GUID] = true
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
	elseif level == 2 then
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
	elseif level == 3 then
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
	elseif level == 4 then
		ETPowerUserL4[GUID] = true
	end
end 

function AddPowerUserIP(IP)
	s,e,IP,level = string.find(IP,"(%d+%.%d+%.%d+%.%d+)@(%d)")
	level=tonumber(level)
	if level == 0 then
		ETPowerUserL0[IP] = true
	elseif level == 1 then
		ETPowerUserL1[IP] = true
		ETPowerUserL2[IP] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
	elseif level == 2 then
		ETPowerUserL2[IP] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
	elseif level == 3 then
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
	elseif level == 4 then
		ETPowerUserL4[IP] = true
	end
end

function AddPUGUID(GUID, Name, level)
	local fdguid,len = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_APPEND )
	if level == 0 then
		ETPowerUserL0[GUID] = true
		GUID = GUID .. "@0 - " .. Name .. "\n"
	elseif level == 1 then
		ETPowerUserL1[GUID] = true
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
		GUID = GUID .. "@1 - " .. Name .. "\n"
	elseif level == 2 then
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
		GUID = GUID .. "@2 - " .. Name .. "\n"
	elseif level == 3 then
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[GUID] = true
		GUID = GUID .. "@3 - " .. Name .. "\n"
	elseif level == 4 then
		ETPowerUserL4[GUID] = true
		GUID = GUID .. "@4 - " .. Name .. "\n"
	else 
		et.G_Print("ERROR: Invalid level!")
		return 0
	end
	et.trap_FS_Write( GUID, string.len(GUID) ,fdguid )
	et.G_Print( "PowerUser GUID: " .. GUID .. " - " .. Name .. " Added. \n" )
	et.trap_FS_FCloseFile( fdguid ) 
	return 1
end

function AddPUIP(IP,Name,level)
	local fdip,len = et.trap_FS_FOpenFile( "PowerUserIPs.dat", et.FS_APPEND )
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	if(IP==nil) then
		et.G_Print("invalid ip format")
		return 0
	end
	if level == 0 then
		ETPowerUserL0[IP] = true
		IP = IP .. "@0 - " .. Name .. "\n"
	elseif level == 1 then
		ETPowerUserL1[IP] = true
		ETPowerUserL2[IP] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
		IP = IP .. "@1 - " .. Name .. "\n"
	elseif level == 2 then
		ETPowerUserL2[IP] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
		IP = IP .. "@2 - " .. Name .. "\n"
	elseif level == 3 then
		ETPowerUserL3[IP] = true
		ETPowerUserL4[IP] = true
		IP = IP .. "@3 - " .. Name .. "\n"
	elseif level == 4 then
		ETPowerUserL4[IP] = true
		IP = IP .. "@4 - " .. Name .. "\n"
	else 
		et.G_Print("ERROR: Invalid level!")
		return 0
	end
	et.trap_FS_Write( IP, string.len(IP) ,fdip )
	et.G_Print( "PowerUser IP: " .. IP .. " - " .. Name ..  "  Added. \n" )
	et.trap_FS_FCloseFile( fdip ) 
	return 1
end

function Announce(Pos,Announcement)
	if(Pos==1) then
		et.trap_SendServerCommand( -1,"cp \"^1ANNOUNCEMENT: ^7" .. Announcement .. " \"\n")		
	elseif(Pos==2) then
		et.trap_SendServerCommand( -1,"cpm \"^1ANNOUNCEMENT: ^7" .. Announcement .. " \"\n")	
	elseif(Pos==3) then
		et.trap_SendServerCommand( -1,"sc \"^1ANNOUNCEMENT: ^7" .. Announcement .. " \"\n")		
	end
end

function AnnounceMe(PlayerID)
	if(PlayerID~=-1) then
		MyString = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ) .. " ^7has logged in as admin"
	else
		MyString = "The Admin is watching the console."
	end
	Announce(2,MyString)
end

function BalanceCheck()
	local Red =0
	local Blue=0
	local i = 0
	while(i<tonumber(et.trap_Cvar_Get("sv_maxclients"))) do
		if(isPlayer(i)) then
			if(et.gentity_get(i,"sess.sessionTeam")==1) then
				Red =Red +1
			elseif(et.gentity_get(i,"sess.sessionTeam")==2) then
				Blue=Blue+1
			end
		end
		i=i+1
	end
	if(math.abs(Red-Blue)>=2 and et.trap_Cvar_Get("g_balancedteams")=="1") then
		local TimeFix = 30
		if(tonumber(et.trap_Cvar_Get("p_BalanceTime"))~=nil) then
			TimeFix=tonumber(et.trap_Cvar_Get("p_BalanceTime"))
		else
			et.trap_Cvar_Set("p_BalanceTime",30)
		end
		if(TimeFix>0) then
			if(Red>Blue) then
				et.trap_SendServerCommand( -1,"cp \"Allies are short " .. Red-Blue .. " players, please balance teams." .. "\"\n")
			elseif (Red<Blue) then
				et.trap_SendServerCommand( -1,"cp \"Axis is short " .. Blue-Red .. " players, please balance teams." .. "\"\n")
			end
		end
		ETAutoBalanceTime =et.trap_Milliseconds()+TimeFix*1000
	end
end

function CancelVote()
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "cancelvote\n" )
end

function cantVote(PlayerID)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local ip = et.Info_ValueForKey( userinfo, "ip" )
	local guid = et.Info_ValueForKey( userinfo, "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		if(AddCantVoteIP(ip)+AddCantVoteGUID(guid)~=0) then
			et.trap_SendServerCommand( PlayerID,"cpm \"You cannot vote now.\"\n")
			return 1
		end
	end
	return 0
end

function canVote(PlayerID) 
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		if(RemoveCantVoteGUID(guid)+RemoveCantVoteIP(ip)~=0) then
			et.trap_SendServerCommand( PlayerID,"cpm \"You can now vote.\"\n")
			return 1
		end
	end
	return 0
end

function CheckAlarm(Time)
	local i = 0
	while ( i < tonumber(et.trap_Cvar_Get("sv_maxclients"))) do
		if(ETPlayerAlarm[i]~=nil) then
			if(ETPlayerAlarm[i][1]<=Time) then
				et.trap_SendServerCommand( i,"cp \"Your Requested Alarm.\"\n")
				et.G_Print("This is the Alarm: ".. Time .."\n")
				ETPlayerAlarm[i]=nil
			end
		end
		i=i+1
	end
end

function checkAutoAnnounce(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		if (PowerUserLevel(PlayerID) == 4 or PowerUserLevel(PlayerID) == 3 or PowerUserLevel(PlayerID) == 2) then
			return true
		else
			return false
		end
	end
	return false
end

function CheckClanProtection(PlayerID)
	local name=et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" )
	local password = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "clanpwd" )
	if(ETClanTagProtection[2]==0 and string.find(name,ETClanTagProtection[1])==0) then
		if(password~=tempPas) then
			local n = math.random(1000,9999)
			RenameUser(PlayerID,"ETPlayer" .. n)
		end
	elseif(ETClanTagProtection[2]==1 and string.find(name,ETClanTagProtection[1])==string.len(name)-string.len(ETClanTagProtection[1])) then
		if(password~=tempPas) then
			local n = math.random(1000,9999)
			RenameUser(PlayerID,"ETPlayer" .. n)
		end
	end
end

function checkMute(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETPowerMute[ip] ~= nil or ETPowerMute[guid] ~= nil
	end
	return false
end

function CheckNameProtection(PlayerID)
	local name=et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" )
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid =  string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	local password = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "nickpwd" )
	local ProtectedName = ETProtectedNames[et.Q_CleanStr(name)]
	local handler = tonumber(et.trap_Cvar_Get("p_NameProtectAction"))
	s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	if(ProtectedName==nil) then
		return
	end
	if( ProtectedName[1]=="1" and ProtectedName[2]==name ) then
		if ( ProtectedName[3]==ip  or ProtectedName[4]==guid  or ProtectedName[5]==password ) then
			ProtectedName[3]=ip  
			ProtectedName[4]=guid  
			ProtectedName[5]=password
			return
		end
	elseif( ProtectedName[1]=="2" and et.Q_CleanStr(ProtectedName[2])==et.Q_CleanStr(name) ) then
		if ( ProtectedName[3]==ip  or ProtectedName[4]==guid  or ProtectedName[5]==password ) then
			ProtectedName[3]=ip  
			ProtectedName[4]=guid  
			ProtectedName[5]=password
			return
		end
	end
	if(handler==nil) then
		handler=0
		et.trap_Cvar_Set("p_NameProtectAction","0")
	end
	--0=rename, 1=kick (no time), 2=rename then kick(notime), 3=2min kick
	if(handler==0 or handler==2) then
		local n = math.random(1000,9999)
		RenameUser(PlayerID,"ETPlayer" .. n)
	end
	if(handler==1 or handler==2) then
		KickUser(PlayerID,0)
	end
	if(handler==3) then
		KickUser(PlayerID,120)
	end
end

function checkSpecLock(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETSpecLock[ip] or ETSpecLock[guid] 
	end
end

function checkVote(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETCantVote[ip] ~= nil or ETCantVote[guid] ~= nil
	end
	return false
end

function ClientUserCommand(PlayerID, Command, BangCommand, Cvar1, Cvar2, Cvarct)
	if(string.lower(BangCommand)=="!rules") then
		ShowServerRules(PlayerID)
		return 0
	--elseif (string.lower(BangCommand)=="!loc")
	--	et.trap_SendServerCommand( PlayerID,"cpm \"" .. PlayerID .. "\n\"" )
	--	et.trap_SendServerCommand( PlayerID,"cpm \"" .. et.gentity_get(PlayerID, "r.currentOrigin") .. "\n\"" )
	--	return 1
	elseif(string.lower(BangCommand) == "!admintest") then
		MyStatus(PlayerID)
		return 0
	elseif(string.lower(BangCommand) == "!help" || string.lower(BangCommand) == "!showcommands") then
		ListCommands(PlayerID)
		return 0
	elseif (string.lower(BangCommand) == "!find" and Cvarct>=3) then
		PlayerSlot( Cvar1, PlayerID )
		return 0
	elseif (string.lower(BangCommand) == "!time") then
		local iTime = os.date("%I:%M:%S%p")
		et.trap_SendServerCommand( PlayerID,"cpm \"Server time is: " .. iTime .. "\n\"")
		return 0
	elseif (string.lower(BangCommand) == "!date") then
		local iTime = os.date("%x %I:%M:%S%p")
		et.trap_SendServerCommand( PlayerID,"cpm \"Server date and time is: " .. iTime .. "\n\"")
		return 0
	elseif (string.lower(BangCommand) == "!modinfo") then
		ModInfo(PlayerID)
		return 0
	elseif (string.lower(BangCommand) == "!adminlist") then
		ListOnlinePowerUsers(PlayerID)
		return 0
	elseif (( string.lower(BangCommand) == "!pass" or string.lower(BangCommand) == "!login" or string.lower(BangCommand) == "!password" )) then
		LoginPU(PlayerID,Cvar1)
		return 1
	--elseif (( string.lower(BangCommand)) == "!check") then
	--	et.trap_SendServerCommand( PlayerID,"cpm \"This is CPM\n\"")
	--	et.trap_SendServerCommand( PlayerID,"sc \"This is SC\n\"")
	--	et.trap_SendServerCommand( PlayerID,"cp \"This is CP\n\"")
	--	et.trap_SendServerCommand( PlayerID,"print \"This is PRINT\n\"")
	--	return 1
	elseif ( string.lower(BangCommand) == "!alarm" and Cvarct>=3) then
		if(tonumber(Cvar1)~=nil) then
			et.trap_Cvar_Set("ps_AlarmTime" .. PlayerID,et.trap_Milliseconds()+tonumber(Cvar1)*60000)
			SetAlarm(PlayerID, tonumber(et.trap_Cvar_Set("ps_AlarmTime")))
		else
			et.trap_SendServerCommand( PlayerID,"cpm \"Invalid time length!\"\n")
		end
	elseif ( string.lower(BangCommand) == "!cvar" and Cvarct>=3) then
	local s,e,temp=string.find(string.lower(Cvar1),"(pass)")
	if(et.trap_Cvar_Get(Cvar1)~="" and temp==nil) then
			et.trap_SendServerCommand( PlayerID,"cpm \"" .. Cvar1 .. " is: " .. et.trap_Cvar_Get(Cvar1))
		else
			et.trap_SendServerCommand( PlayerID,"cpm \"unknown cmd in line: " .. Cvar1 .. "\n\"")
		end
	end
	return 0
end

function CreatePowerUser(PlayerID, level)
	local fdip,len = et.trap_FS_FOpenFile( "PowerUserIPs.dat", et.FS_APPEND )
	local fdguid,len = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_APPEND )
	local IP   = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local Name = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ))
	local GUID = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	if level == 0 then
		ETPowerUserL0[IP] = true
		ETPowerUserL0[GUID] = true
		IP = IP .. "@0 - " .. Name .. "\n"
		GUID = GUID .. "@0 - " .. Name .. "\n"
	elseif level == 1 then
		ETPowerUserL1[IP] = true
		ETPowerUserL1[GUID] = true
		ETPowerUserL2[IP] = true
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[IP] = true
		ETPowerUserL4[GUID] = true
		IP = IP .. "@1 - " .. Name .. "\n"
		GUID = GUID .. "@1 - " .. Name .. "\n"
	elseif level == 2 then
		ETPowerUserL2[IP] = true
		ETPowerUserL2[GUID] = true
		ETPowerUserL3[IP] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[IP] = true
		ETPowerUserL4[GUID] = true
		IP = IP .. "@2 - " .. Name .. "\n"
		GUID = GUID .. "@2 - " .. Name .. "\n"
	elseif level == 3 then
		ETPowerUserL3[IP] = true
		ETPowerUserL3[GUID] = true
		ETPowerUserL4[IP] = true
		ETPowerUserL4[GUID] = true
		IP = IP .. "@3 - " .. Name .. "\n"
		GUID = GUID .. "@3 - " .. Name .. "\n"
	elseif level == 4 then
		ETPowerUserL4[IP] = true
		ETPowerUserL4[GUID] = true
		IP = IP .. "@4 - " .. Name .. "\n"
		GUID = GUID .. "@4 - " .. Name .. "\n"
	else 
		et.G_Print("ERROR: Invalid level!")
		return 0
	end
	et.trap_FS_Write( IP, string.len(IP) ,fdip )
	et.trap_FS_Write( GUID, string.len(GUID) ,fdguid )
	et.G_Print( "PowerUser IP: " .. IP .. " - " .. Name ..  "  Added. \n" )
	et.G_Print( "PowerUser GUID: " .. GUID .. " - " .. Name .. " Added. \n" )
	et.trap_FS_FCloseFile( fdip ) 
	et.trap_FS_FCloseFile( fdguid ) 
	return 1
end

function DemutePlayer(PlayerID)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local userconfig = et.trap_GetConfigstring(et.CS_PLAYERS+PlayerID)
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( userinfo, "name" ) )
	local ip = et.Info_ValueForKey( userinfo, "ip" )
	s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	local guid = string.upper(et.Info_ValueForKey( userinfo, "cl_guid" ))
	RemoveMuteGUID(guid)
	RemoveMuteIP(ip)
	return 1
end

function DisplayBadUser(PlayerID)
	local i = 0
	local size=tonumber(et.trap_Cvar_Get("sv_maxclients"))
	while (i<size) do
		local report = getBadUser(i)
		if (report~=nil) then
			if(PlayerID~=-1) then
				et.trap_SendServerCommand(PlayerID, "cpm \"Bad User: PID = " .. i .. " Name = " .. report[1] .. " Reason =" .. report[4] .. "\"\n")
			else
				et.G_Print("Bad User: PID = " .. i .. " Name = " .. report[1] .. " Reason =" .. report[4] .. "\n")

			end
		end
		i=i+1
	end
end

function FakeRCONPowerUser(Command) 
	et.trap_SendConsoleCommand( et.EXEC_APPEND, Command .. "\n" )
end

function FixBalance()
	local Red ={}
	local Blue={}
	local i = 0
	local r=1
	local b=1
	while(i<tonumber(et.trap_Cvar_Get("sv_maxclients"))) do
		if(isPlayer(i)) then
			if(et.gentity_get(i,"sess.sessionTeam")==1) then
				Red[r]=i
				r=r+1
			elseif(et.gentity_get(i,"sess.sessionTeam")==2) then
				Blue[b]=i
				b=b+1
			end
		end
		i=i+1
	end
	if(math.abs(table.getn(Red)-table.getn(Blue))<2 or et.trap_Cvar_Get("g_balancedteams")~="1") then
		ETAutoBalanceTime=0
		return
	end
	if et.trap_Cvar_Get("p_BalanceAction")=="1" then
		ETAutoBalanceTime=0
		ResetStreaks()
		ShuffleTeamsXP()
	elseif et.trap_Cvar_Get("p_BalanceAction")=="2" then
		if(table.getn(Red)>table.getn(Blue)) then
			PutTeam(Red[math.random(1,table.getn(Red))],"blue")
		else
			PutTeam(Blue[math.random(1,table.getn(Blue))],"red")
		end
	else
		Announce(2,"Teams are uneven, please balance them.")
		ETAutoBalanceTime=et.trap_Milliseconds()+10*1000
	end
end

function FixWinStreak()
	local MaxStreak = tonumber(et.trap_Cvar_Get("p_MaxStreak"))
	local MapCountAction = tonumber(et.trap_Cvar_Get("p_MapCountAction"))
	local MapCount = tonumber(et.trap_Cvar_Get("p_MapCount"))
	local temp=tonumber(et.trap_Cvar_Get("ps_ETWinStreakR"))
	if(temp==nil) then
		et.trap_Cvar_Set("ps_ETWinStreakR", 0)
	end
	temp=tonumber(et.trap_Cvar_Get("ps_ETWinStreakB"))
	if(temp==nil) then
		et.trap_Cvar_Set("ps_ETWinStreakB", 0)
	end
	ETWinStreak["B"] = tonumber(et.trap_Cvar_Get("ps_ETWinStreakB"))
	ETWinStreak["R"] = tonumber(et.trap_Cvar_Get("ps_ETWinStreakR"))
	if(MaxStreak == nil) then
		MaxStreak=0
	end
	if(MapCount==nil) then
		MapCount=0
	end
	if(MapCountAction==nil) then
		MapCountAction=0
	end
	ETCurrGameState=tonumber(et.trap_Cvar_Get("gamestate"))
	if(ETCurrGameState~=ETPrevGameState) then
		ETPrevGameState=ETCurrGameState
		if(ETCurrGameState==et.GS_INTERMISSION) then
			if( ETBWins~=tonumber(et.trap_Cvar_Get("g_alliedwins")) ) then
				ETWinStreak["B"]=ETWinStreak["B"]+1
				ETWinStreak["R"]=0
			elseif( ETRWins~=tonumber(et.trap_Cvar_Get("g_axiswins")) ) then
				ETWinStreak["R"]=ETWinStreak["R"]+1
				ETWinStreak["B"]=0
			end
			ETBWins=tonumber(et.trap_Cvar_Get("g_alliedwins"))
			ETRWins=tonumber(et.trap_Cvar_Get("g_axiswins"))
			ETMaps=ETMaps+1
			et.trap_Cvar_Set("ps_ETWinStreakR", ETWinStreak["R"])
			et.trap_Cvar_Set("ps_ETWinStreakB", ETWinStreak["B"])
			et.trap_Cvar_Set("ps_ETMaps",ETMaps)
			if(( ETWinStreak["R"]>=MaxStreak or ETWinStreak["B"]>=MaxStreak ) and MaxStreak > 0 ) then
				if( ShuffleOrSwap(StreakBreak()) == 1 ) then
					ShuffleLock()
					ResetStreaks()
				end
			elseif(ETMaps>=MapCount) then
				if(ShuffleOrSwap(MapCountAction) == 1) then
					ResetStreaks()
				end
			end
		elseif(ETCurrGameState==et.GS_WARMUP_COUNTDOWN) then
			ETBWins=tonumber(et.trap_Cvar_Get("g_alliedwins"))
			ETRWins=tonumber(et.trap_Cvar_Get("g_axiswins"))
			ETMaps =tonumber(et.trap_Cvar_Get("ps_ETMaps"))
			if(ETMaps==nil) then
				et.trap_Cvar_Set("ps_ETMaps",0)
				ETMaps=0
			end
			local temp=tonumber(et.trap_Cvar_Get("ps_ETWinStreakR"))
			if(temp==nil) then
				et.trap_Cvar_Set("ps_ETWinStreakR", 0)
			end
 			temp=tonumber(et.trap_Cvar_Get("ps_ETWinStreakB"))
			if(temp==nil) then
				et.trap_Cvar_Set("ps_ETWinStreakB", 0)
			end
			ETWinStreak["B"] = tonumber(et.trap_Cvar_Get("ps_ETWinStreakB"))
			ETWinStreak["R"] = tonumber(et.trap_Cvar_Get("ps_ETWinStreakR"))
			if(( ETWinStreak["R"]>=MaxStreak or ETWinStreak["B"]>=MaxStreak ) and MaxStreak > 0 ) then
				local choice = ShuffleOrSwap(StreakBreak())
				if( choice == 2) then
					ResetStreaks()
				elseif( choice == 3 ) then
					ShuffleLock()
					ResetStreaks()
				end
			elseif(ETMaps>=MapCount) then
				if(ShuffleOrSwap(MapCountAction) ~=0 ) then
					ResetStreaks()
				end
			end
		end
	end
end

function getBadUser(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	local name = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ))
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		if ETAbuserMonitor[ip]~=nil  then
			return ETAbuserMonitor[ip]
		elseif ETAbuserMonitor[guid]~=nil then
			return ETAbuserMonitor[guid]
		end
	end
	return nil
end

function GlobalActionCPM(PlayerID,Action) 
	if(PlayerID~=-1) then
		local Name = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" )
		et.trap_SendServerCommand( -1,"cp \"" .. Name .. " ^7has been " .. Action .. " by the admin.\"\n")
	else
		et.trap_SendServerCommand( -1,"cp \"The admin has done a " .. Action .. ".\"\n")
	end
	PlaySound("-1","/sound/ETPower/energy.wav")
end

function IRCAs(Name, Text)
	et.trap_SendServerCommand( -1,"cpm \"^3IRC - ^1" .. Name .. "^2: " .. Text .. "^7\"\n")
end

function isPlayer(checkNum)
	local SlotNum = tonumber(checkNum)
	if(SlotNum==nil) then
		return false
	elseif(SlotNum>tonumber(et.trap_Cvar_Get("sv_maxclients"))) then
		return false
	end
	return et.gentity_get (SlotNum,"inuse")
end

function KickUser( PlayerID, Time )
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ) )
	et.trap_DropClient( PlayerID, "Admin Decision", Time )
end

function KillUser(PlayersID)
	et.gentity_set( PlayersID, "health", -200)
	if(tonumber(et.trap_Cvar_Get("p_PlaySound"))==1) then
		PlaySound(PlayersID .. "","/sound/ETPower/disappear.wav")
	end
	return 1
end

function ListCommands(PlayerID)
	local TimeKickAdmin = 2
	local NoTimeKickAdmin = 4
	local PutSpecAdmin = 4
	local KillAdmin = 2
	local RefAdmin = 3
	local SuperMuteAdmin = 2
	local MuteAdmin = 4
	local RenameAdmin = 3
	local NoVoteAdmin = 2
	local PlayerAdmin = 3
	local WarnAdmin = 4
	local PFVoteAdmin = 4
	local ShuffleAdmin = 3
	local ShuffleNRAdmin =4
	local AnnounceAdmin = 4
	local InfoAdmin = 3
	local RCONADMIN = 0
	local CONFIGADMIN=3
	local AbuserAdmin=4
	local NextMapAdmin=3
	local EXECADMIN = 3
	local LockTeamAdmin = 3
	local unLockTeamAdmin=4
	local ConsoleAdmin = 1
	et.trap_SendServerCommand( PlayerID,"cpm \"Console Commands Available to you.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"/m ^3PID ^2Message ^7- Sends the ^2Message ^7to the player in slot ^3PID^7.  If there is no player \"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"                 in the slot.  Default behavior (partial name matching) is activated.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"/m ^3PID ^2Message ^7- Sends the ^2Message ^7to the player in slot ^3PID^7.  If there is no player \"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"/say_admin ^3Message ^7- Sends the ^3Message ^7to all of the admins on the server.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"Say Commands Available to you.\"\n")
	if RCONADMIN >= PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!# ^3Server Code ^7- Sends your entire line of ^3Server Code^7 to the console.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!AdminList ^7- Displays admins currently on this server.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!AdminTest ^7- Displays your admin level for this server.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Alarm ^3Time ^7- Stores an alarm to remind you of a time.  ^3Time^7 is in minutes.\"\n")
	if AnnounceAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Announce ^3Location ^2Announcement ^7- Broadcasts the text in ^2Announcemnt^7 to the server.\"\n")
	end
	if AnnounceAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!AnnounceMe ^7- Broadcasts to the server that you have admin rights.\"\n")
	end
	if AbuserAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID, "cpm\"^1!BadUser ^3PID ^2Reason ^7- Marks the player in slot ^3PID ^7as a bad user, for ^2Reason^7.\"\n" )
	end
	if PFVoteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!CancelVote ^7- Cancels the current vote in process.\"\n")
	end
	if NoVoteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!CantVote ^3PID ^7- Removes the ability for the player in slot ^3PID^7 to vote.\"\n")
	end
	if NoVoteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!CanVote ^3PID ^7- Returns the ability for the player in slot ^3PID^7 to vote.\"\n")
	end
	if CONFIGADMIN>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!config ^3ConfigName ^7- Runs the .config file that matches the name ^3CfgName^7.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Date ^7- Shows the server's current date and time.\"\n")
	if MuteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!DeMute ^3PID ^7- Allows the player in slot ^3PID^7 to be unmuted.\"\n")
	end
	if EXECADMIN>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!exec ^3CfgName ^7- Exec's the cfg file that matches the name ^3CfgName^7.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Find ^3String ^7- Returns PID's and Names of everyone that has ^3String ^7in their name.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Help ^7- Shows this menu.\"\n")
	if InfoAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Info ^3PID ^7- Shows info on player in slot ^3PID ^7.\"\n")
	end
	if NoTimeKickAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Kick ^3PID ^7- Kicks the user in slot ^3PID ^7.\"\n")
	end
	if TimeKickAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Kick ^3PID ^2Time ^7- Kicks the user in slot ^3PID ^7for ^2Time ^7Seconds.\"\n")
	end
	if KillAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Kill ^3PID ^7- Kills the player located in slot ^3PID^7.\"\n")
	end
	if LockTeamAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID, "cpm\"^1!Lockspec ^3PID ^7- Locks the player in slot ^3PID^7 into spectator mode.\"\n")
	end
	if AbuserAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID, "cpm\"^1!listBadUsers ^7- Lists all the players marked as a bad user currently on the server.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Login ^3Password ^7- Logs you into PowerUser.\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!ModInfo ^7- Gives information on ETPowerMod^7.\"\n")
	if MuteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Mute ^3PID^7 - Mutes the player in slot ^3PID^7.  This is a persistant mute,\"\n")
		et.trap_SendServerCommand( PlayerID,"cpm \"            so if they disconnect, they will still be muted on next connect.\"\n")
	end
	if SuperMuteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"            Also they get cantvoted when you mute them,\"\n")
	end
	if NextMapAdmin >=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID, "cpm\"^1!nextmap ^7- Loads the next map.  Works in any mode (sw loads next round).\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Pass ^3Password ^7- Logs you into PowerUser.\"\n")
	if PFVoteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!PassVote ^7- Passes the current vote in process.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Password ^3Password ^7- Logs you into PowerUser.\"\n")
	if PutSpecAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!PutSpec ^3PID ^7- Puts the player in slot ^3PID^7 into the spectator mode.\"\n")
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!PutTeam ^3PID ^2Team^7- Puts the player in slot ^3PID^7 into ^2Team.\"\n")
		et.trap_SendServerCommand( PlayerID,"cpm \"                   Team can be r, red, b, blue, allies, or axis.\"\n")
	end
	if RefAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Ref ^3PID ^7- Makes the player in slot ^3PID^7 into a ref.\"\n")
	end
	if RenameAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!ReName ^3PID ^2NewName ^7- Renames the player in slot ^3PID^7 to ^2NewName^7.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Rules ^7- Displays the rules for the server.\"\n")
	if ShuffleAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!ShuffleXP ^7- Shuffle teams based on XP (standard shuffle).\"\n")
	end
	if ShuffleNRAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!ShuffleXPNR ^7- Shuffle teams based on XP w/o a map restart.\"\n")
	end
	et.trap_SendServerCommand( PlayerID,"cpm \"^1!Time ^7- Shows the server's current time.\"\n")
	if unLockTeamAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Unlockspec ^3PID ^7- Unlocks the locked spec in slot ^3PID^7.\"\n")
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Unlockspecall ^7- Unlocks all locked specs on the server.\"\n")
	end
	if MuteAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!UnMute ^3PID ^7- Unmutes the player in slot ^3PID^7.\"\n")
	end
	if WarnAdmin>=PowerUserLevel(PlayerID) then
		et.trap_SendServerCommand( PlayerID,"cpm \"^1!Warn ^3PID^7 ^2Warning ^7- Sends the text ^2Warning ^7to player in slot ^3PID^7.\"\n")
	end
	
end

function ListOnlinePowerUsers(PlayerID)
	local i=0
	local j=1
	local size=tonumber(et.trap_Cvar_Get("sv_maxclients"))
	local matches = {}
	while (i<size) do
		if(PowerUserLevel(i)~=nil) then
			if (PowerUserLevel(i)~=0) then
				matches[j]=i
				j=j+1
			end
		end
		i=i+1
	end
	if (table.getn(matches)~=nil) then
		i=1
		while (i<=table.getn(matches)) do
			et.trap_SendServerCommand( PlayerID,"cpm \"" .. et.Info_ValueForKey( et.trap_GetUserinfo( matches[i] ), "name" ) .. " ^7is a level " .. PowerUserLevel(matches[i])  .. " admin.\"\n")
			i=i+1
		end
		if table.getn(matches)==0 then
			et.trap_SendServerCommand( PlayerID,"cpm \"There are no visible admins online currently. Level 0 admins do not show up in this list.\"\n")
		else
			et.trap_SendServerCommand( PlayerID,"cpm \"Level 0 admins do not show up in this list.\"\n")

		end
	end
	return matches

end

function LoadCantVotes()
	local CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerNoVotesIPs"))
	local i = 1
	while(i<=table.getn(CantVotes)) do
		ETCantVote[CantVotes[i]] = true
		i=i+1
	end
	CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerMuteGUIDs"))
	i = 1
	while(i<=table.getn(CantVotes)) do
		ETCantVote[CantVotes[i]] = true
		i=i+1
	end

end

function LoadClanProtection()
	local tempST=et.trap_Cvar_Get("p_ClanProtectTag")
	local tempPos=tonumber(et.trap_Cvar_Get("p_ClanProtectPos"))
	local tempPas=et.trap_Cvar_Get("p_ClanProtectPas")
	if (tempSt~="" and tempPos~=nil and tempPas~="") then
		ETClanTagProtection={[1]=tempST,[2]=tempPos,[3]=tempPas}
		return 1
	end
	return 0
end

function LoadMutes()
	local Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteIP"))
	local i = 1
	while(i<=table.getn(Mutes)) do
		ETPowerMute[Mutes[i]] = true
		i=i+1
	end
	Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteGUIDs"))
	i = 1
	while(i<=table.getn(Mutes)) do
		ETPowerMute[Mutes[i]] = true
		i=i+1
	end
end

function LoadNameProtection()
	local fd,len = et.trap_FS_FOpenFile( et.trap_Cvar_Get("p_NameProtectFile"), et.FS_READ )
	local i = 0
	if len==-1 or len==0 then
		et.trap_FS_FCloseFile(fd)
		return
	end
	local filestr = et.trap_FS_Read( fd, len )
	et.trap_FS_FCloseFile(fd)
	for name,nametype,ip,guid,password in string.gfind(filestr, "([^%\\]+)%\\(%d+)%\\([^%\\]*)%\\(%x*)%\\([^%\\]*)%\\") do
		i=i+1
		ETProtectedNames[et.Q_CleanStr(name)]={[1]=nametype,[2]=name,[3]=ip,[4]=guid,[5]=password,[6]=i}
		ETProtectedNames[i]=et.Q_CleanStr(name)
		et.G_Print("Protected Name Added = " .. name .. "\n")
	end	
end

function LoadPowerUsers()
	local fd,len = et.trap_FS_FOpenFile( "PowerUserIPs.dat", et.FS_READ )
	if len == -1 then
		et.G_Print("WARNING: No PowerUserIp's Defined! \n")
	else
		local filestr = et.trap_FS_Read( fd, len )
		for ip in string.gfind(filestr, "(%d+%.%d+%.%d+%.%d+@%d)%s") do
			et.G_Print( "PowerUser IP:  " .. ip .. " Added. \n")
			AddPowerUserIP(ip)
		end
	end
	et.trap_FS_FCloseFile( fd ) 
	fd,len = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_READ )
	if len == -1 then
		et.G_Print( "WARNING: No PowerUserGUID's Defined! \n")
	else
		local filestr = et.trap_FS_Read( fd, len )
		for guid in string.gfind(filestr, "(%x+@%d)%s") do
			-- upcase for exact matches
			guid = string.upper(guid)
			et.G_Print( "PowerUser GUID: " .. guid .. " Added. \n" )
			AddPowerUserGUID(guid)
		end
	end
	et.trap_FS_FCloseFile( fd ) 
end

function loadRules() 
	local fd,len = et.trap_FS_FOpenFile( "rules.dat", et.FS_READ )
	if len> -1 then
		ETRules = et.trap_FS_Read( fd, len )
		local icount=0
	else
		et.G_Print( "WARNING: No rules defined! \n" )
	end
	et.trap_FS_FCloseFile( fd )
end

function LockSpecUser(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		ETSpecLock[ip] = true
		ETSpecLock[guid] = true			
	end
end

function LockTeams()
	ETTeamsLock=et.trap_Milliseconds()+2*1000*5
end

function log_admin_use(pid, command)
	local filename = et.trap_Cvar_Get("p_AdminLogFile")
	local Name = ""
	if string.len(filename)>1 then
		local fd,len = et.trap_FS_FOpenFile( filename, et.FS_APPEND )
		if(pid~=-1) then
			Name = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( pid ), "name" ))
		else
			Name = "ServerConsole"
		end
		local WriteThis = Name .. " performed " .. command .. "\n"
		et.trap_FS_Write( WriteThis, string.len(WriteThis) ,fd )
		et.trap_FS_FCloseFile( fd ) 
	end
end

function LoginPU(PlayerID, Password)
	if(Password==et.trap_Cvar_Get("rconpassword") and Password ~= "") then
		CreatePowerUser(PlayerID,0)
		et_AutoSAL(PlayerID)		
		return 0
	elseif(Password==et.trap_Cvar_Get("p_pu1pass") and Password ~= "") then
		CreatePowerUser(PlayerID,1)
		et_AutoSAL(PlayerID)		
		return 1
	elseif(Password==et.trap_Cvar_Get("p_pu2pass") and Password ~= "") then
		CreatePowerUser(PlayerID,2)
		et_AutoSAL(PlayerID)		
		return 2
	elseif(Password==et.trap_Cvar_Get("p_pu3pass") and Password ~= "") then
		CreatePowerUser(PlayerID,3)
		et_AutoSAL(PlayerID)		
		return 3
	elseif(Password==et.trap_Cvar_Get("p_pu4pass") and Password ~= "") then
		CreatePowerUser(PlayerID,4)
		et_AutoSAL(PlayerID)		
		return 4
	else
		return -1
	end
end

function ModInfo(PlayerID)
	et.trap_SendServerCommand( PlayerID,"cpm \"This server is using ETPowerMod version " .. ETPowerModVersion .. ".\n\"")
	et.trap_SendServerCommand( PlayerID,"cpm \"Created by Grendel, aka G073nks.\n\"")
	et.trap_SendServerCommand( PlayerID,"cpm \"For more information go to http://etpower.no-ip.org\n\"")
	et.trap_SendServerCommand( PlayerID,"cpm \"Or on IRC at irc.freenode.org/#ETPower\n\"")
end

function MutePlayer(PlayerID)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local userconfig = et.trap_GetConfigstring(et.CS_PLAYERS+PlayerID)
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( userinfo, "name" ) )
	local ip = et.Info_ValueForKey( userinfo, "ip" )
	if(ip==nil) then
		return 0
	end
	s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	local guid = string.upper(et.Info_ValueForKey( userinfo, "cl_guid" ))
	local ismute     = et.Info_ValueForKey( userconfig, "mu")
	if AddMuteIP(ip) + AddMuteGUID(guid) ~= "0" then
		et.trap_SendConsoleCommand(et.EXEC_APPEND, "mute " .. "\"" .. PlayerName .. "\"" .. "\n" )
		et.trap_SendServerCommand( PlayerID,"cpm \"You have been muted by the admin.\"\n")
		return 1
	end
	return 0
end

function MyStatus(PlayerID)
	local IP   = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local GUID = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	if (  ETPowerUserL0[GUID] or ETPowerUserL0[IP] ) then
		et.trap_SendServerCommand( PlayerID,"cpm \"You are full admin\n\"")
	elseif ( ETPowerUserL1[GUID] or ETPowerUserL1[IP] ) then
		et.trap_SendServerCommand( PlayerID,"cpm \"You are Level 1 Power User\n\"\n")
	elseif ( ETPowerUserL2[GUID] or ETPowerUserL2[IP] ) then
		et.trap_SendServerCommand( PlayerID,"cpm \"You are Level 2 Power User\n\"\n")
	elseif ( ETPowerUserL3[GUID] or ETPowerUserL3[IP] ) then
		et.trap_SendServerCommand( PlayerID,"cpm \"You are Level 3 Power User\n\"\n")			
	elseif ( ETPowerUserL4[GUID] or ETPowerUserL4[IP] ) then
		et.trap_SendServerCommand( PlayerID,"cpm \"You are Level 4 Power User\n\"\n")			
	else
		et.trap_SendServerCommand( PlayerID,"cpm \"You are lowly user\"\n")			
	end
end

function NumPrivateMessage(rPlayerID,sPlayerID,MSG,Sender)
	local rName = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( rPlayerID ), "name" ))
	local sName = et.Info_ValueForKey( et.trap_GetUserinfo( sPlayerID ), "name" )
	et.trap_SendServerCommand( rPlayerID,"cpm \"" .. sName .. "^7: ^1(Private to " .. rName .. ")^7" .. MSG .. "\"\n")
	if(Sender) then
		et.trap_SendServerCommand( sPlayerID,"cpm \"" .. sName .. "^7: ^1(Private to " .. rName .. ")^7" .. MSG .. "\"\n")
	end
end

function ParseString(inputString)
	local i = 1
	local t = {}
	for w in string.gfind(inputString, "([^%s]+)%s*") do
		t[i]=w
		i=i+1
	end
	return t
 end
 
function PassVote()
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "passvote\n" )
end

function PlayerInfo(PlayerID, ClientNum)
	local name = et.Q_CleanStr(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ))
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	local guid = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	if ip ~= nil then
		if(ClientNum~=-1) then
			if PowerUserLevel(PlayerID) ~= nil then
				et.trap_SendServerCommand(ClientNum, "cpm \"Name:   " .. name .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"IP:     " .. ip .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"GUID:   " .. guid .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"Slot:   " .. PlayerID .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"PBSlot: " .. PlayerID+1 .. "\"\n")
				if(ETIACINFO[PlayerID]~=nil) then
					et.trap_SendServerCommand(ClientNum, "cpm \"ETProGUID: " .. ETIACINFO[PlayerID][1] .. "\"\n")
					if(ETIACINFO[PlayerID][2]~=nil) then
						et.trap_SendServerCommand(ClientNum, "cpm \"ETProIAC: " .. ETIACINFO[PlayerID][2] .. "\"\n")
					end
				end
				et.trap_SendServerCommand(ClientNum, "cpm \"Power User Level: Level " .. PowerUserLevel(PlayerID) .. "\"\n")
			else
				et.trap_SendServerCommand(ClientNum, "cpm \"Name:   " .. name .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"IP:     " .. ip .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"GUID:   " .. guid .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"Slot:   " .. PlayerID .. "\"\n")
				et.trap_SendServerCommand(ClientNum, "cpm \"PBSlot: " .. PlayerID+1 .. "\"\n")
				if(ETIACINFO[PlayerID]~=nil) then
					et.trap_SendServerCommand(ClientNum, "cpm \"ETProGUID: " .. ETIACINFO[PlayerID][1] .. "\"\n")
					if(ETIACINFO[PlayerID][2]~=nil) then
						et.trap_SendServerCommand(ClientNum, "cpm \"ETProIAC: " .. ETIACINFO[PlayerID][2] .. "\"\n")
					end
				end
				et.trap_SendServerCommand(ClientNum, "cpm \"Power User Level: User\"\n")
			end
		else
			if PowerUserLevel(PlayerID) ~= nil then
				et.G_Print("Name:   " .. name .. "\n")
				et.G_Print("IP:     " .. ip .. "\n")
				et.G_Print("GUID:   " .. guid .. "\n")
				et.G_Print("Slot:   " .. PlayerID .. "\n")
				et.G_Print("PBSlot: " .. PlayerID+1 .. "\n")
				if(ETIACINFO[PlayerID]~=nil) then
					et.G_Print("ETProGUID: " .. ETIACINFO[PlayerID][1] .. "\n")
					if(ETIACINFO[PlayerID][2]~=nil) then
						eet.G_Print("ETProIAC: " .. ETIACINFO[PlayerID][2] .. "\n")
					end
				end
				et.G_Print("Power User Level: Level " .. PowerUserLevel(PlayerID) .. "\n")
			else
				et.G_Print("Name:   " .. name .. "\n")
				et.G_Print("IP:     " .. ip .. "\n")
				et.G_Print("GUID:   " .. guid .. "\n")
				et.G_Print("Slot:   " .. PlayerID .. "\n")
				et.G_Print("PBSlot: " .. PlayerID+1 .. "\n")
				if(ETIACINFO[PlayerID]~=nil) then
					et.G_Print("ETProGUID: " .. ETIACINFO[PlayerID][1] .. "\n")
					if(ETIACINFO[PlayerID][2]~=nil) then
						et.G_Print("ETProIAC: " .. ETIACINFO[PlayerID][2] .. "\n")
					end
				end
				et.G_Print("Power User Level: User\n")
			end
		end
	end
end

function PlayerSlot( PlayerName, PlayerID )
	local i=0
	local j=1
	local size=tonumber(et.trap_Cvar_Get("sv_maxclients"))
	local matches = {}
	while (i<size) do
		s,e,found = string.find(string.lower(et.Q_CleanStr( et.Info_ValueForKey( et.trap_GetUserinfo( i ), "name" ) )),string.lower(PlayerName)) 
		if(found~=nil) then
				matches[j]=i
				j=j+1
		end
		i=i+1
	end
	if (table.getn(matches)~=nil) then
		i=1
		while (i<=table.getn(matches)) do
			et.trap_SendServerCommand( PlayerID,"cpm \"" .. et.Info_ValueForKey( et.trap_GetUserinfo( matches[i] ), "name" ) .. " ^7is in slot " .. matches[i]  .. "\"\n")
			i=i+1
		end
		if table.getn(matches)==0 then
				et.trap_SendServerCommand( PlayerID,"cpm \"You had no matches to that name.\"\n")
		end
	end
	return matches
end

function PlaySound( entNum , Sound)
	if(tonumber(entNum)~=nil) then
		if(tonumber(entNum)>=0) then
			et.G_Sound(entNum,et.G_SoundIndex(Sound))
			return 1
		else
			PlaySoundGlobal(Sound)
		end
	end
	return 0
end

function PlaySoundGlobal(Sound)
	et.G_globalSound(Sound)
end

function PowerCfg(CfgName)
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "exec " .. CfgName .. "\n" )
end

function PowerConfig(ConfigName)
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "config " .. ConfigName .. "\n" )
end

function PowerUserCommand(PlayerID, Command, BangCommand, Cvar1, Cvar2, Cvarct) 
	local IP = ""
	local GUID = ""
	local intercepted =0
	if(PlayerID~=-1) then
		IP   = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
		GUID = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
		s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	else
		IP   = -1
		GUID = -1
	end
	if (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL1[IP] or ETPowerUserL1[GUID]) then
		intercepted = 1
	end
	local SayPowerUser =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local TeamPowerUsr =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local PrivPowerUsr =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL2[IP] or ETPowerUserL2[GUID])
	local CmdPowerUser =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL1[IP] or ETPowerUserL1[GUID])
	local TimeKickAdmin=  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL2[IP] or ETPowerUserL2[GUID])
	local NoTimeKickAdmin=(ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local PutSpecAdmin =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local KillAdmin = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL2[IP] or ETPowerUserL2[GUID])
	local RefAdmin = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local SuperMuteAdmin= (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL2[IP] or ETPowerUserL2[GUID])
	local MuteAdmin = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local RenameAdmin =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local NoVoteAdmin =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL2[IP] or ETPowerUserL2[GUID])
	local PlayerAdmin =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local WarnAdmin = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local PFVoteAdmin =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local ShuffleAdmin =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local ShuffleNRAdmin= (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local AnnounceAdmin=  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])
	local InfoAdmin = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local RCONADMIN = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID])
	local AbuserAdmin =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID] )
	local EXECADMIN = 	  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID] )
	local CONFIGADMIN =   (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID] )
	local NextMapAdmin =  (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local LockTeamAdmin = (ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL3[IP] or ETPowerUserL3[GUID])
	local unLockTeamAdmin=(ETPowerUserL0[IP] or ETPowerUserL0[GUID] or ETPowerUserL4[IP] or ETPowerUserL4[GUID])

	if ((Command=="say" and SayPowerUser) or (Command=="say_team" and TeamPowerUser) or (Command=="say_teamnl" and TeamPowerUser) or (Command=="command" and CmdPowerUser)) then
		if (Cvarct>=2) then
			if (string.lower(BangCommand) == "!announceme" and AnnounceAdmin) then
				AnnounceMe(PlayerID)
				log_admin_use(PlayerID, "Announceme")
				return 1
			elseif (string.lower(BangCommand) == "!passvote" and PFVoteAdmin) then
				PassVote()
				GlobalActionCPM(-1,"passvote")
				log_admin_use(PlayerID, "PassVote")
				return intercepted
			elseif (string.lower(BangCommand) == "!cancelvote" and PFVoteAdmin) then
				CancelVote()
				GlobalActionCPM(-1,"cancelvote")
				log_admin_use(PlayerID, "Cancelvote")
				return intercepted
			elseif (string.lower(BangCommand) == "!shufflexp" and ShuffleAdmin) then
				ShuffleTeamsXP()
				ResetStreaks()
				GlobalActionCPM(-1,"shuffle teams")
				log_admin_use(PlayerID, "ShuffleTeamsXP")
				ShuffleLock()
				return intercepted
			elseif (string.lower(BangCommand) == "!shufflexpnr" and ShuffleAdmin) then
				ShuffleTeamsXP_NoRestart()
				ResetStreaks()
				GlobalActionCPM(-1,"shuffle teams w/o a restart")
				log_admin_use(PlayerID, "ShuffleTeamsXPNR")
				ShuffleLock()
				return intercepted
			elseif (string.lower(BangCommand) == "!listbadusers" and AbuserAdmin) then
				DisplayBadUser(PlayerID)
				log_admin_use(PlayerID, "ListBadUsers")
				return 1
			elseif (string.lower(BangCommand) == "!nextmap" and NextMapAdmin) then
				et.trap_SendConsoleCommand( et.EXEC_APPEND, "timelimit 0.01 \n" )
				GlobalActionCPM(-1,"nextmap")
				log_admin_use(PlayerID, "NextMap")
				return intercepted
			elseif ( string.lower(BangCommand) == "!unlockspecall" and unLockTeamAdmin) then
				log_admin_use(PlayerID, "Unlock all Team locks")
				et.trap_SendServerCommand( -1,"cpm \"All spec locks have been removed by the admin.\"\n")
				RemoveSpecLocks()
				return intercepted
--			elseif ( string.lower(BangCommand) == "!sal") then			
--				et.gentity_set(PlayerID, "sess.semiadmin",1)
--				et.G_Print(et.gentity_get(PlayerID, "sess.semiadmin") .. "\n")
--				return 0
			elseif ( string.lower(BangCommand) == "!hit") then 
				et.trap_SendServerCommand( -1,"cpm \"Your Team Number is " .. et.gentity_get( PlayerID, "sess.sessionTeam") .. "\"\n")
				return 0
			elseif (Cvarct>=3) then
				if (string.lower(BangCommand) == "!kill" and KillAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Kill " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"killed")
						KillUser(tonumber(Cvar1))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!kick" and NoTimeKickAdmin and Cvarct==3) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Kick " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"kicked")
						KickUser(tonumber(Cvar1), 120)
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!kick" and TimeKickAdmin and Cvarct>3) then
					if isPlayer(Cvar1) and tonumber(Cvar2)~= nil  then
						log_admin_use(PlayerID, "TimeKick " .. Cvar1 .. " " .. Cvar2)
						GlobalActionCPM(tonumber(Cvar1),"kiicked for " .. Cvar2 .. " seconds")
						KickUser(tonumber(Cvar1), tonumber(Cvar2))
					elseif (isPlayer(Cvar1) and tonumber(Cvar2)== nil) then
						log_admin_use(PlayerID, "Kick " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"kicked")
						KickUser(tonumber(Cvar1), 120)
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!kick" and NoTimeKickAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Kick " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"kicked")
						KickUser(tonumber(Cvar1), 120)
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!putspec" and PutSpecAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "PutSpec " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"moved to spectator")
						PutSpec(tonumber(Cvar1))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!putteam" and PutSpecAdmin and Cvarct>3) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "PutTeam " .. Cvar1 .. " " .. Cvar2)
						GlobalActionCPM(tonumber(Cvar1),"killed")
						PutTeam(tonumber(Cvar1), (Cvar2))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!ref" and RefAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Ref " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"ref'ed")
						RefereePlayer(tonumber(Cvar1))
					end
					return intercepted
				elseif ((string.lower(BangCommand) == "!cantvote" or string.lower(BangCommand) == "!can'tvote" ) and NoVoteAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "CantVote " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"cant voted")
						cantVote(tonumber(Cvar1))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!canvote" and NoVoteAdmin) then
					if isPlayer(Cvar1) then
						GlobalActionCPM(tonumber(Cvar1),"can voted")
						log_admin_use(PlayerID, "CanVote " .. Cvar1)
						canVote(tonumber(Cvar1))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!mute" and MuteAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Mute " .. Cvar1)
						MutePlayer(tonumber(Cvar1))
						if(SuperMuteAdmin) then
							log_admin_use(PlayerID, "CantVote  " .. Cvar1)
							GlobalActionCPM(tonumber(Cvar1),"Power-Muted")
							cantVote(tonumber(Cvar1))
						else
						GlobalActionCPM(tonumber(Cvar1),"Persistant-Muted")						
						end
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!unmute" and MuteAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Unmute " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"Unmuted")
						UnMutePlayer(tonumber(Cvar1))
						canVote(tonumber(Cvar1))
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!demute" and MuteAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Demute " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"demuted")
						DemutePlayer(tonumber(Cvar1))
						canVote(tonumber(Cvar1))
					end
					return intercepted
				elseif ((string.lower(BangCommand) == "!rename" or string.lower(BangCommand) == "!name") and RenameAdmin and Cvarct>3) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Rename " .. Cvar1)
						GlobalActionCPM(tonumber(Cvar1),"renamed")
						RenameUser(tonumber(Cvar1),Cvar2)
					end
					return intercepted
				elseif (string.lower(BangCommand) == "!warn" and WarnAdmin and Cvarct>3) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Warn " .. Cvar1 .. " " .. Cvar2)
						warn(tonumber(Cvar1),Cvar2)
					end
					return 1				
				elseif (string.lower(BangCommand) == "!announce" and AnnounceAdmin and Cvarct>3) then
					if tonumber(Cvar1)== 1 or tonumber(Cvar1)== 2 or tonumber(Cvar1)== 3 then
						log_admin_use(PlayerID, "Annoucne " .. Cvar2)
						Announce(tonumber(Cvar1),Cvar2)
					end
					return 1
				elseif ( string.lower(BangCommand) == "!info" and InfoAdmin ) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "Info " .. Cvar1)
						PlayerInfo((tonumber(Cvar1)), PlayerID)
					end
					return intercepted	
				elseif ( string.lower(BangCommand) =="!#" and RCONADMIN ) then
					log_admin_use(PlayerID, "RCON " .. Cvar1 .. " " .. Cvar2)
					FakeRCONPowerUser(Cvar1 .. " " .. Cvar2)
					return 1
				elseif ( string.lower(BangCommand) == "!exec" and EXECADMIN ) then
					log_admin_use(PlayerID, "Exec " .. Cvar1)
					PowerCfg(Cvar1)
					return intercepted
				elseif ( string.lower(BangCommand) == "!config" and CONFIGADMIN ) then
					log_admin_use(PlayerID, "Config " .. Cvar1)
					PowerConfig(Cvar1)
					return intercepted
				elseif ( string.lower(BangCommand) == "!baduser" and Cvarct>3 and AbuserAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "AddBadUser " .. Cvar1)
						AddBadUser(tonumber(Cvar1), Cvar2)
					end
					return 1
				elseif ( string.lower(BangCommand) == "!lockspec" and LockTeamAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "lock spec " .. Cvar1)
						PutSpec(tonumber(Cvar1))
						et.trap_SendServerCommand( tonumber(Cvar1),"cpm \"You have been locked in spec by the admin.\"\n")
						GlobalActionCPM(tonumber(Cvar1),"locked in spec")
						LockSpecUser(tonumber(Cvar1))
					end
					return intercepted
				elseif ( string.lower(BangCommand) == "!unlockspec" and unLockTeamAdmin) then
					if isPlayer(Cvar1) then
						log_admin_use(PlayerID, "unlock spec " .. Cvar1)
						et.trap_SendServerCommand( tonumber(Cvar1),"cpm \"You have been unlocked from spec by the admin.\"\n")
						GlobalActionCPM(tonumber(Cvar1),"unlocked from spec")
						unLockSpecUser(tonumber(Cvar1))
					return intercepted
					end
				end
			end
		end
	end
	--et.G_Print("\n\n\n\n\n" .. Command .. "\n\n\n\n\n")
	return ClientUserCommand(PlayerID, Command, BangCommand, Cvar1, Cvar2, Cvarct)
end

function PowerUserEmulation(PlayerID)
	local BangCommand = et.trap_Argv(0)
	local Cvar1 = ""
	local Cvar2 = ""
	local Cvarct= et.trap_Argc()+1
	if(et.trap_Argc()>1) then
		Cvar1=et.trap_Argv(1)
	end
	if(et.trap_Argc()>2) then
		Cvar2=et.ConcatArgs(2)
	end
	if(PowerUserLevel(PlayerID)==0 or PowerUserLevel(PlayerID)==1) then
		return PowerUserCommand(PlayerID , "command" , BangCommand , Cvar1 , Cvar2 , Cvarct) 
	end
end

function PowerUserLevel(PlayerID)
	local ip = ""
	local guid = ""
	if(PlayerID~=-1) then
		ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
		guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	else
		ip=-1
		guid=-1
	end
	if ( ETPowerUserL0[ip] or  ETPowerUserL0[guid] ) then
		return 0
	elseif ( ETPowerUserL1[ip] or ETPowerUserL1[guid] ) then
		return 1
	elseif ( ETPowerUserL2[ip] or ETPowerUserL2[guid] ) then
		return 2
	elseif ( ETPowerUserL3[ip] or ETPowerUserL3[guid] ) then
		return 3
	elseif ( ETPowerUserL4[ip] or ETPowerUserL4[guid] ) then
		return 4
	end
	return nil
end

function PowerUserList()
	local fd,len = et.trap_FS_FOpenFile( "PowerUserIPs.dat", et.FS_READ )
	local i = 0
	local g = 0
	if len == -1 then
		et.G_Print("There are no Power User IP's to list. \n")
	else
		local filestr = et.trap_FS_Read( fd, len )
		et.G_Print( "PUID:  IP              = Name\n")
		for ip,name in string.gfind(filestr, "(%d+%.%d+%.%d+%.%d+@%d)%s%-%s*([^%\n]*)") do
			i=i+1
			et.G_Print( "IP-" .. i .. ":  " .. ip .. " - " .. name .. " \n")
		end
	end
	et.trap_FS_FCloseFile( fd ) 
	fd,len = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_READ )
	if len == -1 then
		et.G_Print( "There are no Power User GUID's to list. \n")
	else
		local filestr = et.trap_FS_Read( fd, len )
		et.G_Print( "\nPUGUID: GUID                               - Name\n")
		for guid,name in string.gfind(filestr, "(%x+@%d)%s%-%s*([^%\n]*)") do
			-- upcase for exact matches
			guid = string.upper(guid)
			g=g+1
			et.G_Print( "GUID-" .. g .. ": " .. guid .. " - " .. name .. " \n" )
		end
	end
	et.trap_FS_FCloseFile( fd ) 
end



function ReadIAC(text)
	local t = ParseString(text)
	if(ETIACNextLinePID==-1 and table.getn(t)>3) then
		if(t[4]~="GUID") then
			local temp=tonumber(t[3])
			if(temp~=nil) then
				ETIACNextLinePID=temp
			else
				ETIACNextLinePID=-1
				et.G_Print("Invalid ETPro IAC Line\n")
				et.G_Print("--------------------------------------------------------------------")
				et.G_Print(text)
				et.G_Print("--------------------------------------------------------------------")
			end
		else
			local temp=tonumber(t[3])
			et.G_Print("t5=" .. t[5] .."\n")
			if(temp~=nil) then
				if(ETIACINFO[temp]==nil) then
					ETIACINFO[temp]={}
				end
				ETIACINFO[temp][1]=t[5]
				ETIACNextLinePID=-1
			else
				ETIACNextLinePID=-1
				et.G_Print("Invalid ETPro IAC Line\n")
				et.G_Print("--------------------------------------------------------------------")
				et.G_Print(text)
				et.G_Print("--------------------------------------------------------------------")
			end
		end
	elseif(table.getn(t)==3 and ETIACNextLinePID~=-1) then
		ETIACINFO[ETIACNextLinePID][2]=t[3]
		ETIACNextLinePID=-1
	else
		ETIACNextLinePID=-1
		et.G_Print("Invalid ETPro IAC Line\n")
		et.G_Print("--------------------------------------------------------------------")
		et.G_Print(text)
		et.G_Print("--------------------------------------------------------------------")
	end
end

function RefereePlayer(PlayerID) 
	local isref = et.Info_ValueForKey( et.trap_GetConfigstring( PlayerID ), "ref" )
	if isref ~= "1" then
		et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref referee " .. PlayerID .. "\n" )
		et.trap_SendServerCommand( PlayerID,"cpm \"You have been made ref by the admin.\"\n")
		return 1
	end
	return 0
end

function RemoveCantVoteGUID(GUID)
	s,e,GUID = string.find(GUID,"(%x+)")
	GUID = string.upper(GUID)
	local CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerNoVotesGUIDs"))
	local i = 1
	while(i<=table.getn(CantVotes)) do
		if(GUID==CantVotes[i]) then
			CantVotes[i]=""
		end
		i=i+1
	end
	et.trap_Cvar_Set("ps_PowerNoVotesGUIDs",table.concat(CantVotes," "))
	if(ETCantVote[GUID]~=nil) then
		ETCantVote[GUID] = nil
		return 1
	end
	return 0
end

function RemoveCantVoteIP(IP)
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	local CantVotes = ParseString(et.trap_Cvar_Get("ps_PowerNoVotesIPs"))
	local i = 1
	while(i<=table.getn(CantVotes)) do
		if(IP==CantVotes[i]) then
			CantVotes[i]=nil
		end
		i=i+1
	end
	et.trap_Cvar_Set("ps_PowerNoVotesIPs",table.concat(CantVotes," "))
	if(ETCantVote[IP] ~= nil) then
		ETCantVote[IP]=nil
		return 1
	end
	return 0
end

function RemoveGUIDPowerUser(index)
	local fdin,lenin = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_READ )
	local fdout,lenout = et.trap_FS_FOpenFile( "TempFile.dat", et.FS_WRITE )
	local g = 0
	local IPRemove = ""
	if lenin == -1 then
		et.G_Print("There is no Power User IP to remove \n")
	else
		local filestr = et.trap_FS_Read( fdin, lenin )
		for guid,name in string.gfind(filestr, "(%x+@%d)%s%-%s*([^%\n]*)") do
			g=g+1
			if (g==index) then
				s,e,guid = string.find(guid,"(%x+)@%d")
				guid = string.upper(guid)
				ETPowerUserL0[guid] = nil
				ETPowerUserL1[guid] = nil
				ETPowerUserL2[guid] = nil
				ETPowerUserL3[guid] = nil
				ETPowerUserL4[guid] = nil
			else
				guid = 	string.upper(guid) .. " - " .. name .. "\n"
				et.trap_FS_Write( guid, string.len(guid) ,fdout )
			end
		end
	end
	et.trap_FS_FCloseFile( fdin ) 
	et.trap_FS_FCloseFile( fdout )
	et.trap_FS_Rename( "TempFile.dat", "PowerUserGUIDs.dat" )	
end

function RemoveIPPowerUser(index)
	local fdin,lenin = et.trap_FS_FOpenFile( "PowerUserIPs.dat", et.FS_READ )
	local fdout,lenout = et.trap_FS_FOpenFile( "TempFile.dat", et.FS_WRITE )
	local i = 0
	local IPRemove = ""
	if lenin == -1 then
		et.G_Print("There is no Power User IP to remove \n")
	else
		local filestr = et.trap_FS_Read( fdin, lenin )
		for ip,name in string.gfind(filestr, "(%d+%.%d+%.%d+%.%d+@%d)%s%-%s*([^%\n]*)") do
			i=i+1
			if (i==index) then
				s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)@%d")
				ETPowerUserL0[ip] = nil
				ETPowerUserL1[ip] = nil
				ETPowerUserL2[ip] = nil
				ETPowerUserL3[ip] = nil
				ETPowerUserL4[ip] = nil
			else
				ip = ip .. " - " .. name .. "\n"
				et.trap_FS_Write( ip, string.len(ip) ,fdout )
			end
		end
	end
	et.trap_FS_FCloseFile( fdin ) 
	et.trap_FS_FCloseFile( fdout )
	et.trap_FS_Rename( "TempFile.dat", "PowerUserIPs.dat" )	
end

function RemoveMuteGUID(GUID)
	s,e,GUID = string.find(GUID,"(%x+)")
	GUID = string.upper(GUID)
	local Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteGUIDs"))
	local i = 1
	while(i<=table.getn(Mutes)) do
		if(GUID==Mutes[i]) then
			Mutes[i]=""
		end
		i=i+1
	end
	et.trap_Cvar_Set("ps_PowerMuteGUIDs",table.concat(Mutes," "))
	if(ETPowerMute[GUID]~=nil) then
		ETPowerMute[GUID] = nil
		return 1
	end
	return 0
end

function RemoveMuteIP(IP)
	s,e,IP = string.find(IP,"(%d+%.%d+%.%d+%.%d+)")
	local Mutes = ParseString(et.trap_Cvar_Get("ps_PowerMuteIP"))
	local i = 1
	while(i<=table.getn(Mutes)) do
		if(IP==Mutes[i]) then
			Mutes[i]=""
		end
		i=i+1
	end
	et.trap_Cvar_Set("ps_PowerMuteIP",table.concat(Mutes," "))
	ETPowerMute[IP] = nil
	return 1
end

function RemoveSpecLocks() 
	ETSpecLock={}
end

function RenameUser(PlayerID,Name)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( userinfo, "name" ) )
	userinfo = et.Info_SetValueForKey( userinfo, "name", Name )
	et.trap_SetUserinfo( PlayerID, userinfo )
	et.trap_SendConsoleCommand(et.EXEC_APPEND, "mute " .. "\"" .. PlayerName .. "\"" .. "\n" )
	PlayerName = et.Q_CleanStr( et.Info_ValueForKey( userinfo, "name" ) )
	et.trap_SendConsoleCommand(et.EXEC_APPEND, "unmute " .. "\"" .. PlayerName .. "\"" .. "\n" )
end

function ResetStreaks()
	ETWinStreak["R"] = 0
	ETWinStreak["B"] = 0
	ETMaps=0
	et.trap_Cvar_Set("ps_ETWinStreakR", 0)
	et.trap_Cvar_Set("ps_ETWinStreakB", 0)
	et.trap_Cvar_Set("ps_ETMaps", 0)
end

function SayAs(Name, Text)
	et.trap_SendServerCommand( -1,"cpm \"^1" .. Name .. "^2: " .. Text .. "^7\"\n")
end

function SetAlarm(PlayerID,Time)
	ETPlayerAlarm[PlayerID] = {[1]=Time}
	et.trap_SendServerCommand( PlayerID,"cpm \"Alarm=".. ETPlayerAlarm[PlayerID][1] .. "\"\n")
	et.trap_SendServerCommand( PlayerID,"cpm \"Current=".. et.trap_Milliseconds() .. "\"\n")
end

function ShuffleOrSwap(Option)
	local OptDoNothing = 0
	local OptShuffleTeamsXP = 1
	local OptSwapTeams = 2
	if( Option == OptShuffleTeamsXP ) then
		et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref shuffleteamsxp\n" )
		return OptShuffleTeamsXP
	end
	if( Option == OptSwapTeams) then
		et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref swapteams\n" )
		return OptSwapTeams
	end
	if(Option == OptShuffleTeamsXP + OptSwapTeams) then
		et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref shuffleteamsxp\n" )
		et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref swapteams\n" )
		return OptShuffleTeamsXP + OptSwapTeams
	end
	return OptDoNothing
end

function ShowServerRules( PlayerID ) 
	et.trap_SendServerCommand( PlayerID,"cpm \"Rules:\"\n")
	for w in string.gfind(ETRules, "([^%*]*)%*%s") do
		et.trap_SendServerCommand( PlayerID,"cpm \"" .. w .. "\"")
	end
end

function ShuffleLock()
	local Multiplier = 0
	if(tonumber(et.trap_Cvar_Get("p_unlocktime"))==nil) then
		et.trap_Cvar_Set("p_unlocktime",0)
	end
	Multiplier=tonumber(et.trap_Cvar_Get("p_unlocktime"))
	et.trap_Cvar_Set("ps_lockteams",(et.trap_Milliseconds()+Multiplier*1000*60)) 
 end

function ShuffleTeamsXP()
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref shuffleteamsxp\n" )
end

function ShuffleTeamsXP_NoRestart()
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "ref shuffleteamsxp_norestart\n" )
end

function StreakBreak()
	local OptDoNothing = 0
	local OptShuffleTeamsXP = 1
	local OptSwapTeams = 2
	local ActionSelect = tonumber(et.trap_Cvar_Get("p_StreakBreaker"))
	if( OptSwapTeams == OptShuffleTeamsXP ) then
		return OptShuffleTeamsXP
	elseif( ActionSelect == OptSwapTeams ) then
		return OptSwapTeams
	elseif( ActionSelect == OptSwapTeams+OptShuffleTeamsXP ) then
		return OptSwapTeams+OptShuffleTeamsXP
	end
	return OptDoNothing
end

function unLockSpecUser(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		ETSpecLock[ip] = nil
		ETSpecLock[guid] = nil
	end
end

function UnMutePlayer(PlayerID)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local userconfig = et.trap_GetConfigstring(et.CS_PLAYERS+PlayerID)
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( userinfo, "name" ) )
	local ismute     = et.Info_ValueForKey( userconfig, "mu")
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = string.upper(et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" ))
	s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
	if RemoveMuteGUID(guid) + RemoveMuteIP(ip) ~= "0" then
		et.trap_SendConsoleCommand(et.EXEC_APPEND, "unmute " .. "\"" .. PlayerName .. "\"" .. "\n" )
		return 1
	end
	return 0
end

function warn(PlayerID, Warning)
	et.trap_SendServerCommand( PlayerID,"cpm \"^1Warning:^7" .. Warning .. "\"\n")
end
