local _, addon = ...
local eligibility = {}
addon.BuffEligibility = eligibility
local cache = {}
local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Evaluate(id)
    local baseCooldown = C_Spell.GetSpellBaseCooldown or GetSpellBaseCooldown
    local inBook = C_SpellBook and C_SpellBook.IsSpellInSpellBook or IsPlayerSpell
    local passive = C_Spell.IsSpellPassive or IsPassiveSpell
    if not baseCooldown or not inBook or not passive then return false end
    local cooldown = baseCooldown(id)
    local learned = inBook(id)
    local isPassive = passive(id)
    return Readable(cooldown) and type(cooldown) == 'number' and cooldown == 0
        and Readable(learned) and learned == true
        and Readable(isPassive) and isPassive == false
end
function eligibility:IsEligible(id)
    if not Readable(id) or type(id) ~= 'number' then return false end
    -- Spellbook APIs may be restricted during combat; retain only confirmed metadata.
    if InCombatLockdown() then return cache[id] == true end
    local ok, result = pcall(Evaluate, id)
    cache[id] = ok and result == true
    return cache[id]
end

function eligibility:IsEligibleCooldown(info)
    if not Readable(info) or type(info) ~= 'table' then return false end
    -- Group trackers such as Aspects have a synthetic spell ID that is not in
    -- the spellbook. Qualify through their real linked or replacement spells.
    if self:IsEligible(info.spellID) or self:IsEligible(info.overrideSpellID) then return true end
    local linked = info.linkedSpellIDs
    if Readable(linked) and type(linked) == 'table' then
        for _, id in ipairs(linked) do
            if self:IsEligible(id) then return true end
        end
    end
    return false
end
