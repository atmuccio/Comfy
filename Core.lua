-- Comfy: Personal Quality of Life Tweaks
local addonName, Comfy = ...

-- Default settings
local defaults = {
    tooltipAtMouse = true,
    tooltipMouseOffsetX = 20,
    tooltipMouseOffsetY = 20,
    hideTooltipInCombat = true,
    tooltipCombatModifier = "alt",  -- "alt", "ctrl", "shift"
    hidePlayerFrameInCombat = true,
    craftingOrdersAutoShow = true,
    craftingOrdersFirstCraftOnly = false,
}

-- Initialize saved variables
local function InitializeDB()
    if not ComfyDB then
        ComfyDB = {}
    end
    for key, value in pairs(defaults) do
        if ComfyDB[key] == nil then
            ComfyDB[key] = value
        end
    end
end

-- Settings accessor
function Comfy:Get(key)
    return ComfyDB[key]
end

function Comfy:Set(key, value)
    ComfyDB[key] = value
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()

        -- Initialize modules
        if Comfy.InitMinimapButton then Comfy:InitMinimapButton() end
        if Comfy.InitTooltips then Comfy:InitTooltips() end
        if Comfy.InitPlayerFrame then Comfy:InitPlayerFrame() end
        if Comfy.InitCraftingOrders then Comfy:InitCraftingOrders() end
        if Comfy.InitSettings then Comfy:InitSettings() end

        print("|cff00ff00Comfy|r loaded. Type /comfy or find it in Options > AddOns.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands
SLASH_COMFY1 = "/comfy"
SlashCmdList["COMFY"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "tooltip" then
        if arg == "mouse" then
            ComfyDB.tooltipAtMouse = not ComfyDB.tooltipAtMouse
            print("|cff00ff00Comfy|r: Tooltip at mouse " .. (ComfyDB.tooltipAtMouse and "enabled" or "disabled"))
        elseif arg == "combat" then
            ComfyDB.hideTooltipInCombat = not ComfyDB.hideTooltipInCombat
            print("|cff00ff00Comfy|r: Hide tooltip in combat " .. (ComfyDB.hideTooltipInCombat and "enabled" or "disabled"))
        elseif arg == "alt" or arg == "ctrl" or arg == "shift" then
            ComfyDB.tooltipCombatModifier = arg
            print("|cff00ff00Comfy|r: Combat tooltip modifier set to " .. arg:upper())
        else
            print("|cff00ff00Comfy|r Tooltip options:")
            print("  /comfy tooltip mouse - Toggle tooltip at mouse cursor")
            print("  /comfy tooltip combat - Toggle hide tooltip in combat")
            print("  /comfy tooltip alt|ctrl|shift - Set combat override modifier")
        end
    elseif cmd == "playerframe" then
        ComfyDB.hidePlayerFrameInCombat = not ComfyDB.hidePlayerFrameInCombat
        print("|cff00ff00Comfy|r: Hide player frame in combat " .. (ComfyDB.hidePlayerFrameInCombat and "enabled" or "disabled"))
    elseif cmd == "minimap" then
        local shown = Comfy:ToggleMinimapButton()
        print("|cff00ff00Comfy|r: Minimap button " .. (shown and "shown" or "hidden"))
    else
        print("|cff00ff00Comfy|r - Quality of Life Tweaks")
        print("Commands:")
        print("  /comfy tooltip - Tooltip options")
        print("  /comfy playerframe - Toggle hide player frame in combat")
        print("  /comfy minimap - Toggle minimap button")
        print("")
        print("Current settings:")
        print("  Tooltip at mouse: " .. (ComfyDB.tooltipAtMouse and "ON" or "OFF"))
        print("  Hide tooltip in combat: " .. (ComfyDB.hideTooltipInCombat and "ON" or "OFF"))
        print("  Combat modifier: " .. ComfyDB.tooltipCombatModifier:upper())
        print("  Hide player frame in combat: " .. (ComfyDB.hidePlayerFrameInCombat and "ON" or "OFF"))
        print("  Minimap button: " .. (ComfyDB.showMinimapButton and "ON" or "OFF"))
    end
end

-- Export addon table
_G["Comfy"] = Comfy
