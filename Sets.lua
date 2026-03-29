local DEFAULT_SET = "Default"

local function getDB()
    return AddonManager.db
end

-- Returns true if the name is a reserved built-in set.
local function isReserved(name)
    return name == DEFAULT_SET
end

-- Returns true if a set name is valid (non-empty, safe characters).
local function isValidName(name)
    return type(name) == "string"
        and #name > 0
        and #name <= 64
        and not name:find("[^%w%s%-_]")
end

-- Snapshots the currently enabled addons into a new named set.
-- Returns nil on success, or an error string.
function AddonManager:SaveCurrentState(name)
    if isReserved(name) then
        return "\"" .. name .. "\" is a reserved set name."
    end
    if not isValidName(name) then
        return "Invalid set name. Use letters, numbers, spaces, hyphens, and underscores only."
    end

    local db = getDB()
    if db.sets[name] then
        return "A set named \"" .. name .. "\" already exists."
    end

    local player = UnitName("player")
    local addons = {}
    for _, addonName in ipairs(self:GetAllInstalledAddons()) do
        local state = C_AddOns.GetAddOnEnableState(addonName, player)
        if state > 0 then
            addons[addonName] = true
        end
    end

    db.sets[name] = {
        name   = name,
        addons = addons,
    }
    return nil
end

-- Overwrites an existing set with the current addon state.
-- Returns nil on success, or an error string.
function AddonManager:OverwriteSet(name)
    if isReserved(name) then
        return "\"" .. name .. "\" is a reserved set and cannot be overwritten."
    end
    if not isValidName(name) then
        return "Invalid set name."
    end

    local db = getDB()
    if not db.sets[name] then
        return "Set \"" .. name .. "\" does not exist."
    end

    local player = UnitName("player")
    local addons = {}
    for _, addonName in ipairs(self:GetAllInstalledAddons()) do
        local state = C_AddOns.GetAddOnEnableState(addonName, player)
        if state > 0 then
            addons[addonName] = true
        end
    end

    db.sets[name].addons = addons
    return nil
end

-- Deletes a named set. Returns nil on success, or an error string.
function AddonManager:DeleteSet(name)
    if isReserved(name) then
        return "\"" .. name .. "\" is a reserved set and cannot be deleted."
    end
    local db = getDB()
    if not db.sets[name] then
        return "Set \"" .. name .. "\" does not exist."
    end
    db.sets[name] = nil
    return nil
end

-- Renames a set. Returns nil on success, or an error string.
function AddonManager:RenameSet(oldName, newName)
    if isReserved(oldName) then
        return "\"" .. oldName .. "\" is a reserved set and cannot be renamed."
    end
    if isReserved(newName) then
        return "\"" .. newName .. "\" is a reserved set name."
    end
    if not isValidName(newName) then
        return "Invalid set name. Use letters, numbers, spaces, hyphens, and underscores only."
    end

    local db = getDB()
    if not db.sets[oldName] then
        return "Set \"" .. oldName .. "\" does not exist."
    end
    if db.sets[newName] then
        return "A set named \"" .. newName .. "\" already exists."
    end

    db.sets[newName] = db.sets[oldName]
    db.sets[newName].name = newName
    db.sets[oldName] = nil
    return nil
end

-- Returns a sorted list of set names, with Default always first.
function AddonManager:ListSets()
    local db = getDB()
    local names = {}
    for name in pairs(db.sets) do
        names[#names + 1] = name
    end
    table.sort(names)
    table.insert(names, 1, DEFAULT_SET)
    return names
end

-- Returns the set table for a given name, or nil.
-- Default is virtual and has no stored table.
function AddonManager:GetSet(name)
    if isReserved(name) then return nil end
    return getDB().sets[name]
end

-- Returns the set name assigned to a given zone type, or nil.
function AddonManager:GetSetForZoneType(zoneType)
    for name, set in pairs(getDB().sets) do
        if set.zoneType == zoneType then
            return name
        end
    end
    return nil
end

-- Assigns a zone type to a set (1-to-1: clears it from any other set first).
-- Pass nil zoneType to clear the assignment from this set.
-- Returns nil on success, or an error string.
function AddonManager:SetZoneType(setName, zoneType)
    if isReserved(setName) then
        return "Cannot assign a zone type to the Default set."
    end
    local db = getDB()
    if not db.sets[setName] then
        return "Set \"" .. setName .. "\" does not exist."
    end
    -- Enforce 1-to-1: clear this zone type from any other set
    if zoneType then
        for _, set in pairs(db.sets) do
            if set.zoneType == zoneType then
                set.zoneType = nil
            end
        end
    end
    db.sets[setName].zoneType = zoneType
    return nil
end

-- Returns two lists: valid addon names and missing addon names
-- for the given set (addons that are no longer installed).
function AddonManager:ValidateSet(name)
    local set = self:GetSet(name)
    if not set then return nil, nil end

    local installed = {}
    for _, addonName in ipairs(self:GetAllInstalledAddons()) do
        installed[addonName] = true
    end

    local valid, missing = {}, {}
    for addonName in pairs(set.addons) do
        if installed[addonName] then
            valid[#valid + 1] = addonName
        else
            missing[#missing + 1] = addonName
        end
    end
    table.sort(valid)
    table.sort(missing)
    return valid, missing
end

-- Applies a set: disables all addons, enables only those in the set,
-- saves, and reloads. Missing addons are skipped silently.
-- "Default" enables all installed addons.
-- Returns nil on success, or an error string if the set doesn't exist.
function AddonManager:ApplySet(name)
    local player = UnitName("player")

    if isReserved(name) then
        -- Default: enable everything
        for _, addonName in ipairs(self:GetAllInstalledAddons()) do
            C_AddOns.EnableAddOn(addonName, player)
        end
        C_AddOns.EnableAddOn("AddonManager", player)
        C_AddOns.SaveAddOns()
        ReloadUI()
        return nil
    end

    local set = self:GetSet(name)
    if not set then
        return "Set \"" .. name .. "\" does not exist."
    end

    for _, addonName in ipairs(self:GetAllInstalledAddons()) do
        C_AddOns.DisableAddOn(addonName, player)
    end

    for addonName in pairs(set.addons) do
        local installedName = C_AddOns.GetAddOnInfo(addonName)
        if installedName then
            C_AddOns.EnableAddOn(addonName, player)
        else
            set.addons[addonName] = nil
        end
    end

    -- Always keep AddonManager itself enabled regardless of what the set contains.
    C_AddOns.EnableAddOn("AddonManager", player)

    C_AddOns.SaveAddOns()
    ReloadUI()
end
