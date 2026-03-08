-- Comfy: Settings Panel Module
local addonName, Comfy = ...

function Comfy:InitSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Comfy")

    -- Header
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tooltip Settings"))

    -- Tooltip at Mouse
    do
        local variable = "tooltipAtMouse"
        local name = "Tooltip at Mouse Cursor"
        local tooltip = "Anchors tooltips to your mouse cursor instead of the default corner position."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Hide Tooltip in Combat
    do
        local variable = "hideTooltipInCombat"
        local name = "Hide Tooltips in Combat"
        local tooltip = "Hides tooltips while you are in combat. Use the modifier key below to temporarily show them."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Combat Modifier Key
    do
        local variable = "tooltipCombatModifier"
        local name = "Combat Tooltip Modifier"
        local tooltip = "Hold this key to show tooltips while in combat (when tooltips are hidden in combat)."

        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add("alt", "ALT")
            container:Add("ctrl", "CTRL")
            container:Add("shift", "SHIFT")
            return container:GetData()
        end

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    -- Spacer and Player Frame header
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Player Frame Settings"))

    -- Hide Player Frame in Combat
    do
        local variable = "hidePlayerFrameInCombat"
        local name = "Hide Player Frame in Combat"
        local tooltip = "Hides your player unit frame while in combat for a cleaner view."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Crafting Orders header
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Crafting Orders"))

    -- Auto-show unified view
    do
        local variable = "craftingOrdersAutoShow"
        local name = "Auto-Show Unified Orders"
        local tooltip = "Automatically opens the Comfy unified orders view when you open the Crafting Orders tab. All order types are shown in a single list with inline rewards and first-craft badges."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- First Craft Only default
    do
        local variable = "craftingOrdersFirstCraftOnly"
        local name = "Default to First Craft Only"
        local tooltip = "When enabled, the unified orders view defaults to showing only orders that are first-time crafts."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- General Settings header
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

    -- Show Minimap Button
    do
        local variable = "showMinimapButton"
        local name = "Show Minimap Button"
        local tooltip = "Shows a button on the minimap for quick access to Comfy settings."

        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. variable, variable, ComfyDB, type(ComfyDB[variable]), name, ComfyDB[variable])
        setting:SetValueChangedCallback(function(_, newValue)
            if Comfy.minimapButton then
                if newValue then
                    Comfy.minimapButton:Show()
                else
                    Comfy.minimapButton:Hide()
                end
            end
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    Settings.RegisterAddOnCategory(category)
    Comfy.settingsCategory = category
end

-- Add command to open settings directly
local originalSlashHandler = SlashCmdList["COMFY"]
SlashCmdList["COMFY"] = function(msg)
    if msg == "" or msg == "options" or msg == "settings" or msg == "config" then
        Settings.OpenToCategory(Comfy.settingsCategory:GetID())
    else
        originalSlashHandler(msg)
    end
end
