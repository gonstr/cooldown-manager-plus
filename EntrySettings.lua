local _, addon = ...
local lists = {}
addon.EntrySettings = lists

function lists:Create(content, refresh, owner)
    local page = {expanded = {}, widgets = {}}
    local overrides = addon.Overrides
    local popupWidth = 320
    local hiddenKeys = {
        buff = {'notifyMissingSelfBuffs', 'hideDuplicateBuffs'},
        spell = {'combatOnly', 'replaceCooldownTimers'},
    }

    local function Customized(kind, id)
        local options = overrides.Get(addon.Buffs:GetDB(), kind, id)
        for _, key in ipairs(hiddenKeys[kind]) do
            if type(options[key]) == 'boolean' then return true end
        end
        return false
    end

    local function Set(kind, id, key, value)
        if kind == 'buff' then addon.Buffs:SetEffect(id, key, value)
        elseif key == 'replaceCooldownTimers' then addon.TimerLayer:SetOverride(id, value)
        else addon.Cooldowns:SetOverride(id, key, value) end
    end

    function page:CloseEditor()
        self.selected = nil
        if self.popup then self.popup:Hide(); self.dismiss:Hide() end
    end

    local function CreateEditor()
        if page.popup then return end
        local dismiss = CreateFrame('Frame', nil, owner)
        dismiss:SetAllPoints(UIParent)
        dismiss:SetFrameStrata('DIALOG')
        dismiss:SetFrameLevel(owner:GetFrameLevel() + 10)
        dismiss:EnableMouse(true)
        dismiss:SetPropagateMouseClicks(true)
        dismiss:SetScript('OnMouseDown', function()
            -- Let the selected options button toggle the editor on mouse-up.
            -- Closing it here first would make that same click reopen it.
            if page.selected and page.selected.options:IsMouseOver() then return end
            page:CloseEditor()
        end)
        dismiss:Hide()
        page.dismiss = dismiss

        local popup = CreateFrame('Frame', nil, owner, 'BackdropTemplate')
        page.popup = popup
        popup:SetWidth(popupWidth)
        popup:SetFrameStrata('DIALOG')
        popup:SetFrameLevel(dismiss:GetFrameLevel() + 1)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background',
            edgeFile='Interface\\Tooltips\\UI-Tooltip-Border', tile=true, tileSize=16, edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}})
        popup:SetBackdropColor(0.08, 0.08, 0.08, 1)
        popup:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        popup.title = popup:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        popup.title:SetPoint('TOPLEFT', popup, 'TOPLEFT', 12, -12)
        popup.title:SetWidth(popupWidth - 48)
        popup.title:SetJustifyH('LEFT')
        popup.close = CreateFrame('Button', nil, popup, 'UIPanelCloseButton')
        popup.close:SetPoint('TOPRIGHT', popup, 'TOPRIGHT', -3, -3)
        popup.close:SetScript('OnClick', function() page:CloseEditor() end)
        popup.rows = {}
        popup.reset = CreateFrame('Button', nil, popup, 'UIPanelButtonTemplate')
        popup.reset:SetSize(135, 24)
        popup.reset:SetText('Reset overrides')
        popup.reset:SetScript('OnClick', function()
            local selected = page.selected
            if not selected then return end
            -- Always show is edited visibly in the list, independently of the
            -- hidden options reset here. Clear only this editor's settings.
            if selected.kind == 'buff' then
                for _, key in ipairs(hiddenKeys.buff) do Set('buff', selected.entry.key, key, nil) end
            else addon.Cooldowns:ResetOverrides(selected.entry.key) end
            refresh()
        end)
        popup:SetScript('OnHide', function() page.selected = nil; dismiss:Hide() end)
        popup:Hide()
    end

    local function Choices()
        return {{label='Use default'}, {label='Disabled', value=false}, {label='Enabled', value=true}}
    end

    local function UpdateEditor(row)
        CreateEditor()
        page.selected = row
        local popup = page.popup
        popup.title:SetText(row.entry.name)
        local fields = {}
        if row.kind == 'buff' then
            if row.entry.knownSelf and row.entry.reminderEligible then
                fields[#fields + 1] = {key='notifyMissingSelfBuffs', label='Notify on missing self buffs in combat', choices=Choices()}
            end
            fields[#fields + 1] = {key='hideDuplicateBuffs', label='Hide buffs already shown on spell icons', choices=Choices()}
        else
            fields[#fields + 1] = {key='combatOnly', label=row.category == 'utility' and 'Hide utility cooldowns outside combat' or 'Hide essential cooldowns outside combat', choices=Choices()}
            if addon.TimerLayer:SupportsItem(row.entry.item) then
                fields[#fields + 1] = {key='replaceCooldownTimers', label='Hide buff timers on spell icons', choices=Choices()}
            end
        end
        for _, control in ipairs(popup.rows) do control:Hide() end
        local offset = 20 + popup.title:GetStringHeight()
        for index, field in ipairs(fields) do
            local control = popup.rows[index]
            if not control then
                control = CreateFrame('Frame', nil, popup)
                control.label = control:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                control.label:SetPoint('TOPLEFT', control, 'TOPLEFT')
                control.label:SetWidth(popupWidth - 24)
                control.label:SetJustifyH('LEFT')
                control.dropdown = CreateFrame('DropdownButton', nil, control, 'WowStyle1DropdownTemplate')
                control.dropdown:SetWidth(popupWidth - 24)
                popup.rows[index] = control
            end
            control.label:SetText(field.label)
            local labelHeight = control.label:GetStringHeight()
            control.dropdown:ClearAllPoints()
            control.dropdown:SetPoint('TOPLEFT', control, 'TOPLEFT', 0, -labelHeight - 6)
            local value = overrides.Get(addon.Buffs:GetDB(), row.kind, row.entry.key)[field.key]
            local selectedText = 'Use default'
            for _, choice in ipairs(field.choices) do
                if choice.value == value then selectedText = choice.label end
            end
            control.dropdown:SetDefaultText(selectedText)
            control.dropdown:SetScript('OnEnter', function(self)
                if overrides.Get(addon.Buffs:GetDB(), row.kind, row.entry.key)[field.key] ~= nil then return end
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:SetText('Use the matching option in General settings.', nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            control.dropdown:SetScript('OnLeave', function() GameTooltip:Hide() end)
            control.dropdown:SetupMenu(function(_, root)
                for _, choice in ipairs(field.choices) do
                    local option = choice
                    root:CreateRadio(option.label, function()
                        return overrides.Get(addon.Buffs:GetDB(), row.kind, row.entry.key)[field.key] == option.value
                    end, function()
                        Set(row.kind, row.entry.key, field.key, option.value)
                        refresh()
                    end)
                end
            end)
            control:ClearAllPoints()
            control:SetPoint('TOPLEFT', popup, 'TOPLEFT', 12, -offset)
            control:SetSize(popupWidth - 24, labelHeight + 44)
            control:Show()
            offset = offset + labelHeight + 44
        end
        popup.reset:ClearAllPoints()
        popup.reset:SetPoint('TOPLEFT', popup, 'TOPLEFT', 12, -offset)
        popup.reset:SetEnabled(Customized(row.kind, row.entry.key))
        popup:SetHeight(offset + 36)
        popup:ClearAllPoints()
        popup:SetPoint('TOPRIGHT', row, 'BOTTOMRIGHT', 0, -2)
        page.dismiss:Show()
        popup:Show()
    end

    local function Widget(key, template)
        local widget = page.widgets[key]
        if not widget then
            widget = CreateFrame(template and 'Button' or 'Frame', nil, content, template)
            page.widgets[key] = widget
        end
        return widget
    end

    local function Position(widget, offset, height)
        widget:ClearAllPoints()
        widget:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -offset)
        widget:SetPoint('RIGHT', content, 'RIGHT')
        widget:SetHeight(height)
        widget:Show()
        return offset + height
    end

    local function Header(group, offset)
        local header = Widget(group.key, 'ListHeaderThreeSliceTemplate')
        if not header.label then
            header.label = header:GetTitleRegion()
            header:SetTitleColor(false, NORMAL_FONT_COLOR)
            header:SetTitleColor(true, NORMAL_FONT_COLOR)
            header:RegisterForClicks('LeftButtonUp')
            header:SetClickHandler(function(_, button)
                if button ~= 'LeftButton' then return end
                page.expanded[group.key] = not page.expanded[group.key]
                refresh()
            end)
        end
        header:UpdateCollapsedState(not page.expanded[group.key])
        header:SetHeaderText(group.label)
        return Position(header, offset, 22) + 8
    end

    local function AlwaysShowTooltip(widget)
        widget:EnableMouse(true)
        widget:SetScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:SetText('Show missing buffs as gray icons.', nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript('OnLeave', function() GameTooltip:Hide() end)
    end

    local function Entry(group, entry, offset)
        local row = Widget(group.key .. ':' .. entry.key)
        row.entry, row.kind, row.category = entry, group.kind, group.key
        if not row.label then
            row.icon = row:CreateTexture(nil, 'ARTWORK')
            row.icon:SetSize(24, 24)
            row.icon:SetPoint('LEFT', row, 'LEFT', 4, 0)
            row.label = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            row.label:SetPoint('LEFT', row.icon, 'RIGHT', 6, 0)
            row.label:SetJustifyH('LEFT')
            row.label:SetWordWrap(false)
            row.options = CreateFrame('Button', nil, row, 'UIPanelButtonTemplate')
            row.options:SetSize(30, 22)
            row.options:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
            row.options:SetText('...')
            row.options:SetScript('OnClick', function()
                if page.selected == row then page:CloseEditor() else UpdateEditor(row) end
            end)
            row.options:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:SetText(row.entry.name .. '\nOverride settings', nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            row.options:SetScript('OnLeave', function() GameTooltip:Hide() end)
            row.summary = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            row.summary:SetWidth(78)
            row.summary:SetJustifyH('RIGHT')
            if group.kind == 'buff' then
                row.check = CreateFrame('CheckButton', nil, row, 'UICheckButtonTemplate')
                row.check:SetSize(32, 32)
                AlwaysShowTooltip(row.check)
                row.check:SetPoint('RIGHT', row, 'RIGHT', -38, 0)
                row.check:SetScript('OnClick', function(self)
                    Set('buff', row.entry.key, 'alwaysShow', self:GetChecked())
                    refresh()
                end)
                row.summary:SetPoint('RIGHT', row.check, 'LEFT', -6, 0)
            else row.summary:SetPoint('RIGHT', row.options, 'LEFT', -6, 0) end
        end
        local customized = Customized(group.kind, entry.key)
        row.summary:SetText(customized and 'Customized' or '')
        row.icon:SetTexture(entry.icon or 134400)
        row.label:SetText(entry.name)
        row.label:SetWidth(math.max(60, content:GetWidth() - (group.kind == 'buff' and 110 or 74) - (customized and 84 or 0)))
        if row.check then row.check:SetChecked(entry.options and entry.options.alwaysShow == true) end
        offset = Position(row, offset, 36)
        return offset, row
    end

    function page:Layout(offset)
        for _, widget in pairs(self.widgets) do widget:Hide() end
        local groups = {
            {key='buffs', label='Buffs', kind='buff', entries=addon.Buffs:GetEntries()},
            {key='essential', label='Essential spells', kind='spell', entries=addon.Cooldowns:GetEntries(EssentialCooldownViewer)},
            {key='utility', label='Utility spells', kind='spell', entries=addon.Cooldowns:GetEntries(UtilityCooldownViewer)},
        }
        local selectedRow
        for _, group in ipairs(groups) do
            if #group.entries > 0 then
                offset = Header(group, offset)
                if self.expanded[group.key] then
                    if group.kind == 'buff' then
                        local column = Widget('buff-column')
                        if not column.label then
                            column.label = column:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                            column.label:SetWidth(90)
                            column.label:SetPoint('CENTER', column, 'RIGHT', -54, 0)
                            column.label:SetText('Always show')
                            column.tooltipTarget = CreateFrame('Frame', nil, column)
                            column.tooltipTarget:SetSize(90, 20)
                            column.tooltipTarget:SetPoint('CENTER', column.label, 'CENTER')
                            AlwaysShowTooltip(column.tooltipTarget)
                        end
                        offset = Position(column, offset, 20)
                    end
                    for _, entry in ipairs(group.entries) do
                        local row
                        offset, row = Entry(group, entry, offset)
                        if row == self.selected then selectedRow = row end
                    end
                end
                offset = offset + 12
            end
        end
        if selectedRow then UpdateEditor(selectedRow) else self:CloseEditor() end
        return offset
    end
    return page
end
