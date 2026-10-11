local frames = {}
local methods = {}
local function frame(parent, template)
    local f = setmetatable({parent=parent, template=template, shown=true, scripts={}, width=460, height=600}, {__index=methods})
    frames[#frames+1] = f
    return f
end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:HookScript(k,v) self.scripts[k]=v end
function methods:Show() local changed=not self.shown; self.shown=true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown; self.shown=false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsMouseOver() return self.mouseOver == true end
function methods:SetParent(p) self.parent=p end
function methods:GetFrameLevel() return 1 end
function methods:GetSize() return self.width,self.height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:EnableMouse() end
function methods:SetPropagateMouseClicks(value) self.propagateMouseClicks=value end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetClampedToScreen() end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetEnabled(v) self.enabled=v end
function methods:IsEnabled() return self.enabled end
function methods:SetMotionScriptsWhileDisabled() end
function methods:SetTextColor() end
function methods:SetWordWrap() end
function methods:SetText(v) self.text=v end
function methods:SetupMenu(fn) self.menuGenerator=fn end
function methods:SetDefaultText(text) self.defaultText=text end
function methods:SetTexture(v) self.texture=v end
function methods:GetStringHeight() return 16 end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:CreateFontString() return frame(self) end
function methods:CreateTexture() return frame(self) end
function methods:GetTitleRegion() return self.Name end
function methods:SetHeaderText(text) self.Name:SetText(text) end
function methods:SetTitleColor() end
function methods:UpdateCollapsedState(collapsed) self.collapsed=collapsed end
function methods:SetClickHandler(handler)
    self.scripts.OnClick=function(self,button) handler(self,button or 'LeftButton') end
end
function methods:RegisterForClicks() end
function methods:SetCustomOnMouseUpHandler(v) self.click=v end
function methods:GetScrollChild() return self.child end
function methods:SetScrollChild(v) self.child=v end
function methods:GetVerticalScroll() return self.position or 0 end
function methods:SetVerticalScroll(v) self.position=v end
for _, name in ipairs({'SetAllPoints','SetSize','SetJustifyH','SetFrameLevel','SetVertexColor','RegisterEvent','UnregisterAllEvents','InitializeIconAnchoring','UpdateScrollChildRect'}) do methods[name]=function() end end
CreateFrame=function(_,_,p,t) local f=frame(p,t); if t=='LargeSideTabButtonTemplate' then f.Icon=frame(f) elseif t=='ListHeaderThreeSliceTemplate' then f.Name=frame(f) elseif t=='ScrollFrameTemplate' then f.ScrollBar=frame(f) end; return f end
local hooks={}
hooksecurefunc=function(_,name,fn) hooks[name]=fn end
local settings=frame()
settings.CooldownScroll=frame(settings)
settings.CooldownScroll.child=frame(settings.CooldownScroll)
local original=settings.CooldownScroll.child
settings.CooldownScroll.position=37
settings.CooldownScroll.ScrollBar=frame(settings.CooldownScroll)
settings.CooldownScroll.ScrollBar.alpha=0.7
settings.SpellsTab=frame(settings)
settings.TabButtons={settings.SpellsTab}
settings.SetDisplayMode=function() end
settings.SearchBox=frame(settings)
CooldownViewerSettings=settings
UIParent=frame()
NORMAL_FONT_COLOR={}
EssentialCooldownViewer={}
UtilityCooldownViewer={}
local db={}
local addon={Buffs={GetDB=function() return db end,Refresh=function() end,GetEntries=function() return {} end},Cooldowns={}}
addon.Cooldowns.GetEntries=function(_,viewer)
    if viewer==EssentialCooldownViewer then return {{key=1,name='Example',item={supported=true},options=addon.Overrides.Get(db,'spell',1)}, {key=3,name='Charge spell',item={},options={}}}
    elseif viewer==UtilityCooldownViewer then return {{key=2,name='Utility example',item={supported=true},options=addon.Overrides.Get(db,'spell',2)}} end
    return {}
end
addon.Cooldowns.SetOverride=function(_,id,name,value) addon.Overrides.Set(db,'spell',id,name,value) end
addon.Cooldowns.ResetOverrides=function(_,id) addon.Overrides.Reset(db,'spell',id) end
addon.Buffs.SetCentered=function(_,enabled) db.centerIcons=enabled==true end
local eligible = false
local timerEnabled
addon.TimerLayer = {SetEnabled=function(_,enabled) timerEnabled=enabled; db.replaceCooldownTimers=enabled end,
    SupportsItem=function(_,item) return item and item.supported end,
    SetOverride=function(_,id,value) addon.Overrides.Set(db,'spell',id,'replaceCooldownTimers',value) end}
addon.Compact = {GetSparkViewer=function() return eligible and EssentialCooldownViewer or nil end}
GameTooltip = {SetOwner=function() end, SetText=function(_,text) GameTooltip.text=text end, Show=function() end, Hide=function() end}
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('EntrySettings.lua'))('RenamedAddon',addon)
assert(loadfile('CooldownManagerPlus.lua'))('RenamedAddon',addon)
local function find(predicate)
    for _,f in ipairs(frames) do if predicate(f) then return f end end
