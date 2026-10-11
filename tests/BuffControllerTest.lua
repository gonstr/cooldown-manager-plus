-- Exercise real controller logic with the WoW-only frame boundary simulated.
local addon = {}
local timers, combat = {}, false
local registeredEvents, eventHandler = {}, nil
CreateFrame = function()
    return {RegisterEvent = function(_, event) registeredEvents[event]=true end, RegisterUnitEvent = function() end,
        SetScript = function(_, name, callback) if name=="OnEvent" then eventHandler=callback end end}
end
C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}
C_Spell = {GetSpellInfo = function(id) return {name = 'Spell ' .. id, iconID = id} end}
InCombatLockdown = function() return combat end
local secret = {}
issecretvalue = function(value) return value == secret end
hooksecurefunc = function(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local function drain()
    local iterations = 0
    while #timers > 0 do
        iterations = iterations + 1
        assert(iterations < 20, 'updates must settle rather than schedule forever')
        local pending = timers
        timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
end
local function item(id, unit, active)
    local object = {id = id, unit = unit, active = active, layoutIndex = id, shown = active}
    object.Icon = {
        SetDesaturated = function(self, value) self.gray = value end,
        SetVertexColor = function(self, r) self.tint = r end,
    }
    function object:GetCooldownID() return self.id end
    function object:GetCooldownInfo() return {spellID = self.id} end
    function object:GetAuraDataUnit() return self.unit end
    function object:IsActive() return self.active end
    function object:GetWidth() return 40 end
    function object:GetScale() return 1 end
    function object:IsProtected() return self.protected end
    function object:ShouldBeShown() return self.active == true end
    function object:IsShown() return self.shown end
    function object:SetShown(value) self.shown = value end
    function object:ClearAllPoints() self.x = nil end
    function object:SetPoint(_, _, _, x) self.x = x end
    function object:UpdateShownState() self.shown = self:ShouldBeShown() end
    function object:RefreshData() self:UpdateShownState() end
    return object
end
local player, target = item(1, 'player', true), item(2, 'target', true)
local items = {player, target}
local viewer = {iconPadding = 10}
viewer.itemFramePool = {EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return items[i] end
end}
function viewer:IsEditing() return self.editing end
function viewer:GetItemContainerFrame() return self end
function viewer:Layout() player.x, target.x = -23, 23 end
function viewer:RefreshData() end
function viewer:SetHideWhenInactive() end
BuffIconCooldownViewer = viewer
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('BuffLayoutModel.lua'))('ForeverAddonTest', addon)
assert(loadfile('BuffLayout.lua'))('ForeverAddonTest', addon)
drain()
addon.Buffs:SetEffect(2, 'alwaysShow', true)
target.unit, target.active = nil, false
target:RefreshData()
drain()
assert(target.shown and target.Icon.gray, 'missing buff stays visible and gray')
target.unit, target.active = 'target', true
target:RefreshData()
drain()
assert(target.shown and not target.Icon.gray and target.Icon.tint == 1, 'applied target regains full color')
addon.Buffs:SetEffect(2, 'alwaysShow', false)
target.active = false
target:RefreshData()
drain()
assert(not target.shown and not target.Icon.gray, 'removing override restores native hidden state')
player.active = secret
addon.Buffs:SetEffect(1, 'alwaysShow', true)
drain()
assert(not player.shown, 'secret active state must not force an always-show override')
assert(CooldownManagerPlusDB.observedGroups == nil and CooldownManagerPlusDB.gap == nil)
player.active, player.unit, target.active, target.unit = true, 'player', true, 'target'
addon.Buffs:SetSeparate(true)
drain()
assert(player.x < 0 and target.x > 0, 'self left and target right in the existing viewer')
target.unit, target.active = nil, false
addon.Buffs:SetEffect(2, 'alwaysShow', true)
drain()
assert(target.x > 0, 'missing target effect retains its observed group')
addon.Buffs:SetSeparate(false)
drain()
assert(player.x == -23 and target.x == 23, 'disable restores native viewer layout')
local secondSelf = item(3, 'player', true)
items[#items + 1] = secondSelf
function viewer:GetAdditionalPaddingOffset() return -4 end
addon.Buffs:SetSeparate(true)
drain()
assert(secondSelf.x - player.x == 46, 'within-group spacing matches native icon padding plus art correction')
assert(target.x - secondSelf.x == 62, 'only the self/target boundary adds the 16-unit gap')
local selfX, secondX, targetX = player.x, secondSelf.x, target.x
addon.Buffs:SetEffect(2, 'alwaysShow', false)
target.active=false
target:RefreshData()
drain()
assert(not target.shown and player.x==selfX and secondSelf.x==secondX, 'hiding target buffs preserves self slots')
secondSelf.active=false
secondSelf:RefreshData()
drain()
assert(player.x==selfX, 'a single remaining self buff does not recenter')
local reserved=addon.Buffs:GetSplitLayout({player},40,6)
assert(#reserved==3, 'split layout retains hidden tracked slots for compact positioning too')
target.active=true; secondSelf.active=true
target:RefreshData(); secondSelf:RefreshData()
drain()
assert(player.x==selfX and target.x==targetX, 'reappearing buffs restore the same slots')
target.active=false; secondSelf.active=false
addon.Buffs:SetEffect(2, 'alwaysShow', false)
target:RefreshData(); secondSelf:RefreshData()
drain()
addon.Buffs:SetCentered(true)
drain()
assert(player.x==0, 'centering puts a single visible buff at the center')
local centered=addon.Buffs:GetSplitLayout({player},40,6)
assert(#centered==1, 'centering excludes inactive slots from the split row')
target.active=true; target:RefreshData()
drain()
assert(player.x==-31 and target.x==31, 'centered separate groups retain the gap and grow equally outward')
addon.Buffs:SetSeparate(false)
drain()
assert(player.x==-23 and target.x==23, 'centering also works with native order and no group gap')
target.active=false; target:RefreshData()
drain()
assert(player.x==0, 'native-order centered row shrinks back to the middle')
addon.Buffs:SetCentered(false)
drain()
assert(player.x==-23, 'disabling centering restores native fixed positions')
target.active=true; secondSelf.active=true
addon.Buffs:SetSeparate(true)
drain()
print('PASS: missing/applied transitions, native defaults, stable self/target slots and restoration')

local duplicate = true
addon.Duplicates = {HasVisibleDuplicate=function() return duplicate end}
local db = addon.Buffs:GetDB()
db.hideDuplicateBuffs = true
player.active = true
addon.Buffs:Apply()
assert(not player.shown, 'global duplicate setting hides confirmed duplicate despite Always show')
player:UpdateShownState()
assert(not player.shown, 'native refresh never exposes a confirmed duplicate before queued layout runs')
drain()
addon.Buffs:SetEffect(1, 'hideDuplicateBuffs', false)
drain()
assert(player.shown, 'per-buff keep-visible exception overrides global duplicate setting')
db.hideDuplicateBuffs = false
addon.Buffs:SetEffect(1, 'hideDuplicateBuffs', true)
drain()
assert(not player.shown, 'per-buff duplicate hiding works with global disabled')
viewer.editing=true
addon.Buffs:Apply()
assert(player.shown, 'Edit Mode reveals duplicate buffs')
viewer.editing=false; duplicate=false
addon.Buffs:Apply()
assert(player.shown, 'buff returns as soon as no visible duplicate exists')
addon.Buffs:ResetOverrides(1)
assert(not addon.Buffs:GetDB().effects[1], 'per-buff reset clears shared Always show and dropdown overrides')

CooldownManagerPlusDB = {optionsVersion=2,effects={[1]={alwaysShow=true,notifyMissing=true}},spellTimers={[1]=false,[2]=true}}
local migrated = addon.Buffs:GetDB()
assert(migrated.notifyMissingSelfBuffs and migrated.replaceCooldownTimers, 'previous selections migrate to global options')
assert(migrated.spellTimers == nil and migrated.effects[1].notifyMissing == nil, 'obsolete per-icon settings removed')
assert(migrated.effects[1].alwaysShow, 'Always show selections are retained')

assert(registeredEvents.PLAYER_REGEN_DISABLED and registeredEvents.PLAYER_REGEN_ENABLED, 'reminders refresh on both combat boundaries')
local reminderUpdates=0
addon.BuffReminder={Update=function() reminderUpdates=reminderUpdates+1 end}
for _, event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED'}) do
    local previous=reminderUpdates
    eventHandler(nil,event)
    drain()
    assert(reminderUpdates>previous, event .. ' refreshes the reminder without an aura event')
end
