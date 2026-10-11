local addon, db = {}, {}
local secret = setmetatable({}, {__eq=function() error('secret compared') end, __lt=function() error('secret ordered') end})
issecretvalue = function(value) return rawequal(value, secret) end
addon.Buffs = {GetDB=function() return db end}
local suppressed, hidden = false, false
addon.TimerLayer = {IsEnabledFor=function() return suppressed end, IsReplacing=function() return false end}
addon.Cooldowns = {ShouldDisplayItem=function() return not hidden end}
local function frame()
    return {shown=true,alpha=1, IsVisible=function(self) return self.shown end, GetEffectiveAlpha=function(self) return self.alpha end}
end
local buff, spell = frame(), frame()
buff.unit, spell.unit = 'target', 'target'
buff.instance, spell.instance = 71, 71
buff.info, spell.info = {spellID=1978}, {spellID=1978}
buff.active = true
spell.wasSetFromAura = true
spell.Cooldown = frame()
function spell:GetTotemData() return self.totem end
function buff:IsActive() return self.active end
for _, item in ipairs({buff,spell}) do
    function item:GetAuraSpellInstanceID() return self.instance end
    function item:GetAuraDataUnit() return self.unit end
    function item:GetCooldownInfo() return self.info end
    function item:GetAuraSpellID() return self.auraSpell end
end
local viewer = frame()
viewer.itemFramePool={EnumerateActive=function() local done=false; return function() if not done then done=true; return spell end end end}
EssentialCooldownViewer, UtilityCooldownViewer = viewer, nil
SlashCmdList={}
assert(loadfile('Overrides.lua'))('CooldownManagerPlus', addon)
assert(loadfile('DuplicateBuffs.lua'))('CooldownManagerPlus', addon)
local duplicates=addon.Duplicates
assert(duplicates:HasVisibleDuplicate(buff), 'matching visible aura timer is a duplicate')
spell.totem={expirationTime=30}
assert(not duplicates:HasVisibleDuplicate(buff), 'totem timer takes precedence over cached aura and cannot hide its buff')
spell.totem=nil
spell.unit='player'
assert(not duplicates:HasVisibleDuplicate(buff), 'same aura instance on another unit is not a duplicate')
spell.unit='target'; spell.instance=72
assert(not duplicates:HasVisibleDuplicate(buff), 'another aura of same spell must not hide the buff')
spell.instance=71; spell.wasSetFromAura=false
assert(not duplicates:HasVisibleDuplicate(buff), 'ordinary cooldown does not replace a buff')
spell.wasSetFromAura=true; suppressed=true
assert(not duplicates:HasVisibleDuplicate(buff), 'effective timer suppression retains buff')
suppressed=false; hidden=true
assert(not duplicates:HasVisibleDuplicate(buff), 'combat-filtered spell retains buff')
hidden=false; viewer.shown=false
assert(not duplicates:HasVisibleDuplicate(buff), 'hidden viewer retains buff')
viewer.shown=true; spell.Cooldown.shown=false
assert(not duplicates:HasVisibleDuplicate(buff), 'hidden aura timer retains buff')
spell.Cooldown.shown=true; spell.alpha=0
assert(not duplicates:HasVisibleDuplicate(buff), 'transparent spell retains buff')
spell.alpha=1; spell.instance=secret
assert(duplicates:HasVisibleDuplicate(buff), 'secret spell aura instance matches through unambiguous native spell metadata')
spell.instance=71; buff.instance=secret
assert(duplicates:HasVisibleDuplicate(buff), 'secret buff aura instance matches through unambiguous native spell metadata')
buff.instance=71; spell.wasSetFromAura=secret
assert(not duplicates:HasVisibleDuplicate(buff), 'secret display state cannot hide buff')
spell.wasSetFromAura=true; buff.active=secret
assert(not duplicates:HasVisibleDuplicate(buff), 'secret buff active state cannot hide buff')
buff.active=true; spell.unit=secret
assert(not duplicates:HasVisibleDuplicate(buff), 'secret unit cannot hide buff')
spell.unit='target'; spell.alpha=secret
assert(not duplicates:HasVisibleDuplicate(buff), 'secret opacity cannot hide buff')
spell.alpha=1; EssentialCooldownViewer=nil; UtilityCooldownViewer=viewer
assert(duplicates:HasVisibleDuplicate(buff), 'utility-only viewer also works')

