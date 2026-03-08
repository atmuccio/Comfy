-- Comfy: Tooltip Module
local addonName, Comfy = ...

local function IsModifierDown()
    local modifier = ComfyDB.tooltipCombatModifier
    if modifier == "alt" then
        return IsAltKeyDown()
    elseif modifier == "ctrl" then
        return IsControlKeyDown()
    elseif modifier == "shift" then
        return IsShiftKeyDown()
    end
    return false
end

local function ShouldShowTooltip()
    -- If not in combat, always show
    if not InCombatLockdown() then
        return true
    end

    -- In combat: check if we should hide
    if not ComfyDB.hideTooltipInCombat then
        return true
    end

    -- Allow modifier key to override
    return IsModifierDown()
end

function Comfy:InitTooltips()
    -- Tooltip at mouse position
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if ComfyDB.tooltipAtMouse then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR", ComfyDB.tooltipMouseOffsetX, ComfyDB.tooltipMouseOffsetY)
        end
    end)

    -- Hide tooltips in combat
    GameTooltip:HookScript("OnShow", function(self)
        if not ShouldShowTooltip() then
            self:Hide()
        end
    end)

    -- Also hook OnUpdate to catch tooltips that might slip through
    local throttle = 0
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        throttle = throttle + elapsed
        if throttle < 0.1 then return end
        throttle = 0

        if self:IsShown() and not ShouldShowTooltip() then
            self:Hide()
        end
    end)
end
