-- Comfy: Crafting Orders Enhancement Module
-- Replaces the tabbed crafting orders UI with a single unified list showing
-- all order types, inline rewards, first-craft badges, and smart sorting.
local addonName, Comfy = ...

-- ────────────────────────────────────────────────────────────────────────────
-- Constants
-- ────────────────────────────────────────────────────────────────────────────

local FIRST_CRAFT_COLOR  = CreateColor(0.2, 0.9, 0.3)
local DIM_COLOR          = CreateColor(0.5, 0.5, 0.5)
local WHITE              = CreateColor(1, 1, 1)

local TYPE_COLORS = {
    [Enum.CraftingOrderType.Public]   = CreateColor(0.6, 0.8, 1.0),
    [Enum.CraftingOrderType.Guild]    = CreateColor(0.25, 1.0, 0.25),
    [Enum.CraftingOrderType.Personal] = CreateColor(1.0, 0.8, 0.2),
    [Enum.CraftingOrderType.Npc]      = CreateColor(0.9, 0.5, 1.0),
}

local TYPE_LABELS = {
    [Enum.CraftingOrderType.Public]   = "Public",
    [Enum.CraftingOrderType.Guild]    = "Guild",
    [Enum.CraftingOrderType.Personal] = "Personal",
    [Enum.CraftingOrderType.Npc]      = "Patron",
}

local ROW_HEIGHT = 30
local HEADER_HEIGHT = 24
local FILTER_BAR_HEIGHT = 32

local ROW_FIELDS = { "typeText", "qualityIcon", "recipeName", "patronName", "rewards", "reagents", "timeLeft" }

-- Fallback quality atlas names (used when API lookup fails)
local QUALITY_ATLAS_FALLBACK = {
    [1] = "Professions-Icon-Quality-Tier1-Small",
    [2] = "Professions-Icon-Quality-Tier2-Small",
    [3] = "Professions-Icon-Quality-Tier3-Small",
    [4] = "Professions-Icon-Quality-Tier4-Small",
    [5] = "Professions-Icon-Quality-Tier5-Small",
}

-- Shared no-op widget stub
local NOOP_WIDGET = { Show = function() end, Hide = function() end }

-- Get the correct quality atlas for a given order, handling both 5-tier and 2-tier recipes
local qualityAtlasCache = {}

local function GetQualityAtlas(order)
    if not order.minQuality or order.minQuality <= 1 then return nil end
    if not order.spellID then return QUALITY_ATLAS_FALLBACK[order.minQuality] end

    local cacheKey = order.spellID * 10 + order.minQuality
    if qualityAtlasCache[cacheKey] ~= nil then return qualityAtlasCache[cacheKey] end

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemQualityInfo then
        local ok, qualityInfo = pcall(C_TradeSkillUI.GetRecipeItemQualityInfo, order.spellID, order.minQuality)
        if ok and qualityInfo then
            local atlas = qualityInfo.smallIcon or qualityInfo.iconSmall
            if atlas then
                qualityAtlasCache[cacheKey] = atlas
                return atlas
            end
        end
    end
    local fallback = QUALITY_ATLAS_FALLBACK[order.minQuality]
    qualityAtlasCache[cacheKey] = fallback
    return fallback
end

-- ────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────────────────────────────────

local function FormatIcon(fileID, size)
    if not fileID then return "" end
    size = size or 20
    return "|T" .. fileID .. ":" .. size .. ":" .. size .. ":0:0|t"
end

