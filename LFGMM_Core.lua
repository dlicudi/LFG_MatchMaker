--[[
	LFG MatchMaker - Addon for World of Warcraft.
	Version: 1.1.4
	URL: https://github.com/AvilanHauxen/LFG_MatchMaker
	Copyright (C) 2019-2020 L.I.R.

	This file is part of 'LFG MatchMaker' addon for World of Warcraft.

    'LFG MatchMaker' is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    'LFG MatchMaker' is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with 'LFG MatchMaker'. If not, see <https://www.gnu.org/licenses/>.
]]--


------------------------------------------------------------------------------------------------------------------------
-- CORE
------------------------------------------------------------------------------------------------------------------------

-- Performance optimization: Pre-compiled pattern caches
local LFGMM_Core_AccentReplacementMap = {
	["á"] = "a", ["à"] = "a", ["ä"] = "a", ["â"] = "a", ["ã"] = "a",
	["é"] = "e", ["è"] = "e", ["ë"] = "e", ["ê"] = "e",
	["í"] = "i", ["ì"] = "i", ["ï"] = "i", ["î"] = "i",
	["ñ"] = "n",
	["ó"] = "o", ["ò"] = "o", ["ö"] = "o", ["ô"] = "o", ["õ"] = "o",
	["ú"] = "u", ["ù"] = "u", ["ü"] = "u", ["û"] = "u",
	["ß"] = "ss", ["œ"] = "oe", ["ç"] = "c"
}

-- Optimized accent removal function
local function LFGMM_Core_RemoveAccents(text)
	return text:gsub("[áàäâãéèëêíìïîñóòöôõúùüûßœç]", LFGMM_Core_AccentReplacementMap)
end

-- Dungeon pattern cache - will be populated at startup
local LFGMM_Core_DungeonPatternCache = {}
local LFGMM_Core_DungeonLookupCache = {}
local LFGMM_Core_FallbackPatternCache = {}

-- Function to compile dungeon patterns for better performance
local function LFGMM_Core_CompileDungeonPatterns()
	LFGMM_Core_DungeonPatternCache = {}
	LFGMM_Core_DungeonLookupCache = {}
	LFGMM_Core_FallbackPatternCache = {}
	
	-- Get enabled languages from settings, fallback to English if not initialized
	local enabledLanguages = LFGMM_DB and LFGMM_DB.SETTINGS and LFGMM_DB.SETTINGS.IdentifierLanguages or {"EN"}
	
	-- Compile main dungeon patterns
	for _, dungeon in ipairs(LFGMM_GLOBAL.DUNGEONS) do
		local patterns = {}
		local notPatterns = {}
		
		for _, languageCode in ipairs(enabledLanguages) do
			if dungeon.Identifiers[languageCode] then
				for _, identifier in ipairs(dungeon.Identifiers[languageCode]) do
					table.insert(patterns, {
						start = "^" .. identifier .. "[%W]+",
						exact = "^" .. identifier .. "$",
						middle = "[%W]+" .. identifier .. "[%W]+",
						end_ = "[%W]+" .. identifier .. "$"
					})
				end
			end
			
			if dungeon.NotIdentifiers and dungeon.NotIdentifiers[languageCode] then
				for _, notIdentifier in ipairs(dungeon.NotIdentifiers[languageCode]) do
					table.insert(notPatterns, {
						start = "^" .. notIdentifier .. "[%W]+",
						exact = "^" .. notIdentifier .. "$",
						middle = "[%W]+" .. notIdentifier .. "[%W]+",
						end_ = "[%W]+" .. notIdentifier .. "$"
					})
				end
			end
		end
		
		LFGMM_Core_DungeonPatternCache[dungeon.Index] = {
			patterns = patterns,
			notPatterns = notPatterns,
			dungeon = dungeon
		}
	end
	
	-- Compile fallback patterns
	for _, dungeonsFallback in ipairs(LFGMM_GLOBAL.DUNGEONS_FALLBACK) do
		local patterns = {}
		
		for _, languageCode in ipairs(enabledLanguages) do
			if dungeonsFallback.Identifiers[languageCode] then
				for _, identifier in ipairs(dungeonsFallback.Identifiers[languageCode]) do
					table.insert(patterns, {
						start = "^" .. identifier .. "[%W]+",
						exact = "^" .. identifier .. "$",
						middle = "[%W]+" .. identifier .. "[%W]+",
						end_ = "[%W]+" .. identifier .. "$"
					})
				end
			end
		end
		
		table.insert(LFGMM_Core_FallbackPatternCache, {
			patterns = patterns,
			dungeonsFallback = dungeonsFallback
		})
	end
