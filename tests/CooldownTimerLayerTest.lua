local addon, db, created, combat = {}, {}, {}, false
addon.Buffs = {GetDB = function() return db end}
local methods = {}
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha or 0.8 end
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:GetFrameLevel() return 2 end
function methods:GetHideCountdownNumbers() return false end
function methods:SetCooldownFromDurationObject(v) self.duration=v end
function methods:SetSwipeTexture(v) self.swipeTexture=v end
function methods:Clear() self.duration=nil end
for _,name in ipairs({'SetAllPoints','SetFrameLevel','SetDrawBling','SetDrawEdge','SetDrawSwipe','SetSwipeColor','EnableMouse','SetHideCountdownNumbers','RegisterEvent','SetScript'}) do methods[name]=function() end end
local function widget() return setmetatable({}, {__index=methods}) end
CreateFrame = function(kind,_,parent)
    local result=widget()
    if kind=='Cooldown' then created[parent]=result end
    return result
end
InCombatLockdown=function() return combat end
C_Timer={NewTicker=function(_,fn) return {Cancel=function() end,run=fn} end}
-- The opaque token errors if code tries arithmetic or ordering on it.
local duration=setmetatable({}, {__add=function() error('secret duration read') end,__lt=function() error('secret duration read') end})
C_Spell={GetSpellCooldownDuration=function(id,ignoreGCD) assert(ignoreGCD); if id==3044 then return duration end end}
local function item(id,extra)
    local info=extra or {}; info.spellID=id
    return {Cooldown=widget(),GetCooldownID=function() return id end,GetCooldownInfo=function() return info end,
        RefreshData=function() error('native refresh must never be called') end}
end
local sting,shot,charges,equipment=item(1978),item(3044),item(4,{charges=true}),item(5,{equipSlot=13})
local active={sting,shot,charges,equipment}
local editing=false
EssentialCooldownViewer={IsEditing=function() return editing end,itemFramePool={EnumerateActive=function()
    local i=0; return function() i=i+1; return active[i] end
end}}
UtilityCooldownViewer=nil
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('CooldownTimerLayer.lua'))('ForeverAddonTest',addon)
local nativeRefresh=shot.RefreshData
addon.TimerLayer:SetEnabled(true)
assert(sting.Cooldown.alpha==0 and shot.Cooldown.alpha==0)
assert(created[sting].shown and created[sting].duration==nil, 'no debuff/GCD timer for sting')
assert(created[shot].swipeTexture=='Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe', 'replacement uses the icon-shaped native swipe instead of the default circular texture')
assert(created[shot].duration==duration, 'opaque cooldown passed straight to engine')
assert(not created[charges] and not created[equipment], 'unsupported icons retain native timers')
assert(shot.RefreshData==nativeRefresh, 'native methods are untouched')
editing=true; addon.TimerLayer:Apply()
assert(shot.Cooldown.alpha==0.8 and not created[shot].shown)
editing=false; addon.TimerLayer:Apply()
active={sting}; addon.TimerLayer:Apply()
assert(shot.Cooldown.alpha==0.8, 'released item restored')
local new=item(3044); active={new}; combat=true; addon.TimerLayer:Apply()
assert(not created[new] and new.Cooldown.alpha==nil, 'defer creation during combat')
combat=false; addon.TimerLayer:Apply(); assert(created[new])
addon.TimerLayer:SetEnabled(false)
assert(new.Cooldown.alpha==0.8 and not created[new].shown)
print('PASS: visual replacement, opaque durations, native restoration, pool release, Edit Mode, combat deferral')

active={sting,shot}
addon.TimerLayer:SetOverride(1978, false)
addon.TimerLayer:SetEnabled(true)
assert(sting.Cooldown.alpha==0.8 and shot.Cooldown.alpha==0, 'native buff timer can be retained for one spell')
addon.TimerLayer:SetEnabled(false)
addon.TimerLayer:SetOverride(3044, true)
assert(shot.Cooldown.alpha==0 and created[shot].shown, 'per-spell suppression works while global option is off')
addon.TimerLayer:SetOverride(3044, nil)
assert(shot.Cooldown.alpha==0.8 and not created[shot].shown, 'Follow global restores native timer')
