local addon, combat = {}, false
local secret={}
issecretvalue=function(value) return value==secret end
InCombatLockdown=function() return combat end
C_Spell={IsSpellPassive=function(id) return id==3 end}
C_SpellBook={IsSpellInSpellBook=function(id) return id~=4 and id~=1324056 end}
GetSpellBaseCooldown=function(id) if id==2 then return 10000 elseif id==5 then return secret end; return 0 end
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('BuffEligibility.lua'))('ForeverAddonTest',addon)
assert(addon.BuffEligibility:IsEligible(1), 'learned non-passive buff with zero spell cooldown is eligible')
for _, id in ipairs({2,3,4,5}) do assert(not addon.BuffEligibility:IsEligible(id), 'cooldown, passive, unlearned and secret metadata are excluded') end
local aspects={spellID=1324056,overrideSpellID=1324056,linkedSpellIDs={4,2,3,5,13165}}
assert(not addon.BuffEligibility:IsEligible(aspects.spellID), 'group tracker itself is not a learned spell')
assert(addon.BuffEligibility:IsEligibleCooldown(aspects), 'Aspects qualifies through a learned linked Aspect')
assert(not addon.BuffEligibility:IsEligibleCooldown({spellID=1324056,linkedSpellIDs={4,2,3,5}}), 'linked spells retain learned, cooldown, passive and readable checks')
assert(not addon.BuffEligibility:IsEligibleCooldown({spellID=secret,linkedSpellIDs=secret}), 'secret metadata is excluded')
assert(addon.BuffEligibility:IsEligibleCooldown({spellID=4,overrideSpellID=1}), 'learned replacement spell qualifies')
combat=true
GetSpellBaseCooldown=function() error('restricted API in combat') end
assert(addon.BuffEligibility:IsEligible(1), 'combat uses cached metadata')
assert(addon.BuffEligibility:IsEligibleCooldown(aspects), 'group tracker uses linked spell eligibility cached before combat')
assert(not addon.BuffEligibility:IsEligible(9), 'uncached spell in combat is not guessed eligible')
assert(not addon.BuffEligibility:IsEligible(secret))
combat=false
assert(not addon.BuffEligibility:IsEligible(1), 'unavailable metadata fails closed')
print('PASS: reminder eligibility, cooldown/passive/unlearned exclusion and combat-safe cached metadata')
