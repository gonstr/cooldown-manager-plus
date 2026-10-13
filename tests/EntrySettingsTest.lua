local addon = {}
assert(loadfile('Overrides.lua'))('Test', addon)
local db = {effects={}, spellOverrides={}}
local combat = false
local secret = {}
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
Enum = {CooldownViewerCategory={Essential=0, Utility=1, TrackedBuff=2, TrackedBar=3, HiddenSpell=4, HiddenAura=5}}
local callbacks = {}
Menu = {ModifyMenu=function(tag, callback) callbacks[tag]=callback end}
local function region()
    return {shown=true, SetPoint=function() end, SetSize=function() end,
        SetText=function(self, text) self.text=text end, SetFont=function() end,
        SetShadowColor=function() end, SetShadowOffset=function() end,
        SetFrameLevel=function() end, EnableMouse=function() end,
        Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end,
        CreateFontString=function() return region() end,
        CreateTexture=function(self) local texture=region(); self.textures=self.textures or {}; self.textures[#self.textures+1]=texture; return texture end,
        SetColorTexture=function(self,...) self.color={...} end,
        SetAllPoints=function(self,target) self.target=target end,
        SetHeight=function() end, SetWidth=function() end}
end
local events
CreateFrame = function()
    local frame = region()
    frame.RegisterEvent=function() end
    frame.SetScript=function(_, _, fn) events=fn end
    return frame
end
hooksecurefunc=function(object, name, callback)
    local original=object[name]
    assert(type(original)=='function', 'hook only existing native methods')
    object[name]=function(self, ...) original(self, ...); callback(self, ...) end
end
local tooltip={lines={}, AddLine=function(self, text) self.lines[#self.lines+1]=text end, Show=function() end}
GetAppropriateTooltip=function() return tooltip end
GameTooltip=tooltip
addon.Buffs={GetDB=function() return db end,
    SetEffect=function(_, id, key, value) addon.Overrides.Set(db,'buff',id,key,value) end}
addon.Cooldowns={SetOverride=function(_,id,key,value) addon.Overrides.Set(db,'spell',id,key,value) end,
    ResetOverrides=function(_,id) addon.Overrides.Reset(db,'spell',id) end}
addon.TimerLayer={SupportsItem=function(_,item) return item.info.charges==false end,
    SetOverride=function(_,id,value) addon.Overrides.Set(db,'spell',id,'replaceCooldownTimers',value) end}
addon.BuffEligibility={IsEligibleCooldown=function(_,info) return info.eligible==true end}
local function item(id, category, extra)
    local f=region()
    f.id=id; f.info=extra or {}; f.info.category=category; f.Icon=region()
    f.GetCooldownID=function(self) return self.id end
    f.GetCooldownInfo=function(self) return self.info end
    f.GetFrameLevel=function() return 2 end
    f.IsEmptyCategory=function(self) return self.empty==true end
    f.RefreshData=function() end
    f.RefreshTooltip=function() end
    return f
end
local buff=item(10,2,{selfAura=true,eligible=true})
local essential=item(20,0,{charges=false})
local utility=item(21,1,{charges=true})
local hidden=item(22,4,{charges=false})
local hiddenBuff=item(11,5,{selfAura=false})
local bar=item(12,3,{selfAura=true,eligible=true})
local active={buff,essential,utility,hidden,hiddenBuff,bar}
local function pool(list)
    return {EnumerateActive=function() local i=0; return function() i=i+1; return list[i] end end}
end
local settings={categoryPool=pool({{itemPool=pool(active)}}), RefreshLayout=function() error('addon must never call native RefreshLayout') end,
    RefreshVisibleCategories=function() error('addon must never refresh native data') end,
    HookScript=function(self,name,fn) self[name]=fn end}
assert(loadfile('EntrySettings.lua'))('Test',addon)
assert(type(addon.EntrySettings.Install)=='function', 'per-icon overrides integrate with native settings')
addon.EntrySettings:Install(settings)
local function menuNode()
    local node={children={}}
    local function add(kind,label,selected,callback)
        local child=menuNode(); child.kind=kind; child.label=label; child.selected=selected; child.callback=callback
        node.children[#node.children+1]=child; return child
    end
    node.CreateDivider=function() return add('divider') end
    node.CreateTitle=function(_,label) return add('title',label) end
    node.CreateButton=function(_,label,callback) return add('button',label,nil,callback) end
    node.CreateCheckbox=function(_,label,selected,callback) return add('checkbox',label,selected,callback) end
    node.CreateRadio=function(_,label,selected,callback) return add('radio',label,selected,callback) end
    node.SetEnabled=function(self,value) self.enabled=value end
    node.SetTooltip=function(self,fn) self.tooltip=fn end
    return node
end
local function menu(f)
    local root=menuNode(); root:CreateButton('Blizzard default',function() end)
    callbacks.MENU_COOLDOWN_SETTINGS_ITEM(f,root)
    assert(root.children[1].label=='Blizzard default', 'native menu entries preserved')
    return root
end
local function find(node,label)
    for _,child in ipairs(node.children) do if child.label==label then return child end end
end
local function choose(node,label) local choice=assert(find(node,label)); choice.callback(); return choice end
local root=menu(buff)
assert(root.children[2].kind=='divider' and root.children[3].label=='|cff26d9c7CM Plus|r', 'teal title follows native section')
local always=assert(find(root,'Always show'))
always.callback(); assert(db.effects[10].alwaysShow==true, 'Always show persists on the native buff icon')
local notify=assert(find(root,'Notify on missing self buffs in combat'))
choose(notify,'Disabled'); assert(db.effects[10].notifyMissingSelfBuffs==false, 'disabled remains an explicit override')
choose(notify,'Use default'); assert(db.effects[10].notifyMissingSelfBuffs==nil, 'Use default restores inheritance')
choose(notify,'Enabled')
local duplicates=assert(find(root,'Hide buffs already shown on spell icons'))
choose(duplicates,'Enabled'); assert(db.effects[10].hideDuplicateBuffs==true)
assert(buff.cmPlusIndicator and buff.cmPlusIndicator.shown, 'native settings icon shows active overrides')
buff:RefreshTooltip()
assert(table.concat(tooltip.lines,'\n'):find('Always show',1,true), 'native tooltip explains icon indicators')
find(menu(buff),'Reset overrides').callback()
assert(addon.Overrides.Count('buff',db.effects[10])==0 and not buff.cmPlusIndicator.shown, 'reset clears every override and its indicators')
assert(not find(menu(hiddenBuff),'Notify on missing self buffs in combat'), 'unconfirmed self buffs cannot offer reminders')
assert(not find(menu(bar),'Always show'), 'bar settings are outside buff-icon override scope')
root=menu(essential)
choose(assert(find(root,'Hide essential cooldowns outside combat')),'Enabled')
choose(assert(find(root,'Hide buff timers on spell icons')),'Disabled')
assert(db.spellOverrides[20].combatOnly and db.spellOverrides[20].replaceCooldownTimers==false)
assert(essential.cmPlusIndicator.shown and not essential.cmPlusIndicator.text, 'customized icons have a border without letter badges')
assert(essential.cmPlusIndicator.target==essential.Icon and #essential.cmPlusIndicator.textures==4, 'border surrounds the native icon')
for _, edge in ipairs(essential.cmPlusIndicator.textures) do
    assert(edge.color[1]==0.15 and edge.color[2]==0.85 and edge.color[3]==0.78 and edge.color[4]==1, 'override border is opaque teal')
end
choose(assert(find(root,'Hide essential cooldowns outside combat')),'Use default')
assert(essential.cmPlusIndicator.shown, 'an explicitly disabled setting alone keeps the border')
tooltip.lines={}; essential:RefreshTooltip()
assert(table.concat(tooltip.lines,'\n'):find('Hide buff timers on spell icons: Disabled',1,true), 'tooltip still explains disabled overrides')
choose(assert(find(root,'Hide buff timers on spell icons')),'Use default')
assert(not essential.cmPlusIndicator.shown, 'returning all settings to default removes the border')
choose(assert(find(root,'Hide buff timers on spell icons')),'Enabled')
find(menu(essential),'Reset overrides').callback()
assert(not db.spellOverrides[20] and not essential.cmPlusIndicator.shown, 'spell reset clears both settings and indicators')
assert(find(menu(utility),'Hide utility cooldowns outside combat') and not find(menu(utility),'Hide buff timers on spell icons'), 'utility label and unsupported timer handling')
db.spellOverrides[21]={replaceCooldownTimers=false}
addon.EntrySettings:RefreshIndicators()
assert(utility.cmPlusIndicator and utility.cmPlusIndicator.shown, 'saved overrides keep their border even when their control is currently unavailable')
tooltip.lines={}; utility:RefreshTooltip()
assert(table.concat(tooltip.lines,'\n'):find('Hide buff timers on spell icons: Disabled',1,true), 'tooltip explains every saved override')
assert(find(menu(hidden),'Hide buff timers on spell icons'), 'hidden spells retain overrides before native placement')
db.effects[10]={alwaysShow=true}
addon.EntrySettings:RefreshIndicators()
buff.id=30; buff:RefreshData()
assert(not buff.cmPlusIndicator.shown, 'pooled icons clear previous entry borders')
buff.id=10; buff.empty=true; buff:RefreshData()
assert(not buff.cmPlusIndicator.shown and #menu(buff).children==1, 'empty native slots have no overrides')
buff.empty=false; buff:RefreshData()
local stale=menu(buff); buff.id=31
find(stale,'Always show').callback()
assert(db.effects[10].alwaysShow and not db.effects[31], 'stale menu callbacks cannot write after an icon is reused')
buff.id=secret
assert(#menu(buff).children==1, 'secret IDs are never used as override keys')
buff:RefreshData(); assert(not buff.cmPlusIndicator.shown)
buff.id=10; buff.info.category=secret
assert(#menu(buff).children==1, 'secret categories remain opaque')
buff.info.category=2
buff.info.selfAura=secret
assert(not find(menu(buff),'Notify on missing self buffs in combat'), 'opaque self-aura metadata cannot offer reminders')
buff.info.selfAura=true
local moved=menu(essential); essential.info.category=1
choose(assert(find(moved,'Hide essential cooldowns outside combat')),'Enabled')
assert(not db.spellOverrides[20], 'category changes invalidate an already open override menu')
assert(find(menu(essential),'Hide utility cooldowns outside combat'), 'menu follows native category changes')
combat=true
root=menu(buff)
assert(find(root,'Always show').enabled==false, 'combat disables override controls')
find(root,'Always show').callback(); assert(db.effects[10].alwaysShow, 'combat also rejects stale callbacks')
local fresh=item(40,2,{selfAura=true,eligible=true}); active[#active+1]=fresh; db.effects[40]={alwaysShow=true}
addon.EntrySettings:RefreshIndicators(); assert(not fresh.cmPlusIndicator, 'indicator creation waits until combat ends')
combat=false; events(nil,'PLAYER_REGEN_ENABLED')
assert(fresh.cmPlusIndicator and fresh.cmPlusIndicator.shown, 'deferred borders appear after combat')
print('PASS: native menu extension, inheritance/reset, eligibility, borders, pooled identities, secret values and combat deferral')