end

-- Optimized dungeon matching function
local function LFGMM_Core_FindDungeonMatches(message, enabledLanguages)
	local uniqueDungeonMatches = LFGMM_Utility_CreateUniqueDungeonsList()
	
	-- Check main dungeons
	for dungeonIndex, cache in pairs(LFGMM_Core_DungeonPatternCache) do
		local matched = false
		
		-- Check positive patterns
		for _, pattern in ipairs(cache.patterns) do
			if string.find(message, pattern.start) or
			   string.find(message, pattern.exact) or
			   string.find(message, pattern.middle) or
			   string.find(message, pattern.end_) then
				matched = true
				break
			end
		end
		
		-- Check negative patterns (NotIdentifiers)
		if matched and #cache.notPatterns > 0 then
			for _, notPattern in ipairs(cache.notPatterns) do
				if string.find(message, notPattern.start) or
				   string.find(message, notPattern.exact) or
				   string.find(message, notPattern.middle) or
				   string.find(message, notPattern.end_) then
					matched = false
					break
				end
			end
		end
		
		if matched then
			uniqueDungeonMatches:Add(cache.dungeon)
			
			if cache.dungeon.ParentDungeon then
				uniqueDungeonMatches:Add(LFGMM_GLOBAL.DUNGEONS[cache.dungeon.ParentDungeon])
			end
		end
	end
	
	-- Check fallback patterns
	for _, fallbackCache in ipairs(LFGMM_Core_FallbackPatternCache) do
		local matched = false
		
		for _, pattern in ipairs(fallbackCache.patterns) do
			if string.find(message, pattern.start) or
			   string.find(message, pattern.exact) or
			   string.find(message, pattern.middle) or
			   string.find(message, pattern.end_) then
				matched = true
				break
			end
		end
		
		if matched then
			local singleInFallbackMatched = false
			
			for _, dungeonIndex in ipairs(fallbackCache.dungeonsFallback.Dungeons) do
				if uniqueDungeonMatches.List[dungeonIndex] then
					singleInFallbackMatched = true
					break
				end
			end
			
			if not singleInFallbackMatched then
				for _, dungeonIndex in ipairs(fallbackCache.dungeonsFallback.Dungeons) do
					local dungeon = LFGMM_GLOBAL.DUNGEONS[dungeonIndex]
					uniqueDungeonMatches:Add(dungeon)
					
					if dungeon.ParentDungeon then
						uniqueDungeonMatches:Add(LFGMM_GLOBAL.DUNGEONS[dungeon.ParentDungeon])
					end
				end
			end
		end
	end
	
	return uniqueDungeonMatches
end

-- Public function to recompile patterns when settings change
function LFGMM_Core_RecompileDungeonPatterns()
	LFGMM_Core_CompileDungeonPatterns()
end


-- Safe function to get player class with fallback
function LFGMM_Core_GetSafePlayerClass()
	return LFGMM_GLOBAL.PLAYER_CLASS or LFGMM_GLOBAL.CLASSES["WARRIOR"]
end

-- Function to determine message type (LFG/LFM/UNKNOWN)
local function LFGMM_Core_GetPlayerSearchType(message, isGeneralOrTrade)
	local typeMatch = nil
	
	-- Search for type identifiers in enabled languages
	for _, languageCode in ipairs(LFGMM_DB.SETTINGS.IdentifierLanguages) do
		if LFGMM_GLOBAL.MESSAGETYPE_IDENTIFIERS[languageCode] then
			for _, identifierCollection in ipairs(LFGMM_GLOBAL.MESSAGETYPE_IDENTIFIERS[languageCode]) do
				for _, identifier in ipairs(identifierCollection.Identifiers) do
					if string.find(message, identifier) then
						typeMatch = identifierCollection.Type
						break
					end
				end
				if typeMatch then break end
			end
		end
		if typeMatch then break end
	end
	
	-- If no direct match found, try to infer from context
	if not typeMatch then
		typeMatch = "UNKNOWN"
		
		-- Check for boost-related patterns
		if string.find(message, "wts.-boost") then
			typeMatch = "LFM"
		elseif string.find(message, "wtb.-boost") then
			typeMatch = "LFG"
		elseif string.find(message, "heal[i]?[n]?[g]?[%W]*service[s]?") or 
			   string.find(message, "tank[i]?[n]?[g]?[%W]*service[s]?") then
			typeMatch = "LFG"
		end
	end
	
	return typeMatch
end


