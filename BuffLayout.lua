local _, addon = ...
local model = addon.BuffLayoutModel
local controller = {}
addon.Buffs = controller
local viewer, queued, applying
local hookedItems = setmetatable({}, {__mode = 'k'})
local changedIcons = setmetatable({}, {__mode = 'k'})
local observedGroups = {}
local eventFrame = CreateFrame('Frame')

local function IsReadable(value)
    return not (issecretvalue and issecretvalue(value))
end

function controller:GetDB()
    if type(CooldownManagerPlusDB) ~= 'table' then
        CooldownManagerPlusDB = {}
    end
    local db = CooldownManagerPlusDB
    if db.centerIcons == nil then db.centerIcons = db.centerBuffs == true end
    db.centerBuffs = nil
    db.cooldownsOnly = nil -- Removed: overriding native aura display taints secret aura access.
    db.effects = db.effects or {}
    if not db.simpleBuffOptions then
        if db.replaceCooldownTimers == nil and db.spellTimers then
            db.replaceCooldownTimers = false
            for _, enabled in pairs(db.spellTimers) do
                if enabled then db.replaceCooldownTimers = true; break end
            end
        end
        if db.notifyMissingSelfBuffs == nil then
            db.notifyMissingSelfBuffs = false
            for _, effect in pairs(db.effects) do
                if effect.notifyMissing then db.notifyMissingSelfBuffs = true; break end
            end
        end
        db.spellTimers = nil
        for _, effect in pairs(db.effects) do effect.notifyMissing = nil end
        db.simpleBuffOptions = true
    end
    if db.optionsVersion ~= 2 then
        db.observedGroups, db.gap, db.split, db.cooldowns = nil, nil, nil, nil
        for _, effect in pairs(db.effects) do effect.group = nil end
        db.optionsVersion = 2
    end
    if db.swingSparks == nil then db.swingSparks = db.compact == true end
    if db.classAuraStyle == nil then
        db.classAuraStyle = db.compact == true or db.iconZoom == true
        db.compact, db.iconZoom = db.classAuraStyle, db.classAuraStyle
    end
    return db
end

function controller:GetEntries()
    local entries = {}
    if not viewer or not viewer.itemFramePool then
        return entries
    end
    local db = self:GetDB()
    for item in viewer.itemFramePool:EnumerateActive() do
        local id = item:GetCooldownID()
        if IsReadable(id) and type(id) == 'number' then
            local options = db.effects[id] or {}
            local active = item:IsActive()
            local readableActive = IsReadable(active)
            local info = item:GetCooldownInfo()
            local unit = item:GetAuraDataUnit()
            local group = observedGroups[id]
            if IsReadable(unit) and (unit == 'player' or unit == 'target') then
                group = unit == 'target' and 'target' or 'self'
                observedGroups[id] = group
            elseif not group and info and IsReadable(info.selfAura) and type(info.selfAura) == 'boolean' then
                group = info.selfAura and 'self' or 'target'
            end
            local spellID = info and info.spellID
            if not IsReadable(spellID) then spellID = nil end
            local spellInfo = spellID and C_Spell.GetSpellInfo(spellID)
            entries[#entries + 1] = {
                key = id, item = item, options = options,
                group = group or 'self',
                knownSelf = group == 'self',
                reminderEligible = addon.BuffEligibility and addon.BuffEligibility:IsEligibleCooldown(info) or false,
                order = item.layoutIndex or 0,
                name = spellInfo and spellInfo.name or ('Effect ' .. id),
                icon = spellInfo and spellInfo.iconID,
                active = readableActive and active or false,
                readableActive = readableActive,
                width = item:GetWidth() * item:GetScale(),
            }
        end
    end
    table.sort(entries, function(a, b) return a.order < b.order end)
    return entries
end

