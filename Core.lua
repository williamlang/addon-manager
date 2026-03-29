AddonManager = {}
AddonManager.CURRENT_VERSION = 1

local defaults = {
    sets = {},
    options = {
        confirmOnSwitch = true,
    },
    version = 1,
}

local function initDB()
    if not AddonManagerDB then
        AddonManagerDB = CopyTable(defaults)
        return
    end

    -- schema migration
    if not AddonManagerDB.version or AddonManagerDB.version < AddonManager.CURRENT_VERSION then
        -- future migrations go here
        AddonManagerDB.version = AddonManager.CURRENT_VERSION
    end

    -- ensure required keys exist for older saved data
    if not AddonManagerDB.sets then AddonManagerDB.sets = {} end
    if not AddonManagerDB.options then AddonManagerDB.options = CopyTable(defaults.options) end
end

-- Returns a list of all installed addon names, excluding AddonManager itself
-- and all Blizzard_ built-in addons.
function AddonManager:GetAllInstalledAddons()
    local list = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "AddonManager" and not name:find("^Blizzard_") then
            list[#list + 1] = name
        end
    end
    return list
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == "AddonManager" then
        initDB()
        AddonManager.db = AddonManagerDB
        frame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        AddonManager:ShowPicker()
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
