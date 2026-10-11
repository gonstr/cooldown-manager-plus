local _, addon = ...
local duplicates = {}
addon.Duplicates = duplicates

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Visible(frame)
    if not frame or not frame.IsVisible or not frame.GetEffectiveAlpha then return false end
    local shown, alpha = frame:IsVisible(), frame:GetEffectiveAlpha()
    return Readable(shown) and shown == true and Readable(alpha) and type(alpha) == 'number' and alpha > 0
end

local function Identity(item)
    if not item.GetAuraSpellInstanceID or not item.GetAuraDataUnit then return end
    local id, unit = item:GetAuraSpellInstanceID(), item:GetAuraDataUnit()
    if not Readable(unit) or (unit ~= 'player' and unit ~= 'target') then return end
    if not Readable(id) then return nil, unit, true end
    if type(id) == 'number' then return id, unit, false end
end

local function AuraSpell(item)
    -- Prefer the actual current aura, then the native active linked spell.
    -- Neither call reads an aura duration or compares a secret value.
    local current = item.GetAuraSpellID and item:GetAuraSpellID()
    if Readable(current) and type(current) == 'number' then return current end
    local info = item.GetCooldownInfo and item:GetCooldownInfo()
    if not Readable(info) or type(info) ~= 'table' then return end
    if not Readable(info.linkedSpellID) then return end
    if type(info.linkedSpellID) == 'number' then return info.linkedSpellID end
    -- Without a current spell, only accept a tracker with one possible effect.
    -- Grouped trackers with several possible spells remain visible.
    local candidate, ambiguous
    local function Add(id)
        if not Readable(id) then ambiguous = true; return end
        if id == nil then return end
        if type(id) ~= 'number' then ambiguous = true; return end
        if candidate and candidate ~= id then ambiguous = true end
        candidate = id
    end
    Add(info.spellID)
    Add(info.overrideSpellID)
    Add(info.overrideTooltipSpellID)
    local linked = info.linkedSpellIDs
    if not Readable(linked) then return end
    if linked ~= nil then
        if type(linked) ~= 'table' then return end
        for _, id in ipairs(linked) do Add(id) end
    end
    if not ambiguous then return candidate end
end

local function AuraSelector(item)
    local info = item.GetCooldownInfo and item:GetCooldownInfo()
    if not Readable(info) or type(info) ~= 'table' then return end
    local priorities, valid, count = {}, true, 0
    local function Add(id, priority)
        if not Readable(id) then valid = false; return end
        if id == nil then return end
        if type(id) ~= 'number' then valid = false; return end
        if not priorities[id] then count = count + 1 end
        priorities[id] = math.min(priorities[id] or priority, priority)
    end
    -- Mirror the native GetAssociatedAuraSpellPriority metadata. All ranks in
    -- linkedSpellIDs share priority 1; no spell names, ranks or classes are guessed.
    Add(info.spellID, 4)
    Add(info.overrideSpellID, 3)
    Add(info.overrideTooltipSpellID, 2)
    local linked = info.linkedSpellIDs
    if not Readable(linked) then return end
    if linked ~= nil then
        if type(linked) ~= 'table' then return end
        for _, id in ipairs(linked) do Add(id, 1) end
    end
    local current = info.linkedSpellID
    if Readable(current) then
        Add(current, 1)
    else
        -- An opaque active linked spell is redundant only when every candidate
        -- already has the native highest priority. Otherwise selection is unknown.
        for _, priority in pairs(priorities) do
            if priority ~= 1 then valid = false end
        end
    end
    if valid and count > 0 then return priorities, count end
end

local function SameSelector(buff, item, spell, otherSpell)
    local a, countA = AuraSelector(buff)
    local b, countB = AuraSelector(item)
    if not a or not b or countA ~= countB then return false end
    if spell and not b[spell] then return false end
    if otherSpell and not a[otherSpell] then return false end
    for id, priority in pairs(a) do
        if b[id] ~= priority then return false end
    end
    return true
end

local function SameAura(buff, item, id, unit, secretID)
    local otherID, otherUnit, otherSecret = Identity(item)
    if not otherUnit or unit ~= otherUnit then return false end
    if not secretID and not otherSecret then return id == otherID end
    -- Combat can make instance IDs secret. Match readable native effect metadata
    -- instead, while all visibility and aura-timer checks remain mandatory.
    local spell, otherSpell = AuraSpell(buff), AuraSpell(item)
    if spell and otherSpell then return spell == otherSpell end
    return SameSelector(buff, item, spell, otherSpell)
