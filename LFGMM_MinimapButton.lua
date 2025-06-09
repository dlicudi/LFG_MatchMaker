--[[
	LFG MatchMaker - Addon for World of Warcraft.
	Version: 1.1.0
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
-- MINIMAP BUTTON
------------------------------------------------------------------------------------------------------------------------


local dbIcon, dbIconData;

function LFGMM_MinimapButton_Initialize()
	-- Initialize LibDB
	dbIcon = LibStub("LibDBIcon-1.0");
	dataBroker = LibStub("LibDataBroker-1.1");

	-- Create minimap button config
	dbIconData = dataBroker:NewDataObject(
		"LFG MatchMaker",
		{
			type = "data source",
			text = "LFG MatchMaker",
			icon = "Interface\\Icons\\INV_Misc_GroupLooking",
			iconCoords = {0, 1, 0, 1},
			iconR = 1,
			iconG = 1,
			iconB = 1,
			OnClick = LFGMM_MinimapButton_Button_OnClick,
			OnTooltipShow = function (tooltip)
				tooltip:AddLine("LFG MatchMaker", 1, 1, 1);
				
				-- Add search status information
				local lfgRunning = LFGMM_DB.SEARCH.LFG.Running;
				local lfmRunning = LFGMM_DB.SEARCH.LFM.Running;
				
				if (lfgRunning or lfmRunning) then
					tooltip:AddLine(" ");  -- Blank line for spacing
					
					if (lfgRunning) then
						tooltip:AddLine("• LFG Search: Active", 0, 1, 0);  -- Green text
						
						-- Show selected dungeons count
						local dungeonCount = 0;
						for _ in pairs(LFGMM_DB.SEARCH.LFG.Dungeons) do
							dungeonCount = dungeonCount + 1;
						end
						if (dungeonCount > 0) then
							tooltip:AddLine("  " .. dungeonCount .. " dungeon(s) selected", 0.8, 0.8, 0.8);
						end
					end
					
					if (lfmRunning) then
						tooltip:AddLine("• LFM Search: Active", 0, 1, 0);  -- Green text
						
						-- Show selected dungeon name if available
						if (LFGMM_DB.SEARCH.LFM.Dungeon) then
							local dungeonName = LFGMM_Utility_GetDungeonNameById(LFGMM_DB.SEARCH.LFM.Dungeon);
							if (dungeonName) then
								tooltip:AddLine("  " .. dungeonName, 0.8, 0.8, 0.8);
							end
						end
					end
				else
					tooltip:AddLine(" ");  -- Blank line for spacing
					tooltip:AddLine("No active searches", 0.6, 0.6, 0.6);  -- Gray text
				end
				
				tooltip:AddLine(" ");  -- Blank line for spacing
				tooltip:AddLine("Click to open", 0.5, 0.5, 1);  -- Light blue text
			end,
		}
	);
	
	-- Add button
	dbIcon:Register("LFG MatchMaker", dbIconData, LFGMM_DB.SETTINGS.MinimapLibDBSettings);

	-- Toggle show
	LFGMM_MinimapButton_ToggleVisibility();
end


function LFGMM_MinimapButton_Refresh()
	if (LFGMM_DB.SEARCH.LFG.Running or LFGMM_DB.SEARCH.LFM.Running) then
		dbIconData.iconR = 0.2;
		dbIconData.iconG = 1;
		dbIconData.iconB = 0.2;
	else
		dbIconData.iconR = 1;
		dbIconData.iconG = 1;
		dbIconData.iconB = 1;
	end
end


function LFGMM_MinimapButton_ToggleVisibility()
	if (LFGMM_DB.SETTINGS.ShowMinimapButton) then
		dbIcon:Show("LFG MatchMaker");
		
		-- Fix overlapping icons display issue
		dbIcon:GetMinimapButton("LFG MatchMaker"):SetFrameLevel(10);
	else
		dbIcon:Hide("LFG MatchMaker");
	end
end


function LFGMM_MinimapButton_Button_OnClick()
	LFGMM_Core_MainWindow_ToggleShow();
end

