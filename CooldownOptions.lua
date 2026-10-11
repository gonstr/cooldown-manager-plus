local _, addon = ...
local options = {}
addon.Cooldowns = options
local hooked = setmetatable({}, {__mode = 'k'})
local hidden = setmetatable({}, {__mode = 'k'})
local previousAlpha = setmetatable({}, {__mode = 'k'})
local frame = CreateFrame('Frame')
local queued

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function options:GetEntries(viewer)
    local entries = {}
    local db = addon.Buffs:GetDB()
    if not viewer or not viewer.itemFramePool then return entries end
    for item in viewer.itemFramePool:EnumerateActive() do
        local id = item:GetCooldownID()
        if Readable(id) and type(id) == 'number' then
            local info = item:GetCooldownInfo()
            local spellID = info and info.spellID
            if not Readable(spellID) then spellID = nil end
            local spell = spellID and C_Spell.GetSpellInfo(spellID)
            entries[#entries + 1] = {key = id, item = item,
                options = addon.Overrides.Get(db, 'spell', id),
                name = spell and spell.name or ('Effect ' .. id),
                icon = spell and spell.iconID,
                order = item.layoutIndex or 0}
        end
    end
    table.sort(entries, function(a, b) return a.order < b.order end)
    return entries
end

function options:ShouldDisplayItem(item)
    return not hidden[item]
end

function options:Apply()
    local combat = UnitAffectingCombat('player')
    local db = addon.Buffs:GetDB()
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer}) do
        for _, entry in ipairs(self:GetEntries(viewer)) do
            local item = entry.item
            if not hooked[item] then
                hooked[item] = true
                local function Refreshed()
                    -- The buff viewer may refresh before this spell's aura timer.
                    -- Recheck immediately when its native display is ready.
                    if addon.Buffs.HideDuplicates then addon.Buffs:HideDuplicates() end
                    options:QueueUpdate()
                end
                hooksecurefunc(item, 'UpdateShownState', Refreshed)
                hooksecurefunc(item, 'RefreshData', Refreshed)
                for _, name in ipairs({'RefreshCooldownOnly', 'OnCooldownDone'}) do
                    if type(item[name]) == 'function' then
                        hooksecurefunc(item, name, Refreshed)
                    end
                end
            end
            local global = (viewer == EssentialCooldownViewer and db.essentialOnlyCombat == true)
                or (viewer == UtilityCooldownViewer and db.utilityOnlyCombat == true)
            local onlyCombat = addon.Overrides.Resolve(entry.options, 'combatOnly', global)
            local hide = onlyCombat and not combat and not viewer:IsEditing()
            hidden[item] = hide or nil
            -- Keep native visibility/tracking intact. Alpha can change across
            -- combat boundaries without hiding or disabling a protected icon.
            if hide then
                if previousAlpha[item] == nil then previousAlpha[item] = item:GetAlpha() end
                item:SetAlpha(0)
            elseif previousAlpha[item] ~= nil then
                item:SetAlpha(previousAlpha[item])
                previousAlpha[item] = nil
            end
        end
        if addon.CenteredRows then addon.CenteredRows:Apply(viewer, self:GetEntries(viewer)) end
    end
    if addon.Compact then addon.Compact:QueueUpdate() end
    if addon.Buffs.QueueUpdate then addon.Buffs:QueueUpdate() end
end

function options:SetOverride(id, name, value)
    addon.Overrides.Set(addon.Buffs:GetDB(), 'spell', id, name, value)
    self:Apply()
end

function options:ResetOverrides(id)
    addon.Overrides.Reset(addon.Buffs:GetDB(), 'spell', id)
    if addon.TimerLayer then addon.TimerLayer:Refresh() end
    self:Apply()
end

function options:QueueUpdate()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; options:Apply() end)
end

function options:SetOnlyCombat(enabled)
    addon.Buffs:GetDB().essentialOnlyCombat = enabled
    self:Apply()
end

function options:SetUtilityOnlyCombat(enabled)
    addon.Buffs:GetDB().utilityOnlyCombat = enabled == true
    self:Apply()
end

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_REGEN_DISABLED')
frame:RegisterEvent('PLAYER_REGEN_ENABLED')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:SetScript('OnEvent', function()
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer}) do
        if not hooked[viewer] and viewer.itemFramePool then
            hooked[viewer] = true
            for _, name in ipairs({'RefreshData', 'SetIsEditing', 'UpdateShownState'}) do
                if type(viewer[name]) == 'function' then
                    hooksecurefunc(viewer, name, function() options:QueueUpdate() end)
                end
            end
        end
    end
    options:QueueUpdate()
end)
