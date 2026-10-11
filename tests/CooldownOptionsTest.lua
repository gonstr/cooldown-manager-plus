local addon, timers, combat = {}, {}, false
local eventHandler
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) eventHandler=fn end} end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
C_Spell = {GetSpellInfo = function(id) return {name = 'Spell ' .. id, iconID = id} end}
UnitAffectingCombat = function() return combat end
hooksecurefunc = function(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...) original(self, ...); callback(self, ...) end
end
local function makeViewer(id)
    local item = {alpha = 0.8, layoutIndex = 1}
    function item:GetCooldownID() return id end
    function item:GetCooldownInfo() return {spellID = id} end
    function item:GetAlpha() return self.alpha end
    function item:SetAlpha(a) self.alpha = a end
    function item:UpdateShownState() end
    function item:RefreshData() end
    local viewer = {editing = false}
    function viewer:IsEditing() return self.editing end
    function viewer:RefreshData() end
    function viewer:SetIsEditing(value) self.editing=value end
    function viewer:UpdateShownState() end
    viewer.itemFramePool = {EnumerateActive = function()
        local returned = false
        return function() if not returned then returned = true; return item end end
    end}
    return viewer, item
end
local essential, essentialItem = makeViewer(1)
local utility, utilityItem = makeViewer(2)
EssentialCooldownViewer, UtilityCooldownViewer = essential, utility
local db = {}
addon.Buffs = {GetDB = function() return db end}
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('CooldownOptions.lua'))('ForeverAddonTest', addon)
local options = addon.Cooldowns
options:SetOnlyCombat(true)
assert(essentialItem.alpha == 0 and not options:ShouldDisplayItem(essentialItem))
assert(utilityItem.alpha == 0.8 and options:ShouldDisplayItem(utilityItem), 'unconfigured cooldown is unaffected')
combat = true
options:Apply()
assert(essentialItem.alpha == 0.8 and options:ShouldDisplayItem(essentialItem), 'combat restores original alpha')
combat, essential.editing = false, true
options:Apply()
assert(essentialItem.alpha == 0.8, 'Edit Mode keeps filtered spells visible')
essential.editing = false
options:Apply()
assert(essentialItem.alpha == 0)
options:SetOnlyCombat(false)
assert(essentialItem.alpha == 0.8 and options:ShouldDisplayItem(essentialItem), 'unchecking restores native presentation')
options:SetOnlyCombat(true)
assert(utilityItem.alpha == 0.8, 'utility visibility remains native')
assert(#options:GetEntries(essential) == 1, 'hidden essential spells remain listed')
options:SetUtilityOnlyCombat(true)
assert(utilityItem.alpha == 0 and not options:ShouldDisplayItem(utilityItem), 'utility setting hides its row outside combat')
assert(essentialItem.alpha == 0, 'essential setting remains independent')
combat = true
options:Apply()
assert(utilityItem.alpha == 0.8 and essentialItem.alpha == 0.8, 'combat restores both rows')
combat, utility.editing = false, true
options:Apply()
assert(utilityItem.alpha == 0.8 and essentialItem.alpha == 0, 'Edit Mode reveals utility without affecting essential filtering')
utility.editing = false
options:Apply()
assert(utilityItem.alpha == 0)
options:SetUtilityOnlyCombat(false)
assert(utilityItem.alpha == 0.8 and essentialItem.alpha == 0, 'disabling utility filter restores only utility')
print('PASS: independent essential/utility combat visibility, alpha restoration, Edit Mode, hidden-spell listing')

options:SetOverride(1, 'combatOnly', false)
assert(essentialItem.alpha == 0.8, 'per-spell always-visible exception restores alpha outside combat')
options:SetOnlyCombat(false)
options:SetOverride(1, 'combatOnly', true)
assert(essentialItem.alpha == 0, 'per-spell combat filter works with global filter disabled')
options:ResetOverrides(1)
assert(essentialItem.alpha == 0.8, 'reset restores global visibility')

local buffUpdates=0
addon.Buffs.QueueUpdate=function() buffUpdates=buffUpdates+1 end
eventHandler()
for _, fn in ipairs(timers) do fn() end
timers={}; buffUpdates=0
essential:UpdateShownState()
for _, fn in ipairs(timers) do fn() end
assert(buffUpdates>0, 'native viewer visibility change rechecks duplicate buffs even when timer replacement is off')

local immediateHides=0
addon.Buffs.HideDuplicates=function() immediateHides=immediateHides+1 end
essentialItem:RefreshData()
assert(immediateHides>0, 'spell aura refresh hides duplicates synchronously before queued updates')
