-- ============================================================
-- Constants
-- ============================================================
local FRAME_W, FRAME_H   = 700, 500
local PANEL_LEFT_W       = 200
local ROW_H              = 22
local PAD                = 10

-- ============================================================
-- Helpers
-- ============================================================
local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffAddonManager:|r " .. tostring(msg))
end

-- ============================================================
-- Main frame (built lazily on first open)
-- ============================================================
local mainFrame

local function createMainFrame()
    if mainFrame then return end

    -- Root frame
    local f = CreateFrame("Frame", "AddonManagerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    mainFrame = f

    if f.TitleText then f.TitleText:SetText("AddonManager") end

    -- --------------------------------------------------------
    -- Left panel: set list
    -- --------------------------------------------------------
    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -28)
    leftPanel:SetSize(PANEL_LEFT_W, FRAME_H - 60)

    local setListLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    setListLabel:SetPoint("TOPLEFT", leftPanel, PAD, -PAD)
    setListLabel:SetText("SAVED SETS")

    -- ScrollFrame for the set list
    local setScroll = CreateFrame("ScrollFrame", "AddonManagerSetScroll", leftPanel, "UIPanelScrollFrameTemplate")
    setScroll:SetPoint("TOPLEFT", setListLabel, "BOTTOMLEFT", 0, -4)
    setScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -28, 60)

    local setContent = CreateFrame("Frame", "AddonManagerSetContent", setScroll)
    setContent:SetSize(PANEL_LEFT_W - 30, 1)
    setScroll:SetScrollChild(setContent)

    -- Buttons at the bottom of the left panel
    local loadBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    loadBtn:SetSize(80, 22)
    loadBtn:SetPoint("BOTTOMLEFT", leftPanel, PAD, PAD)
    loadBtn:SetText("Load")
    loadBtn:Disable()

    local deleteBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    deleteBtn:SetSize(80, 22)
    deleteBtn:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -4, PAD)
    deleteBtn:SetText("Delete")
    deleteBtn:Disable()

    -- --------------------------------------------------------
    -- Divider
    -- --------------------------------------------------------
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetSize(1, FRAME_H - 60)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", PANEL_LEFT_W + 4, -28)
    divider:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- --------------------------------------------------------
    -- Right panel: addon checklist
    -- --------------------------------------------------------
    local rightPanel = CreateFrame("Frame", nil, f)
    rightPanel:SetPoint("TOPLEFT", f, "TOPLEFT", PANEL_LEFT_W + 8, -28)
    rightPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)

    local addonListLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonListLabel:SetPoint("TOPLEFT", rightPanel, PAD, -PAD)
    addonListLabel:SetText("ADDONS  (check to include in set)")

    -- ScrollFrame for addon checkboxes
    local addonScroll = CreateFrame("ScrollFrame", "AddonManagerAddonScroll", rightPanel, "UIPanelScrollFrameTemplate")
    addonScroll:SetPoint("TOPLEFT", addonListLabel, "BOTTOMLEFT", 0, -4)
    addonScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -28, 80)

    local addonContent = CreateFrame("Frame", "AddonManagerAddonContent", addonScroll)
    addonContent:SetSize(FRAME_W - PANEL_LEFT_W - 50, 1)
    addonScroll:SetScrollChild(addonContent)

    -- Save strip at the bottom of the right panel
    local nameLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("BOTTOMLEFT", rightPanel, PAD, 52)
    nameLabel:SetText("Set Name:")

    local nameBox = CreateFrame("EditBox", "AddonManagerNameBox", rightPanel, "InputBoxTemplate")
    nameBox:SetSize(160, 20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(64)

    local saveBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 22)
    saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    saveBtn:SetText("Save Current")

    local statusText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", rightPanel, PAD, PAD + 8)
    statusText:SetWidth(FRAME_W - PANEL_LEFT_W - 20)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    -- --------------------------------------------------------
    -- Confirm-reload dialog
    -- --------------------------------------------------------
    local confirmDialog = CreateFrame("Frame", "AddonManagerConfirmDialog", UIParent, "BasicFrameTemplate")
    confirmDialog:SetSize(360, 130)
    confirmDialog:SetPoint("CENTER")
    confirmDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    confirmDialog:Hide()
    if confirmDialog.TitleText then confirmDialog.TitleText:SetText("Confirm Reload") end

    local confirmText = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirmText:SetPoint("TOP", confirmDialog, "TOP", 0, -36)
    confirmText:SetWidth(320)
    confirmText:SetJustifyH("CENTER")
    confirmText:SetText("")
    confirmDialog.confirmText = confirmText

    local yesBtn = CreateFrame("Button", nil, confirmDialog, "UIPanelButtonTemplate")
    yesBtn:SetSize(100, 24)
    yesBtn:SetPoint("BOTTOMLEFT", confirmDialog, "BOTTOM", -54, 14)
    yesBtn:SetText("Reload Now")

    local noBtn = CreateFrame("Button", nil, confirmDialog, "UIPanelButtonTemplate")
    noBtn:SetSize(100, 24)
    noBtn:SetPoint("BOTTOMRIGHT", confirmDialog, "BOTTOM", 54, 14)
    noBtn:SetText("Cancel")
    noBtn:SetScript("OnClick", function() confirmDialog:Hide() end)

    -- --------------------------------------------------------
    -- State
    -- --------------------------------------------------------
    local selectedSet   = nil   -- currently highlighted set name
    local checkboxes    = {}    -- addonName -> CheckButton

    -- --------------------------------------------------------
    -- Populate addon checklist
    -- --------------------------------------------------------
    local function buildAddonList(filterSet)
        -- filterSet: if provided, pre-check only the addons in that set
        --            if nil, reflect current live enable state
        for _, cb in pairs(checkboxes) do
            cb:Hide()
            cb:ClearAllPoints()
        end
        checkboxes = {}

        local player = UnitName("player")
        local addons = AddonManager:GetAllInstalledAddons()
        local y = 0

        for _, addonName in ipairs(addons) do
            local cb = CreateFrame("CheckButton", nil, addonContent, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", addonContent, 4, -y)

            -- UICheckButtonTemplate provides cb.text positioned to the right of the box
            if cb.text then
                cb.text:SetText(addonName)
            end

            if filterSet then
                local set = AddonManager:GetSet(filterSet)
                cb:SetChecked(set and set.addons[addonName] == true)
            else
                local state = C_AddOns.GetAddOnEnableState(addonName, player)
                cb:SetChecked(state > 0)
            end

            checkboxes[addonName] = cb
            y = y + ROW_H
        end

        addonContent:SetHeight(math.max(y, 1))
    end

    -- --------------------------------------------------------
    -- Populate set list
    -- --------------------------------------------------------
    local setRows = {}

    local function buildSetList()
        for _, row in ipairs(setRows) do row:Hide() end
        setRows = {}

        local names = AddonManager:ListSets()
        local y = 0

        for _, name in ipairs(names) do
            local row = CreateFrame("Button", nil, setContent)
            row:SetSize(PANEL_LEFT_W - 32, ROW_H)
            row:SetPoint("TOPLEFT", setContent, 0, -y)

            local highlight = row:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.2, 0.5, 1, 0.3)
            highlight:Hide()
            row.highlight = highlight

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", row, 4, 0)
            label:SetText(name)
            row.label = label

            row:SetScript("OnClick", function()
                selectedSet = name
                for _, r in ipairs(setRows) do r.highlight:Hide() end
                highlight:Show()
                buildAddonList(name)
                loadBtn:Enable()
                deleteBtn:Enable()
            end)

            setRows[#setRows + 1] = row
            y = y + ROW_H
        end

        setContent:SetHeight(math.max(y, 1))
    end

    -- --------------------------------------------------------
    -- Load button
    -- --------------------------------------------------------
    loadBtn:SetScript("OnClick", function()
        if not selectedSet then return end
        local setName = selectedSet
        if AddonManager.db.options.confirmOnSwitch then
            confirmDialog.confirmText:SetText(
                "Switch to set \"" .. setName .. "\"?\nThis will reload the UI."
            )
            yesBtn:SetScript("OnClick", function()
                confirmDialog:Hide()
                local err = AddonManager:ApplySet(setName)
                if err then print(err) end
            end)
            confirmDialog:Show()
        else
            local err = AddonManager:ApplySet(setName)
            if err then print(err) end
        end
    end)

    -- --------------------------------------------------------
    -- Delete button
    -- --------------------------------------------------------
    deleteBtn:SetScript("OnClick", function()
        if not selectedSet then return end
        local err = AddonManager:DeleteSet(selectedSet)
        if err then
            statusText:SetText("|cffff4444" .. err .. "|r")
        else
            statusText:SetText("Deleted set \"" .. selectedSet .. "\".")
            selectedSet = nil
            loadBtn:Disable()
            deleteBtn:Disable()
            buildSetList()
            buildAddonList(nil)
            AddonManager:RebuildPicker()
        end
    end)

    -- --------------------------------------------------------
    -- Save button
    -- --------------------------------------------------------
    saveBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():match("^%s*(.-)%s*$")  -- trim whitespace
        if name == "" then
            statusText:SetText("|cffff4444Please enter a set name.|r")
            return
        end

        -- Build the addons table from current checkbox state
        local db = AddonManager.db
        if db.sets[name] then
            statusText:SetText("|cffff4444A set named \"" .. name .. "\" already exists.|r")
            return
        end

        local addons = {}
        for addonName, cb in pairs(checkboxes) do
            if cb:GetChecked() then
                addons[addonName] = true
            end
        end

        db.sets[name] = { name = name, addons = addons }
        nameBox:SetText("")
        statusText:SetText("|cff00ff00Saved set \"" .. name .. "\".|r")
        buildSetList()
        AddonManager:RebuildPicker()
    end)

    -- --------------------------------------------------------
    -- OnShow: refresh everything
    -- --------------------------------------------------------
    f:SetScript("OnShow", function()
        selectedSet = nil
        loadBtn:Disable()
        deleteBtn:Disable()
        statusText:SetText("")
        buildSetList()
        buildAddonList(nil)
    end)

    -- Store refs for slash command use
    f.buildSetList  = buildSetList
    f.buildAddonList = buildAddonList
