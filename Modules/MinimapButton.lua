-- Comfy: Minimap Button Module
local addonName, Comfy = ...

local minimapButton

local function UpdatePosition()
    local angle = math.rad(ComfyDB.minimapButtonPosition or 220)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragStart(self)
    self.isDragging = true
end

local function OnDragStop(self)
    self.isDragging = false
end

local function OnUpdate(self)
    if not self.isDragging then return end

    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale

    local angle = math.deg(math.atan2(cy - my, cx - mx))
    ComfyDB.minimapButtonPosition = angle
    UpdatePosition()
end

local function OnClick(self, button)
    if button == "LeftButton" then
        -- Open settings panel
        if Comfy.settingsCategory then
            Settings.OpenToCategory(Comfy.settingsCategory:GetID())
        end
    elseif button == "RightButton" then
        -- Show quick toggle menu using MenuUtil (replaces deprecated EasyMenu)
        MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle("Comfy Settings")

            rootDescription:CreateCheckbox("Tooltip at Mouse", function()
                return ComfyDB.tooltipAtMouse
            end, function()
                ComfyDB.tooltipAtMouse = not ComfyDB.tooltipAtMouse
            end)

            rootDescription:CreateCheckbox("Hide Tooltips in Combat", function()
                return ComfyDB.hideTooltipInCombat
            end, function()
                ComfyDB.hideTooltipInCombat = not ComfyDB.hideTooltipInCombat
            end)

            rootDescription:CreateCheckbox("Hide Player Frame in Combat", function()
                return ComfyDB.hidePlayerFrameInCombat
            end, function()
                ComfyDB.hidePlayerFrameInCombat = not ComfyDB.hidePlayerFrameInCombat
            end)

            rootDescription:CreateDivider()

            rootDescription:CreateButton("Open Settings Panel", function()
                if Comfy.settingsCategory then
                    Settings.OpenToCategory(Comfy.settingsCategory:GetID())
                end
            end)

            rootDescription:CreateButton("Hide Minimap Button", function()
                ComfyDB.showMinimapButton = false
                minimapButton:Hide()
                print("|cff00ff00Comfy|r: Minimap button hidden. Use /comfy minimap to show it again.")
            end)
        end)
    end
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Comfy", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Quick toggles", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function OnLeave(self)
    GameTooltip:Hide()
end

function Comfy:InitMinimapButton()
    -- Default setting
    if ComfyDB.showMinimapButton == nil then
        ComfyDB.showMinimapButton = true
    end
    if ComfyDB.minimapButtonPosition == nil then
        ComfyDB.minimapButtonPosition = 220
    end

    -- Create the button
    minimapButton = CreateFrame("Button", "ComfyMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)

    -- Background (dark circle behind icon)
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(136467) -- Interface\\Minimap\\UI-Minimap-Background
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER", 0, 0)
    minimapButton.bg = bg

    -- Icon texture (using texture ID for reliability)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(133665) -- INV_Misc_Bag_Enchanted texture ID
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 0)
    minimapButton.icon = icon

    -- Border overlay
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -2, 2)
    minimapButton.border = border

    -- Highlight texture
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(136477) -- Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight
    highlight:SetSize(25, 25)
    highlight:SetPoint("CENTER", 0, 0)
    highlight:SetBlendMode("ADD")

    -- Make it draggable
    minimapButton:SetMovable(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Scripts
    minimapButton:SetScript("OnDragStart", OnDragStart)
    minimapButton:SetScript("OnDragStop", OnDragStop)
    minimapButton:SetScript("OnUpdate", OnUpdate)
    minimapButton:SetScript("OnClick", OnClick)
    minimapButton:SetScript("OnEnter", OnEnter)
    minimapButton:SetScript("OnLeave", OnLeave)

    -- Position it
    UpdatePosition()

    -- Show/hide based on setting
    if ComfyDB.showMinimapButton then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end

    Comfy.minimapButton = minimapButton
end

-- Function to toggle minimap button visibility
function Comfy:ToggleMinimapButton()
    ComfyDB.showMinimapButton = not ComfyDB.showMinimapButton
    if ComfyDB.showMinimapButton then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
    return ComfyDB.showMinimapButton
end
