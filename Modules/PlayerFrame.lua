-- Comfy: Player Frame Module
local addonName, Comfy = ...

local playerFrameHidden = false
local originalAlpha = 1

function Comfy:InitPlayerFrame()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat

    eventFrame:SetScript("OnEvent", function(self, event)
        if not ComfyDB.hidePlayerFrameInCombat then
            -- If setting is off, make sure frame is visible
            if playerFrameHidden then
                PlayerFrame:SetAlpha(originalAlpha)
                playerFrameHidden = false
            end
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            -- Entering combat - hide player frame
            if not playerFrameHidden then
                originalAlpha = PlayerFrame:GetAlpha()
                PlayerFrame:SetAlpha(0)
                playerFrameHidden = true
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Leaving combat - show player frame
            if playerFrameHidden then
                PlayerFrame:SetAlpha(originalAlpha)
                playerFrameHidden = false
            end
        end
    end)
end
