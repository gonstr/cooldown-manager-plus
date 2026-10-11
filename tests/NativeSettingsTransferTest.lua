local addon = {}
local file = io.open('Core/NativeSettingsTransfer.lua')
assert(file, 'native transfer adapter exists')
file:close()
local function clone(value)
    if type(value)~='table' then return value end
    local result={}; for k,v in pairs(value) do result[k]=clone(v) end; return result
end
CreateFromMixins=function(mixin) return clone(mixin) end
Enum={CDMLayoutMode={AccessOnly=0}}
CooldownViewerUtil={GetCurrentClassAndSpecTag=function() return 1 end, GetClassAndSpecTagText=function() return 'Hunter' end}
CooldownManagerLayout_GetID=function(layout) return layout.id end
CooldownManagerLayout_GetName=function(layout) return layout.name end
CooldownManagerLayout_GetClassAndSpecTag=function(layout) return layout.tag end
local liveLayout={id=1,name='Existing',tag=1}
local live={GetActiveLayout=function() return liveLayout end, HasPendingChanges=function(self) return self.pending end}
live.GetSerializer=function() return {SerializeLayouts=function(_,id) assert(id==1); return 'single' end} end
live.SetActiveLayout=function() error('live layout state must not be mutated') end
CooldownViewerSettings={GetLayoutManager=function() return live end}
local saved, writes='existing',0
C_CooldownViewer={GetLayoutData=function() return saved end, SetLayoutData=function(data) saved=data; writes=writes+1 end}
CooldownViewerLayoutManagerMixin={
    Init=function(self,provider,serializer) self.layouts={}; self.serializer=serializer end,
    SetHasPendingChanges=function() error('native notifications must be disabled on detached manager') end,
    NotifyListeners=function() error('native notifications must be disabled on detached manager') end,
    AreLayoutsFullyMaxed=function(self) local n=0; for _ in pairs(self.layouts) do n=n+1 end; return n>=2 end,
    CreateLayoutsFromSerializedData=function(self,text) return self.serializer:DeserializeLayouts(text) end,
    GetLayout=function(self,id) return self.layouts[id] end,
    SetActiveLayout=function(self,layout) self.active=layout.id; self:SetHasPendingChanges(true); return layout.tag==1 end,
    UseDefaultLayout=function(self) self.active=0; self:SetHasPendingChanges(true) end,
}
CooldownViewerDataStoreSerializationMixin={
    Init=function(self,manager,persistence) self.manager=manager; self:DeserializeLayouts(persistence:GetSerializedData()) end,
    DeserializeLayouts=function(self,text)
        if text=='existing' then self.manager.layouts[1]=clone(liveLayout); return {1} end
        if text=='single' then self.manager.layouts[2]={id=2,name='Imported',tag=1}; self.manager:NotifyListeners(); return {2} end
        return nil
    end,
    SerializeLayouts=function(self)
        assert(self.manager.layouts[1].name=='Existing', 'preserve previously saved layouts')
        return self.manager.active==0 and 'merged-default' or 'merged-imported'
    end,
}
assert(loadfile('Core/NativeSettingsTransfer.lua'))('CooldownManagerPlus',addon)
local adapter=addon.NativeSettingsTransfer
local exported=assert(adapter:Export())
assert(exported.blizzard=='single' and exported.specTag==1 and exported.layoutName=='Existing', 'read selected native layout without modifying it')
local merged=assert(adapter:Prepare(exported))
assert(merged=='merged-imported' and saved=='existing' and writes==0 and liveLayout.name=='Existing', 'preview merges into detached state without native writes')
assert(adapter:Commit(merged) and saved==merged, 'only commit writes serialized native data')
saved='existing'
assert(adapter:Prepare({specTag=1,blizzard=''})=='merged-default', 'starter layout import preserves existing saved layouts')
assert(not adapter:Prepare({specTag=2,blizzard='single'}), 'reject different spec')
assert(not adapter:Prepare({specTag=1,blizzard='bad'}), 'reject malformed native layout')
local maxed=CooldownViewerLayoutManagerMixin.AreLayoutsFullyMaxed
CooldownViewerLayoutManagerMixin.AreLayoutsFullyMaxed=function() return true end
assert(not adapter:Prepare(exported), 'respect native saved-layout limit')
CooldownViewerLayoutManagerMixin.AreLayoutsFullyMaxed=maxed
live.pending=true
assert(not adapter:Prepare(exported), 'preserve pending native edits by rejecting import')
live.pending=false
InCombatLockdown=function() return true end
local previous=writes
assert(not adapter:Commit(merged) and writes==previous, 'no native write in combat')
InCombatLockdown=function() return false end
C_CooldownViewer.SetLayoutData=function() error('write rejected') end
assert(not adapter:Commit(merged), 'report native setter failure')
C_CooldownViewer.SetLayoutData=function() end
assert(not adapter:Commit(merged), 'verify native setter actually persisted the new data')
print('PASS: selected native export, detached merge, existing-layout preservation, starter layout, pending-edit/spec/combat guards and native save failure')