end

-- ============================================================
-- Dropdown picker  (anchor button always on screen; click toggles list)
-- ============================================================
local PICK_W     = 160
local PICK_ROW_H = 22

local pickerAnchor
local pickerDropdown
local pickerRows    = {}
local pickerIsOpen  = false

-- StaticPopup for the reload confirmation
StaticPopupDialogs["ADDONMANAGER_APPLY_CONFIRM"] = {
    text       = "Switch to addon set \"%s\"?\nThis will reload the UI.",
    button1    = "Reload Now",
    button2    = "Cancel",
    OnAccept   = function(_, setName)
        local err = AddonManager:ApplySet(setName)
        if err then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffAddonManager:|r " .. err)
        end
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

local function pickerApply(name)
    if AddonManager.db and AddonManager.db.options.confirmOnSwitch then
        StaticPopup_Show("ADDONMANAGER_APPLY_CONFIRM", name, nil, name)
    else
        local err = AddonManager:ApplySet(name)
        if err then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffAddonManager:|r " .. err)
        end
    end
end

local function closeDropdown()
    if pickerDropdown then pickerDropdown:Hide() end
    pickerIsOpen = false
    if pickerAnchor then pickerAnchor:SetText("Addon Sets  ▼") end
end

local function openDropdown()
    -- rebuild rows
    for _, row in ipairs(pickerRows) do row:Hide() end
    pickerRows = {}

    local names = AddonManager:ListSets()
    local y = -4

    for _, name in ipairs(names) do
        local row = CreateFrame("Button", nil, pickerDropdown)
        row:SetSize(PICK_W - 8, PICK_ROW_H)
        row:SetPoint("TOPLEFT", pickerDropdown, 4, y)
        row:Show()

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.2, 0.5, 1, 0.3)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", row, 6, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(name == "Default" and "|cffffcc00" .. name .. "|r" or name)

        row:SetScript("OnClick", function()
            closeDropdown()
            pickerApply(name)
        end)

        pickerRows[#pickerRows + 1] = row
        y = y - PICK_ROW_H
    end

    pickerDropdown:SetHeight(math.abs(y) + 4)
    pickerDropdown:ClearAllPoints()
    pickerDropdown:SetPoint("TOPLEFT", pickerAnchor, "BOTTOMLEFT", 0, -2)
    pickerDropdown:Show()
    pickerIsOpen = true
    pickerAnchor:SetText("Addon Sets  ▲")
end

local function createPicker()
    if pickerAnchor then return end

    -- Anchor button (always on screen)
    local btn = CreateFrame("Button", "AddonManagerPickerAnchor", UIParent, "UIPanelButtonTemplate")
    btn:SetSize(PICK_W, 24)
    btn:SetText("Addon Sets  ▼")
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetClampedToScreen(true)
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        closeDropdown()
        local point, _, relPoint, x, y = self:GetPoint()
        if AddonManager.db then
            AddonManager.db.pickerPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    btn:SetScript("OnClick", function()
        if pickerIsOpen then closeDropdown() else openDropdown() end
    end)

    -- Restore saved position or default
    local pos = AddonManager.db and AddonManager.db.pickerPos
    if pos then
        btn:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        btn:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end

    pickerAnchor = btn

    -- Dropdown panel
    local d = CreateFrame("Frame", "AddonManagerPickerDropdown", UIParent, "BackdropTemplate")
    d:SetWidth(PICK_W)
    d:SetFrameStrata("DIALOG")
    d:SetClampedToScreen(true)
    d:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    d:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    d:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    d:Hide()
    pickerDropdown = d
end

function AddonManager:ShowPicker()
    createPicker()
    pickerAnchor:Show()
end

function AddonManager:RebuildPicker()
    if pickerIsOpen then openDropdown() end
end

-- ============================================================
-- Public toggle
-- ============================================================
function AddonManager:ToggleUI()
    createMainFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_ADDONMANAGER1 = "/addonmanager"
SLASH_ADDONMANAGER2 = "/am"

SlashCmdList["ADDONMANAGER"] = function(input)
    local cmd, rest = input:match("^(%S*)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "show" then
        AddonManager:ToggleUI()

    elseif cmd == "list" then
        local names = AddonManager:ListSets()
        if #names == 0 then
            print("No saved sets.")
        else
            print("Saved sets:")
            for _, name in ipairs(names) do
                print("  " .. name)
            end
        end

    elseif cmd == "save" then
        local name = rest:match("^%s*(.-)%s*$")
        if name == "" then
            print("Usage: /am save <name>")
            return
        end
        local err = AddonManager:SaveCurrentState(name)
        if err then print(err) else print("Saved set \"" .. name .. "\".") end

    elseif cmd == "load" then
        local name = rest:match("^%s*(.-)%s*$")
        if name == "" then
            print("Usage: /am load <name>")
            return
        end
        local err = AddonManager:ApplySet(name)
        if err then print(err) end

    elseif cmd == "delete" or cmd == "del" then
        local name = rest:match("^%s*(.-)%s*$")
        if name == "" then
            print("Usage: /am delete <name>")
            return
        end
        local err = AddonManager:DeleteSet(name)
        if err then print(err) else print("Deleted set \"" .. name .. "\".") end

    elseif cmd == "rename" then
        local oldName, newName = rest:match("^%s*(.-)%s+(.-)%s*$")
        if not oldName or oldName == "" or not newName or newName == "" then
            print("Usage: /am rename <oldname> <newname>")
            return
        end
        local err = AddonManager:RenameSet(oldName, newName)
        if err then print(err) else print("Renamed \"" .. oldName .. "\" to \"" .. newName .. "\".") end

    elseif cmd == "pick" then
        AddonManager:ShowPicker()

    elseif cmd == "options" or cmd == "config" then
        AddonManager:OpenOptions()

    elseif cmd == "help" then
        print("/am               — toggle UI")
        print("/am pick          — toggle quick-pick window")
        print("/am options       — open settings panel")
        print("/am list          — list saved sets")
        print("/am save <name>   — save current addon state as a named set")
        print("/am load <name>   — apply a set and reload UI")
        print("/am delete <name> — delete a set")
        print("/am rename <old> <new> — rename a set")

    else
        print("Unknown command. Type /am help for usage.")
    end
end
