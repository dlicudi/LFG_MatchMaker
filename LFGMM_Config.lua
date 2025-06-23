--[[
	LFG MatchMaker - Addon for World of Warcraft.
	URL: https://github.com/dlicudi/LFG_MatchMaker
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
-- CONFIG & SAVED VARIABLES
------------------------------------------------------------------------------------------------------------------------


-- Centralized version management
LFGMM_ADDON_VERSION = "1.2.6"

function LFGMM_Load()
	LFGMM_DB_VERSION = 4;
	
	-- Get locale language
	local locale = GetLocale();
	if (locale == "deDE") then
		locale = "DE";
	elseif (locale == "frFR") then
		locale = "FR";
	elseif (locale == "esES" or locale == "esMX") then
		locale = "ES";
	else
		locale = nil;
	end

	-- Database
	if (LFGMM_DB == nil) then
		LFGMM_DB = {
			VERSION = LFGMM_DB_VERSION,
			SETTINGS = {
				MessageTimeout = 30,
				MaxMessageAge = 10,
				BroadcastInterval = 2,
				InfoWindowLocation = "right",
				RequestInviteMessage = "",
				RequestInviteMessageTemplate = "Invite for group ({L} {C})",
				ShowQuestLogButton = true,
				ShowMinimapButton = true,
				HideLowLevel = false,
				HideHighLevel = false,
				HidePvp = false,
				HideRaids = false,
				MinimapLibDBSettings = {},
				IdentifierLanguages = { "EN" },
				UseTradeChannel = false,
				UseGeneralChannel = false,
			},
			LIST = {
				Dungeons = {},
				ShowUnknownDungeons = false,
				MessageTypes = {
					Unknown = false,
					Lfg = true,
					Lfm = true,
				}
			},
			SEARCH = {
				LastBroadcast = time() - 600,
				LFG = {
					Running = false,
					MatchLfg = false,
					MatchUnknown = true,
					AutoStop = true,
					Broadcast = false,
					BroadcastMessage = "",
					BroadcastMessageTemplate = "{L} {C} LFG {A}",
					Dungeons = {},
				},
				LFM = {
					Running = false,
					MatchLfm = false,
					MatchUnknown = true,
					AutoStop = true,
					Broadcast = false,
					BroadcastMessage = "",
					BroadcastMessageTemplate = "LF{N}M {D}",
					Dungeon = nil,
				}
			}
		};
		
		-- Add locale identifier language
		if (locale ~= nil) then
			table.insert(LFGMM_DB.SETTINGS.IdentifierLanguages, locale);
		end

		-- Add all dungeons to list selection
		for _,dungeon in ipairs(LFGMM_GLOBAL.DUNGEONS) do
			table.insert(LFGMM_DB.LIST.Dungeons, dungeon.Index);
		end

	else
		if (LFGMM_DB.VERSION <= 1) then
			LFGMM_DB.SETTINGS.IdentifierLanguages = { "EN" };

			-- Add locale identifier language
			if (locale ~= nil) then
				table.insert(LFGMM_DB.SETTINGS.IdentifierLanguages, locale);
			end
		end
		
		if (LFGMM_DB.VERSION <= 2) then
			LFGMM_DB.SEARCH.LFG.AutoStop = true;
			LFGMM_DB.SEARCH.LFM.AutoStop = true;
		end
		
		if (LFGMM_DB.VERSION <= 3) then
			LFGMM_DB.SETTINGS.MinimapLibDBSettings = {};
			LFGMM_DB.SETTINGS.InfoWindowLocation = "right";
			LFGMM_DB.SETTINGS.UseTradeChannel = false;
			LFGMM_DB.SETTINGS.UseGeneralChannel = false;
		end
		
		if (LFGMM_DB.VERSION < LFGMM_DB_VERSION) then
			LFGMM_DB.VERSION = LFGMM_DB_VERSION;
		end
	end
	
	-- OnLoad search = off
	LFGMM_DB.SEARCH.LFG.Running = false;
	LFGMM_DB.SEARCH.LFM.Running = false;
end


------------------------------------------------------------------------------------------------------------------------
-- GLOBAL VARIABLES
------------------------------------------------------------------------------------------------------------------------


LFGMM_GLOBAL = {
	READY = false,
	LIST_SCROLL_INDEX = 1,
	SEARCH_LOCK = false,
	BROADCAST_LOCK = false,
	AUTOSTOP_AVAILABLE = true,
	WHO_COOLDOWN = 0,
	PLAYER_NAME = "",
	PLAYER_LEVEL = 0,
	PLAYER_CLASS = "",
	LFG_CHANNEL_NAME = "LookingForGroup",
	GENERAL_CHANNEL_NAME = "General",
	TRADE_CHANNEL_NAME = "Trade",
	TRADE_CHANNEL_AVAILABLE = false,
	GROUP_MEMBERS = {},
	DUNGEONS = {},
	DUNGEONS_FALLBACK = {},
	MESSAGES = {},
	MESSAGE_SORT_INDEX = 1,
	LANGUAGES = {
		{ 
			Code = "EN",
			Name = "English",
		},
		{ 
			Code = "DE",
			Name = "German",
		},
		{ 
			Code = "FR",
			Name = "French",
		},
		{ 
			Code = "ES",
			Name = "Spanish",
		},
		-- { 
			-- Code = "RU",
			-- Name = "Russian",
		-- },
	},
	CLASSES = {
		WARRIOR = {
			Name = "Warrior",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.WARRIOR,
			IconCoordinates = CLASS_ICON_TCOORDS.WARRIOR,
			Color = "|cFFC79C6E",
		},
		PALADIN = {
			Name = "Paladin",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.PALADIN,
			IconCoordinates = CLASS_ICON_TCOORDS.PALADIN,
			Color = "|cFFF58CBA",
		},
		HUNTER = {
			Name = "Hunter",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.HUNTER,
			IconCoordinates = CLASS_ICON_TCOORDS.HUNTER,
			Color = "|cFFABD473",
		},
		ROGUE = {
			Name = "Rogue",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.ROGUE,
			IconCoordinates = CLASS_ICON_TCOORDS.ROGUE,
			Color = "|cFFFFF569",
		},
		PRIEST = {
			Name = "Priest",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.PRIEST,
			IconCoordinates = CLASS_ICON_TCOORDS.PRIEST,
			Color = "|cFFFFFFFF",
		},
		SHAMAN = {
			Name = "Shaman",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.SHAMAN,
			IconCoordinates = CLASS_ICON_TCOORDS.SHAMAN,
			Color = "|cFF0070DE",
		},
		MAGE = {
			Name = "Mage",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.MAGE,
			IconCoordinates = CLASS_ICON_TCOORDS.MAGE,
			Color = "|cFF69CCF0",
		},
		WARLOCK = {
			Name = "Warlock",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.WARLOCK,
			IconCoordinates = CLASS_ICON_TCOORDS.WARLOCK,
			Color = "|cFF9482C9",
		},
		DRUID = {
			Name = "Druid",
			LocalizedName = LOCALIZED_CLASS_NAMES_MALE.DRUID,
			IconCoordinates = CLASS_ICON_TCOORDS.DRUID,
			Color = "|cFFFF7D0A",
		},
	},
};