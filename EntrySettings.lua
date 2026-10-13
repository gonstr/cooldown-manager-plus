local _, addon = ...
local settingsUI = {}
addon.EntrySettings = settingsUI
local installedSettings
local hooked = setmetatable({}, {__mode='k'})
local eventFrame = CreateFrame('Frame')

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Describe(item)
    if not item or type(item.GetCooldownID) ~= 'function'
        or type(item.GetCooldownInfo) ~= 'function' then return end
    if item.IsEmptyCategory then
        local empty = item:IsEmptyCategory()
        if not Readable(empty) or empty then return end
    end
    local id = item:GetCooldownID()
    if not Readable(id) or type(id) ~= 'number' then return end
    local info = item:GetCooldownInfo()
    if not Readable(info) or type(info) ~= 'table' or not Readable(info.category) then return end
    local categories = Enum.CooldownViewerCategory
    local category = info.category
    if category == categories.TrackedBuff or category == categories.HiddenAura then
        return {id=id, kind='buff', info=info, category=category}
    elseif category == categories.Essential or category == categories.Utility or category == categories.HiddenSpell then
        return {id=id, kind='spell', info=info, category=category}
    end
end

local function Fields(entry, item, includeSaved)
    if entry.kind == 'buff' then
        local fields = {{key='alwaysShow', label='Always show', checkbox=true}}
        if includeSaved or (Readable(entry.info.selfAura) and entry.info.selfAura == true
            and addon.BuffEligibility:IsEligibleCooldown(entry.info)) then
            fields[#fields+1] = {key='notifyMissingSelfBuffs', label='Notify on missing self buffs in combat'}
        end
        fields[#fields+1] = {key='hideDuplicateBuffs', label='Hide buffs already shown on spell icons'}
        return fields
    end
    local label = 'Hide cooldowns outside combat'
    if entry.category == Enum.CooldownViewerCategory.Essential then label = 'Hide essential cooldowns outside combat'
    elseif entry.category == Enum.CooldownViewerCategory.Utility then label = 'Hide utility cooldowns outside combat' end
    local fields = {{key='combatOnly', label=label}}
    if includeSaved or addon.TimerLayer:SupportsItem(item) then
        fields[#fields+1] = {key='replaceCooldownTimers', label='Hide buff timers on spell icons'}
    end
    return fields
end

local function Status(item)
    local entry = Describe(item)
    if not entry then return false, {} end
    local options = addon.Overrides.Get(addon.Buffs:GetDB(), entry.kind, entry.id)
    local lines = {}
    for _, field in ipairs(Fields(entry, item, true)) do
        local value = options[field.key]
        if type(value) == 'boolean' and (not field.checkbox or value) then
            lines[#lines+1] = field.label .. ': ' .. (value and 'Enabled' or 'Disabled')
        end
    end
    return #lines > 0, lines
end

local function RefreshItem(item)
    local customized = Status(item)
    local indicator = item.cmPlusIndicator
    if not customized then
        if indicator then indicator:Hide() end
        return
    end
    if not indicator then
        -- All overlays are addon-owned; never create children on native icons in combat.
        if InCombatLockdown() or not item.Icon then return end
        indicator = CreateFrame('Frame', nil, item)
        item.cmPlusIndicator = indicator
        indicator:SetAllPoints(item.Icon)
        indicator:SetFrameLevel(item:GetFrameLevel() + 2)
        indicator:EnableMouse(false)
        for _, side in ipairs({'TOP', 'BOTTOM', 'LEFT', 'RIGHT'}) do
            local edge = indicator:CreateTexture(nil, 'OVERLAY')
            edge:SetColorTexture(0.15, 0.85, 0.78, 1)
            if side == 'TOP' or side == 'BOTTOM' then
                edge:SetPoint(side .. 'LEFT', indicator, side .. 'LEFT')
                edge:SetPoint(side .. 'RIGHT', indicator, side .. 'RIGHT')
                edge:SetHeight(2)
            else
                edge:SetPoint('TOP' .. side, indicator, 'TOP' .. side)
                edge:SetPoint('BOTTOM' .. side, indicator, 'BOTTOM' .. side)
                edge:SetWidth(2)
            end
        end
    end
    indicator:Show()
end

function settingsUI:RefreshIndicators()
    if not installedSettings or not installedSettings.categoryPool then return end
    for category in installedSettings.categoryPool:EnumerateActive() do
        if category.itemPool then
            for item in category.itemPool:EnumerateActive() do
                if not hooked[item] then
                    hooked[item] = true
                    -- Post-hooks observe native recycling and tooltip updates without driving them.
                    if type(item.RefreshData) == 'function' then
                        hooksecurefunc(item, 'RefreshData', RefreshItem)
                    end
                    if type(item.RefreshTooltip) == 'function' then
                        hooksecurefunc(item, 'RefreshTooltip', function(owner)
                            local _, lines = Status(owner)
                            if #lines == 0 then return end
                            local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
                            tooltip:AddLine(' ')
                            tooltip:AddLine('CM Plus overrides', 0.15, 0.85, 0.78)
                            for _, line in ipairs(lines) do tooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
                            tooltip:Show()
                        end)
                    end
                end
                RefreshItem(item)
            end
        end
    end
end

local function Set(entry, key, value)
    if entry.kind == 'buff' then addon.Buffs:SetEffect(entry.id, key, value)
    elseif key == 'replaceCooldownTimers' then addon.TimerLayer:SetOverride(entry.id, value)
    else addon.Cooldowns:SetOverride(entry.id, key, value) end
    settingsUI:RefreshIndicators()
end

local function ExtendMenu(owner, root)
    local entry = Describe(owner)
    if not entry then return end
    local function Options()
        return addon.Overrides.Get(addon.Buffs:GetDB(), entry.kind, entry.id)
    end
    local function CanWrite()
        if InCombatLockdown() then return false end
        local current = Describe(owner)
        return current and current.id == entry.id and current.category == entry.category
    end
    root:CreateDivider()
    root:CreateTitle('|cff26d9c7CM Plus|r')
    for _, field in ipairs(Fields(entry, owner)) do
        local control
        if field.checkbox then
            control = root:CreateCheckbox(field.label, function() return Options()[field.key] == true end,
                function() if CanWrite() then Set(entry, field.key, Options()[field.key] ~= true) end end)
            control:SetTooltip(function(tooltip) tooltip:AddLine('Show missing buffs as gray icons.', 1, 1, 1, true) end)
        else
            control = root:CreateButton(field.label)
            for _, choice in ipairs({{label='Use default'}, {label='Enabled', value=true}, {label='Disabled', value=false}}) do
                local radio = control:CreateRadio(choice.label,
                    function() return Options()[field.key] == choice.value end,
                    function() if CanWrite() then Set(entry, field.key, choice.value) end end)
                radio:SetEnabled(not InCombatLockdown())
                if choice.value == nil then
                    radio:SetTooltip(function(tooltip)
                        tooltip:AddLine('Use the matching option in General settings.', 1, 1, 1, true)
                    end)
                end
            end
        end
        control:SetEnabled(not InCombatLockdown())
    end
    local reset = root:CreateButton('Reset overrides', function()
        if not CanWrite() then return end
        if entry.kind == 'buff' then
            for _, key in ipairs({'alwaysShow', 'notifyMissingSelfBuffs', 'hideDuplicateBuffs'}) do Set(entry, key, nil) end
        else
            addon.Cooldowns:ResetOverrides(entry.id)
            settingsUI:RefreshIndicators()
        end
    end)
    reset:SetEnabled(not InCombatLockdown() and addon.Overrides.Count(entry.kind, Options()) > 0)
end

function settingsUI:Install(settings)
    if installedSettings or not Menu or type(Menu.ModifyMenu) ~= 'function' then return end
    installedSettings = settings
    Menu.ModifyMenu('MENU_COOLDOWN_SETTINGS_ITEM', ExtendMenu)
    hooksecurefunc(settings, 'RefreshLayout', function() self:RefreshIndicators() end)
    if type(settings.RefreshVisibleCategories) == 'function' then
        hooksecurefunc(settings, 'RefreshVisibleCategories', function() self:RefreshIndicators() end)
    end
    settings:HookScript('OnShow', function() self:RefreshIndicators() end)
    self:RefreshIndicators()
end

eventFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
eventFrame:SetScript('OnEvent', function() settingsUI:RefreshIndicators() end)
