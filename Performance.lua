-- ============================================================
-- Addon memory tracking
-- ============================================================

local memData = {}  -- [addonName] = { current = KB, peak = KB }

local function sample()
    if not UpdateAddOnMemoryUsage then return end
    UpdateAddOnMemoryUsage()
    for _, name in ipairs(AddonManager:GetAllInstalledAddons()) do
        local kb = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(name)) or 0
        local d = memData[name]
        if not d then
            memData[name] = { current = kb, peak = kb }
        else
            d.current = kb
            if kb > d.peak then d.peak = kb end
        end
    end
end

-- Returns { current, peak } in KB, or nil if not yet sampled.
function AddonManager:GetAddonMemory(name)
    return memData[name]
end

-- Returns total current memory in KB for all addons in the given set.
-- "Default" sums all installed addons.
function AddonManager:GetSetMemoryTotal(setName)
    local total = 0
    if setName == "Default" then
        for _, name in ipairs(self:GetAllInstalledAddons()) do
            local d = memData[name]
            if d then total = total + d.current end
        end
    else
        local set = self:GetSet(setName)
        if not set then return 0 end
        for name in pairs(set.addons) do
            local d = memData[name]
            if d then total = total + d.current end
        end
    end
    return total
end

-- Immediately sample memory (called when opening the UI).
function AddonManager:SampleMemory()
    sample()
end

-- Also sample automatically on zone changes and after leaving combat.
local perfFrame = CreateFrame("Frame")
perfFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
perfFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
perfFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
perfFrame:SetScript("OnEvent", function()
    if AddonManager.db and AddonManager.db.options.memoryTrackingEnabled then
        C_Timer.After(1, sample)
    end
end)