end

local function IsAuraTimer(item)
    local auraTimer = item.wasSetFromAura
    if not Readable(auraTimer) or auraTimer ~= true or not item.GetTotemData then return false end
    -- Native totem timers use the aura flag too, taking precedence over any
    -- cached aura identity. They cannot prove the buff is displayed here.
    local totem = item:GetTotemData()
    return Readable(totem) and totem == nil
end

local function RejectReason(item)
    if not IsAuraTimer(item) then return 'not displaying an aura timer' end
    if not Visible(item) then return 'spell icon hidden or transparent' end
    if not Visible(item.Cooldown) then return 'native timer hidden or transparent' end
    if addon.Cooldowns and not addon.Cooldowns:ShouldDisplayItem(item) then return 'combat visibility override' end
    if addon.TimerLayer and (addon.TimerLayer:IsEnabledFor(item) or addon.TimerLayer:IsReplacing(item)) then
        return 'spell timer replacement enabled'
    end
end

local function Safe(value)
    if not Readable(value) then return '<secret>' end
    return tostring(value)
end

function duplicates:HasVisibleDuplicate(buff, report)
    local active = buff:IsActive()
    if not Readable(active) or active ~= true then
        if report then report('buff inactive or active state secret') end
        return false
    end
    local id, unit, secretID = Identity(buff)
    if not unit then
        if report then report('buff aura identity or unit unavailable') end
        return false
    end
    if report then
        report('buff unit=' .. unit .. ', instance=' .. (secretID and '<secret>' or Safe(id)) .. ', resolved spell=' .. Safe(AuraSpell(buff)))
    end
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer}) do
        if viewer.itemFramePool and Visible(viewer) then
            for item in viewer.itemFramePool:EnumerateActive() do
                local reason = RejectReason(item)
                local matches = not reason and SameAura(buff, item, id, unit, secretID)
                if report then
                    local info = item:GetCooldownInfo() or {}
                    report('spell ' .. Safe(info.spellID) .. ': ' .. (reason or (matches and 'MATCH' or 'aura identity mismatch')))
                    if not reason and not matches then
                        report('  resolved=' .. Safe(AuraSpell(item)) .. ', aura spell=' .. Safe(item.GetAuraSpellID and item:GetAuraSpellID()) .. ', linked=' .. Safe(info.linkedSpellID))
                        report('  base=' .. Safe(info.spellID) .. ', override=' .. Safe(info.overrideSpellID) .. ', tooltip=' .. Safe(info.overrideTooltipSpellID))
                        if Readable(info.linkedSpellIDs) and type(info.linkedSpellIDs) == 'table' then
                            local linked = {}
                            for _, spell in ipairs(info.linkedSpellIDs) do linked[#linked + 1] = Safe(spell) end
                            report('  linked candidates=' .. table.concat(linked, ','))
                        end
                    end
                end
                if matches then return true end
            end
        elseif report then report('spell viewer hidden or transparent') end
    end
    return false
end

-- Local diagnostics use the same checks as the hide decision; no secret values
-- are compared, converted or exposed. An optional name limits the output.
if SlashCmdList then
    SLASH_COOLDOWNMANAGERPLUSDEBUG1 = '/cmpdebug'
    SlashCmdList.COOLDOWNMANAGERPLUSDEBUG = function(query)
        query = (query or ''):lower()
        local found = false
        for _, entry in ipairs(addon.Buffs:GetEntries()) do
            if entry.name:lower():find(query, 1, true) then
                found = true
                print('CMP: ' .. entry.name)
                local db = addon.Buffs:GetDB()
                print('CMP: hide enabled=' .. Safe(addon.Overrides.Resolve(entry.options, 'hideDuplicateBuffs', db.hideDuplicateBuffs))
                    .. ', Edit Mode=' .. Safe(BuffIconCooldownViewer:IsEditing()) .. ', protected=' .. Safe(entry.item:IsProtected()))
                local match = duplicates:HasVisibleDuplicate(entry.item, function(message) print('CMP: ' .. message) end)
                print('CMP: duplicate=' .. Safe(match) .. ', buff shown=' .. Safe(entry.item:IsShown()))
            end
        end
        if not found then print('CMP: no tracked buff matched that name.') end
    end
end
