--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Todo List--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---Silent login
---Name recognition
-------Killer, Killed, DamageGiver, DamageReciever, Revived, Healed, Healer, Reviver, Target
-------Partial name match
---Admin offline messages, optional RCON MSG History

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Quick Refrence--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Sending global msg
-------et.trap_SendServerCommand( -1,"cpm \"\"\n")		
--Get cvar and translate to a number
-------tonumber(et.trap_Cvar_Get("cvar"))
--partial name match
------- pmh_NameMatch(nonformatted name)


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Script Start--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

ETPowerModVersion = "1.0"
ETSilent = 0
ETSALevels = 0
ETPowerMute = {}
ETCantVote = {}
ETKnifeOnly = {}
ETPowerUsers = {}
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

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--ET Default Functions--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Updated 01Dec08
function et_InitGame( levelTime, randomSeed, restart )
	local currentver = et.trap_Cvar_Get("mod_version")
	et.G_Print( "Gotenks ETPowerMod, PowerMod version " .. ETPowerModVersion .. "\n" )
	et.RegisterModname( "Gotenks_PowerMod-" .. ETPowerModVersion .. " " .. et.FindSelf() )
	et.trap_SendConsoleCommand(et.EXEC_APPEND, "forcecvar mod_version \"" .. currentver .. " - ETPowerMod\"" .. "\n" )
	pm_LoadPowerModCvars()
	pm_LoadPersistantMutes()
	pm_LoadPersistantSpecs()
	pm_LoadPersistantKnives()
	et.G_Print("Loading Power User Prifiles\n")
	pm_LoadPowerUsers()
	et.G_Print("----------------------------------------------------\n")
	et.G_Print("Loading Rules\n")
	pm_LoadRules()
end

--Updated 09Dec08
function et_ClientBegin( clientNum )
	local rank = pm_GetAutoRank(clientNum)
	pm_loadUserInfo(clientNum)
	pm_AssignRank(clientNum,rank,true)
	disp_ModInfo(clientNum)
end


function et_ClientCommand( clientNum, command )
	local rank = pm_GetRank(clientNum)
	local cmd1 = string.lower(et.trap_Argv(0))
	local cmd2 = string.lower(et.trap_Argv(1))
	if(cmd1=="sa" or cmd1=="semiadmin") then
		if(pm_CommandAllowed(cmd2)) then
			return pm_DoCommand(et.ConcatArgs(1),clientNum)
		end	
		
	end
end

--Updated 28Dec08
function et_RunFrame( levelTime )
	if(ETLockTeams and et.trap_Milliseconds()>ETTeamsLock) then
			pm_UnlockTeams()
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--AutoActions--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function pm_DoCommand(command,Admin)
	local cmd = pmh_String2Array(command)
	--multiuse command, sub choices will depend on 2nd and sometimes 3rd entry
	--	teams - locks teams until unlock teams or unlock all is called, individual 
	--		players can be unlocked, people currently in spec are not locked
	--		check to ensure that players can change classes within their new team.
	--	teams <time> - locks teams for specified time, if time goes beyond end of 
	--		map, lock expires at end of map, locking works like unlock teams command
	--		check to ensure that players can change classes within their new team.
	--	spec <pid> - places a player into spec then locks them until unlock team,
	--		unlock all, unlock spec <pid>, unlock spec <name> is called
	--	spec <name> - router to lock spec <pid>, uses name matching
	--	mute <pid> - locks a player into mute until unlock all, unlock mute <pid>,
	--		unlock mute <name> is called
	if(string.lower(cmd[0]) == "lock") then	
		if(string.lower(cmd[1]) == "teams") then
			if(tonumber(cmd[2])!= 3) then
				return LockTeams(cmd[2])				
			end
			return LockTeams(9999)
		elseif(string.lower(cmd[1]) == "spec")
			if(tonumber(cmd[2])!=nil) then
				LockSpecUser(cmd[2])
				return 1
			end
			local users = pmh_NameMatch(pmh_Array2String(cmd[2]))
			if(users == nil or users == {})
				et.trap_SendServerCommand( Admin,"cpm \"No Users matching the specified name".\"\n")
				return 1
			else
				for(i = 0; users[i]!=nil;i = i + 1 ) do
					LockSpecUser(users[i])					
				end
				return 1
			end
			return 1
		elseif(string.lower(cmd[1]) == "mute")
			if(tonumber(cmd[2])!=nil) then
				LockMuteUser(cmd[2])
				return 1
			end
			local users = pmh_NameMatch(pmh_Array2String(cmd[2]))
			if(users == nil or users == {})
				et.trap_SendServerCommand( Admin,"cpm \"No Users matching the specified name".\"\n")
				return 1
			else
				for(i = 0; users[i]!=nil;i = i + 1 ) do
					LockMuteUser(users[i])					
				end
				return 1
			end
			return 1		
		end
	--multiuse command, sub choices will depend on 2nd and sometimes 3rd entry
	--	all - removes all locks currently inplace.
	--	teams - unlocks teams, does not remove people locked into spec
	--	spec <pid> - unlocks the specified spec
	--	spec <name> - unlocks the specified spec
	--	specs - unlocks all spec locks currently on the server
	--	mute <pid> - unlocks a mute locked player
	--	mute <name> -unlocks a mute locked player
	--	mutes - unlocks all mute locks currently on the server
	elseif(string.lower(cmd[0]) == "unlock") then	
		if(string.lower(cmd[1]) == "all") then
		
		elseif(string.lower(cmd[1]) == "teams") then
		
		elseif(string.lower(cmd[1]) == "spec") then
		
		elseif(string.lower(cmd[1]) == "specs") then
		
		elseif(string.lower(cmd[1]) == "mute") then
		
		elseif(string.lower(cmd[1]) == "mutes") then
		end
	end