function controller:GetSplitLayout(items, size, spacing)
    local entries, included, groups = {}, {}, {}
    local centered = self:GetDB().centerIcons == true
    for _, entry in ipairs(self:GetEntries()) do
        groups[entry.item] = entry.group
        if not centered then
            entries[#entries + 1] = entry
            included[entry.item] = true
        end
    end
    for _, item in ipairs(items) do
        if not included[item] then
            entries[#entries + 1] = {item = item, group = groups[item] or 'self'}
        end
    end
    local ordered, positions, split = model.SplitRow(entries, size, spacing, 16)
    local result = {}
    for i, entry in ipairs(ordered) do result[i] = entry.item end
    return result, positions, split
end

function controller:QueueUpdate()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        controller:Apply()
    end)
end

local function HideDuplicate(item)
    if not viewer or viewer:IsEditing() or not addon.Duplicates then return end
    if InCombatLockdown() and item:IsProtected() then return end
    local id = item:GetCooldownID()
    if not IsReadable(id) or type(id) ~= 'number' then return end
    local db = controller:GetDB()
    if addon.Overrides.Resolve(db.effects[id], 'hideDuplicateBuffs', db.hideDuplicateBuffs)
        and addon.Duplicates:HasVisibleDuplicate(item) then
        item:SetShown(false)
    end
end

function controller:HideDuplicates()
    if not viewer or not viewer.itemFramePool then return end
    for item in viewer.itemFramePool:EnumerateActive() do HideDuplicate(item) end
end

function controller:Apply()
    if applying or not viewer then return end
    applying = true
    local db = self:GetDB()
    local entries = self:GetEntries()
    local editing = viewer:IsEditing()
    local inCombat = InCombatLockdown()
    local visibilityChanged = false
    for _, entry in ipairs(entries) do
        local item = entry.item
        if not hookedItems[item] then
            hookedItems[item] = true
            local function Refreshed()
                -- Hide before rendering; geometry and reminder work remain queued.
                HideDuplicate(item)
                controller:QueueUpdate()
            end
            hooksecurefunc(item, 'UpdateShownState', Refreshed)
            hooksecurefunc(item, 'RefreshData', Refreshed)
        end
        local canChange = not (inCombat and item:IsProtected())
        if canChange then
            -- Ask the original predicate each time; an icon we forced visible
            -- must not become its own "native shown" state on the next refresh.
            local nativeShown = item:ShouldBeShown()
            local override = entry.options.alwaysShow == true and entry.readableActive
            local shown, gray = model.GetAppearance(entry.active, nativeShown, override)
            local hideDuplicate = addon.Overrides.Resolve(entry.options, 'hideDuplicateBuffs', db.hideDuplicateBuffs)
            if not editing and hideDuplicate and addon.Duplicates and addon.Duplicates:HasVisibleDuplicate(item) then
                shown = false
            end
            if item:IsShown() ~= shown then visibilityChanged = true end
            item:SetShown(shown)
            if override and not editing then
                item.Icon:SetDesaturated(gray)
                item.Icon:SetVertexColor(gray and 0.55 or 1, gray and 0.55 or 1, gray and 0.55 or 1)
                changedIcons[item] = true
            elseif changedIcons[item] then
                item.Icon:SetDesaturated(false)
                item.Icon:SetVertexColor(1, 1, 1)
                changedIcons[item] = nil
            end
        end
    end

    if visibilityChanged and not inCombat and not db.compact then
        viewer:GetItemContainerFrame():Layout()
    end

    if (db.separateBuffs or db.centerIcons) and not db.compact and not editing then
        local items = {}
        for _, entry in ipairs(entries) do
            if not db.centerIcons or entry.item:IsShown() then
                items[#items + 1] = entry.item
            end
        end
        local scale = viewer.iconScale or (items[1] and items[1]:GetScale()) or 1
        local size = items[1] and items[1]:GetWidth() * scale or 0
        -- Native layout compensates for transparent padding in the icon art.
        -- Splitting groups must retain that compensation between their icons.
        local artPadding = viewer.GetAdditionalPaddingOffset and viewer:GetAdditionalPaddingOffset() or -4
        local spacing = ((viewer.iconPadding or 0) + artPadding) * scale
        local ordered, positions
        if db.separateBuffs then
            ordered, positions = self:GetSplitLayout(items, size, spacing)
        else
            local row = {}
            for _, item in ipairs(items) do row[#row + 1] = {item=item, group='self'} end
            local layout
            layout, positions = model.SplitRow(row, size, spacing, 0)
            ordered = {}
            for i, entry in ipairs(layout) do ordered[i] = entry.item end
        end
        for i, item in ipairs(ordered) do
            if not (inCombat and item:IsProtected()) then
                item:ClearAllPoints()
                item:SetPoint('CENTER', viewer, 'CENTER', positions[i] / item:GetScale(), 0)
            end
        end
    end
    if addon.BuffReminder then addon.BuffReminder:Update(entries, editing) end
    applying = false
    if db.compact and addon.Compact then addon.Compact:QueueUpdate() end
end

function controller:SetCentered(enabled)
    self:GetDB().centerIcons = enabled == true
    if addon.Cooldowns then addon.Cooldowns:Apply() end
    self:Refresh()
end

function controller:SetSeparate(enabled)
    self:GetDB().separateBuffs = enabled == true
    self:Refresh()
end

function controller:Refresh()
    if viewer and not InCombatLockdown() then
        -- Re-run only geometry, avoiding Blizzard's protected data refresh APIs.
        viewer:GetItemContainerFrame():Layout()
    end
    self:QueueUpdate()
end

function controller:SetEffect(id, name, value)
    addon.Overrides.Set(self:GetDB(), 'buff', id, name, value)
    self:Refresh()
end

function controller:ResetOverrides(id)
    addon.Overrides.Reset(self:GetDB(), 'buff', id)
    self:Refresh()
end

local function Attach()
    if viewer or not BuffIconCooldownViewer or not BuffIconCooldownViewer.itemFramePool then return end
    viewer = BuffIconCooldownViewer
    hooksecurefunc(viewer:GetItemContainerFrame(), 'Layout', function() controller:Apply() end)
    hooksecurefunc(viewer, 'RefreshData', function() controller:QueueUpdate() end)
    hooksecurefunc(viewer, 'SetHideWhenInactive', function() controller:QueueUpdate() end)
    controller:QueueUpdate()
end

eventFrame:RegisterEvent('PLAYER_LOGIN')
eventFrame:RegisterEvent('ADDON_LOADED')
eventFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
eventFrame:RegisterEvent('PLAYER_REGEN_DISABLED')
eventFrame:RegisterEvent('PLAYER_TARGET_CHANGED')
eventFrame:RegisterUnitEvent('UNIT_AURA', 'player', 'target')
eventFrame:SetScript('OnEvent', function()
    Attach()
    controller:QueueUpdate()
end)
Attach()
