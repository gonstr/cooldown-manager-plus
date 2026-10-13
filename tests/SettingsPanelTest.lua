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
function methods:EnableMouse(value) self.mouseEnabled=value end
function methods:EnableKeyboard(value) self.keyboardEnabled=value end
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
function methods:SetText(v) self.text=v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.text or '' end
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
for _, name in ipairs({'SetMultiLine','SetAutoFocus','SetFontObject','SetTextInsets','SetMaxLetters','SetFocus','ClearFocus','HighlightText'}) do methods[name]=function() end end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:SetAllPoints(target) self.allPoints=target end
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
settings.LayoutDropdown=frame(settings)
settings.LayoutDropdown.menuGenerator=function() error('native menu must not be replaced or invoked') end
local nativeLayoutMenu=settings.LayoutDropdown.menuGenerator
CooldownViewerSettings=settings
UIParent=frame()
NORMAL_FONT_COLOR={}
EssentialCooldownViewer={}
UtilityCooldownViewer={}
local db={}
local addon={Buffs={GetDB=function() return db end,Refresh=function() end,GetEntries=function() return {} end},Cooldowns={}}
local characters={'Other - Realm'}
addon.Settings={GetCharacters=function() return characters end, CanCopyOverrides=function() return false end,
    CopyCharacter=function(_,name) db.copiedFrom=name; return true end}
StaticPopupDialogs={}
local pendingCopy
StaticPopup_Show=function(key, name, scope, data) pendingCopy={key=key,name=name,scope=scope,data=data} end
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
addon.EntrySettings.Install=function() end
addon.EntrySettings.RefreshIndicators=function() end
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
local copyDropdown = find(function(f) return f.template=='WowStyle1DropdownTemplate' and f.defaultText=='Copy from character' end)
assert(copyDropdown, 'character copy dropdown is available in settings')
local copyFooter=copyDropdown.parent
assert(copyFooter.parent==settings and copyFooter.allPoints==settings.LayoutDropdown, 'copy control belongs to an independent fixed footer aligned with the native dropdown')
assert(not copyFooter.shown, 'addon footer starts hidden')
local menu={}
local function menuNode(entries)
    return {CreateDivider=function() end,CreateTitle=function() end,CreateButton=function(_,label,callback)
        local item={callback=callback,children={}}; entries[label]=item
        local child=menuNode(item.children); child.SetEnabled=function(_,enabled) item.enabled=enabled end; return child
    end,SetEnabled=function() end}
end
copyDropdown.menuGenerator(nil,menuNode(menu))
assert(menu['Other - Realm'] and not menu['Copy from character'], 'copy menu lists characters directly')
local count=0; for _ in pairs(menu) do count=count+1 end
assert(count==1, 'footer offers only character copying')
menu['Other - Realm'].callback()
assert(pendingCopy and not db.copiedFrom, 'copy requires confirmation before replacing settings')
StaticPopupDialogs[pendingCopy.key].OnAccept(nil,pendingCopy.data)
assert(db.copiedFrom=='Other - Realm', 'confirmed copy applies the selected character')
characters={}
local emptyMenu={}; copyDropdown.menuGenerator(nil,menuNode(emptyMenu))
assert(emptyMenu['No other saved characters'] and emptyMenu['No other saved characters'].enabled==false, 'empty copy menu explains why no source is available')
characters={'Other - Realm'}
local tab=find(function(f) return f.template=='LargeSideTabButtonTemplate' end)
assert(tab.Icon.texture=='Interface\\AddOns\\RenamedAddon\\Media\\TealPlus')
tab.click(nil,'LeftButton',true)
assert(copyFooter.shown and not settings.LayoutDropdown.shown, 'addon page shows its own footer in place of the native control')
assert(settings.CooldownScroll.child==original and original.shown, 'addon tab never replaces or hides native scroll content')
assert(settings.CooldownScroll.position==37, 'addon tab leaves native scroll position untouched')
assert(find(function(f) return f.template=='ScrollFrameTemplate' end), 'addon scrolling uses the same template as native pages')
assert(settings.CooldownScroll.ScrollBar:GetAlpha()==0, 'unused native scrollbar is invisible on addon page')
assert(not header('General settings') and not header('Essential spells') and not header('Utility spells'), 'global page has no accordions')
assert(toggle('Zoom icons').shown, 'global settings are always visible')
assert(find(function(f) return f.text == 'Right-click icons in Blizzard’s Buffs and Spells tabs to override settings for individual spells.' end), 'global page explains how to access per-icon overrides')
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
assert(not copyFooter.shown and settings.LayoutDropdown.shown, 'native page restores its dropdown and hides the addon footer')
assert(settings.LayoutDropdown.menuGenerator==nativeLayoutMenu, 'native dropdown behavior remains unchanged')
assert(settings.CooldownScroll.child==original and original.shown and settings.CooldownScroll.position==37)
eligible=true
tab.click(nil,'LeftButton',true)
assert(sparkToggle.enabled, 'global settings refresh when returning to the plus tab')
local timerToggle=toggle('Hide buff timers on spell icons')
local duplicateToggle=toggle('Hide buffs already shown on spell icons')
timerToggle:SetChecked(true); timerToggle.scripts.OnClick(timerToggle)
assert(timerEnabled and not duplicateToggle.enabled)
timerToggle:SetChecked(false); timerToggle.scripts.OnClick(timerToggle)
assert(duplicateToggle.enabled)
settings.scripts.OnHide()
assert(settings.CooldownScroll.child==original and original.shown)
assert(settings.CooldownScroll.ScrollBar:GetAlpha()==0.7, 'leaving addon page restores native scrollbar appearance')
assert(not copyFooter.shown and settings.LayoutDropdown.shown, 'closing settings restores the native footer')
print('PASS: always-visible global settings, override hint, character copying and native scroll/footer restoration')
