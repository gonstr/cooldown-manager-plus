local _, addon = ...
local overrides = {}
addon.Overrides = overrides
local keys = {
    spell = {'combatOnly', 'replaceCooldownTimers'},
    buff = {'alwaysShow', 'notifyMissingSelfBuffs', 'hideDuplicateBuffs'},
}

function overrides.Resolve(options, key, global)
    local value = options and options[key]
    if type(value) == 'boolean' then return value end
    return global == true
end

function overrides.Get(db, kind, id)
    local entries = kind == 'buff' and db.effects or db.spellOverrides
    return entries and entries[id] or {}
end

function overrides.Set(db, kind, id, key, value)
    local field = kind == 'buff' and 'effects' or 'spellOverrides'
    db[field] = db[field] or {}
    db[field][id] = db[field][id] or {}
    db[field][id][key] = value
end

function overrides.Count(kind, options)
    local count = 0
    for _, key in ipairs(keys[kind]) do
        if type(options[key]) == 'boolean' and (key ~= 'alwaysShow' or options[key]) then
            count = count + 1
        end
    end
    return count
end

function overrides.Reset(db, kind, id)
    local field = kind == 'buff' and 'effects' or 'spellOverrides'
    if db[field] then db[field][id] = nil end
end