buff.instance, spell.instance = secret, secret
assert(duplicates:HasVisibleDuplicate(buff), 'two secret instance IDs never need comparison for the same native effect')
spell.info={spellID=3044}
assert(not duplicates:HasVisibleDuplicate(buff), 'different tracked spells do not match secret instances')
spell.info={spellID=1978,linkedSpellIDs={1978,3044}}
assert(not duplicates:HasVisibleDuplicate(buff), 'ambiguous grouped metadata keeps the buff')
spell.info.linkedSpellID=1978
assert(duplicates:HasVisibleDuplicate(buff), 'readable active linked spell resolves a grouped tracker')
spell.info.linkedSpellID=secret
assert(not duplicates:HasVisibleDuplicate(buff), 'secret active linked spell does not resolve ambiguity')
spell.auraSpell=1978
assert(duplicates:HasVisibleDuplicate(buff), 'readable current aura spell identifies grouped display')
spell.auraSpell=3044
assert(not duplicates:HasVisibleDuplicate(buff), 'current aura spell takes precedence over base metadata')
spell.auraSpell=secret; spell.info={spellID=secret}
assert(not duplicates:HasVisibleDuplicate(buff), 'unknown or secret spell metadata keeps the buff')
spell.info={spellID=1978}; spell.instance=nil
assert(not duplicates:HasVisibleDuplicate(buff), 'absent aura identity is not treated as a secret active aura')
spell.instance=secret; spell.unit='player'
assert(not duplicates:HasVisibleDuplicate(buff), 'metadata fallback still requires matching units')
spell.unit='target'
buff.info={spellID=1978,overrideSpellID=1978,linkedSpellID=secret,linkedSpellIDs={1978,13549,13550}}
spell.info={spellID=1978,overrideSpellID=1978,linkedSpellID=secret,linkedSpellIDs={1978,13549,13550}}
assert(duplicates:HasVisibleDuplicate(buff), 'identical native rank selectors match despite secret current rank and instance IDs')
spell.info.linkedSpellIDs={1978,13549}
assert(not duplicates:HasVisibleDuplicate(buff), 'partially overlapping rank selectors are not equivalent')
spell.info={spellID=1978,linkedSpellID=secret,linkedSpellIDs={1978,13549,13550},overrideTooltipSpellID=3044}
assert(not duplicates:HasVisibleDuplicate(buff), 'different aura selection metadata preserves the buff')
spell.info={spellID=1978,linkedSpellID=secret,linkedSpellIDs={secret}}
assert(not duplicates:HasVisibleDuplicate(buff), 'secret static candidates cannot prove equivalent trackers')
spell.info={spellID=1978,overrideSpellID=1978,linkedSpellID=secret,linkedSpellIDs={13550,1978,13549}}
assert(duplicates:HasVisibleDuplicate(buff), 'equivalent selector priority maps do not depend on metadata list ordering')
buff.instance,spell.instance=71,72
assert(not duplicates:HasVisibleDuplicate(buff), 'readable differing instances still take precedence over equivalent metadata')
buff.instance,spell.instance=secret,secret
spell.unit='target'; suppressed=true
assert(not duplicates:HasVisibleDuplicate(buff), 'metadata fallback still respects timer suppression')

print('PASS: duplicate detection, exact instances, secret-instance metadata fallback, ambiguity, units, visibility and timer suppression')

suppressed=false
spell.info={spellID=1978,linkedSpellIDs={1978,3044},linkedSpellID=secret}
local lines={}
addon.Buffs.GetEntries=function() return {{name='Serpent Sting',item=buff,options={}}} end
BuffIconCooldownViewer={IsEditing=function() return false end}
buff.IsProtected=function() return false end
buff.IsShown=function() return true end
local originalPrint=print
print=function(line) lines[#lines+1]=line end
SlashCmdList.COOLDOWNMANAGERPLUSDEBUG('Serpent Sting')
print=originalPrint
local output=table.concat(lines,'\n')
assert(output:find('aura identity mismatch',1,true) and output:find('linked=<secret>',1,true), 'diagnostic exposes rejection without comparing or converting secret fields')
assert(output:find('duplicate=false',1,true), 'diagnostic reports the same result as production check')
print('PASS: diagnostic command reports live rejection conditions safely')
