local addonName, addon = ...
local installed = false
local eventFrame = CreateFrame("Frame")

local function InstallTab()
    local settings = CooldownViewerSettings
    if installed or not settings or not settings.CooldownScroll
        or type(settings.SetDisplayMode) ~= "function" then
        return
    end

    installed = true

    -- Keep our page outside Blizzard's TabButtons and displayMode tables:
    -- Blizzard's SetDisplayMode only accepts its own predefined categories.
    local panel = CreateFrame("Frame", nil, settings)
    panel:SetAllPoints(settings.CooldownScroll)
    panel:Hide()

    -- Own the scrolling surface so native layout callbacks never see addon content.
    panel:SetFrameLevel(settings:GetFrameLevel() + 10)
    panel:EnableMouse(true)
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(panel)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.08, 0.08, 0.08, 1)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetAllPoints(panel)
    local nativeScrollBar = settings.CooldownScroll.ScrollBar
    if nativeScrollBar and scroll.ScrollBar then
        scroll.ScrollBar:ClearAllPoints()
        scroll.ScrollBar:SetAllPoints(nativeScrollBar)
    end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 1)
    scroll:SetScrollChild(content)
    local RefreshRows

    local function Checkbox(label, onClick)
        local button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", button, "RIGHT", 2, 0)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        button.label = text
        button:SetScript("OnClick", function(self)
            onClick(self:GetChecked())
            if RefreshRows then RefreshRows() end
        end)
        return button
    end

    local themeToggle = Checkbox("Use retro icon style", function(checked)
        local db = addon.Buffs:GetDB()
        db.classAuraStyle = checked == true
        db.compact, db.iconZoom = db.classAuraStyle, db.classAuraStyle
        addon.IconStyle:SetEnabled(checked)
        addon.Compact:SetEnabled(checked)
    end)
    local swingToggle = Checkbox("Integrated swing timer spark", function(checked)
        addon.Compact:SetSparksEnabled(checked)
    end)
    swingToggle:SetMotionScriptsWhileDisabled(true)
    swingToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:IsEnabled()
            and "Show weapon swing progress as a spark across spell icons."
            or "Add at least 3 Essential or Utility icons to enable the spark.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    swingToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local combatToggle = Checkbox("Hide essential cooldowns outside combat", function(checked)
        addon.Cooldowns:SetOnlyCombat(checked)
    end)
    local utilityCombatToggle = Checkbox("Hide utility cooldowns outside combat", function(checked)
        addon.Cooldowns:SetUtilityOnlyCombat(checked)
    end)
    local separateToggle = Checkbox("Separate self and target buffs", function(checked)
        addon.Buffs:SetSeparate(checked)
    end)


    local centerToggle = Checkbox("Center icons", function(checked)
        addon.Buffs:SetCentered(checked)
    end)

    local notifyToggle = Checkbox("Notify on missing self buffs in combat", function(checked)
        addon.Buffs:GetDB().notifyMissingSelfBuffs = checked == true
        addon.Buffs:Refresh()
    end)
    local timerToggle = Checkbox("Hide buff timers on spell icons", function(checked)
        addon.TimerLayer:SetEnabled(checked)
    end)
    local duplicateToggle = Checkbox("Hide buffs already shown on spell icons", function(checked)
        addon.Buffs:GetDB().hideDuplicateBuffs = checked == true
        addon.Buffs:Refresh()
    end)
    duplicateToggle:SetMotionScriptsWhileDisabled(true)
    duplicateToggle:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(self:IsEnabled()
            and 'Hide buff icons while their effect is shown on a spell icon.'
            or 'Requires buff timers on spell icons.', nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    duplicateToggle:SetScript('OnLeave', function() GameTooltip:Hide() end)
    local descriptions = {
        {themeToggle, "Compact, cropped icons with thin borders."},
        {combatToggle, "Show Essential icons in combat."},
        {utilityCombatToggle, "Show Utility icons in combat."},
        {centerToggle, "Center each row as visible icons change. Keep the gap between groups."},
        {separateToggle, "Place self buffs on the left and target effects on the right, with a gap."},
        {notifyToggle, "Show a bouncing reminder for missing self buffs in combat."},
        {timerToggle, "Show spell cooldowns on spell icons."},
    }
    for _, description in ipairs(descriptions) do
        local button, explanation = description[1], description[2]
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(explanation, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local generalExpanded = true
    local general = CreateFrame("Button", nil, content, "ListHeaderThreeSliceTemplate")
    general.label = general:GetTitleRegion()
    general:SetHeaderText("General settings")
    general:SetTitleColor(false, NORMAL_FONT_COLOR)
    general:SetTitleColor(true, NORMAL_FONT_COLOR)
    general:RegisterForClicks("LeftButtonUp")
    general:SetClickHandler(function(_, button)
        if button ~= "LeftButton" then return end
        generalExpanded = not generalExpanded
        RefreshRows()
    end)
    general:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Display options and addon features.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    general:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local headers = {}
    local entrySettings = addon.EntrySettings:Create(content, function() RefreshRows() end, panel)
    RefreshRows = function()
        local db = addon.Buffs:GetDB()
        themeToggle:SetChecked(db.classAuraStyle == true)
        swingToggle:SetChecked(db.swingSparks == true)
        local canShowSpark = addon.Compact:GetSparkViewer() ~= nil
        swingToggle:SetEnabled(canShowSpark)
        swingToggle.label:SetTextColor(canShowSpark and 1 or 0.5, canShowSpark and 1 or 0.5, canShowSpark and 1 or 0.5)
        combatToggle:SetChecked(db.essentialOnlyCombat == true)
        utilityCombatToggle:SetChecked(db.utilityOnlyCombat == true)
        separateToggle:SetChecked(db.separateBuffs == true)
        centerToggle:SetChecked(db.centerIcons == true)
        notifyToggle:SetChecked(db.notifyMissingSelfBuffs == true)
        timerToggle:SetChecked(db.replaceCooldownTimers == true)
        duplicateToggle:SetChecked(db.hideDuplicateBuffs == true)
        local duplicatesEnabled = db.replaceCooldownTimers ~= true
        duplicateToggle:SetEnabled(duplicatesEnabled)
        duplicateToggle.label:SetTextColor(duplicatesEnabled and 1 or 0.5, duplicatesEnabled and 1 or 0.5, duplicatesEnabled and 1 or 0.5)
        content:SetWidth(math.max(280, scroll:GetWidth()))
        for _, header in pairs(headers) do header:Hide() end
        local sections = {
            {name="Display", controls={themeToggle, separateToggle, centerToggle, notifyToggle, combatToggle, utilityCombatToggle}},
            {name="Utility", controls={swingToggle}},
            {name="Buff display", controls={timerToggle, duplicateToggle}},
        }
        general:ClearAllPoints()
        general:SetPoint("TOPLEFT", content, "TOPLEFT")
        general:SetPoint("RIGHT", content, "RIGHT")
        general:SetHeight(22)
        general:UpdateCollapsedState(not generalExpanded)
        general:Show()
        for _, section in ipairs(sections) do
            for _, control in ipairs(section.controls) do control:Hide() end
        end
        local offset = 30
        for sectionIndex, section in ipairs(sections) do
            if generalExpanded and section.controls then
                local header = headers[sectionIndex]
                if not header then
                    header = CreateFrame("Frame", nil, content)
                    header.name = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    header.name:SetPoint("TOP", header, "TOP", 0, -6)
                    header.leftLine = header:CreateTexture(nil, "ARTWORK")
                    header.leftLine:SetTexture("Interface\\Buttons\\WHITE8X8")
                    header.leftLine:SetVertexColor(0.65, 0.52, 0.30, 0.6)
                    header.leftLine:SetHeight(1)
                    header.leftLine:SetPoint("LEFT", header, "TOPLEFT", 0, -13)
                    header.leftLine:SetPoint("RIGHT", header.name, "LEFT", -10, 0)
                    header.rightLine = header:CreateTexture(nil, "ARTWORK")
                    header.rightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
                    header.rightLine:SetVertexColor(0.65, 0.52, 0.30, 0.6)
                    header.rightLine:SetHeight(1)
                    header.rightLine:SetPoint("LEFT", header.name, "RIGHT", 10, 0)
                    header.rightLine:SetPoint("RIGHT", header, "TOPRIGHT", 0, -13)
                    headers[sectionIndex] = header
                end
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
                header:SetPoint("RIGHT", content, "RIGHT")
                header.name:SetText(section.name)
                header:SetHeight(28)
                header:Show()
                offset = offset + 34
                for _, control in ipairs(section.controls or {}) do
                    control:ClearAllPoints()
                    control:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
                    control.label:SetWidth(math.max(180, content:GetWidth() - 40))
                    control:Show()
                    offset = offset + math.max(36, control.label:GetStringHeight() + 10)
                end
                offset = offset + 14
            end
        end
        -- Match the trailing gap used by the per-icon accordion sections.
        offset = entrySettings:Layout(offset + 12)
        content:SetHeight(math.max(60, offset))
        scroll:UpdateScrollChildRect()
    end
    panel:SetScript("OnShow", RefreshRows)
    panel:SetScript("OnHide", function() entrySettings:CloseEditor() end)

    -- Use the same side-tab art as Blizzard, without inheriting its parentArray.
    local tab = CreateFrame("Frame", nil, settings, "LargeSideTabButtonTemplate")
    tab.tooltipText = "CooldownManagerPlus"
    tab:InitializeIconAnchoring()
    tab.Icon:SetTexture('Interface\\AddOns\\' .. addonName .. '\\Media\\TealPlus')
    tab.Icon:SetSize(30, 30)
    tab.Icon:SetVertexColor(0.15, 0.85, 0.78)
    tab:SetChecked(false)
    tab:SetFrameLevel(panel:GetFrameLevel() + 1)

    local tabs = settings.TabButtons
    local lastTab = tabs and tabs[#tabs] or settings.SpellsTab
    if lastTab then
        tab:SetSize(lastTab:GetSize())
        tab:SetPoint("TOP", lastTab, "BOTTOM", 0, -3)
    else
        tab:SetSize(43, 55)
        tab:SetPoint("TOPLEFT", settings, "TOPRIGHT", 4, -60)
    end

    local active = false
    local nativeScrollBarAlpha
    local hiddenControls = {}
    local controlNames = {
        "GroupBuffFilter", "SettingsDropdown",
        "LayoutDropdown", "UndoButton", "SaveButton", "SearchBox",
    }

    local function RestoreNativePage(afterDisplayMode)
        if not active then
            return
        end
        active = false
        panel:Hide()
        if nativeScrollBarAlpha ~= nil then
            nativeScrollBar:SetAlpha(nativeScrollBarAlpha)
            nativeScrollBarAlpha = nil
        end
        tab:SetChecked(false)
        for control, wasShown in pairs(hiddenControls) do
            -- SetDisplayMode may have just selected a different native page.
            if afterDisplayMode and control == settings.GroupBuffFilter then
                control:SetShown(settings.displayMode == "groupBuffs")
            else
                control:SetShown(wasShown)
            end
        end
        hiddenControls = {}
        if tabs then
            for _, nativeTab in ipairs(tabs) do
                nativeTab:SetChecked(nativeTab.displayMode == settings.displayMode)
            end
        end
    end

    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button ~= "LeftButton" or not upInside or active then
            return
        end
        active = true
        if nativeScrollBar then
            -- Change only rendering; hiding the native frame can run its scripts.
            nativeScrollBarAlpha = nativeScrollBar:GetAlpha()
            nativeScrollBar:SetAlpha(0)
        end
        for _, name in ipairs(controlNames) do
            local control = settings[name]
            if control then
                hiddenControls[control] = control:IsShown()
                control:Hide()
            end
        end
        if tabs then
            for _, nativeTab in ipairs(tabs) do
                nativeTab:SetChecked(false)
            end
        end
        tab:SetChecked(true)
        scroll:SetVerticalScroll(0)
        panel:Show()
    end)

    -- This hook also runs when Blizzard returns early because the user clicks
    -- the already-selected native mode. Never replace the original method.
    hooksecurefunc(settings, "SetDisplayMode", function()
        RestoreNativePage(true)
    end)
    settings:HookScript("OnHide", function()
        RestoreNativePage(false)
    end)

    eventFrame:UnregisterAllEvents()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", InstallTab)
InstallTab()
