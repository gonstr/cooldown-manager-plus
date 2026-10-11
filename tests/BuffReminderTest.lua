local frames = {}
local function widget()
    local f = {scripts={}}
    function f:SetScript(name,fn) self.scripts[name]=fn end
    function f:SetSize() end
    function f:SetFrameStrata() end
    function f:EnableMouse() end
    function f:SetWidth() end
    function f:SetJustifyH() end
    function f:SetTextColor() end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:ClearAllPoints() end
    function f:SetPoint(...) self.point={...} end
    function f:SetText(v) self.text=v end
    function f:CreateFontString() self.label=widget(); return self.label end
    return f
end
CreateFrame=function() local f=widget(); frames[#frames+1]=f; return f end
UIParent={}
BuffIconCooldownViewer={}
local combat=false
UnitAffectingCombat=function() return combat end
local enabled=true
local compact=false
local anchor={}
local addon={Buffs={GetDB=function() return {compact=compact,notifyMissingSelfBuffs=enabled} end},Compact={GetReminderAnchor=function() if compact then return anchor,60 end end}}
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('BuffLayoutModel.lua'))('ForeverAddonTest',addon)
assert(loadfile('BuffReminder.lua'))('ForeverAddonTest',addon)
local entries={{name='Aspect',reminderEligible=true,knownSelf=true,readableActive=true,active=false}}
addon.BuffReminder:Update(entries,false)
assert(not frames[1].shown, 'missing buffs stay quiet outside combat')
combat=true
addon.BuffReminder:Update(entries,false)
assert(frames[1].shown and frames[1].label.text=='Aspect is missing!')
frames[1].scripts.OnUpdate(frames[1], 0.1)
assert(frames[1].label.point[5] > 0, 'new reminder bounces upward')
local animation = frames[1].scripts.OnUpdate
addon.BuffReminder:Update(entries,false)
assert(frames[1].scripts.OnUpdate == animation, 'unchanged message does not restart bounce')
frames[1].scripts.OnUpdate(frames[1], 0.71)
assert(frames[1].scripts.OnUpdate == animation, 'bounce continues beyond the original two cycles')
animation(frames[1], 10.1)
assert(frames[1].label.point[5] > 0 and frames[1].label.point[5] <= 8, 'continuous bounce stays within its height after many cycles')
entries[2] = {name='Aura',reminderEligible=true,knownSelf=true,readableActive=true,active=false}
addon.BuffReminder:Update(entries,false)
assert(frames[1].scripts.OnUpdate, 'changed reminder starts a new bounce')
entries[2] = nil
assert(frames[1].point[2]==BuffIconCooldownViewer and frames[1].point[3]=='TOP')
compact=true
addon.BuffReminder:Update(entries,false)
assert(frames[1].point[2]==anchor and frames[1].point[5]==76, 'compact reminder follows the centered layout anchor')
entries[1].active=true
addon.BuffReminder:Update(entries,false)
assert(not frames[1].shown, 'applied buff clears reminder')
entries[1].active=false; entries[1].readableActive=false
addon.BuffReminder:Update(entries,false)
assert(not frames[1].shown, 'secret active state never produces a reminder')
entries[1].readableActive=true
addon.BuffReminder:Update(entries,true)
assert(not frames[1].shown, 'Edit Mode suppresses reminders')
print('PASS: reminder text, native/compact anchoring, applied/secret state and Edit Mode')

combat=false
entries[1].options={notifyMissingSelfBuffs=true}
enabled=false
addon.BuffReminder:Update(entries,false)
assert(not frames[1].shown and not frames[1].scripts.OnUpdate, 'per-buff enable cannot bypass combat restriction')
combat=true
addon.BuffReminder:Update(entries,false)
assert(frames[1].shown, 'per-buff enable works in combat with global disabled')
combat=false
addon.BuffReminder:Update(entries,false)
assert(not frames[1].shown and not frames[1].scripts.OnUpdate, 'leaving combat clears reminder and bounce')
combat=true
addon.BuffReminder:Update(entries,false)
assert(frames[1].shown and frames[1].scripts.OnUpdate, 'reentering combat starts a fresh reminder')
