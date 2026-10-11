local settings = dofile('tests/DatabaseEnvironment.lua')('Hunter', 'Realm')
local addon = {Settings=settings}
local file = io.open('Core/SettingsTransfer.lua')
assert(file, 'combined setup transfer module exists')
file:close()
assert(loadfile('Core/SettingsTransfer.lua'))('CooldownManagerPlus', addon)
local registry, serial = {}, 0
local function clone(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = clone(child) end
    return result
end
-- CBOR/base64 are native C boundaries; emulate their transport, not their implementation.
C_EncodingUtil = {
    SerializeCBOR=function(value) serial=serial+1; local key='data'..serial; registry[key]=clone(value); return key end,
    DeserializeCBOR=function(key) return clone(registry[key]) end,
    EncodeBase64=function(value) return value end, DecodeBase64=function(value) return value end,
}
local native = {tag=1, name='Hunter layout', data='blizzard-export', prepares=0, writes=0}
addon.NativeSettingsTransfer = {
    Export=function() return {specTag=native.tag, layoutName=native.name, blizzard=native.data} end,
    Prepare=function(_,payload)
        native.prepares=native.prepares+1
        if payload.specTag ~= native.tag then return nil, 'Different specialization.' end
        if payload.blizzard == 'invalid' then return nil, 'Invalid Blizzard layout.' end
        return 'merged-native-data'
    end,
    Commit=function(_,data) native.writes=native.writes+1; native.saved=data; return true end,
}
C_CooldownViewer = {GetCooldownViewerCooldownInfo=function(id) if id==1 then return {spellID=123} end end}
local profile = settings:GetDB()
profile.centerIcons=true
profile.effects[1]={alwaysShow=true,hideDuplicateBuffs=false}
local transfer = addon.SettingsTransfer
local exported = assert(transfer:Export())
assert(exported:sub(1,5)=='CMP1:', 'exports a recognizable versioned combined string')
local preview = assert(transfer:Inspect(exported))
assert(preview.payload.settings.centerIcons and preview.payload.settings.effects[1].hideDuplicateBuffs==false, 'export preserves general settings and explicit false overrides')
assert(preview.payload.blizzard=='blizzard-export' and preview.payload.layoutName=='Hunter layout', 'export includes native selected layout')
assert(native.writes==0 and profile.centerIcons, 'preview does not change either settings store')
profile.centerIcons=false
ReloadUI=function() native.reloaded=true end
assert(transfer:Import(exported))
assert(settings:GetDB().centerIcons and native.saved=='merged-native-data' and native.reloaded, 'confirmed import applies both settings stores and reloads')
local function encode(value) return 'CMP1:'..C_EncodingUtil.EncodeBase64(C_EncodingUtil.SerializeCBOR(value)) end
local payload=clone(preview.payload)
payload.version=2
assert(not transfer:Inspect(encode(payload)), 'reject unsupported versions')
payload=clone(preview.payload); payload.settings.centerIcons='yes'
assert(not transfer:Inspect(encode(payload)), 'reject malformed setting types')
payload=clone(preview.payload); payload.settings.effects[1].arbitrary=true
assert(not transfer:Inspect(encode(payload)), 'reject unknown override keys')
assert(not transfer:Inspect('not a setup string'), 'reject invalid encoding without executing input')
assert(not transfer:Inspect(string.rep('x',200001)), 'bound import text size')
payload=clone(preview.payload); payload.class='MAGE'
assert(not transfer:Inspect(encode(payload)), 'reject incompatible class for combined import')
payload=clone(preview.payload); payload.specTag=2
assert(not transfer:Inspect(encode(payload)), 'reject incompatible specialization')
payload=clone(preview.payload); payload.blizzard='invalid'
assert(not transfer:Inspect(encode(payload)), 'native validation failure rejects import')
payload=clone(preview.payload); payload.identities.effects[1]=999
local mismatched=assert(transfer:Inspect(encode(payload)))
assert(not mismatched.payload.settings.effects[1] and mismatched.skipped==1, 'skip overrides whose native spell identity differs')
local writes=native.writes
InCombatLockdown=function() return true end
assert(not transfer:Import(exported) and native.writes==writes, 'combat rejection does not write settings')
InCombatLockdown=function() return false end
addon.NativeSettingsTransfer.Commit=function() return false, 'Native save failed.' end
settings:GetDB().centerIcons=false
assert(not transfer:Import(exported) and not settings:GetDB().centerIcons, 'native write failure preserves CM Plus settings')
print('PASS: combined setup validation, preview isolation, import, reload, class/spec checks, spell identity matching and failure guards')