end
local function header(name)
    return find(function(f) return f.template=='ListHeaderThreeSliceTemplate' and f.label.text==name end)
end
local function row(name)
    return find(function(f) return f.icon and f.label and f.label.text==name and f.options end)
end
local function toggle(name)
    return find(function(f) return f.label and f.label.text==name and f.template=='UICheckButtonTemplate' end)
end
local function editor()
    return find(function(f) return f.template=='BackdropTemplate' and f.title and f.shown end)
end
local function choose(dropdown,label)
    local choices={}
    dropdown.menuGenerator(nil,{CreateRadio=function(_,text,selected,callback) choices[text]=callback end})
    assert(choices[label], 'requested choice exists')
    choices[label]()
end
local tab=find(function(f) return f.template=='LargeSideTabButtonTemplate' end)
assert(tab.Icon.texture=='Interface\\AddOns\\RenamedAddon\\Media\\TealPlus')
tab.click(nil,'LeftButton',true)
assert(settings.CooldownScroll.child==original and original.shown, 'addon tab never replaces or hides native scroll content')
assert(settings.CooldownScroll.position==37, 'addon tab leaves native scroll position untouched')
assert(find(function(f) return f.template=='ScrollFrameTemplate' end), 'addon scrolling uses the same template as native pages')
assert(settings.CooldownScroll.ScrollBar:GetAlpha()==0, 'unused native scrollbar is invisible on addon page')
assert(header('Essential spells') and header('Utility spells'), 'spell accordions are directly accessible without an Advanced wrapper')
assert(header('Essential spells').collapsed and header('Utility spells').collapsed, 'spell lists start collapsed')
assert(not header('Buffs') and not header('Advanced overrides'), 'empty buffs omitted and no Advanced wrapper remains')
assert(not row('Example'), 'collapsed category does not allocate spell rows')
local general=header('General settings')
assert(general and not general.collapsed, 'General settings starts expanded')
general.scripts.OnEnter(general)
assert(GameTooltip.text=='Display options and addon features.')
general.scripts.OnClick(general)
assert(general.collapsed and not toggle('Use retro icon style').shown, 'collapsing General settings hides top options')
assert(header('Essential spells').shown, 'per-icon categories remain accessible')
general.scripts.OnClick(general)
assert(toggle('Use retro icon style').shown, 'expanding General settings restores top options')
local centerToggle=toggle('Center icons')
assert(centerToggle and not centerToggle.checked, 'centering defaults to fixed positions')
centerToggle:SetChecked(true); centerToggle.scripts.OnClick(centerToggle)
assert(db.centerIcons and centerToggle.checked, 'centering checkbox persists selection')
centerToggle.scripts.OnEnter(centerToggle)
assert(GameTooltip.text:find('gap between groups',1,true), 'centering tooltip explains separation interaction')
local sparkToggle=toggle('Integrated swing timer spark')
assert(not sparkToggle.enabled)
sparkToggle.scripts.OnEnter(sparkToggle)
assert(GameTooltip.text:find('at least 3',1,true))
hooks.SetDisplayMode()
assert(settings.CooldownScroll.child==original and original.shown and settings.CooldownScroll.position==37)
eligible=true
addon.Buffs.GetEntries=function() return {
    {key=10,name='Self buff',knownSelf=true,reminderEligible=true,options=addon.Overrides.Get(db,'buff',10)},
    {key=11,name='Target buff',knownSelf=false,options=addon.Overrides.Get(db,'buff',11)},
} end
addon.Buffs.SetEffect=function(_,id,name,value) addon.Overrides.Set(db,'buff',id,name,value) end
addon.Buffs.ResetOverrides=function(_,id) addon.Overrides.Reset(db,'buff',id) end
tab.click(nil,'LeftButton',true)
local buffs=header('Buffs')
assert(buffs and buffs.collapsed, 'buffs start collapsed')
buffs.scripts.OnClick(buffs)
assert(not buffs.collapsed and row('Self buff') and row('Target buff'), 'opening buffs reveals the plain list')
local categories=0
for _,f in ipairs(frames) do if f.template=='ListHeaderThreeSliceTemplate' then categories=categories+1 end end
assert(categories==4, 'General settings and three per-icon categories use four accordions')
local selfRow=row('Self buff')
assert(selfRow.check and not selfRow.scripts.OnClick, 'Always show is directly on a plain row')
selfRow.check:SetChecked(true); selfRow.check.scripts.OnClick(selfRow.check)
assert(db.effects[10].alwaysShow and selfRow.summary.text=='', 'Always show alone has no hidden-customization marker')
local timerToggle=toggle('Hide buff timers on spell icons')
local duplicateToggle=toggle('Hide buffs already shown on spell icons')
timerToggle:SetChecked(true); timerToggle.scripts.OnClick(timerToggle)
assert(timerEnabled and not duplicateToggle.enabled)
duplicateToggle.scripts.OnEnter(duplicateToggle)
assert(GameTooltip.text:find('Requires buff timers',1,true))
timerToggle:SetChecked(false); timerToggle.scripts.OnClick(timerToggle)
assert(duplicateToggle.enabled)
selfRow.options.scripts.OnClick(selfRow.options)
local popup=editor()
assert(popup and popup.title.text=='Self buff', 'options button opens an anchored editor for that entry')
assert(popup.rows[1].label.text=='Notify on missing self buffs in combat' and popup.rows[2].label.text=='Hide buffs already shown on spell icons', 'eligible buff editor shows all applicable options together')
assert(popup.rows[1].dropdown.defaultText=='Use default')
popup.rows[1].dropdown.scripts.OnEnter(popup.rows[1].dropdown)
assert(GameTooltip.text=='Use the matching option in General settings.')
choose(popup.rows[1].dropdown,'Disabled')
assert(db.effects[10].notifyMissingSelfBuffs==false and selfRow.summary.text=='Customized', 'hidden exception marks the row and persists')
popup.reset.scripts.OnClick(popup.reset)
assert(db.effects[10].alwaysShow and db.effects[10].notifyMissingSelfBuffs==nil and selfRow.check.checked and selfRow.summary.text=='', 'reset restores popup options without changing the visible Always show checkbox')
row('Target buff').options.scripts.OnClick(row('Target buff').options)
assert(editor()==popup and popup.title.text=='Target buff', 'one editor is reused when selecting another row')
assert(popup.rows[1].label.text=='Hide buffs already shown on spell icons' and not popup.rows[2].shown, 'ineligible buff only offers applicable option')
local dismiss=find(function(f) return f.propagateMouseClicks and f.scripts.OnMouseDown end)
assert(dismiss and dismiss.shown, 'outside-click dismissal active while editor open')
dismiss.scripts.OnMouseDown(dismiss)
assert(not editor() and not dismiss.shown, 'outside click closes popup and releases dismissal layer')
selfRow.options.scripts.OnClick(selfRow.options)
selfRow.options.mouseOver=true
dismiss.scripts.OnMouseDown(dismiss)
selfRow.options.scripts.OnClick(selfRow.options)
assert(not editor(), 'mouse-down propagation followed by clicking the same options button closes without reopening')
selfRow.options.mouseOver=false
local essential=header('Essential spells')
essential.scripts.OnClick(essential,'RightButton')
assert(essential.collapsed, 'category expands only on left click')
essential.scripts.OnClick(essential)
assert(row('Example') and row('Charge spell') and not row('Example').check, 'spell list uses plain rows without Always show')
row('Example').options.scripts.OnClick(row('Example').options)
assert(popup.rows[1].label.text=='Hide essential cooldowns outside combat' and popup.rows[2].label.text=='Hide buff timers on spell icons')
choose(popup.rows[1].dropdown,'Enabled')
choose(popup.rows[2].dropdown,'Enabled')
assert(db.spellOverrides[1].combatOnly and db.spellOverrides[1].replaceCooldownTimers and row('Example').summary.text=='Customized')
choose(popup.rows[2].dropdown,'Use default')
assert(db.spellOverrides[1].replaceCooldownTimers==nil)
row('Charge spell').options.scripts.OnClick(row('Charge spell').options)
assert(popup.rows[1].label.text=='Hide essential cooldowns outside combat' and not popup.rows[2].shown, 'unsupported spell does not offer timer option')
essential.scripts.OnClick(essential)
assert(not editor(), 'collapsing selected category closes popup')
assert(not row('Example').shown)
buffs.scripts.OnClick(buffs)
assert(buffs.collapsed and not selfRow.shown)
hooks.SetDisplayMode()
tab.click(nil,'LeftButton',true)
assert(buffs.collapsed, 'category expansion is remembered when switching tabs')
buffs.scripts.OnClick(buffs)
selfRow.options.scripts.OnClick(selfRow.options)
settings.scripts.OnHide()
assert(not editor() and not dismiss.shown, 'leaving addon page closes editor and outside-click layer')
assert(settings.CooldownScroll.child==original and original.shown)
assert(settings.CooldownScroll.ScrollBar:GetAlpha()==0.7, 'leaving addon page restores native scrollbar appearance')
print('PASS: flat category lists, inline Always show, anchored scoped editor, customization/reset, dismissal and native scroll restoration')
