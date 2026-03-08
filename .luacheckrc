std = "lua51"
max_line_length = false
codes = true
self = false

exclude_files = {
    ".release",
    ".luarocks",
}

ignore = {
    "122", -- Setting read-only global (addon namespace creation)
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Value assigned to variable is unused
    "432", -- Shadowing upvalue argument (common pattern for self in callbacks)
    "542", -- Empty if branch
}

globals = {
    -- Addon namespace
    "ComfyDB",

    -- Slash commands
    "SlashCmdList",
    "SLASH_COMFY1",
    "SLASH_COMFY2",
}

read_globals = {
    -- Lua standard
    "table",
    "string",
    "math",
    "pairs",
    "ipairs",
    "type",
    "tostring",
    "tonumber",
    "select",
    "unpack",
    "print",
    "getmetatable",
    "setmetatable",
    "rawget",
    "rawset",
    "next",
    "error",
    "pcall",
    "xpcall",
    "_G",
    "time",
    "date",
    "format",
    "wipe",
    "tinsert",
    "tremove",
    "strsplit",
    "hooksecurefunc",

    -- WoW API - Frames
    "CreateFrame",
    "UIParent",
    "Minimap",
    "GameTooltip",
    "PlayerFrame",
    "Settings",
    "MenuUtil",
    "GetCursorPosition",
    "CreateColor",

    -- WoW API - Combat
    "InCombatLockdown",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsShiftKeyDown",

    -- WoW API - Crafting
    "C_CraftingOrders",
    "C_TradeSkillUI",
    "C_Timer",
    "C_Item",
    "C_Texture",
    "Enum",
    "ProfessionsFrame",

    -- WoW API - Other
    "GameTooltip_SetDefaultAnchor",
    "GetItemInfo",
    "C_CurrencyInfo",
    "StaticPopupDialogs",
    "StaticPopup_Show",
    "MinimalSliderWithSteppersMixin",
    "UISpecialFrames",
    "ITEM_QUALITY_COLORS",
    "SecondsToTime",
    "GetServerTime",
}