end

--Updated 28Dec08
function pm_UnlockTeams() 
	ETTeamsLock=-1
	ETLockTeams=false
end

--Updated 04Dec08
function pm_CommandAllowed(cmd, level) 
	local allowedcmds = et.trap_Cvar_Get("b_semiadmincmds" + level)
	if(string.find(allowedcmds,cmd)==nil) then
		return false
	end
	return true
end


--Updated 02Dec08
function pm_LoadPowerModCvars() 
	--Determines if semiadmins log in silently, if this 
	local Silent = tonumber(et.trap_Cvar_Get("p_Silent"))
	if(Silent != 1) then
		et.trap_Cvar_Set("p_Silent", 0)
		ETSilent = 0
	else
		ETSilent = 1
	end
	--sets' the number of semiadmin levels within the ETPowermod system
	local levels = tonumber(et.trap_Cvar_Get("b_semiadminlevels"))
	ETSALevels = levels
end

--Updated 01Dec08
function pm_LoadPowerUsers()
	local fd,len = et.trap_FS_FOpenFile( "PowerUserGUIDs.dat", et.FS_READ )
	if len == -1 then
		et.G_Print( "^1WARNING: ^3No PowerUserGUID's Defined! \n")
	else
		local filestr = et.trap_FS_Read( fd, len )
		--Use the pattern <GUID>@<Level>  
		--The Level should match the Semiadmin Level associated with the User
		--All auto logins should silently log admin in.
		for guid in string.gfind(filestr, "(%x+@%d)%s") do
			-- upcase for exact matches
			s,e,guid,level = string.find(guid,"(%x+)@(%d)")
			et.G_Print( "PowerUser GUID: " .. guid .. " Added. \n" )
			ETPowerUsers[guid] = {guid,tonumber(level)}
		end
	end
	et.trap_FS_FCloseFile( fd ) 
end

--updated 01Dec08
function pm_LoadPersistantMutes()
	local fd,len = et.trap_FS_FOpenFile( "pm_Mutes.dat", et.FS_READ )
	if len == -1 then
		return
	else
		local filestr = et.trap_FS_Read( fd, len )
		for guid in string.gfind(filestr, "(%x)%s") do
			guid = string.upper(guid)
			ETPowerMute[guid] = true
		end
	end
	et.trap_FS_FCloseFile( fd )
end

--updated 01Dec08
function pm_LoadPersistantSpecs()
	local fd,len = et.trap_FS_FOpenFile( "pm_Specs.dat", et.FS_READ )
	if len == -1 then
		return
	else
		local filestr = et.trap_FS_Read( fd, len )
		for guid in string.gfind(filestr, "(%x)%s") do
			guid = string.upper(guid)
			ETSpecLock[guid] = true
		end
	end
	et.trap_FS_FCloseFile( fd )
end

--updated 01Dec08
function pm_LoadPersistantKnives() 
	local fd,len = et.trap_FS_FOpenFile( "pm_Knives.dat", et.FS_READ )
	if len == -1 then
		return
	else
		local filestr = et.trap_FS_Read( fd, len )
		for guid in string.gfind(filestr, "(%x)%s") do
			guid = string.upper(guid)
			ETKnifeOnly[guid] = true
		end
	end
	et.trap_FS_FCloseFile( fd )
end

