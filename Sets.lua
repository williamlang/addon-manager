local function getDB()
    return AddonManager.db
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
    local db = getDB()
    if not db.sets[name] then
        return "Set \"" .. name .. "\" does not exist."
    end
    db.sets[name] = nil
    return nil
end

-- Renames a set. Returns nil on success, or an error string.
function AddonManager:RenameSet(oldName, newName)
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

-- Returns a sorted list of set names.
function AddonManager:ListSets()
    local db = getDB()
    local names = {}
    for name in pairs(db.sets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- Returns the set table for a given name, or nil.
function AddonManager:GetSet(name)
    return getDB().sets[name]
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
-- Returns nil on success, or an error string if the set doesn't exist.
function AddonManager:ApplySet(name)
    local set = self:GetSet(name)
    if not set then
        return "Set \"" .. name .. "\" does not exist."
    end

    local player = UnitName("player")

    for _, addonName in ipairs(self:GetAllInstalledAddons()) do
        C_AddOns.DisableAddOn(addonName, player)
    end

    for addonName in pairs(set.addons) do
        -- GetAddOnInfo returns nil for the name if the addon isn't installed
        local installedName = C_AddOns.GetAddOnInfo(addonName)
        if installedName then
            C_AddOns.EnableAddOn(addonName, player)
        end
    end

    -- Always keep AddonManager itself enabled regardless of what the set contains.
    C_AddOns.EnableAddOn("AddonManager", player)

    C_AddOns.SaveAddOns()
    ReloadUI()
end
