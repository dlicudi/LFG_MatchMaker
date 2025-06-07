-- Initialize frame properties that were previously set in XML
local function InitializeFrameProperties()
    -- Main window
    LFGMM_MainWindow:SetFrameStrata("HIGH")
    LFGMM_MainWindow:SetMovable(true)
    LFGMM_MainWindow:EnableMouse(true)
    LFGMM_MainWindow:Hide()

    -- Quest log button frame
    LFGMM_QuestLog_Button_Frame:SetFrameStrata("LOW")
    LFGMM_QuestLog_Button_Frame:Hide()

    -- Tabs
    LFGMM_LfgTab:Show()
    LFGMM_LfmTab:Hide()
    LFGMM_ListTab:Hide()
    LFGMM_SettingsTab:Hide()

    -- Info windows
    local infoWindows = {
        "LFGMM_LfgTab_BroadcastMessageInfoWindow",
        "LFGMM_LfmTab_BroadcastMessageInfoWindow",
        "LFGMM_ListTab_MessageInfoWindow",
        "LFGMM_SettingsTab_RequestInviteMessageInfoWindow",
        "LFGMM_SettingsTab_ChannelsDropDownInfoWindow"
    }

    for _, window in ipairs(infoWindows) do
        local frame = _G[window]
        if frame then
            frame:SetFrameStrata("HIGH")
            frame:EnableMouse(true)
            frame:Hide()
        end
    end

    -- Popup window
    LFGMM_PopupWindow:SetFrameStrata("HIGH")
    LFGMM_PopupWindow:SetMovable(true)
    LFGMM_PopupWindow:EnableMouse(true)
    LFGMM_PopupWindow:Hide()

    -- Broadcast window
    LFGMM_BroadcastWindow:SetFrameStrata("HIGH")
    LFGMM_BroadcastWindow:SetMovable(true)
    LFGMM_BroadcastWindow:EnableMouse(true)
    LFGMM_BroadcastWindow:Hide()

    -- Buttons
    LFGMM_PopupWindow_IgnoreButton:Hide()
    LFGMM_PopupWindow_WhisperButton:Show()
    LFGMM_PopupWindow_RequestInviteButton:Hide()
    LFGMM_PopupWindow_InviteButton:Hide()
    LFGMM_PopupWindow_SkipWaitButton:Hide()

    -- Font strings
    LFGMM_ListTab_MessageInfoWindow_InPartyText:Hide()
    LFGMM_PopupWindow_WaitText:Hide()
    LFGMM_PopupWindow_WaitCountdownText:Hide()
end

-- Register the initialization function
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "LFG_MatchMaker_Continued" then
        InitializeFrameProperties()
    end
end) 