-- Build reagent breakdown: compare recipe schematic with what customer provided
local function GetReagentBreakdown(order)
    if not order.spellID then return nil, nil end

    local provided = {}
    if order.reagents then
        for _, r in ipairs(order.reagents) do
            local itemID
            if r.reagentInfo then
                if r.reagentInfo.reagent then
                    itemID = r.reagentInfo.reagent.itemID
                end
                itemID = itemID or r.reagentInfo.itemID
            end
            if itemID then
                provided[itemID] = (r.reagentInfo and r.reagentInfo.quantity) or 0
            end
        end
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, false)
    if not ok or not schematic or not schematic.reagentSlotSchematics then
        return nil, nil
    end

    local customerReagents = {}
    local crafterReagents = {}

    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.reagents and #slot.reagents > 0 then
            local reagent = slot.reagents[1]
            local itemID = reagent and reagent.itemID
            if itemID then
                local qty = slot.quantityRequired or 0
                if qty > 0 then
                    local name = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
                    local icon = C_Item.GetItemIconByID(itemID)
                    local prefix = icon and (FormatIcon(icon, 14) .. " ") or ""
                    local entry = prefix .. name .. (qty > 1 and (" x" .. qty) or "")

                    if provided[itemID] then
                        customerReagents[#customerReagents + 1] = entry
                    else
                        crafterReagents[#crafterReagents + 1] = entry
                    end
                end
            end
        end
    end

    return customerReagents, crafterReagents
end

local function MoneyToShortString(copper)
    if not copper or copper == 0 then return "" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    if gold > 0 and silver > 0 then
        return gold .. "|cffffd700g|r " .. silver .. "|cffc7c7cfs|r"
    elseif gold > 0 then
        return gold .. "|cffffd700g|r"
    elseif silver > 0 then
        return silver .. "|cffc7c7cfs|r"
    end
    return (copper % 100) .. "|cffeda55fc|r"
end

local function TimeRemainingString(expirationTime)
    local remaining = expirationTime - time()
    if remaining <= 0 then return "|cffff4444Expired|r" end
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    if days > 0 then return days .. "d " .. hours .. "h" end
    if hours > 0 then return hours .. "h" end
    local mins = math.floor((remaining % 3600) / 60)
    return "|cffffff00" .. mins .. "m|r"
end

local function ReagentLabel(state)
    if state == Enum.CraftingOrderReagentsType.All  then return "|cff00ff00All|r" end
    if state == Enum.CraftingOrderReagentsType.Some then return "|cffffff00Some|r" end
    if state == Enum.CraftingOrderReagentsType.None then return "|cffff6666None|r" end
    return "?"
end

local function ItemIcon(itemLink, size)
    if not itemLink then return "" end
    return FormatIcon(C_Item.GetItemIconByID(itemLink), size or 20)
end

local function CurrencyIcon(currencyType, size)
    if not currencyType then return "" end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyType)
    return (info and info.iconFileID) and FormatIcon(info.iconFileID, size or 20) or ""
end

local function StripAllEscapes(text)
    if not text then return "" end
    text = text:gsub("%s?|A[^|]+|a", "")
    text = text:gsub("|T[^|]*|t", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H[^|]*|h", "")
    text = text:gsub("|n", "")
    return text:match("^%s*(.-)%s*$") or text
end

local function GetCleanItemName(itemLink)
    if not itemLink then return "" end
    local name = C_Item.GetItemNameByID(itemLink)
    if not name or name == "" then
        name = itemLink:match("%[(.-)%]") or ""
    end
    return StripAllEscapes(name)
end

local function TypePill(orderType)
    local label = TYPE_LABELS[orderType] or "?"
    local color = TYPE_COLORS[orderType] or WHITE
    return color:WrapTextInColorCode("[" .. label .. "]")
end

-- ────────────────────────────────────────────────────────────────────────────
-- Recipe info cache (first craft + learned, shared)
-- ────────────────────────────────────────────────────────────────────────────

local firstCraftCache = {}
local learnedCache = {}

local function EnsureRecipeInfoCached(id)
    if firstCraftCache[id] ~= nil then return end
    local info = C_TradeSkillUI.GetRecipeInfo(id)
    if info then
        firstCraftCache[id] = info.firstCraft or false
        learnedCache[id] = info.learned ~= false
    else
        firstCraftCache[id] = false
        learnedCache[id] = true
    end
end

local function IsFirstCraft(order)
    local id = order.spellID
    if not id then return false end
    EnsureRecipeInfoCached(id)
    return firstCraftCache[id]
end

local function IsLearned(order)
    local id = order.spellID
    if not id then return true end
    EnsureRecipeInfoCached(id)
    return learnedCache[id]
end

local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
cacheFrame:SetScript("OnEvent", function() wipe(firstCraftCache) wipe(learnedCache) wipe(qualityAtlasCache) end)

local function BuildRewardText(order)
    if order._rewardText then return order._rewardText end

    local parts = {}

    -- Gold commission (net after consortium cut)
    if order.tipAmount and order.tipAmount > 0 then
        local net = order.tipAmount - (order.consortiumCut or 0)
        parts[#parts + 1] = MoneyToShortString(net)
    end

    -- NPC/patron rewards: items and currencies
    if order.npcOrderRewards then
        for _, reward in ipairs(order.npcOrderRewards) do
            if reward.itemLink then
                local icon = ItemIcon(reward.itemLink, 20)
                local ct = (reward.count and reward.count > 1) and WHITE:WrapTextInColorCode("x" .. reward.count) or ""
                parts[#parts + 1] = icon .. ct
            elseif reward.currencyType then
                local icon = CurrencyIcon(reward.currencyType, 20)
                local ct = (reward.count and reward.count > 0) and WHITE:WrapTextInColorCode("x" .. reward.count) or ""
                parts[#parts + 1] = icon .. ct
            end
        end
    end

    local result = #parts > 0 and table.concat(parts, "  ") or DIM_COLOR:WrapTextInColorCode("---")
    order._rewardText = result
    return result
end

-- ────────────────────────────────────────────────────────────────────────────
-- State
-- ────────────────────────────────────────────────────────────────────────────

local comfyFrame       -- our replacement frame
local orderRows = {}   -- row frame pool
local allOrders = {}   -- merged orders from all types
local filteredOrders = {}
local ordersByType = {} -- per-type cache: ordersByType[orderType] = { orders... }

local typeFilters = {
    [Enum.CraftingOrderType.Public]   = true,
    [Enum.CraftingOrderType.Guild]    = true,
    [Enum.CraftingOrderType.Personal] = true,
    [Enum.CraftingOrderType.Npc]      = true,
}

local SORT_FIRST_CRAFT = 1
local SORT_COMMISSION  = 2
local SORT_TIME        = 3
local SORT_NAME        = 4
local currentSort = SORT_FIRST_CRAFT
local sortReversed = false

-- ────────────────────────────────────────────────────────────────────────────
-- Sorting & Filtering
-- ────────────────────────────────────────────────────────────────────────────

local function SortOrders()
    table.sort(filteredOrders, function(a, b)
        -- Unlearned sorts to bottom
        local aLearned = a._isLearned and 1 or 0
        local bLearned = b._isLearned and 1 or 0
        if aLearned ~= bLearned then return aLearned > bLearned end

        -- First craft sorts to top (within learned)
        local aFirst = a._isFirstCraft and 1 or 0
        local bFirst = b._isFirstCraft and 1 or 0
        if aFirst ~= bFirst then return aFirst > bFirst end

        local result
        if currentSort == SORT_COMMISSION then
            result = (a.tipAmount or 0) > (b.tipAmount or 0)
        elseif currentSort == SORT_TIME then
            result = (a.expirationTime or 0) < (b.expirationTime or 0)
        elseif currentSort == SORT_NAME then
            result = (a._displayName or "") < (b._displayName or "")
        else
            result = (a.tipAmount or 0) > (b.tipAmount or 0)
        end

        if sortReversed then return not result end
        return result
    end)
end

local function ApplyFilters()
    wipe(filteredOrders)
    for _, order in ipairs(allOrders) do
        if typeFilters[order.orderType] then
            if not ComfyDB.craftingOrdersFirstCraftOnly or order._isFirstCraft then
                filteredOrders[#filteredOrders + 1] = order
            end
        end
    end
    SortOrders()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Data fetching (sequential request chain)
-- ────────────────────────────────────────────────────────────────────────────

local typesToRequest = {
    Enum.CraftingOrderType.Npc,
    Enum.CraftingOrderType.Personal,
    Enum.CraftingOrderType.Guild,
    Enum.CraftingOrderType.Public,
}

local function CollectResults(orderType, displayBuckets)
    local orders
    if displayBuckets then
        orders = {}
        local buckets = C_CraftingOrders.GetCrafterBuckets()
        if buckets then
            for _, bucket in ipairs(buckets) do
                orders[#orders + 1] = {
                    orderType = orderType,
                    spellID = bucket.spellID,
                    skillLineAbilityID = bucket.skillLineAbilityID,
                    tipAmountAvg = bucket.tipAmountAvg,
                    tipAmountMax = bucket.tipAmountMax,
                    tipAmount = bucket.tipAmountMax or bucket.tipAmountAvg or 0,
                    numAvailable = bucket.numAvailable,
                    reagentState = bucket.reagentState,
                    outputItemHyperlink = bucket.outputItemHyperlink,
                    _isBucket = true,
                    _bucketData = bucket,
                }
            end
        end
    else
        orders = C_CraftingOrders.GetCrafterOrders()
        if orders then
            for _, order in ipairs(orders) do
                order.orderType = order.orderType or orderType
            end
        end
    end
    return orders or {}
end

local function CacheOrderMetadata()
    for _, order in ipairs(allOrders) do
        if not order._displayName then
            if order.outputItemHyperlink then
                order._displayName = GetCleanItemName(order.outputItemHyperlink)
            elseif order.spellID then
                order._displayName = C_Spell.GetSpellName(order.spellID) or ""
            else
                order._displayName = ""
            end
        end
        if order._isLearned == nil then
            order._isLearned = IsLearned(order)
            order._isFirstCraft = IsFirstCraft(order)
        end
    end
end

local requestGeneration = 0
local cacheTimestamp = 0
local CACHE_TTL = 180 -- 3 minutes

local function RebuildAllOrders()
    wipe(allOrders)
    for _, typeOrders in pairs(ordersByType) do
        for _, order in ipairs(typeOrders) do
            allOrders[#allOrders + 1] = order
        end
    end
end

local function RefreshDisplay()
    CacheOrderMetadata()
    ApplyFilters()
    if comfyFrame and comfyFrame:IsShown() then
        Comfy:RefreshCraftingOrdersDisplay()
    end
end

local function FinishLoading()
    cacheTimestamp = time()
    RebuildAllOrders()
    RefreshDisplay()
    if comfyFrame then
        if comfyFrame.refreshBtn then comfyFrame.refreshBtn:Enable() end
        if comfyFrame.loadingFrame then comfyFrame.loadingFrame:Hide() end
    end
end

local function RequestNextType(index, generation, typesToFetch)
    if generation ~= requestGeneration then return end
    local fetchList = typesToFetch or typesToRequest

    -- Update loading overlay
    if comfyFrame and comfyFrame.loadingFrame then
        if index <= #fetchList then
            comfyFrame.loadingFrame:Show()
            comfyFrame.loadingBar:SetMinMaxValues(0, #fetchList)
            comfyFrame.loadingBar:SetValue(index - 1)
            local typeName = TYPE_LABELS[fetchList[index]] or "..."
            comfyFrame.loadingText:SetText("Fetching " .. typeName .. " orders... (" .. index .. "/" .. #fetchList .. ")")
        end
    end

    if index > #fetchList then
        FinishLoading()
        return
    end

    local orderType = fetchList[index]

    if comfyFrame and comfyFrame.countText then
        comfyFrame.countText:SetText("Loading... (" .. (index) .. "/" .. #fetchList .. ")")
    end

    if orderType == Enum.CraftingOrderType.Guild and not IsInGuild() then
        RequestNextType(index + 1, generation, typesToFetch)
        return
    end

    local callbackFired = false

    C_Timer.After(3, function()
        if not callbackFired and generation == requestGeneration then
            callbackFired = true
            RequestNextType(index + 1, generation, typesToFetch)
        end
    end)

    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local profession = profInfo and profInfo.profession

    local ok, err = pcall(C_CraftingOrders.RequestCrafterOrders, {
        orderType = orderType,
        selectedSkillLineAbility = nil,
        searchFavorites = false,
        initialNonPublicSearch = (orderType ~= Enum.CraftingOrderType.Public),
        primarySort = {
            sortType = Enum.CraftingOrderSortType.ItemName,
            reversed = false,
        },
        secondarySort = {
            sortType = Enum.CraftingOrderSortType.Tip,
            reversed = true,
        },
        forCrafter = true,
        offset = 0,
        profession = profession,
        callback = function(_, _, displayBuckets)
            if callbackFired or generation ~= requestGeneration then return end
            callbackFired = true

            ordersByType[orderType] = CollectResults(orderType, displayBuckets)

            -- Progressive display: rebuild and show as each type arrives
            RebuildAllOrders()
            RefreshDisplay()

            RequestNextType(index + 1, generation, typesToFetch)
        end,
    })

    if not ok then
        if not callbackFired then
            callbackFired = true
            RequestNextType(index + 1, generation, typesToFetch)
        end
    end
end

local function RequestAllOrders()
    wipe(ordersByType)
    wipe(allOrders)
    requestGeneration = requestGeneration + 1
    if comfyFrame and comfyFrame.refreshBtn then
        comfyFrame.refreshBtn:Disable()
    end
    RequestNextType(1, requestGeneration)
end

local function RequestOrderTypes(types)
    requestGeneration = requestGeneration + 1
    if comfyFrame and comfyFrame.refreshBtn then
        comfyFrame.refreshBtn:Disable()
    end
    RequestNextType(1, requestGeneration, types)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Show/Hide: intercept BrowseFrame
-- ────────────────────────────────────────────────────────────────────────────

-- Hide/show Blizzard's children inside BrowseFrame
local browseChildFrames = {}  -- child frames we Hide/Show
local browseTextRegions = {}  -- FontStrings we alpha-toggle (Blizzard re-shows these on timers)

local ordersRemainingDisplay = nil

local function CaptureBrowseChildren()
    if #browseChildFrames > 0 then return end
    local browse = ProfessionsFrame.OrdersPage.BrowseFrame
    for _, child in ipairs({browse:GetChildren()}) do
        if child ~= comfyFrame then
            browseChildFrames[#browseChildFrames + 1] = child
        end
    end
    for _, region in ipairs({browse:GetRegions()}) do
        if region:IsObjectType("FontString") then
            browseTextRegions[#browseTextRegions + 1] = region
        end
    end
    -- Capture the named OrdersRemainingDisplay directly
    ordersRemainingDisplay = browse.OrdersRemainingDisplay
end

local comfyUIActive = false
local lastViewedOrderType = nil

local function ShowComfyUI(skipRefresh)
    if not comfyFrame then return end
    comfyUIActive = true
    CaptureBrowseChildren()
    for _, child in ipairs(browseChildFrames) do
        child:Hide()
        if not child._comfyHooked then
            -- Hook both Show and SetShown so Blizzard can't re-show via either path
            local origShow = child.Show
            child.Show = function(self, ...)
                if comfyUIActive then return end
                origShow(self, ...)
            end
            local origSetShown = child.SetShown
            child.SetShown = function(self, shown, ...)
                if comfyUIActive and shown then return end
                origSetShown(self, shown, ...)
            end
            child._comfyHooked = true
        end
    end
    for _, region in ipairs(browseTextRegions) do
        if not region._comfyHooked then
            local origSetAlpha = region.SetAlpha
            region.SetAlpha = function(self, alpha)
                if comfyUIActive then
                    origSetAlpha(self, 0)
                else
                    origSetAlpha(self, alpha)
                end
            end
            local origSetText = region.SetText
            region.SetText = function(self, text, ...)
                if comfyUIActive then return end
                origSetText(self, text, ...)
            end
            region._comfyHooked = true
        end
        region:SetAlpha(0)
    end
    -- Nuclear option for OrdersRemainingDisplay — hide it and reparent off-screen
    if ordersRemainingDisplay and not ordersRemainingDisplay._comfyStashed then
        ordersRemainingDisplay._comfyOrigParent = ordersRemainingDisplay:GetParent()
        ordersRemainingDisplay._comfyStashed = true
    end
    if ordersRemainingDisplay then
        ordersRemainingDisplay:SetParent(comfyFrame)
        ordersRemainingDisplay:Hide()
        ordersRemainingDisplay:SetAlpha(0)
    end
    comfyFrame:Show()
    local cacheStale = (time() - cacheTimestamp) >= CACHE_TTL
    if not skipRefresh or cacheStale then
        RequestAllOrders()
    else
        -- Check which types are missing from cache
        local missing = {}
        for _, orderType in ipairs(typesToRequest) do
            if not ordersByType[orderType] then
                missing[#missing + 1] = orderType
            end
        end
        if #missing > 0 then
            -- Show cached data immediately, then fetch only missing types
            RebuildAllOrders()
            RefreshDisplay()
            RequestOrderTypes(missing)
        else
            RebuildAllOrders()
            RefreshDisplay()
        end
    end
end

local function HideComfyUI()
    if not comfyFrame then return end
    comfyUIActive = false
    comfyFrame:Hide()
    -- Restore OrdersRemainingDisplay to its original parent
    if ordersRemainingDisplay and ordersRemainingDisplay._comfyOrigParent then
        ordersRemainingDisplay:SetParent(ordersRemainingDisplay._comfyOrigParent)
        ordersRemainingDisplay:SetAlpha(1)
        ordersRemainingDisplay:Show()
    end
    for _, child in ipairs(browseChildFrames) do
        child:Show()
    end
    for _, region in ipairs(browseTextRegions) do
        region:SetAlpha(1)
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- UI Creation
-- ────────────────────────────────────────────────────────────────────────────

local filterButtons = {}

local function CreateFilterToggle(parent, orderType, xOffset)
    local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    btn:SetSize(22, 22)
    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn:SetChecked(true)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", btn, "RIGHT", 2, 0)
    local color = TYPE_COLORS[orderType]
    label:SetText(color:WrapTextInColorCode(TYPE_LABELS[orderType]))

    btn:SetScript("OnClick", function(self)
        typeFilters[orderType] = self:GetChecked()
        ApplyFilters()
        Comfy:RefreshCraftingOrdersDisplay()
    end)

    btn._label = label
    filterButtons[orderType] = btn
    return btn, label:GetStringWidth() + 30
end

local function CreateSortButton(parent, text, sortKey, xOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(HEADER_HEIGHT)
    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", btn, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    btn._label = label

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("LEFT", label, "RIGHT", 2, 0)
    btn._arrow = arrow

    btn:SetScript("OnClick", function()
        if currentSort == sortKey then
            sortReversed = not sortReversed
        else
            currentSort = sortKey
            sortReversed = false
        end
        ApplyFilters()
        Comfy:RefreshCraftingOrdersDisplay()
    end)

    return btn
end

local function CreateComfyFrame()
    if comfyFrame then return comfyFrame end

    local ordersPage = ProfessionsFrame.OrdersPage
    local browse = ordersPage.BrowseFrame

    -- Parent inside BrowseFrame — we hide its children and fill its space directly.
    comfyFrame = CreateFrame("Frame", "ComfyCraftingOrdersFrame", browse)
    comfyFrame:SetAllPoints()
    comfyFrame:Hide()

    -- ── Top bar (offset below BrowseFrame's built-in title) ──
    local topBar = CreateFrame("Frame", nil, comfyFrame)
    topBar:SetPoint("TOPLEFT", comfyFrame, "TOPLEFT", 8, -36)
    topBar:SetPoint("TOPRIGHT", comfyFrame, "TOPRIGHT", -8, -36)
    topBar:SetHeight(22)

    local refreshBtn = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 20)
    refreshBtn:SetPoint("RIGHT", topBar, "RIGHT", 0, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() RequestAllOrders() end)
    comfyFrame.refreshBtn = refreshBtn

    local countText = topBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", refreshBtn, "LEFT", -10, 0)
    comfyFrame.countText = countText

    -- Orders remaining (public order claim limit) — left of count text
    local claimInfo = topBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    claimInfo:SetPoint("RIGHT", countText, "LEFT", -16, 0)
    comfyFrame.claimInfo = claimInfo

    -- ── Filter bar ──
    local filterBar = CreateFrame("Frame", nil, comfyFrame)
    filterBar:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", topBar, "BOTTOMRIGHT", 0, -2)
    filterBar:SetHeight(FILTER_BAR_HEIGHT)

    local filterLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("LEFT", filterBar, "LEFT", 4, 0)
    filterLabel:SetText("Show:")
    filterLabel:SetTextColor(0.7, 0.7, 0.7)

    local xOff = 42
    for _, ot in ipairs({
        Enum.CraftingOrderType.Npc,
        Enum.CraftingOrderType.Personal,
        Enum.CraftingOrderType.Guild,
        Enum.CraftingOrderType.Public,
    }) do
        local _, usedWidth = CreateFilterToggle(filterBar, ot, xOff)
        xOff = xOff + usedWidth + 16
    end

    -- "First Craft Only" toggle
    local fcBtn = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    fcBtn:SetSize(22, 22)
    fcBtn:SetPoint("LEFT", filterBar, "LEFT", xOff + 16, 0)
    fcBtn:SetChecked(false)
    local fcLabel = fcBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fcLabel:SetPoint("LEFT", fcBtn, "RIGHT", 2, 0)
    fcLabel:SetText(FIRST_CRAFT_COLOR:WrapTextInColorCode("First Craft Only"))
    fcBtn:SetScript("OnClick", function(self)
        ComfyDB.craftingOrdersFirstCraftOnly = self:GetChecked()
        ApplyFilters()
        Comfy:RefreshCraftingOrdersDisplay()
    end)
    comfyFrame.firstCraftOnlyBtn = fcBtn
    comfyFrame.filterBar = filterBar

    -- ── Column headers ──
    local headerRow = CreateFrame("Frame", nil, comfyFrame)
    headerRow:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -2)
    headerRow:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -2)
    headerRow:SetHeight(HEADER_HEIGHT)

    comfyFrame.colDefs = {
        { key = "type",    label = "Type",    width = 0.07, sort = nil },
        { key = "quality", label = "",        width = 0.03, sort = nil },
        { key = "recipe",  label = "Recipe",  width = 0.25, sort = SORT_NAME },
        { key = "patron",  label = "From",    width = 0.12, sort = nil },
        { key = "rewards", label = "Rewards", width = 0.28, sort = SORT_COMMISSION },
        { key = "reagents",label = "Reagents",width = 0.10, sort = nil },
        { key = "time",    label = "Time",    width = 0.10, sort = SORT_TIME },
    }

    comfyFrame.headerButtons = {}
    local hx = 4
    for i, col in ipairs(comfyFrame.colDefs) do
        if col.sort then
            local btn = CreateSortButton(headerRow, col.label, col.sort, hx)
            comfyFrame.headerButtons[i] = btn
        else
            local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", headerRow, "LEFT", hx, 0)
            fs:SetText(col.label)
            fs:SetTextColor(0.8, 0.7, 0.2)
            comfyFrame.headerButtons[i] = fs
        end
    end
    comfyFrame.headerRow = headerRow

    -- Separator
    local sep = comfyFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -1)
    sep:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, -1)
    sep:SetHeight(1)
    sep:SetColorTexture(0.4, 0.35, 0.15, 0.8)

    -- ── Scroll frame ──
    local scrollFrame = CreateFrame("ScrollFrame", nil, comfyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", comfyFrame, "BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    comfyFrame.scrollFrame = scrollFrame
    comfyFrame.content = content

    -- Empty state
    local emptyText = comfyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
    emptyText:SetText("No orders found.\nOpen a profession at a crafting station to see orders.")
    emptyText:Hide()
    comfyFrame.emptyText = emptyText

    -- Loading overlay (covers scroll area)
    local loadingFrame = CreateFrame("Frame", nil, comfyFrame)
    loadingFrame:SetPoint("TOPLEFT", scrollFrame)
    loadingFrame:SetPoint("BOTTOMRIGHT", scrollFrame)
    loadingFrame:SetFrameLevel(comfyFrame:GetFrameLevel() + 10)
    loadingFrame:Hide()

    local loadingText = loadingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    loadingText:SetPoint("CENTER", loadingFrame, "CENTER", 0, 10)
    loadingText:SetText("Loading orders...")

    local loadingBarBg = loadingFrame:CreateTexture(nil, "BACKGROUND")
    loadingBarBg:SetSize(200, 12)
    loadingBarBg:SetPoint("TOP", loadingText, "BOTTOM", 0, -8)
    loadingBarBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    local loadingBar = CreateFrame("StatusBar", nil, loadingFrame)
    loadingBar:SetSize(200, 12)
    loadingBar:SetPoint("TOP", loadingText, "BOTTOM", 0, -8)
    loadingBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    loadingBar:SetStatusBarColor(0.2, 0.8, 0.4)
    loadingBar:SetMinMaxValues(0, #typesToRequest)
    loadingBar:SetValue(0)

    comfyFrame.loadingFrame = loadingFrame
    comfyFrame.loadingText = loadingText
    comfyFrame.loadingBar = loadingBar

    -- F5 to refresh
    comfyFrame:EnableKeyboard(true)
    comfyFrame:SetScript("OnKeyDown", function(self, key)
        if key == "F5" then
            RequestAllOrders()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    return comfyFrame
end

-- ────────────────────────────────────────────────────────────────────────────
-- Row creation
-- ────────────────────────────────────────────────────────────────────────────

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.3, 0.3, 0.1, 0.3)

    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
    end

    row.typeText    = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.recipeName  = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.patronName  = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rewards     = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.reagents    = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timeLeft    = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    -- Quality tier icon (Texture widget, positioned in its own column)
    local qualityIcon = row:CreateTexture(nil, "OVERLAY")
    qualityIcon:SetSize(20, 20)
    qualityIcon:Hide()
    row.qualityIcon = qualityIcon

    row.typeText:SetJustifyH("LEFT")
    row.recipeName:SetJustifyH("LEFT")
    row.recipeName:SetWordWrap(false)
    row.patronName:SetJustifyH("LEFT")
    row.patronName:SetWordWrap(false)
    row.rewards:SetJustifyH("LEFT")
    row.rewards:SetWordWrap(false)
    row.reagents:SetJustifyH("CENTER")
    row.timeLeft:SetJustifyH("CENTER")

    -- Click: go to order detail via Blizzard's detail view
    row:SetScript("OnClick", function(self)
        if not self.orderData then return end
        local order = self.orderData
        local ordersPage = ProfessionsFrame.OrdersPage
        local browse = ordersPage.BrowseFrame

        if order._isBucket then
            -- For bucketed public orders, switch to Blizzard's public tab
            HideComfyUI()
            if browse.PublicOrdersButton then
                browse.PublicOrdersButton:Click()
            end
            return
        end

        -- Track which type we're viewing so we can selectively refresh on completion
        lastViewedOrderType = order.orderType

        -- Clean swap: restore Blizzard children and open detail view simultaneously
        HideComfyUI()
        if ordersPage.ViewOrder then
            ordersPage:ViewOrder(order)
        elseif ordersPage.SelectAndViewOrder then
            ordersPage:SelectAndViewOrder(order)
        end
    end)

    -- Tooltip
    row:SetScript("OnEnter", function(self)
        if not self.orderData then return end
        local order = self.orderData

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        if order.outputItemHyperlink then
            GameTooltip:SetHyperlink(order.outputItemHyperlink)
            GameTooltip:AddLine(" ")
        end

        if not IsLearned(order) then
            GameTooltip:AddLine("Recipe not learned", DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b)
        elseif IsFirstCraft(order) then
            GameTooltip:AddLine("First Craft — Skill Point Available", FIRST_CRAFT_COLOR.r, FIRST_CRAFT_COLOR.g, FIRST_CRAFT_COLOR.b)
        end

        GameTooltip:AddDoubleLine("Type:", TypePill(order.orderType), 0.7, 0.7, 0.7)

        if order.customerName then
            GameTooltip:AddDoubleLine("From:", order.customerName, 0.7, 0.7, 0.7, 1, 1, 1)
        end

        if order.tipAmount and order.tipAmount > 0 then
            GameTooltip:AddDoubleLine("Commission:", GetMoneyString(order.tipAmount), 0.7, 0.7, 0.7, 1, 0.82, 0)
        end

        if order.npcOrderRewards and #order.npcOrderRewards > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Patron Rewards:", 0.8, 0.7, 0.2)
            for _, reward in ipairs(order.npcOrderRewards) do
                if reward.itemLink then
                    local ct = (reward.count and reward.count > 1) and (" x" .. reward.count) or ""
                    GameTooltip:AddLine("  " .. reward.itemLink .. ct)
                elseif reward.currencyType then
                    local cInfo = C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
                    local name = cInfo and cInfo.name or ("Currency " .. reward.currencyType)
                    local icon = cInfo and cInfo.iconFileID and (FormatIcon(cInfo.iconFileID, 14) .. " ") or ""
                    local ct = (reward.count and reward.count > 0) and (" x" .. reward.count) or ""
                    GameTooltip:AddLine("  " .. icon .. name .. ct, 1, 1, 1)
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Reagents:", ReagentLabel(order.reagentState), 0.7, 0.7, 0.7)

        -- Reagent breakdown: use recipe schematic to show full list
        local custReagents, craftReagents = GetReagentBreakdown(order)
        if custReagents and #custReagents > 0 then
            GameTooltip:AddLine("  Provided:", 0.5, 0.8, 0.5)
            for _, entry in ipairs(custReagents) do
                GameTooltip:AddLine("    " .. entry, 0.7, 0.7, 0.7)
            end
        end
        if craftReagents and #craftReagents > 0 then
            GameTooltip:AddLine("  You provide:", 1, 0.5, 0.5)
            for _, entry in ipairs(craftReagents) do
                GameTooltip:AddLine("    " .. entry, 0.7, 0.7, 0.7)
            end
        end

        if order.expirationTime then
            GameTooltip:AddDoubleLine("Expires:", TimeRemainingString(order.expirationTime), 0.7, 0.7, 0.7, 1, 1, 1)
        end

        if order._isBucket and order.numAvailable then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Available:", order.numAvailable, 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddLine("Click to browse individual orders", 0.5, 0.5, 0.5)
        end

        if order.customerNotes and order.customerNotes ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Notes: " .. order.customerNotes, 0.8, 0.8, 0.8, true)
        end

        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

-- ────────────────────────────────────────────────────────────────────────────
-- Layout and display
-- ────────────────────────────────────────────────────────────────────────────

local function UpdateColumnPositions()
    if not comfyFrame then return end

    local totalWidth = comfyFrame.scrollFrame:GetWidth() - 4
    if totalWidth <= 0 then totalWidth = comfyFrame:GetWidth() - 44 end

    local cols = comfyFrame.colDefs
    local xOff = 4
    for i, col in ipairs(cols) do
        local w = totalWidth * col.width
        local hdr = comfyFrame.headerButtons[i]
        if hdr then
            if hdr.SetWidth then
                hdr:ClearAllPoints()
                hdr:SetPoint("LEFT", comfyFrame.headerRow, "LEFT", xOff, 0)
                hdr:SetWidth(w)
                if hdr._arrow then
                    if currentSort == col.sort then
                        hdr._arrow:SetText(sortReversed and " ▲" or " ▼")
                    else
                        hdr._arrow:SetText("")
                    end
                end
            elseif hdr.SetPoint then
                hdr:ClearAllPoints()
                hdr:SetPoint("LEFT", comfyFrame.headerRow, "LEFT", xOff, 0)
                hdr:SetWidth(w)
            end
        end

        local field = ROW_FIELDS[i]
        for _, row in ipairs(orderRows) do
            if field and row[field] then
                row[field]:ClearAllPoints()
                row[field]:SetPoint("LEFT", row, "LEFT", xOff, 0)
                row[field]:SetWidth(w - 4)
            end
        end

        xOff = xOff + w
    end
end

function Comfy:RefreshCraftingOrdersDisplay()
    if not comfyFrame then return end

    comfyFrame.countText:SetText(#filteredOrders .. " of " .. #allOrders .. " orders")

    -- Orders remaining — read from Blizzard's OrdersRemainingDisplay
    if comfyFrame.claimInfo and ordersRemainingDisplay then
        local text = nil
        -- Look for FontString children inside OrdersRemainingDisplay
        for _, region in ipairs({ordersRemainingDisplay:GetRegions()}) do
            if region:IsObjectType("FontString") then
                local t = region:GetText()
                if t and t ~= "" then
                    text = t
                    break
                end
            end
        end
        if text then
            comfyFrame.claimInfo:SetText(text)
        else
            comfyFrame.claimInfo:SetText("")
        end
    end

    -- Filter count badges
    local typeCounts = {}
    for _, order in ipairs(allOrders) do
        typeCounts[order.orderType] = (typeCounts[order.orderType] or 0) + 1
    end
    for ot, btn in pairs(filterButtons) do
        local count = typeCounts[ot] or 0
        local color = TYPE_COLORS[ot]
        btn._label:SetText(color:WrapTextInColorCode(TYPE_LABELS[ot]) .. " |cff888888(" .. count .. ")|r")
    end

    -- Smart empty state
    if #filteredOrders == 0 then
        if #allOrders == 0 then
            comfyFrame.emptyText:SetText("No orders found.\nOpen a profession at a crafting station to see orders.")
        else
            comfyFrame.emptyText:SetText("No orders match your current filters.\nTry enabling more order types above.")
        end
        comfyFrame.emptyText:Show()
    else
        comfyFrame.emptyText:Hide()
    end

    local content = comfyFrame.content
    for i, order in ipairs(filteredOrders) do
        if not orderRows[i] then
            orderRows[i] = CreateRow(content, i)
        end
        local row = orderRows[i]
        row.orderData = order

        row.typeText:SetText(TypePill(order.orderType))

        local name = order._displayName or "Unknown"
        if not order._isLearned then
            row.recipeName:SetText(DIM_COLOR:WrapTextInColorCode(name))
        elseif order._isFirstCraft then
            row.recipeName:SetText(FIRST_CRAFT_COLOR:WrapTextInColorCode(name))
        else
            row.recipeName:SetText(name)
        end

        -- Quality tier icon (Texture widget) — skip tier 1 since it's the minimum baseline
        local atlasName = GetQualityAtlas(order)
        if atlasName then
            row.qualityIcon:SetAtlas(atlasName, false)
            row.qualityIcon:Show()
        else
            row.qualityIcon:Hide()
        end

        if order.customerName then
            row.patronName:SetText(order.customerName)
        elseif order._isBucket and order.numAvailable then
            row.patronName:SetText(DIM_COLOR:WrapTextInColorCode(order.numAvailable .. " orders"))
        else
            row.patronName:SetText("---")
        end

        row.rewards:SetText(BuildRewardText(order))
        row.reagents:SetText(ReagentLabel(order.reagentState))

        if order.expirationTime then
            row.timeLeft:SetText(TimeRemainingString(order.expirationTime))
        else
            row.timeLeft:SetText("---")
        end

        row:Show()
    end

    for i = #filteredOrders + 1, #orderRows do
        orderRows[i]:Hide()
    end

    content:SetSize(
        comfyFrame.scrollFrame:GetWidth(),
        math.max(1, #filteredOrders * ROW_HEIGHT)
    )

    UpdateColumnPositions()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Expiration timer
-- ────────────────────────────────────────────────────────────────────────────

local refreshTicker

local function StartRefreshTimer()
    if refreshTicker then return end
    refreshTicker = C_Timer.NewTicker(60, function()
        if comfyFrame and comfyFrame:IsShown() and #filteredOrders > 0 then
            for _, row in ipairs(orderRows) do
                if row:IsShown() and row.orderData and row.orderData.expirationTime then
                    row.timeLeft:SetText(TimeRemainingString(row.orderData.expirationTime))
                end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Module init — hook Blizzard's Crafting Orders page
-- ────────────────────────────────────────────────────────────────────────────

local hooked = false

local function SetupHooks()
    if hooked then return end
    if not ProfessionsFrame or not ProfessionsFrame.OrdersPage then return end
    hooked = true

    CreateComfyFrame()
    StartRefreshTimer()

    local ordersPage = ProfessionsFrame.OrdersPage
    local browse = ordersPage.BrowseFrame

    -- Core hook: when BrowseFrame tries to show, intercept and show ours instead
    hooksecurefunc(browse, "Show", function()
        if ComfyDB.craftingOrdersAutoShow and comfyFrame and not comfyFrame:IsShown() then
            -- Let Blizzard finish its Show call, then immediately swap
            C_Timer.After(0, function()
                if browse:IsShown() and ordersPage:IsShown() then
                    ShowComfyUI(#allOrders > 0)
                end
            end)
        end
    end)

    -- When returning from order detail (SetupTable fires), re-show our UI with cached data
    if ordersPage.SetupTable then
        hooksecurefunc(ordersPage, "SetupTable", function()
            if ComfyDB.craftingOrdersAutoShow and comfyFrame then
                C_Timer.After(0.1, function()
                    if ordersPage:IsShown() then
                        -- If we just completed an order, invalidate that type
                        if lastViewedOrderType and ordersByType[lastViewedOrderType] then
                            ordersByType[lastViewedOrderType] = nil
                            wipe(allOrders)
                        end
                        lastViewedOrderType = nil
                        ShowComfyUI(true)
                    end
                end)
            end
        end)
    end

    -- Restore Blizzard's UI when leaving the orders tab entirely
    ordersPage:HookScript("OnHide", function()
        if comfyFrame and comfyFrame:IsShown() then
            HideComfyUI()
        end
    end)
end

function Comfy:InitCraftingOrders()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("TRADE_SKILL_SHOW")
    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_Professions" then
            C_Timer.After(0.3, SetupHooks)
        elseif event == "TRADE_SKILL_SHOW" then
            if ProfessionsFrame and ProfessionsFrame.OrdersPage then
                C_Timer.After(0.3, SetupHooks)
            end
        end
    end)

    if ProfessionsFrame and ProfessionsFrame.OrdersPage then
        C_Timer.After(0.3, SetupHooks)
    end
end
