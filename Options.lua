-- ============================================================
-- Interface Options / Settings panel
-- Registered under Game Menu → Interface → AddOns → AddonManager
-- ============================================================
local ROW_H = 26
local PAD   = 12

-- --------------------------------------------------------
-- Panel frame
-- --------------------------------------------------------
local panel = CreateFrame("Frame")
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetText("AddonManager")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetText("Save and switch between named addon sets.")

-- Open main window button
local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
openBtn:SetSize(160, 24)
openBtn:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
openBtn:SetText("Open AddonManager")
openBtn:SetScript("OnClick", function()
    AddonManager:ToggleUI()
end)

-- Auto zone switch toggle
local autoSwitchCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
autoSwitchCheck:SetSize(22, 22)
autoSwitchCheck:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -10)
if autoSwitchCheck.text then
    autoSwitchCheck.text:SetText("Prompt to switch addon set when entering an instance")
end
autoSwitchCheck:SetScript("OnClick", function(self)
    if AddonManager.db then
        AddonManager.db.options.autoSwitchEnabled = self:GetChecked()
    end
end)

-- Section header
local sectionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sectionLabel:SetPoint("TOPLEFT", autoSwitchCheck, "BOTTOMLEFT", 0, -12)
sectionLabel:SetText("Saved Sets")

-- --------------------------------------------------------
-- Scroll area for the set list
-- --------------------------------------------------------
local scrollFrame = CreateFrame("ScrollFrame", "AddonManagerOptionsScroll", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", sectionLabel, "BOTTOMLEFT", 0, -6)
scrollFrame:SetSize(700, 300)

local scrollChild = CreateFrame("Frame", "AddonManagerOptionsScrollChild", scrollFrame)
scrollChild:SetSize(680, 1)
scrollFrame:SetScrollChild(scrollChild)

-- --------------------------------------------------------
-- Save-current-state strip
-- --------------------------------------------------------
local saveLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
saveLabel:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -14)
saveLabel:SetText("Save Current State")

local nameBox = CreateFrame("EditBox", "AddonManagerOptionsNameBox", panel, "InputBoxTemplate")
nameBox:SetSize(200, 20)
nameBox:SetPoint("TOPLEFT", saveLabel, "BOTTOMLEFT", 0, -6)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(64)
nameBox:SetHintText("Set name...")

local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
saveBtn:SetSize(120, 24)
saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
saveBtn:SetText("Save Current")

local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
statusText:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
statusText:SetWidth(280)
statusText:SetJustifyH("LEFT")
statusText:SetText("")

-- --------------------------------------------------------
-- Build / rebuild the set list rows
-- --------------------------------------------------------
local setRows = {}

local function buildSetList()
    for _, row in ipairs(setRows) do
        row:Hide()
    end
    setRows = {}
    statusText:SetText("")

    local names = AddonManager:ListSets()
    local y = 0

    for _, name in ipairs(names) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(660, ROW_H)
        row:SetPoint("TOPLEFT", scrollChild, 0, -y)

        if (#setRows % 2 == 0) then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, 6, 0)
        label:SetText(name)

        -- Zone type badge
        if name ~= "Default" then
            local set = AddonManager:GetSet(name)
            local zt = set and set.zoneType
            if zt then
                local zoneBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                zoneBadge:SetPoint("LEFT", row, 220, 0)
                zoneBadge:SetText(AddonManager.ZONE_LABEL[zt] or zt)
                zoneBadge:SetTextColor(0.5, 0.8, 1, 1)
            end
        end

        local loadBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        loadBtn:SetSize(70, 20)
        loadBtn:SetPoint("RIGHT", row, "RIGHT", -84, 0)
        loadBtn:SetText("Load")
        loadBtn:SetScript("OnClick", function()
            -- reuse the StaticPopup defined in UI.lua
            if AddonManager.db.options.confirmOnSwitch then
                StaticPopup_Show("ADDONMANAGER_APPLY_CONFIRM", name, nil, name)
            else
                local err = AddonManager:ApplySet(name)
                if err then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffAddonManager:|r " .. err)
                end
            end
        end)

        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(70, 20)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        delBtn:SetText("Delete")
        delBtn:SetScript("OnClick", function()
            local err = AddonManager:DeleteSet(name)
            if err then
                statusText:SetText("|cffff4444" .. err .. "|r")
            else
                buildSetList()
            end
        end)

        setRows[#setRows + 1] = row
        y = y + ROW_H
    end

    if #names == 0 then
        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        empty:SetPoint("TOPLEFT", scrollChild, 6, 0)
        empty:SetText("No saved sets yet.")
        setRows[#setRows + 1] = empty
    end

    scrollChild:SetHeight(math.max(#names * ROW_H, 1))
end

-- --------------------------------------------------------
-- Save button
-- --------------------------------------------------------
saveBtn:SetScript("OnClick", function()
    local name = nameBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then
        statusText:SetText("|cffff4444Please enter a set name.|r")
        return
    end

    local function doSave()
        local err = AddonManager:SaveCurrentState(name)
        if err then
            statusText:SetText("|cffff4444" .. err .. "|r")
        else
            nameBox:SetText("")
            statusText:SetText("|cff00ff00Saved \"" .. name .. "\".|r")
            buildSetList()
        end
    end

    local function doOverwrite()
        local err = AddonManager:OverwriteSet(name)
        if err then
            statusText:SetText("|cffff4444" .. err .. "|r")
        else
            nameBox:SetText("")
            statusText:SetText("|cff00ff00Overwrote \"" .. name .. "\".|r")
            buildSetList()
        end
    end

    if AddonManager.db.sets[name] then
        AddonManager.pendingOverwrite = doOverwrite
        StaticPopup_Show("ADDONMANAGER_OVERWRITE_CONFIRM", name)
    else
        doSave()
    end
end)

nameBox:SetScript("OnEnterPressed", function()
    saveBtn:Click()
end)

-- --------------------------------------------------------
-- Refresh every time the panel is shown
-- --------------------------------------------------------
panel:SetScript("OnShow", function()
    if AddonManager.db then
        autoSwitchCheck:SetChecked(AddonManager.db.options.autoSwitchEnabled)
    end
    buildSetList()
end)

-- --------------------------------------------------------
-- Register with the Settings API (retail 10.x+)
-- Deferred to ADDON_LOADED so the Settings API is fully ready.
-- --------------------------------------------------------
local optionsCategory

local optionsLoader = CreateFrame("Frame")
optionsLoader:RegisterEvent("ADDON_LOADED")
optionsLoader:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "AddonManager" then return end
    self:UnregisterEvent("ADDON_LOADED")
    optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, "AddonManager")
    optionsCategory:SetID("AddonManager")
    Settings.RegisterAddOnCategory(optionsCategory)
end)

function AddonManager:OpenOptions()
    if optionsCategory then
        Settings.OpenToCategory(optionsCategory)
    end
end