--updated 01Dec08
function pm_LoadRules() 
	local fd,len = et.trap_FS_FOpenFile( "rules.dat", et.FS_READ )
	if len> -1 then
		ETRules = et.trap_FS_Read( fd, len )
	else
		et.G_Print( "WARNING: No rules defined! \n" )
	end
	et.trap_FS_FCloseFile( fd )
end

--updated 02Dec08
function pm_GetAutoRank(clientNum)
	--gets rank from list of auto guid's and returns rank level
	--(-2) = normal player
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	guid = string.upper(guid)
	local rank = ETPowerUsers[guid]
	if rank == nil or rank<1 or rank>ETSALevels then
		return -2
	else 
		return rank
	end
end

--updated 09Dec08
function pm_AssignRank(clientNum,rank,Connect)
	--admin option for silent log in, either all silent or all public
	--if rank is null, don't sign in
	--if rank is not associated with level, will default to level 1
	--if rank is 0 rcon access is granted
	--if rank is -1 referee access is granted
	local name = et.Info_ValueForKey( et.trap_GetUserinfo( clientNum ), "name" )
	if(ETSilent != 1 and et.gentity_get(PlayerID, "sess.semiadmin") == 0 and rank == 0) then
		if(Connect == true) then
			Announce(1,"Admin " + name + " has joined the server" )
		else
			Announce(1,"Admin " + name + " has signed in.")
		end
	elseif(ETSilent != 1 and et.gentity_get(PlayerID, "sess.semiadmin") == 0 and rank == -1) then
		if(Connect == true) then
			Announce(1,"Referee " + name + " has joined the server" )
		else
			Announce(1,"Referee " + name + " has signed in.")
		end
	elseif(ETSilent != 1 and et.gentity_get(PlayerID, "sess.semiadmin") == 0) then
		if(Connect == true) then
			Announce(1,"Admin " + name + " has joined the server" )
		else
			Announce(1,"Admin " + name + " has signed in.")
		end
	end
	
	if(rank>0) then
		et.gentity_set(PlayerID,"sess.semiadmin",rank)
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Helper Functions--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function pmh_loadUserInfo(clientNum)
	--loads gathered info on user:
	--	Original Name / Time & Date Stamp
	--	Total Kills / Longest Kill Spree / Total Deaths / Total Suicides
	--	Total Team Damage / Total Enemy Damage
	--	Warning List(Date, Warning, Admin)
	--	IP Connection List
	--	
end

function pmh_writeUserInfo(clientNum)
	local filename = et.trap_Cvar_Get("p_AdminLogFile")
	local GUID = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
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

--updated 09Dec08
function pmh_NameMatch(Name)
	local pids = {}
	local maxPlayers = tonumber(pmh_readVar("sv_maxclients"))
	local matches = 0
	for(i=0;i<maxPlayers;i=i+1) do
		s,e,found = string.find(string.lower(et.Q_CleanStr( et.Info_ValueForKey( et.trap_GetUserinfo( i ), "name" ) )),string.lower(PlayerName)) 
		if(found!=nil)
			pids[matches] = i
			matches = matches + 1
		end
	end
	return pids
end

--Updated 06Dec08
function pmh_String2Array(String) 
	local returnme = {}
	local i = 0
	for word in string.gfind(String, "%S+") do
		returnme[i] = word
		i = + 1
	end
	return returnme
end

--Updated 06Dec08
function pmh_Array2String(Array,start)
	local returnme = ""
	
	for i = start, Array[i] != NULL, i = i+1 do
		returnme = returnme + " " + Array[i]
	end
end

function pmh_AddPowerUserGUID(guid,level)
	
end

--Updated 06Dec08
function pmh_readVar(varName)
	return et.trap_Cvar_Get(varName)
end

function pmh_MyRank(PlayerID) 

end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Commands--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Updated 07Dec08
function LockTeams(Time)
	ETTeamsLock=et.trap_Milliseconds()+Time*1000
	ETLockTeams=true
end



function Warn(clientNum,warnLevel)
	--Warn level 0 = Private message issueing warning
	--Warn level 1 = Private message issueing warning, system records warning
	--Warn level 2 = Global message issueing warning, system records warning
	--Warn level 3 = Global message issueing warning, locked spec for 3 min, system records warning, 
	--At set variable, kick will be issued, system records kick.
	
	
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

--Updated 28Dec08
function LockSpecUser(PlayerID)
	local guid = string.upper(et.Info_ValueForKey( userinfo, "cl_guid" ))
	PutSpec(PlayerID)
	et.trap_SendServerCommand( PlayerID,"cpm \"You have been locked into spec.\"\n")	
	ETSpecLock[guid] = true			