function LFGMM_Core_Initialize()
	tinsert(UISpecialFrames, "LFGMM_MainWindow");
	
	-- Compile dungeon patterns for performance optimization
	LFGMM_Core_CompileDungeonPatterns();
	
	LFGMM_LfgTab_Initialize();
	LFGMM_LfmTab_Initialize();
	LFGMM_ListTab_Initialize();
	LFGMM_SettingsTab_Initialize();
	LFGMM_PopupWindow_Initialize();
	LFGMM_MinimapButton_Initialize();
	LFGMM_BroadcastWindow_Initialize();
	
	LFGMM_Core_SetInfoWindowLocations();

	if (LFGMM_DB.SETTINGS.ShowQuestLogButton) then
		LFGMM_QuestLog_Button_Frame:Show();
	end

	LFGMM_MainWindow:RegisterForDrag("LeftButton");
	LFGMM_MainWindow:SetScript("OnDragStart", LFGMM_MainWindow.StartMoving);
	LFGMM_MainWindow:SetScript("OnDragStop", LFGMM_MainWindow.StopMovingOrSizing);
	LFGMM_MainWindow:SetScript("OnShow", function() PlaySound(839); LFGMM_Core_Refresh(); end);
	LFGMM_MainWindow:SetScript("OnHide", function() PlaySound(840); end);
	
	LFGMM_MainWindowTab1:SetScript("OnClick", function() PlaySound(841); LFGMM_LfgTab_Show(); end);
	LFGMM_MainWindowTab2:SetScript("OnClick", function() PlaySound(841); LFGMM_LfmTab_Show(); end);
	LFGMM_MainWindowTab3:SetScript("OnClick", function() PlaySound(841); LFGMM_ListTab_Show(); end);
	LFGMM_MainWindowTab4:SetScript("OnClick", function() PlaySound(841); LFGMM_SettingsTab_Show(); end);
	
	PanelTemplates_SetNumTabs(LFGMM_MainWindow, 4);
	
	local groupSize = #LFGMM_GLOBAL.GROUP_MEMBERS;
	if (groupSize > 1) then
		LFGMM_LfmTab_Show();
	else
		LFGMM_LfgTab_Show();
	end
	
	LFGMM_GLOBAL.READY = true;

	print("|cff00ff00LFG MatchMaker Continued|r |cffaaaaaa(v1.2.1)|r by |cffff8040Dubhan-PyrewoodVillage|r loaded. Type |cffffff00/lfgmm|r for options.")
end


function LFGMM_Core_Refresh()
	LFGMM_LfgTab_Refresh();
	LFGMM_LfmTab_Refresh();
	LFGMM_ListTab_Refresh();
end


function LFGMM_Core_MainWindow_ToggleShow()
	if (LFGMM_MainWindow:IsVisible()) then
		LFGMM_LfgTab_BroadcastMessageInfoWindow:Hide();
		LFGMM_LfmTab_BroadcastMessageInfoWindow:Hide();
		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:Hide();
		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:Hide();
		LFGMM_ListTab_MessageInfoWindow_Hide();
		LFGMM_ListTab_ConfirmForgetAll:Hide();
		LFGMM_MainWindow:Hide();
	else
		LFGMM_LfgTab_BroadcastMessageInfoWindow:Hide();
		LFGMM_LfmTab_BroadcastMessageInfoWindow:Hide();
		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:Hide();
		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:Hide();
		LFGMM_ListTab_MessageInfoWindow_Hide();
		LFGMM_ListTab_ConfirmForgetAll:Hide();
		LFGMM_MainWindow:Show(); 
		LFGMM_Core_Refresh();
		LFGMM_Core_SetGuiEnabled(true);
	end
end


function LFGMM_Core_SetGuiEnabled(enabled)
	if (enabled) then
		LFGMM_DisableMainWindowOverlay:Hide();
		LFGMM_MainWindowTab1:Enable();
		LFGMM_MainWindowTab2:Enable();
		LFGMM_MainWindowTab3:Enable();
		LFGMM_MainWindowTab4:Enable();
	else
		LFGMM_DisableMainWindowOverlay:Show();
		LFGMM_MainWindowTab1:Disable();
		LFGMM_MainWindowTab2:Disable();
		LFGMM_MainWindowTab3:Disable();
		LFGMM_MainWindowTab4:Disable();
	end
end


