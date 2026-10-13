local loadCharacter = dofile('tests/DatabaseEnvironment.lua')
CooldownManagerPlusDB = {centerBuffs=true, compact=true, effects={[1978]={alwaysShow=true, hideDuplicateBuffs=false}},
    spellTimers={[1978]=true}, essentialOnlyCombat=true}
local hunter = loadCharacter('Hunter', 'Realm')
local profile = hunter:GetDB()
assert(not profile.centerIcons and not profile.classAuraStyle and not profile.replaceCooldownTimers, 'old settings are discarded instead of migrated')
assert(next(profile.effects) == nil, 'old per-icon overrides are discarded')
assert(not CooldownManagerPlusDB.global or not CooldownManagerPlusDB.global.legacySettings, 'no legacy backup is created')
profile.effects[1978] = {alwaysShow=true, hideDuplicateBuffs=false}
profile.swingSparks = true
local mage = loadCharacter('Mage', 'Realm')
local fresh = mage:GetDB()
assert(not fresh.centerIcons and not fresh.classAuraStyle and not fresh.essentialOnlyCombat, 'another character starts with built-in defaults')
assert(next(fresh.effects) == nil and next(fresh.spellOverrides) == nil, 'new character has no spell or buff overrides')
fresh.notifyMissingSelfBuffs = true
hunter = loadCharacter('Hunter', 'Realm')
assert(hunter:GetDB().swingSparks and not hunter:GetDB().notifyMissingSelfBuffs, 'character settings remain independent on relog')
assert(hunter:GetDB().effects[1978].hideDuplicateBuffs == false, 'new profile preserves explicit false overrides')
local otherRealm = loadCharacter('Hunter', 'Other Realm')
assert(not otherRealm:GetDB().swingSparks, 'same name on another realm has independent settings')
CooldownManagerPlusDB = nil
assert(not loadCharacter('Fresh', 'Realm'):GetDB().swingSparks, 'fresh installation starts with defaults')
local source = loadCharacter('Source', 'Realm')
source:GetDB().centerIcons = true
source:GetDB().effects[1] = {alwaysShow=true, hideDuplicateBuffs=false}
source:GetDB().effects[2] = {alwaysShow=true}
C_CooldownViewer = {GetCooldownViewerCooldownInfo=function(id)
    if id == 1 then return {spellID=123} end
end}
local destination = loadCharacter('Destination', 'Realm')
assert(destination:GetCharacters()[1] == 'Fresh - Realm', 'copy menu lists saved characters in sorted order')
assert(destination:CopyCharacter('Source - Realm'), 'copy an existing character')
assert(destination:GetDB().centerIcons and destination:GetDB().effects[1].hideDuplicateBuffs == false, 'copy general settings and compatible explicit overrides')
assert(not destination:GetDB().effects[2], 'skip overrides unavailable in native Cooldown Manager data')
destination:GetDB().effects[1].alwaysShow = false
assert(CooldownManagerPlusDB.profiles['Source - Realm'].effects[1].alwaysShow, 'copy is independent of source')
assert(not destination:CopyCharacter('Missing - Realm'), 'reject unknown source without changing settings')
assert(destination:GetDB().centerIcons and not destination:GetDB().effects[1].alwaysShow, 'invalid copy preserves current configuration')
assert(not destination:CopyCharacter('Destination - Realm'), 'reject copying current character to itself')
InCombatLockdown = function() return true end
assert(not destination:CopyCharacter('Source - Realm'), 'copy is blocked in combat')
InCombatLockdown = function() return false end
CooldownManagerPlusDB.profiles['Source - Realm'].characterClass = 'MAGE'
assert(destination:CopyCharacter('Source - Realm'), 'copy visual settings from a different class')
assert(destination:GetDB().centerIcons and next(destination:GetDB().effects) == nil, 'different class copies general settings without per-icon overrides')
print('PASS: real AceDB fresh defaults, character/realm isolation, persistence, independent copying, class and entry compatibility, combat guard')
