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
addon.Settings={GetCharacters=function() return {'Other - Realm'} end, CanCopyOverrides=function() return false end,
    CopyCharacter=function(_,name) db.copiedFrom=name; return true end,
    Reset=function() db.didReset=true; return true end}
addon.SettingsTransfer={Export=function() return 'CMP1:export' end,
    Import=function(_,text) if text~='valid' then return false,'Invalid string.' end; db.didImport=true; return true end}
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
assert(loadfile('UI/SetupDialog.lua'))('RenamedAddon',addon)
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
local copyDropdown = find(function(f) return f.template=='WowStyle1DropdownTemplate' and f.defaultText=='Settings' end)
assert(copyDropdown, 'character copy dropdown is available in settings')
local copyFooter=copyDropdown.parent
assert(copyFooter.parent==settings and copyFooter.allPoints==settings.LayoutDropdown, 'copy control belongs to an independent fixed footer aligned with the native dropdown')
assert(not copyFooter.shown, 'addon footer starts hidden')
local menu={}
local function menuNode(entries)
    return {CreateDivider=function() end,CreateTitle=function() end,CreateButton=function(_,label,callback)
        local item={callback=callback,children={}}; entries[label]=item
        return menuNode(item.children)
    end,SetEnabled=function() end}
end
copyDropdown.menuGenerator(nil,menuNode(menu))
assert(menu['Import settings'] and menu['Export settings'] and menu['Reset CM Plus settings'], 'footer contains import, export and reset')
menu['Copy from character'].children['Other - Realm'].callback()
assert(pendingCopy and not db.copiedFrom, 'copy requires confirmation before replacing settings')
StaticPopupDialogs[pendingCopy.key].OnAccept(nil,pendingCopy.data)
assert(db.copiedFrom=='Other - Realm', 'confirmed copy applies the selected character')
menu['Reset CM Plus settings'].callback()
assert(not db.didReset, 'reset requires confirmation')
StaticPopupDialogs[pendingCopy.key].OnAccept(nil,pendingCopy.data)
assert(db.didReset, 'confirmed reset restores current character settings')
menu['Import settings'].callback()
local setupDialog=find(function(f) return f.edit and f.action and f.status end)
assert(setupDialog and setupDialog.shown, 'import opens addon-owned setup dialog')
assert(setupDialog.edit.mouseEnabled and setupDialog.edit.keyboardEnabled and setupDialog.edit.point, 'input has explicit anchoring and accepts mouse and keyboard input')
setupDialog.edit:ClearFocus()
setupDialog.edit.parent.scripts.OnMouseDown()
assert(setupDialog.edit.focused, 'clicking the empty input viewport focuses the editable field')
setupDialog.edit:SetText('invalid'); setupDialog.action.scripts.OnClick()
assert(not db.didImport and setupDialog.status.text=='Invalid string.', 'invalid input is displayed without applying settings')
setupDialog.edit:SetText('valid'); setupDialog.action.scripts.OnClick()
assert(db.didImport and setupDialog.action.text=='Import', 'one import click validates and applies a valid setup')
setupDialog:Hide()
menu['Export settings'].callback()
assert(setupDialog.edit.text=='CMP1:export' and setupDialog.action.text=='Select string', 'export displays selectable combined string')
CopyToClipboard=function() error('clipboard API is restricted to Blizzard') end
local selected=false
setupDialog.edit.HighlightText=function() selected=true end
setupDialog.action.scripts.OnClick()
assert(selected, 'export action selects text for manual copying without calling restricted APIs')
setupDialog:Hide()
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
assert(copyFooter.shown and not settings.LayoutDropdown.shown, 'addon page shows its own footer in place of the native control')
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
assert(general.collapsed and not toggle('Zoom icons').shown, 'collapsing General settings hides top options')
assert(header('Essential spells').shown, 'per-icon categories remain accessible')
general.scripts.OnClick(general)
assert(toggle('Zoom icons').shown, 'expanding General settings restores top options')
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
menu['Import settings'].callback()
assert(setupDialog.shown and not editor(), 'opening setup dialog releases the per-icon editor dismissal layer')
settings.scripts.OnHide()
assert(not setupDialog.shown, 'closing the manager also closes the addon setup dialog')
assert(not editor() and not dismiss.shown, 'leaving addon page closes editor and outside-click layer')
assert(settings.CooldownScroll.child==original and original.shown)
assert(settings.CooldownScroll.ScrollBar:GetAlpha()==0.7, 'leaving addon page restores native scrollbar appearance')
assert(not copyFooter.shown and settings.LayoutDropdown.shown, 'closing settings restores the native footer')
print('PASS: flat category lists, inline Always show, anchored scoped editor, customization/reset, dismissal and native scroll restoration')