function LFGMM_Core_SetInfoWindowLocations()
	if (LFGMM_DB.SETTINGS.InfoWindowLocation == "right") then
		LFGMM_SettingsTab_InfoWindowLocationButton:SetText("right >");

		LFGMM_LfgTab_BroadcastMessageInfoWindow:ClearAllPoints();
		LFGMM_LfgTab_BroadcastMessageInfoWindow:SetPoint("BOTTOMLEFT", "LFGMM_MainWindow", "BOTTOMRIGHT", 10, -2);

		LFGMM_LfmTab_BroadcastMessageInfoWindow:ClearAllPoints();
		LFGMM_LfmTab_BroadcastMessageInfoWindow:SetPoint("BOTTOMLEFT", "LFGMM_MainWindow", "BOTTOMRIGHT", 10, -2);

		LFGMM_ListTab_MessageInfoWindow:ClearAllPoints();
		LFGMM_ListTab_MessageInfoWindow:SetPoint("BOTTOMLEFT", "LFGMM_MainWindow", "BOTTOMRIGHT", 10, -2);

		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:ClearAllPoints();
		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:SetPoint("BOTTOMLEFT", "LFGMM_MainWindow", "BOTTOMRIGHT", 10, -2);

		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:ClearAllPoints();
		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:SetPoint("BOTTOMLEFT", "LFGMM_MainWindow", "BOTTOMRIGHT", 10, -2);
	else
		LFGMM_SettingsTab_InfoWindowLocationButton:SetText("< left");

		LFGMM_LfgTab_BroadcastMessageInfoWindow:ClearAllPoints();
		LFGMM_LfgTab_BroadcastMessageInfoWindow:SetPoint("BOTTOMRIGHT", "LFGMM_MainWindow", "BOTTOMLEFT", -10, -2);

		LFGMM_LfmTab_BroadcastMessageInfoWindow:ClearAllPoints();
		LFGMM_LfmTab_BroadcastMessageInfoWindow:SetPoint("BOTTOMRIGHT", "LFGMM_MainWindow", "BOTTOMLEFT", -10, -2);

		LFGMM_ListTab_MessageInfoWindow:ClearAllPoints();
		LFGMM_ListTab_MessageInfoWindow:SetPoint("BOTTOMRIGHT", "LFGMM_MainWindow", "BOTTOMLEFT", -10, -2);

		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:ClearAllPoints();
		LFGMM_SettingsTab_RequestInviteMessageInfoWindow:SetPoint("BOTTOMRIGHT", "LFGMM_MainWindow", "BOTTOMLEFT", -10, -2);

		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:ClearAllPoints();
		LFGMM_SettingsTab_ChannelsDropDownInfoWindow:SetPoint("BOTTOMRIGHT", "LFGMM_MainWindow", "BOTTOMLEFT", -10, -2);
	end
end


function LFGMM_Core_StartWhoCooldown()
	if (LFGMM_GLOBAL.WHO_COOLDOWN <= 0) then
		LFGMM_GLOBAL.WHO_COOLDOWN = 5;
		C_Timer.After(1, LFGMM_Core_WhoCooldown);
	end
end


function LFGMM_Core_WhoCooldown()
	LFGMM_GLOBAL.WHO_COOLDOWN = LFGMM_GLOBAL.WHO_COOLDOWN - 1;

	LFGMM_ListTab_MessageInfoWindow_Refresh();
	LFGMM_PopupWindow_Refresh();
	
	if (LFGMM_GLOBAL.WHO_COOLDOWN > 0) then
		C_Timer.After(1, LFGMM_Core_WhoCooldown);
	end
end


function LFGMM_Core_WhoRequest(message)
	-- Send who request
	C_FriendList.SendWho("n-\"" .. message.Player .. "\"");

	-- Start cooldown
	LFGMM_Core_StartWhoCooldown();
end


function LFGMM_Core_Ignore(message)
	-- Ignore message for current type
	message.Ignore[message.Type] = true;
end


function LFGMM_Core_Invite(message)
	-- Invite player
	InviteUnit(message.Player);
	
	-- Mark as contacted
	message.Invited = true;
end


function LFGMM_Core_RequestInvite(message)
	-- Send request
	local whisper = LFGMM_DB.SETTINGS.RequestInviteMessage;
	SendChatMessage(whisper, "WHISPER", nil, message.Player);

	-- Mark as contacted
	message.InviteRequested = true;
end


function LFGMM_Core_OpenWhisper(message)
	ChatFrame_SendTell(message.Player, DEFAULT_CHAT_FRAME);
end