end

--Updated 28Dec08
function LockMuteUser(PlayerID)
	local userinfo = et.trap_GetUserinfo( PlayerID )
	local guid = string.upper(et.Info_ValueForKey( userinfo, "cl_guid" ))
	et.trap_SendConsoleCommand(et.EXEC_APPEND, "mute " .. "\"" .. PlayerName .. "\"" .. "\n" )
	et.trap_SendServerCommand( PlayerID,"cpm \"You have been muted by the admin.\"\n")
end


function AnnounceMe(PlayerID)
	if(PlayerID~=-1) then
		MyString = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ) .. " ^7has logged in as admin"
	else
		MyString = "The Admin is watching the console."
	end
	Announce(2,MyString)
end



function CancelVote()
	et.trap_SendConsoleCommand( et.EXEC_APPEND, "cancelvote\n" )
end

function CantVote(PlayerID)
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

function CanVote(PlayerID) 
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

function FakeRCONPowerUser(Command) 
	et.trap_SendConsoleCommand( et.EXEC_APPEND, Command .. "\n" )
end

function KickUser( PlayerID, Time )
	local PlayerName = et.Q_CleanStr( et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" ) )
	et.trap_DropClient( PlayerID, "Admin Decision", Time )
end

function KillUser(PlayerID)
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

function pm_GetPowerUserLevel(PlayerID)
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



function pm_PlaySound( entNum , Sound)
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


function pm_PlaySoundGlobal(Sound)
	et.G_globalSound(Sound)
end

function pm_BalanceCheck()
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

function pm_CheckMute(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETPowerMute[ip] ~= nil or ETPowerMute[guid] ~= nil
	end
	return false
end

function pm_CheckSpecLock(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETSpecLock[ip] or ETSpecLock[guid] 
	end
end

function pm_CheckVote(PlayerID)
	local ip = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "ip" )
	local guid = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "cl_guid" )
	if(ip~=nil) then
		s,e,ip = string.find(ip,"(%d+%.%d+%.%d+%.%d+)")
		return ETCantVote[ip] ~= nil or ETCantVote[guid] ~= nil
	end
	return false
end

function pm_GlobalActionCPM(PlayerID,Action) 
	if(PlayerID~=-1) then
		local Name = et.Info_ValueForKey( et.trap_GetUserinfo( PlayerID ), "name" )
		et.trap_SendServerCommand( -1,"cp \"" .. Name .. " ^7has been " .. Action .. " by the admin.\"\n")
	else
		et.trap_SendServerCommand( -1,"cp \"The admin has done a " .. Action .. ".\"\n")
	end
	PlaySound("-1","/sound/ETPower/energy.wav")
end

function pm_IRCAs(Name, Text)
	et.trap_SendServerCommand( -1,"cpm \"^3IRC - ^1" .. Name .. "^2: " .. Text .. "^7\"\n")
end

function pm_IsPlayer(checkNum)
	local SlotNum = tonumber(checkNum)
	if(SlotNum==nil) then
		return false
	elseif(SlotNum>tonumber(et.trap_Cvar_Get("sv_maxclients"))) then
		return false
	end
	return et.gentity_get (SlotNum,"inuse")
end

function pm_LoadMutes()
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

function pm_LoadNameProtection()
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

function pm_LogAdminUse(pid, command)
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

function pm_ParseString(inputString)
	local i = 1
	local t = {}
	for w in string.gfind(inputString, "([^%s]+)%s*") do
		t[i]=w
		i=i+1
	end
	return t
 end
 
 function pm_ReadIAC(text)
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

function pistolOnly(clientNum)
	
end

function pm_LoadRules() 
	local fd,len = et.trap_FS_FOpenFile( "rules.dat", et.FS_READ )
	if len> -1 then
		ETRules = et.trap_FS_Read( fd, len )
		local icount=0
	else
		et.G_Print( "WARNING: No rules defined! \n" )
	end
	et.trap_FS_FCloseFile( fd )
end

function disp_ModInfo(clientNum)
	et.trap_SendServerCommand( clientNum,"cpm \"This server is using ETPowerMod version " .. ETPowerModVersion .. ".\n\"")
	et.trap_SendServerCommand( clientNum,"cpm \"Created by Grendel, aka G073nks.\n\"")
	et.trap_SendServerCommand( clientNum,"cpm \"For more information go to http://etpower.no-ip.org\n\"")
	et.trap_SendServerCommand( clientNum,"cpm \"Or on IRC at irc.freenode.org/#ETPower\n\"")
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



