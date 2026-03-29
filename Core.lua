AddonManager = {}
AddonManager.CURRENT_VERSION = 1

-- Zone type definitions shared across all modules
AddonManager.ZONE_TYPES = {
    { value = "raid",    label = "Raid" },
    { value = "dungeon", label = "Dungeon" },
    { value = "pvp",     label = "Battleground" },
    { value = "arena",   label = "Arena" },
}

AddonManager.ZONE_LABEL = {}
for _, zt in ipairs(AddonManager.ZONE_TYPES) do
    AddonManager.ZONE_LABEL[zt.value] = zt.label
end

-- Maps WoW GetInstanceInfo() instanceType → our zone type key
AddonManager.INSTANCE_TO_ZONE = {
    raid  = "raid",
    party = "dungeon",
    pvp   = "pvp",
    arena = "arena",
}

local defaults = {
    sets = {},
    options = {
        confirmOnSwitch   = true,
        autoSwitchEnabled = true,
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
        AddonManagerDB.version = AddonManager.CURRENT_VERSION
    end

    -- ensure required keys exist for older saved data
    if not AddonManagerDB.sets then AddonManagerDB.sets = {} end
    if not AddonManagerDB.options then AddonManagerDB.options = CopyTable(defaults.options) end
    if AddonManagerDB.options.autoSwitchEnabled == nil then
        AddonManagerDB.options.autoSwitchEnabled = true
    end
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

-- Checks if the current instance has a set assigned and prompts to switch.
function AddonManager:CheckZoneSwitch()
    if not self.db or not self.db.options.autoSwitchEnabled then return end
    local _, instanceType = GetInstanceInfo()
    local zoneType = self.INSTANCE_TO_ZONE[instanceType]
    if not zoneType then return end
    local setName = self:GetSetForZoneType(zoneType)
    if not setName then return end
    if self.db.lastAppliedSet == setName then return end
    local label = self.ZONE_LABEL[zoneType] or zoneType
    StaticPopup_Show("ADDONMANAGER_ZONE_SWITCH", label, setName, setName)
end

local pickerShown = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "AddonManager" then
            initDB()
            AddonManager.db = AddonManagerDB
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if not pickerShown then
            AddonManager:ShowPicker()
            pickerShown = true
        end
        if not isInitialLogin and not isReloadingUi then
            AddonManager:CheckZoneSwitch()
        end
    end
end)