function LFGMM_Core_RemoveUnavailableDungeonsFromSelections()
	local removeSelections = {};
	for _,dungeon in ipairs(LFGMM_Utility_GetAllUnavailableDungeonsAndRaids()) do
		table.insert(removeSelections, dungeon.Index);
		
		if (not LFGMM_DB.SEARCH.LFM.Running and LFGMM_DB.SEARCH.LFM.Dungeon == dungeon.Index) then
			LFGMM_DB.SEARCH.LFM.Dungeon = nil;
		end
	end

	LFGMM_Utility_ArrayRemove(LFGMM_DB.LIST.Dungeons, removeSelections);

	if (not LFGMM_DB.SEARCH.LFG.Running) then
		LFGMM_Utility_ArrayRemove(LFGMM_DB.SEARCH.LFG.Dungeons, removeSelections);
	end
	
	LFGMM_LfgTab_DungeonsDropDown_UpdateText();
	LFGMM_LfgTab_UpdateBroadcastMessage();
	
	LFGMM_LfmTab_DungeonDropDown_UpdateText();
	LFGMM_LfmTab_UpdateBroadcastMessage();

	LFGMM_ListTab_DungeonsDropDown_UpdateText();
end


function LFGMM_Core_GetGroupMembers()
	local groupMembers = {};
	
	-- Raid
	for index=1, 40 do
		local playerName = UnitName("raid" .. index);
		if (playerName ~= nil) then
			table.insert(groupMembers, playerName);
		end
	end

	-- Party
	if (#groupMembers == 0) then
		local player = UnitName("player");
		table.insert(groupMembers, player);

		for index=1, 4 do
			local playerName = UnitName("party" .. index);
			if (playerName ~= nil) then
				table.insert(groupMembers, playerName);
			end
		end
	end

	-- Store group members
	LFGMM_GLOBAL.GROUP_MEMBERS = groupMembers;
end


function LFGMM_Core_FindSearchMatch()
	-- Return if stopped
	if (not LFGMM_DB.SEARCH.LFG.Running and not LFGMM_DB.SEARCH.LFM.Running) then
		return;
	end

	-- Return if match popup window is open
	if (LFGMM_PopupWindow:IsVisible()) then
		return;
	end

	-- Ensure lock
	if (LFGMM_GLOBAL.SEARCH_LOCK) then
		return;
	end

	-- Lock
	LFGMM_GLOBAL.SEARCH_LOCK = true;

	-- Determine dungeons to search for
	local searchDungeonIndexes = {};
	if (LFGMM_DB.SEARCH.LFG.Running) then
		searchDungeonIndexes = LFGMM_DB.SEARCH.LFG.Dungeons;
	elseif (LFGMM_DB.SEARCH.LFM.Running) then
		searchDungeonIndexes = { LFGMM_DB.SEARCH.LFM.Dungeon };
	end
	
	-- Get max message age
	local maxMessageAge = time() - (60 * LFGMM_DB.SETTINGS.MaxMessageAge);

	-- Look for messages matching search criteria and show popup
	for _,message in pairs(LFGMM_GLOBAL.MESSAGES) do
		local skip = false;

		-- Skip ignored
		if (message.Ignore[message.Type] ~= nil) then
			skip = true;
			
		-- Skip old
		elseif (message.Timestamp < maxMessageAge) then
			skip = true;

		-- Skip contacted
		elseif (message.Type == "LFG" and message.Invited) then
			skip = true;

		elseif (message.Type == "LFM" and message.InviteRequested) then
			skip = true;

		elseif (message.Type == "UNKNOWN" and (message.Invited or message.InviteRequested)) then
			skip = true;

		-- Skip LFG and/or UNKNOWN match for LFG search
		elseif (LFGMM_DB.SEARCH.LFG.Running) then
			if (message.Type == "LFG" and not LFGMM_DB.SEARCH.LFG.MatchLfg) then
				skip = true;
			elseif (message.Type == "UNKNOWN" and not LFGMM_DB.SEARCH.LFG.MatchUnknown) then
				skip = true;
			end					

		-- Skip LFM and/or UNKNOWN match for LFM search
		elseif (LFGMM_DB.SEARCH.LFM.Running) then
			if (message.Type == "LFM" and not LFGMM_DB.SEARCH.LFM.MatchLfm) then
				skip = true;
			elseif (message.Type == "UNKNOWN" and not LFGMM_DB.SEARCH.LFM.MatchUnknown) then
				skip = true;
			end
			
		-- Skip messages from group members
		elseif (LFGMM_Utility_ArrayContains(LFGMM_GLOBAL.GROUP_MEMBERS, message.Player)) then
			skip = true;
		end
		
		-- Find dungeon match
		if (not skip) then
			for _,searchDungeonIndex in ipairs(searchDungeonIndexes) do
				for _,dungeonIndex in ipairs(message.Dungeons) do
					if (dungeonIndex == searchDungeonIndex) then
						LFGMM_PopupWindow_ShowForMatch(message);
						return;
					end
				end
			end
		end
	end

	-- Release lock if popup window has not been shown
	if (not LFGMM_PopupWindow:IsVisible()) then
		LFGMM_GLOBAL.SEARCH_LOCK = false;
	end
end


function LFGMM_Core_JoinChannels()
	LFGMM_GLOBAL.LFG_CHANNEL_NAME = LFGMM_Utility_GetLfgChannelName();
	JoinTemporaryChannel(LFGMM_GLOBAL.LFG_CHANNEL_NAME);
	
	LFGMM_GLOBAL.GENERAL_CHANNEL_NAME = LFGMM_Utility_GetGeneralChannelName();
	if (LFGMM_DB.SETTINGS.UseGeneralChannel) then
		JoinTemporaryChannel(LFGMM_GLOBAL.GENERAL_CHANNEL_NAME);
	end

	LFGMM_GLOBAL.TRADE_CHANNEL_NAME, LFGMM_GLOBAL.TRADE_CHANNEL_AVAILABLE = LFGMM_Utility_GetTradeChannelName();
	if (LFGMM_DB.SETTINGS.UseTradeChannel and LFGMM_GLOBAL.TRADE_CHANNEL_AVAILABLE) then
		JoinTemporaryChannel(LFGMM_GLOBAL.TRADE_CHANNEL_NAME);
	end
	
	LFGMM_SettingsTab_ChannelsDropDown_UpdateText();
end


------------------------------------------------------------------------------------------------------------------------
-- EVENT HANDLER
------------------------------------------------------------------------------------------------------------------------

-- Modular event handlers for better maintainability

-- Handle player entering world event
local function LFGMM_Core_HandlePlayerEnteringWorld()
	-- Get player info
	LFGMM_GLOBAL.PLAYER_NAME = UnitName("player")
	LFGMM_GLOBAL.PLAYER_LEVEL = UnitLevel("player")
	local localizedClass, englishClass = UnitClass("player")
	LFGMM_GLOBAL.PLAYER_CLASS = LFGMM_GLOBAL.CLASSES[englishClass]

	-- Get group members
	LFGMM_Core_GetGroupMembers()

	-- Load
	LFGMM_Load()
	LFGMM_Core_Initialize()

	-- Join channels
	C_Timer.After(5, function()
		LFGMM_Core_JoinChannels()
	end)
end

-- Handle zone change event
local function LFGMM_Core_HandleZoneChanged()
	C_Timer.After(5, function()
		LFGMM_Core_JoinChannels()
	end)
end

-- Handle player level up event
local function LFGMM_Core_HandlePlayerLevelUp(newLevel)
	LFGMM_GLOBAL.PLAYER_LEVEL = newLevel
	LFGMM_Core_GetGroupMembers()
	LFGMM_Core_Refresh()
end

-- Handle party invite request event
local function LFGMM_Core_HandlePartyInviteRequest(player)
	if LFGMM_DB.SETTINGS.ShowInvitePopup then
		LFGMM_PopupWindow_ShowInviteReceived(player)
	end
end

-- Handle chat system messages
local function LFGMM_Core_HandleChatSystemMessage(message)
	-- Check for player level in /who response
	local match = string.match(message, "^|Hplayer:([^|]+)|h%[([^%]]+)%]|h.+Level (%d+).+")
	if match then
		local playerName = match
		local playerLevel = tonumber(select(3, string.match(message, "^|Hplayer:([^|]+)|h%[([^%]]+)%]|h.+Level (%d+).+")))
		
		if LFGMM_GLOBAL.MESSAGES[playerName] then
			LFGMM_GLOBAL.MESSAGES[playerName].PlayerLevel = playerLevel
			LFGMM_ListTab_Refresh()
			LFGMM_ListTab_MessageInfoWindow_Refresh()
			LFGMM_PopupWindow_Refresh()
		end
	end
end

-- Handle group roster updates
local function LFGMM_Core_HandleGroupRosterUpdate()
	LFGMM_Core_GetGroupMembers()
	
	-- Stop LFG search when group is formed
	if LFGMM_DB.SEARCH.LFG.Running and #LFGMM_GLOBAL.GROUP_MEMBERS > 1 then
		LFGMM_DB.SEARCH.LFG.Running = false
		LFGMM_Core_Refresh()
	end
	
	-- Stop LFM search when group reaches dungeon capacity
	if LFGMM_DB.SEARCH.LFM.Running and LFGMM_DB.SEARCH.LFM.Dungeon then
		local dungeon = LFGMM_GLOBAL.DUNGEONS[LFGMM_DB.SEARCH.LFM.Dungeon]
		local maxGroupSize = 5 -- Default for most dungeons
		
		if dungeon and dungeon.MaxGroupSize then
			maxGroupSize = dungeon.MaxGroupSize
		end
		
		if #LFGMM_GLOBAL.GROUP_MEMBERS >= maxGroupSize then
			LFGMM_DB.SEARCH.LFM.Running = false
			LFGMM_Core_Refresh()
		end
	end
	
	LFGMM_LfgTab_Refresh()
	LFGMM_LfmTab_Refresh()
	LFGMM_PopupWindow_Refresh()
end

-- Handle chat channel messages (LFG parsing)
local function LFGMM_Core_HandleChatChannelMessage(message, player, playerGuid, channelName)
	local isGeneralChannel = string.find(channelName, "^" .. LFGMM_GLOBAL.GENERAL_CHANNEL_NAME)
	local isTradeChannel = string.find(channelName, "^" .. LFGMM_GLOBAL.TRADE_CHANNEL_NAME)

	if channelName == LFGMM_GLOBAL.LFG_CHANNEL_NAME or
		(isGeneralChannel and LFGMM_DB.SETTINGS.UseGeneralChannel) or
		(isTradeChannel and LFGMM_DB.SETTINGS.UseTradeChannel) then
		
		local now = time()
		local messageOrg = message
		message = string.lower(message)

		-- Ignore own messages
		if player == LFGMM_GLOBAL.PLAYER_NAME then
			return
		end
		
		-- Replace special characters in message (optimized)
		message = LFGMM_Core_RemoveAccents(message)

		-- Remove item links to prevent false positive matches from item names
		message = string.gsub(message, "%phitem[%d:]+%ph%[.-%]", "")

		-- Remove "/w me" and "/w inv" from message before parsing
		for _, languageCode in ipairs(LFGMM_DB.SETTINGS.IdentifierLanguages) do
			if languageCode == "EN" then
				message = string.gsub(message, "/w[%W]+me", " ")
				message = string.gsub(message, "/w[%W]+inv", " ")
			elseif languageCode == "DE" then
				message = string.gsub(message, "/w[%W]+mir", " ")
				message = string.gsub(message, "/w[%W]+bei", " ")
			elseif languageCode == "FR" then
				message = string.gsub(message, "/w[%W]+moi", " ")
				message = string.gsub(message, "/w[%W]+pour", " ")
				message = string.gsub(message, "[%W]+w/moi", " ")
				message = string.gsub(message, "[%W]+w/pour", " ")
			elseif languageCode == "ES" then
				message = string.gsub(message, "/w[%W]+yo", " ")
			end
		end

		-- Use optimized dungeon matching function
		local uniqueDungeonMatches = LFGMM_Core_FindDungeonMatches(message, LFGMM_DB.SETTINGS.IdentifierLanguages)

		-- Handle DM ambiguity (Deadmines vs Dire Maul)
		if uniqueDungeonMatches.List[3] and uniqueDungeonMatches.List[39] and
			not uniqueDungeonMatches.List[40] and not uniqueDungeonMatches.List[41] and
			not uniqueDungeonMatches.List[42] and not uniqueDungeonMatches.List[43] then
			
			for _, dungeon in ipairs(uniqueDungeonMatches:GetDungeonList()) do
				if dungeon.Index ~= 3 and dungeon.MinLevel <= 30 then
					uniqueDungeonMatches:Remove(LFGMM_GLOBAL.DUNGEONS[39])
					break
				end
				if dungeon.Index ~= 39 and dungeon.MinLevel >= 50 then
					uniqueDungeonMatches:Remove(LFGMM_GLOBAL.DUNGEONS[3])
					break
				end
			end
		end
		
		-- Check for "Any dungeon" match
		local isAnyDungeonMatch = LFGMM_Utility_ArrayContainsAll(uniqueDungeonMatches:GetIndexList(), LFGMM_GLOBAL.DUNGEONS_FALLBACK[4].Dungeons)
		
		-- Determine message type (LFG/LFM)
		local typeMatch = LFGMM_Core_GetPlayerSearchType(message, isGeneralChannel or isTradeChannel)
		local dungeonMatches = uniqueDungeonMatches:GetIndexList()
		
		-- Only process messages with clear type/dungeon match for General/Trade channels
		if (isGeneralChannel or isTradeChannel) and (typeMatch == "UNKNOWN" or #dungeonMatches == 0) then
			return
		end
		
		-- Handle message storage and updates
		local savedMessage = LFGMM_GLOBAL.MESSAGES[player]
		local messageSortIndex = LFGMM_GLOBAL.MESSAGE_SORT_INDEX
		LFGMM_GLOBAL.MESSAGE_SORT_INDEX = LFGMM_GLOBAL.MESSAGE_SORT_INDEX + 1
		
		if savedMessage then
			-- Only update if new message has dungeon matches or saved message doesn't
			if #dungeonMatches > 0 or #savedMessage.Dungeons == 0 then
				savedMessage.Timestamp = now
				savedMessage.Type = typeMatch
				savedMessage.Message = messageOrg
				savedMessage.Dungeons = dungeonMatches
				savedMessage.SortIndex = messageSortIndex
			end
		else
			-- Add new message
			local localizedClass, classFile = GetPlayerInfoByGUID(playerGuid)
			local newMessage = {
				Player = player,
				PlayerClass = LFGMM_GLOBAL.CLASSES[classFile],
				PlayerLevel = nil,
				Timestamp = now,
				Type = typeMatch,
				Message = messageOrg,
				Dungeons = dungeonMatches,
				Ignore = {},
				Invited = false,
				InviteRequested = false,
				SortIndex = messageSortIndex
			}
			LFGMM_GLOBAL.MESSAGES[player] = newMessage
		end
		
		-- Clean up old messages (over 30 minutes)
		local maxAge = now - (60 * 30)
		for playerName, playerMessage in pairs(LFGMM_GLOBAL.MESSAGES) do
			if playerMessage.Timestamp < maxAge then
				LFGMM_GLOBAL.MESSAGES[playerName] = nil
			end
		end
		
		-- Search for match
		if LFGMM_DB.SEARCH.LFG.Running or LFGMM_DB.SEARCH.LFM.Running then
			LFGMM_Core_FindSearchMatch()
		end
	
		-- Refresh UI
		LFGMM_ListTab_Refresh()
		LFGMM_ListTab_MessageInfoWindow_Refresh()
		LFGMM_PopupWindow_Refresh()
	end
end

-- Main event handler dispatcher
function LFGMM_Core_EventHandler(self, event, ...)
	-- Initialize
	if not LFGMM_GLOBAL.READY and event == "PLAYER_ENTERING_WORLD" then
		LFGMM_Core_HandlePlayerEnteringWorld()
		
	-- Return if not ready
	elseif not LFGMM_GLOBAL.READY then
		return
	
	-- Dispatch to appropriate handler
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		LFGMM_Core_HandleZoneChanged()
	
	elseif event == "PLAYER_LEVEL_UP" then
		LFGMM_Core_HandlePlayerLevelUp(select(1, ...))
		
	elseif event == "PARTY_INVITE_REQUEST" then
		LFGMM_Core_HandlePartyInviteRequest(select(1, ...))
		
	elseif event == "CHAT_MSG_SYSTEM" then
		LFGMM_Core_HandleChatSystemMessage(select(1, ...))
		
	elseif event == "GROUP_ROSTER_UPDATE" then
		LFGMM_Core_HandleGroupRosterUpdate()
		
	elseif event == "CHAT_MSG_CHANNEL" then
		local message = select(1, ...)
		local player = select(5, ...)
		local playerGuid = select(12, ...)
		local channelName = select(9, ...)
		LFGMM_Core_HandleChatChannelMessage(message, player, playerGuid, channelName)
	end
end


-- OnHide party invite
local PARTY_INVITE_OnHide = StaticPopupDialogs["PARTY_INVITE"].OnHide;
StaticPopupDialogs["PARTY_INVITE"].OnHide = function(self)
	LFGMM_PopupWindow_HideForInvited();
	LFGMM_PopupWindow_RestorePosition();
	PARTY_INVITE_OnHide(self);
end


------------------------------------------------------------------------------------------------------------------------
-- STARTUP
------------------------------------------------------------------------------------------------------------------------


-- Register events
LFGMM_MainWindow:RegisterEvent("PLAYER_ENTERING_WORLD");
LFGMM_MainWindow:RegisterEvent("ZONE_CHANGED_NEW_AREA");
LFGMM_MainWindow:RegisterEvent("CHAT_MSG_CHANNEL");
LFGMM_MainWindow:RegisterEvent("PLAYER_LEVEL_UP");
LFGMM_MainWindow:RegisterEvent("GROUP_ROSTER_UPDATE");
LFGMM_MainWindow:RegisterEvent("CHAT_MSG_SYSTEM");
LFGMM_MainWindow:RegisterEvent("PARTY_INVITE_REQUEST");
LFGMM_MainWindow:SetScript("OnEvent", LFGMM_Core_EventHandler);

-- Register slash commands
SLASH_LFGMM1 = "/lfgmm";
SLASH_LFGMM2 = "/lfgmatchmaker";
SLASH_LFGMM3 = "/matchmaker";
SlashCmdList["LFGMM"] = function() 
	LFGMM_Core_MainWindow_ToggleShow();
end
