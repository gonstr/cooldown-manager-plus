local _, addon = ...
local transfer = {}
addon.SettingsTransfer = transfer
local prefix, limit = 'CMP1:', 200000
local fields = {effects={alwaysShow=true, notifyMissingSelfBuffs=true, hideDuplicateBuffs=true},
    spellOverrides={combatOnly=true, replaceCooldownTimers=true}}

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function ID(value)
    return type(value)=='number' and value>0 and value<1000000000 and value==math.floor(value)
end
local function Spell(id)
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then return nil end
    local ok, spell = pcall(function()
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
        local value = info and info.spellID
        return Readable(value) and ID(value) and value or nil
    end)
    return ok and spell or nil
end
local function Available()
    return C_EncodingUtil and C_EncodingUtil.SerializeCBOR and C_EncodingUtil.DeserializeCBOR
        and C_EncodingUtil.EncodeBase64 and C_EncodingUtil.DecodeBase64
end
local function Busy()
    return InCombatLockdown and InCombatLockdown()
end

function transfer:Export()
    if Busy() then return nil, 'Leave combat before exporting settings.' end
    if not Available() then return nil, 'Settings encoding is unavailable in this build.' end
    local native, message = addon.NativeSettingsTransfer:Export()
    if not native then return nil, message end
    local profile = addon.Settings:GetDB()
    local payload = {version=1, class=profile.characterClass, specTag=native.specTag,
        specText=native.specText, layoutName=native.layoutName, blizzard=native.blizzard,
        settings={}, identities={effects={},spellOverrides={}}}
    for key, default in pairs(addon.Settings.defaults) do
        if type(default)=='boolean' then payload.settings[key] = profile[key] == true end
    end
    for field, keys in pairs(fields) do
        payload.settings[field] = {}
        for id, options in pairs(profile[field]) do
            local spell = ID(id) and Spell(id)
            if spell then
                local entry = {}
                for key in pairs(keys) do
                    if type(options[key])=='boolean' then entry[key]=options[key] end
                end
                if next(entry) then
                    payload.settings[field][id] = entry
                    payload.identities[field][id] = spell
                end
            end
        end
    end
    local ok, result = pcall(function()
        return prefix .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.SerializeCBOR(payload))
    end)
    if not ok or #result>limit then return nil, 'Unable to encode these settings.' end
    return result
end

function transfer:Inspect(text)
    if Busy() then return nil, 'Leave combat before importing settings.' end
    if not Available() then return nil, 'Settings encoding is unavailable in this build.' end
    if type(text)~='string' or #text>limit then return nil, 'Invalid settings string.' end
    text = text:gsub('%s', '')
    if text:sub(1,#prefix)~=prefix then return nil, 'Paste a CM Plus settings string.' end
    local ok, payload = pcall(function()
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecodeBase64(text:sub(#prefix+1)))
    end)
    if not ok or type(payload)~='table' or payload.version~=1 then return nil, 'Invalid or unsupported settings string.' end
    local profile = addon.Settings:GetDB()
    if payload.class~=profile.characterClass then return nil, 'These settings are for a different class.' end
    if (type(payload.specTag)~='number' and type(payload.specTag)~='string')
        or type(payload.layoutName)~='string' or #payload.layoutName>200
        or type(payload.blizzard)~='string' or #payload.blizzard>limit
        or type(payload.settings)~='table' or type(payload.identities)~='table'
        or (payload.specText~=nil and (type(payload.specText)~='string' or #payload.specText>200)) then
        return nil, 'Invalid settings data.'
    end
    for key, value in pairs(payload.settings) do
        if addon.Settings.defaults[key]==nil or (not fields[key] and type(value)~='boolean') then
            return nil, 'The string contains invalid settings.'
        end
    end
    local clean, skipped, count = {}, 0, 0
    for key, default in pairs(addon.Settings.defaults) do
        if type(default)=='boolean' then clean[key] = payload.settings[key] == true end
    end
    for field, keys in pairs(fields) do
        local entries, identities = payload.settings[field], payload.identities[field]
        if type(entries)~='table' or type(identities)~='table' then return nil, 'Invalid per-icon settings.' end
        clean[field] = {}
        local total = 0
        for id, options in pairs(entries) do
            total = total + 1
            if total>1000 or not ID(id) or type(options)~='table' or not ID(identities[id]) then
                return nil, 'Invalid per-icon settings.'
            end
            for key, value in pairs(options) do
                if not keys[key] or type(value)~='boolean' then return nil, 'Invalid per-icon option.' end
            end
            if Spell(id)==identities[id] then
                clean[field][id] = options
                count = count + 1
            else skipped = skipped + 1 end
        end
    end
    payload.settings = clean
    local prepared, message = addon.NativeSettingsTransfer:Prepare(payload)
    if not prepared then return nil, message end
    return {payload=payload, prepared=prepared, skipped=skipped, count=count}
end

function transfer:Import(text)
    -- Validate against the current combat, spec and native layout state before
    -- committing either settings store.
    local preview, message = self:Inspect(text)
    if not preview then return false, message end
    local ok
    ok, message = addon.NativeSettingsTransfer:Commit(preview.prepared)
    if not ok then return false, message end
    addon.Settings:Replace(preview.payload.settings)
    ReloadUI()
    return true
end
